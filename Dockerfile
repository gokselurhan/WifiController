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

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . /app

ENTRYPOINT ["/entrypoint.sh"]
