#!/bin/bash
set -e

echo "=== WiFi Controller Kurulumu ==="

# Gerekli bağımlılıkları kontrol et
if ! command -v docker &> /dev/null; then
    echo "Docker bulunamadı. Lütfen önce Docker'ı kurun."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "docker-compose bulunamadı. Lütfen önce Docker Compose'u kurun."
    exit 1
fi

# Projeyi klonla
echo "Proje klonlanıyor..."
cd ~
rm -rf WifiController
git clone https://github.com/gokselurhan/WifiController.git
cd WifiController

# Çalıştırma yetkisi ver
chmod +x entrypoint.sh

# Konteynerleri oluştur ve başlat
echo "Docker konteynerleri oluşturuluyor..."
docker-compose down --remove-orphans
docker system prune -af
docker-compose up -d --build

echo "=== Kurulum Tamamlandı ==="
echo "Yönetim paneli: http://$(hostname -I | awk '{print $1}'):5000"
