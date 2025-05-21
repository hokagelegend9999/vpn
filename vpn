#!/bin/bash

# Modern Colors
BLUE='\033[0;38;5;27m'
CYAN='\033[0;38;5;45m'
GREEN='\033[0;38;5;46m'
YELLOW='\033[0;38;5;226m'
RED='\033[0;38;5;196m'
PURPLE='\033[0;38;5;165m'
ORANGE='\033[0;38;5;208m'
NC='\033[0m' # No Color

# Text Gradient
gradient() {
    local text=$1
    local length=${#text}
    local output=""
    
    for (( i=0; i<length; i++ )); do
        char=${text:$i:1}
        color_code=$(( 27 + (i * 18 / length) ))
        output+="\033[38;5;${color_code}m${char}"
    done
    
    echo -ne "${output}${NC}"
}

# Check service status
check_service() {
    systemctl is-active accel-ppp &> /dev/null
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}● RUNNING${NC}"
    else
        echo -e "${RED}● STOPPED${NC}"
    fi
}

# Files
CHAP_FILE="/home/sstp/sstp_account"
EXPIRY_FILE="/home/sstp/account_expiry"
LOG_FILE="/var/log/vpn_users.log"

# Header with animation
display_header() {
    clear
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════════╗"
    gradient "                H O K A G E   V P N   M A N A G E R  P R O               "
    echo -e "\n${PURPLE}╚════════════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${BLUE}┌──────────────────────────────┬──────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│ ${CYAN}● SSTP Service${BLUE}             │ $(check_service) ${BLUE}                         │${NC}"
    echo -e "${BLUE}│ ${CYAN}● PPTP Service${BLUE}             │ $(check_service) ${BLUE}                         │${NC}"
    echo -e "${BLUE}└──────────────────────────────┴──────────────────────────────────────┘${NC}"
    echo ""
}

# Calculate expiry date
calculate_expiry() {
    local period=$1
    if [[ $period == *"day"* ]]; then
        days=${period% day*}
        date -d "+${days} days" +"%Y-%m-%d"
    elif [[ $period == *"month"* ]]; then
        months=${period% month*}
        date -d "+${months} months" +"%Y-%m-%d"
    elif [[ $period == *"year"* ]]; then
        years=${period% year*}
        date -d "+${years} years" +"%Y-%m-%d"
    else
        date -d "+1 month" +"%Y-%m-%d" # Default 1 month
    fi
}

# Check if account is expired
check_expiry() {
    local user=$1
    local expiry_date=$(grep "^$user " "$EXPIRY_FILE" | cut -d' ' -f2)
    
    if [ -z "$expiry_date" ]; then
        echo -e "${YELLOW}No expiry set${NC}"
    elif [ $(date -d "$expiry_date" +%s) -lt $(date +%s) ]; then
        echo -e "${RED}EXPIRED ($expiry_date)${NC}"
    else
        echo -e "${GREEN}Active until $expiry_date${NC}"
    fi
}

# Display user registration info
display_user_info() {
    local user=$1
    local pass=$2
    local expiry=$3
    local ip=$(curl -s ifconfig.me)
    local date=$(date +"%Y-%m-%d %H:%M:%S")
    local expiry_date=$(calculate_expiry "$expiry")
    
    # Log user info
    echo "[$date] User created: $user | IP: $ip | Expiry: $expiry_date" >> "$LOG_FILE"
    echo "$user $expiry_date" >> "$EXPIRY_FILE"
    
    display_header
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════════╗"
    echo -e "${GREEN}║                🎉 USER REGISTRATION SUCCESSFUL 🎉                ║"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${CYAN}┌────────────────────────────────────────────────────────────────────┐"
    echo -e "${CYAN}│ ${YELLOW}🔑 ACCOUNT DETAILS:${NC}                                                   │"
    echo -e "${CYAN}│                                                                    │"
    echo -e "${CYAN}│ ${BLUE}Username: ${YELLOW}$user${NC}                                               │"
    echo -e "${CYAN}│ ${BLUE}Password: ${YELLOW}$pass${NC}                                               │"
    echo -e "${CYAN}│ ${BLUE}IP Server: ${YELLOW}$ip${NC}                                                │"
    echo -e "${CYAN}│ ${BLUE}Account Valid Until: ${YELLOW}$expiry_date${NC}                             │"
    echo -e "${CYAN}│                                                                    │"
    echo -e "${CYAN}│ ${BLUE}📅 Created on: ${YELLOW}$date${NC}                                          │"
    echo -e "${CYAN}└────────────────────────────────────────────────────────────────────┘${NC}"
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════════╗"
    echo -e "${PURPLE}║ ${CYAN}📌 CONNECTION INSTRUCTIONS:${NC}                                         ║"
    echo -e "${PURPLE}║                                                                    ║"
    echo -e "${PURPLE}║ ${YELLOW}For SSTP:${NC}                                                         ║"
    echo -e "${PURPLE}║ 1. Add new VPN connection in network settings                      ║"
    echo -e "${PURPLE}║ 2. Choose SSTP protocol                                          ║"
    echo -e "${PURPLE}║ 3. Server address: ${YELLOW}$ip${PURPLE}                                        ║"
    echo -e "${PURPLE}║ 4. Enter your credentials                                        ║"
    echo -e "${PURPLE}║                                                                    ║"
    echo -e "${PURPLE}║ ${YELLOW}For PPTP:${NC}                                                         ║"
    echo -e "${PURPLE}║ 1. Create new PPTP connection                                     ║"
    echo -e "${PURPLE}║ 2. Server address: ${YELLOW}$ip${PURPLE}                                        ║"
    echo -e "${PURPLE}║ 3. Enter your credentials                                        ║"
    echo -e "${PURPLE}║                                                                    ║"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    read -p "$(echo -e "${YELLOW}▶ Press Enter to return to main menu...${NC}")"
}

