from flask import Flask, jsonify, request, send_from_directory
import subprocess
import os

app = Flask(__name__)

BASE_DIR = os.path.dirname(__file__)
SSID_FILE = "/etc/hostapd/hostapd.conf"

def check_ap_limit():
    """Geçici olarak hep True döndür: çoklu AP destekleniyormuş gibi davran."""
    return True
    # -------------------
    # Orijinal kod buraya gelecekti, ama geçici devre dışı:
    # try:
    #     result = subprocess.run(
    #         "iw list", shell=True, capture_output=True, text=True
    #     )
    #     lines = result.stdout.splitlines()
    #     combo_section = False
    #     for line in lines:
    #         if "valid interface combinations" in line:
    #             combo_section = True
    #         elif combo_section and "AP" in line:
    #             compact = line.replace(" ", "")
    #             return not ("AP}<=1" in compact)
    #     return True
    # except:
    #     return True

@app.route('/')
def index():
    # artık kesinlikle app.py'nın olduğu dizinden alacak
    return send_from_directory(BASE_DIR, 'index.html')

@app.route('/api/interfaces')
def interfaces():
    result = subprocess.run(
        "iw dev | awk '$1==\"Interface\"{print $2}'",
        shell=True, capture_output=True, text=True
    )
    interfaces = [l for l in result.stdout.splitlines() if l.strip()]
    return jsonify({"interfaces": interfaces})

@app.route('/api/ethinterfaces')
def eth_interfaces():
    all_ifaces = sorted(os.listdir('/sys/class/net'))
    def describe(iface):
        if iface == 'lo': return 'Döngü arayüzü (loopback)'
        if iface.startswith(('wl','wlan','wlp')): return 'Kablosuz (Wi-Fi)'
        if iface.startswith(('eth','enp','ens','eno','enx')): return 'Ethernet'
        if iface == 'docker0': return 'Docker köprü ağı'
        if iface.startswith('br-'): return 'Bridge'
        if iface.startswith('veth'): return 'Sanal Ethernet'
        if iface.startswith('tun'): return 'TUN/TAP VPN'
        if iface.startswith('wg'): return 'WireGuard VPN'
        if iface.startswith('virbr'): return 'Libvirt bridge'
        return 'Bilinmeyen arayüz'
    uplinks = [{"name": i, "description": describe(i)} for i in all_ifaces]
    return jsonify({"interfaces": uplinks})

@app.route('/api/ssids', methods=['GET','POST'])
def manage_ssids():
    if request.method == 'GET':
        if not os.path.exists(SSID_FILE):
            return jsonify({"ssids": []})
        with open(SSID_FILE) as f:
            lines = f.readlines()
        ssid = pwd = iface = ""
        enable = "1"
        for line in lines:
            if line.startswith("interface="):
                iface = line.strip().split("=",1)[1]
            elif line.startswith("ssid="):
                ssid = line.strip().split("=",1)[1]
            elif line.startswith("wpa_passphrase="):
                pwd = line.strip().split("=",1)[1]
        return jsonify({"ssids":[{"ssid":ssid,"password":pwd,"iface":iface,"vlan":"Yok","enable":enable}]})

    data = request.get_json(force=True)
    pwd = data.get('password','')
    if not (8 <= len(pwd) <= 63):
        return jsonify({"error":"Parola 8–63 karakter olmalı."}),400
    if not check_ap_limit() and os.path.exists(SSID_FILE):
        return jsonify({"error":"Bu cihaz yalnızca tek SSID yayınına izin veriyor."}),400

    with open(SSID_FILE,'w') as f:
        f.write(f"interface={data['iface']}\n")
        f.write("driver=nl80211\n")
        f.write(f"ssid={data['ssid']}\n")
        f.write("hw_mode=g\n")
        f.write("channel=6\n")
        f.write(f"wpa_passphrase={pwd}\n")
        f.write("wpa=2\n")
        f.write("wpa_key_mgmt=WPA-PSK\n")
        f.write("rsn_pairwise=CCMP\n")

    subprocess.run(["pkill","hostapd"], check=False)
    subprocess.run(["hostapd","-B",SSID_FILE], check=False)
    return jsonify({"message":"SSID kaydedildi ve yayın başladı"}),201

@app.route('/api/ssids/<int:index>', methods=['DELETE'])
def delete_ssid(index):
    if os.path.exists(SSID_FILE):
        os.remove(SSID_FILE)
    subprocess.run(["pkill","hostapd"], check=False)
    return jsonify({"message":"SSID silindi ve yayını durdurdu"}),200

if __name__=='__main__':
    app.run(host="0.0.0.0", port=5000)
