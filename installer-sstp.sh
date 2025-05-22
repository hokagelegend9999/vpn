#!/bin/bash
set -e

# Fungsi untuk menangani error
function handle_error() {
    echo -e "\033[1;31m[ERROR] $1\033[0m"
    echo -e "\033[1;33m[!] Mencoba metode alternatif...\033[0m"
    
    # Fallback: Kompilasi dari source
    apt-get install -y git cmake build-essential libssl-dev libpcre3-dev || {
        echo -e "\033[1;31m[ERROR] Gagal install dependencies untuk kompilasi\033[0m"
        exit 1
    }
    
    echo -e "\033[1;36m[+] Mengunduh source code accel-ppp...\033[0m"
    git clone https://github.com/accel-ppp/accel-ppp.git /tmp/accel-ppp || {
        echo -e "\033[1;31m[ERROR] Gagal mengunduh source code\033[0m"
        exit 1
    }
    
    cd /tmp/accel-ppp
    mkdir build
    cd build
    
    echo -e "\033[1;36m[+] Mengkompilasi accel-ppp...\033[0m"
    cmake -DBUILD_DRIVER=FALSE .. && make && make install || {
        echo -e "\033[1;31m[ERROR] Gagal mengkompilasi accel-ppp\033[0m"
        exit 1
    }
    
    ldconfig
    return 0
}

# Warna untuk output
GREEN='\033[1;32m'
BLUE='\033[1;34m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}[+] Memperbarui sistem...${NC}"
apt-get update || {
    echo -e "${YELLOW}[!] Warning: Gagal update package list, melanjutkan dengan cache yang ada...${NC}"
}

echo -e "${BLUE}[+] Menginstall dependencies dasar...${NC}"
apt-get install -y software-properties-common wget openssl || handle_error "Gagal install dependencies dasar"

echo -e "${BLUE}[+] Mencoba menambahkan repository alternatif...${NC}"
add-apt-repository -y ppa:accel-ppp/ppa || handle_error "Gagal menambahkan repository alternatif"

echo -e "${BLUE}[+] Menginstall accel-ppp...${NC}"
apt-get update && apt-get install -y accel-ppp accel-ppp-tools || handle_error "Gagal install accel-ppp dari repository"

echo -e "${GREEN}[✓] accel-ppp berhasil diinstall${NC}"

# Konfigurasi lanjutan
echo -e "${BLUE}[+] Membuat struktur direktori...${NC}"
mkdir -p /etc/ssl/sstp /var/log/accel-ppp /etc/ppp

echo -e "${BLUE}[+] Membuat sertifikat self-signed...${NC}"
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout /etc/ssl/sstp/server.key \
    -out /etc/ssl/sstp/server.crt \
    -subj "/CN=sstp-server" || handle_error "Gagal membuat sertifikat SSL"

cp /etc/ssl/sstp/server.crt /etc/ssl/sstp/ca.crt

echo -e "${BLUE}[+] Membuat konfigurasi pengguna...${NC}"
cat <<EOF > /etc/ppp/chap-secrets
# Format: username * password *
vpnuser * vpnpassword *
admin * adminpassword *
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
192.168.77.10-192.168.77.200,name=sstp

[dns]
dns1=8.8.8.8
dns2=8.8.4.4

[log]
log-file=/var/log/accel-ppp/accel.log
level=3
color=1
EOL

echo -e "${BLUE}[+] Membuat systemd service...${NC}"
cat > /etc/systemd/system/accel-ppp.service <<'EOL'
[Unit]
Description=Accel-PPP VPN Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/sbin/accel-pppd -c /etc/accel-ppp.conf
Restart=always
RestartSec=5
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOL

echo -e "${BLUE}[+] Memulai layanan...${NC}"
systemctl daemon-reload
systemctl enable --now accel-ppp

echo -e "${GREEN}[✓] Instalasi berhasil diselesaikan!${NC}"
echo -e "\n${YELLOW}=== Informasi Server VPN ===${NC}"
echo -e "Port SSTP: ${GREEN}444${NC}"
echo -e "IP Pool: ${GREEN}192.168.77.10-192.168.77.200${NC}"
echo -e "Contoh Pengguna:"
echo -e "  - Username: ${GREEN}vpnuser${NC} Password: ${GREEN}vpnpassword${NC}"
echo -e "  - Username: ${GREEN}admin${NC} Password: ${GREEN}adminpassword${NC}"
echo -e "\n${YELLOW}=== Perintah Manajemen ===${NC}"
echo -e "Start service: ${GREEN}systemctl start accel-ppp${NC}"
echo -e "Stop service: ${GREEN}systemctl stop accel-ppp${NC}"
echo -e "Status service: ${GREEN}systemctl status accel-ppp${NC}"
echo -e "Lihat log: ${GREEN}journalctl -u accel-ppp -f${NC}"
echo -e "\n${YELLOW}Catatan:${NC}"
echo -e "1. Gunakan file ${GREEN}/etc/ssl/sstp/ca.crt${NC} untuk autentikasi klien"
echo -e "2. Tambahkan pengguna baru di ${GREEN}/etc/ppp/chap-secrets${NC}"
echo -e "3. Restart service setelah modifikasi konfigurasi"
