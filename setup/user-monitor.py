#!/usr/bin/env python3
"""AFTERLIFE VPN monitor: colorful, read-only terminal views.

Measurements are labeled by their actual provenance. No changes to VPN services,
firewall, authentication, logging, user records or connection limits.
"""
import collections
import datetime as dt
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

try:
    from colorama import Fore, Style, init
    init(autoreset=False)
except ImportError:
    class Fore:
        CYAN = "\033[96m"
        GREEN = "\033[92m"
        YELLOW = "\033[93m"
        RED = "\033[91m"
        MAGENTA = "\033[95m"
        BLUE = "\033[94m"
        WHITE = "\033[97m"
    class Style:
        BRIGHT = "\033[1m"
        RESET_ALL = "\033[0m"

ANSI = re.compile(r"\x1b\[[0-9;]*m")
USE_COLOR = sys.stdout.isatty() and os.environ.get("NO_COLOR") is None
W = min(102, max(38, shutil.get_terminal_size(fallback=(84, 24)).columns - 1))
INNER = W - 4


def color(value, shade):
    return shade + str(value) + Style.RESET_ALL if USE_COLOR else str(value)


def visible(text):
    return ANSI.sub("", str(text))


def truncate(text, limit):
    raw = visible(text)
    if len(raw) <= limit:
        return str(text)
    return raw[:max(0, limit - 1)] + ("…" if limit > 1 else "")


def frame_line(text=""):
    raw = truncate(str(text), INNER)
    pad = max(0, INNER - len(visible(raw)))
    return color("║", Fore.CYAN) + " " + raw + " " * pad + " " + color("║", Fore.CYAN)


def box(title, rows, tint=Fore.CYAN):
    # A single consistent terminal-width frame, including narrow mobile terminals.
    print(color("╔" + "═" * (W - 2) + "╗", tint))
    print(frame_line(color(title[:INNER], tint + Style.BRIGHT)))
    print(color("╟" + "─" * (W - 2) + "╢", tint))
    for line in rows:
        print(frame_line(line))
    print(color("╚" + "═" * (W - 2) + "╝", tint))
    print()


