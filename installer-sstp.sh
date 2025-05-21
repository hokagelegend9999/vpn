#!/bin/bash

# =============================================
# SSTP VPN Installer with Beautiful UI
# Version: 3.0 - Fixed EOF + Enhanced UI
# =============================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Cleanup function
cleanup() {
    echo -e "${YELLOW}[!] Membersihkan instalasi lama...${NC}"
    sudo systemctl stop accel-ppp 2>/dev/null
    sudo pkill -9 accel-pppd 2>/dev/null
    sudo rm -rf /usr/src/accel-ppp /etc/accel-ppp.conf /var/log/accel-ppp
    echo -e "${GREEN}[✓] Bersih!${NC}"
}

# Install dependencies
install_deps() {
    echo -e "\n${CYAN}» Memasang dependensi...${NC}"
    sudo apt update -y && sudo apt install -y \
        build-essential cmake git libssl-dev \
        libpcre3-dev liblua5.1-0-dev libnl-3-dev \
        libnl-genl-3-dev pkg-config iproute2 curl openssl
}

# Install accel-ppp
install_accel() {
    echo -e "\n${CYAN}» Menginstall accel-ppp...${NC}"
    cd /usr/src
    sudo git clone https://github.com/accel-ppp/accel-ppp.git
    cd accel-ppp
    git checkout 1.12.0  # Gunakan versi stabil
    mkdir build && cd build
    cmake -DCMAKE_INSTALL_PREFIX=/usr \
          -DRADIUS=FALSE -DBUILD_DRIVER=FALSE ..
    make -j$(nproc) && sudo make install
}

# Configure service
configure_service() {
    echo -e "\n${CYAN}» Mengkonfigurasi service...${NC}"
    
    # Buat direktori log
    sudo mkdir -p /var/log/accel-ppp
    
    # Config file
    sudo tee /etc/accel-ppp.conf > /dev/null <<'ACCEL_EOF'
[modules]
ppp
sstp
auth-chap

[core]
log-error=/var/log/accel-ppp/error.log
log-debug=/var/log/accel-ppp/debug.log

[ppp]
verbose=1
mtu=1400
mru=1400

[sstp]
bind=0.0.0.0:4443
ssl-key=/etc/ssl/private/ssl.key
ssl-cert=/etc/ssl/certs/ssl.crt

[auth-chap]
chap-secrets=/etc/ppp/chap-secrets

[ip-pool]
gw-ip=192.168.30.1
pool-start=192.168.30.10
pool-end=192.168.30.100
ACCEL_EOF

    # Systemd service
    sudo tee /etc/systemd/system/accel-ppp.service > /dev/null <<'SERVICE_EOF'
[Unit]
Description=Accel-PPP Server
After=network.target

[Service]
Type=forking
ExecStart=/usr/sbin/accel-pppd -c /etc/accel-ppp.conf -p /run/accel-pppd.pid
PIDFile=/run/accel-pppd.pid
Restart=on-failure
TimeoutStartSec=60s
Environment="ACCEL_PPP_DEBUG=99"

[Install]
WantedBy=multi-user.target
SERVICE_EOF

    # SSL certificates
    sudo mkdir -p /etc/ssl/{private,certs}
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/private/ssl.key \
        -out /etc/ssl/certs/ssl.crt \
        -subj "/CN=sstp-server"
    sudo chmod 600 /etc/ssl/private/ssl.key
}

# Create beautiful UI
create_ui() {
    echo -e "\n${CYAN}» Membuat antarmuka manajemen...${NC}"
    
    sudo tee /usr/local/bin/sstp-ui > /dev/null <<'UI_EOF'
#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

check_status() {
    if systemctl is-active --quiet accel-ppp; then
        echo -e "${GREEN}● AKTIF${NC}"
    else
        echo -e "${RED}● NON-AKTIF${NC}"
    fi
}

show_header() {
    clear
    echo -e "${PURPLE}"
    echo "   _____ _____ _____ _____   ____  ____  ____  ____  "
    echo "  / ___// ___// ___// ___/  / __ \/ __ \/ __ \/ __ \ "
    echo "  \__ \/ __ \/ __ \/ __ \  / /_/ / /_/ / /_/ / /_/ / "
    echo " ___/ / /_/ / /_/ / /_/ /  \__, /\____/\____/ .___/  "
    echo "/____/\____/\____/\____/  /____/           /_/       "
    echo -e "${NC}"
    echo -e "${BLUE}» MANAJEMEN SERVER SSTP «${NC}"
    echo -e "Status: $(check_status)"
    echo -e "${YELLOW}$(date '+%A, %d %B %Y %H:%M:%S')${NC}"
    echo -e "${CYAN}==========================================${NC}"
}

while true; do
    show_header
    
    echo -e "${GREEN}"
    echo "1. Buat Akun Baru"
    echo "2. Lihat Semua Akun"
    echo "3. Hapus Akun"
    echo -e "${YELLOW}"
    echo "4. Mulai/Restart SSTP"
    echo "5. Hentikan SSTP"
    echo -e "${RED}"
    echo "0. Keluar"
    echo -e "${CYAN}"
    echo "=========================================="
    echo -e "${NC}"
    
    read -p "Pilih menu [0-5]: " choice
    
    case $choice in
        1)
            read -p "Username: " user
            read -p "Password: " pass
            echo "$user * $pass *" | sudo tee -a /etc/ppp/chap-secrets >/dev/null
            sudo systemctl restart accel-ppp
            echo -e "\n${GREEN}»» BERHASIL ««${NC}"
            echo -e "Server: $(curl -s ifconfig.me)"
            echo -e "Port: 4443"
            echo -e "Username: ${YELLOW}$user${NC}"
            echo -e "Password: ${YELLOW}$pass${NC}"
            ;;
        2)
            echo -e "\n${BLUE}» Daftar Akun «${NC}"
            sudo cat /etc/ppp/chap-secrets | awk '{print $1,$3}' | column -t
            ;;
        3)
            read -p "Username yang akan dihapus: " deluser
            sudo sed -i "/^$deluser /d" /etc/ppp/chap-secrets
            sudo systemctl restart accel-ppp
            echo -e "${GREEN}Akun $deluser dihapus!${NC}"
            ;;
        4)
            sudo systemctl restart accel-ppp
            sleep 2
            echo -e "${YELLOW}Service direstart!${NC}"
            ;;
        5)
            sudo systemctl stop accel-ppp
            echo -e "${RED}Service dihentikan!${NC}"
            ;;
        0)
            echo -e "${BLUE}Sampai jumpa!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Pilihan tidak valid!${NC}"
            ;;
    esac
    
    read -p "Tekan Enter untuk melanjutkan..."
done
UI_EOF

    sudo chmod +x /usr/local/bin/sstp-ui
}

# Main function
main() {
    echo -e "${PURPLE}"
    echo "=========================================="
    echo " SSTP VPN Installer with Beautiful UI"
    echo "=========================================="
    echo -e "${NC}"
    
    cleanup
    install_deps
    install_accel
    configure_service
    create_ui
    
    sudo systemctl daemon-reload
    sudo systemctl enable --now accel-ppp
    
    echo -e "\n${GREEN}"
    echo "=========================================="
    echo " INSTALASI BERHASIL!"
    echo ""
    echo " Untuk mengelola server, jalankan:"
    echo ""
    echo "    ${YELLOW}sudo sstp-ui${GREEN}"
    echo ""
    echo " Port: ${CYAN}4443${GREEN} (bisa diubah di /etc/accel-ppp.conf)"
    echo "=========================================="
    echo -e "${NC}"
}

# Run main
main
