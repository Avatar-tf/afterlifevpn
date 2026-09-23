<div align="center">
  <h1>⚡ AFTERLIFE VPN AUTOSCRIPT</h1>
  <p><b>A comprehensive, production-ready VPN automation platform engineered for maximum performance and security.</b></p>
</div>

---

AFTERLIFE VPN delivers a complete multi-protocol tunneling solution with SSL/TLS encryption, port hopping capabilities, TCP optimization, and an intuitive management interface. 

Built exclusively for **Ubuntu (20.04, 22.04, 24.04) LTS** to ensure rock-solid stability and performance.

## 🌟 Core Features

### 🔐 Advanced Tunneling Protocols
- **SSH WebSocket (WSS):** Encrypted WebSocket tunneling with full SSL/TLS support on configurable ports (default: 443).
- **VMess (Xray-core):** Modern V2Ray protocol with WebSocket transport, TLS encryption, and `/vmess` path routing (Port 443).
- **Hysteria 2:** Cutting-edge QUIC-based proxy with intelligent port hopping (53, 20000-40000) and Google masquerading for maximum stealth.
- **Dropbear SSH:** Lightweight, high-performance SSH server with custom branding and configurable ports (default: 442).
- **UDP Custom:** Direct UDP tunneling via badvpn-udpgw for gaming and VoIP applications (Port 53).
- **TCP BBR:** Google's BBR congestion control algorithm for superior throughput on high-latency connections.

### 🛡️ Enterprise-Grade Security
- **Automated SSL/TLS:** Let's Encrypt integration via acme.sh with automatic certificate issuance and renewal.
- **Multi-Layer Encryption:** TLS 1.3 for WebSocket, VMess, and Hysteria 2 protocols.
- **Account Expiration:** Automatic user account expiry with no shell access for enhanced security.
- **Domain Validation:** Full support for custom domains with DNS-based certificate validation.
- **Firewall Ready:** Pre-configured for iptables/UFW with persistent rules across reboots.

### 🎛️ Intelligent Management System
- **Interactive TUI Menu:** Beautiful color-coded terminal interface accessible via the `menu` command.
- **Real-Time Monitoring:** Live service status checks and active connection tracking.
- **Configuration Backup/Restore:** Complete system state preservation with one-click disaster recovery.
- **Dynamic Port Management:** Change any service port on-the-fly without reinstallation.
- **Log Management:** Automated log rotation and cleanup to prevent disk space issues.
- **Bandwidth Control:** Per-interface speed limiting with wondershaper integration.

## 📦 One-Command Installation

Deploy AFTERLIFE VPN on a fresh Ubuntu server with a single command as `root`:

```bash
apt update && apt install -y wget
```

```bash
wget -qO install.sh https://raw.githubusercontent.com/Avatar-tf/afterlifevpn/main/install.sh && chmod +x install.sh && sudo ./install.sh
```

**Installation Requirements:**
- Fresh Ubuntu 20.04/22.04/24.04 LTS VPS
- Minimum 512MB RAM, 1 CPU core, 10GB disk
- Public IPv4 address
- Domain name (recommended for SSL)
- Root access

**Installation Process:**
1. System compatibility check and version detection
2. Dependency installation (Python3, curl, wget, socat, etc.)
3. TCP BBR kernel optimization
4. SSL certificate generation via Let's Encrypt
5. Multi-protocol service deployment
6. Systemd service registration with auto-restart
7. Management menu installation

## 🛠️ Post-Installation Management

After successful installation, manage your VPN infrastructure:

1. **Launch Control Panel:** Type `menu` anywhere in your terminal to access the comprehensive management interface.

2. **Menu Options:**
   - **Option 1:** Display VMess configuration (UUID, ports, paths)
   - **Option 2:** Display Hysteria 2 configuration (server, password, ports)
   - **Option 3:** Create SSH accounts with custom expiration
   - **Option 4:** Force SSL certificate renewal
   - **Option 5:** Check all service statuses
   - **Option 6:** Restart all VPN services
   - **Option 7:** Change Dropbear SSH port
   - **Option 8:** Change SSH WebSocket port
   - **Option 9:** Switch Hysteria between single-port and port-hopping modes
   - **Option 10:** View system information and port configuration
   - **Option 11:** Backup all configurations and certificates
   - **Option 12:** Restore from previous backup
   - **Option 13:** Clear system logs and free disk space
   - **Option 14:** Monitor active connections in real-time
   - **Option 15:** Configure bandwidth limits

3. **Service Management:**
   ```bash
   systemctl status ws-ssh      # SSH WebSocket status
   systemctl status xray        # VMess/V2Ray status
   systemctl status hysteria    # Hysteria 2 status
   systemctl status dropbear    # Dropbear SSH status
   systemctl status udp-custom  # UDP Custom status
   ```

## 📂 System Architecture

AFTERLIFE VPN follows Linux best practices with organized, sandboxed configurations:

- `/usr/local/afterlifevpn/`: Core configuration files and service scripts
  - `config.conf`: Main installation configuration
  - `vmess-config.txt`: VMess client configuration
  - `hysteria-config.txt`: Hysteria 2 client configuration
  - `setup/`: Modular installation scripts
  - `menu/`: Management interface

- `/etc/afterlifevpn/cert/`: SSL/TLS certificates
  - `private.key`: Private key
  - `fullchain.crt`: Full certificate chain

- `/etc/hysteria/`: Hysteria 2 configuration
  - `config.yaml`: Server configuration with port hopping

- `/usr/local/etc/xray/`: Xray-core configuration
  - `config.json`: VMess protocol settings

