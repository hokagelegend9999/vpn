#!/bin/bash

# =============================================
# HOKAGE VPN Installer (Kompatibel dengan tendang)
# Version: 4.0 - Ultimate Compatibility
# =============================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

show_banner() {
    clear
    echo -e "${PURPLE}"
    echo "  _    _  ___  _   _  ___   _____ "
    echo " | |  | |/ _ \| | | |/ _ \ / ____|"
    echo " | |__| | | | | | | | | | | |  __ "
    echo " |  __  | | | | | | | | | | | |_ |"
    echo " | |  | | |_| | |_| | |_| | |__| |"
    echo " |_|  |_|\___/ \___/ \___/ \_____|"
    echo -e "${NC}"
    echo -e "${BLUE}» MANAJEMEN SERVER VPN NINJA «${NC}"
    echo -e "${YELLOW}$(date '+%A, %d %B %Y %H:%M:%S')${NC}"
    echo -e "${CYAN}==========================================${NC}"
}

cleanup() {
    show_banner
    echo -e "${YELLOW}[!] Membersihkan instalasi lama...${NC}"
    sudo systemctl stop accel-ppp 2>/dev/null
    sudo pkill -9 accel-pppd 2>/dev/null
    sudo rm -rf /usr/src/accel-ppp /etc/accel-ppp.conf /var/log/accel-ppp
    echo -e "${GREEN}[✓] Sistem bersih!${NC}"
    sleep 2
}

install_deps() {
    show_banner
    echo -e "\n${CYAN}» Memasang senjata ninja...${NC}"
    sudo apt update -y && sudo apt install -y \
        build-essential cmake git libssl-dev \
        libpcre3-dev liblua5.1-0-dev libnl-3-dev \
        libnl-genl-3-dev pkg-config iproute2 curl openssl
    echo -e "${GREEN}[✓] Senjata siap digunakan!${NC}"
    sleep 2
}

install_accel() {
    show_banner
    echo -e "\n${CYAN}» Menginstall teknik HOKAGE...${NC}"
    cd /usr/src
    sudo git clone https://github.com/accel-ppp/accel-ppp.git
    cd accel-ppp
    git checkout 1.12.0
    mkdir build && cd build
    cmake -DCMAKE_INSTALL_PREFIX=/usr \
          -DRADIUS=FALSE -DBUILD_DRIVER=FALSE ..
    make -j$(nproc) && sudo make install
    echo -e "${GREEN}[✓] Teknik HOKAGE terpasang!${NC}"
    sleep 2
}

configure_service() {
    show_banner
    echo -e "\n${CYAN}» Menyiapkan gulungan ninja...${NC}"
    
    sudo mkdir -p /var/log/accel-ppp
    
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
bind=0.0.0.0:4433
ssl-key=/etc/ssl/private/ssl.key
ssl-cert=/etc/ssl/certs/ssl.crt

[auth-chap]
chap-secrets=/etc/ppp/chap-secrets

[ip-pool]
gw-ip=192.168.90.1
pool-start=192.168.90.10
pool-end=192.168.90.100
ACCEL_EOF

    sudo tee /etc/systemd/system/accel-ppp.service > /dev/null <<'SERVICE_EOF'
[Unit]
Description=HOKAGE VPN Server
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

    sudo mkdir -p /etc/ssl/{private,certs}
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/private/ssl.key \
        -out /etc/ssl/certs/ssl.crt \
        -subj "/CN=hokage-server"
    sudo chmod 600 /etc/ssl/private/ssl.key
    
    echo -e "${GREEN}[✓] Gulungan ninja siap!${NC}"
    sleep 2
}

