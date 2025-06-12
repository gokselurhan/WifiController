# Python tabanlı bir imaj kullanıyoruz
FROM python:3.9-slim

# Sistem güncellemeleri ve gerekli paketler
RUN apt-get update && apt-get install -y \
    hostapd \
    dnsmasq \
    iw \
    net-tools \
    wpasupplicant \
    && rm -rf /var/lib/apt/lists/*

# Uygulama dizini oluştur
WORKDIR /app

# Backend bağımlılıklarını kopyala ve yükle
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Uygulama dosyalarını kopyala
COPY backend/ /app/backend/
COPY frontend/ /app/frontend/

# Hostapd ve dnsmasq konfigürasyonları için dizin
RUN mkdir -p /etc/hostapd /etc/dnsmasq.d

# Port bilgisi
EXPOSE 80

# Uygulamayı çalıştır
CMD ["python", "-m", "backend.app"]
