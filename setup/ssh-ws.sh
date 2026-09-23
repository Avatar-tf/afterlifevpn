#!/bin/bash

DOMAIN=$1
WS_PORT=${2:-443}

# Install dependencies
apt install -y python3 python3-pip
pip3 install websockets

# Create WebSocket proxy script
cat > /usr/local/bin/ws-ssh.py <<EOF
#!/usr/bin/env python3
import asyncio
import websockets
import socket
import ssl

async def proxy(websocket, path):
    ssh_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    ssh_socket.connect(('127.0.0.1', 22))
    
    async def ws_to_ssh():
        try:
            async for message in websocket:
                ssh_socket.sendall(message)
        except:
            pass
    
    async def ssh_to_ws():
        try:
            while True:
                data = await asyncio.get_event_loop().run_in_executor(
                    None, ssh_socket.recv, 4096
                )
                if not data:
                    break
                await websocket.send(data)
        except:
            pass
    
    await asyncio.gather(ws_to_ssh(), ssh_to_ws())
    ssh_socket.close()

# SSL context
ssl_context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ssl_context.load_cert_chain('/etc/afterlifevpn/cert/fullchain.crt', '/etc/afterlifevpn/cert/private.key')

start_server = websockets.serve(proxy, "0.0.0.0", $WS_PORT, ssl=ssl_context)
asyncio.get_event_loop().run_until_complete(start_server)
asyncio.get_event_loop().run_forever()
EOF

chmod +x /usr/local/bin/ws-ssh.py

# Create systemd service
cat > /etc/systemd/system/ws-ssh.service <<EOF
[Unit]
Description=SSH WebSocket Proxy
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/ws-ssh.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Save port configuration
echo "$WS_PORT" > /usr/local/afterlifevpn/ws-port.conf

systemctl daemon-reload
systemctl start ws-ssh
systemctl enable ws-ssh

echo "SSH WebSocket installed on port $WS_PORT with SSL/TLS"
