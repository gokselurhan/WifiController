# Dockerfile

FROM python:3.11-slim

# 1) Sistem paketleri: hostapd (AP), iproute2 (bridge), iptables (NAT), dhclient (DHCP)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      hostapd \
      iproute2 \
      iptables \
      isc-dhcp-client && \
    rm -rf /var/lib/apt/lists/*

# 2) Uygulama klasörüne geç ve Python bağımlılıklarını kur
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 3) Tüm proje dosyalarını kopyala ve entrypoint’e çalıştırma izni ver
COPY . .
RUN chmod +x entrypoint.sh

# 4) Container başladığında entrypoint.sh çalışsın
ENTRYPOINT ["./entrypoint.sh"]
