#!/bin/bash

# IPv4 forwarding aktif et
sysctl -w net.ipv4.ip_forward=1

# NAT (kablosuzdan geleni kabloluya yönlendirmek için)
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# hostapd varsa başlat
if [ -f /etc/hostapd/hostapd.conf ]; then
  hostapd -B /etc/hostapd/hostapd.conf
else
  echo "hostapd config dosyası yok, hostapd başlatılmadı."
fi

# Flask uygulamasını başlat
python app.py
