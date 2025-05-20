#!/bin/bash

clear
echo "🛠️  Memulai instalasi SSTP Server (accel-ppp)..."

# Update & install dependencies
apt update -y
apt install -y build-essential cmake git libpcre3-dev libssl-dev liblua5.1-0-dev \
libnl-3-dev libnl-genl-3-dev pkg-config iproute2 curl

# Clone accel-ppp jika belum ada
if [ ! -d "/usr/src/accel-ppp" ]; then
    echo "📥 Clone & Build accel-ppp..."
    cd /usr/src
    git clone https://github.com/accel-ppp/accel-ppp.git
    cd accel-ppp
    mkdir build && cd build
    cmake -DCMAKE_INSTALL_PREFIX=/usr -DKDIR=/usr/src/linux-headers-$(uname -r) \
    -DCPACK_TYPE=Debian -DRADIUS=FALSE -DBUILD_DRIVER=FALSE ..
    make -j$(nproc)
    make install
    cp /usr/src/accel-ppp/doc/etc/accel-ppp.conf.sample /etc/accel-ppp.conf
else
    echo "📁 accel-ppp sudah ada, skip clone."
fi

# Konfigurasi chap-secrets & accel-ppp
touch /etc/ppp/chap-secrets

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

# Buat sertifikat SSL self-signed
echo "🔐 Membuat sertifikat SSL self-signed..."
mkdir -p /etc/ssl/private /etc/ssl/certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/ssl.key \
    -out /etc/ssl/certs/ssl.crt \
    -subj "/CN=sstp-server"

# Aktifkan accel-ppp
echo "📦 Mengaktifkan accel-ppp..."
systemctl enable accel-ppp
systemctl restart accel-ppp

# Install menu sstp
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

      # Ambil IP Publik Server
      server_ip=$(curl -s ifconfig.me || curl -s ipinfo.io/ip)

      echo "======================================"
      echo "🎉 Info Akun SSTP untuk $user"
      echo "Server IP   : $server_ip"
      echo "Username    : $user"
      echo "Password    : $pass"
      echo "Port        : 443"
      echo "Protocol    : SSTP (SSL VPN)"
      echo "======================================"
      echo "💡 Cara Menggunakan:"
      echo "  - Buka VPN SSTP di Windows"
      echo "  - Masukkan IP server di kolom 'Server name or address'"
      echo "  - Gunakan username & password di atas"
      echo "  - Centang 'Allow these protocols' > Microsoft CHAP Version 2"
      echo "  - Hubungkan dan selesai!"
      echo "======================================"
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

echo ""
echo "✅ Instalasi selesai!"
echo "🔧 Jalankan perintah berikut untuk mulai:"
echo ""
echo "    sudo sstp"
echo ""
echo ""
echo "🎉 Instalasi selesai dan menu 'sstp' telah dibuat."
echo "📢 Contoh langsung membuat akun SSTP awal..."

read -p "Masukkan username pertama: " user
read -p "Masukkan password: " pass

echo "$user * $pass *" >> /etc/ppp/chap-secrets
systemctl restart accel-ppp

# Ambil IP Publik Server
server_ip=$(curl -s ifconfig.me || curl -s ipinfo.io/ip)

echo ""
echo "======================================"
echo "🎉 Info Akun SSTP untuk $user"
echo "Server IP   : $server_ip"
echo "Username    : $user"
echo "Password    : $pass"
echo "Port        : 443"
echo "Protocol    : SSTP (SSL VPN)"
echo "======================================"
echo "💡 Cara Menggunakan:"
echo "  - Buka VPN SSTP di Windows"
echo "  - Masukkan IP server di kolom 'Server name or address'"
echo "  - Gunakan username & password di atas"
echo "  - Centang 'Allow these protocols' > Microsoft CHAP Version 2"
echo "  - Hubungkan dan selesai!"
echo "======================================"
