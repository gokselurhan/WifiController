# Dockerfile

FROM node:18-slim


RUN apt-get update && \
    apt-get install -y hostapd wireless-tools iw iproute2 && \
    rm -rf /var/lib/apt/lists/*


WORKDIR /app


COPY package.json ./
RUN npm install


COPY . .


EXPOSE 3000


CMD ["node", "server.js"]
