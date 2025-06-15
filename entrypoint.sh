#!/usr/bin/env bash
set -e

BRIDGE=${BRIDGE:-br0}
UPLINK=${UPLINK_IFACE:-ens192}
WIFI_IFACE=${WIFI_IFACE:-wls160}

echo ">>> Bridge: $BRIDGE, Uplink: $UPLINK, Wi-Fi: $WIFI_IFACE"

# 1) Bridge oluştur (varsa hata vermez)
ip link add name "$BRIDGE" type bridge 2>/dev/null || true
ip link set dev "$BRIDGE" up

# 2) Önce eski köprülemeyi kaldır (eğer önceden master yapılmışlarsa)
for IF in $(bridge link | awk -v br="$BRIDGE" '$1==br{print $4}'); do
  ip link set dev "$IF" nomaster
done

# 3) Uplink ve Wi-Fi’ı bridge’e ekle
ip link set dev "$UPLINK" up
ip link set dev "$WIFI_IFACE" up
ip link set dev "$UPLINK" master "$BRIDGE"
ip link set dev "$WIFI_IFACE" master "$BRIDGE"

# 4) hostapd.conf hazırla (tek SSID örnek)
cat > /etc/hostapd/hostapd.conf <<EOF
interface=$WIFI_IFACE
driver=nl80211
ssid=${SSID}
hw_mode=g
channel=${CHANNEL}
bridge=$BRIDGE
EOF

# 5) Hostapd başlat
echo ">>> Starting hostapd…"
hostapd -B /etc/hostapd/hostapd.conf

# 6) (İsteğe bağlı) Ek bir Guest SSID isterseniz,
#    hostapd multi-BSS ile şöyle ekleyebilirsiniz:
# bridge=$GUEST_BRIDGE
# bss=$WIFI_IFACE-guest
# ssid=$GUEST_SSID
#
# Aynı mantıkla başka köprüler (br_guest vb) da entrypoint’te 
# ip link add …, ip link set nomaster/ master …  
# ve hostapd.conf’a bss blokları ile eklenir.

# 7) Flask API başlat
echo ">>> Starting Flask…"
exec python app.py --host=0.0.0.0 --port=5000
