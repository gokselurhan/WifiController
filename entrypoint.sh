#!/usr/bin/env bash
# entrypoint.sh

set -e
echo ">>> Entrypoint başlatıldı"

# 1) Uplink ve Wi-Fi arayüzlerini tespit et
if [ -z "$UPLINK_IFACE" ]; then
  UPLINK_IFACE=$(ip route show default | awk '{print $5; exit}') || true
fi
echo "Uplink arayüzü: $UPLINK_IFACE"

if [ -z "$WIFI_IFACE" ]; then
  WIFI_IFACE=$(iw dev | awk '$1=="Interface"{print $2; exit}') || true
fi
echo "Wi-Fi arayüzü: $WIFI_IFACE"

# 2) Bridge oluşturma ve IP taşıma
echo ">>> Bridge oluşturuluyor: br0"
ip link add name br0 type bridge 2>/dev/null || echo "br0 zaten mevcut"
ip link set dev br0 up 2>/dev/null || echo "br0 up hatası yoksayıldı"

CURRENT_IP=$(ip -4 addr show dev "$UPLINK_IFACE" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' ) || true
if [ -n "$CURRENT_IP" ]; then
  echo ">>> $UPLINK_IFACE üzerindeki IP ($CURRENT_IP) br0’e aktarılıyor"
  ip addr flush dev "$UPLINK_IFACE" 2>/dev/null || echo "flush hatası yoksayıldı"
  ip addr add "$CURRENT_IP" dev br0 2>/dev/null || echo "IP ekleme hatası yoksayıldı"
fi

# 3) Arayüzleri bridge’e ekleme
echo ">>> $UPLINK_IFACE ve $WIFI_IFACE bridge’e ekleniyor"
ip link set dev "$UPLINK_IFACE" master br0 2>/dev/null || echo "uplink master hatası yoksayıldı"
ip link set dev "$WIFI_IFACE" master br0 2>/dev/null || echo "wifi master hatası yoksayıldı"
ip link set dev "$WIFI_IFACE" up 2>/dev/null || echo "wifi up hatası yoksayıldı"

# 4) hostapd konfigürasyonu
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

# 5) hostapd’i çalıştır (başarısız olsa da devam et)
echo ">>> hostapd başlatılıyor"
pkill hostapd 2>/dev/null || true
hostapd -B /etc/hostapd/hostapd.conf 2>/dev/null || echo "Uyarı: hostapd başlatılamadı"

# 6) Flask API'yi kesin başlat
echo ">>> Flask API başlatılıyor"
exec python app.py
