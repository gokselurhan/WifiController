FROM python:3.11-slim

RUN apt-get update && apt-get install -y \
    hostapd iproute2 iw net-tools iptables \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app



COPY . .

RUN chmod +x entrypoint.sh

EXPOSE 5000

ENTRYPOINT ["./entrypoint.sh"]
