FROM python:3.9-slim

RUN apt-get update && apt-get install -y \
    hostapd \
    dnsmasq \
    iw \
    net-tools \
    wpasupplicant \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY backend /app/backend
COPY frontend /app/frontend

RUN mkdir -p /etc/hostapd /etc/dnsmasq.d

EXPOSE 80

CMD ["python", "-m", "backend.app"]
