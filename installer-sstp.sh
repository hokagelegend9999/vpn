#!/bin/bash

# =============================================
# HOKAGE VPN Installer - Ultimate Ninja Edition
# Version: 5.2 - Complete Ready-to-Use Package
# =============================================

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
    echo " _    ____  _  ______  __________  "
    echo "/ \  /  _ \/ |/ /  _ \/  __/  __/  "
    echo "| |_|| / \||   /| / \|| |  |  \    "
    echo "| | || \_/||   \| |-||| |_//  /_   "
    echo "\_/ \\____/\_|\_\_/ \|\____\____\  "
    echo -e "${NC}"
    echo -e "${BLUE}» NINJA VPN CONTROL PANEL «${NC}"
    echo -e "${YELLOW}$(date '+%A, %d %B %Y %H:%M:%S')${NC}"
    echo -e "${CYAN}══════════════════════════════${NC}"
}

cleanup() {
    show_banner
    echo -e "${YELLOW}[!] Cleaning old installations...${NC}"
    sudo systemctl stop accel-ppp 2>/dev/null
    sudo pkill -9 accel-pppd 2>/dev/null
    sudo rm -rf /usr/src/accel-ppp /etc/accel-ppp.conf /var/log/accel-ppp
    echo -e "${GREEN}[✓] System purified!${NC}"
    sleep 2
}

install_deps() {
    show_banner
    echo -e "\n${CYAN}» Installing ninja tools...${NC}"
    sudo apt update -y && sudo apt install -y \
        build-essential cmake git libssl-dev \
        libpcre3-dev liblua5.1-0-dev libnl-3-dev \
        libnl-genl-3-dev pkg-config iproute2 curl openssl
    echo -e "${GREEN}[✓] Tools ready!${NC}"
    sleep 2
}

install_accel() {
    show_banner
    echo -e "\n${CYAN}» Compiling shadow techniques...${NC}"
    cd /usr/src
    sudo git clone https://github.com/accel-ppp/accel-ppp.git
    cd accel-ppp
    git checkout 1.12.0
    mkdir build && cd build
    cmake -DCMAKE_INSTALL_PREFIX=/usr \
          -DRADIUS=FALSE -DBUILD_DRIVER=FALSE ..
    make -j$(nproc) && sudo make install
    echo -e "${GREEN}[✓] Techniques mastered!${NC}"
    sleep 2
}

configure_service() {
    show_banner
    echo -e "\n${CYAN}» Configuring ninja scrolls...${NC}"
    
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
    
    echo -e "${GREEN}[✓] Scrolls encrypted!${NC}"
    sleep 2
}

create_ui() {
    show_banner
    echo -e "\n${CYAN}» Creating ninja interface...${NC}"
    
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
    echo " _    ____  _  ______  __________  "
    echo "/ \  /  _ \/ |/ /  _ \/  __/  __/  "
    echo "| |_|| / \||   /| / \|| |  |  \    "
    echo "| | || \_/||   \| |-||| |_//  /_   "
    echo "\_/ \\____/\_|\_\_/ \|\____\____\  "
    echo -e "${NC}"
    echo -e "${BLUE}» NINJA VPN CONTROL PANEL «${NC}"
    echo -e "Status: $([ -f /run/accel-pppd.pid ] && echo -e "${GREEN}● ACTIVE${NC}" || echo -e "${RED}● INACTIVE${NC}")"
    echo -e "${YELLOW}$(date '+%A, %d %B %Y %H:%M:%S')${NC}"
    echo -e "${CYAN}══════════════════════════════${NC}"
}

