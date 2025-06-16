#!/bin/bash
set -e

# Eğer START_NETWORK=yes verilmediyse, bridge/DHCP-relay/hostapd atlanacak.
if [ "$START_NETWORK" = "yes" ]; then
  echo ">>> NETWORK SETUP: Başlatılıyor…"

  UPLINK=${UPLINK:-ens192}
  WIFI_IFACE=${WIFI_IFACE:-wls160}
  BRIDGE=${BRIDGE:-br0}

  # 1) Bridge’i hazırla
  ip link add name $BRIDGE type bridge 2>/dev/null || true
  ip link set dev $BRIDGE up

  # 2) Uplink + Wi-Fi’ı köprüye ekle
  ip link set dev $UPLINK up
  ip link set dev $WIFI_IFACE up
  ip link set dev $UPLINK master $BRIDGE
  ip link set dev $WIFI_IFACE master $BRIDGE

  # 3) Uplink’ten IP sil, 4) DHCP ile bridge’e IP al
  ip addr flush dev $UPLINK
  echo ">>> DHCP ile $BRIDGE’e IP alınıyor…"
  dhclient -v $BRIDGE

  # 5) Lease’den DHCP sunucusunu tespit et
  LEASE_FILE=$(ls /var/lib/dhcp/dhclient.* | grep $BRIDGE | head -1 || true)
  if [ -f "$LEASE_FILE" ]; then
    DEFAULT_SERVER=$(grep server-identifier $LEASE_FILE \
                     | tail -1 | awk '{print $3}' | sed 's/;//')
    echo ">>> Bulunan DHCP sunucusu: $DEFAULT_SERVER"
  fi

  # 6) Relay’i başlat
  DHCP_SERVER="${DHCP_SERVER:-$DEFAULT_SERVER}"
  if [ -n "$DHCP_SERVER" ]; then
    echo ">>> DHCP relay: $WIFI_IFACE + $BRIDGE -> $DHCP_SERVER"
    pkill dhcrelay 2>/dev/null || true
    dhcrelay -i $WIFI_IFACE -i $BRIDGE $DHCP_SERVER &
  fi

  # 7) hostapd’i başlat
  echo ">>> hostapd başlatılıyor…"
  hostapd -B /etc/hostapd/hostapd.conf

else
  echo ">>> START_NETWORK!=yes; bridge/DHCP/hostapd atlandı."
fi

# Her koşulda önce Flask UI’yi ayağa kaldır
exec python3 app.py
