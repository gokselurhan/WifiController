FROM python:3.9-slim

RUN apt-get update && \
    apt-get install -y \
    procps \
    iproute2 \
    iw \
    hostapd \
    net-tools \
    isc-dhcp-relay \
    iptables \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/default

WORKDIR /app
COPY . /app

# Python bağımlılıklarını yükle
RUN pip install --no-cache-dir -r requirements.txt

RUN chmod +x entrypoint.sh

CMD ["./entrypoint.sh"]
