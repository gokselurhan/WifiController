#!/bin/bash
set -e

# IPv4 forwarding
sysctl -w net.ipv4.ip_forward=1

# Uplink arayüzü (env ile gelir, yoksa eth0)
UPLINK_IFACE=${UPLINK_IFACE:-eth0}

# NAT: wlan0 → uplink
iptables -t nat -A POSTROUTING -o "$UPLINK_IFACE" -j MASQUERADE

# Hostapd başlat (varsa)
if [ -f /etc/hostapd/hostapd.conf ]; then
  hostapd -B /etc/hostapd/hostapd.conf
else
  echo "hostapd config yok. Atlanıyor."
fi

# Flask API’yi başlat
exec python app.py
