FROM python:3.11-slim

ARG DEBIAN_FRONTEND=noninteractive
ENV DEBIAN_FRONTEND=${DEBIAN_FRONTEND} \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_ROOT_USER_ACTION=ignore

# 1) Gerekli tüm paketler: hostapd, dhcp-relay + interface tespiti için iproute2, iw vb.
RUN apt-get update && apt-get install -y --no-install-recommends \
      apt-utils \
      hostapd \
      isc-dhcp-relay \
      iproute2 \
      iw \
      net-tools \
      wireless-tools \
      procps \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 2) Python bağımlılıkları
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
 && pip install --no-cache-dir -r requirements.txt

# 3) Uygulama kodu
COPY . .
RUN chmod +x entrypoint.sh

EXPOSE 5000
ENTRYPOINT ["./entrypoint.sh"]
