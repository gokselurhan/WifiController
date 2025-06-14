#!/bin/bash
set -e

# 1) Eğer ortam değişkeni yoksa default route arayüzünü bul
if [ -z "$UPLINK_IFACE" ]; then
  UPLINK_IFACE=$(ip route show default 0.0.0.0/0 | awk '{print $5; exit}')
fi
echo "Uplink arayüzü: $UPLINK_IFACE"

# 2) AP arayüzünüzü ortamdan alın veya varsayılanı kullanın
if [ -z "$WIFI_IFACE" ]; then
  # Basitçe 'iw dev' komutuyla ilk Interface satırını alabilirsiniz
  WIFI_IFACE=$(iw dev | awk '$1=="Interface"{print $2; exit}')
fi
echo "Wi-Fi arayüzü: $WIFI_IFACE"

# 3) IPv4 forwarding’i aktif et
sysctl -w net.ipv4.ip_forward=1

# 4) (Opsiyonel) NAT gerekiyorsa
# iptables -t nat -A POSTROUTING -o "$UPLINK_IFACE" -j MASQUERADE

# 5) Mevcut br0 varsa kaldır
ip link show br0 &>/dev/null && ip link delete br0 type bridge

# 6) Yeni br0 oluştur, uplink ve wifi arayüzlerini ekle
ip link add name br0 type bridge
ip link set dev "$UPLINK_IFACE" master br0
ip link set dev "$WIFI_IFACE" master br0

# 7) Portları aktif et
ip link set dev "$UPLINK_IFACE" up
ip link set dev "$WIFI_IFACE" up
ip link set dev br0 up

# 8) hostapd varsa başlat
if [ -f /etc/hostapd/hostapd.conf ]; then
  pkill hostapd || true
  hostapd -B /etc/hostapd/hostapd.conf
else
  echo "hostapd.conf bulunamadı; hostapd atlandı."
fi

# 9) Flask uygulamasını çalıştır
exec python app.py
