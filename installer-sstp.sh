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

# Versi SoftEther terbaru
SOFTETHER_VERSION="4.44-9807-rtm"
DOWNLOAD_URL="https://github.com/SoftEtherVPN/SoftEtherVPN_Stable/releases/download/v4.44-9807-rtm/softether-vpnserver-v4.44-9807-rtm-2025.04.16-linux-x64-64bit.tar.gz"
ALTERNATE_URL="http://github.com/SoftEtherVPN/SoftEtherVPN_Stable/releases/download/v4.44-9807-rtm/softether-vpnserver-v4.44-9807-rtm-2025.04.16-linux-x64-64bit.tar.gz"

# Verifikasi arsitektur
ARCH=$(uname -m)
if [ "$ARCH" != "x86_64" ]; then
    echo -e "${RED}[ERROR] Script ini hanya untuk sistem x86_64${NC}"
    echo -e "${YELLOW}Arsitektur sistem Anda: $ARCH${NC}"
    exit 1
fi

# ==============================================
# FUNGSI UTILITAS
# ==============================================

function show_header() {
    clear
    echo -e "${BLUE}"
    echo "  _____       _   _   _      _   _ "
    echo " / ____|     | | | | | |    | | | |"
    echo "| (___   ___ | |_| |_| | ___| |_| |"
    echo " \___ \ / _ \| __| __| |/ _ \ __| |"
    echo " ____) | (_) | |_| |_| |  __/ |_| |"
    echo "|_____/ \___/ \__|\__|_|\___|\__|_|"
    echo -e "${NC}"
    echo -e "${YELLOW}=== SOFTETHER VPN INSTALLER ===${NC}"
    echo -e "${BLUE}Versi Script: 2.2.0${NC}"
    echo -e "${BLUE}Versi SoftEther: ${SOFTETHER_VERSION}${NC}"
    echo -e "${BLUE}OS Support: Linux x86_64 (Ubuntu/Debian)${NC}"
    echo -e "${BLUE}Tanggal Rilis: 2025-04-16${NC}"
    echo ""
}

function handle_error() {
    echo -e "\n${RED}[ERROR] $1${NC}"
    echo -e "${YELLOW}[!] Mencoba metode alternatif...${NC}"
    return 1
}

# ==============================================
# INSTALASI SOFTETHER VPN (VERSI TERBARU)
# ==============================================

