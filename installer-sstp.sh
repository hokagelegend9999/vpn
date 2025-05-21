#!/bin/bash

# SSTP Server Installer with Beautiful UI
# This script will install accel-ppp (SSTP server) and create a user-friendly UI

# Colors for UI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root${NC}"
    exit 1
fi

# Function to install dependencies
install_dependencies() {
    echo -e "${YELLOW}Installing dependencies...${NC}"
    apt update -y
    apt install -y build-essential cmake git libpcre3-dev libssl-dev liblua5.1-0-dev \
    libnl-3-dev libnl-genl-3-dev pkg-config iproute2 curl openssl
}

# Function to install accel-ppp
install_accel_ppp() {
    echo -e "${YELLOW}Installing accel-ppp...${NC}"
    if [ ! -d "/usr/src/accel-ppp" ]; then
        cd /usr/src
        git clone https://github.com/accel-ppp/accel-ppp.git
        cd accel-ppp
        mkdir build && cd build
        cmake -DCMAKE_INSTALL_PREFIX=/usr -DKDIR=/usr/src/linux-headers-$(uname -r) \
        -DCPACK_TYPE=Debian -DRADIUS=FALSE -DBUILD_DRIVER=FALSE ..
        make -j$(nproc)
        make install
    else
        echo -e "${CYAN}accel-ppp already exists, skipping installation.${NC}"
    fi
}

# Function to configure accel-ppp
configure_accel_ppp() {
    echo -e "${YELLOW}Configuring accel-ppp...${NC}"
    mkdir -p /etc/accel-ppp /etc/ppp
    
    # Create SSL certificates
    echo -e "${YELLOW}Creating SSL certificates...${NC}"
    mkdir -p /etc/ssl/private /etc/ssl/certs
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/private/ssl.key \
        -out /etc/ssl/certs/ssl.crt \
        -subj "/CN=sstp-server"
    
    # Create chap-secrets file
    touch /etc/ppp/chap-secrets
    chmod 600 /etc/ppp/chap-secrets
    
    # Create accel-ppp config
    cat <<EOF > /etc/accel-ppp.conf
[modules]
log-file
ppp
sstp
auth-chap
cli

[core]
log-error=/var/log/accel-ppp-error.log
log-info=/var/log/accel-ppp-info.log

[ppp]
verbose=1
min-mtu=1280
mtu=1400
mru=1400
ipv4=require
ipv6=disable

[sstp]
bind=0.0.0.0:443
ssl-key=/etc/ssl/private/ssl.key
ssl-cert=/etc/ssl/certs/ssl.crt

[auth-chap]
chap-secrets=/etc/ppp/chap-secrets

[ip-pool]
gw-ip=192.168.30.1
pool-start=192.168.30.10
pool-end=192.168.30.100
ifname=ppp0

[dns]
dns1=8.8.8.8
dns2=1.1.1.1

[cli]
telnet=127.0.0.1:2000
password=admin
EOF
    
    # Create systemd service
    cat <<EOF > /etc/systemd/system/accel-ppp.service
[Unit]
Description=Accel-PPP Server
After=network.target

[Service]
Type=forking
ExecStart=/usr/sbin/accel-pppd -c /etc/accel-ppp.conf -p /var/run/accel-pppd.pid
ExecReload=/bin/kill -HUP \$MAINPID
PIDFile=/var/run/accel-pppd.pid
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable accel-ppp
}

