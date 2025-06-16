from flask import Flask, jsonify, request, send_from_directory
import subprocess
import os

app = Flask(__name__)

SSID_FILE = "/etc/hostapd/hostapd.conf"

def check_ap_limit():
    """Cihazın birden fazla AP (access point) desteğini kontrol eder."""
    try:
        result = subprocess.run(
            "iw list", shell=True, capture_output=True, text=True
        )
        lines = result.stdout.splitlines()
        combo_section = False
        for line in lines:
            if "valid interface combinations" in line:
                combo_section = True
            elif combo_section:
                compact = line.replace(" ", "")
                if "AP" in line:
                    # "{ AP } <=1" kısıtlaması varsa sadece 1 AP desteği var
                    return not ("AP}<=1" in compact)
        return True
    except Exception:
        return True

@app.route('/')
def index():
    # index.html'i sun
    return send_from_directory('.', 'index.html')

@app.route('/api/interfaces')
def wifi_interfaces():
    """Sistemdeki Wi-Fi arayüzlerini döner."""
    try:
        result = subprocess.run(
            "iw dev | awk '$1==\"Interface\"{print $2}'",
            shell=True, capture_output=True, text=True
        )
        interfaces = [l for l in result.stdout.splitlines() if l.strip()]
    except Exception:
        interfaces = []
    return jsonify({"interfaces": interfaces})

@app.route('/api/ethinterfaces')
def eth_interfaces():
    """
    Loopback (lo) hariç tüm sistem arayüzlerini döner.
    Böylece hem fiziksel, hem docker0, tun*, br-*, vs. listelenir.
    """
    try:
        all_ifaces = os.listdir('/sys/class/net')
        uplink_ifaces = [iface for iface in all_ifaces if iface != 'lo']
    except Exception as e:
        print("Error listing interfaces:", e)
        uplink_ifaces = []
    return jsonify({"interfaces": uplink_ifaces})

@app.route('/api/ssids', methods=['GET', 'POST'])
def manage_ssids():
    """
    GET  -> Mevcut SSID konfigürasyonlarını döner.
    POST -> Yeni bir SSID ekler veya var olanı günceller.
    """
    if request.method == 'GET':
        if not os.path.exists(SSID_FILE):
            return jsonify({"ssids": []})
        with open(SSID_FILE) as f:
            lines = f.readlines()
        # TODO: lines içinden hostapd.conf parsing yapıp döndürün
        return jsonify({"ssids": []})

    else:
        # TODO: request.json içinden ssid, password, vlan bilgilerini alıp kaydedin
        return jsonify({"message": "SSID eklendi/güncellendi"}), 201

@app.route('/api/ssids/<int:index>', methods=['DELETE'])
def delete_ssid(index):
    """
    Belirtilen indeksteki SSID’i siler.
    (Örnek: tüm hostapd.conf’u siliyor; ihtiyacınıza göre özelleştirin.)
    """
    if os.path.exists(SSID_FILE):
        os.remove(SSID_FILE)
    subprocess.run(["pkill", "hostapd"], check=False)
    return jsonify({"message": "SSID silindi"}), 200

if __name__ == '__main__':
    app.run(host="0.0.0.0", port=5000)
