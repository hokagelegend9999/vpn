#!/bin/bash
set -e

echo "[+] Update system and install build dependencies..."
apt update
apt install -y build-essential cmake libssl-dev libpcre3-dev git openssl liblua5.3-dev libjson-c-dev libcurl4-openssl-dev

echo "[+] Installing required kernel headers..."
apt install -y linux-headers-$(uname -r)

echo "[+] Downloading accel-ppp source code..."
cd /usr/src
git clone https://github.com/accel-ppp/accel-ppp.git
cd accel-ppp

echo "[+] Configuring and compiling accel-ppp..."
mkdir build
cd build
cmake -DCMAKE_INSTALL_PREFIX=/usr -DKDIR=/usr/src/linux-headers-$(uname -r) -DRADIUS=TRUE -DBUILD_IPOE=TRUE -DBUILD_VLAN_MON=TRUE ..
make -j$(nproc)
make install

echo "[+] Creating configuration directories..."
mkdir -p /etc/ssl/sstp /var/log/accel-ppp /etc/ppp
chown -R root:root /etc/ssl/sstp
chmod -R 700 /etc/ssl/sstp

echo "[+] Generating self-signed certificate..."
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
 -keyout /etc/ssl/sstp/server.key \
 -out /etc/ssl/sstp/server.crt \
 -subj "/CN=sstp-server" \
 -addext "subjectAltName=DNS:sstp-server"

chmod 600 /etc/ssl/sstp/server.key
chmod 644 /etc/ssl/sstp/server.crt
cp /etc/ssl/sstp/server.crt /etc/ssl/sstp/ca.crt

echo "[+] Creating chap-secrets file..."
cat <<EOF > /etc/ppp/chap-secrets
# Secrets for authentication using CHAP
# client    server  secret          IP addresses
vpnuser    *       vpnpassword     *
EOF
chmod 600 /etc/ppp/chap-secrets

echo "[+] Creating accel-ppp configuration..."
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

echo "[+] Creating systemd service..."
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

[Install]
WantedBy=multi-user.target
EOF

echo "[+] Enabling and starting service..."
systemctl daemon-reload
systemctl enable accel-ppp
systemctl start accel-ppp

echo "[+] Setting up IP forwarding..."
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

echo "[+] Configuring firewall..."
apt install -y iptables-persistent
iptables -t nat -A POSTROUTING -o $(ip route | grep default | awk '{print $5}') -j MASQUERADE
iptables -A FORWARD -i sstp+ -j ACCEPT
iptables-save > /etc/iptables/rules.v4

echo "[+] Installation completed successfully!"
echo "    SSTP Server is running on port 444"
echo "    Test credentials:"
echo "    Username: vpnuser"
echo "    Password: vpnpassword"
echo "    Check status: systemctl status accel-ppp"
