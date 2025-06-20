from flask import Flask, jsonify, request, send_from_directory
import subprocess
import time
import re
import os

app = Flask(__name__)

BASE_DIR  = os.path.dirname(__file__)
SSID_FILE = "/etc/hostapd/hostapd.conf"
DHCP_RELAY_CONF = "/etc/default/isc-dhcp-relay"

def get_ap_limit():
    """`iw list` çıktısından #{ AP } <= N değerini bulur ve int olarak döner."""
    try:
        output = subprocess.check_output("iw list", shell=True, text=True)
        m = re.search(r"#\{\s*AP\s*\}\s*<=\s*(\d+)", output)
        if m:
            return int(m.group(1))
    except:
        pass
    return 1  # Eğer parse edilemezse fallback olarak 1 SSID

def configure_dhcp_relay(uplink_interface, dhcp_servers="192.168.1.1"):
    """DHCP Relay konfigürasyonunu günceller"""
    # AP arayüzlerini otomatik tespit et
    ap_interfaces = []
    if os.path.exists(SSID_FILE):
        with open(SSID_FILE, 'r') as f:
            for line in f:
                if line.startswith('interface='):
                    iface = line.split('=')[1].strip()
                    if iface not in ap_interfaces:
                        ap_interfaces.append(iface)

    # Tüm arayüzleri birleştir (AP arayüzleri + uplink)
    all_interfaces = ap_interfaces + [uplink_interface]
    interfaces_str = " ".join(all_interfaces)

    try:
        with open(DHCP_RELAY_CONF, 'w') as f:
            f.write(f"""# Otomatik oluşturuldu - WiFi Kontrol Paneli
SERVERS="{dhcp_servers}"
INTERFACES="{interfaces_str}"
OPTIONS="-d"
""")
        print(f"DHCP Relay güncellendi: AP={ap_interfaces} Uplink={uplink_interface}")
        
        subprocess.run(["service", "isc-dhcp-relay", "restart"], check=True)
        return True
    except Exception as e:
        print(f"DHCP Relay hatası: {str(e)}")
        return False

def apply_nat_rules(uplink_interface):
    """NAT kurallarını uygula veya güncelle"""
    # Eski kuralları temizle
    subprocess.run(["iptables", "-t", "nat", "-F"], check=False)
    
    # Yeni NAT kuralını ekle
    subprocess.run(
        ["iptables", "-t", "nat", "-A", "POSTROUTING", "-o", uplink_interface, "-j", "MASQUERADE"],
        check=True
    )
    print(f"NAT kuralları güncellendi: {uplink_interface}")

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
        return jsonify({"error":"Parola 8–63 karakter olmalı."}), 400
    
    # DHCP Relay ve NAT konfigürasyonunu güncelle
    uplink_interface = data.get('uplink', 'eth0')
    dhcp_servers = data.get('dhcp_servers', '192.168.1.1')
    configure_dhcp_relay(uplink_interface, dhcp_servers)
    apply_nat_rules(uplink_interface)

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
        return jsonify({"error":f"Dosyaya yazılamadı: {e}"}), 500

    # Hostapd'yi yeniden başlat (sadece geçerli konfig varsa)
    if os.path.exists(SSID_FILE) and os.stat(SSID_FILE).st_size > 0:
        subprocess.run(["pkill","-9","hostapd"], check=False)
        time.sleep(0.5)
        subprocess.run(["hostapd","-B", SSID_FILE], check=False)

    return jsonify({"message":"Yeni SSID eklendi ve yayın güncellendi."}), 201

@app.route('/api/ssids/<int:index>', methods=['DELETE'])
def delete_ssid(index):
    if not os.path.exists(SSID_FILE):
        return jsonify({"message":"Konfig bulunamadı."}), 404

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
        return jsonify({"error":"Geçersiz index."}), 400

    blocks.pop(index)

    try:
        with open(SSID_FILE, 'w') as f:
            for blk in blocks:
                for l in blk:
                    f.write(l)
                f.write("\n")
    except Exception as e:
        return jsonify({"error":f"Dosyaya yazılamadı: {e}"}), 500

    # NAT ve DHCP Relay'i güncelle
    uplink_interface = request.args.get('uplink', 'eth0')
    apply_nat_rules(uplink_interface)
    configure_dhcp_relay(uplink_interface)

    # Hostapd'yi yeniden başlat
    if os.path.exists(SSID_FILE) and os.stat(SSID_FILE).st_size > 0:
        subprocess.run(["pkill","hostapd"], check=False)
        subprocess.run(["hostapd","-B", SSID_FILE], check=False)
    else:
        subprocess.run(["pkill","-9","hostapd"], check=False)

    return jsonify({"message":"SSID silindi ve yayın güncellendi."}), 200

if __name__ == '__main__':
    app.run(host="0.0.0.0", port=5000)
