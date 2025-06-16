# Dockerfile
FROM python:3.11-slim

ARG DEBIAN_FRONTEND=noninteractive
ENV DEBIAN_FRONTEND=${DEBIAN_FRONTEND}

# hostapd, dhcp-relay, vb için gereken paketler
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

# Python bağımlılıkları
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Flask için templates klasörünü oluştur ve index.html'i oraya kopyala
RUN mkdir -p /app/templates
COPY index.html /app/templates/index.html

# Uygulama kodunu kopyala
COPY app.py entrypoint.sh /app/
RUN chmod +x entrypoint.sh

# (Eğer başka .html dosyaları veya template partial'larınız varsa:)
# COPY templates/ /app/templates/

# ENTRYPOINT içinde hem network flag hem Flask çalışacak
ENTRYPOINT ["./entrypoint.sh"]
