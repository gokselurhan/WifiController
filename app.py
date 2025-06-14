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
                    return not ("AP}<=1" in compact)
        return True
    except Exception:
        return True

@app.route('/')
def index():
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
    Loopback, docker0, tun*, br-* vs. dahil olmak üzere 
    /sys/class/net altındaki tüm arayüzleri listeler ve
    her birine açıklama (description) ekler.
    """
    try:
        all_ifaces = sorted(os.listdir('/sys/class/net'))
    except Exception as e:
        print("Error listing interfaces:", e)
        all_ifaces = []

    def describe(iface: str) -> str:
        if iface == 'lo':
            return 'Loopback interface'
        if iface.startswith(('wl','wlan','wlp')):
            return 'Wireless (Wi-Fi) interface'
        if iface.startswith(('eth','enp','ens','eno','enx')):
            return 'Physical Ethernet interface'
        if iface == 'docker0':
            return 'Docker bridge network'
        if iface.startswith('br-'):
            return 'Bridge network interface'
        if iface.startswith('veth'):
            return 'Virtual Ethernet (container link)'
        if iface.startswith('tun'):
            return 'TUN/TAP VPN interface'
        if iface.startswith('wg'):
            return 'WireGuard VPN interface'
        if iface.startswith('virbr'):
            return 'Libvirt virtual bridge'
        # gerekirse buraya yeni pattern’ler ekleyebilirsiniz
        return 'Unknown interface'

    uplink_ifaces = [
        {"name": iface, "description": describe(iface)}
        for iface in all_ifaces
    ]

    return jsonify({"interfaces": uplink_ifaces})

@app.route('/api/ssids', methods=['GET', 'POST'])
def manage_ssids():
    if request.method == 'GET':
        if not os.path.exists(SSID_FILE):
            return jsonify({"ssids": []})
        with open(SSID_FILE) as f:
            lines = f.readlines()
        # TODO: hostapd.conf parse edip gerçek ssid listesini döndürün
        return jsonify({"ssids": []})

    # POST ile yeni/güncelleme
    data = request.json or {}
    # TODO: data['ssid'], data['password'], data['vlan'] vs. kaydedin
    return jsonify({"message": "SSID eklendi/güncellendi"}), 201

@app.route('/api/ssids/<int:index>', methods=['DELETE'])
def delete_ssid(index):
    if os.path.exists(SSID_FILE):
        os.remove(SSID_FILE)
    subprocess.run(["pkill", "hostapd"], check=False)
    return jsonify({"message": "SSID silindi"}), 200

if __name__ == '__main__':
    app.run(host="0.0.0.0", port=5000)
