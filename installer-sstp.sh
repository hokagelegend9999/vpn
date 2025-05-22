#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

VPN_USER="vpnuser"
VPN_PASS="vpnpassword"
VPN_PSK="vpnsharedkey"
SERVER_IP=$(curl -s ifconfig.me)

function status_service() {
  local name=$1
  local service=$2
  if systemctl is-active --quiet "$service"; then
    echo -e "$name: ${GREEN}✔ RUNNING${NC}"
  else
    echo -e "$name: ${RED}✘ NOT RUNNING${NC}"
  fi
}

function install_pptp() {
  echo "[*] Install PPTP VPN"
  apt update && apt install -y pptpd ppp iptables-persistent
  cat > /etc/pptpd.conf <<EOF
localip 192.168.0.1
remoteip 192.168.0.100-200
EOF
  cat > /etc/ppp/chap-secrets <<EOF
$VPN_USER pptpd $VPN_PASS *
EOF

  sed -i '/^net.ipv4.ip_forward/c\net.ipv4.ip_forward=1' /etc/sysctl.conf
  sysctl -p

  iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
  netfilter-persistent save

  systemctl restart pptpd
  systemctl enable pptpd
  echo "[*] PPTP VPN Installed and Started"
}

function install_l2tp() {
  echo "[*] Install L2TP/IPSec VPN"
  apt update && apt install -y strongswan xl2tpd ppp iptables-persistent

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

  sed -i '/^net.ipv4.ip_forward/c\net.ipv4.ip_forward=1' /etc/sysctl.conf
  sysctl -p

  iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
  netfilter-persistent save

  systemctl restart strongswan-starter
  systemctl enable strongswan-starter

  systemctl restart xl2tpd
  systemctl enable xl2tpd

  echo "[*] L2TP/IPSec VPN Installed and Started"
}

function install_sstp() {
  echo "[*] Install SSTP VPN"
  apt update && apt install -y python3-pip iptables-persistent

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

  echo "[*] SSTP VPN Installed and Started"
}

function show_status() {
  echo "Status Layanan VPN:"
  status_service "PPTP" "pptpd"
  status_service "L2TP/IPSec (strongSwan)" "strongswan-starter"
  status_service "L2TP (xl2tpd)" "xl2tpd"
  status_service "SSTP" "sstpd"
}

function main_menu() {
  clear
  echo "=============================="
  echo "  VPN Installer & Manager"
  echo "=============================="
  echo "Server IP: $SERVER_IP"
  echo ""
  echo "1) Install PPTP VPN"
  echo "2) Install L2TP/IPSec VPN"
  echo "3) Install SSTP VPN"
  echo "4) Tampilkan Status VPN"
  echo "5) Keluar"
  echo -n "Pilih menu [1-5]: "
  read pilihan
  case $pilihan in
    1) install_pptp ;;
    2) install_l2tp ;;
    3) install_sstp ;;
    4) show_status ;;
    5) echo "Keluar..."; exit 0 ;;
    *) echo "Pilihan tidak valid." ;;
  esac
  echo ""
  read -p "Tekan ENTER untuk kembali ke menu..."
  main_menu
}

main_menu
