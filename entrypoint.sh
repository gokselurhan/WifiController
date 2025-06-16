#!/usr/bin/env bash
set -e

echo ">>> Entrypoint başladı"

# 1) Uplink arayüzünü bul
if [ -z "$UPLINK_IFACE" ]; then
  UPLINK_IFACE=$(ip route show default | awk '{print $5; exit}')
fi
echo "Uplink arayüzü: $UPLINK_IFACE"

# 2) Wi-Fi arayüzünü bul
if [ -z "$WIFI_IFACE" ]; then
  WIFI_IFACE=$(iw dev | awk '$1=="Interface"{print $2; exit}')
fi
echo "Wi-Fi arayüzü: $WIFI_IFACE"

# 3) Bridge oluştur ve hem uplink hem wifi’i içine al
BRIDGE="br0"
ip link add name $BRIDGE type bridge 2>/dev/null || true
ip link set dev $BRIDGE up

# Mevcut IP bilgisini kaydet
IP_CIDR=$(ip -4 addr show dev $UPLINK_IFACE | awk '/inet /{print $2; exit}')
GATEWAY=$(ip route show default | awk '/default/ {print $3; exit}')

# Uplink arayüzünden IP ve route’u temizle
ip addr flush dev $UPLINK_IFACE
ip link set dev $UPLINK_IFACE master $BRIDGE

# Wi-Fi arayüzünü bridge’e ata
ip link set dev $WIFI_IFACE master $BRIDGE
ip link set dev $WIFI_IFACE up

# IP ve varsayılan gateway’i bridge’e ata
ip addr add $IP_CIDR dev $BRIDGE
ip route add default via $GATEWAY dev $BRIDGE

echo "Bridge ($BRIDGE) kuruldu. IP: $IP_CIDR, GW: $GATEWAY"

# 4) hostapd.conf oluştur (bridge modu için)
cat > /etc/hostapd/hostapd.conf <<EOF
interface=$WIFI_IFACE
driver=nl80211
ssid=${SSID:-MyAP}
hw_mode=g
channel=${CHANNEL:-6}
wmm_enabled=1
bridge=$BRIDGE
EOF

echo "hostapd.conf hazırlandı"

# 5) hostapd’i başlat
pkill hostapd 2>/dev/null || true
echo "hostapd başlatılıyor..."
hostapd -B /etc/hostapd/hostapd.conf

# 6) Flask API’yi başlat
echo "Flask uygulaması başlatılıyor..."
exec python app.py