create_ui() {
    show_banner
    echo -e "\n${CYAN}» Membuat segel ninja...${NC}"
    
    sudo tee /usr/local/bin/hokage > /dev/null <<'UI_EOF'
#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

show_banner() {
    clear
    echo -e "${PURPLE}"
    echo "  _    _  ___  _   _  ___   _____ "
    echo " | |  | |/ _ \| | | |/ _ \ / ____|"
    echo " | |__| | | | | | | | | | | |  __ "
    echo " |  __  | | | | | | | | | | | |_ |"
    echo " | |  | | |_| | |_| | |_| | |__| |"
    echo " |_|  |_|\___/ \___/ \___/ \_____|"
    echo -e "${NC}"
    echo -e "${BLUE}» MANAJEMEN SERVER VPN NINJA «${NC}"
    echo -e "Status: $([ -f /run/accel-pppd.pid ] && echo -e "${GREEN}● AKTIF${NC}" || echo -e "${RED}● NON-AKTIF${NC}")"
    echo -e "${YELLOW}$(date '+%A, %d %B %Y %H:%M:%S')${NC}"
    echo -e "${CYAN}==========================================${NC}"
}

while true; do
    show_banner
    
    echo -e "${GREEN}"
    echo "1. Buat Pasukan Baru"
    echo "2. Lihat Semua Pasukan"
    echo "3. Hapus Pasukan"
    echo -e "${YELLOW}"
    echo "4. Aktifkan/Jiakan Kembali"
    echo "5. Nonaktifkan Sementara"
    echo -e "${BLUE}"
    echo "6. Periksa Log Pertempuran"
    echo -e "${RED}"
    echo "0. Keluar dari Medan Perang"
    echo -e "${CYAN}"
    echo "=========================================="
    echo -e "${NC}"
    
    read -p "Pilih jurus [0-6]: " choice
    
    case $choice in
        1)
            read -p "Nama Pasukan: " user
            read -p "Kode Rahasia: " pass
            echo "$user * $pass *" | sudo tee -a /etc/ppp/chap-secrets >/dev/null
            sudo systemctl restart accel-ppp
            echo -e "\n${GREEN}»» PASUKAN DIBERDAYAKAN ««${NC}"
            echo -e "Markas Besar: $(curl -s ifconfig.me)"
            echo -e "Gerbang: 4433"
            echo -e "Nama Pasukan: ${YELLOW}$user${NC}"
            echo -e "Kode Rahasia: ${YELLOW}$pass${NC}"
            ;;
        2)
            echo -e "\n${BLUE}» DAFTAR PASUKAN «${NC}"
            sudo cat /etc/ppp/chap-secrets | awk '{print $1,$3}' | column -t
            ;;
        3)
            read -p "Nama Pasukan yang akan dibubarkan: " deluser
            sudo sed -i "/^$deluser /d" /etc/ppp/chap-secrets
            sudo systemctl restart accel-ppp
            echo -e "${GREEN}Pasukan $deluser dibubarkan!${NC}"
            ;;
        4)
            sudo systemctl restart accel-ppp
            sleep 2
            echo -e "${YELLOW}Kekuatan ninja dijiakan kembali!${NC}"
            ;;
        5)
            sudo systemctl stop accel-ppp
            echo -e "${RED}Ninja bersembunyi...${NC}"
            ;;
        6)
            echo -e "\n${BLUE}» CATATAN PERTEMPURAN «${NC}"
            sudo tail -20 /var/log/accel-ppp/error.log
            ;;
        0)
            echo -e "${BLUE}Ninja menghilang dalam asap...${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Jurus tidak dikenal!${NC}"
            ;;
    esac
    
    read -p "Tekan Enter untuk melanjutkan..."
done
UI_EOF

    sudo chmod +x /usr/local/bin/hokage
    echo -e "${GREEN}[✓] Segel ninja siap digunakan!${NC}"
    sleep 2
}

post_install() {
    show_banner
    echo -e "\n${CYAN}» Memeriksa kompatibilitas dengan tendang...${NC}"
    
    # Backup cron yang ada
    sudo crontab -l > ~/cron_backup.txt 2>/dev/null
    
    # Pastikan cron job tendang tetap ada
    if ! crontab -l | grep -q "/usr/bin/tendang"; then
        echo -e "${YELLOW}[!] Memulihkan jurus tendang...${NC}"
        (crontab -l 2>/dev/null; echo "*/5 * * * * /usr/bin/tendang") | crontab -
    fi
    
    echo -e "${GREEN}[✓] Jurus tendang tetap aktif setiap 5 menit${NC}"
    sleep 2
}

main() {
    show_banner
    echo -e "${PURPLE}"
    echo "=========================================="
    echo " INSTALASI TEKNIK HOKAGE VPN DIMULAI"
    echo "=========================================="
    echo -e "${NC}"
    sleep 2
    
    cleanup
    install_deps
    install_accel
    configure_service
    create_ui
    post_install
    
    sudo systemctl daemon-reload
    sudo systemctl enable --now accel-ppp
    
    show_banner
    echo -e "${GREEN}"
    echo "=========================================="
    echo " TEKNIK HOKAGE VPN SIAP DIGUNAKAN!"
    echo ""
    echo " Untuk mengaktifkan antarmuka ninja:"
    echo ""
    echo "    ${YELLOW}sudo hokage${GREEN}"
    echo ""
    echo " Fitur yang tetap bekerja:"
    echo " - Jurus tendang Anda (/usr/bin/tendang)"
    echo " - VPN HOKAGE (port 4433)"
    echo ""
    echo " Markas Besar: ${CYAN}$(curl -s ifconfig.me)${GREEN}"
    echo " Gerbang Ninja: ${CYAN}4433${GREEN}"
    echo "=========================================="
    echo -e "${NC}"
}

main
