#!/bin/bash

# =============================================
# SSTP VPN Server Installer with Auto-Cleanup
# Version: 2.1 (Fixed Deadlock Issues)
# =============================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Cleanup previous installation
cleanup() {
    echo -e "${YELLOW}[!] Cleaning up previous installation...${NC}"
    
    # Stop and disable service
    sudo systemctl stop accel-ppp 2>/dev/null
    sudo systemctl disable accel-ppp 2>/dev/null
    
    # Kill all processes
    sudo pkill -9 accel-pppd 2>/dev/null
    
    # Remove files
    sudo rm -rf \
        /usr/src/accel-ppp \
        /etc/accel-ppp.conf \
        /etc/ssl/private/ssl.key \
        /etc/ssl/certs/ssl.crt \
        /etc/systemd/system/accel-ppp.service \
        /var/log/accel-ppp 2>/dev/null
    
    echo -e "${GREEN}[✓] Cleanup complete!${NC}"
}

# Install dependencies
install_deps() {
    echo -e "${YELLOW}[!] Installing dependencies...${NC}"
    sudo apt update -y
    sudo apt install -y \
        build-essential \
        cmake \
        git \
        libpcre3-dev \
        libssl-dev \
        liblua5.1-0-dev \
        libnl-3-dev \
        libnl-genl-3-dev \
        pkg-config \
        iproute2 \
        curl \
        openssl \
        strace \
        gdb
}

# Build and install accel-ppp
install_accel_ppp() {
    echo -e "${YELLOW}[!] Installing accel-ppp...${NC}"
    
    cd /usr/src
    sudo git clone https://github.com/accel-ppp/accel-ppp.git
    cd accel-ppp
    
    # Checkout stable version
    git checkout 1.12.0
    
    mkdir build
    cd build
    cmake -DCMAKE_INSTALL_PREFIX=/usr \
          -DKDIR=/usr/src/linux-headers-$(uname -r) \
          -DCPACK_TYPE=Debian \
          -DRADIUS=FALSE \
          -DBUILD_DRIVER=FALSE \
          -DCMAKE_BUILD_TYPE=Release ..
    
    make -j$(nproc)
    sudo make install
}

# Configure accel-ppp
configure_accel_ppp() {
    echo -e "${YELLOW}[!] Configuring accel-ppp...${NC}"
    
    # Create directories
    sudo mkdir -p /etc/accel-ppp /etc/ppp /var/log/accel-ppp
    
    # Generate SSL certificates
    echo -e "${BLUE}[*] Generating SSL certificates...${NC}"
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/private/ssl.key \
        -out /etc/ssl/certs/ssl.crt \
        -subj "/CN=sstp-server"
    
    # Create minimal config
    sudo bash -c 'cat > /etc/accel-ppp.conf << EOF
[modules]
ppp
sstp
auth-chap

[core]
log-error=/var/log/accel-ppp/error.log
log-debug=/var/log/accel-ppp/debug.log
thread-count=2

[ppp]
verbose=1
min-mtu=1280
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
EOF'
    
    # Create systemd service with fixes
    sudo bash -c 'cat > /etc/systemd/system/accel-ppp.service << EOF
[Unit]
Description=Accel-PPP Server
After=network.target

[Service]
Type=forking
ExecStart=/usr/sbin/accel-pppd -c /etc/accel-ppp.conf -p /run/accel-pppd.pid
PIDFile=/run/accel-pppd.pid
Restart=on-failure
RestartSec=5s
TimeoutStartSec=60s
TimeoutStopSec=30s
LimitNOFILE=65536
Environment="ACCEL_PPP_DEBUG=99"

[Install]
WantedBy=multi-user.target
EOF'
    
    # Fix permissions
    sudo chmod 600 /etc/ssl/private/ssl.key
    sudo chmod 644 /etc/ssl/certs/ssl.crt
    sudo chown -R nobody:nogroup /var/log/accel-ppp
    
    # Enable service
    sudo systemctl daemon-reload
    sudo systemctl enable accel-ppp
}

# Create management UI
create_management_ui() {
    echo -e "${YELLOW}[!] Creating management UI...${NC}"
    
    sudo bash -c 'cat > /usr/local/bin/sstp-ui << EOF
#!/bin/bash

# Colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
NC="\033[0m"

check_status() {
    if systemctl is-active --quiet accel-ppp; then
        echo -e "\${GREEN}● RUNNING\${NC}"
    else
        echo -e "\${RED}● STOPPED\${NC}"
    fi
}

while true; do
    clear
    echo -e "\${BLUE}"
    echo "   ███████ ███████ ████████ ██████ "
    echo "   ██      ██         ██    ██   ██"
    echo "   ███████ █████      ██    ██████ "
    echo "        ██ ██         ██    ██     "
    echo "   ███████ ███████    ██    ██     "
    echo -e "\${NC}"
    echo -e "\${YELLOW}==================================\${NC}"
    echo -e "Status: \$(check_status)"
    echo -e "\${YELLOW}==================================\${NC}"
    echo -e "\${GREEN}1. Create SSTP Account\${NC}"
    echo -e "\${GREEN}2. List All Accounts\${NC}"
    echo -e "\${GREEN}3. Delete Account\${NC}"
    echo -e "\${YELLOW}4. Start/Restart SSTP\${NC}"
    echo -e "\${RED}5. Stop SSTP\${NC}"
    echo -e "\${BLUE}0. Exit\${NC}"
    echo -e "\${YELLOW}==================================\${NC}"
    
    read -p "Select option [0-5]: " choice
    
    case \$choice in
        1)
            read -p "Username: " user
            read -p "Password: " pass
            echo "\$user * \$pass *" | sudo tee -a /etc/ppp/chap-secrets >/dev/null
            sudo systemctl restart accel-ppp
            echo -e "\${GREEN}Account created successfully!\${NC}"
            ;;
        2)
            echo -e "\${YELLOW}Current Accounts:\${NC}"
            sudo cat /etc/ppp/chap-secrets | awk '{print \$1,\$3}'
            ;;
        3)
            read -p "Username to delete: " deluser
            sudo sed -i "/^\$deluser /d" /etc/ppp/chap-secrets
            sudo systemctl restart accel-ppp
            echo -e "\${GREEN}Account deleted successfully!\${NC}"
            ;;
        4)
            sudo systemctl restart accel-ppp
            echo -e "\${YELLOW}Service restarted\${NC}"
            ;;
        5)
            sudo systemctl stop accel-ppp
            echo -e "\${RED}Service stopped\${NC}"
            ;;
        0)
            exit 0
            ;;
        *)
            echo -e "\${RED}Invalid option!\${NC}"
            ;;
    esac
    
    read -p "Press Enter to continue..."
done
EOF'
    
    sudo chmod +x /usr/local/bin/sstp-ui
}

# Main installation
main() {
    echo -e "${BLUE}"
    echo "=========================================="
    echo " SSTP VPN Server Installer with Auto-Cleanup"
    echo "=========================================="
    echo -e "${NC}"
    
    cleanup
    install_deps
    install_accel_ppp
    configure_accel_ppp
    create_management_ui
    
    # Start service
    sudo systemctl start accel-ppp
    
    echo -e "${GREEN}"
    echo "=========================================="
    echo " Installation Complete!"
    echo ""
    echo " To manage your SSTP server:"
    echo ""
    echo "    sudo sstp-ui"
    echo ""
    echo " Default port: 4443 (changed from 443)"
    echo "=========================================="
    echo -e "${NC}"
}

# Run main function
main
