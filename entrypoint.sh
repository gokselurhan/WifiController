#!/bin/bash
set -e

# Ortam değişkenlerini al
DHCP_SERVERS=${DHCP_RELAY_SERVERS:-192.168.1.1}
UPLINK_IFACE=${UPLINK_INTERFACE:-eth0}

# 1) IPv4 forwarding aktif et
/sbin/sysctl -w net.ipv4.ip_forward=1

# 2) DHCP Relay konfigürasyonu
echo "DHCP Relay konfigürasyonu yapılıyor..."
cat > /etc/default/isc-dhcp-relay <<EOF
# Otomatik oluşturuldu - WiFi Kontrol Paneli
SERVERS="$DHCP_SERVERS"
INTERFACES=""
OPTIONS=""
EOF

# 3) Fiziksel phy cihazını tespit et
PHY=$(iw dev | awk '$1=="phy"{print $2; exit}')

# 4) Varsayılan AP arayüzünüzü bulun
PRIMARY_IFACE=$(iw dev | awk '$1=="Interface"{print $2; exit}')

# 5) Sanal AP arayüzü oluştur
if [ -n "$PHY" ] && [ -n "$PRIMARY_IFACE" ]; then
  if ! iw dev | grep -q "${PRIMARY_IFACE}_1"; then
    echo "Sanal AP arayüzü oluşturuluyor: ${PRIMARY_IFACE}_1"
    iw phy $PHY interface add ${PRIMARY_IFACE}_1 type __ap 2>/dev/null || \
      echo "Dikkat: Sanal AP arayüzü oluşturulamadı (sürücü desteklemiyor olabilir)"
  fi
fi

# 6) hostapd varsa başlat
if [ -f /etc/hostapd/hostapd.conf ]; then
  echo "hostapd başlatılıyor..."
  hostapd -B /etc/hostapd/hostapd.conf
else
  echo "hostapd config dosyası yok, hostapd başlatılmadı."
fi

# 7) DHCP Relay servisini başlat
echo "DHCP Relay başlatılıyor..."
service isc-dhcp-relay restart

# 8) NAT kurallarını uygula
echo "NAT kuralları ayarlanıyor..."
iptables -t nat -A POSTROUTING -o $UPLINK_IFACE -j MASQUERADE

# 9) Flask uygulamasını çalıştır
exec python app.py
