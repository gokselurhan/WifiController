from flask import Flask, jsonify, request, send_from_directory
import subprocess
import os

app = Flask(__name__)

SSID_FILE = "/etc/hostapd/hostapd.conf"

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

        ssid = passphrase = iface = vlan = ''
        enable = '1'
        for line in lines:
            if line.startswith("interface="): iface = line.strip().split("=")[1]
            if line.startswith("ssid="): ssid = line.strip().split("=")[1]
            if line.startswith("wpa_passphrase="): passphrase = line.strip().split("=")[1]

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
            subprocess.run(["hostapd", "-B", "/etc/hostapd/hostapd.conf"], check=False)

            return jsonify({"message": "SSID eklendi"}), 201

