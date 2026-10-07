<div align="center">

# AFTERLIFE VPN

Multi-protocol VPS management for **Ubuntu 20.04 / 22.04 / 24.04 LTS**

[github.com/Avatar-tf/afterlifevpn](https://github.com/Avatar-tf/afterlifevpn)

</div>

---

## Overview

AFTERLIFE VPN installs and manages Hysteria 2, SlowDNS/dnstt, SSH/Dropbear, Xray, SSH WebSocket, BadVPN, WireGuard and related services from one menu.

The recommended Hysteria + SlowDNS design uses **public UDP 53** as the client-facing port while the services stay on separate internal backend ports:

```text
Internet
   |
   | UDP 53
   v
AFTERLIFE Port 53 Demultiplexer
   |
   +-- small DNS/dnstt traffic --> UDP 5300
   |
   +-- Hysteria traffic --------> UDP 4430
```

In this mode Hysteria does **not** bind directly to UDP 53. The client still connects to UDP 53 because the mux redirects that traffic internally.

---

## Recommended system

- Fresh Ubuntu 24.04 LTS
- Ubuntu 22.04 and 20.04 are also supported
- Root access
- Public IPv4
- A domain already pointing to the VPS
- UDP 53 allowed by the VPS/cloud firewall

Do not run the installer on a server that already hosts important DNS, web or VPN services unless you understand the port and firewall changes it will make.

---

## DNS setup before installation

Create an A record for the main hostname:

```text
Type: A
Name: vpn
Target: YOUR_VPS_PUBLIC_IP
```

Example:

```text
vpn.example.com -> YOUR_VPS_PUBLIC_IP
```

If Cloudflare is used, keep the record **DNS only** while issuing the certificate.

For SlowDNS/dnstt, the installer also asks for a tunnel nameserver. The default is:

```text
ns.vpn.example.com
```

Create the DNS records required by your DNS provider so that the tunnel nameserver ultimately points to the VPS.

---

## Installation

Log in as root and run:

```bash
apt update && apt install -y wget curl
wget -qO install.sh https://raw.githubusercontent.com/Avatar-tf/afterlifevpn/main/install.sh
chmod +x install.sh
./install.sh
```

The installer asks only for:

1. Main domain
2. Tunnel nameserver

It then performs:

- OS and public-IP preflight checks
- DNS verification for the main domain
- TLS certificate issuance
- Nginx and Xray setup
- Hysteria backend installation
- SlowDNS/dnstt installation
- Dropbear/SSH WebSocket/BadVPN setup
- Port 53 mux setup
- Shared HY activation
- Final service and listener health checks

If the domain does not resolve to the VPS public IPv4, installation stops before certificate issuance instead of leaving a half-configured server.

---

## Default post-install state

A successful fresh install finishes in **Shared HY** mode:

```text
Public UDP 53
   |
   +--> dnstt backend UDP 5300
   |
   +--> Hysteria backend UDP 4430
```

Hysteria Salamander obfuscation is enabled automatically in Shared HY.

A unique Salamander secret is generated per server and stored at:

```text
/usr/local/afterlifevpn/hysteria-obfs.secret
```

The secret is reused when switching away from Shared HY and back again, so previously generated Shared-HY client links remain valid.

---

## Port 53 modes

Open:

```bash
menu
```

Then choose:

```text
11) Port 53
```

Available modes:

| Mode | Behavior |
|---|---|
| SlowDNS only | dnstt uses public UDP 53; Hysteria remains on backend 4430 |
| Hysteria only | Hysteria binds directly to UDP 53; dnstt is stopped |
| Shared HY | dnstt + Hysteria share public UDP 53; Salamander ON |
| Shared UDP | dnstt + UDP Custom share public UDP 53 |
| Shared ALL | dnstt + UDP Custom + Hysteria share public UDP 53; Hysteria obfs OFF |
| Reset Engine | Removes mux rules and returns Hysteria to backend mode |

### Shared HY — recommended for Hysteria

Shared HY keeps:

```text
Hysteria backend : UDP 4430
dnstt backend    : UDP 5300
Client port      : UDP 53
Salamander       : ON
```

Create a **new Hysteria account/link after selecting the desired port-53 mode** so the generated client link contains the correct port and obfuscation settings.

### Shared ALL

Shared ALL uses:

```text
0-300 byte UDP packets    -> dnstt 5300
301-1199 byte UDP packets -> UDP Custom 7300
remaining UDP packets     -> Hysteria 4430
```

Hysteria Salamander obfuscation is disabled in this mode by design.

---

## Hysteria 2 users

Open:

```text
menu
3) Hysteria 2
1) Manage Users
```

Each account receives its own generated password and expiration date.

When Shared HY or Shared ALL is active, generated links use public port 53 even though Hysteria itself is listening on backend 4430.

Example shape:

```text
hy2://PASSWORD@SERVER_IP:53?insecure=1&sni=your.domain&obfs=salamander&obfs-password=SECRET#user-Hy2
```

Do not manually change the server listener to 53 just because a generated client link contains `:53`.

---

## SlowDNS / dnstt

dnstt runs on:

```text
0.0.0.0:5300/udp
```

and forwards to:

```text
127.0.0.1:109
```

where Dropbear provides the SSH backend.

dnstt keys are stored in:

```text
/etc/afterlifevpn/dns/server.key
/etc/afterlifevpn/dns/server.pub
```

The private key is restricted to root.

---

## Important ports

| Port | Purpose |
|---|---|
| 22/tcp | OpenSSH |
| 80/tcp | ACME/certificate issuance |
| 109/tcp | Dropbear / SlowDNS SSH backend |
| 443/tcp | Nginx / TLS / Xray |
| 53/udp | Public Port 53 engine |
| 4430/udp | Hysteria backend in shared modes |
| 5300/udp | dnstt backend |
| 7300/udp | BadVPN / UDP Custom backend |
| 8443/tcp | Xray Reality |
| 2048/udp | WireGuard |

Your cloud firewall/security group must allow the public ports you intend to use. For the port-53 feature, **UDP 53** must be allowed.

---

## Certificates

Certificates are stored at:

```text
/etc/afterlifevpn/cert/fullchain.crt
/etc/afterlifevpn/cert/private.key
```

Permissions:

```text
fullchain.crt : 644
private.key   : 600
```

Certificate tools are available under:

```text
menu
10) Domain
```

When changing the server domain, point the new A record to the VPS first, wait for DNS propagation, issue/install the new certificate, and restart Nginx/Hysteria before generating new client links.

---

## Port 53 traffic counters

To verify the demultiplexer:

```text
menu
11) Port 53
7) View Raw Demux Counters
```

For a working Hysteria connection in Shared HY, the Hysteria redirect counter should increase.

A working Shared ALL Hysteria connection should similarly increase the redirect to backend UDP 4430.

---

## Reboot persistence

Fresh installs create:

```text
afterlife-port53.service
```

This restores the selected Port 53 mode after reboot.

The selected state is stored in:

```text
/usr/local/afterlifevpn/port53-mode.conf
```

---

## Useful checks

Service status:

```bash
systemctl status hysteria --no-pager
systemctl status dnstt --no-pager
systemctl status nginx --no-pager
systemctl status dropbear --no-pager
```

Listeners:

```bash
ss -tulnp
```

Hysteria config:

```bash
cat /etc/hysteria/config.yaml
```

Hysteria logs:

```bash
journalctl -u hysteria -n 50 --no-pager
```

dnstt logs:

```bash
journalctl -u dnstt -n 50 --no-pager
```

---

## Main files

```text
/usr/local/afterlifevpn/config.conf
/usr/local/afterlifevpn/nameserver.conf
/usr/local/afterlifevpn/port53-mode.conf
/usr/local/afterlifevpn/hysteria-obfs.secret
/usr/local/afterlifevpn/menu/menu.sh
/usr/local/afterlifevpn/setup/
/usr/local/afterlifevpn/users/hysteria_users.txt

/etc/afterlifevpn/cert/
/etc/afterlifevpn/dns/
/etc/hysteria/config.yaml
/etc/hysteria/auth.sh
```

---

## Updating AFTERLIFE

Use:

```text
menu
U) Update AFTERLIFE
```

The updater replaces management/setup scripts but does not intentionally overwrite active certificates or user databases.

After an update, verify the Port 53 counters and create a fresh test Hysteria account before relying on the server in production.

---

## Troubleshooting Hysteria on UDP 53

If a Hysteria link works on backend `:4430` but not public `:53`:

1. Confirm the selected Port 53 mode.
2. Generate a fresh Hysteria link after switching modes.
3. Check that Hysteria is running.
4. Check the Port 53 demux counters.
5. Verify UDP 53 is allowed by the cloud/VPS firewall.

In Shared HY this is the expected state:

```text
Hysteria bind :4430
Public link   :53
Obfs          :salamander ON
```

That is normal and does not mean the generated link is using the wrong port.

---

## Support

- Repository: https://github.com/Avatar-tf/afterlifevpn
- Telegram: @afterlife005

Use this project only where permitted by your provider, network policies and local law.
