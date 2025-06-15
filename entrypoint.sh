#!/usr/bin/env bash
set -e

echo ">>> Entrypoint başlatıldı"

# 1) Arayüzlerin isimlerini al
UPLINK_IFACE=${UPLINK_IFACE:-$(ip route show default | awk '{print $5; exit}')}
WIFI_IFACE=${WIFI_IFACE:-$(iw dev | awk '$1=="Interface"{print $2; exit}')}

echo "Uplink iface: $UPLINK_IFACE"
echo "Wi-Fi iface: $WIFI_IFACE"

# 2) Arayüzleri mutlaka 'up' yap
ip link set dev "$UPLINK_IFACE" up
ip link set dev "$WIFI_IFACE" up

# 3) hostapd.conf oluştur
cat > /etc/hostapd/hostapd.conf <<EOF
interface=$WIFI_IFACE
driver=nl80211
ssid=${SSID:-MyAP}
hw_mode=g
channel=${CHANNEL:-6}
wmm_enabled=1
EOF

# 4) hostapd’i başlat
echo ">>> hostapd başlatılıyor"
hostapd -B /etc/hostapd/hostapd.conf

# 5) Upstream DHCP sunucusunu otomatik bul
UPSTREAM_DHCP=${DHCP_SERVER:-$(ip route show default | awk '/default/ {print $3; exit}')}

echo ">>> DHCP Relay: dinle [$WIFI_IFACE] + [$UPLINK_IFACE] → upstream $UPSTREAM_DHCP"
# 6) dhcrelay’i hem AP hem uplink üzerinde dinleyecek şekilde başlat
dhcrelay -i "$WIFI_IFACE" -i "$UPLINK_IFACE" "$UPSTREAM_DHCP" &

# 7) Flask API
echo ">>> Flask API başlatılıyor"
exec python app.py
