<div align="center">

# AFTERLIFE VPN

Multi-protocol VPS panel for **Ubuntu 20.04 / 22.04 / 24.04 LTS**

[github.com/Avatar-tf/afterlifevpn](https://github.com/Avatar-tf/afterlifevpn)

</div>

---

## What you get

| Service | How it is meant to run |
|---|---|
| Hysteria 2 | **UDP 53**, password-only `hy2://` links, optional hop `53,20000-40000` |
| Dropbear SSH | **TCP 109** (SlowDNS target) + HTML banner in `/etc/issue.net` |
| OpenSSH | TCP 22 (do not replace with Dropbear) |
| SlowDNS (dnstt) | Listens on UDP **5300**, forwards to Dropbear `127.0.0.1:109` |
| Xray / SSH-WS / BadVPN | Installed by the main installer. Do not steal UDP 53 from Hysteria |

Hysteria client links (IP as host, domain only as SNI):

```text
hy2://PASSWORD@SERVER_IP:53?insecure=1&sni=your.domain#user-Hy2
hy2://PASSWORD@SERVER_IP:53,20000-40000?insecure=1&sni=your.domain#user-Hy2-Hop
```

---

## Requirements

- Fresh Ubuntu 20.04 / 22.04 / 24.04 and **root**
- Public IPv4
- A domain whose **A record** already points at this VPS
- Open these ports: `22/tcp`, `109/tcp`, `443/tcp`, `53/udp`, `5300/udp`, `20000-40000/udp`

On Azure and some Ubuntu 24 kernels, `iptables` is nft and may print `Incompatible with this kernel`. Use **`iptables-legacy`** for Port 53 mux rules.

---

## Install order (do not skip)

### 1. Point DNS first

At Cloudflare (or your DNS host):

- `A` record for the hostname → VPS IPv4
- Wait until this works:

```bash
dig +short your.domain
```

### 2. Install as root

```bash
apt update && apt install -y wget curl
wget -qO install.sh https://raw.githubusercontent.com/Avatar-tf/afterlifevpn/main/install.sh
chmod +x install.sh
sudo ./install.sh
```

Enter the domain when asked. Certificates go to `/etc/afterlifevpn/cert/`.

### 3. Confirm domain and certs

```bash
ls /etc/afterlifevpn/cert/fullchain.crt /etc/afterlifevpn/cert/private.key
cat /usr/local/afterlifevpn/config.conf
```

`DOMAIN=` must be your hostname.

### 4. Hysteria users (UDP 53)

Do **not** use Hysteria menu **Reinstall / Change Mode** on a working server.

```bash
menu
# 3 → Hysteria → 1 Manage Users → Add User
```

Or:

```bash
bash /usr/local/afterlifevpn/setup/hysteria-user.sh
```

Type **username** and **days** only. Password is generated. Test the STANDARD IP link first.

Check:

```bash
ss -ulnp | grep hysteria
grep -A3 '^auth:' /etc/hysteria/config.yaml
```

Need `*:53` and:

```yaml
auth:
  type: command
  command: /etc/hysteria/auth.sh
```

### 5. Dropbear banner

```bash
bash /usr/local/afterlifevpn/setup/dropbear.sh
ps aux | grep '[d]ropbear'
```

The process must show `-b /etc/issue.net` and keep the port already in use (**109** on the reference design).

Edit the banner later:

```bash
nano /etc/issue.net
systemctl restart dropbear
```

### 6. SlowDNS last (optional)

1. Install `/usr/local/bin/dnstt-server`
2. Service: UDP `0.0.0.0:5300` → `127.0.0.1:109`
3. DNS: `NS ns` → `ns.your.domain` and `A ns` → VPS IP
4. Only then use the Port 53 menu

If `iptables -t nat` fails:

```bash
iptables-legacy -t nat -L -n
```

Keep Hysteria on `:53`. Redirect only NS-name DNS queries to `5300`.

---

## Menu

```bash
menu
```

```text
1  SSH
2  Xray
3  Hysteria 2
4  WireGuard
5  L2TP
6  Subscriptions
7  BBR
8  Settings
9  Backup
10 Domain
11 Port 53
U  Download scripts from GitHub
V  Diagnostics
X  Exit
```

**U** only replaces files under `/usr/local/afterlifevpn`. It does **not** rewrite yaml, certificates, `/etc/issue.net`, or iptables.

After U, apply a component yourself if needed:

```bash
bash /usr/local/afterlifevpn/setup/dropbear.sh
bash /usr/local/afterlifevpn/setup/hysteria-user.sh
```

Do not run `setup/hysteria.sh` on a live node unless you accept a yaml reset.

---

## Hysteria rules

| Do | Do not |
|---|---|
| Keep `listen: :53` | Move Hysteria to 443 “just to test” |
| Create users with `hysteria-user.sh` | Rely on a single yaml `password` after users exist |
| Use `hy2://PASSWORD@IP:53?...` | Use `username:password@` unless you switched to userpass |
| Toggle Salamander only with the safe `hysteria.sh` | Press Reinstall / Change Mode on a working VPS |

Salamander **off** → short link.  
Salamander **on** → add `&obfs=salamander&obfs-password=SECRET`.

---

## Ports

| Port | Service |
|---|---|
| 22/tcp | OpenSSH |
| 109/tcp | Dropbear (dnstt backend) |
| 443/tcp | WS / Xray / TLS |
| 53/udp | Hysteria 2 |
| 5300/udp | dnstt-server |
| 7300 | badvpn-udpgw |
| 20000-40000/udp | Hysteria hop → 53 |

---

## Paths

```text
/usr/local/afterlifevpn/config.conf
/usr/local/afterlifevpn/setup/
/usr/local/afterlifevpn/menu/menu.sh
/usr/local/afterlifevpn/users/hysteria_users.txt
/etc/afterlifevpn/cert/
/etc/hysteria/config.yaml
/etc/hysteria/auth.sh
/etc/issue.net
/etc/default/dropbear
```

---

## Checks

```bash
systemctl is-active hysteria dropbear
ss -ulnp | grep -E ':(53|5300)\s'
ss -tlnp | grep -E ':(109|22|443)\s'
journalctl -u hysteria -n 20 --no-pager
```

A working Hysteria client shows `client connected` in that log.

---

## Pull scripts without the menu

```bash
BASE=https://raw.githubusercontent.com/Avatar-tf/afterlifevpn/main
ROOT=/usr/local/afterlifevpn
mkdir -p $ROOT/setup $ROOT/menu
for f in setup/dropbear.sh setup/hysteria.sh setup/hysteria-user.sh setup/slowdns.sh menu/menu.sh; do
  wget -q -O $ROOT/$f $BASE/$f && chmod +x $ROOT/$f
done
```

This does not restart services and does not change certificates.

---

## Support

- Repo: https://github.com/Avatar-tf/afterlifevpn
- Telegram: @afterlife005
- WhatsApp: +234 816 512 9071

For legitimate privacy and administration only. You are responsible for local law.
