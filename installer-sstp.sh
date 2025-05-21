#!/bin/bash

# =============================================
# HOKAGE VPN Master Script
# Version: 5.0 - Ultimate Ninja Edition
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

# ... [bagian fungsi lainnya tetap sama seperti sebelumnya] ...

create_ui() {
    show_banner
    echo -e "\n${CYAN}» Creating Ninja Scroll...${NC}"
    
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
    echo -e "${GREEN}[✓] Ninja scroll prepared!${NC}"
    sleep 2
}

# ... [bagian main dan lainnya tetap sama] ...

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
