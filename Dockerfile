# Dockerfile

FROM node:18-slim

# ① Hostapd, iw, wireless-tools ve iproute2 paketlerini yükle
RUN apt-get update && \
    apt-get install -y hostapd wireless-tools iw iproute2 && \
    rm -rf /var/lib/apt/lists/*

# ② Çalışma dizinini /app olarak ayarla
WORKDIR /app

# ③ package.json'ı kopyala ve bağımlılıkları yükle
COPY package.json ./
RUN npm install

# ④ Projedeki diğer tüm dosyaları (hostapd.conf, server.js, index.html, vs.) kopyala
COPY . .

# ⑤ API’nın dinleyeceği portu bildir
EXPOSE 3000

# ⑥ Node.js uygulamasını başlat
CMD ["node", "server.js"]
