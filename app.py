from flask import Flask, render_template, request, jsonify
import subprocess, os, signal

app = Flask(__name__)

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/dhcp_servers')
def dhcp_servers():
    servers = []
    try:
        # Ağdaki DHCP sunucularını tarar
        res = subprocess.run(
            ['nmap', '--script', 'broadcast-dhcp-discover', '-sU', '-p', '67'],
            capture_output=True, text=True, timeout=30
        )
        for line in res.stdout.splitlines():
            if 'Server Identifier:' in line:
                ip = line.split('Server Identifier:')[-1].strip()
                servers.append(ip)
    except Exception as e:
        print('DHCP scan hatası:', e)

    # Ortam değişkenindeki override’ı en başa koy
    default = os.environ.get('DHCP_SERVER') or os.environ.get('DEFAULT_SERVER')
    if default and default not in servers:
        servers.insert(0, default)
    return jsonify(servers=servers)

@app.route('/api/set_dhcp_server', methods=['POST'])
def set_dhcp_server():
    data = request.get_json()
    server = data.get('server')
    if not server:
        return jsonify(success=False, error='Sunucu IP belirtilmedi'), 400

    wifi_iface = os.environ.get('WIFI_IFACE', 'wls160')
    bridge = os.environ.get('BRIDGE', 'br0')

    # Mevcut relay’i durdur
    subprocess.run(['pkill', 'dhcrelay'], stderr=subprocess.DEVNULL)

    # Yeni relay başlat
    try:
        subprocess.Popen(['dhcrelay', '-i', wifi_iface, '-i', bridge, server])
        os.environ['DHCP_SERVER'] = server
        return jsonify(success=True)
    except Exception as e:
        return jsonify(success=False, error=str(e)), 500

# (Mevcut hotspot kontrol route'larınız buraya gelir...)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
