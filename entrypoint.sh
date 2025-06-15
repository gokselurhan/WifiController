#!/usr/bin/env bash
set -e

echo ">>> Entrypoint başlatıldı"

# 1) Arayüzleri tespit et
UPLINK_IFACE=${UPLINK_IFACE:-$(ip route show default | awk '{print $5; exit}')}
WIFI_IFACE=${WIFI_IFACE:-$(iw dev | awk '$1=="Interface"{print $2; exit}')}

echo "Uplink: $UPLINK_IFACE, Wi-Fi: $WIFI_IFACE"

# 2) IP forwarding aç
sysctl -w net.ipv4.ip_forward=1 || true

# 3) iptables NAT kuralı
iptables -t nat -F
iptables -t nat -A POSTROUTING -o "$UPLINK_IFACE" -j MASQUERADE

# 4) dnsmasq konfigürasyonu (AP ağına DHCP)
cat > /etc/dnsmasq.conf <<EOF
interface=$WIFI_IFACE
dhcp-range=192.168.50.10,192.168.50.200,12h
dhcp-option=3,192.168.50.1
EOF

echo ">>> dnsmasq başlatılıyor"
dnsmasq --keep-in-foreground --conf-file=/etc/dnsmasq.conf &
sleep 1

# 5) hostapd konfigürasyonu
cat > /etc/hostapd/hostapd.conf <<EOF
interface=$WIFI_IFACE
driver=nl80211
ssid=${SSID}
hw_mode=g
channel=${CHANNEL}
wmm_enabled=1
EOF

echo ">>> hostapd başlatılıyor"
hostapd -B /etc/hostapd/hostapd.conf || echo "Uyarı: hostapd başlatılamadı"

# 6) Flask API
echo ">>> Flask API başlatılıyor"
exec python app.py
