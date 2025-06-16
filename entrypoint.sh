#!/bin/bash
set -e

# 1) IPv4 forwarding aktif et
sysctl -w net.ipv4.ip_forward=1

# 2) NAT (kablosuzdan geleni kabloluya yönlendirmek için)
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# 3) Fiziksel phy cihazını tespit et (ilk bulunanı alıyoruz)
PHY=$(iw dev | awk '$1=="phy"{print $2; exit}')

# 4) Varsayılan AP arayüzünüzü bulun (örneğin wlan0)
PRIMARY_IFACE=$(iw dev | awk '$1=="Interface"{print $2; exit}')

# 5) Sanal AP arayüzü oluştur (wlan0_1) — destekliyorsa
if [ -n "$PHY" ] && [ -n "$PRIMARY_IFACE" ]; then
  if ! iw dev | grep -q "${PRIMARY_IFACE}_1"; then
    echo "Sanal AP arayüzü oluşturuluyor: ${PRIMARY_IFACE}_1"
    iw phy $PHY interface add ${PRIMARY_IFACE}_1 type __ap 2>/dev/null || \
      echo "Dikkat: Sanal AP arayüzü oluşturulamadı (sürücü desteklemiyor olabilir)"
  fi
fi

# 6) hostapd varsa başlat (multi-BSS destekliyorsa hem wlan0 hem wlan0_1’i konfigürasyonda yayınlayabilecek)
if [ -f /etc/hostapd/hostapd.conf ]; then
  echo "hostapd başlatılıyor..."
  hostapd -B /etc/hostapd/hostapd.conf
else
  echo "hostapd config dosyası yok, hostapd başlatılmadı."
fi

# 7) Flask uygulamasını çalıştır
exec python app.py
