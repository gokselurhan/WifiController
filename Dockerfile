FROM node:18-slim

# A) Hostapd, iw ve wireless-tools paketlerini yükle
RUN apt-get update && \
    apt-get install -y hostapd wireless-tools iw && \
    rm -rf /var/lib/apt/lists/*

# B) Çalışma dizinini ayarla
WORKDIR /app

# C) package.json'ı kopyala ve bağımlılıkları yükle
COPY package.json ./
RUN npm install

# D) Geri kalan dosyaları kopyala
COPY . .

# E) Port bildirimi
EXPOSE 3000

# F) Uygulamayı başlat (Root olarak container içindeyken hostapd + ip link komutları çalışacak)
CMD ["node", "server.js"]
