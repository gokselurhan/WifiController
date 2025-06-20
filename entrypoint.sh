#!/bin/bash
set -e

# Gerekirse hostapd vs. başka servisleri başlat
# hostapd -B /etc/hostapd/hostapd.conf

# Relay ayarlarını kontrol et ve başlat
RELAY_CONFIG="/etc/hostapd/relay_config.txt"
if [ -f "$RELAY_CONFIG" ]; then
  while read -r line; do
    IFACE=$(echo "$line" | cut -d: -f1)
    VLAN=$(echo "$line" | cut -d: -f2)
    # Burada DHCP sunucu IP'sini istersen arayüzden de alabilirsin, burada örnek olarak otomatik set:
    SERVER_IP="192.168.${VLAN}.1"
    echo "DHCP relay başlatılıyor: $IFACE -> $SERVER_IP"
    dhcrelay -i "$IFACE" "$SERVER_IP" &
  done < "$RELAY_CONFIG"
fi

# Flask uygulamasını başlat
exec python3 app.py