# Function to create the UI menu
create_ui_menu() {
    echo -e "${YELLOW}Creating sstp-ui command...${NC}"
    cat <<'EOF' > /usr/local/bin/sstp-ui
#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to check SSTP status
check_sstp_status() {
    if systemctl is-active --quiet accel-ppp; then
        echo -e "${GREEN}●${NC}"  # Green dot for active
    else
        echo -e "${RED}●${NC}"  # Red dot for inactive
    fi
}

# Function to display header
display_header() {
    clear
    echo -e "${CYAN}"
    echo "   _____ _____ _____ _____   ____  ____  ____  ____  "
    echo "  / ___// ___// ___// ___/  / __ \/ __ \/ __ \/ __ \ "
    echo "  \__ \/ __ \/ __ \/ __ \  / /_/ / /_/ / /_/ / /_/ / "
    echo " ___/ / /_/ / /_/ / /_/ /  \__, /\____/\____/ .___/  "
    echo "/____/\____/\____/\____/  /____/           /_/       "
    echo -e "${NC}"
    echo -e "${BLUE}SSTP VPN Server Management${NC}"
    echo -e "Status: $(check_sstp_status) SSTP Service"
    echo -e "${YELLOW}$(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo -e "${PURPLE}==========================================${NC}"
}

# Function to create new account
create_account() {
    display_header
    echo -e "${GREEN}» Buat Akun SSTP Baru «${NC}"
    echo -e "${NC}"
    read -p "Username: " user
    read -p "Password: " pass
    
    echo "$user * $pass *" >> /etc/ppp/chap-secrets
    systemctl restart accel-ppp
    
    server_ip=$(curl -s ifconfig.me || curl -s ipinfo.io/ip)
    
    echo -e "${PURPLE}"
    echo "=========================================="
    echo -e "${GREEN}✅ AKUN BERHASIL DIBUAT!${NC}"
    echo -e "${CYAN}"
    echo "  Server IP   : $server_ip"
    echo "  Username    : $user"
    echo "  Password    : $pass"
    echo "  Port        : 443"
    echo "  Protocol    : SSTP (SSL VPN)"
    echo -e "${PURPLE}"
    echo "=========================================="
    echo -e "${YELLOW}"
    echo "💡 Petunjuk Penggunaan:"
    echo "1. Buka VPN SSTP di Windows"
    echo "2. Masukkan IP server"
    echo "3. Gunakan username & password di atas"
    echo "4. Centang 'Allow these protocols'"
    echo "5. Pilih 'Microsoft CHAP Version 2'"
    echo "6. Hubungkan"
    echo -e "${PURPLE}"
    echo "=========================================="
    echo -e "${NC}"
    
    read -p "Tekan Enter untuk kembali ke menu utama..."
}

# Function to view accounts
view_accounts() {
    display_header
    echo -e "${GREEN}» Daftar Akun SSTP «${NC}"
    echo -e "${NC}"
    
    if [ -s /etc/ppp/chap-secrets ]; then
        echo -e "${CYAN}Username\tPassword${NC}"
        echo -e "${PURPLE}--------\t--------${NC}"
        while IFS= read -r line; do
            user=$(echo "$line" | awk '{print $1}')
            pass=$(echo "$line" | awk '{print $3}')
            echo -e "${YELLOW}$user\t\t$pass${NC}"
        done < /etc/ppp/chap-secrets
    else
        echo -e "${RED}Tidak ada akun SSTP yang terdaftar.${NC}"
    fi
    
    echo -e "${PURPLE}"
    echo "=========================================="
    echo -e "${NC}"
    
    read -p "Tekan Enter untuk kembali ke menu utama..."
}

# Function to delete account
delete_account() {
    display_header
    echo -e "${GREEN}» Hapus Akun SSTP «${NC}"
    echo -e "${NC}"
    
    if [ -s /etc/ppp/chap-secrets ]; then
        echo "Akun yang tersedia:"
        echo -e "${CYAN}"
        cat /etc/ppp/chap-secrets | awk '{print $1}'
        echo -e "${NC}"
        
        read -p "Masukkan username yang akan dihapus: " deluser
        
        if grep -q "^$deluser " /etc/ppp/chap-secrets; then
            sed -i "/^$deluser /d" /etc/ppp/chap-secrets
            systemctl restart accel-ppp
            echo -e "${GREEN}✅ Akun $deluser berhasil dihapus.${NC}"
        else
            echo -e "${RED}❌ Username tidak ditemukan.${NC}"
        fi
    else
        echo -e "${RED}Tidak ada akun SSTP yang terdaftar.${NC}"
    fi
    
    echo -e "${PURPLE}"
    echo "=========================================="
    echo -e "${NC}"
    
    read -p "Tekan Enter untuk kembali ke menu utama..."
}

# Function to start/restart SSTP
start_sstp() {
    display_header
    echo -e "${GREEN}» Memulai/Restart SSTP «${NC}"
    
    systemctl restart accel-ppp
    
    if systemctl is-active --quiet accel-ppp; then
        echo -e "${GREEN}✅ SSTP berhasil dijalankan.${NC}"
    else
        echo -e "${RED}❌ Gagal menjalankan SSTP.${NC}"
    fi
    
    echo -e "${PURPLE}"
    echo "=========================================="
    echo -e "${NC}"
    
    read -p "Tekan Enter untuk kembali ke menu utama..."
}

# Function to stop SSTP
stop_sstp() {
    display_header
    echo -e "${GREEN}» Menghentikan SSTP «${NC}"
    
    systemctl stop accel-ppp
    
    if systemctl is-active --quiet accel-ppp; then
        echo -e "${RED}❌ Gagal menghentikan SSTP.${NC}"
    else
        echo -e "${GREEN}✅ SSTP berhasil dihentikan.${NC}"
    fi
    
    echo -e "${PURPLE}"
    echo "=========================================="
    echo -e "${NC}"
    
    read -p "Tekan Enter untuk kembali ke menu utama..."
}

# Main menu function
main_menu() {
    while true; do
        display_header
        
        echo -e "${GREEN}"
        echo "1. Buat Akun SSTP Baru"
        echo "2. Lihat Semua Akun"
        echo "3. Hapus Akun SSTP"
        echo -e "${YELLOW}"
        echo "4. Mulai/Restart SSTP"
        echo "5. Stop SSTP"
        echo -e "${RED}"
        echo "0. Keluar"
        echo -e "${PURPLE}"
        echo "=========================================="
        echo -e "${NC}"
        
        read -p "Pilih menu [0-5]: " menu
        
        case $menu in
            1)
                create_account
                ;;
            2)
                view_accounts
                ;;
            3)
                delete_account
                ;;
            4)
                start_sstp
                ;;
            5)
                stop_sstp
                ;;
            0)
                echo -e "${GREEN}Terima kasih! Sampai jumpa lagi.${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Pilihan tidak valid! Silakan coba lagi.${NC}"
                sleep 2
                ;;
        esac
    done
}

# Start the main menu
main_menu
EOF

    chmod +x /usr/local/bin/sstp-ui
}

# Main installation process
echo -e "${PURPLE}"
echo "=========================================="
echo " SSTP VPN Server Installer with Beautiful UI"
echo "=========================================="
echo -e "${NC}"

install_dependencies
install_accel_ppp
configure_accel_ppp
create_ui_menu

# Start the service
systemctl start accel-ppp

echo -e "${GREEN}"
echo "=========================================="
echo " Installation Complete!"
echo " "
echo " To manage your SSTP server, run:"
echo " "
echo "    sstp-ui"
echo " "
echo " This will launch the beautiful UI menu"
echo "=========================================="
echo -e "${NC}"

# Create initial account
read -p "Would you like to create an initial SSTP account now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    /usr/local/bin/sstp-ui
fi
