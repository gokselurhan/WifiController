from flask import Flask, jsonify, request, send_from_directory
import subprocess, os, json

app = Flask(__name__, static_url_path='', static_folder='.')

SSID_FILE = '/etc/hostapd/hostapd.conf'

@app.route('/')
def index():
    return send_from_directory('.', 'index.html')

@app.route('/api/interfaces')
def interfaces():
    result = subprocess.run("iw dev | awk '$1==\"Interface\"{print $2}'", shell=True, capture_output=True)
    interfaces = result.stdout.decode().strip().split("\n")
    return jsonify({"interfaces": interfaces})

@app.route('/api/ssids', methods=['GET', 'POST'])
def manage_ssids():
    if request.method == 'GET':
        if not os.path.exists(SSID_FILE):
            return jsonify({"ssids": []})

        with open(SSID_FILE) as f:
            lines = f.readlines()

        ssid = passphrase = iface = ''
        enable = vlan = '1'
        ssids = []
        for line in lines:
            if 'interface=' in line:
                iface = line.split('=')[1].strip()
            if 'ssid=' in line:
                ssid = line.split('=')[1].strip()
            if 'wpa_passphrase=' in line:
                passphrase = line.split('=')[1].strip()

        ssids.append({"ssid": ssid, "password": passphrase, "iface": iface, "enable": enable, "vlan": vlan})
        return jsonify({"ssids": ssids})

    elif request.method == 'POST':
        data = request.json
        with open('/etc/hostapd/hostapd.conf', 'w') as f:
            f.write(f"interface={data['iface']}\n")
            f.write("driver=nl80211\n")
            f.write(f"ssid={data['ssid']}\n")
            f.write("hw_mode=g\n")
            f.write("channel=6\n")
            f.write(f"wpa_passphrase={data['password']}\n")
            f.write("wpa=2\n")
            f.write("wpa_key_mgmt=WPA-PSK\n")
            f.write("rsn_pairwise=CCMP\n")

        subprocess.run(["systemctl", "restart", "hostapd"], check=False)
        return jsonify({"message": "SSID oluşturuldu"}), 201

@app.route('/api/ssids/<int:index>', methods=['DELETE'])
def delete_ssid(index):
    open('/etc/hostapd/hostapd.conf', 'w').close()
    subprocess.run(["systemctl", "stop", "hostapd"], check=False)
    return jsonify({"message": "SSID silindi"}), 200

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5000)
