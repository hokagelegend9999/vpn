#!/bin/bash

# =============================================
# SoftEther VPN Installer for Ubuntu 20.04 LTS
# Version: 4.44 - Using Precompiled Binary
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
    sudo systemctl stop softether-vpnserver 2>/dev/null
    sudo rm -rf /usr/local/vpnserver /etc/systemd/system/softether-vpnserver.service
    echo -e "${GREEN}[✓] Bersih!${NC}"
}

# Install dependencies
install_deps() {
    echo -e "\n${CYAN}» Memasang dependensi...${NC}"
    sudo apt update -y && sudo apt install -y \
        build-essential libreadline-dev libssl-dev \
        libncurses-dev zlib1g-dev iptables
}

# Download and install SoftEther
install_softether() {
    echo -e "\n${CYAN}» Mengunduh SoftEther VPN...${NC}"
    cd /tmp
    wget https://github.com/SoftEtherVPN/SoftEtherVPN_Stable/releases/download/v4.44-9807-rtm/softether-vpnserver-v4.44-9807-rtm-2025.04.16-linux-x64-64bit.tar.gz
    
    echo -e "\n${CYAN}» Mengekstrak paket...${NC}"
    tar xzf softether-vpnserver-*.tar.gz
    cd vpnserver
    
    echo -e "\n${CYAN}» Menginstall...${NC}"
    sudo mkdir -p /usr/local/vpnserver
    sudo cp -a * /usr/local/vpnserver
    sudo chmod 600 /usr/local/vpnserver/*
    sudo chmod 700 /usr/local/vpnserver/vpnserver
    sudo chmod 700 /usr/local/vpnserver/vpncmd
    
    # Create init script
    sudo tee /etc/systemd/system/softether-vpnserver.service > /dev/null <<'SERVICE_EOF'
[Unit]
Description=SoftEther VPN Server
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/vpnserver/vpnserver start
ExecStop=/usr/local/vpnserver/vpnserver stop
Restart=on-failure

[Install]
WantedBy=multi-user.target
SERVICE_EOF
}

# Configure SoftEther
configure_softether() {
    echo -e "\n${CYAN}» Mengkonfigurasi SoftEther...${NC}"
    sudo systemctl daemon-reload
    sudo systemctl enable softether-vpnserver
    
    # Start service
    sudo systemctl start softether-vpnserver
    
    # Basic configuration
    echo -e "\n${YELLOW}» Konfigurasi awal (ikuti petunjuk):${NC}"
    echo -e "1. Tekan Enter untuk skip manajer konfigurasi"
    echo -e "2. Pilih '1' untuk set password server"
    echo -e "3. Masukkan password yang kuat"
    echo -e "4. Konfirmasi password"
    echo -e "5. Tekan Enter untuk keluar"
    
    sudo /usr/local/vpnserver/vpncmd /SERVER localhost /CMD ServerPasswordSet
    
    # Enable SSTP
    sudo /usr/local/vpnserver/vpncmd /SERVER localhost /PASSWORD:yourpassword /CMD SSTPEnable yes
    sudo /usr/local/vpnserver/vpncmd /SERVER localhost /PASSWORD:yourpassword /CMD OpenVpnEnable no
    sudo /usr/local/vpnserver/vpncmd /SERVER localhost /PASSWORD:yourpassword /CMD IPsecEnable no
    
    echo -e "\n${GREEN}[✓] Konfigurasi SSTP selesai!${NC}"
}

# Create management UI
create_ui() {
    echo -e "\n${CYAN}» Membuat antarmuka manajemen...${NC}"
    
    sudo tee /usr/local/bin/vpn-ui > /dev/null <<'UI_EOF'
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
    if systemctl is-active --quiet softether-vpnserver; then
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
    echo -e "${BLUE}» MANAJEMEN SERVER SoftEther VPN «${NC}"
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
    echo "4. Mulai/Restart VPN"
    echo "5. Hentikan VPN"
    echo -e "${BLUE}"
    echo "6. Ganti Password Server"
    echo -e "${RED}"
    echo "0. Keluar"
    echo -e "${CYAN}"
    echo "=========================================="
    echo -e "${NC}"
    
    read -p "Pilih menu [0-6]: " choice
    
    case $choice in
        1)
            read -p "Username: " user
            read -p "Password: " pass
            read -p "Hub (default: DEFAULT): " hub
            hub=${hub:-DEFAULT}
            read -sp "Password Server: " serverpass
            echo
            sudo /usr/local/vpnserver/vpncmd /SERVER localhost /PASSWORD:$serverpass /HUB:$hub /CMD UserCreate $user /GROUP:none /REALNAME:none /NOTE:none
            sudo /usr/local/vpnserver/vpncmd /SERVER localhost /PASSWORD:$serverpass /HUB:$hub /CMD UserPasswordSet $user /PASSWORD:$pass
            echo -e "\n${GREEN}»» BERHASIL ««${NC}"
            echo -e "Server: $(curl -s ifconfig.me)"
            echo -e "Port: 443 (SSTP)"
            echo -e "Username: ${YELLOW}$user${NC}"
            echo -e "Password: ${YELLOW}$pass${NC}"
            echo -e "Hub: ${YELLOW}$hub${NC}"
            ;;
        2)
            read -p "Hub (default: DEFAULT): " hub
            hub=${hub:-DEFAULT}
            read -sp "Password Server: " serverpass
            echo
            echo -e "\n${BLUE}» Daftar Akun «${NC}"
            sudo /usr/local/vpnserver/vpncmd /SERVER localhost /PASSWORD:$serverpass /HUB:$hub /CMD UserList | awk '/User Name|Full Name|Last Login|^$/ {print}'
            ;;
        3)
            read -p "Username yang akan dihapus: " deluser
            read -p "Hub (default: DEFAULT): " hub
            hub=${hub:-DEFAULT}
            read -sp "Password Server: " serverpass
            echo
            sudo /usr/local/vpnserver/vpncmd /SERVER localhost /PASSWORD:$serverpass /HUB:$hub /CMD UserDelete $deluser
            echo -e "${GREEN}Akun $deluser dihapus!${NC}"
            ;;
        4)
            sudo systemctl restart softether-vpnserver
            sleep 2
            echo -e "${YELLOW}Service direstart!${NC}"
            ;;
        5)
            sudo systemctl stop softether-vpnserver
            echo -e "${RED}Service dihentikan!${NC}"
            ;;
        6)
            read -sp "Password Server Lama: " oldpass
            echo
            sudo /usr/local/vpnserver/vpncmd /SERVER localhost /PASSWORD:$oldpass /CMD ServerPasswordSet
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

    sudo chmod +x /usr/local/bin/vpn-ui
}

# Main function
main() {
    echo -e "${PURPLE}"
    echo "=========================================="
    echo " SoftEther VPN Installer for Ubuntu 20.04"
    echo "=========================================="
    echo -e "${NC}"
    
    cleanup
    install_deps
    install_softether
    configure_softether
    create_ui
    
    echo -e "\n${GREEN}"
    echo "=========================================="
    echo " INSTALASI BERHASIL!"
    echo ""
    echo " Untuk mengelola server, jalankan:"
    echo ""
    echo "    ${YELLOW}sudo vpn-ui${GREEN}"
    echo ""
    echo " Port SSTP: ${CYAN}443${GREEN}"
    echo " Port Manajemen: ${CYAN}5555${GREEN}"
    echo ""
    echo " Catatan:"
    echo " - Gunakan password server yang telah Anda buat"
    echo " - Default Hub: DEFAULT"
    echo "=========================================="
    echo -e "${NC}"
}

# Run main
main
