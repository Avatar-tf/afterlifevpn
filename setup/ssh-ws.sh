#!/bin/bash

WS_PORT=${1:-8880}

cat > /usr/local/bin/ws-ssh.py <<EOF
#!/usr/env/python3
import socket
import select
import sys

LISTEN_IP = '127.0.0.1'
LISTEN_PORT = int("$WS_PORT")
BACKEND_PORT = 109

def run_proxy():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind((LISTEN_IP, LISTEN_PORT))
    server.listen(500)
    
    while True:
        client_sock, client_addr = server.accept()
        try:
            # Connect to Dropbear locally
            backend_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            backend_sock.connect(('127.0.0.1', BACKEND_PORT))
            
            # Read initial client data (contains the WebSocket upgrade request)
            client_sock.setblocking(False)
            try:
                initial_data = client_sock.recv(8192)
            except BlockingIOError:
                initial_data = b''
                
            if initial_data:
                # If it's an HTTP/WS request, reply with 101 Switching Protocols back to client
                if b'Upgrade: websocket' in initial_data or b'upgrade: websocket' in initial_data.lower():
                    response = b"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n"
                    client_sock.sendall(response)
                    # Strip headers if they were bundled with early payload, or pass remaining binary payload to Dropbear
                    header_end = initial_data.find(b'\r\n\r\n')
                    if header_end != -1:
                        remainder = initial_data[header_end + 4:]
                        if remainder:
                            backend_sock.sendall(remainder)
                else:
                    # If raw payload, pass straight through
                    backend_sock.sendall(initial_data)
                    
            client_sock.setblocking(True)
            
            # Bidirectional non-blocking forwarding loop
            sockets = [client_sock, backend_sock]
            while True:
                r, w, e = select.select(sockets, [], sockets, 300)
                if e or not r:
                    break
                for s in r:
                    data = s.recv(16384)
                    if not data:
                        raise Exception("Connection closed")
                    if s is client_sock:
                        backend_sock.sendall(data)
                    else:
                        client_sock.sendall(data)
        except Exception:
            pass
        finally:
            client_sock.close()
            try:
                backend_sock.close()
            except:
                pass

if __name__ == '__main__':
    run_proxy()
EOF

chmod +x /usr/local/bin/ws-ssh.py

cat > /etc/systemd/system/ws-ssh.service <<EOF
[Unit]
Description=AFTERLIFE Secure WS-SSH Tunnel Proxy
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
