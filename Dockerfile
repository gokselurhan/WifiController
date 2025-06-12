# Python tabanlı imaj
FROM python:3.9-slim

# Gerekli sistem paketleri
RUN apt-get update && apt-get install -y \
    hostapd \
    dnsmasq \
    iw \
    net-tools \
    wpasupplicant \
    && rm -rf /var/lib/apt/lists/*

# Çalışma dizini oluştur
WORKDIR /app

# Python bağımlılıklarını yükle
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Uygulama dosyalarını kopyala
COPY backend /app/backend
COPY frontend /app/frontend

# Konfigürasyon dizinleri
RUN mkdir -p /etc/hostapd /etc/dnsmasq.d

# Port aç
EXPOSE 80

# Uygulamayı başlat
CMD ["python", "-m", "backend.app"]
