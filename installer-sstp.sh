#!/bin/bash
set -e

echo "[+] Update & install dependencies..."
apt update && apt install -y accel-ppp accel-ppp-tools openssl

echo "[+] Membuat direktori konfigurasi dan log..."
mkdir -p /etc/ssl/sstp /var/log/accel-ppp /etc/ppp

echo "[+] Membuat sertifikat self-signed..."
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
 -keyout /etc/ssl/sstp/server.key \
 -out /etc/ssl/sstp/server.crt \
 -subj "/CN=sstp-server"

cp /etc/ssl/sstp/server.crt /etc/ssl/sstp/ca.crt

echo "[+] Membuat file akun SSTP..."
cat <<EOF > /etc/ppp/chap-secrets
vpnuser * vpnpassword *
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
log-error=/var/log/accel-ppp/accel-error.log

[common]
ppp-max-mtu=1400

[chap-secrets]
chap-secrets=/etc/ppp/chap-secrets

[ppp]
mtu=1400
mru=1400
mppe=require
ipv4=require
lcp-echo-interval=20
lcp-echo-timeout=60

[sstp]
port=444
accept=ssl
ssl-protocol=tls1.2
ssl-ca-file=/etc/ssl/sstp/ca.crt
ssl-pemfile=/etc/ssl/sstp/server.crt
ssl-keyfile=/etc/ssl/sstp/server.key
ip-pool=sstp
ifname=sstp%d

[ip-pool]
192.168.88.10-192.168.88.100,name=sstp

[dns]
dns1=8.8.8.8
dns2=1.1.1.1

[log]
log-file=/var/log/accel-ppp/accel.log
level=3
EOF

echo "[+] Membuat systemd service..."
cat <<EOF > /etc/systemd/system/accel-ppp.service
[Unit]
Description=HOKAGE VPN Server
After=network.target

[Service]
ExecStart=/usr/sbin/accel-pppd -c /etc/accel-ppp.conf
Restart=always
RestartSec=5
Type=simple

[Install]
WantedBy=multi-user.target
EOF

echo "[+] Reload daemon & enable service..."
systemctl daemon-reload
systemctl enable accel-ppp
systemctl restart accel-ppp

echo "[✓] Instalasi selesai. Cek status dengan: systemctl status accel-ppp"
