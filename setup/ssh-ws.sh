#!/bin/bash
# AFTERLIFE WS-SSH Installer (Fixed version)
# Compatible with NetMod + nginx reverse proxy on 443

WS_PORT=${1:-8880}

echo "[*] Installing WS-SSH Proxy on port $WS_PORT ..."

# Create the improved Python proxy
cat > /usr/local/bin/ws-ssh.py << 'EOF'
#!/usr/bin/env python3
import socket
import select
import threading
import base64
import hashlib
import sys

LISTEN_IP   = '127.0.0.1'          # localhost only (nginx will forward to it)
LISTEN_PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8880
BACKEND     = ('127.0.0.1', 109)

def log(msg):
    print(f"[WS-SSH] {msg}", flush=True)

def forward(src, dst):
    try:
        while True:
            r, _, _ = select.select([src], [], [], 120)
            if not r:
                break
            data = src.recv(16384)
            if not data:
                break
            dst.sendall(data)
    except Exception:
        pass
    finally:
        for s in (src, dst):
            try:
                s.close()
            except Exception:
                pass

def make_accept(key: str) -> str:
    magic = key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
    return base64.b64encode(hashlib.sha1(magic.encode()).digest()).decode()

def client_handler(client, addr):
    target = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        target.connect(BACKEND)

        # Read the complete HTTP request (handles fragmented packets from mobile)
        client.settimeout(10)
        data = b""
        while b"\r\n\r\n" not in data:
            chunk = client.recv(4096)
            if not chunk:
                return
            data += chunk
            if len(data) > 16384:
                break
        client.settimeout(None)

        req = data.decode("utf-8", errors="ignore")
        first_line = req.splitlines()[0] if req else "empty"
        log(f"Client {addr} → {first_line}")

        if "upgrade" in req.lower() and "websocket" in req.lower():
            key = None
            for line in req.splitlines():
                if line.lower().startswith("sec-websocket-key:"):
                    key = line.split(":", 1)[1].strip()
                    break

            headers = [
                "HTTP/1.1 101 Switching Protocols",
                "Upgrade: websocket",
                "Connection: Upgrade",
            ]
            if key:
                headers.append(f"Sec-WebSocket-Accept: {make_accept(key)}")
            headers.append("")
            headers.append("")
            client.sendall("\r\n".join(headers).encode())

            # Forward any data that came after the headers
            leftover = data.split(b"\r\n\r\n", 1)[1] if b"\r\n\r\n" in data else b""
            if leftover:
                target.sendall(leftover)
        else:
            # Not a WebSocket request – just pipe everything
            target.sendall(data)

        t1 = threading.Thread(target=forward, args=(client, target), daemon=True)
        t2 = threading.Thread(target=forward, args=(target, client), daemon=True)
        t1.start()
        t2.start()
        t1.join()
        t2.join()

    except Exception as e:
        log(f"Handler error from {addr}: {e}")
    finally:
        for s in (client, target):
            try:
                s.close()
            except Exception:
                pass

def main():
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind((LISTEN_IP, LISTEN_PORT))
    srv.listen(200)
    log(f"Listening on {LISTEN_IP}:{LISTEN_PORT} → Dropbear {BACKEND[1]}")

    while True:
        client, addr = srv.accept()
        threading.Thread(target=client_handler, args=(client, addr), daemon=True).start()

if __name__ == "__main__":
    main()
EOF

chmod +x /usr/local/bin/ws-ssh.py

# Create systemd service (port is passed as argument)
cat > /etc/systemd/system/ws-ssh.service << EOF
[Unit]
Description=AFTERLIFE WS-SSH Proxy (NetMod)
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 -u /usr/local/bin/ws-ssh.py ${WS_PORT}
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl restart ws-ssh
systemctl enable ws-ssh

echo
echo "[+] WS-SSH Proxy installed and running on 127.0.0.1:${WS_PORT}"
echo "[+] Make sure your nginx is proxying to http://127.0.0.1:${WS_PORT}"
systemctl status ws-ssh --no-pager -l
