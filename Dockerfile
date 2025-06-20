FROM python:3.9-slim

# Linux kernel headers'larını yükle
RUN apt-get update && \
    apt-get install -y \
    linux-headers-$(uname -r) \
    kmod \
    && rm -rf /var/lib/apt/lists/*

# Geri kalan kurulumlar
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
    && rm -rf /var/lib/apt/lists/*

# Kernel modüllerini host'tan konteynere kopyala
RUN mkdir -p /lib/modules/$(uname -r)
COPY /lib/modules/$(uname -r)/ /lib/modules/$(uname -r)/
RUN depmod -a

RUN mkdir -p /etc/default
RUN mkdir -p /etc/hostapd

WORKDIR /app
COPY . /app

RUN pip install --no-cache-dir -r requirements.txt

RUN chmod +x entrypoint.sh

CMD ["./entrypoint.sh"]
