FROM python:3.11-slim

# 1) Host ağındaki arayüzlerde değişiklik yapabilmek için network araçları ve hostapd kurulumu
RUN apt-get update && apt-get install -y \
    hostapd \
    iproute2 \
    iw \
    net-tools \
    iptables \
    procps \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 2) Python bağımlılıkları (requirements.txt projenizde yer almalı)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 3) Uygulama kodu ve entrypoint betiği
COPY . .

# 4) entrypoint.sh çalıştırılabilir kıl
RUN chmod +x entrypoint.sh

# 5) Flask’in dinlediği port (host network modunda expose’a gerek yok ama dokümente için)
EXPOSE 5000

ENTRYPOINT ["./entrypoint.sh"]
