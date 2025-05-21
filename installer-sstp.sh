#!/bin/bash

# =============================================
# HOKAGE VPN Installer - Ultimate Ninja Edition
# Version: 5.3 - With SSTP/PPTP Support
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
        libnl-genl-3-dev pkg-config iproute2 curl openssl \
        pptp-linux net-tools
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
pptp
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

[pptp]
bind=0.0.0.0:1723

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
    
    # Initialize chap-secrets file
    sudo touch /etc/ppp/chap-secrets
    sudo chmod 600 /etc/ppp/chap-secrets
    
    echo -e "${GREEN}[✓] Scrolls encrypted!${NC}"
    sleep 2
}

update_menu() {
    show_banner
    echo -e "\n${CYAN}» Updating ninja menu...${NC}"
    
    # Backup existing menu
    sudo cp /usr/bin/menu /usr/bin/menu.backup
    
    # Add SSTP/PPTP options to the menu
    sudo tee -a /usr/bin/menu > /dev/null <<'MENU_EOF'

# SSTP/PPTP Management
sstp_management() {
    echo -e "\n${CYAN}» SSTP MANAGEMENT «${NC}"
    echo "1. Create SSTP Account"
    echo "2. Delete SSTP Account"
    echo "3. List SSTP Accounts"
    echo "4. Restart SSTP Service"
    echo -e "${RED}0. Back to Main Menu${NC}"
    
    read -p "Choose option: " sstp_opt
    case $sstp_opt in
        1)
            read -p "Username: " username
            read -p "Password: " password
            echo "$username * $password *" | sudo tee -a /etc/ppp/chap-secrets >/dev/null
            sudo systemctl restart accel-ppp
            echo -e "${GREEN}Account created!${NC}"
            echo -e "Server: $(curl -s ifconfig.me)"
            echo -e "Port: 4433"
            echo -e "Username: ${YELLOW}$username${NC}"
            echo -e "Password: ${YELLOW}$password${NC}"
            ;;
        2)
            read -p "Username to delete: " deluser
            sudo sed -i "/^$deluser /d" /etc/ppp/chap-secrets
            sudo systemctl restart accel-ppp
            echo -e "${GREEN}Account deleted!${NC}"
            ;;
        3)
            echo -e "\n${CYAN}» SSTP ACCOUNTS «${NC}"
            sudo cat /etc/ppp/chap-secrets | awk '{print $1,$3}' | column -t
            ;;
        4)
            sudo systemctl restart accel-ppp
            echo -e "${GREEN}SSTP service restarted!${NC}"
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}Invalid option!${NC}"
            ;;
    esac
}

pptp_management() {
    echo -e "\n${CYAN}» PPTP MANAGEMENT «${NC}"
    echo "1. Create PPTP Account"
    echo "2. Delete PPTP Account"
    echo "3. List PPTP Accounts"
    echo "4. Restart PPTP Service"
    echo -e "${RED}0. Back to Main Menu${NC}"
    
    read -p "Choose option: " pptp_opt
    case $pptp_opt in
        1)
            read -p "Username: " username
            read -p "Password: " password
            echo "$username * $password *" | sudo tee -a /etc/ppp/chap-secrets >/dev/null
            sudo systemctl restart accel-ppp
            echo -e "${GREEN}Account created!${NC}"
            echo -e "Server: $(curl -s ifconfig.me)"
            echo -e "Port: 1723"
            echo -e "Username: ${YELLOW}$username${NC}"
            echo -e "Password: ${YELLOW}$password${NC}"
            ;;
        2)
            read -p "Username to delete: " deluser
            sudo sed -i "/^$deluser /d" /etc/ppp/chap-secrets
            sudo systemctl restart accel-ppp
            echo -e "${GREEN}Account deleted!${NC}"
            ;;
        3)
            echo -e "\n${CYAN}» PPTP ACCOUNTS «${NC}"
            sudo cat /etc/ppp/chap-secrets | awk '{print $1,$3}' | column -t
            ;;
        4)
            sudo systemctl restart accel-ppp
            echo -e "${GREEN}PPTP service restarted!${NC}"
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}Invalid option!${NC}"
            ;;
    esac
}
MENU_EOF

    # Update main menu options
    sudo sed -i '/LIST MENU/a\
[15] SSTP [Menu] [16] PPTP [Menu]' /usr/bin/menu

    # Add case options for new services
    sudo sed -i '/case \$choi in/a\
        15) sstp_management ;;\
        16) pptp_management ;;' /usr/bin/menu

    echo -e "${GREEN}[✓] Menu updated with SSTP/PPTP options!${NC}"
    sleep 2
}

post_install() {
    show_banner
    echo -e "\n${CYAN}» Finalizing ninja deployment...${NC}"
    
    # Enable IP forwarding
    sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
    sudo sysctl -p

    # Firewall rules
    sudo ufw allow 1723/tcp  # PPTP
    sudo ufw allow 4433/tcp  # SSTP
    
    # Verify service status
    sudo systemctl daemon-reload
    sudo systemctl enable --now accel-ppp
    
    if systemctl is-active --quiet accel-ppp; then
        echo -e "${GREEN}[✓] HOKAGE VPN is active${NC}"
        echo -e "SSTP Port: 4433"
        echo -e "PPTP Port: 1723"
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
    update_menu
    post_install
    
    show_banner
    echo -e "${GREEN}"
    echo "══════════════════════════════"
    echo " NINJA VPN READY FOR DEPLOYMENT"
    echo ""
    echo " New Features Added:"
    echo " - SSTP VPN (port 4433)"
    echo " - PPTP VPN (port 1723)"
    echo ""
    echo " Access via main menu:"
    echo "    ${YELLOW}menu${GREEN}"
    echo ""
    echo " Server IP: ${CYAN}$(curl -s ifconfig.me)${GREEN}"
    echo "══════════════════════════════"
    echo -e "${NC}"
}

main
