@app.route('/api/status')
def status():
    interfaces = subprocess.run("iw dev | awk '$1==\"Interface\"{print $2}'", shell=True, capture_output=True, text=True).stdout.strip().split('\n')
    interfaces = [i for i in interfaces if i]
    ap_limit = check_ap_limit()
    ssid_info = []

    if os.path.exists(SSID_FILE):
        with open(SSID_FILE) as f:
            lines = f.readlines()
        current_iface = ""
        current_ssid = ""
        for line in lines:
            if line.startswith("interface="):
                current_iface = line.strip().split("=")[1]
            if line.startswith("ssid="):
                current_ssid = line.strip().split("=")[1]
        if current_iface:
            ssid_info.append({"iface": current_iface, "ssid": current_ssid})

    return jsonify({"ap_limit": ap_limit, "active": ssid_info})
