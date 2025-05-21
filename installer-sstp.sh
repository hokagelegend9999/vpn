#!/bin/bash
set -e

echo "=== Install dependencies ==="
sudo apt update
sudo apt install -y git build-essential cmake libssl-dev libpcap-dev libcurl4-openssl-dev libjson-c-dev libnl-3-dev libnl-genl-3-dev iptables ppp xl2tpd lsof curl

echo "=== Clone accel-ppp source ==="
cd /tmp
rm -rf accel-ppp
git clone https://github.com/accel-ppp/accel-ppp.git
cd accel-ppp

echo "=== Build accel-ppp ==="
mkdir -p build && cd build
cmake ..
make
sudo make install

echo "=== Create accel-ppp config ==="
sudo tee /etc/accel-ppp.conf > /dev/null <<EOF
[modules]
ppp
sstp
pptp
l2tp
auth-chap

[core]
log-error=/var/log/accel-ppp/error.log
log-debug=/var/log/accel-ppp/debug.log

[ppp]
verbose=1
mtu=1400
mru=1400

[sstp]
bind=0.0.0.0:4433
ssl-key=/etc/ssl/private/ssl.key
ssl-cert=/etc/ssl/certs/ssl.crt

[pptp]
bind=0.0.0.0:1723

[l2tp]
bind=0.0.0.0:1701

[auth-chap]
chap-secrets=/etc/ppp/chap-secrets

[ip-pool]
gw-ip=192.168.90.1
pool-start=192.168.90.10
pool-end=192.168.90.100
EOF

echo "=== Create /etc/ppp/chap-secrets (example) ==="
sudo tee /etc/ppp/chap-secrets > /dev/null <<EOF
# client    server    secret          IP addresses
testuser    *         testpass        *
EOF
sudo chmod 600 /etc/ppp/chap-secrets

echo "=== Enable IP forwarding ==="
sudo sysctl -w net.ipv4.ip_forward=1
sudo sed -i '/^net.ipv4.ip_forward/d' /etc/sysctl.conf
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf

echo "=== Setup iptables (NAT and forwarding) ==="
sudo iptables -t nat -A POSTROUTING -s 192.168.90.0/24 -o eth0 -j MASQUERADE
sudo iptables -A FORWARD -s 192.168.90.0/24 -j ACCEPT
sudo iptables -A FORWARD -d 192.168.90.0/24 -j ACCEPT

echo "=== Save iptables rules ==="
sudo apt install -y iptables-persistent
sudo netfilter-persistent save

echo "=== Setup systemd service ==="
sudo tee /etc/systemd/system/accel-ppp.service > /dev/null <<EOF
[Unit]
Description=Accel-PPP daemon
After=network.target

[Service]
ExecStart=/usr/local/sbin/accel-pppd -d -c /etc/accel-ppp.conf
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

echo "=== Reload systemd and start accel-ppp ==="
sudo systemctl daemon-reload
sudo systemctl enable accel-ppp
sudo systemctl start accel-ppp

echo "=== DONE ==="
echo "Check status with: sudo systemctl status accel-ppp"
echo "Check logs with: sudo journalctl -u accel-ppp -f"
