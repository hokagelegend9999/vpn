#!/bin/bash

set -e

# Ganti dengan IP server kamu
SERVER_IP=$(curl -s ifconfig.me)
VPN_USER="vpnuser"
VPN_PASS="vpnpassword"
VPN_PSK="vpnsharedkey"

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
  git build-essential libssl-dev libpcap-dev

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
systemctl enable strongswan xl2tpd

echo "[4] Setup SSTP Server"
cd /opt
git clone https://github.com/sarfata/sstp-server.git
cd sstp-server
make && make install

mkdir -p /etc/sstp
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/sstp/sstp.key -out /etc/sstp/sstp.crt \
  -subj "/C=ID/ST=VPN/L=VPN/O=VPN/OU=VPN/CN=$SERVER_IP"

cat > /etc/systemd/system/sstpd.service <<EOF
[Unit]
Description=SSTP VPN Server
After=network.target

[Service]
ExecStart=/usr/local/sbin/sstpd --iprange 192.168.2.10-192.168.2.20 --cert /etc/sstp/sstp.crt --key /etc/sstp/sstp.key
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
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
