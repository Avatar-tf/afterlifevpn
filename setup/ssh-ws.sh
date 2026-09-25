#!/bin/bash

# Default internal port for Nginx to proxy to
WS_PORT=${1:-8880}

# Create the Raw TCP WebSocket-to-SSH Proxy
cat > /usr/local/bin/ws-ssh.py <<EOF
#!/usr/bin/env python3
import socket
import threading
import select

LISTENING_PORT = int("$WS_PORT")
DROPBEAR_PORT = 109

def handle_client(client_socket):
    try:
        # Read the initial HTTP payload from NetMod/Cloudflare
        request = client_socket.recv(8192).decode('utf-8', errors='ignore')
        
        # If it asks for a WebSocket upgrade, send the fake 101 acceptance
        if "Upgrade: websocket" in request.lower() or "connection: upgrade" in request.lower():
            response = (
                "HTTP/1.1 101 Switching Protocols\r\n"
                "Upgrade: websocket\r\n"
                "Connection: Upgrade\r\n\r\n"
            )
            client_socket.send(response.encode('utf-8'))
            
        # Connect to the local Dropbear SSH server
        ssh_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        ssh_socket.connect(('127.0.0.1', DROPBEAR_PORT))
        
        # Blindly bridge the raw TCP traffic in both directions
        sockets = [client_socket, ssh_socket]
        while True:
            read_sockets, _, error_sockets = select.select(sockets, [], sockets)
            if error_sockets:
                break
            for sock in read_sockets:
                data = sock.recv(8192)
                if not data:
                    return
                if sock is client_socket:
                    ssh_socket.sendall(data)
                else:
                    client_socket.sendall(data)
                    
    except Exception:
        pass
    finally:
        client_socket.close()

def main():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(('127.0.0.1', LISTENING_PORT))
    server.listen(100)
    print(f"Raw WebSocket Proxy listening on 127.0.0.1:{LISTENING_PORT} -> Dropbear:109")
    
    while True:
        client_socket, _ = server.accept()
        client_thread = threading.Thread(target=handle_client, args=(client_socket,))
        client_thread.daemon = True
        client_thread.start()

if __name__ == '__main__':
    main()
EOF

chmod +x /usr/local/bin/ws-ssh.py

# Create systemd service
cat > /etc/systemd/system/ws-ssh.service <<EOF
[Unit]
Description=SSH WebSocket Proxy (Raw TCP)
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/ws-ssh.py
Restart=always
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

# Save port configuration
echo "$WS_PORT" > /usr/local/afterlifevpn/ws-port.conf

systemctl daemon-reload
systemctl restart ws-ssh
systemctl enable ws-ssh

echo "Raw SSH WebSocket Proxy installed on internal port $WS_PORT pointing to Dropbear on 109"
