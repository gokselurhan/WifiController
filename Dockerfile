# 1) Temel imaj olarak Node 18 slim alıyoruz
FROM node:18-slim

# 2) Paket listelerini güncelle ve iw/wireless-tools paketlerini yükle
RUN apt-get update && \
    apt-get install -y wireless-tools iw && \
    rm -rf /var/lib/apt/lists/*

# 3) Çalışma dizinini /app olarak ayarla
WORKDIR /app

# 4) package.json ve package-lock.json (varsa) kopyala
COPY package.json ./

# 5) Bağımlılıkları yükle
RUN npm install

# 6) Kalan tüm dosyaları konteynere kopyala
COPY . .

# 7) Konteyner içindeki uygulamanın dinleyeceği portu bildir
EXPOSE 3000

# 8) Konteyner çalıştığında uygulamanın aşağıdaki komutla başlamasını sağla
CMD ["npm", "start"]
