# syntax=docker/dockerfile:1.4
FROM python:3.11-slim

# 1) Sistem araçlarını host ağı üzerinden kur
RUN --network=host apt-get update \
    && apt-get install -y \
       hostapd \
       dnsmasq \
       iproute2 \
       iw \
       net-tools \
       iptables \
       procps \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 2) Python bağımlılıklarını yükle
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 3) Uygulama kodu ve entrypoint
COPY . .
RUN chmod +x entrypoint.sh

EXPOSE 5000
ENTRYPOINT ["./entrypoint.sh"]
