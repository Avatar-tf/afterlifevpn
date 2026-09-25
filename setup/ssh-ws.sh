#!/bin/bash

WS_PORT=${1:-8880}

cat > /usr/local/bin/ws-ssh.py <<EOF
#!/usr/bin/env python3
import socket
import threading
import select
import base64
import hashlib

LISTEN_PORT = int("$WS_PORT")
TARGET_PORT = 109
GUID = b"258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

def compute_accept_key(sec_key):
    sha1 = hashlib.sha1(sec_key.encode('utf-8') + GUID).digest()
    return base64.b64encode(sha1).decode('utf-8')

def handle_client(client_sock):
    target_sock = None
    try:
        client_sock.settimeout(10)
        request = client_sock.recv(16384)
        if not request:
            client_sock.close()
            return
            
        # Parse WebSocket Sec-WebSocket-Key for proper handshake validation
        sec_key = None
        for line in request.decode('utf-8', errors='ignore').split('\r\n'):
            if line.lower().startswith('sec-websocket-key:'):
                sec_key = line.split(':', 1)[1].strip()
                break
                
        if sec_key:
            accept_key = compute_accept_key(sec_key)
            response = (
                "HTTP/1.1 101 Switching Protocols\r\n"
                "Upgrade: websocket\r\n"
                "Connection: Upgrade\r\n"
                f"Sec-WebSocket-Accept: {accept_key}\r\n\r\n"
            )
        else:
            response = (
                "HTTP/1.1 101 Switching Protocols\r\n"
                "Upgrade: websocket\r\n"
                "Connection: Upgrade\r\n\r\n"
            )
            
        client_sock.sendall(response.encode('utf-8'))
        
        # Connect to local Dropbear
        target_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        target_sock.connect(('127.0.0.1', TARGET_PORT))
        
        client_sock.settimeout(None)
        target_sock.settimeout(None)
        
        # Blindly bridge data streams
        sockets = [client_sock, target_sock]
        while True:
            r, _, e = select.select(sockets, [], sockets, 300)
            if e or not r:
                break
            for s in r:
                data = s.recv(65536)
                if not data:
                    return
                if s is client_sock:
                    target_sock.sendall(data)
                else:
                    client_sock.sendall(data)
    except Exception:
        pass
    finally:
        try:
            client_sock.close()
        except:
            pass
        try:
            if target_sock:
                target_sock.close()
        except:
            pass

def main():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(('127.0.0.1', LISTEN_PORT))
    server.listen(500)
    
    while True:
        client_sock, _ = server.accept()
        threading.Thread(target=handle_client, args=(client_sock,), daemon=True).start()

if __name__ == '__main__':
    main()
EOF

chmod +x /usr/local/bin/ws-ssh.py

cat > /etc/systemd/system/ws-ssh.service <<EOF
[Unit]
Description=AFTERLIFE Production WS-SSH Proxy
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/ws-ssh.py
Restart=always
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl restart ws-ssh
systemctl enable ws-ssh
