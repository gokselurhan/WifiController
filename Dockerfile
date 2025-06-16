FROM python:3.11-slim

ARG DEBIAN_FRONTEND=noninteractive
ENV DEBIAN_FRONTEND=${DEBIAN_FRONTEND}

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      hostapd \
      iproute2 \
      iw \
      bridge-utils \
      net-tools \
      procps \
      isc-dhcp-relay \
      nmap \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Önce requirements'i yükle
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Uygulama dosyalarını kopyala ve entrypoint'e çalıştırma izni ver
COPY . .
RUN chmod +x entrypoint.sh

# entrypoint artık WORKDIR içindeki ./entrypoint.sh
ENTRYPOINT ["./entrypoint.sh"]
