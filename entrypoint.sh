#!/bin/bash
set -e

# Ortam değişkenlerini al
DHCP_SERVERS=${DHCP_RELAY_SERVERS:-192.168.1.1}
UPLINK_IFACE=${UPLINK_INTERFACE:-eth0}

# IPv4 forwarding aktif et - KALDIRILDI (host network'te izin verilmiyor)

# VLAN desteği için kernel modülünü yükle
echo "8021q" >> /etc/modules
modprobe 8021q

# DHCP Relay konfigürasyonu
echo "DHCP Relay konfigürasyonu yapılıyor..."
cat > /etc/default/isc-dhcp-relay <<EOF
# Otomatik oluşturuldu - WiFi Kontrol Paneli
SERVERS="$DHCP_SERVERS"
INTERFACES="$UPLINK_IFACE"
OPTIONS="-d"
EOF

# Fiziksel phy cihazını tespit et
PHY=$(iw dev | awk '$1=="phy"{print $2; exit}')

# Varsayılan AP arayüzünüzü bulun
PRIMARY_IFACE=$(iw dev | awk '$1=="Interface"{print $2; exit}')

# Sanal AP arayüzü oluştur
if [ -n "$PHY" ] && [ -n "$PRIMARY_IFACE" ]; then
  if ! iw dev | grep -q "${PRIMARY_IFACE}_1"; then
    echo "Sanal AP arayüzü oluşturuluyor: ${PRIMARY_IFACE}_1"
    iw phy $PHY interface add ${PRIMARY_IFACE}_1 type __ap 2>/dev/null || \
      echo "Dikkat: Sanal AP arayüzü oluşturulamadı (sürücü desteklemiyor olabilir)"
  fi
fi

# hostapd için varsayılan konfig dosyası oluştur
if [ ! -f /etc/hostapd/hostapd.conf ]; then
  echo "interface=$PRIMARY_IFACE" > /etc/hostapd/hostapd.conf
  echo "driver=nl80211" >> /etc/hostapd/hostapd.conf
  echo "ssid=Default-WiFi" >> /etc/hostapd/hostapd.conf
  echo "hw_mode=g" >> /etc/hostapd/hostapd.conf
  echo "channel=6" >> /etc/hostapd/hostapd.conf
  echo "wpa=2" >> /etc/hostapd/hostapd.conf
  echo "wpa_passphrase=password123" >> /etc/hostapd/hostapd.conf
  echo "wpa_key_mgmt=WPA-PSK" >> /etc/hostapd/hostapd.conf
  echo "rsn_pairwise=CCMP" >> /etc/hostapd/hostapd.conf
fi

# hostapd başlat
echo "hostapd başlatılıyor..."
if [ -s /etc/hostapd/hostapd.conf ]; then
  hostapd -B /etc/hostapd/hostapd.conf || echo "hostapd başlatılamadı"
else
  echo "Uyarı: hostapd.conf dosyası boş, hostapd başlatılmadı"
fi

# DHCP Relay servisini başlat
echo "DHCP Relay başlatılıyor..."
service isc-dhcp-relay restart

# NAT kurallarını uygula
echo "NAT kuralları ayarlanıyor..."
iptables -t nat -F POSTROUTING
iptables -t nat -A POSTROUTING -o $UPLINK_IFACE -j MASQUERADE

# Flask uygulamasını çalıştır
exec python app.py
