#!/bin/bash

# =============================================
# HOKAGE VPN Menu Update with SSTP/PPTP Support
# Version: 5.5 - Menu Integration Fix
# =============================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Function to update the menu
update_menu() {
    # Backup existing menu
    sudo cp /usr/bin/menu /usr/bin/menu.backup
    
    # Find the menu display section and add new options
    sudo sed -i '/echo -e "$COLOR1│ ${WH}\[${COLOR1}05${WH}\]${NC} ${COLOR1}• ${WH}BACKUP/a\
echo -e "$COLOR1│ ${WH}\[${COLOR1}11${WH}\]${NC} ${COLOR1}• ${WH}SSTP     ${WH}\[${COLOR1}Menu${WH}\]     ${WH}\[${COLOR1}12${WH}\]${NC} ${COLOR1}• ${WH}PPTP     ${WH}\[${COLOR1}Menu${WH}\]$COLOR1 │ $NC"' /usr/bin/menu

    # Add the case statements for new options
    sudo sed -i '/case $opt in/a\
11 | 11) clear ; sstp_management ;;\
12 | 12) clear ; pptp_management ;;' /usr/bin/menu

    # Add the SSTP/PPTP management functions at the end of the file
    sudo tee -a /usr/bin/menu > /dev/null <<'MENU_EOF'

# SSTP Management
sstp_management() {
    while true; do
        clear
        echo -e "$COLOR1╭═══════════════════════════════════════════════════╮${NC}"
        echo -e "$COLOR1│ ${WH}            • SSTP VPN MANAGEMENT •              ${NC} $COLOR1│${NC}"
        echo -e "$COLOR1╰═══════════════════════════════════════════════════╯${NC}"
        echo -e "$COLOR1╭═══════════════════════════════════════════════════╮${NC}"
        echo -e "$COLOR1│ ${WH}[${COLOR1}01${WH}]${NC} ${COLOR1}• ${WH}Create SSTP Account                          $COLOR1│${NC}"
        echo -e "$COLOR1│ ${WH}[${COLOR1}02${WH}]${NC} ${COLOR1}• ${WH}Delete SSTP Account                          $COLOR1│${NC}"
        echo -e "$COLOR1│ ${WH}[${COLOR1}03${WH}]${NC} ${COLOR1}• ${WH}List SSTP Accounts                           $COLOR1│${NC}"
        echo -e "$COLOR1│ ${WH}[${COLOR1}04${WH}]${NC} ${COLOR1}• ${WH}Restart SSTP Service                         $COLOR1│${NC}"
        echo -e "$COLOR1│ ${WH}[${COLOR1}00${WH}]${NC} ${COLOR1}• ${WH}Back to Main Menu                           $COLOR1│${NC}"
        echo -e "$COLOR1╰═══════════════════════════════════════════════════╯${NC}"
        echo -e ""
        echo -ne " ${WH}Select menu ${COLOR1}: ${WH}"; read sstp_opt
        
        case $sstp_opt in
            01 | 1)
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
            02 | 2)
                read -p "Username to delete: " deluser
                sudo sed -i "/^$deluser /d" /etc/ppp/chap-secrets
                sudo systemctl restart accel-ppp
                echo -e "${GREEN}Account deleted!${NC}"
                ;;
            03 | 3)
                echo -e "\n${CYAN}» SSTP ACCOUNTS «${NC}"
                sudo cat /etc/ppp/chap-secrets | awk '{print $1,$3}' | column -t
                ;;
            04 | 4)
                sudo systemctl restart accel-ppp
                echo -e "${GREEN}SSTP service restarted!${NC}"
                ;;
            00 | 0)
                menu
                ;;
            *)
                echo -e "${RED}Invalid option!${NC}"
                ;;
        esac
        echo -e "\nPress Enter to continue..."
        read
    done
}

# PPTP Management
pptp_management() {
    while true; do
        clear
        echo -e "$COLOR1╭═══════════════════════════════════════════════════╮${NC}"
        echo -e "$COLOR1│ ${WH}            • PPTP VPN MANAGEMENT •              ${NC} $COLOR1│${NC}"
        echo -e "$COLOR1╰═══════════════════════════════════════════════════╯${NC}"
        echo -e "$COLOR1╭═══════════════════════════════════════════════════╮${NC}"
        echo -e "$COLOR1│ ${WH}[${COLOR1}01${WH}]${NC} ${COLOR1}• ${WH}Create PPTP Account                           $COLOR1│${NC}"
        echo -e "$COLOR1│ ${WH}[${COLOR1}02${WH}]${NC} ${COLOR1}• ${WH}Delete PPTP Account                           $COLOR1│${NC}"
        echo -e "$COLOR1│ ${WH}[${COLOR1}03${WH}]${NC} ${COLOR1}• ${WH}List PPTP Accounts                            $COLOR1│${NC}"
        echo -e "$COLOR1│ ${WH}[${COLOR1}04${WH}]${NC} ${COLOR1}• ${WH}Restart PPTP Service                          $COLOR1│${NC}"
        echo -e "$COLOR1│ ${WH}[${COLOR1}00${WH}]${NC} ${COLOR1}• ${WH}Back to Main Menu                            $COLOR1│${NC}"
        echo -e "$COLOR1╰═══════════════════════════════════════════════════╯${NC}"
        echo -e ""
        echo -ne " ${WH}Select menu ${COLOR1}: ${WH}"; read pptp_opt
        
        case $pptp_opt in
            01 | 1)
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
            02 | 2)
                read -p "Username to delete: " deluser
                sudo sed -i "/^$deluser /d" /etc/ppp/chap-secrets
                sudo systemctl restart accel-ppp
                echo -e "${GREEN}Account deleted!${NC}"
                ;;
            03 | 3)
                echo -e "\n${CYAN}» PPTP ACCOUNTS «${NC}"
                sudo cat /etc/ppp/chap-secrets | awk '{print $1,$3}' | column -t
                ;;
            04 | 4)
                sudo systemctl restart accel-ppp
                echo -e "${GREEN}PPTP service restarted!${NC}"
                ;;
            00 | 0)
                menu
                ;;
            *)
                echo -e "${RED}Invalid option!${NC}"
                ;;
        esac
        echo -e "\nPress Enter to continue..."
        read
    done
}
MENU_EOF

    echo -e "${GREEN}[✓] Menu updated with SSTP/PPTP options!${NC}"
}

# Main execution
show_banner
update_menu
echo -e "\n${GREEN}Update completed successfully!${NC}"
echo -e "New menu options:"
echo -e "  ${YELLOW}11${NC} - SSTP Management"
echo -e "  ${YELLOW}12${NC} - PPTP Management"
echo -e "\nUse ${YELLOW}menu${NC} to access the updated interface"
