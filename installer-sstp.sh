#!/bin/bash
set -e

echo -e "\033[1;36m[+] Menambahkan repository accel-ppp...\033[0m"
add-apt-repository -y ppa:accel-ppp/accel-ppp > /dev/null 2>&1 || { echo "Gagal menambahkan repository"; exit 1; }

echo -e "\033[1;36m[+] Update & install dependencies...\033[0m"
apt update -y && apt install -y accel-ppp accel-ppp-tools openssl

echo -e "\033[1;36m[+] Membuat direktori konfigurasi dan log...\033[0m"
mkdir -p /etc/ssl/sstp /var/log/accel-ppp /etc/ppp

echo -e "\033[1;36m[+] Membuat sertifikat self-signed...\033[0m"
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
 -keyout /etc/ssl/sstp/server.key \
 -out /etc/ssl/sstp/server.crt \
 -subj "/CN=sstp-server"

cp /etc/ssl/sstp/server.crt /etc/ssl/sstp/ca.crt

echo -e "\033[1;36m[+] Membuat file akun SSTP...\033[0m"
cat <<EOF > /etc/ppp/chap-secrets
# Contoh format: username * password *
vpnuser * vpnpassword *
EOF
chmod 600 /etc/ppp/chap-secrets

echo -e "\033[1;36m[+] Membuat konfigurasi accel-ppp...\033[0m"
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

echo -e "\033[1;36m[+] Membuat systemd service...\033[0m"
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

echo -e "\033[1;36m[+] Reload daemon & enable service...\033[0m"
systemctl daemon-reload
systemctl enable --now accel-ppp

echo -e "\033[1;32m[✓] Instalasi selesai!\033[0m"
echo -e "\033[1;33mPerintah yang berguna:"
echo -e "• Cek status: systemctl status accel-ppp"
echo -e "• Restart service: systemctl restart accel-ppp"
echo -e "• Lihat log: journalctl -u accel-ppp -f\033[0m"