function install_softether() {
    echo -e "${BLUE}[+] Menginstall dependencies...${NC}"
    apt-get update
    apt-get install -y build-essential libreadline-dev libssl-dev libncurses-dev zlib1g-dev wget
    
    echo -e "${BLUE}[+] Mengunduh SoftEther VPN ${SOFTETHER_VERSION}...${NC}"
    
    # Coba download dari URL utama (HTTPS)
    echo -e "${YELLOW}[-] Mencoba dari URL utama (HTTPS)...${NC}"
    if wget --tries=3 --timeout=30 -O /tmp/softether.tar.gz "$DOWNLOAD_URL"; then
        echo -e "${GREEN}[+] Berhasil mengunduh${NC}"
    else
        echo -e "${RED}[!] Gagal mengunduh dari HTTPS, mencoba HTTP...${NC}"
        # Coba download dari URL alternatif (HTTP)
        if wget --tries=3 --timeout=30 -O /tmp/softether.tar.gz "$ALTERNATE_URL"; then
            echo -e "${GREEN}[+] Berhasil mengunduh dari HTTP${NC}"
        else
            echo -e "${RED}[ERROR] Gagal mengunduh dari semua sumber${NC}"
            echo -e "${YELLOW}[!] Silakan unduh manual dari:${NC}"
            echo -e "${BLUE}https://github.com/SoftEtherVPN/SoftEtherVPN_Stable/releases/tag/v4.44-9807-rtm${NC}"
            echo -e "${YELLOW}dan simpan sebagai /tmp/softether.tar.gz lalu jalankan script lagi${NC}"
            exit 1
        fi
    fi

    echo -e "${BLUE}[+] Mengekstrak paket...${NC}"
    tar xzvf /tmp/softether.tar.gz -C /tmp
    cd /tmp/vpnserver
    
    echo -e "${BLUE}[+] Kompilasi...${NC}"
    # Bersihkan file objek sebelumnya
    find . -type f -name "*.o" -exec rm -f {} \;
    make clean
    
    # Kompilasi untuk x86_64
    make -j$(nproc)
    
    echo -e "${BLUE}[+] Menginstall ke /usr/local/vpnserver...${NC}"
    mkdir -p /usr/local/vpnserver
    cp * /usr/local/vpnserver
    chmod 600 /usr/local/vpnserver/*
    chmod 700 /usr/local/vpnserver/vpnserver
    chmod 700 /usr/local/vpnserver/vpncmd
    
    echo -e "${BLUE}[+] Membuat systemd service...${NC}"
    cat > /etc/systemd/system/vpnserver.service <<'EOL'
[Unit]
Description=SoftEther VPN Server
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/vpnserver/vpnserver start
ExecStop=/usr/local/vpnserver/vpnserver stop
Restart=always
WorkingDirectory=/usr/local/vpnserver

[Install]
WantedBy=multi-user.target
EOL

    echo -e "${BLUE}[+] Mengaktifkan service...${NC}"
    systemctl daemon-reload
    systemctl enable vpnserver
    systemctl start vpnserver
}

# ==============================================
# KONFIGURASI DASAR SOFTETHER
# ==============================================

function configure_softether() {
    echo -e "${BLUE}[+] Membuat konfigurasi dasar (tunggu 10 detik)...${NC}"
    
    # Tunggu hingga service benar-benar aktif
    sleep 10
    
    # Set password admin
    /usr/local/vpnserver/vpncmd localhost /SERVER /CMD ServerPasswordSet Admin123
    
    # Buat hub default
    /usr/local/vpnserver/vpncmd localhost /SERVER /PASSWORD:Admin123 /CMD HubCreate DEFAULT /PASSWORD:hub123
    
    # Buat user VPN
    /usr/local/vpnserver/vpncmd localhost /SERVER /PASSWORD:Admin123 /HUB:DEFAULT /CMD UserCreate vpnuser /GROUP:none /REALNAME:"VPN User" /NOTE:"Test User"
    /usr/local/vpnserver/vpncmd localhost /SERVER /PASSWORD:Admin123 /HUB:DEFAULT /CMD UserPasswordSet vpnuser /PASSWORD:password123
    
    # Aktifkan L2TP/IPsec
    /usr/local/vpnserver/vpncmd localhost /SERVER /PASSWORD:Admin123 /CMD IPsecEnable /L2TP:yes /L2TPRAW:yes /ETHERIP:no /PSK:vpnprekey /DEFAULTHUB:DEFAULT
    
    # Aktifkan SSTP
    /usr/local/vpnserver/vpncmd localhost /SERVER /PASSWORD:Admin123 /CMD SstpEnable yes
    
    # Aktifkan OpenVPN
    /usr/local/vpnserver/vpncmd localhost /SERVER /PASSWORD:Admin123 /CMD OpenVpnEnable yes /PORTS:1194
    
    # Konfigurasi NAT
    /usr/local/vpnserver/vpncmd localhost /SERVER /PASSWORD:Admin123 /CMD SecureNatEnable DEFAULT
    
    echo -e "${BLUE}[+] Membuka port firewall...${NC}"
    ufw allow 443/tcp
    ufw allow 992/tcp
    ufw allow 1194/tcp
    ufw allow 1194/udp
    ufw allow 5555/tcp
    ufw allow 500/udp
    ufw allow 4500/udp
    ufw allow 1701/udp
    
    # Untuk x86_64 khusus
    ufw allow 22/tcp   # SSH
    ufw --force enable
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

# Install SoftEther
install_softether

# Konfigurasi dasar
configure_softether

# Selesai
echo -e "\n${GREEN}[✓] INSTALASI SOFTETHER VPN BERHASIL${NC}"
echo -e "${YELLOW}========================================${NC}"
echo -e "${BLUE}Informasi Server VPN:${NC}"
echo -e "Versi: ${GREEN}${SOFTETHER_VERSION}${NC}"
echo -e "Arsitektur: ${GREEN}x86_64${NC}"
echo -e "SSTP Port: ${GREEN}443${NC}"
echo -e "OpenVPN Port: ${GREEN}1194${NC}"
echo -e "L2TP/IPsec Port: ${GREEN}1701${NC}"
echo -e "Admin Port: ${GREEN}5555${NC}"
echo -e "User: ${GREEN}vpnuser${NC} | Pass: ${GREEN}password123${NC}"
echo -e "IPsec Pre-Shared Key: ${GREEN}vpnprekey${NC}"
echo -e "Admin Password: ${GREEN}Admin123${NC}"
echo -e "Hub Password: ${GREEN}hub123${NC}"
echo -e "${YELLOW}========================================${NC}"
echo -e "${BLUE}Perintah manajemen:${NC}"
echo -e "Start: ${GREEN}systemctl start vpnserver${NC}"
echo -e "Stop: ${GREEN}systemctl stop vpnserver${NC}"
echo -e "Status: ${GREEN}systemctl status vpnserver${NC}"
echo -e "Log: ${GREEN}journalctl -u vpnserver -f${NC}"
echo -e "${YELLOW}========================================${NC}"
echo -e "${BLUE}Untuk konfigurasi lanjutan:${NC}"
echo -e "Gunakan: ${GREEN}/usr/local/vpnserver/vpncmd${NC}"
echo -e "${YELLOW}========================================${NC}"
