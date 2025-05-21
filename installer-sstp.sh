#!/bin/bash

# ================================================
# VPN ALL-IN-ONE INSTALLER (PPTP + SSTP + OpenVPN)
# Version: 3.0
# Tested on: Ubuntu 20.04/22.04
# ================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check root
if [ "$(id -u)" -ne 0 ]; then
  echo -e "${RED}Error: Script must be run as root${NC}"
  exit 1
fi

# Header
echo -e "${BLUE}"
cat << "EOF"
   ____   _____ _____   _____   _____ _____ 
  / __ \ / ____|  __ \ / ____| / ____|  __ \
 | |  | | (___ | |__) | |  __ | |    | |__) |
 | |  | |\___ \|  ___/| | |_ || |    |  ___/ 
 | |__| |____) | |    | |__| || |____| |     
  \____/|_____/|_|     \_____(_)_____|_|     
EOF
echo -e "${NC}"

# Function to install PPTP
install_pptp() {
  echo -e "\n${YELLOW}[1/3] Installing PPTP VPN...${NC}"
  apt install -y pptpd
  
  # Configure PPTP
  cat > /etc/pptpd.conf << EOL
option /etc/ppp/pptpd-options
logwtmp
localip 192.168.50.1
remoteip 192.168.50.100-200
EOL

  # Configure PPP options
  sed -i 's/#ms-dns 10.0.0.1/ms-dns 8.8.8.8/' /etc/ppp/pptpd-options
  sed -i 's/#ms-dns 10.0.0.2/ms-dns 8.8.4.4/' /etc/ppp/pptpd-options

  # Enable IP forwarding
  sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
  sysctl -p

  # Firewall rules
  iptables -t nat -A POSTROUTING -o $(ip route | grep default | awk '{print $5}') -j MASQUERADE
  iptables-save > /etc/iptables.rules

  # Add sample user
  echo "vpnuser pptpd vpnpassword *" >> /etc/ppp/chap-secrets

  systemctl restart pptpd
  systemctl enable pptpd
}

# Function to install SSTP
install_sstp() {
  echo -e "\n${YELLOW}[2/3] Installing SSTP VPN...${NC}"
  
  # Install dependencies
  apt install -y build-essential cmake libssl-dev libpcre3-dev
  
  # Install accel-ppp
  cd /usr/src
  git clone https://github.com/accel-ppp/accel-ppp.git
  cd accel-ppp
  mkdir build && cd build
  cmake -DCMAKE_INSTALL_PREFIX=/usr -DKDIR=/usr/src/linux-headers-$(uname -r) ..
  make -j$(nproc)
  make install

  # Generate SSL certs
  mkdir -p /etc/ssl/{private,certs}
  openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout /etc/ssl/private/sstp.key \
    -out /etc/ssl/certs/sstp.crt \
    -subj "/CN=sstp-server"

  # Create config
  cat > /etc/accel-ppp.conf << EOL
[modules]
log-file
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
ssl-key=/etc/ssl/private/sstp.key
ssl-cert=/etc/ssl/certs/sstp.crt

[auth-chap]
chap-secrets=/etc/ppp/chap-secrets

[ip-pool]
gw-ip=192.168.60.1
pool-start=192.168.60.100
pool-end=192.168.60.200
EOL

  # Create systemd service
  cat > /etc/systemd/system/accel-ppp.service << EOL
[Unit]
Description=Accel-PPP Server
After=network.target

[Service]
Type=forking
ExecStart=/usr/sbin/accel-pppd -c /etc/accel-ppp.conf
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOL

  systemctl daemon-reload
  systemctl start accel-ppp
  systemctl enable accel-ppp
}

