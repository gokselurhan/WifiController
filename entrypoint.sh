#!/bin/bash

# Kernel seviyesinde NAT routing ve forwarding açık mı
sysctl -w net.ipv4.ip_forward=1

# iptables NAT
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# İlk başta hostapd config yoksa başlatılmasın
if [ ! -f /etc/hostapd/hostapd.conf ]; then
  echo "hostapd config /etc/hostapd/hostapd.conf not found, not starting hostapd.."
else
  hostapd -B /etc/hostapd/hostapd.conf
fi

python app.py
