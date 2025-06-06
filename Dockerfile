# 1) Temel imaj olarak Node 18 slim alıyoruz
FROM node:18-slim

# 2) Çalışma dizinini /app olarak ayarla
WORKDIR /app

# 3) package.json ve package-lock.json (eğer varsa) kopyala
COPY package.json ./

# 4) Bağımlılıkları yükle
RUN npm install

# 5) Geriye kalan tüm dosyaları konteynere kopyala
COPY . .

# 6) Konteyner içindeki uygulamanın dinleyeceği portu bildir
EXPOSE 3000

# 7) Konteyner çalıştığında uygulamanın aşağıdaki komutla başlamasını sağla
CMD ["npm", "start"]
