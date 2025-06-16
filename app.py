from flask import Flask, jsonify, request, send_from_directory
import subprocess
import os

app = Flask(__name__)

SSID_DOSYA = "/etc/hostapd/hostapd.conf"

def sinirli_ap_destegi_var_mi():
    """
    Cihazın birden fazla access point desteğini kontrol eder.
    Eğer "{ AP } <= 1" kısıtlaması varsa sadece 1 AP desteklenir.
    """
    try:
        result = subprocess.run(
            "iw list", shell=True, capture_output=True, text=True
        )
        lines = result.stdout.splitlines()
        bul = False
        for satir in lines:
            if "valid interface combinations" in satir:
                bul = True
            elif bul and "AP" in satir:
                komp = satir.replace(" ", "")
                return not ("AP}<=1" in komp)
        return True
    except:
        return True

@app.route('/')
def index():
    # index.html dosyasını sunar
    return send_from_directory('.', 'index.html')

@app.route('/api/interfaces')
def wifi_arayuzleri():
    """Sistemdeki Wi-Fi arayüzlerini döner."""
    try:
        result = subprocess.run(
            "iw dev | awk '$1==\"Interface\"{print $2}'",
            shell=True, capture_output=True, text=True
        )
        arayuzler = [l for l in result.stdout.splitlines() if l.strip()]
    except:
        arayuzler = []
    return jsonify({"interfaces": arayuzler})

@app.route('/api/ethinterfaces')
def tum_ag_arayuzleri():
    """
    /sys/class/net altındaki tüm ağ arayüzlerini (lo dahil)
    isim ve açıklama ile döner.
    """
    try:
        tum = sorted(os.listdir('/sys/class/net'))
    except Exception as e:
        print("Arayüz listeleme hatası:", e)
        tum = []

    def aciklama(iface: str) -> str:
        if iface == 'lo':
            return 'Döngü arayüzü (loopback)'
        if iface.startswith(('wl','wlan','wlp')):
            return 'Kablosuz (Wi-Fi) arayüz'
        if iface.startswith(('eth','enp','ens','eno','enx')):
            return 'Fiziksel Ethernet arayüzü'
        if iface == 'docker0':
            return 'Docker köprü ağı'
        if iface.startswith('br-'):
            return 'Köprü (bridge) arayüz'
        if iface.startswith('veth'):
            return 'Sanal Ethernet (container bağlantısı)'
        if iface.startswith('tun'):
            return 'TUN/TAP VPN arayüzü'
        if iface.startswith('wg'):
            return 'WireGuard VPN arayüzü'
        if iface.startswith('virbr'):
            return 'Libvirt köprü arayüzü'
        return 'Bilinmeyen arayüz'

    uplink_arayuzleri = [
        {"name": i, "description": aciklama(i)}
        for i in tum
    ]
    return jsonify({"interfaces": uplink_arayuzleri})

@app.route('/api/ssids', methods=['GET', 'POST'])
def ssid_yonetimi():
    """
    GET  -> Mevcut SSID konfigürasyonlarını döner.
    POST -> Yeni SSID ekler veya var olanı günceller.
    """
    if request.method == 'GET':
        if not os.path.exists(SSID_DOSYA):
            return jsonify({"ssids": []})
        with open(SSID_DOSYA) as f:
            satirlar = f.readlines()
        # TODO: hostapd.conf içeriğini parse edip gerçek SSID listesini döndürün
        return jsonify({"ssids": []})
    else:
        # TODO: request.json içinden ssid, password, vlan bilgilerini alıp kaydedin
        return jsonify({"message": "SSID eklendi/güncellendi"}), 201

@app.route('/api/ssids/<int:index>', methods=['DELETE'])
def ssid_sil(index):
    """
    Belirtilen indeksteki SSID’i siler.
    (Örnek olarak tüm hostapd.conf’u siliyor, ihtiyaca göre değiştirin.)
    """
    if os.path.exists(SSID_DOSYA):
        os.remove(SSID_DOSYA)
    subprocess.run(["pkill", "hostapd"], check=False)
    return jsonify({"message": "SSID silindi"}), 200

if __name__ == '__main__':
    # Host ağında 0.0.0.0 üzerinden dinle
    app.run(host="0.0.0.0", port=5000)
