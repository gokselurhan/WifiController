from flask import Flask, render_template, request, jsonify
import subprocess

app = Flask(__name__)

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/interfaces')
def interfaces():
    # /sys/class/net içindeki arayüzleri listele
    try:
        output = subprocess.check_output('ls /sys/class/net', shell=True)
        all_ifaces = output.decode().split()
        # sadece "eth" ile başlayanları al
        eth_ifaces = [iface for iface in all_ifaces if iface.startswith('eth')]
    except Exception as e:
        print("Hata:", e)
        eth_ifaces = []
    return jsonify({'interfaces': eth_ifaces})

# Mevcut diğer endpoint'leriniz
# @app.route('/save', methods=['POST'])
# def save():
#     …

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
