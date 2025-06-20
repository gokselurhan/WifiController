FROM python:3.9-slim

RUN apt-get update && \
    apt-get install -y \
    iw \
    hostapd \
    net-tools \
    isc-dhcp-relay \
    iptables \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . /app

RUN chmod +x entrypoint.sh

CMD ["./entrypoint.sh"]
