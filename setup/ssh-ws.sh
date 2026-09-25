#!/bin/bash

WS_PORT=${1:-8880}

cat > /usr/local/bin/ws-ssh.py <<EOF
#!/usr/bin/env python3
import socket
import select
import threading
import sys

LISTEN_IP = '127.0.0.1'
LISTEN_PORT = int("$WS_PORT")
BACKEND_PORT = 109

def log(msg):
    print(f"[WS-SSH] {msg}", flush=True)

def forward(source, destination, direction):
    try:
        while True:
            r, _, _ = select.select([source], [], [], 60)
            if r:
                data = source.recv(16384)
                if not data:
                    break
                destination.sendall(data)
    except Exception:
        pass
    finally:
        try:
            source.close()
        except:
            pass
        try:
            destination.close()
        except:
            pass

def client_handler(client_socket, client_addr):
    target_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        target_socket.connect(('127.0.0.1', BACKEND_PORT))
        
        # Read initial client payload (NetMod WebSocket request headers)
        client_socket.settimeout(8)
        try:
            initial_data = client_socket.recv(16384)
        except socket.timeout:
            initial_data = b''
        client_socket.settimeout(None)
        
        if initial_data:
            req_str = initial_data.decode('utf-8', errors='ignore')
            log(f"Received request from {client_addr}")
            
            # Accept any NetMod HTTP/WebSocket upgrade request
            if 'upgrade' in req_str.lower() or 'websocket' in req_str.lower() or 'get /' in req_str.lower():
                response = (
                    "HTTP/1.1 101 Switching Protocols\r\n"
                    "Upgrade: websocket\r\n"
                    "Connection: Upgrade\r\n\r\n"
                )
                client_socket.sendall(response.encode('utf-8'))
                
                # Forward any trailing payload past the headers to Dropbear
                header_end = initial_data.find(b'\r\n\r\n')
                if header_end != -1:
                    remainder = initial_data[header_end + 4:]
                    if remainder:
                        target_socket.sendall(remainder)
            else:
                target_socket.sendall(initial_data)

        # Start bidirectional bridging threads
        t1 = threading.Thread(target=forward, args=(client_socket, target_socket, "Client->Dropbear"))
        t2 = threading.Thread(target=forward, args=(target_socket, client_socket, "Dropbear->Client"))
        t1.daemon = True
        t2.daemon = True
        t1.start()
        t2.start()
        t1.join()
        t2.join()
    except Exception as e:
        log(f"Handler error: {e}")
    finally:
        try:
            client_socket.close()
        except:
            pass
        try:
            target_socket.close()
        except:
            pass

def main():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind((LISTEN_IP, LISTEN_PORT))
    server.listen(500)
    log(f"WS-SSH Proxy listening on {LISTEN_IP}:{LISTEN_PORT} -> Dropbear:{BACKEND_PORT}")
    
    while True:
        client_sock, client_addr = server.accept()
        threading.Thread(target=client_handler, args=(client_sock, client_addr), daemon=True).start()

if __name__ == '__main__':
    main()
EOF

chmod +x /usr/local/bin/ws-ssh.py

cat > /etc/systemd/system/ws-ssh.service <<EOF
[Unit]
Description=AFTERLIFE SSH WebSocket Proxy (NetMod Fix)
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 -u /usr/local/bin/ws-ssh.py
Restart=always
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl restart ws-ssh
systemctl enable ws-ssh