# Main menu
while true; do
    display_header
    
    echo -e "${CYAN}┌────────────────────────────────────────────────────────────────────┐"
    echo -e "${CYAN}│ ${YELLOW}📋 MAIN MENU:${NC}                                                         │"
    echo -e "${CYAN}│                                                                    │"
    echo -e "${CYAN}│ ${BLUE}1. ${YELLOW}➕ Create new user account${NC}                                     │"
    echo -e "${CYAN}│ ${BLUE}2. ${YELLOW}➖ Delete user account${NC}                                        │"
    echo -e "${CYAN}│ ${BLUE}3. ${YELLOW}👥 View all users${NC}                                            │"
    echo -e "${CYAN}│ ${BLUE}4. ${YELLOW}⏳ Check account expiry${NC}                                       │"
    echo -e "${CYAN}│ ${BLUE}5. ${YELLOW}📊 Service status${NC}                                            │"
    echo -e "${CYAN}│ ${BLUE}6. ${YELLOW}🔄 Restart all services${NC}                                       │"
    echo -e "${CYAN}│ ${BLUE}0. ${YELLOW}🚪 Exit${NC}                                                      │"
    echo -e "${CYAN}└────────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    
    read -p "$(echo -e "${YELLOW}▶ Select option [0-6]: ${NC}")" choice

    case "$choice" in
        1)
            display_header
            echo -e "${CYAN}┌────────────────────────────────────────────────────────────────────┐"
            echo -e "${CYAN}│ ${YELLOW}➕ CREATE NEW USER ACCOUNT${NC}                                     │"
            echo -e "${CYAN}└────────────────────────────────────────────────────────────────────┘${NC}"
            read -p "$(echo -e "${BLUE}▶ Enter username: ${NC}")" user
            read -s -p "$(echo -e "${BLUE}▶ Enter password: ${NC}")" pass
            echo ""
            echo -e "${CYAN}┌────────────────────────────────────────────────────────────────────┐"
            echo -e "${CYAN}│ ${YELLOW}⏳ ACCOUNT EXPIRATION PERIOD${NC}                                  │"
            echo -e "${CYAN}├────────────────────────────────────────────────────────────────────┤"
            echo -e "${CYAN}│ ${BLUE}1. ${YELLOW}7 days${NC}                                              │"
            echo -e "${CYAN}│ ${BLUE}2. ${YELLOW}30 days (1 month)${NC}                                  │"
            echo -e "${CYAN}│ ${BLUE}3. ${YELLOW}90 days (3 months)${NC}                                 │"
            echo -e "${CYAN}│ ${BLUE}4. ${YELLOW}365 days (1 year)${NC}                                  │"
            echo -e "${CYAN}│ ${BLUE}5. ${YELLOW}Custom period${NC}                                      │"
            echo -e "${CYAN}└────────────────────────────────────────────────────────────────────┘${NC}"
            read -p "$(echo -e "${YELLOW}▶ Select expiry period [1-5]: ${NC}")" expiry_choice
            
            case $expiry_choice in
                1) expiry="7 days";;
                2) expiry="30 days";;
                3) expiry="90 days";;
                4) expiry="365 days";;
                5) 
                    read -p "$(echo -e "${YELLOW}▶ Enter custom period (e.g., '14 days', '6 months', '2 years'): ${NC}")" expiry
                    ;;
                *) expiry="30 days";;
            esac
            
            echo -e "\n$user * $pass *" >> "$CHAP_FILE"
            display_user_info "$user" "$pass" "$expiry"
            ;;
        2)
            display_header
            echo -e "${CYAN}┌────────────────────────────────────────────────────────────────────┐"
            echo -e "${CYAN}│ ${YELLOW}➖ DELETE USER ACCOUNT${NC}                                        │"
            echo -e "${CYAN}└────────────────────────────────────────────────────────────────────┘${NC}"
            read -p "$(echo -e "${BLUE}▶ Enter username to delete: ${NC}")" user
            sed -i "/^$user /d" "$CHAP_FILE"
            sed -i "/^$user /d" "$EXPIRY_FILE"
            echo -e "${GREEN}✔ User $user has been deleted${NC}"
            sleep 1
            ;;
        3)
            display_header
            echo -e "${CYAN}┌────────────────────────────────────────────────────────────────────┐"
            echo -e "${CYAN}│ ${YELLOW}👥 LIST OF ALL USERS${NC}                                         │"
            echo -e "${CYAN}├────────────────────────────────────────────────────────────────────┤${NC}"
            printf "${CYAN}│ ${BLUE}%-20s ${YELLOW}%-30s ${BLUE}%-10s${CYAN}│\n${NC}" "USERNAME" "EXPIRATION DATE" "STATUS"
            echo -e "${CYAN}├────────────────────────────────────────────────────────────────────┤${NC}"
            
            while read -r line; do
                user=$(echo "$line" | cut -d' ' -f1)
                expiry_date=$(echo "$line" | cut -d' ' -f2)
                status=""
                
                if [ -z "$expiry_date" ]; then
                    status="${YELLOW}No expiry${NC}"
                elif [ $(date -d "$expiry_date" +%s) -lt $(date +%s) ]; then
                    status="${RED}Expired${NC}"
                else
                    status="${GREEN}Active${NC}"
                fi
                
                printf "${CYAN}│ ${BLUE}%-20s ${YELLOW}%-30s ${BLUE}%-10s${CYAN}│\n${NC}" "$user" "$expiry_date" "$status"
            done < <(paste -d' ' <(cut -d' ' -f1 "$CHAP_FILE") <(awk '{print $2}' "$EXPIRY_FILE"))
            
            echo -e "${CYAN}└────────────────────────────────────────────────────────────────────┘${NC}"
            read -p "$(echo -e "${YELLOW}▶ Press Enter to continue...${NC}")"
            ;;
        4)
            display_header
            echo -e "${CYAN}┌────────────────────────────────────────────────────────────────────┐"
            echo -e "${CYAN}│ ${YELLOW}⏳ CHECK ACCOUNT EXPIRY${NC}                                       │"
            echo -e "${CYAN}└────────────────────────────────────────────────────────────────────┘${NC}"
            read -p "$(echo -e "${BLUE}▶ Enter username to check: ${NC}")" user
            echo ""
            
            if grep -q "^$user " "$CHAP_FILE"; then
                expiry_info=$(grep "^$user " "$EXPIRY_FILE")
                if [ -z "$expiry_info" ]; then
                    echo -e "${YELLOW}No expiry date set for user $user${NC}"
                else
                    expiry_date=$(echo "$expiry_info" | cut -d' ' -f2)
                    if [ $(date -d "$expiry_date" +%s) -lt $(date +%s) ]; then
                        echo -e "${RED}Account $user has EXPIRED on $expiry_date${NC}"
                    else
                        days_left=$(( ($(date -d "$expiry_date" +%s) - $(date +%s) ))
                        days_left=$(( days_left / 86400 ))
                        echo -e "${GREEN}Account $user is ACTIVE until $expiry_date (${days_left} days remaining)${NC}"
                    fi
                fi
            else
                echo -e "${RED}User $user not found${NC}"
            fi
            
            read -p "$(echo -e "${YELLOW}▶ Press Enter to continue...${NC}")"
            ;;
        5)
            display_header
            echo -e "${CYAN}┌────────────────────────────────────────────────────────────────────┐"
            echo -e "${CYAN}│ ${YELLOW}📊 SERVICE STATUS${NC}                                             │"
            echo -e "${CYAN}├────────────────────────────────────────────────────────────────────┤"
            echo -e "${CYAN}│ ${BLUE}● SSTP Service:${NC} $(check_service) ${BLUE}                         │${NC}"
            echo -e "${CYAN}│ ${BLUE}● PPTP Service:${NC} $(check_service) ${BLUE}                         │${NC}"
            echo -e "${CYAN}└────────────────────────────────────────────────────────────────────┘${NC}"
            read -p "$(echo -e "${YELLOW}▶ Press Enter to continue...${NC}")"
            ;;
        6)
            display_header
            echo -e "${CYAN}┌────────────────────────────────────────────────────────────────────┐"
            echo -e "${CYAN}│ ${YELLOW}🔄 RESTARTING SERVICES${NC}                                        │"
            echo -e "${CYAN}└────────────────────────────────────────────────────────────────────┘${NC}"
            echo -e "${YELLOW}▶ Restarting accel-ppp service...${NC}"
            systemctl restart accel-ppp
            sleep 1
            echo -e "${GREEN}✔ All services have been restarted${NC}"
            sleep 1
            ;;
        0)
            display_header
            echo -e "${CYAN}┌────────────────────────────────────────────────────────────────────┐"
            echo -e "${CYAN}│ ${YELLOW}🚪 EXITING HOKAGE VPN MANAGER${NC}                                │"
            echo -e "${CYAN}└────────────────────────────────────────────────────────────────────┘${NC}"
            echo -e "${BLUE}Thank you for using HOKAGE VPN Manager Pro${NC}"
            exit 0
            ;;
        *)
            display_header
            echo -e "${RED}┌────────────────────────────────────────────────────────────────────┐"
            echo -e "${RED}│ ⚠ Invalid option! Please select between 0-6 ⚠                   │"
            echo -e "${RED}└────────────────────────────────────────────────────────────────────┘${NC}"
            sleep 1
            ;;
    esac
done
