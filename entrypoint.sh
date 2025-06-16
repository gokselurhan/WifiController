#!/bin/bash
set -e

# Ortam değişkenleri (docker-compose.yml içinde tanımlı)
UPLINK=${UPLINK:-ens192}
WIFI_IFACE=${WIFI_IFACE:-wls160}
BRIDGE=${BRIDGE:-br0}

# 1) Bridge yarat ve aktif et
ip link add name $BRIDGE type bridge 2>/dev/null || true
ip link set dev $BRIDGE up

# 2) Uplink & Wi-Fi’ı köprüye ekle
ip link set dev $UPLINK up
ip link set dev $WIFI_IFACE up
ip link set dev $UPLINK master $BRIDGE
ip link set dev $WIFI_IFACE master $BRIDGE

# 3) Uplink’ten eski IP’yi sil
ip addr flush dev $UPLINK

# 4) Bridge’e DHCP ile IP al
echo ">>> DHCP ile $BRIDGE üzerinden IP alınıyor…"
dhclient -v $BRIDGE

# 5) Lease dosyasından upstream DHCP sunucusunu bul
LEASE_FILE=$(ls /var/lib/dhcp/dhclient.* | grep $BRIDGE | head -1 || true)
if [ -f "$LEASE_FILE" ]; then
    DEFAULT_SERVER=$(grep server-identifier $LEASE_FILE \
                     | tail -1 | awk '{print $3}' | sed 's/;//')
    echo ">>> Tespit edilen DHCP sunucusu: $DEFAULT_SERVER"
else
    echo ">>> Lease dosyası bulunamadı: $LEASE_FILE"
fi

# 6) DHCP relay başlat (env ile override etme imkânı)
DHCP_SERVER="${DHCP_SERVER:-$DEFAULT_SERVER}"
if [ -n "$DHCP_SERVER" ]; then
    echo ">>> DHCP relay başlatılıyor: $WIFI_IFACE + $BRIDGE → $DHCP_SERVER"
    pkill dhcrelay 2>/dev/null || true
    dhcrelay -i $WIFI_IFACE -i $BRIDGE $DHCP_SERVER &
else
    echo ">>> DHCP sunucusu belirtilmedi; relay atlanıyor."
fi

# 7) hostapd’i arka planda başlat
echo ">>> hostapd başlatılıyor…"
hostapd -B /etc/hostapd/hostapd.conf

# 8) Flask uygulamasını başlat
exec python3 app.py
