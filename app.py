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
    result = subprocess.run("iw dev | awk '$1==\"Interface\"{print $2}'", shell=True, capture_output=True)
    interfaces = result.stdout.decode().strip().split("\n")
    interfaces = [i for i in interfaces if i]
    return jsonify({"interfaces": interfaces})

@app.route('/api/ssids', methods=['GET', 'POST'])
def manage_ssids():
    if request.method == 'GET':
        if not os.path.exists(SSID_FILE):
            return jsonify({"ssids": []})

        with open(SSID_FILE) as f:
            lines = f.readlines()

        ssid = passphrase = iface = vlan = ''
        enable = '1'
        for line in lines:
            if line.startswith("interface="):
                iface = line.strip().split("=")[1]
            if line.startswith("ssid="):
                ssid = line.strip().split("=")[1]
            if line.startswith("wpa_passphrase="):
                passphrase = line.strip().split("=")[1]

        return jsonify({
            "ssids": [{
                "ssid": ssid,
                "password": passphrase,
                "iface": iface,
                "vlan": vlan if vlan else "Yok",
                "enable": enable
            }]
        })

    elif request.method == 'POST':
        try:
            data = request.get_json(force=True)

            password = data.get('password', '')
            if not (8 <= len(password) <= 63):
                return jsonify({"error": "Parola 8 ile 63 karakter arasında olmalıdır."}), 400

            # Tek SSID desteği varsa ve zaten kayıtlı varsa ikinciyi engelle
            if not check_ap_limit() and os.path.exists(SSID_FILE):
                return jsonify({"error": "Bu cihaz aynı anda yalnızca 1 SSID yayınına izin veriyor."}), 400

            with open(SSID_FILE, 'w') as f:
                f.write(f"interface={data['iface']}\n")
                f.write("driver=nl80211\n")
                f.write(f"ssid={data['ssid']}\n")
                f.write("hw_mode=g\n")
                f.write("channel=6\n")
                f.write(f"wpa_passphrase={data['password']}\n")
                f.write("wpa=2\n")
                f.write("wpa_key_mgmt=WPA-PSK\n")
                f.write("rsn_pairwise=CCMP\n")

            subprocess.run(["pkill", "hostapd"], check=False)
            subprocess.run(["hostapd", "-B", SSID_FILE], check=False)

            return jsonify({"message": "SSID eklendi"}), 201

        except Exception as e:
            return jsonify({"error": str(e)}), 500

@app.route('/api/ssids/<int:index>', methods=['DELETE'])
def delete_ssid(index):
    if os.path.exists(SSID_FILE):
        os.remove(SSID_FILE)
    subprocess.run(["pkill", "hostapd"], check=False)
    return jsonify({"message": "SSID silindi"}), 200

if __name__ == '__main__':
    app.run(host="0.0.0.0", port=5000)
