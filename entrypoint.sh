#!/usr/bin/env bash
set -e

echo ">>> Entrypoint başlatıldı"

# 1) Arayüzleri tespit et
UPLINK_IFACE=${UPLINK_IFACE:-$(ip route show default | awk '{print $5; exit}')}
WIFI_IFACE=${WIFI_IFACE:-$(iw dev | awk '$1=="Interface"{print $2; exit}')}
echo "Uplink arayüzü: $UPLINK_IFACE"
echo "Wi-Fi arayüzü: $WIFI_IFACE"

# 2) Mevcut IP ve Gateway bilgilerini al
IP_WITH_CIDR=$(ip -4 addr show dev "$UPLINK_IFACE" \
  | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+')
GW=$(ip route show default | awk '/default/ {print $3; exit}')
echo "Taşınacak IP: $IP_WITH_CIDR, Gateway: $GW"

# 3) Bridge oluştur ve ayağa kaldır
echo ">>> br0 bridge’i kuruluyor"
ip link add name br0 type bridge 2>/dev/null || true
ip link set dev br0 up

# 4) Uplink IP’sini bridge’e taşı
if [ -n "$IP_WITH_CIDR" ]; then
  echo ">>> $UPLINK_IFACE üzerindeki IP br0’e taşınıyor"
  ip addr flush dev "$UPLINK_IFACE"
  ip addr add "$IP_WITH_CIDR" dev br0
fi

# 5) Default route’u güncelle
echo ">>> Varsayılan rota br0 üzerinden ayarlanıyor"
ip route del default dev "$UPLINK_IFACE" 2>/dev/null || true
ip route add default via "$GW" dev br0

# 6) Arayüzleri bridge’e ekle
echo ">>> $UPLINK_IFACE ve $WIFI_IFACE bridge’e ekleniyor"
ip link set dev "$UPLINK_IFACE" master br0
ip link set dev "$WIFI_IFACE" master br0
ip link set dev "$UPLINK_IFACE" up
ip link set dev "$WIFI_IFACE" up

# 7) hostapd konfigürasyonu (bridge=br0 ekli)
cat > /etc/hostapd/hostapd.conf <<EOF
interface=$WIFI_IFACE
driver=nl80211
ssid=${SSID:-MyAP}
hw_mode=g
channel=${CHANNEL:-6}
wmm_enabled=1
bridge=br0
EOF

# 8) hostapd’i başlat
echo ">>> hostapd başlatılıyor"
pkill hostapd 2>/dev/null || true
hostapd -B /etc/hostapd/hostapd.conf || echo "Uyarı: hostapd başlatılamadı"

# 9) Flask API’yi çalıştır
echo ">>> Flask API başlatılıyor"
exec python app.py
