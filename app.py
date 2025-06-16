from flask import Flask, jsonify, request, send_from_directory
import subprocess
import os

app = Flask(__name__)

SSID_FILE = "/etc/hostapd/hostapd.conf"

def check_ap_limit():
    """Cihaz birden fazla AP destekliyor mu kontrol eder"""
    try:
        result = subprocess.run("iw list", shell=True, capture_output=True, text=True)
        lines = result.stdout.splitlines()
        combo_section = False
        for i, line in enumerate(lines):
            if "valid interface combinations" in line:
                combo_section = True
            elif combo_section:
                if "AP" in line:
                    if "AP } <= 1" in line.replace(" ", ""):
                        return False  # sadece 1 AP destekliyor
                    else:
                        return True
        return True  # AP kısıtlaması bulunamadıysa izin ver
    except:
        return True  # hata varsa engelleme

@app.route('/')
def index():
    return send_from_directory('.', 'index.html')

@app.route('/api/interfaces')
def interfaces():
    # Wi-Fi kartı listesi
    result = subprocess.run(
        "iw dev | awk '$1==\"Interface\"{print $2}'",
        shell=True, capture_output=True
    )
    interfaces = result.stdout.decode().strip().split("\n")
    interfaces = [i for i in interfaces if i]
    return jsonify({"interfaces": interfaces})

@app.route('/api/ethinterfaces')
def ethinterfaces():
    # Ethernet arayüzlerini listeler (eth* ile başlayanlar)
    try:
        output = subprocess.check_output("ls /sys/class/net", shell=True)
        all_ifaces = output.decode().split()
        eth_ifaces = [iface for iface in all_ifaces if iface.startswith("eth")]
    except Exception as e:
        print("Error listing Ethernet interfaces:", e)
        eth_ifaces = []
    return jsonify({"interfaces": eth_ifaces})

@app.route('/api/ssids', methods=['GET', 'POST'])
def manage_ssids():
    if request.method == 'GET':
        if not os.path.exists(SSID_FILE):
            return jsonify({"ssids": []})
        with open(SSID_FILE) as f:
            lines = f.readlines()
        # … Mevcut SSID okuma/parsing kodunuz …
        # return jsonify({"ssids": ssid_list})
    else:
        # POST ile SSID ekleme/güncelleme kodunuz
        # return jsonify({"message": "SSID eklendi"}), 201
        pass

@app.route('/api/ssids/<int:index>', methods=['DELETE'])
def delete_ssid(index):
    if os.path.exists(SSID_FILE):
        os.remove(SSID_FILE)
    subprocess.run(["pkill", "hostapd"], check=False)
    return jsonify({"message": "SSID silindi"}), 200

if __name__ == '__main__':
    app.run(host="0.0.0.0", port=5000)
