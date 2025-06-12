#!/usr/bin/env python3
from flask import Flask, jsonify, request
import subprocess
import json
import os
from wifi_manager import WifiManager

app = Flask(__name__)
wifi_manager = WifiManager()

# API endpoint'leri
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

# Frontend dosyalarını sun
@app.route('/')
def serve_index():
    return app.send_static_file('index.html')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80, debug=True)
