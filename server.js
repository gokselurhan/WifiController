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

// Statik dosyaları sunmak (index.html, CSS/JS dosyaları vb.)
app.use(express.static(__dirname));
app.use(cors());
app.use(bodyParser.json());

// Eğer ssids.json yoksa, başlangıçta boş bir dizi olarak oluştur
if (!fs.existsSync(SSID_DB_PATH)) {
  fs.writeFileSync(SSID_DB_PATH, JSON.stringify([]), 'utf8');
}

// 1) Wi-Fi arayüzlerini listeleyen endpoint
app.get('/api/interfaces', (req, res) => {
  exec('iw dev', (err, stdout, stderr) => {
    if (err) {
      console.error('iw komut hatası:', stderr);
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

// 3) Yeni SSID ekleyen ve aynı zamanda hotspot’u başlatan endpoint
app.post('/api/ssids', (req, res) => {
  const yeni = req.body;
  // Zorunlu alan kontrolü
  if (!yeni.ssid || !yeni.password || !yeni.iface) {
    return res.status(400).json({ error: 'Gerekli alanlar eksik.' });
  }

  let mevcutList;
  try {
    mevcutList = JSON.parse(fs.readFileSync(SSID_DB_PATH, 'utf8'));
  } catch (e) {
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
  // nmcli komutları ile hotspot başlatma
  // --------------------------------------------------------
  const iface   = yeni.iface;      // Örn: "wls160"
  const ssid    = yeni.ssid;       // Örn: "EvSSID"
  const pass    = yeni.password;   // Örn: "Parola123"
  const conName = `AP-${ssid}`;    // Örn: "AP-EvSSID"

  // (a) Önce varsa aynı ada sahip bağlantıyı sil
  exec(`nmcli connection delete "${conName}"`, (deleteErr, deleteStdout, deleteStderr) => {
    // Silme hatası olsa bile devam ediliyor; silinemeyen bağlantı olmayabilir
    if (deleteErr) {
      console.warn(`"` + conName + `" bağlantısı silinemedi veya yok:`, deleteStderr.trim());
    }

    // (b) Yeni hotspot oluştur
    const cmd = `nmcli dev wifi hotspot ifname ${iface} con-name "${conName}" ssid "${ssid}" password "${pass}"`;
    exec(cmd, (err2, stdout2, stderr2) => {
      if (err2) {
        console.error('Hotspot başlatılamadı:', stderr2.trim());
        // Yine de ekleme başarılı sayıyoruz; frontend'e uyarı gönderiyoruz
        return res.json({
          success: true,
          ssids: mevcutList,
          warn: 'Hotspot başlatılamadı. (nmcli hatası)'
        });
      }
      console.log('Hotspot başarıyla başlatıldı:', stdout2.trim());
      return res.json({ success: true, ssids: mevcutList });
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

    // Silinen SSID varsa, aynı named connection'ı da silelim
    const conNameToDelete = `AP-${silinen.ssid}`;
    exec(`nmcli connection delete "${conNameToDelete}"`, (delErr) => {
      if (delErr) {
        console.warn(`Eski bağlantı "${conNameToDelete}" silinemedi veya yok.`);
      } else {
        console.log(`Eski bağlantı "${conNameToDelete}" silindi.`);
      }
      return res.json({ success: true, ssids: mevcutList });
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
