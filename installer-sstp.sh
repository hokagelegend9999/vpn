#!/bin/bash

set -e

echo "📦 Menginstal dependensi..."
apt update && apt install -y \
    build-essential cmake git libpcre3-dev libssl-dev \
    liblua5.2-dev pkg-config iproute2 openssl

echo "📥 Clone & Build accel-ppp..."
cd /usr/src
git clone https://github.com/accel-ppp/accel-ppp.git
cd accel-ppp
mkdir build
cd build
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCPACK_TYPE=Debian ..
make
make install

echo "✅ Instalasi accel-ppp selesai!"

echo "🧾 Membuat konfigurasi accel-ppp..."
cp /etc/accel-ppp.conf.dist /etc/accel-ppp.conf

cat > /etc/accel-ppp.conf <<EOF
[modules]
log_file
ppp
sstp
auth_mschap_v2
chap-secrets

[core]
log-error=/var/log/accel-ppp.log
thread-count=4

[ppp]
verbose=1
min-mtu=1280
mtu=1400
mru=1400

[auth]
chap-secrets=/etc/ppp/chap-secrets

[sstp]
bind=0.0.0.0:443
ssl-cert=/etc/ssl/certs/sstp.crt
ssl-key=/etc/ssl/private/sstp.key

[ip-pool]
gw-ip=10.0.0.1
start-ip=10.0.0.2
end-ip=10.0.0.200

[dns]
dns1=8.8.8.8
dns2=1.1.1.1
EOF

echo "🔐 Membuat sertifikat SSL..."
mkdir -p /etc/ssl/private
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/sstp.key -out /etc/ssl/certs/sstp.crt \
    -subj "/C=ID/ST=Jakarta/L=Jakarta/O=VPN/OU=IT/CN=$(hostname)"

echo "📄 Menyiapkan file chap-secrets..."
touch /etc/ppp/chap-secrets
chmod 600 /etc/ppp/chap-secrets

echo "🛠️ Membuat menu script SSTP..."
cat > /usr/local/bin/sstp <<'EOM'
#!/bin/bash

USER_FILE="/etc/ppp/chap-secrets"

add_user() {
    echo -n "Masukkan username: "
    read username
    echo -n "Masukkan password: "
    read -s password
    echo

    if grep -w "$username" $USER_FILE > /dev/null; then
        echo "⚠️  User sudah ada!"
    else
        echo -e "$username\t*\t$password\t*" | sudo tee -a $USER_FILE > /dev/null
        echo "✅ Akun SSTP berhasil dibuat!"
    fi
    sudo systemctl restart accel-ppp
}

list_users() {
    echo "📄 Daftar User SSTP:"
    sudo awk '{print $1}' $USER_FILE | sort | uniq
}

delete_user() {
    echo -n "Masukkan username yang ingin dihapus: "
    read username
    if grep -w "$username" $USER_FILE > /dev/null; then
        sudo sed -i "/^$username\s/d" $USER_FILE
        echo "🗑️  User $username berhasil dihapus."
    else
        echo "⚠️  User tidak ditemukan."
    fi
    sudo systemctl restart accel-ppp
}

while true; do
    clear
    echo "========= MENU SSTP USER ========="
    echo "1. Buat akun SSTP"
    echo "2. Lihat semua akun"
    echo "3. Hapus akun SSTP"
    echo "0. Keluar"
    echo "=================================="
    echo -n "Pilih menu: "
    read choice

    case $choice in
        1) add_user ;;
        2) list_users ;;
        3) delete_user ;;
        0) exit ;;
        *) echo "❌ Pilihan tidak valid!" ;;
    esac
    echo ""
    read -p "Tekan Enter untuk kembali ke menu..."
done
EOM

chmod +x /usr/local/bin/sstp

echo "✅ Instalasi selesai!"
echo "💻 Ketik 'sstp' untuk membuka menu!"
