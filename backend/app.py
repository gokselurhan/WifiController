from flask import Flask, jsonify, request, send_from_directory
import json
import subprocess
from wifi_manager import WifiManager
import os

app = Flask(__name__, static_folder='../frontend/static')

wifi_manager = WifiManager()

# API Endpoints
@app.route('/api/interfaces', methods=['GET'])
def get_interfaces():
    interfaces = wifi_manager.get_wifi_interfaces()
    return jsonify({"interfaces": interfaces})

@app.route('/api/ssids', methods=['GET'])
def get_ssids():
    ssids = wifi_manager.get_configured_ssids()
    return jsonify({"ssids": ssids})

@app.route('/api/ssids', methods=['POST'])
def add_ssid():
    data = request.get_json()
    result = wifi_manager.add_ssid(
        data['ssid'],
        data['password'],
        data['vlan'],
        data['enable'],
        data['iface']
    )
    return jsonify({"success": result})

@app.route('/api/ssids/<int:ssid_id>', methods=['DELETE'])
def delete_ssid(ssid_id):
    result = wifi_manager.delete_ssid(ssid_id)
    return jsonify({"success": result})

# Frontend Dosyaları
@app.route('/')
def serve_index():
    return send_from_directory(app.static_folder, 'index.html')

@app.route('/<path:path>')
def serve_static(path):
    return send_from_directory(app.static_folder, path)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80)
