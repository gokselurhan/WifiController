#!/bin/bash
set -e

# 1) UPLINK_IFACE'i ya env'den ya default routing'ten al
if [ -z "$UPLINK_IFACE" ]; then
  UPLINK_IFACE=$(ip route show default 0.0.0.0/0 | awk '{print $5; exit}')
fi
echo "Uplink arayüzü: $UPLINK_IFACE"

# 2) WIFI_IFACE'i ya env'den ya ilk 'iw dev' Interface'den al
if [ -z "$WIFI_IFACE" ]; then
  WIFI_IFACE=$(iw dev | awk '$1=="Interface"{print $2; exit}')
fi
echo "Wi-Fi arayüzü: $WIFI_IFACE"

# 3) IPv4 forwarding aç
sysctl -w net.ipv4.ip_forward=1

# 4) Basit NAT kuralı (isterseniz kaldırabilirsiniz)
iptables -t nat -A POSTROUTING -o "$UPLINK_IFACE" -j MASQUERADE

# 5) DNSMASQ ile DHCP (Wi-Fi üzerinden IP dağıtmak için)
cat > /etc/dnsmasq.conf <<EOF
interface=$WIFI_IFACE
bind-interfaces
dhcp-range=192.168.50.10,192.168.50.100,12h
dhcp-option=3,192.168.50.1
dhcp-option=6,8.8.8.8,8.8.4.4
EOF
dnsmasq --conf-file=/etc/dnsmasq.conf

# 6) hostapd.conf varsa hostapd'yi başlat
if [ -f /etc/hostapd/hostapd.conf ]; then
  pkill hostapd || true
  hostapd -B /etc/hostapd/hostapd.conf
else
  echo "hostapd.conf bulunamadı; hostapd atlandı."
fi

# 7) Flask API'yi başlat
exec python app.py
