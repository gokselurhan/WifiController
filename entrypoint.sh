#!/usr/bin/env bash
# entrypoint.sh

set -e
echo ">>> Entrypoint başlatıldı"

# 1) Uplink ve Wi-Fi arayüzlerini tespit et
if [ -z "$UPLINK_IFACE" ]; then
  UPLINK_IFACE=$(ip route show default | awk '{print $5; exit}')
fi
echo "Uplink arayüzü: $UPLINK_IFACE"

if [ -z "$WIFI_IFACE" ]; then
  WIFI_IFACE=$(iw dev | awk '$1=="Interface"{print $2; exit}')
fi
echo "Wi-Fi arayüzü: $WIFI_IFACE"

# 2) Mevcut IP ayarlarını bridge'e taşıma
echo ">>> Bridge oluşturuluyor: br0"
ip link add name br0 type bridge || echo "br0 zaten mevcut"
ip link set dev br0 up

# Eğer uplink arayüzünde IP varsa bridge'e taşıyalım
CURRENT_IP=$(ip -4 addr show dev "$UPLINK_IFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+')
if [ -n "$CURRENT_IP" ]; then
  echo ">>> $UPLINK_IFACE üzerindeki IP ($CURRENT_IP) br0’e aktarılıyor"
  ip addr flush dev "$UPLINK_IFACE"
  ip addr add "$CURRENT_IP" dev br0
fi

# 3) Uplink ve Wi-Fi arayüzlerini bridge’e ekle
echo ">>> $UPLINK_IFACE ve $WIFI_IFACE bridge’e ekleniyor"
ip link set dev "$UPLINK_IFACE" master br0
ip link set dev "$WIFI_IFACE" master br0
ip link set dev "$WIFI_IFACE" up

# 4) hostapd konfigürasyonu (bridge=br0 eklendi)
echo ">>> hostapd.conf oluşturuluyor"
cat > /etc/hostapd/hostapd.conf <<EOF
interface=$WIFI_IFACE
driver=nl80211
ssid=${SSID:-MyAP}
hw_mode=g
channel=${CHANNEL:-6}
wmm_enabled=1
bridge=br0
EOF

# 5) hostapd’i başlat
echo ">>> hostapd başlatılıyor"
pkill hostapd || true
hostapd -B /etc/hostapd/hostapd.conf || echo "Uyarı: hostapd başlatılamadı"

# 6) Flask API'yi çalıştır
echo ">>> Flask API başlatılıyor"
exec python app.py
