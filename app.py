from flask import Flask, jsonify, request, send_from_directory
import subprocess
import time
import re
import os

app = Flask(__name__)

BASE_DIR   = os.path.dirname(__file__)
SSID_FILE  = "/etc/hostapd/hostapd.conf"

def get_ap_limit():
    """`iw list` çıktısından #{ AP } <= N değerini bulur ve int olarak döner."""
    try:
        output = subprocess.check_output("iw list", shell=True, text=True)
        m = re.search(r"#\{\s*AP\s*\}\s*<=\s*(\d+)", output)
        if m:
            return int(m.group(1))
    except:
        pass
    return 1  # Eğer parse edilemezse 1 SSID ile devam

@app.route('/api/aplimit')
def ap_limit():
    return jsonify({"max_ap": get_ap_limit()})

@app.route('/')
def index():
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
        if iface == 'lo':   return 'Döngü arayüzü (loopback)'
        if iface.startswith(('wl','wlan','wlp')): return 'Kablosuz (Wi-Fi)'
        if iface.startswith(('eth','enp','ens','eno','enx')): return 'Ethernet'
        if iface == 'docker0': return 'Docker köprü ağı'
        if iface.startswith('br-'):   return 'Bridge'
        if iface.startswith('veth'):  return 'Sanal Ethernet'
        if iface.startswith('tun'):   return 'TUN/TAP VPN'
        if iface.startswith('wg'):    return 'WireGuard VPN'
        if iface.startswith('virbr'): return 'Libvirt bridge'
        return 'Bilinmeyen arayüz'
    uplinks = [{"name": i, "description": describe(i)} for i in all_ifaces]
    return jsonify({"interfaces": uplinks})

@app.route('/api/ssids', methods=['GET','POST'])
def manage_ssids():
    if request.method == 'GET':
        if not os.path.exists(SSID_FILE):
            return jsonify({"ssids": []})
        ssids = []
        current = {}
        with open(SSID_FILE) as f:
            for raw in f:
                line = raw.strip()
                if not line:
                    if current:
                        current.setdefault('vlan','Yok')
                        current.setdefault('enable','1')
                        ssids.append(current)
                        current = {}
                    continue
                if line.startswith('interface='):
                    if current:
                        current.setdefault('vlan','Yok')
                        current.setdefault('enable','1')
                        ssids.append(current)
                        current = {}
                    current['iface'] = line.split('=',1)[1]
                elif line.startswith('ssid='):
                    current['ssid'] = line.split('=',1)[1]
                elif line.startswith('wpa_passphrase='):
                    current['password'] = line.split('=',1)[1]
        if current:
            current.setdefault('vlan','Yok')
            current.setdefault('enable','1')
            ssids.append(current)
        return jsonify({"ssids": ssids})

    # POST: yeni bloğu append et
    data = request.get_json(force=True)
    pwd = data.get('password','')
    if not (8 <= len(pwd) <= 63):
        return jsonify({"error":"Parola 8–63 karakter olmalı."}),400

    try:
        with open(SSID_FILE, 'a') as f:
            f.write("\n# Eklenen SSID\n")
            f.write(f"interface={data['iface']}\n")
            f.write("driver=nl80211\n")
            f.write(f"ssid={data['ssid']}\n")
            f.write("hw_mode=g\n")
            f.write("channel=6\n")
            f.write(f"wpa_passphrase={pwd}\n")
            f.write("wpa=2\n")
            f.write("wpa_key_mgmt=WPA-PSK\n")
            f.write("rsn_pairwise=CCMP\n")
    except Exception as e:
        return jsonify({"error":f"Dosyaya yazılamadı: {e}"}),500

   # Hostapd'yi önce zorla öldür, kısa süre bekle, sonra yeniden başlat
   subprocess.run(["pkill","-9","hostapd"], check=False)
    time.sleep(0.5)
    subprocess.run(["hostapd","-B",SSID_FILE], check=False)
    return jsonify({"message":"Yeni SSID eklendi ve yayın güncellendi."}),201

@app.route('/api/ssids/<int:index>', methods=['DELETE'])
def delete_ssid(index):
    if not os.path.exists(SSID_FILE):
        return jsonify({"message":"Konfig bulunamadı."}),404
    blocks = []
    current = []
    with open(SSID_FILE) as f:
        for line in f:
            if line.strip().startswith('interface=') and current:
                blocks.append(current)
                current = []
            current.append(line)
        if current:
            blocks.append(current)
    if index < 0 or index >= len(blocks):
        return jsonify({"error":"Geçersiz index."}),400

    blocks.pop(index)
    try:
        with open(SSID_FILE, 'w') as f:
            for blk in blocks:
                for l in blk:
                    f.write(l)
                f.write("\n")
    except Exception as e:
        return jsonify({"error":f"Dosyaya yazılamadı: {e}"}),500

    subprocess.run(["pkill","hostapd"], check=False)
    subprocess.run(["hostapd","-B",SSID_FILE], check=False)
    return jsonify({"message":"SSID silindi ve yayın güncellendi."}),200

if __name__=='__main__':
    app.run(host="0.0.0.0", port=5000)
