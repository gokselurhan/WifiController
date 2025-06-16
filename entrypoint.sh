#!/bin/bash
set -e

# 1) Environment’den ya da default eth0
UPLINK_IFACE=${UPLINK_IFACE:-eth0}

# 2) IPv4 forwarding’i aktif et
sysctl -w net.ipv4.ip_forward=1

# 3) NAT: kablosuzdan gelen trafiği uplink’e masquerade et
iptables -t nat -A POSTROUTING -o "$UPLINK_IFACE" -j MASQUERADE

# 4) hostapd varsa arkaplanda başlat
if [ -f /etc/hostapd/hostapd.conf ]; then
  hostapd -B /etc/hostapd/hostapd.conf
else
  echo "hostapd config yok; atlandı."
fi

# 5) Flask uygulamasını çalıştır
exec python app.py
