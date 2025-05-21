# 🚀 SSTP VPN Installer for Ubuntu/Debian


<p align="center">
  <img src="https://github.com/hokagelegend9999/vpn/blob/main/sstp.jpg?raw=true" alt="Tampilan Menu" width="600"/>
</p>



**Installer otomatis dan mudah** untuk setup **SSTP VPN Server** menggunakan **accel-ppp** di Ubuntu/Debian.

---

## ⚙️ Fitur

- Instalasi `accel-ppp` dari source terbaru  
- Konfigurasi SSTP dengan sertifikat SSL otomatis  
- Menu interaktif untuk manajemen user SSTP:  
  - Tambah user  
  - Lihat daftar user  
  - Hapus user  
- Shortcut perintah `sstp` untuk akses mudah  
- Konfigurasi IP pool dan DNS siap pakai  

---

## 💻 Cara Install

Jalankan satu perintah berikut di server Ubuntu/Debian kamu (akses root diperlukan):



1.UBUNTU 20



```bash
wget https://raw.githubusercontent.com/hokagelegend9999/vpn/refs/heads/main/installer-sstp.sh && chmod +x installer-sstp.sh && sudo ./installer-sstp.sh

```

```
cd /usr/bin/
wget https://raw.githubusercontent.com/hokagelegend9999/vpn/refs/heads/main/vpn && sudo chmod +x vpn
cd
```

2.DEBIAN 11



```bash
wget https://raw.githubusercontent.com/hokagelegend9999/vpn/refs/heads/main/debian-installer-sstp.sh && chmod +x debian-installer-sstp.sh && sudo ./debian-installer-sstp.sh

```

```
cd /usr/local/sbin
wget https://raw.githubusercontent.com/hokagelegend9999/vpn/refs/heads/main/vpn && sudo chmod +x vpn
cd
```

🛠 Cara Menggunakan Menu SSTP
Setelah instalasi selesai, jalankan:

```
vpn
```
Menu interaktif akan muncul, pilih opsi sesuai kebutuhan:
========= MENU SSTP USER =========
1. Buat akun SSTP
2. Lihat semua akun
3. Hapus akun SSTP
0. Keluar
==================================
Pilih menu:
🔧 Konfigurasi & Port
Default SSTP menggunakan port 443.

Pastikan port ini tidak bentrok dengan layanan lain (contoh: nginx, apache).

Konfigurasi utama ada di /etc/accel-ppp.conf.

Sertifikat SSL tersimpan di:

/etc/ssl/certs/sstp.crt

/etc/ssl/private/sstp.key

⚠️ Catatan Penting
Script ini hanya diuji di Ubuntu/Debian terbaru.

Diperlukan akses root untuk instalasi dan manajemen user.

User dan password SSTP disimpan di /etc/ppp/chap-secrets dengan format standar.

Setelah menambah/menghapus user, server SSTP otomatis restart.

📜 Lisensi
MIT License © 2025 by HokageLegend9999

💬 Kontak & Support
Bila ada pertanyaan atau masalah, silakan hubungi saya di:

GitHub: hokagelegend9999
https://t.me/hokagelegend1
