FROM node:18-slim

# ① Hostapd, iw ve wireless-tools paketlerini mutlaka kur
RUN apt-get update && \
    apt-get install -y hostapd wireless-tools iw && \
    rm -rf /var/lib/apt/lists/*

# ② Çalışma dizinini /app olarak ayarla
WORKDIR /app

# ③ package.json'ı kopyala ve bağımlılıkları yükle
COPY package.json ./
RUN npm install

# ④ Projedeki diğer tüm dosyaları kopyala
COPY . .

# ⑤ API’nın dinleyeceği portu bildir
EXPOSE 3000

# ⑥ Node.js uygulamasını başlat
CMD ["node", "server.js"]
