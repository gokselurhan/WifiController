# Dockerfile

FROM python:3.11-slim

# 1) Sistem araçları + hostapd + dnsmasq kurulumu
RUN apt-get update && apt-get install -y \
    hostapd \
    dnsmasq \
    iproute2 \
    iw \
    net-tools \
    iptables \
    procps \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 2) Python bağımlılıkları
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 3) Uygulama kodu ve entrypoint
COPY . .

RUN chmod +x entrypoint.sh

# 4) Flask’in dinlediği port (host ağını kullandığınız için publish’a gerek yok)
EXPOSE 5000

ENTRYPOINT ["./entrypoint.sh"]
