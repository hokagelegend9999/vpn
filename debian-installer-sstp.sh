#!/bin/bash
set -e

# Configuration variables
SSTP_PORT=4433
VPN_USER="vpnuser"
VPN_PASS="vpnpassword"
IP_POOL_START="192.168.88.10"
IP_POOL_END="192.168.88.100"

# Function to display error messages
error_exit() {
    echo "[✗] ERROR: $1" >&2
    exit 1
}

# Function to validate IP pool
validate_ip_pool() {
    local start=$1
    local end=$2
    
    # Check if IPs are valid
    if ! [[ $start =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || ! [[ $end =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        error_exit "Invalid IP address format in pool range"
    fi
    
    # Convert IPs to numerical values for comparison
    local ip_to_int() {
        local ip=$1
        IFS=. read -r a b c d <<< "$ip"
        echo $((a * 256 ** 3 + b * 256 ** 2 + c * 256 + d))
    }
    
    local start_num=$(ip_to_int "$start")
    local end_num=$(ip_to_int "$end")
    
    if [ "$start_num" -ge "$end_num" ]; then
        error_exit "IP pool start ($start) must be less than IP pool end ($end)"
    fi
}

# Validate IP pool before proceeding
validate_ip_pool "$IP_POOL_START" "$IP_POOL_END"

echo "[+] Checking system requirements..."
if [ "$(id -u)" -ne 0 ]; then
    error_exit "This script must be run as root"
fi

echo "[+] Updating system and installing dependencies..."
if ! apt update; then
    error_exit "Failed to update package lists"
fi

if ! apt install -y build-essential cmake libssl-dev libpcre3-dev git openssl liblua5.3-dev libjson-c-dev libcurl4-openssl-dev; then
    error_exit "Failed to install dependencies"
fi

echo "[+] Installing required kernel headers..."
if ! apt install -y linux-headers-$(uname -r); then
    error_exit "Failed to install kernel headers"
fi

echo "[+] Downloading and compiling accel-ppp..."
cd /usr/src || error_exit "Failed to change to /usr/src directory"
if [ -d "accel-ppp" ]; then
    echo "[!] accel-ppp directory already exists, removing..."
    rm -rf accel-ppp || error_exit "Failed to remove existing accel-ppp directory"
fi

if ! git clone https://github.com/accel-ppp/accel-ppp.git; then
    error_exit "Failed to clone accel-ppp repository"
fi

cd accel-ppp || error_exit "Failed to enter accel-ppp directory"
mkdir build || error_exit "Failed to create build directory"
cd build || error_exit "Failed to enter build directory"

if ! cmake -DCMAKE_INSTALL_PREFIX=/usr -DKDIR=/usr/src/linux-headers-$(uname -r) -DRADIUS=TRUE -DBUILD_IPOE=TRUE -DBUILD_VLAN_MON=TRUE ..; then
    error_exit "Failed to configure accel-ppp"
fi

if ! make -j$(nproc); then
    error_exit "Failed to compile accel-ppp"
fi

if ! make install; then
    error_exit "Failed to install accel-ppp"
fi

echo "[+] Creating configuration directories..."
mkdir -p /etc/ssl/sstp /var/log/accel-ppp /etc/ppp || error_exit "Failed to create directories"
chown -R root:root /etc/ssl/sstp || error_exit "Failed to set ownership"
chmod -R 700 /etc/ssl/sstp || error_exit "Failed to set permissions"

echo "[+] Generating self-signed certificate..."
if ! openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
 -keyout /etc/ssl/sstp/server.key \
 -out /etc/ssl/sstp/server.crt \
 -subj "/CN=sstp-server" \
 -addext "subjectAltName=DNS:sstp-server"; then
    error_exit "Failed to generate SSL certificate"
fi

chmod 600 /etc/ssl/sstp/server.key || error_exit "Failed to set key permissions"
chmod 644 /etc/ssl/sstp/server.crt || error_exit "Failed to set certificate permissions"
cp /etc/ssl/sstp/server.crt /etc/ssl/sstp/ca.crt || error_exit "Failed to copy CA certificate"

echo "[+] Creating chap-secrets file..."
cat <<EOF > /etc/ppp/chap-secrets || error_exit "Failed to create chap-secrets file"
# Secrets for authentication using CHAP
# client    server  secret          IP addresses
${VPN_USER}    *       ${VPN_PASS}     *
EOF

chmod 600 /etc/ppp/chap-secrets || error_exit "Failed to set chap-secrets permissions"

echo "[+] Creating accel-ppp configuration..."
cat <<EOF > /etc/accel-ppp.conf || error_exit "Failed to create accel-ppp configuration"
[modules]
log_file
sstp
chap-secrets
auth_mschap_v2
ippool

[core]
log-error=/var/log/accel-ppp/error.log
log-debug=/var/log/accel-ppp/debug.log
pidfile=/run/accel-pppd.pid

[common]
single-session=replace
ppp-max-mtu=1400

[chap-secrets]
chap-secrets=/etc/ppp/chap-secrets

[ppp]
verbose=1
min-mtu=1280
mtu=1400
mru=1400
mppe=require
ipv4=require
ipv6=deny
lcp-echo-interval=20
lcp-echo-timeout=60
lcp-echo-failure=3

[sstp]
verbose=1
port=${SSTP_PORT}
accept=ssl
ssl-protocol=tls1.2,tls1.3
ssl-ciphers=DEFAULT:@SECLEVEL=1
ssl-ca-file=/etc/ssl/sstp/ca.crt
ssl-pemfile=/etc/ssl/sstp/server.crt
ssl-keyfile=/etc/ssl/sstp/server.key
ip-pool=sstp
ifname=sstp%d

[ip-pool]
${IP_POOL_START}-${IP_POOL_END},name=sstp

[dns]
dns1=8.8.8.8
dns2=8.8.4.4

[log]
log-file=/var/log/accel-ppp/accel.log
log-emerg=/var/log/accel-ppp/emerg.log
log-fail-file=/var/log/accel-ppp/auth-fail.log
level=3
color=1
EOF

echo "[+] Creating systemd service..."
cat <<EOF > /etc/systemd/system/accel-ppp.service || error_exit "Failed to create systemd service"
[Unit]
Description=Accel-PPP Server
After=network.target

[Service]
Type=forking
ExecStart=/usr/sbin/accel-pppd -c /etc/accel-ppp.conf -d -p /run/accel-pppd.pid
PIDFile=/run/accel-pppd.pid
Restart=on-failure
RestartSec=5s
TimeoutStartSec=30

RuntimeDirectory=accel-ppp
RuntimeDirectoryMode=0755

PrivateTmp=true
ProtectSystem=full
NoNewPrivileges=true
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

echo "[+] Setting up log rotation..."
cat <<EOF > /etc/logrotate.d/accel-ppp || error_exit "Failed to create logrotate configuration"
/var/log/accel-ppp/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 640 root adm
    sharedscripts
    postrotate
        systemctl reload accel-ppp >/dev/null 2>&1 || true
    endscript
}
EOF

echo "[+] Enabling and starting service..."
systemctl daemon-reload || error_exit "Failed to reload systemd daemon"
systemctl enable accel-ppp || error_exit "Failed to enable accel-ppp service"
if ! systemctl start accel-ppp; then
    systemctl status accel-ppp --no-pager
    error_exit "Failed to start accel-ppp service"
fi

echo "[+] Enabling IP forwarding..."
if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf || error_exit "Failed to update sysctl.conf"
fi
sysctl -p || error_exit "Failed to apply sysctl settings"

echo "[+] Configuring firewall..."
if ! command -v iptables >/dev/null; then
    if ! apt install -y iptables-persistent; then
        error_exit "Failed to install iptables-persistent"
    fi
fi

DEFAULT_IFACE=$(ip route | grep default | awk '{print $5}')
if [ -z "$DEFAULT_IFACE" ]; then
    error_exit "Failed to determine default network interface"
fi

iptables -t nat -A POSTROUTING -o "$DEFAULT_IFACE" -j MASQUERADE || error_exit "Failed to add NAT rule"
iptables -A FORWARD -i sstp+ -j ACCEPT || error_exit "Failed to add forwarding rule"
iptables-save > /etc/iptables/rules.v4 || error_exit "Failed to save iptables rules"

echo "[+] Verifying VPN account..."
if ! grep -q "^${VPN_USER}" /etc/ppp/chap-secrets; then
    error_exit "VPN account creation failed - user not found in chap-secrets"
else
    echo "[✓] VPN account verified:"
    echo "    Username: ${VPN_USER}"
    echo "    Password: ${VPN_PASS}"
fi

echo "[+] Cleaning up installation files..."
rm -rf /usr/src/accel-ppp || echo "[!] Warning: Failed to remove accel-ppp source directory"
rm -f "$(readlink -f "$0")" || echo "[!] Warning: Failed to remove installation script"

echo "[✓] Installation completed successfully!"
echo "    SSTP Server is running on port ${SSTP_PORT}"
echo "    VPN credentials:"
echo "    Username: ${VPN_USER}"
echo "    Password: ${VPN_PASS}"
echo "    Check service status: systemctl status accel-ppp"
echo "    Configuration files:"
echo "    - Main config: /etc/accel-ppp.conf"
echo "    - User accounts: /etc/ppp/chap-secrets"
echo "    - SSL certificates: /etc/ssl/sstp/"
