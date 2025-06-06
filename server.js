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

// Aynı dizindeki statik dosyaları (index.html vb.) sunmak için:
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
      console.error('iw komut hatası:', stderr);
      return res.status(500).json({ error: 'Wi-Fi interface listelenemedi' });
    }
    const lines = stdout.split('\n');
    const interfaces = [];
    lines.forEach(line => {
      line = line.trim();
      if (line.startsWith('Interface ')) {
        const parts = line.split(' ');
        if (parts.length >= 2) interfaces.push(parts[1]);
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
    console.error('SSID verisi okunamadı:', e);
    return res.status(500).json({ error: 'SSID verisi yüklenemedi' });
  }
});

// 3) Yeni SSID ekleyen endpoint
app.post('/api/ssids', (req, res) => {
  const yeni = req.body;
  if (!yeni.ssid || !yeni.password || !yeni.iface) {
    return res.status(400).json({ error: 'Gerekli alanlar eksik' });
  }
  let mevcutList;
  try {
    mevcutList = JSON.parse(fs.readFileSync(SSID_DB_PATH, 'utf8'));
  } catch (e) {
    mevcutList = [];
  }
  const duplicate = mevcutList.find(
    item => item.ssid.toLowerCase() === yeni.ssid.toLowerCase()
  );
  if (duplicate) {
    return res.status(400).json({ error: `"${yeni.ssid}" zaten kayıtlı!` });
  }
  mevcutList.push(yeni);
  fs.writeFileSync(SSID_DB_PATH, JSON.stringify(mevcutList, null, 2), 'utf8');
  return res.json({ success: true, ssids: mevcutList });
});

// 4) Bir SSID’yi silen endpoint
app.delete('/api/ssids/:index', (req, res) => {
  const idx = parseInt(req.params.index, 10);
  if (isNaN(idx)) {
    return res.status(400).json({ error: 'Geçersiz index' });
  }
  try {
    let mevcutList = JSON.parse(fs.readFileSync(SSID_DB_PATH, 'utf8'));
    if (idx < 0 || idx >= mevcutList.length) {
      return res.status(404).json({ error: 'Index bulunamadı' });
    }
    mevcutList.splice(idx, 1);
    fs.writeFileSync(SSID_DB_PATH, JSON.stringify(mevcutList, null, 2), 'utf8');
    return res.json({ success: true, ssids: mevcutList });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'Silme işlemi başarısız' });
  }
});

app.listen(PORT, () => {
  console.log(`WiFi Controller API sunucusu port ${PORT}’te çalışıyor.`);
});