- `/usr/bin/menu`: Global menu command symlink

## 🌐 Port Configuration

**Default Port Allocation:**
- **22:** Standard OpenSSH
- **53:** UDP Custom (badvpn-udpgw)
- **80:** Available for HTTP (optional)
- **443:** SSH WebSocket (WSS), VMess, Hysteria 2
- **442:** Dropbear SSH
- **20000-40000:** Hysteria 2 port hopping range (configurable)

**Firewall Configuration Example:**
```bash
# Allow SSH
ufw allow 22/tcp

# Allow SSH WebSocket
ufw allow 443/tcp

# Allow VMess
ufw allow 443/tcp

# Allow Dropbear
ufw allow 442/tcp

# Allow UDP Custom
ufw allow 53/udp

# Allow Hysteria 2 port range
ufw allow 20000:40000/udp
ufw allow 53/udp

# Enable firewall
ufw enable
```

## 🔧 Advanced Configuration

### Change SSH WebSocket Port
```bash
menu
# Select Option 8
# Enter new port (e.g., 8443)
```

### Enable Hysteria 2 Port Hopping
```bash
menu
# Select Option 9
# Choose "Port Hopping Mode"
# Enter range: 20000-40000
# Include port 53: y
```

### Create SSH User Account
```bash
menu
# Select Option 3
# Username: testuser
# Password: SecurePass123
# Expiry: 30 (days)
```

### Backup Configuration
```bash
menu
# Select Option 11
# Backup saved to: /root/afterlifevpn-backup/
```

## 📱 Client Configuration

### VMess (V2RayNG, NekoBox, v2rayN)
```
Address: your-domain.com
Port: 443
UUID: [shown in menu option 1]
AlterID: 0
Network: ws
Path: /vmess
TLS: enabled
```

### Hysteria 2 (Nekoray, Clash Meta)
```
Server: your-domain.com
Port: 20000-40000 (or 443 for single port)
Password: [shown in menu option 2]
Protocol: hysteria2
TLS: enabled
```

### SSH WebSocket (HTTP Injector, HTTP Custom)
```
Server: your-domain.com
Port: 443
Protocol: SSH WebSocket (WSS)
Payload: GET wss://[host] HTTP/1.1[crlf]Host: [host][crlf]Upgrade: websocket[crlf][crlf]
```

## 🔄 Updating the Script

To update individual components:

1. Edit the script on GitHub
2. On your server, re-download the updated script:
```bash
wget -qO /usr/local/afterlifevpn/setup/[script-name].sh https://raw.githubusercontent.com/Avatar-tf/afterlifevpn/main/setup/[script-name].sh
chmod +x /usr/local/afterlifevpn/setup/[script-name].sh
```

3. Restart the affected service:
```bash
systemctl restart [service-name]
```

## 🐛 Troubleshooting

### Services Won't Start
```bash
# Check service logs
journalctl -u ws-ssh -n 50
journalctl -u xray -n 50
journalctl -u hysteria -n 50

# Verify certificates exist
ls -la /etc/afterlifevpn/cert/

# Check port conflicts
netstat -tulpn | grep LISTEN
```

### SSL Certificate Issues
```bash
# Ensure domain points to server IP
dig +short your-domain.com

# Manually renew certificate
~/.acme.sh/acme.sh --renew -d your-domain.com --force

# Restart services
systemctl restart ws-ssh xray hysteria
```

### Connection Refused
```bash
# Check firewall
ufw status

# Verify services are running
systemctl status ws-ssh xray hysteria dropbear udp-custom

# Check if ports are listening
ss -tulpn | grep -E '443|442|53'
```

## ⚠️ Disclaimer

This software is provided for **educational purposes, privacy enhancement, and legitimate network administration only**. 

**Prohibited Uses:**
- Bypassing legal restrictions or terms of service
- Unauthorized access to networks or systems
- Distribution of malware or illegal content
- DDoS attacks or network abuse
- Spam or fraudulent activities

**Legal Notice:**
Users are solely responsible for compliance with local laws and regulations. The developer assumes no liability for misuse, damages, or legal consequences arising from the use of this software.

**Privacy & Data:**
This script does not collect, transmit, or store any user data externally. All configurations remain on your server.

## 📞 Support & Community

<div align="center">
  <p>
    <b>Repository</b> → <a href="https://github.com/Avatar-tf/afterlifevpn">github.com/Avatar-tf/afterlifevpn</a><br>
    <b>Issues</b> → <a href="https://github.com/Avatar-tf/afterlifevpn/issues">Report bugs or request features</a><br>
    <b>Developer</b> → <a href="https://gitlab.com/afterlife4062039">AFTERLIFE</a>
  </p>
</div>

---

<div align="center">
  <p><i>Built with ❤️ for the privacy-conscious community</i></p>
  <p><b>AFTERLIFE VPN</b> - Where Security Meets Performance</p>
</div>

---

## 📝 Changelog

### Version 1.0.0 (Initial Release)
- ✅ SSH WebSocket with SSL/TLS on port 443
- ✅ VMess (Xray-core) with WebSocket transport
- ✅ Hysteria 2 with port hopping (53, 20000-40000)
- ✅ Dropbear SSH on port 442
- ✅ UDP Custom on port 53
- ✅ TCP BBR optimization
- ✅ Automated SSL certificate management
- ✅ Interactive management menu (15 options)
- ✅ Backup and restore functionality
- ✅ Active connection monitoring
- ✅ Bandwidth limiting
- ✅ Log management
- ✅ Ubuntu 20.04/22.04/24.04 support

---
