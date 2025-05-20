#!/bin/bash

set -e

echo "🚀 Memulai proses instalasi SSTP VPN (accel-ppp)..."

# Update dan install dependensi
echo "📦 Memastikan semua dependensi terpasang..."
apt update && apt install -y \
    build-essential cmake git libpcre3-dev libpcre2-dev \
    libssl-dev libcurl4-openssl-dev pkg-config \
    iptables iproute2 ppp gcc g++ uuid-dev openssl

# Siapkan direktori kerja
cd /usr/src/

# Hapus accel-ppp jika sudah ada
if [ -d "accel-ppp" ]; then
  echo "⚠️  Folder accel-ppp sudah ada. Menghapus folder lama..."
  rm -rf accel-ppp
fi

# Clone accel-ppp terbaru
echo "📥 Cloning accel-ppp..."
git clone https://github.com/accel-ppp/accel-ppp.git
cd accel-ppp

# Build
echo "🔧 Build accel-ppp..."
mkdir build && cd build
cmake -DCMAKE_INSTALL_PREFIX=/usr -DKDIR=/lib/modules/$(uname -r)/build ..
make -j$(nproc)
make install

# Konfigurasi
echo "🛠️  Menyiapkan konfigurasi accel-ppp dan SSTP..."
mkdir -p /etc/accel-ppp /var/run/accel-ppp

# Buat config accel-ppp
cat <<EOF > /etc/accel-ppp.conf
[modules]
logfile
pppoe
sstp
cli
auth_mschap-v2
chap-secrets
radius

[core]
logfile=/var/log/accel-ppp.log
loglevel=info

[cli]
telnet=127.0.0.1:2000
password=admin

[dns]
dns1=8.8.8.8
dns2=1.1.1.1

[ppp]
verbose=1
min-mtu=1200
mtu=1400
mru=1400
ccp=no
auth=chap-msv2
chap-secrets=/etc/ppp/chap-secrets
ipv4=require
ipv6=disable

[auth]
any-login=1
noauth=1
client-ip-pool=pool1

[ip-pool]
pool1=192.168.99.10-192.168.99.100

[sstp]
enabled=yes
port=443
ssl-key=/etc/ssl/private/sstp.key
ssl-cert=/etc/ssl/certs/sstp.crt

[logfile]
file=/var/log/accel-ppp.log
level=info
EOF

# Buat sertifikat SSL self-signed
echo "🔐 Membuat sertifikat SSL..."
mkdir -p /etc/ssl/private /etc/ssl/certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/sstp.key \
  -out /etc/ssl/certs/sstp.crt \
  -subj "/C=ID/ST=Jakarta/L=Jakarta/O=SSTP-VPN/OU=IT/CN=sstp.local"

# Enable IP forwarding
sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf

# Systemd service
cat <<EOF > /etc/systemd/system/accel-ppp.service
[Unit]
Description=accel-ppp service
After=network.target

[Service]
ExecStart=/usr/sbin/accel-pppd -c /etc/accel-ppp.conf
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl enable accel-ppp
systemctl start accel-ppp

# Menu perintah sstp
echo "📋 Membuat menu sstp..."
cat <<'EOM' > /usr/local/bin/sstp
#!/bin/bash
while true; do
  echo "========= MENU SSTP USER ========="
  echo "1. Buat akun SSTP"
  echo "2. Lihat semua akun"
  echo "3. Hapus akun SSTP"
  echo "0. Keluar"
  echo "=================================="
  read -p "Pilih menu: " menu
  case $menu in
    1)
      read -p "Username: " user
      read -p "Password: " pass
      echo "$user * $pass *" >> /etc/ppp/chap-secrets
      echo "✅ Akun SSTP berhasil dibuat!"
      systemctl restart accel-ppp
      ;;
    2)
      echo "📋 Daftar akun SSTP:"
      cat /etc/ppp/chap-secrets
      ;;
    3)
      read -p "Masukkan username yang akan dihapus: " deluser
      sed -i "/^$deluser /d" /etc/ppp/chap-secrets
      echo "🗑️ Akun $deluser berhasil dihapus."
      systemctl restart accel-ppp
      ;;
    0)
      exit 0
      ;;
    *)
      echo "❌ Pilihan tidak valid."
      ;;
  esac
done
EOM

chmod +x /usr/local/bin/sstp

echo "✅ Instalasi selesai. Jalankan dengan: sudo sstp"
