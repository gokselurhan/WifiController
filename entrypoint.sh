#!/usr/bin/env bash
# entrypoint.sh

set -e
echo ">>> Entrypoint başlatıldı"

# 1) Uplink arayüzünü belirle
if [ -z "$UPLINK_IFACE" ]; then
  UPLINK_IFACE=$(ip route show default | awk '{print $5; exit}')
fi
echo "Uplink arayüzü: $UPLINK_IFACE"

# 2) Wi-Fi arayüzünü belirle
if [ -z "$WIFI_IFACE" ]; then
  WIFI_IFACE=$(iw dev | awk '$1=="Interface"{print $2; exit}')
fi
echo "Wi-Fi arayüzü: $WIFI_IFACE"

# 3) IPv4 forwarding aç (hata verse de devam et)
echo "IPv4 forwarding açılıyor"
sysctl -w net.ipv4.ip_forward=1 || true

# 4) iptables ile NAT ve forward kuralları
echo "iptables NAT kuralları uygulanıyor"
iptables -t nat -F || true
iptables -F || true
iptables -t nat -A POSTROUTING -o "$UPLINK_IFACE" -j MASQUERADE
iptables -A FORWARD -i "$UPLINK_IFACE" -o "$WIFI_IFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i "$WIFI_IFACE" -o "$UPLINK_IFACE" -j ACCEPT

# 5) hostapd.conf oluştur
echo "hostapd.conf oluşturuluyor"
cat > /etc/hostapd/hostapd.conf <<EOF
interface=$WIFI_IFACE
driver=nl80211
ssid=${SSID:-MyAP}
hw_mode=g
channel=${CHANNEL:-6}
wmm_enabled=1
EOF

# 6) dnsmasq.conf oluştur
echo "dnsmasq.conf oluşturuluyor"
cat > /etc/dnsmasq.conf <<EOF
interface=$WIFI_IFACE
dhcp-range=192.168.50.10,192.168.50.200,12h
dhcp-option=3,192.168.50.1
dhcp-option=6,8.8.8.8,8.8.4.4
EOF

# 7) dnsmasq başlat (hata verse bile devam et)
echo "dnsmasq başlatılıyor"
dnsmasq --conf-file=/etc/dnsmasq.conf || echo "Uyarı: dnsmasq başlatılamadı"

# 8) hostapd başlat (hata verse de devam et)
if [ -f /etc/hostapd/hostapd.conf ]; then
  echo "hostapd başlatılıyor"
  pkill hostapd || true
  hostapd -B /etc/hostapd/hostapd.conf || echo "Uyarı: hostapd başlatılamadı"
else
  echo "hostapd.conf bulunamadı; hostapd atlandı."
fi

# 9) Flask API'yi çalıştır
echo "Flask API başlatılıyor"
exec python app.py
