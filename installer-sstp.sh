#!/bin/bash
set -e

# ==============================================
# KONFIGURASI AWAL
# ==============================================

# Warna untuk output
GREEN='\033[1;32m'
BLUE='\033[1;34m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Versi accel-ppp yang diinginkan
ACCEL_PPP_VERSION="1.12.0"

# ==============================================
# FUNGSI UTILITAS
# ==============================================

function show_header() {
    clear
    echo -e "${BLUE}"
    echo " ██████╗ ██████╗ ███████╗██╗  ██╗"
    echo "██╔════╝██╔═══██╗██╔════╝██║  ██║"
    echo "██║     ██║   ██║█████╗  ███████║"
    echo "██║     ██║   ██║██╔══╝  ██╔══██║"
    echo "╚██████╗╚██████╔╝███████╗██║  ██║"
    echo -e "${NC}"
    echo -e "${YELLOW}=== VPN INSTALLER (SSTP/PPTP/L2TP) ===${NC}"
    echo -e "${BLUE}Versi Script: 2.1.0${NC}"
    echo -e "${BLUE}OS Support: Ubuntu 20.04/22.04${NC}"
    echo ""
}

function handle_error() {
    echo -e "\n${RED}[ERROR] $1${NC}"
    echo -e "${YELLOW}[!] Mencoba metode alternatif...${NC}"
    return 1
}

# ==============================================
# INSTALASI ACCEL-PPP (3 METODE)
# ==============================================

function install_accel_ppp() {
    echo -e "${BLUE}[+] Mencoba instalasi accel-ppp...${NC}"
    
    # Metode 1: Dari repository resmi Ubuntu (jika tersedia)
    echo -e "${YELLOW}[-] Mencoba dari repository Ubuntu...${NC}"
    if apt-cache show accel-ppp &> /dev/null; then
        apt-get install -y accel-ppp accel-ppp-tools && return 0
    fi

    # Metode 2: Dari PPA alternatif
    echo -e "${YELLOW}[-] Mencoba dari PPA alternatif...${NC}"
    if ! add-apt-repository -y ppa:accel-ppp/ppa; then
        handle_error "Gagal menambahkan PPA"
    else
        apt-get update && apt-get install -y accel-ppp accel-ppp-tools && return 0
    fi

    # Metode 3: Kompilasi dari source
    echo -e "${YELLOW}[-] Mengkompilasi dari source...${NC}"
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    echo -e "${BLUE}[+] Menginstall dependencies kompilasi...${NC}"
    apt-get install -y git cmake build-essential libssl-dev libpcre3-dev zlib1g-dev
    
    echo -e "${BLUE}[+] Mengunduh source code...${NC}"
    git clone --branch "$ACCEL_PPP_VERSION" https://github.com/accel-ppp/accel-ppp.git || {
        handle_error "Gagal mengunduh source code"
        return 1
    }
    
    cd accel-ppp
    mkdir build
    cd build
    
    echo -e "${BLUE}[+] Proses kompilasi...${NC}"
    cmake -DBUILD_DRIVER=FALSE -DCMAKE_INSTALL_PREFIX=/usr .. && \
    make -j$(nproc) && \
    make install || {
        handle_error "Gagal mengkompilasi"
        return 1
    }
    
    ldconfig
    return 0
}

# ==============================================
# KONFIGURASI VPN
# ==============================================

function configure_vpn() {
    echo -e "${BLUE}[+] Membuat struktur direktori...${NC}"
    mkdir -p /etc/ssl/sstp /var/log/accel-ppp /etc/ppp
    
    echo -e "${BLUE}[+] Membuat sertifikat SSL...${NC}"
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
        -keyout /etc/ssl/sstp/server.key \
        -out /etc/ssl/sstp/server.crt \
        -subj "/CN=vpnsrv-$(hostname)" || {
        handle_error "Gagal membuat sertifikat"
        return 1
    }
    cp /etc/ssl/sstp/server.crt /etc/ssl/sstp/ca.crt
    
    echo -e "${BLUE}[+] Membuat user VPN...${NC}"
    cat <<EOF > /etc/ppp/chap-secrets
# Format: <username> * <password> *
vpnuser * password123 *
EOF
    chmod 600 /etc/ppp/chap-secrets
    
    echo -e "${BLUE}[+] Membuat config accel-ppp...${NC}"
    cat > /etc/accel-ppp.conf <<'EOL'
[modules]
log_file
sstp
pptp
l2tp
chap-secrets
auth_mschap_v2
ippool

[core]
log-error=/var/log/accel-ppp/error.log
thread-count=4

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

[pptp]
port=1723
ip-pool=pptp

[l2tp]
port=1701
ip-pool=l2tp

[ip-pool]
192.168.77.10-192.168.77.250,name=sstp
192.168.78.10-192.168.78.250,name=pptp
192.168.79.10-192.168.79.250,name=l2tp

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
Type=forking
ExecStart=/usr/sbin/accel-pppd -c /etc/accel-ppp.conf -p /var/run/accel-pppd.pid
PIDFile=/var/run/accel-pppd.pid
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOL

    echo -e "${BLUE}[+] Mengaktifkan service...${NC}"
    systemctl daemon-reload
    systemctl enable --now accel-ppp
}

# ==============================================
# MAIN SCRIPT
# ==============================================

show_header

# Verifikasi root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Script harus dijalankan sebagai root!${NC}"
    exit 1
fi

echo -e "${BLUE}[+] Memperbarui paket sistem...${NC}"
apt-get update || echo -e "${YELLOW}[!] Warning: Gagal update package list${NC}"

echo -e "${BLUE}[+] Menginstall dependencies...${NC}"
apt-get install -y software-properties-common wget openssl

# Instalasi accel-ppp
if ! install_accel_ppp; then
    echo -e "${RED}[!] Gagal menginstall accel-ppp${NC}"
    exit 1
fi

# Konfigurasi VPN
configure_vpn

# Selesai
echo -e "\n${GREEN}[✓] INSTALASI BERHASIL${NC}"
echo -e "${YELLOW}========================================${NC}"
echo -e "${BLUE}Informasi Server VPN:${NC}"
echo -e "SSTP Port: ${GREEN}444${NC}"
echo -e "PPTP Port: ${GREEN}1723${NC}"
echo -e "L2TP Port: ${GREEN}1701${NC}"
echo -e "User: ${GREEN}vpnuser${NC} | Pass: ${GREEN}password123${NC}"
echo -e "Sertifikat CA: ${GREEN}/etc/ssl/sstp/ca.crt${NC}"
echo -e "${YELLOW}========================================${NC}"
echo -e "${BLUE}Perintah manajemen:${NC}"
echo -e "Start: ${GREEN}systemctl start accel-ppp${NC}"
echo -e "Stop: ${GREEN}systemctl stop accel-ppp${NC}"
echo -e "Status: ${GREEN}systemctl status accel-ppp${NC}"
echo -e "Log: ${GREEN}journalctl -u accel-ppp -f${NC}"
echo -e "${YELLOW}========================================${NC}"
