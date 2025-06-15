FROM python:3.11-slim

# DHCP relay için isc-dhcp-relay ve AP için hostapd
RUN apt-get update && apt-get install -y \
    hostapd \
    isc-dhcp-relay \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
RUN chmod +x entrypoint.sh

EXPOSE 5000
ENTRYPOINT ["./entrypoint.sh"]
