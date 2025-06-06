# 1) Temel imaj olarak Node 18 slim al
FROM node:18-slim

# 2) Paket listelerini güncelle ve iw ile wireless-tools paketlerini yükle
RUN apt-get update && \
    apt-get install -y wireless-tools iw && \
    rm -rf /var/lib/apt/lists/*

# 3) Çalışma dizinini /app olarak ayarla
WORKDIR /app

# 4) package.json dosyasını kopyala
COPY package.json ./

# 5) Node.js bağımlılıklarını yükle
RUN npm install

# 6) Geri kalan tüm dosyaları konteynere kopyala
COPY . .

# 7) Konteyner içindeki uygulamanın dinleyeceği port
EXPOSE 3000

# 8) Uygulama başladığında çalışacak komut
CMD ["npm", "start"]
