import subprocess
import json
import os
from pyroute2 import IPRoute

class WifiManager:
    def __init__(self):
        self.config_file = "/etc/hostapd/hostapd.conf"
        self.ssids_file = "/etc/hostapd/ssids.json"
        self._ensure_files_exist()
        
    def _ensure_files_exist(self):
        if not os.path.exists(self.ssids_file):
            with open(self.ssids_file, 'w') as f:
                json.dump({"ssids": []}, f)
    
    def get_wifi_interfaces(self):
        """Mevcut WiFi arayüzlerini listeler"""
        try:
            ip = IPRoute()
            interfaces = [x.get_attr('IFLA_IFNAME') for x in ip.get_links() 
                        if x.get_attr('IFLA_IFNAME').startswith('wl')]
            return interfaces
        except Exception as e:
            print(f"Interface listeleme hatası: {e}")
            return []
    
    def get_configured_ssids(self):
        """Kayıtlı SSID'leri döndürür"""
        try:
            with open(self.ssids_file, 'r') as f:
                data = json.load(f)
                return data.get("ssids", [])
        except Exception as e:
            print(f"SSID okuma hatası: {e}")
            return []
    
    def add_ssid(self, ssid, password, vlan, enable, iface):
        """Yeni SSID ekler"""
        try:
            ssids = self.get_configured_ssids()
            ssids.append({
                "ssid": ssid,
                "password": password,
                "vlan": vlan,
                "enable": int(enable),
                "iface": iface
            })
            
            with open(self.ssids_file, 'w') as f:
                json.dump({"ssids": ssids}, f)
            
            self._apply_hostapd_config(iface, ssid, password)
            return True
        except Exception as e:
            print(f"SSID ekleme hatası: {e}")
            return False
    
    def delete_ssid(self, ssid_id):
        """SSID siler"""
        try:
            ssids = self.get_configured_ssids()
            if ssid_id < 0 or ssid_id >= len(ssids):
                return False
            
            ssids.pop(ssid_id)
            
            with open(self.ssids_file, 'w') as f:
                json.dump({"ssids": ssids}, f)
            
            return True
        except Exception as e:
            print(f"SSID silme hatası: {e}")
            return False
    
    def _apply_hostapd_config(self, interface, ssid, password):
        """Hostapd konfigürasyonunu günceller"""
        config = f"""
interface={interface}
driver=nl80211
ssid={ssid}
hw_mode=g
channel=6
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase={password}
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
"""
        with open(self.config_file, 'w') as f:
            f.write(config)
        
        # Hostapd servisini yeniden başlat
        subprocess.run(["systemctl", "restart", "hostapd"], check=True)
