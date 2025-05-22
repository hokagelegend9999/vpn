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

# Versi SoftEther yang diinginkan
SOFTETHER_VERSION="4.41-9787"

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
    echo -e "${BLUE}Versi Script: 2.0.0${NC}"
    echo -e "${BLUE}OS Support: Ubuntu 20.04/22.04${NC}"
    echo ""
}

function handle_error() {
    echo -e "\n${RED}[ERROR] $1${NC}"
    echo -e "${YELLOW}[!] Mencoba metode alternatif...${NC}"
    return 1
}

# ==============================================
# INSTALASI SOFTETHER VPN
# ==============================================

function install_softether() {
    echo -e "${BLUE}[+] Menginstall dependencies...${NC}"
    apt-get update
    apt-get install -y build-essential libreadline-dev libssl-dev libncurses-dev zlib1g-dev
    
    echo -e "${BLUE}[+] Mengunduh SoftEther VPN...${NC}"
    wget https://github.com/SoftEtherVPN/SoftEtherVPN_Stable/releases/download/${SOFTETHER_VERSION}/softether-vpnserver-${SOFTETHER_VERSION}-linux-x64-64bit.tar.gz -O /tmp/softether.tar.gz
    
    echo -e "${BLUE}[+] Mengekstrak paket...${NC}"
    tar xzvf /tmp/softether.tar.gz -C /tmp
    cd /tmp/vpnserver
    
    echo -e "${BLUE}[+] Kompilasi...${NC}"
    make
    
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
    echo -e "${BLUE}[+] Membuat konfigurasi dasar...${NC}"
    
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
echo -e "SSTP Port: ${GREEN}443${NC}"
echo -e "OpenVPN Port: ${GREEN}1194${NC}"
echo -e "L2TP/IPsec Port: ${GREEN}1701${NC}"
echo -e "Admin Port: ${GREEN}5555${NC}"
echo -e "User: ${GREEN}vpnuser${NC} | Pass: ${GREEN}password123${NC}"
echo -e "IPsec Pre-Shared Key: ${GREEN}vpnprekey${NC}"
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
