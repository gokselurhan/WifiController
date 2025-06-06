// server.js

const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = 3000;
const SSID_DB_PATH = path.join(__dirname, 'ssids.json');
const HOSTAPD_CONF_PATH = path.join(__dirname, 'hostapd.conf');

// Statik dosyaları sunmak (index.html vb.)
app.use(express.static(__dirname));
app.use(cors());
app.use(bodyParser.json());

// Eğer ssids.json yoksa, boş bir dizi ile oluştur
if (!fs.existsSync(SSID_DB_PATH)) {
  fs.writeFileSync(SSID_DB_PATH, JSON.stringify([]), 'utf8');
}

// 1) Wi-Fi arayüzlerini listeleyen endpoint
app.get('/api/interfaces', (req, res) => {
  exec('iw dev', (err, stdout, stderr) => {
    if (err) {
      console.error('iw komut hatası:', stderr.trim());
      return res.status(500).json({ error: 'Wi-Fi arayüzleri listelenemedi.' });
    }
    const lines = stdout.split('\n');
    const interfaces = [];
    lines.forEach(line => {
      line = line.trim();
      if (line.startsWith('Interface ')) {
        const parts = line.split(' ');
        if (parts.length >= 2) {
          interfaces.push(parts[1]);
        }
      }
    });
    return res.json({ interfaces });
  });
});

// 2) Kayıtlı SSID’leri dönen endpoint
app.get('/api/ssids', (req, res) => {
  try {
    const data = fs.readFileSync(SSID_DB_PATH, 'utf8');
    const ssids = JSON.parse(data);
    return res.json({ ssids });
  } catch (e) {
    console.error('ssids.json okunamadı:', e);
    return res.status(500).json({ error: 'SSID verisi yüklenemedi.' });
  }
});

// 3) Yeni SSID ekleyen ve hostapd ile hotspot başlatan endpoint
app.post('/api/ssids', (req, res) => {
  const yeni = req.body;
  // Zorunlu alan kontrolü
  if (!yeni.ssid || !yeni.password || !yeni.iface) {
    return res.status(400).json({ error: 'Gerekli alanlar eksik.' });
  }

  let mevcutList;
  try {
    mevcutList = JSON.parse(fs.readFileSync(SSID_DB_PATH, 'utf8'));
  } catch {
    mevcutList = [];
  }

  // Aynı SSID var mı kontrolü
  const duplicate = mevcutList.find(
    item => item.ssid.toLowerCase() === yeni.ssid.toLowerCase()
  );
  if (duplicate) {
    return res.status(400).json({ error: `"${yeni.ssid}" zaten kayıtlı!` });
  }

  // Yeni SSID’yi listeye ekle ve dosyaya yaz
  mevcutList.push(yeni);
  try {
    fs.writeFileSync(SSID_DB_PATH, JSON.stringify(mevcutList, null, 2), 'utf8');
  } catch (e) {
    console.error('ssids.json yazılamadı:', e);
    return res.status(500).json({ error: 'SSID verisi kaydedilemedi.' });
  }

  // --------------------------------------------------------
  // Hostapd ile hotspot başlatma
  // --------------------------------------------------------
  const iface = yeni.iface;       // Örn: "wls160"
  const ssid  = yeni.ssid;        // Örn: "TestSSID"
  const pass  = yeni.password;    // Örn: "TestPass123"

  // hostapd.conf dosyasını güncelle
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
`.trim();

  try {
    fs.writeFileSync(HOSTAPD_CONF_PATH, conf, 'utf8');
  } catch (e) {
    console.error('hostapd.conf yazılamadı:', e);
    return res.status(500).json({ error: 'hostapd.conf kaydedilemedi.' });
  }

  // Adım 1: Arayüzü down yap
  exec(`ip link set ${iface} down`, (downErr) => {
    if (downErr) {
      console.error(`Arayüz down hatası (${iface}):`, downErr);
      // Yine devam edelim, belki down olmadan da çalışır
    }
    // Adım 2: Hostapd’i arka planda başlat
    exec(`hostapd ${HOSTAPD_CONF_PATH} -B`, (hostErr, stdout, stderr) => {
      if (hostErr) {
        console.error('hostapd başlatılamadı:', stderr.trim());
        return res.json({ success: true, ssids: mevcutList, warn: 'Hotspot başlatılamadı.' });
      }
      // Adım 3: Arayüzü up yap
      exec(`ip link set ${iface} up`, (upErr) => {
        if (upErr) {
          console.error(`Arayüz up hatası (${iface}):`, upErr);
          return res.json({ success: true, ssids: mevcutList, warn: 'Arayüz up yapılamadı.' });
        }
        console.log('Hostapd ile hotspot başarıyla başlatıldı.');
        return res.json({ success: true, ssids: mevcutList });
      });
    });
  });
  // --------------------------------------------------------
});

// 4) Belirli index’teki SSID’yi silen endpoint
app.delete('/api/ssids/:index', (req, res) => {
  const idx = parseInt(req.params.index, 10);
  if (isNaN(idx)) {
    return res.status(400).json({ error: 'Geçersiz index.' });
  }

  try {
    let mevcutList = JSON.parse(fs.readFileSync(SSID_DB_PATH, 'utf8'));
    if (idx < 0 || idx >= mevcutList.length) {
      return res.status(404).json({ error: 'Index bulunamadı.' });
    }
    const silinen = mevcutList.splice(idx, 1)[0];
    fs.writeFileSync(SSID_DB_PATH, JSON.stringify(mevcutList, null, 2), 'utf8');
    console.log(`"${silinen.ssid}" SSID silindi.`);

    // Hostapd’yi durdurmak için
    exec(`pkill hostapd`, (killErr) => {
      if (killErr) {
        console.warn('hostapd sonlandırılamadı veya zaten kapalı.');
      }
      // Arayüzü yeniden managed moda al (opsiyonel)
      exec(`ip link set ${silinen.iface} down && ip link set ${silinen.iface} up`, () => {
        return res.json({ success: true, ssids: mevcutList });
      });
    });
  } catch (e) {
    console.error('Silme işlemi başarısız:', e);
    return res.status(500).json({ error: 'Silme işlemi başarısız.' });
  }
});

// Sunucuyu dinle
app.listen(PORT, () => {
  console.log(`WiFi Controller API sunucusu port ${PORT}’te çalışıyor.`);
});
