FROM python:3.11-slim

ARG DEBIAN_FRONTEND=noninteractive
ENV DEBIAN_FRONTEND=${DEBIAN_FRONTEND}

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      hostapd \
      isc-dhcp-relay \
      iproute2 \
      iw \
      wireless-tools \
      net-tools \
      procps \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
 && pip install --no-cache-dir -r requirements.txt

COPY . .
RUN chmod +x entrypoint.sh

EXPOSE 5000
ENTRYPOINT ["./entrypoint.sh"]
