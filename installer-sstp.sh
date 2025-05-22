#!/bin/bash
set -e

# Fungsi untuk menangani error
function handle_error() {
    echo -e "\033[1;31m[ERROR] $1\033[0m"
    exit 1
}

# Warna untuk output
GREEN='\033[1;32m'
BLUE='\033[1;34m'
RED='\033[1;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}[+] Menyiapkan sistem...${NC}"

# Install dependensi dasar
apt-get update && apt-get install -y software-properties-common wget || handle_error "Gagal install dependencies"

echo -e "${BLUE}[+] Menambahkan repository accel-ppp...${NC}"
# Untuk Ubuntu 20.04 (focal)
add-apt-repository -y ppa:accel-ppp/accel-ppp || handle_error "Gagal menambahkan repository"

echo -e "${BLUE}[+] Mengupdate paket dan install accel-ppp...${NC}"
apt-get update && apt-get install -y accel-ppp accel-ppp-tools openssl || {
    # Fallback jika repository tidak bekerja
    echo -e "${RED}[!] Menggunakan fallback: kompilasi dari source...${NC}"
    apt-get install -y git cmake build-essential libssl-dev libpcre3-dev
    git clone https://github.com/accel-ppp/accel-ppp.git /tmp/accel-ppp
    cd /tmp/accel-ppp
    mkdir build
    cd build
    cmake -DBUILD_DRIVER=FALSE ..
    make
    make install
    ldconfig
}

echo -e "${GREEN}[✓] accel-ppp berhasil diinstall${NC}"

# Lanjutkan dengan bagian konfigurasi SSTP seperti sebelumnya
echo -e "${BLUE}[+] Membuat direktori konfigurasi...${NC}"
mkdir -p /etc/ssl/sstp /var/log/accel-ppp /etc/ppp

echo -e "${BLUE}[+] Membuat sertifikat SSL...${NC}"
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout /etc/ssl/sstp/server.key \
    -out /etc/ssl/sstp/server.crt \
    -subj "/CN=sstp-server" || handle_error "Gagal membuat sertifikat"

cp /etc/ssl/sstp/server.crt /etc/ssl/sstp/ca.crt

echo -e "${BLUE}[+] Membuat file autentikasi...${NC}"
cat <<EOF > /etc/ppp/chap-secrets
# Format: username * password *
vpnuser * vpnpassword *
EOF
chmod 600 /etc/ppp/chap-secrets

echo -e "${BLUE}[+] Membuat konfigurasi accel-ppp...${NC}"
cat > /etc/accel-ppp.conf <<'EOL'
[modules]
log_file
sstp
chap-secrets
auth_mschap_v2
ippool

[core]
log-error=/var/log/accel-ppp/error.log

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
EOL

echo -e "${BLUE}[+] Membuat service systemd...${NC}"
cat > /etc/systemd/system/accel-ppp.service <<'EOL'
[Unit]
Description=Accel-PPP Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/sbin/accel-pppd -c /etc/accel-ppp.conf
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOL

echo -e "${BLUE}[+] Memulai service...${NC}"
systemctl daemon-reload
systemctl enable --now accel-ppp

echo -e "${GREEN}[✓] Instalasi selesai!${NC}"
echo -e "\nBerikut informasi yang perlu dicatat:"
echo -e "• Port SSTP: ${GREEN}444${NC}"
echo -e "• Username: ${GREEN}vpnuser${NC}"
echo -e "• Password: ${GREEN}vpnpassword${NC}"
echo -e "• Sertifikat CA: ${GREEN}/etc/ssl/sstp/ca.crt${NC}"
echo -e "\nPerintah monitoring:"
echo -e "• Status service: ${GREEN}systemctl status accel-ppp${NC}"
echo -e "• Log service: ${GREEN}journalctl -u accel-ppp -f${NC}"
rm
installer-sstp.sh
