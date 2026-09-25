#!/bin/bash

WS_PORT=${1:-8880}

cat > /usr/local/bin/ws-ssh.py <<EOF
#!/usr/bin/env python3
import socket
import select
import threading
import sys
import traceback

LISTEN_PORT = int("$WS_PORT")
TARGET_PORT = 109

def log(msg):
    print(f"[WS-SSH] {msg}", flush=True)

def forward(source, destination, direction):
    try:
        while True:
            r, _, _ = select.select([source], [], [], 60)
            if r:
                data = source.recv(8192)
                if not data:
                    log(f"Connection closed by {direction}")
                    break
                destination.sendall(data)
    except Exception as e:
        log(f"Error in {direction}: {e}")
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
    log(f"Incoming connection from {client_addr}")
    target_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        target_socket.connect(('127.0.0.1', TARGET_PORT))
        
        # Read initial client handshake/payload
        client_socket.settimeout(5)
        try:
            initial_data = client_socket.recv(8192)
        except socket.timeout:
            initial_data = b''
        client_socket.settimeout(None)
        
        if initial_data:
            if b'Upgrade: websocket' in initial_data or b'upgrade: websocket' in initial_data.lower():
                response = b"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n"
                client_socket.sendall(response)
                log("Sent 101 Switching Protocols response")
                
                header_end = initial_data.find(b'\r\n\r\n')
                if header_end != -1:
                    remainder = initial_data[header_end + 4:]
                    if remainder:
                        target_socket.sendall(remainder)
                        log(f"Forwarded {len(remainder)} bytes of trailing payload to Dropbear")
            else:
                target_socket.sendall(initial_data)
                log("Forwarded raw non-WS data to Dropbear")

        t1 = threading.Thread(target=forward, args=(client_socket, target_socket, "Client->Dropbear"))
        t2 = threading.Thread(target=forward, args=(target_socket, client_socket, "Dropbear->Client"))
        t1.daemon = True
        t2.daemon = True
        t1.start()
        t2.start()
        t1.join()
        t2.join()
    except Exception as e:
        log(f"Handler error for {client_addr}: {e}")
        traceback.print_exc()
    finally:
        try:
            client_socket.close()
        except:
            pass
        try:
            target_socket.close()
        except:
            pass
        log(f"Connection closed for {client_addr}")

def main():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(('127.0.0.1', LISTEN_PORT))
    server.listen(500)
    log(f"Proxy listening on 127.0.0.1:{LISTEN_PORT} -> Dropbear:{TARGET_PORT}")
    
    while True:
        client_sock, client_addr = server.accept()
        threading.Thread(target=client_handler, args=(client_sock, client_addr), daemon=True).start()

if __name__ == '__main__':
    main()
EOF

chmod +x /usr/local/bin/ws-ssh.py

cat > /etc/systemd/system/ws-ssh.service <<EOF
[Unit]
Description=AFTERLIFE SSH WebSocket Proxy (Debug)
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
