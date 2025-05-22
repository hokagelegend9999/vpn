#!/bin/bash

set -e

# Konfigurasi
SERVER_IP=$(curl -s ifconfig.me)
VPN_USER="vpnuser"
VPN_PASS="vpnpassword"
VPN_PSK="vpnsharedkey"

# Warna untuk status
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "========================================"
echo "  VPN INSTALLER - PPTP + L2TP + SSTP"
echo "  Untuk Ubuntu 20.04"
echo "  By ChatGPT | $(date)"
echo "========================================"

echo "[1] Update dan Install Dependensi"
apt update && apt install -y \
  pptpd \
  strongswan xl2tpd \
  ppp \
  iptables-persistent \
  python3-pip

echo "[2] Setup PPTP Server"
/bin/cat > /etc/pptpd.conf <<EOF
localip 192.168.0.1
remoteip 192.168.0.100-200
EOF

/bin/cat > /etc/ppp/chap-secrets <<EOF
$VPN_USER pptpd $VPN_PASS *
$VPN_USER l2tpd $VPN_PASS *
EOF

sed -i '/^net.ipv4.ip_forward/c\net.ipv4.ip_forward=1' /etc/sysctl.conf
sysctl -p

iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
netfilter-persistent save

systemctl restart pptpd
systemctl enable pptpd

echo "[3] Setup L2TP/IPSec"

cat > /etc/ipsec.conf <<EOF
config setup
    charondebug="ike 2, knl 2, cfg 2"

conn %default
    keyexchange=ikev1
    authby=secret
    ike=aes256-sha1-modp1024!
    esp=aes256-sha1!
    keyingtries=3
    ikelifetime=8h
    lifetime=1h
    dpdaction=clear
    dpddelay=300s
    dpdtimeout=1h

conn l2tp-psk
    keyexchange=ikev1
    left=$SERVER_IP
    leftid=$SERVER_IP
    leftfirewall=yes
    leftsubnet=0.0.0.0/0
    right=%any
    rightprotoport=17/1701
    auto=add
EOF

cat > /etc/ipsec.secrets <<EOF
: PSK "$VPN_PSK"
EOF

cat > /etc/xl2tpd/xl2tpd.conf <<EOF
[global]
port = 1701

[lns default]
ip range = 192.168.1.10-192.168.1.20
local ip = 192.168.1.1
require chap = yes
refuse pap = yes
require authentication = yes
ppp debug = yes
pppoptfile = /etc/ppp/options.xl2tpd
length bit = yes
EOF

cat > /etc/ppp/options.xl2tpd <<EOF
require-mschap-v2
refuse-chap
refuse-mschap
ms-dns 8.8.8.8
ms-dns 1.1.1.1
asyncmap 0
auth
crtscts
lock
hide-password
modem
mtu 1410
mru 1410
connect-delay 5000
EOF

systemctl restart strongswan-starter
systemctl enable strongswan-starter

systemctl restart xl2tpd
systemctl enable xl2tpd

echo "[4] Setup SSTP Server"

pip3 install git+https://github.com/sorz/sstp-server.git

mkdir -p /etc/sstp
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/sstp/sstp.key -out /etc/sstp/sstp.crt \
  -subj "/C=ID/ST=VPN/L=VPN/O=VPN/OU=VPN/CN=$SERVER_IP"

cat > /etc/systemd/system/sstpd.service <<EOF
[Unit]
Description=SSTP VPN Server
After=network.target

[Service]
ExecStart=/usr/local/bin/sstpd --iprange 192.168.2.10-192.168.2.20 --cert /etc/sstp/sstp.crt --key /etc/sstp/sstp.key
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable sstpd
systemctl start sstpd

echo "========================================"
echo " Installasi Selesai!"
echo " IP Server   : $SERVER_IP"
echo " User VPN    : $VPN_USER"
echo " Password    : $VPN_PASS"
echo " Pre-shared key (L2TP) : $VPN_PSK"
echo "========================================"


# Menu status layanan VPN
function status_service() {
  local name=$1
  local service=$2
  if systemctl is-active --quiet $service; then
    echo -e "$name: ${GREEN}✔ RUNNING${NC}"
  else
    echo -e "$name: ${RED}✘ NOT RUNNING${NC}"
  fi
}

echo
echo "Status Services VPN:"
status_service "PPTP" "pptpd"
status_service "L2TP/IPSec (strongSwan)" "strongswan-starter"
status_service "L2TP (xl2tpd)" "xl2tpd"
status_service "SSTP" "sstpd"
echo