# Function to install OpenVPN
install_openvpn() {
  echo -e "\n${YELLOW}[3/3] Installing OpenVPN...${NC}"
  
  apt install -y openvpn easy-rsa
  
  # Setup CA
  make-cadir ~/openvpn-ca
  cd ~/openvpn-ca
  
  # Configure vars
  sed -i 's/KEY_NAME="EasyRSA"/KEY_NAME="server"/' vars
  sed -i 's/KEY_COUNTRY="US"/KEY_COUNTRY="ID"/' vars
  sed -i 's/KEY_PROVINCE="CA"/KEY_PROVINCE="JAVA"/' vars
  sed -i 's/KEY_CITY="SanFrancisco"/KEY_CITY="Jakarta"/' vars
  sed -i 's/KEY_ORG="Copyleft"/KEY_ORG="MyVPN"/' vars
  sed -i 's/KEY_EMAIL="me@example.com"/KEY_EMAIL="admin@example.com"/' vars
  sed -i 's/KEY_OU="MyOrganizationalUnit"/KEY_OU="IT"/' vars
  
  # Build CA and server certs
  source vars
  ./clean-all
  ./build-ca --batch
  ./build-key-server --batch server
  ./build-dh
  openvpn --genkey --secret keys/ta.key
  
  # Install certs
  cd ~/openvpn-ca/keys
  cp server.crt server.key ca.crt dh2048.pem ta.key /etc/openvpn/
  
  # Configure server
  gunzip -c /usr/share/doc/openvpn/examples/sample-config-files/server.conf.gz > /etc/openvpn/server.conf
  
  # Modify config
  sed -i 's/;push "redirect-gateway def1 bypass-dhcp"/push "redirect-gateway def1 bypass-dhcp"/' /etc/openvpn/server.conf
  sed -i 's/;push "dhcp-option DNS 208.67.222.222"/push "dhcp-option DNS 8.8.8.8"\npush "dhcp-option DNS 8.8.4.4"/' /etc/openvpn/server.conf
  sed -i 's/;user nobody/user nobody/' /etc/openvpn/server.conf
  sed -i 's/;group nogroup/group nogroup/' /etc/openvpn/server.conf
  echo -e "\n# Additional config\nkeepalive 10 120\ncomp-lzo no\npersist-key\npersist-tun" >> /etc/openvpn/server.conf
  
  # Enable IP forwarding
  sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
  sysctl -p
  
  # Firewall rules
  iptables -t nat -A POSTROUTING -o $(ip route | grep default | awk '{print $5}') -j MASQUERADE
  iptables-save > /etc/iptables.rules
  
  systemctl start openvpn@server
  systemctl enable openvpn@server
  
  # Generate client config
  mkdir -p ~/client-configs/files
  cat > ~/client-configs/base.conf << EOL
client
dev tun
proto udp
remote $(curl -s ifconfig.me) 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-CBC
comp-lzo no
verb 3
EOL
}

# Main installation
main() {
  # Update system
  echo -e "${YELLOW}[+] Updating system packages...${NC}"
  apt update -y && apt upgrade -y
  
  # Install all VPN services
  install_pptp
  install_sstp
  install_openvpn
  
  # Final touches
  echo -e "\n${GREEN}[+] Installation complete!${NC}"
  echo -e "\n${BLUE}=== VPN Configuration Summary ===${NC}"
  echo -e "PPTP:"
  echo -e "  Port: 1723/tcp"
  echo -e "  Users: /etc/ppp/chap-secrets"
  echo -e "  Test: sudo pptpd -f"
  
  echo -e "\nSSTP:"
  echo -e "  Port: 4443/tcp"
  echo -e "  Config: /etc/accel-ppp.conf"
  echo -e "  Logs: /var/log/accel-ppp/"
  
  echo -e "\nOpenVPN:"
  echo -e "  Port: 1194/udp"
  echo -e "  Config: /etc/openvpn/server.conf"
  echo -e "  Client config: ~/client-configs/"
  
  echo -e "\n${GREEN}To manage users:"
  echo -e "  PPTP/SSTP: Edit /etc/ppp/chap-secrets"
  echo -e "  OpenVPN: Generate client configs in ~/client-configs/${NC}"
}

# Execute
main
