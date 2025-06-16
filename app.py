from flask import Flask, jsonify, request, send_from_directory
import subprocess
import os
import re

app = Flask(__name__)

SSID_FILE = "/etc/hostapd/hostapd.conf"

def check_ap_limit():
    # … (mevcut fonksiyonunuz aynen kalsın) …

@app.route('/')
def index():
    return send_from_directory('.', 'index.html')

# ↙️ Yeni uplinks endpoint
@app.route('/api/uplinks')
def get_uplinks():
    all_ifaces = os.listdir('/sys/class/net')
    uplinks = [i for i in all_ifaces if i.startswith('eth') or i.startswith('enp')]
    return jsonify({"uplinks": uplinks})
# ↗️

@app.route('/api/interfaces')
def interfaces():
    # … (mevcut kodunuz) …
    result = subprocess.run("iw dev | awk '$1==\"Interface\"{print $2}'",
                             shell=True, capture_output=True)
    interfaces = result.stdout.decode().split()
    return jsonify({"interfaces": interfaces})

@app.route('/api/ssids', methods=['GET', 'POST'])
def manage_ssids():
    # … (mevcut GET/POST kodunuz) …

@app.route('/api/ssids/<int:index>', methods=['DELETE'])
def delete_ssid(index):
    # … (mevcut DELETE kodunuz) …

if __name__ == '__main__':
    app.run(host="0.0.0.0", port=5000)
