FROM python:3.11-slim

# 1) Ortam değişkenleri: interaktif debconf’u ve pip uyarılarını kapatıyoruz
ENV DEBIAN_FRONTEND=noninteractive \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_ROOT_USER_ACTION=ignore

# 2) apt-utils ekleyip paket kurulumlarını yap
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      apt-utils \
      hostapd \
      dnsmasq \
      iproute2 \
      iw \
      net-tools \
      iptables \
      procps \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 3) Pip’i önce yükselt (opsiyonel ama güncel pip’i sağlar), sonra bağımlılıkları yükle
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
 && pip install --no-cache-dir -r requirements.txt

# 4) Uygulama kodu
COPY . .
RUN chmod +x entrypoint.sh

EXPOSE 5000
ENTRYPOINT ["./entrypoint.sh"]
