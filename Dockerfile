# syntax = docker/dockerfile:1.2
FROM python:3.11-slim

# 0) BuildKit kullanıyorsanız aşağıdaki satırı atlayabilirsiniz; 
#    aksi takdirde daima en güncel DNS'i kullanmak için
RUN echo "nameserver 8.8.8.8" > /etc/resolv.conf

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

EXPOSE 5000

ENTRYPOINT ["./entrypoint.sh"]
