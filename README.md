<div align="center">

# AFTERLIFE VPN

**Multi-protocol VPS installer and management dashboard**

Ubuntu **20.04 / 22.04 / 24.04 LTS** · Hysteria2 · SlowDNS (dnstt) · Xray · SSH · Port 53 multiplexer

[Repository](https://github.com/Avatar-tf/afterlifevpn)

</div>

> **Fresh VPS strongly recommended.** Installation changes packages, systemd units, nginx, firewall persistence, and service configuration. Back up an existing machine before proceeding. Ubuntu 24.04 is the recommended tested target family; Ubuntu 26.04 is not yet validated.

## Before you install

You need:
- A VPS with **root/sudo**, public IPv4, and sufficient CPU/RAM/disk space.
- Ubuntu 20.04, 22.04, or 24.04 LTS (prefer 24.04).
- A hostname (for example `vpn.example.com`) with an **A record pointing to the VPS public IPv4**.
- SSH access that remains usable while configuring networking.
- **Inbound TCP 80** reachable during the standalone Let's Encrypt certificate request.
- Firewall/security-group access to allow the ports used by your chosen features.

### Firewall / cloud security group

| Traffic | Purpose | Notes |
|---|---|---|
| TCP 22 | OpenSSH administration | Keep open to your trusted access sources |
| TCP 80 | Let's Encrypt HTTP challenge; HTTP proxy | Needed for certificate issuance/renewal |
| TCP 443 | Nginx TLS / websocket services | Public-facing |
| TCP 109 | Dropbear (SlowDNS SSH target) | Only expose if direct Dropbear access needed |
| UDP 53 | Port 53 routing / Hysteria direct mode | Required for Port 53 modes |
| UDP 4430 | Hysteria2 backend | Required for direct 4430 connections |
| UDP 20000–40000 | Optional Hysteria hop | Enable only when configured |
| UDP 2048 | WireGuard | Enable when using WireGuard |

**Do not normally expose UDP 5300 or UDP 7300 publicly.** These are local redirect backends for SlowDNS and BadVPN. The current installer creates a `0.0.0.0:5300` SlowDNS listener; use your provider firewall or host firewall to block direct public access to that backend. Opening a port in the cloud security group does not configure Linux iptables automatically.

### DNS configuration

Create the main A record *before* running the installer:

```text
vpn.example.com   A   <VPS_PUBLIC_IP>
```

Verify from a machine with `dig`:

```bash
dig +short A vpn.example.com
```

For optional SlowDNS, arrange an NS delegation appropriate to your chosen tunnel hostname and the authoritative DNS provider. In the installer, the optional **SlowDNS nameserver** field should be the delegated tunnel name (for example `ns.vpn.example.com`) only if DNS delegation has been configured. Merely creating an A record for that name is not equivalent to working NS delegation.

## Fresh installation (Ubuntu)

1. SSH into the **new VPS** and elevate to root:

```bash
sudo -i
```

2. Install bootstrap tools and download the script:

```bash
apt-get update
apt-get install -y curl wget ca-certificates
wget -O /root/afterlife-install.sh https://raw.githubusercontent.com/Avatar-tf/afterlifevpn/main/install.sh
```

3. Optionally inspect the downloaded file, then execute:

```bash
less /root/afterlife-install.sh
bash /root/afterlife-install.sh
```

4. Provide the **main domain** when asked. Supply a SlowDNS nameserver if already delegated, or press **Enter to skip** and configure it later through the dashboard.

5. Let certificate generation and services finish. The script installs Hysteria on UDP **4430** by default; **it does not automatically activate Shared ALL**. Port 53 modes are selected separately from the dashboard.

6. Launch:

```bash
menu
# or
afterlife
```

> Certificate issuance requires DNS to resolve to the VPS **and TCP 80 to be reachable**. On failure check cloud security groups, any host firewall, existing web servers on port 80, and Let's Encrypt output. Do not repeatedly rerun the entire installer on an already configured server without backing up first.

## First-run verification

```bash
cat /usr/local/afterlifevpn/config.conf
ls -l /etc/afterlifevpn/cert/fullchain.crt /etc/afterlifevpn/cert/private.key
systemctl is-active nginx xray dropbear
systemctl is-active hysteria-server || systemctl is-active hysteria
ss -ulnp | grep -E ':(53|4430|5300|7300)\b' || true
ss -tlnp | grep -E ':(22|80|109|443)\b' || true
```

Hysteria may be called `hysteria-server.service` (official install) or `hysteria.service` (older/custom installs). The dashboard detects the installed unit rather than assuming one name.

Check Hysteria logs with whichever unit actually exists:

```bash
journalctl -u hysteria-server -n 50 --no-pager
# Older/custom systems:
journalctl -u hysteria -n 50 --no-pager
```

Validate Hysteria's YAML and command-auth helper:

```bash
grep -E '^(listen:|auth:|  type:|  command:)' /etc/hysteria/config.yaml
test -x /etc/hysteria/auth.sh && echo 'auth helper exists'
```

## Port 53 multiplexer (Option 11)

The **main** dashboard contains Port 53 routing. It uses `iptables-legacy` for the managed UDP/53 NAT chain `AFTERLIFE_MUX`; it does **not** replace the system-wide nftables backend.

| Dashboard mode | What happens |
|---|---|
| 1. SlowDNS only | Route UDP/53 to dnstt :5300 |
| 2. Hysteria only | Hysteria binds UDP/53 directly |
| 3. Shared HY | Split short packets to dnstt :5300; rest to Hysteria :4430 |
| 4. Shared UDP | Split short packets to dnstt :5300; rest to UDP Custom :7300 |
| **5. Shared ALL** | **0–300 bytes → :5300; 301–1199 bytes → :7300; remaining → :4430** |
| 6. Reset | Remove managed mux rules and restore default routing mode |
| 7. Counters | Inspect the NAT demux counters |
| 8. SlowDNS repair | Install or repair dnstt |

### Suggested Shared ALL setup

1. Finish installation and verify Hysteria starts on **4430**.
2. Configure the nameserver and install SlowDNS using **Option 11 → 8**, if not already installed.
3. Ensure dnstt is listening on **5300** and BadVPN UDP Custom on **7300**.
4. Open **Option 11 → 5 Shared ALL**, review the warning and confirm.
5. Shared ALL **turns off Hysteria Salamander obfuscation** to support packet-size routing. Client settings must match.
6. Check the counters from **Option 11 → 7**, then test each protocol with a real client.

**Important limitations:** the split is based on packet length, **not reliable protocol identification**. Real Hysteria QUIC packets may fall in the 301–1199 byte range and be sent to UDP Custom; therefore Shared ALL is **experimental**, not a guarantee that arbitrary Hysteria handshakes or MTU conditions work. DNS packets larger than 300 bytes can also be misrouted. If a connection fails, verify packet arrival and counter increments before changing firewall settings or ports.

### Validate legacy NAT routing

```bash
command -v iptables-legacy
iptables-legacy -t nat -S AFTERLIFE_MUX
iptables-legacy -t nat -L AFTERLIFE_MUX -n -v --line-numbers
iptables-legacy -t nat -S PREROUTING | grep AFTERLIFE_MUX
systemctl status afterlife-port53-restore.service --no-pager
```

The dedicated `afterlife-port53-restore.service` restores the saved AfterlifeVPN-owned legacy rules at boot. `netfilter-persistent` using nftables does **not** substitute for this legacy chain.

**If counters remain at zero:** confirm the client actually sends UDP packets to your VPS public IP on port 53, the cloud security group permits UDP 53, the operating system firewall is compatible, and the PREROUTING jump exists in the same iptables backend you are inspecting. The failure may be upstream on an ISP; do not assume that adding an INPUT ACCEPT rule fixes NAT or carrier filtering.

## Hysteria clients and users

Use **Menu → Hysteria → Manage Users** or:

```bash
bash /usr/local/afterlifevpn/setup/hysteria-user.sh
```

The installer uses command-based authentication:

```yaml
auth:
  type: command
  command: /etc/hysteria/auth.sh
```

Create users first, and use the links actually generated by the user manager. In port-53 NAT modes, the external client endpoint can be UDP 53 even though the Hysteria process listens on backend 4430. In direct mode the endpoint is 4430. Ensure client obfuscation settings match the selected mode.

**Do not** run the full Hysteria reinstallation option on a production server merely to change ports. It can overwrite YAML/auth configuration. Back up `/etc/hysteria/` and your users file first.

## Update an existing server

Back up relevant configuration **before** updating:

```bash
mkdir -p /root/afterlife-backup
cp -a /etc/hysteria /root/afterlife-backup/ 2>/dev/null || true
cp -a /usr/local/afterlifevpn /root/afterlife-backup/ 2>/dev/null || true
iptables-legacy-save > /root/afterlife-backup/iptables-legacy.rules 2>/dev/null || true
```

Run `menu`, then select **U — Update AFTERLIFE**. This downloads the latest management scripts and Port 53 restoration files; it **does not rerun the full installer**, rewrite certificates, or automatically reset the active Hysteria YAML. Revisit Option 11 and verify the current routing rules afterward.

> The menu's update operation is not the same as reapplying every installation-time configuration change. Fresh-install fixes may require a separate, reviewed migration on existing VPS instances.

## Troubleshooting shortcuts

```bash
systemctl is-active nginx xray dropbear dnstt
systemctl is-active hysteria-server || systemctl is-active hysteria
ss -ulnp
iptables-legacy -t nat -L AFTERLIFE_MUX -n -v
journalctl -u dnstt -n 40 --no-pager
journalctl -u afterlife-port53-restore -n 40 --no-pager
```

For packet arrival, install `tcpdump` if necessary and inspect an appropriate interface:

```bash
tcpdump -ni any 'udp dst port 53'
```

Run packet captures only on systems you administer and stop them after collecting the necessary evidence.

## Key paths

```text
/usr/local/afterlifevpn/config.conf
/usr/local/afterlifevpn/nameserver.conf
/usr/local/afterlifevpn/port53-mode.conf
/usr/local/afterlifevpn/menu/menu.sh
/usr/local/afterlifevpn/setup/
/usr/local/afterlifevpn/users/hysteria_users.txt
/usr/local/afterlifevpn/bin/afterlife-port53-restore.sh
/etc/hysteria/config.yaml
/etc/hysteria/auth.sh
/etc/afterlifevpn/cert/
/etc/afterlifevpn/dns/
/etc/issue.net
```

## Support

Repository: https://github.com/Avatar-tf/afterlifevpn

For legitimate, authorized privacy and server administration. Operators are responsible for their own deployment, cloud costs, and applicable laws.
