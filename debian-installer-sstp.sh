#!/bin/bash
set -e

echo "[+] Update & install dependencies..."
apt update && apt install -y build-essential cmake libssl-dev libpcre3-dev git openssl

echo "[+] Mengunduh dan mengkompilasi accel-ppp dari sumber..."
cd /usr/src
git clone https://github.com/accel-ppp/accel-ppp.git
cd accel-ppp
mkdir build
cd build
cmake -DCMAKE_INSTALL_PREFIX=/usr -DKDIR=/usr/src/linux-headers-$(uname -r) ..
make
make install

echo "[+] Membuat direktori konfigurasi dan log..."
mkdir -p /etc/ssl/sstp /var/log/accel-ppp /etc/ppp
chown -R root:root /etc/ssl/sstp
chmod -R 700 /etc/ssl/sstp

echo "[+] Membuat sertifikat self-signed..."
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
 -keyout /etc/ssl/sstp/server.key \
 -out /etc/ssl/sstp/server.crt \
 -subj "/CN=sstp-server" \
 -addext "subjectAltName=DNS:sstp-server"

# Set permissions for certificate files
chmod 600 /etc/ssl/sstp/server.key
chmod 644 /etc/ssl/sstp/server.crt

cp /etc/ssl/sstp/server.crt /etc/ssl/sstp/ca.crt
chmod 644 /etc/ssl/sstp/ca.crt

echo "[+] Membuat file akun SSTP..."
cat <<EOF > /etc/ppp/chap-secrets
# Secrets for authentication using CHAP
# client    server  secret          IP addresses
vpnuser    *       vpnpassword     *
EOF
chmod 600 /etc/ppp/chap-secrets

echo "[+] Membuat konfigurasi accel-ppp..."
cat <<EOF > /etc/accel-ppp.conf
[modules]
log_file
sstp
chap-secrets
auth_mschap_v2
ippool

[core]
log-error=/var/log/accel-ppp/error.log
log-debug=/var/log/accel-ppp/debug.log

[common]
single-session=replace
ppp-max-mtu=1400

[chap-secrets]
chap-secrets=/etc/ppp/chap-secrets

[ppp]
verbose=1
min-mtu=1280
mtu=1400
mru=1400
mppe=require
ipv4=require
ipv6=deny
lcp-echo-interval=20
lcp-echo-timeout=60
lcp-echo-failure=3

[sstp]
verbose=1
port=444
accept=ssl
ssl-protocol=tls1.2,tls1.3
ssl-ciphers=DEFAULT:@SECLEVEL=1
ssl-ca-file=/etc/ssl/sstp/ca.crt
ssl-pemfile=/etc/ssl/sstp/server.crt
ssl-keyfile=/etc/ssl/sstp/server.key
ip-pool=sstp
ifname=sstp%d

[ip-pool]
192.168.88.10-192.168.88.100,name=sstp

[dns]
dns1=8.8.8.8
dns2=8.8.4.4

[log]
log-file=/var/log/accel-ppp/accel.log
log-emerg=/var/log/accel-ppp/emerg.log
log-fail-file=/var/log/accel-ppp/auth-fail.log
level=3
color=1
EOF

echo "[+] Membuat systemd service..."
cat <<EOF > /etc/systemd/system/accel-ppp.service
[Unit]
Description=Accel-PPP Server
After=network.target

[Service]
Type=forking
ExecStart=/usr/sbin/accel-pppd -c /etc/accel-ppp.conf -p /var/run/accel-pppd.pid
PIDFile=/var/run/accel-pppd.pid
Restart=on-failure
RestartSec=5s

# Hardening
PrivateTmp=true
ProtectSystem=full
NoNewPrivileges=true
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

echo "[+] Mengatur logging rotation..."
cat <<EOF > /etc/logrotate.d/accel-ppp
/var/log/accel-ppp/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 640 root adm
    sharedscripts
    postrotate
        systemctl reload accel-ppp >/dev/null 2>&1 || true
    endscript
}
EOF

echo "[+] Reload daemon & enable service..."
systemctl daemon-reload
systemctl enable accel-ppp
systemctl start accel-ppp

echo "[+] Mengaktifkan IP forwarding..."
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

echo "[+] Menyiapkan firewall rules..."
apt install -y iptables-persistent
iptables -t nat -A POSTROUTING -o $(ip route | grep default | awk '{print $5}') -j MASQUERADE
iptables -A FORWARD -i sstp+ -j ACCEPT
iptables-save > /etc/iptables/rules.v4

echo "[✓] Instalasi selesai pada Debian 11"
echo "    Cek status dengan: systemctl status accel-ppp"
echo "    Port SSTP: 444 (pastikan terbuka di firewall)"
echo "    Kredensial:"
echo "      Username: vpnuser"
echo "      Password: vpnpassword"
