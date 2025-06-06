// server.js içinde POST /api/ssids işlemi tamamlandıktan sonra:
const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');
// ...

// Hotspot’u açmak için hostapd.conf’u yeniden yaz:
const iface = yeni.iface;        // "wls160"
const ssid = yeni.ssid;          // "TestSSID"
const pass = yeni.password;      // "TestPass123"
const cfgPath = '/home/wifiadmin/WifiController/hostapd.conf';

const conf = `
interface=${iface}
driver=nl80211
ssid=${ssid}
hw_mode=g
channel=6
wmm_enabled=1
auth_algs=1
wpa=2
wpa_passphrase=${pass}
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
`;
fs.writeFileSync(cfgPath, conf);

// Arayüzü down → hostapd → up
exec(`ip link set ${iface} down`, () => {
  exec(`hostapd ${cfgPath} -B`, (errHost) => {
    if (errHost) {
      console.error('hostapd başlatılamadı:', errHost);
      return res.json({ success: true, ssids: mevcutList, warn: 'hostapd başlatılamadı.' });
    }
    exec(`ip link set ${iface} up`, () => {
      console.log('Hostapd ile hotspot başlatıldı.');
      return res.json({ success: true, ssids: mevcutList });
    });
  });
});