def table(headers, rows, widths=None):
    """Fixed-width columns; mobile terminals get fewer columns instead of overflow."""
    count = len(headers)
    spaces = (count - 1) * 2
    if widths is None:
        widths = [max(4, (INNER - spaces) // count)] * count
    widths = list(widths)
    while sum(widths) + spaces > INNER and max(widths) > 4:
        index = max(range(count), key=lambda i: widths[i])
        widths[index] -= 1
    if sum(widths) + spaces > INNER:
        # This occurs only on exceptionally narrow terminals.
        widths = [max(1, (INNER - spaces) // count)] * count

    def fmt(items):
        return "  ".join(truncate(x, n).ljust(n) for x, n in zip(items, widths))
    output = [color(fmt(headers), Fore.WHITE + Style.BRIGHT),
              color("─" * min(INNER, sum(widths) + spaces), Fore.BLUE)]
    if not rows:
        output.append(color("No records available.", Fore.YELLOW))
    else:
        for row in rows:
            output.append(fmt([str(v) for v in row]))
    return output


def run(*args, timeout=5):
    try:
        return subprocess.run(args, check=False, capture_output=True,
                              text=True, timeout=timeout).stdout
    except (OSError, subprocess.TimeoutExpired):
        return ""


def service(name):
    return "ACTIVE" if run("systemctl", "is-active", name).strip() == "active" else "OFFLINE"


def human(number):
    if number is None:
        return "N/A"
    value = float(number)
    for unit in ("B", "KiB", "MiB", "GiB", "TiB"):
        if abs(value) < 1024 or unit == "TiB":
            return f"{value:.1f}{unit}" if unit != "B" else f"{int(value)}B"
        value /= 1024
    return "N/A"


def elapsed(seconds):
    if seconds is None or seconds < 0:
        return "N/A"
    seconds = int(seconds)
    if seconds >= 86400:
        return f"{seconds // 86400}d{seconds % 86400 // 3600}h"
    if seconds >= 3600:
        return f"{seconds // 3600}h{seconds % 3600 // 60}m"
    return f"{seconds // 60}m{seconds % 60}s"


def process_age(pid):
    if not pid:
        return None
    # Approximate socket session duration using owning process lifetime.
    ps = run("ps", "-o", "etimes=", "-p", str(pid)).strip()
    try:
        return int(ps)
    except ValueError:
        return None


def parse_address(endpoint):
    # Covers IPv4, bracketed IPv6, and IPv4-mapped IPv6.
    if ":" not in endpoint:
        return endpoint, ""
    address, port = endpoint.rsplit(":", 1)
    return address.strip("[]"), port


def ssh_sockets():
    # ss -i exports current TCP per-socket counters only on supported kernels.
    # They reset at connection close and must never be called lifetime usage.
    output = run("ss", "-Htinp", "state", "established", timeout=7)
    sockets = []
    current = None
    for line in output.splitlines():
        if not line.strip():
            continue
        stripped = line.strip()
        # ss prints one unindented socket row followed by indented TCP metrics.
        if line[0] not in " \t":
            current = None
            parts = stripped.split()
            if len(parts) < 4:
                continue
            local_ip, port = parse_address(parts[2])
            remote_ip, _ = parse_address(parts[3])
            if port in ("22", "109") and remote_ip:
                pid_match = re.search(r"pid=(\d+)", stripped)
                current = {
                    "type": "SSH" if port == "22" else "Dropbear",
                    "ip": remote_ip,
                    "pid": pid_match.group(1) if pid_match else None,
                    "rx": None, "tx": None,
                }
                sockets.append(current)
            continue
        if current is not None:
            rx = re.search(r"\bbytes_received:(\d+)", stripped)
            tx = re.search(r"\bbytes_acked:(\d+)", stripped)
            if rx:
                current["rx"] = int(rx.group(1))
            if tx:
                current["tx"] = int(tx.group(1))
    return sockets


def ssh_rows():
    groups = {}
    for socket in ssh_sockets():
        key = (socket["type"], socket["ip"])
        group = groups.setdefault(key, {"age": None, "rx": 0, "tx": 0,
                                        "rx_all": True, "tx_all": True, "count": 0})
        group["count"] += 1
        age = process_age(socket["pid"])
        if age is not None:
            group["age"] = max(group["age"] or 0, age)
        for field in ("rx", "tx"):
            if socket[field] is None:
                group[field + "_all"] = False
            else:
                group[field] += socket[field]
    records = []
    for (kind, ip), values in sorted(groups.items()):
        rx = values["rx"] if values["rx_all"] else None
        tx = values["tx"] if values["tx_all"] else None
        total = rx + tx if rx is not None and tx is not None else None
        records.append({"type": kind, "ip": ip, "age": elapsed(values["age"]),
                        "rx": human(rx), "tx": human(tx),
                        "total": human(total), "count": values["count"]})
    return records


def xray_rows():
    path = Path("/var/log/xray/access.log")
    if not path.is_file() or not os.access(path, os.R_OK):
        return [], False
    # Bound CPU and memory: inspect last 4,000 lines only.
    lines = run("tail", "-n", "4000", str(path), timeout=6)
    users = collections.defaultdict(lambda: {"last": "N/A", "hits": 0})
    for line in lines.splitlines():
        if "accepted" not in line.lower():
            continue
        user = re.search(r"\bemail:\s*(\S+)", line)
        origin = re.search(r"\bfrom\s+(\[[\da-fA-F:]+\]|[\d.]+):\d+", line)
        if user and origin:
            key = (user.group(1), origin.group(1).strip("[]"))
            users[key]["hits"] += 1
            timestamp = re.search(r"\b(\d{4}[-/]\d\d[-/]\d\d[ T]\d\d:\d\d)", line)
            if timestamp:
                users[key]["last"] = timestamp.group(1)[-11:]
    return [{"user": u, "ip": ip, **data} for (u, ip), data in sorted(users.items())], True


def count_users(path):
    try:
        return sum(1 for row in Path(path).open(encoding="utf-8", errors="replace") if row.strip())
    except OSError:
        return 0


def server_traffic():
    iface = None
    route = run("ip", "-4", "route", "show", "default")
    match = re.search(r"\bdev\s+(\S+)", route)
    if match:
        iface = match.group(1)
    if not iface or not re.fullmatch(r"[\w.:-]+", iface):
        return None
    root = Path("/sys/class/net") / iface / "statistics"
    try:
        rx = int((root / "rx_bytes").read_text().strip())
        tx = int((root / "tx_bytes").read_text().strip())
    except (OSError, ValueError):
        return None
    return iface, rx, tx


def screen():
    if sys.stdout.isatty():
        sys.stdout.write("\033[2J\033[H")
        sys.stdout.flush()


def header(label):
    screen()
    print(color("  AFTERLIFE VPN  /  USER MONITOR", Fore.CYAN + Style.BRIGHT))
    print(color("  " + label.upper(), Fore.WHITE + Style.BRIGHT))
    print(color("  Monitor-only  |  No blocking  |  No config changes", Fore.GREEN))
    print()


def view_ssh():
    entries = ssh_rows()
    info = [
        f"OpenSSH: {service('ssh')}    Dropbear: {service('dropbear')}",
        f"Distinct socket peers: {len(entries)}",
    ]
    if INNER >= 76:
        cols = ["SERVICE", "REMOTE IP", "AGE~", "RX~", "TX~", "TOTAL~"]
        widths = [10, 24, 8, 9, 9, 10]
        rows = [[e["type"], e["ip"], e["age"], e["rx"], e["tx"], e["total"]] for e in entries]
    else:
        cols = ["REMOTE IP", "AGE~", "TOTAL~"]
        widths = [max(14, INNER - 24), 8, 12]
        rows = [[e["ip"], e["age"], e["total"]] for e in entries]
    box("SSH / DROPBEAR · CURRENT SOCKETS",
        info + [""] + table(cols, rows, widths)
        + ["", "AGE~ = owning process age (estimate).",
           "RX~/TX~ = socket TCP counters, if available.",
           "TOTAL~ = current TCP connections only; NOT account quota.",
           "WS-proxied peers may appear as localhost."], Fore.GREEN)


def view_xray():
    entries, available = xray_rows()
    info = [f"Xray: {service('xray')}    Log: {'readable' if available else 'not available'}",
            f"Historical account/IP pairs in sampled logs: {len(entries)}"]
    if INNER >= 76:
        cols, widths = ["ACCOUNT", "IP", "LAST LOG", "TOTAL"], [21, 24, 15, 10]
        rows = [[e["user"], e["ip"], e["last"], "N/A"] for e in entries]
    else:
        cols, widths = ["ACCOUNT", "IP", "TOTAL"], [max(11, INNER // 3), max(12, INNER // 2), 8]
        rows = [[e["user"], e["ip"], "N/A"] for e in entries]
    box("XRAY · VMESS / VLESS / TROJAN",
        info + [""] + table(cols, rows, widths)
        + ["", "Log IPs are HISTORICAL, not currently online.",
           "Session uptime and per-IP bytes: N/A until instrumented.",
           "No logging configuration was changed."], Fore.MAGENTA)


def view_hysteria():
    count = count_users("/usr/local/afterlifevpn/users/hysteria_users.txt")
    box("HYSTERIA 2 / SLOWDNS", [
        f"Hysteria service:  {service('hysteria-server')}",
        f"SlowDNS service:   {service('dnstt')}",
        f"Registered HY2 accounts: {count}",
        "",
        *table(["REMOTE IP", "UPTIME", "TOTAL"], [], [max(13, INNER - 23), 9, 10]),
        "",
        "Per-user IP, uptime and bandwidth: N/A.",
        "These counters require a verified protocol-level collector.",
    ], Fore.YELLOW)


def view_server():
    traffic = server_traffic()
    if traffic:
        iface, rx, tx = traffic
        values = [[iface, human(rx), human(tx), human(rx + tx)]]
        uptime = None
        try:
            uptime = float(Path("/proc/uptime").read_text().split()[0])
        except (OSError, ValueError):
            pass
        info = [f"Server uptime: {elapsed(uptime)}",
                "Network counters since interface initialization.",
                "Includes all traffic, not just VPN subscribers."]
    else:
        values = []
        info = ["Network interface/counters unavailable."]
    box("SERVER-WIDE BANDWIDTH", info + [""] +
        table(["INTERFACE", "DOWNLOAD", "UPLOAD", "TOTAL"], values,
              [max(10, INNER // 4), max(10, INNER // 4), max(10, INNER // 4), max(10, INNER // 4)]) +
        ["", "Interface RX/TX are host-wide, not per-user traffic."], Fore.CYAN)


def pause():
    try:
        input(color("  Press ENTER to return to the previous menu...", Fore.GREEN))
    except (EOFError, KeyboardInterrupt):
        pass


VIEWS = {
    "1": ("SSH / DROPBEAR", (view_ssh,)),
    "2": ("XRAY", (view_xray,)),
    "3": ("HYSTERIA / SLOWDNS", (view_hysteria,)),
    "4": ("SERVER TRAFFIC", (view_server,)),
    "5": ("ALL PROTOCOLS", (view_ssh, view_xray, view_hysteria, view_server)),
}


def main():
    while True:
        header("DASHBOARD")
        box("LIVE STATUS", [
            "SSH: {}   Dropbear: {}".format(service("ssh"), service("dropbear")),
            "Xray: {}   Hysteria: {}".format(service("xray"), service("hysteria-server")),
            "SlowDNS: {}".format(service("dnstt")),
        ])
        box("SELECT MONITORING PAGE", [
            "1)  SSH / Dropbear          Connected IPs + TCP session stats",
            "2)  Xray (V2Ray)           Account / IP history",
            "3)  Hysteria + SlowDNS     Service and account overview",
            "4)  Server-wide Traffic   Upload / download / totals",
            "5)  View All              Separate boxed tables",
            "0)  Return to AfterlifeVPN",
        ])
        try:
            answer = input(color("  Select [0-5]: ", Fore.YELLOW)).strip()
        except (EOFError, KeyboardInterrupt):
            return
        if answer == "0":
            return
        if answer in VIEWS:
            label, pages = VIEWS[answer]
            header(label)
            for page in pages:
                try:
                    page()
                except Exception as error:
                    # Monitoring must not crash the VPN menu or interfere with services.
                    box("MONITORING VIEW UNAVAILABLE",
                        [f"Unable to read monitoring data: {type(error).__name__}"],
                        Fore.RED)
            pause()


if __name__ == "__main__":
    main()
