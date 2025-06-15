#!/usr/bin/env bash
set -e

# AP arayüzü
WIFI_IFACE=${WIFI_IFACE:-$(iw dev | awk '$1=="Interface"{print $2; exit}')}

# Upstream DHCP sunucusu (modem IP’si)
UPSTREAM_DHCP=${DHCP_SERVER:-$(ip route show default | awk '/default/ {print $3}')}

# 1) hostapd.conf — br0 ile birlikte çalışacak
cat > /etc/hostapd/hostapd.conf <<EOF
interface=$WIFI_IFACE
driver=nl80211
ssid=${SSID:-MyAP}
hw_mode=g
channel=${CHANNEL:-6}
wmm_enabled=1
bridge=br0
EOF

# 2) hostapd başlat
hostapd -B /etc/hostapd/hostapd.conf

# 3) DHCP relay başlat
echo ">>> DHCP relay: $WIFI_IFACE → $UPSTREAM_DHCP"
dhcrelay -i "$WIFI_IFACE" "$UPSTREAM_DHCP" &

# 4) Flask API
exec python app.py
