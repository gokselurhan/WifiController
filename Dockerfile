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
    wireless-tools \
    wpasupplicant \
    vlan \
    kmod \  # Bu satırı ekleyin
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/default
RUN mkdir -p /etc/hostapd

WORKDIR /app
COPY . /app

RUN pip install --no-cache-dir -r requirements.txt

RUN chmod +x entrypoint.sh

CMD ["./entrypoint.sh"]