while true; do
    show_banner
    
    echo -e "${GREEN}"
    echo "1. Create New Shadow Warrior"
    echo "2. List All Warriors"
    echo "3. Remove Warrior"
    echo -e "${YELLOW}"
    echo "4. Activate/Recharge Technique"
    echo "5. Deactivate Technique"
    echo -e "${BLUE}"
    echo "6. View Battle Logs"
    echo -e "${RED}"
    echo "0. Exit Shadow Realm"
    echo -e "${CYAN}"
    echo "══════════════════════════════"
    echo -e "${NC}"
    
    read -p "Select jutsu [0-6]: " choice
    
    case $choice in
        1)
            read -p "Warrior Name: " user
            read -p "Secret Code: " pass
            echo "$user * $pass *" | sudo tee -a /etc/ppp/chap-secrets >/dev/null
            sudo systemctl restart accel-ppp
            echo -e "\n${GREEN}»» WARRIOR INITIATED ««${NC}"
            echo -e "Fortress: $(curl -s ifconfig.me)"
            echo -e "Gate: 4433"
            echo -e "Name: ${YELLOW}$user${NC}"
            echo -e "Code: ${YELLOW}$pass${NC}"
            ;;
        2)
            echo -e "\n${BLUE}» SHADOW WARRIOR ROSTER «${NC}"
            sudo cat /etc/ppp/chap-secrets | awk '{print $1,$3}' | column -t
            ;;
        3)
            read -p "Warrior to eliminate: " deluser
            sudo sed -i "/^$deluser /d" /etc/ppp/chap-secrets
            sudo systemctl restart accel-ppp
            echo -e "${GREEN}Warrior $deluser vanished!${NC}"
            ;;
        4)
            sudo systemctl restart accel-ppp
            sleep 2
            echo -e "${YELLOW}Ninja technique recharged!${NC}"
            ;;
        5)
            sudo systemctl stop accel-ppp
            echo -e "${RED}Technique suspended...${NC}"
            ;;
        6)
            echo -e "\n${BLUE}» BATTLE CHRONICLES «${NC}"
            sudo tail -20 /var/log/accel-ppp/error.log | sed 's/error/Ninja Alert/g'
            ;;
        0)
            echo -e "${BLUE}Vanishing into the mist...${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid jutsu!${NC}"
            ;;
    esac
    
    read -p "Press Enter to continue..."
done
UI_EOF

    sudo chmod +x /usr/local/bin/hokage
    echo -e "${GREEN}[✓] Ninja interface ready!${NC}"
    sleep 2
}

post_install() {
    show_banner
    echo -e "\n${CYAN}» Finalizing ninja deployment...${NC}"
    
    # Backup existing cron
    sudo crontab -l > ~/cron_backup.txt 2>/dev/null
    echo -e "${YELLOW}[!] Cron backup saved to ~/cron_backup.txt${NC}"
    
    # Ensure tendang cron job exists
    if ! crontab -l | grep -q "/usr/bin/tendang"; then
        echo -e "${YELLOW}[!] Restoring tendang technique...${NC}"
        (crontab -l 2>/dev/null; echo "*/5 * * * * /usr/bin/tendang") | crontab -
    fi
    
    # Verify service status
    if systemctl is-active --quiet accel-ppp; then
        echo -e "${GREEN}[✓] HOKAGE VPN is active${NC}"
    else
        echo -e "${RED}[!] VPN service not running!${NC}"
        echo -e "${YELLOW}Trying to start...${NC}"
        sudo systemctl start accel-ppp
    fi
    
    sleep 2
}

main() {
    show_banner
    echo -e "${PURPLE}"
    echo "══════════════════════════════"
    echo " HOKAGE VPN NINJA INSTALLATION"
    echo "══════════════════════════════"
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
    echo "══════════════════════════════"
    echo " NINJA VPN READY FOR DEPLOYMENT"
    echo ""
    echo " To access the shadow panel:"
    echo ""
    echo "    ${YELLOW}sudo hokage${GREEN}"
    echo ""
    echo " Compatible with:"
    echo " - Your tendang technique"
    echo " - HOKAGE VPN (port 4433)"
    echo ""
    echo " Fortress: ${CYAN}$(curl -s ifconfig.me)${GREEN}"
    echo " Secret Gate: ${CYAN}4433${GREEN}"
    echo "══════════════════════════════"
    echo -e "${NC}"
}

main
