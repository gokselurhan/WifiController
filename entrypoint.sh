#!/bin/bash
set -e

# Ortam değişkenlerini al
DHCP_SERVERS=${DHCP_RELAY_SERVERS:-192.168.1.1}
UPLINK_IFACE=${UPLINK_INTERFACE:-eth0}

# 1) IPv4 forwarding aktif et
/sbin/sysctl -w net.ipv4.ip_forward=1

# 2) DHCP Relay konfigürasyonu
echo "DHCP Relay konfigürasyonu yapılıyor..."
mkdir -p /etc/default
cat > /etc/default/isc-dhcp-relay <<EOF
# Otomatik oluşturuldu - WiFi Kontrol Paneli
SERVERS="$DHCP_SERVERS"
INTERFACES=""
OPTIONS=""
EOF

# 3) hostapd.conf için dizin oluştur
mkdir -p /etc/hostapd
touch /etc/hostapd/hostapd.conf

# 4) Fiziksel phy cihazını tespit et
PHY=$(iw dev | awk '$1=="phy"{print $2; exit}')

# 5) Varsayılan AP arayüzünüzü bulun
PRIMARY_IFACE=$(iw dev | awk '$1=="Interface"{print $2; exit}')

# 6) Sanal AP arayüzü oluştur
if [ -n "$PHY" ] && [ -n "$PRIMARY_IFACE" ]; then
  if ! iw dev | grep -q "${PRIMARY_IFACE}_1"; then
    echo "Sanal AP arayüzü oluşturuluyor: ${PRIMARY_IFACE}_1"
    iw phy $PHY interface add ${PRIMARY_IFACE}_1 type __ap 2>/dev/null || \
      echo "Dikkat: Sanal AP arayüzü oluşturulamadı"
  fi
fi

# 7) hostapd başlat
echo "hostapd başlatılıyor..."
hostapd -B /etc/hostapd/hostapd.conf || echo "hostapd başlatılamadı"

# 8) DHCP Relay servisini başlat
echo "DHCP Relay başlatılıyor..."
service isc-dhcp-relay restart

# 9) NAT kurallarını uygula
echo "NAT kuralları ayarlanıyor..."
iptables -t nat -A POSTROUTING -o $UPLINK_IFACE -j MASQUERADE

# 10) Flask uygulamasını çalıştır
exec python app.py
