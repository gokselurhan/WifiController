from flask import Flask, request, jsonify
import os
import json

app = Flask(__name__)

SSIDS_FILE = "/etc/hostapd/ssids.json"
RELAY_FILE = "/etc/hostapd/relay_config.txt"

def load_ssids():
    if os.path.exists(SSIDS_FILE):
        with open(SSIDS_FILE) as f:
            return json.load(f)
    return []

def save_ssids(ssids):
    with open(SSIDS_FILE, "w") as f:
        json.dump(ssids, f, indent=2)

@app.route('/api/ssids', methods=['POST'])
def add_ssid():
    data = request.get_json(force=True)
    ssid = data.get('ssid')
    password = data.get('password')
    vlan = data.get('vlan')
    dhcp_relay = data.get('dhcp_relay', False)
    # Minimum alan kontrolü
    if not ssid or not password:
        return jsonify({'message': 'SSID ve şifre zorunludur.'}), 400
    # JSON güncelle
    ssids = load_ssids()
    ssids.append({
        'ssid': ssid,
        'password': password,
        'vlan': vlan,
        'dhcp_relay': dhcp_relay
    })
    save_ssids(ssids)
    # DHCP relay gerekiyorsa config dosyasına yaz
    if dhcp_relay and vlan:
        relay_entry = f"wlan0.{vlan}:{vlan}:DHCPRELAY\n"  # veya interface adını burada dinamikleştir
        with open(RELAY_FILE, "a") as relayf:
            relayf.write(relay_entry)
    return jsonify({'message': 'SSID başarıyla eklendi.'})

@app.route('/')
def home():
    return open('index.html').read()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80)
