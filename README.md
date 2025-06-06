# WifiController

**Linux'u erişim noktası (Access Point) olarak kullanmak için geliştirilmiş web tabanlı arayüz.**  
Docker içinde çalışabilir, VLAN desteği sunar, QR kod ile kolay bağlantı sağlar.

---

## 🎯 Neden Bu Proje?

Benim ihtiyacım:  
Firewall (örneğin OPNsense) gibi sistemler WiFi kartlarını doğrudan desteklemiyor.  
Ayrı bir Linux sistem üzerinde wifi kartını passthru yaptıktan sonra WiFi yayın yapmak ve bu yayını VLAN + QR özellikleriyle kolayca yönetmek istedim.

Terminal kullanmak güzeldi ama her seferinde `hostapd`, `iw`, `nmcli` komutlarını yazmak yerine basit bir **arayüz ile SSID yönetimi** yapmak istedim.

---

## 🌐 Bu Proje Ne İşe Yarar?

- Bir Linux sistemini Access Point (AP) olarak kullanmanı sağlar
- SSID oluşturma, parola girme, VLAN ID tanımlama
- Yayınlanan her SSID için QR kod üretimi
- Arayüz üzerinden Düzenle / Sil / QR Göster işlemleri
- Docker içinde çalışabilir yapı
- İstenirse ileride Captive Portal gibi modüller eklenebilir

---

## 🛠️ Kullanım

### 1. Docker ile başlat

```bash
git clone https://github.com/goks elu/WifiController.git
cd WifiController
docker build -t wifi-controller-ui .
docker run -d --name wifi-ui -p 8080:80 wifi-controller-ui
