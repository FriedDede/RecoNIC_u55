#!/usr/bin/env python3
# ==============================================================================
#  Copyright (C) 2026, Politecnico di Milano. All rights reserved.
#  SPDX-License-Identifier: MIT
#
# ==============================================================================
"""RecoNIC datapath regression: ICMP, UDP RX/TX and TCP RX/TX.

Runs after `sudo ./netns_setup.sh up`: the card interface lives in network
namespace NS, the peer is a second host NIC reached through the switch. RX
means peer -> card, TX means card -> peer. Every payload is checked byte by
byte (UDP) or by length + SHA-256 (TCP).

  sudo ./datapath_test.py                    # all tests
  sudo ./datapath_test.py -t udp_rx,tcp_tx   # a subset
  ./datapath_test.py --local                 # self-test over loopback, no card

UDP sends every first payload byte 0x00-0xFF at each size (the classifier once
stole UDP packets whose first byte looked like a RoCE RC opcode), from several
source ports so that flows hash to different RX queues. Sizes above the MTU
are IP-fragmented. TCP runs several parallel streams for the same reason.
"""
import argparse
import hashlib
import json
import random
import socket
import struct
import subprocess
import sys
import threading
import time

UDP_PORT = 40000
TCP_PORT = 40001
UDP_SIZES = [5, 64, 300, 1000, 1472, 4000, 8000]
# One source port per first byte: 256 flows hash onto (almost) every RX queue.
# A dead queue shows up as the same first bytes missing at every size.
UDP_SRC_PORTS = 256
UDP_GAP_S = 0.0005
PING_SIZES = [56, 1472, 4000]


# ------------------------------------------------------------------------------
# Payloads: both sides rebuild them from (seed, case index)
# ------------------------------------------------------------------------------
def udp_cases(sizes):
    return [(size, fb) for size in sizes for fb in range(256)]


def udp_payload(seed, i, size, first_byte):
    # first byte under test, then the case index, then deterministic filler
    body = random.Random(seed * 1000003 + i).randbytes(size - 5)
    return bytes([first_byte]) + struct.pack(">I", i) + body


def tcp_stream(seed, nbytes, chunk=1 << 16):
    rng = random.Random(seed)
    while nbytes > 0:
        n = min(chunk, nbytes)
        yield rng.randbytes(n)
        nbytes -= n


# ------------------------------------------------------------------------------
# Endpoints. A receiver prints READY once bound, then a JSON result.
# ------------------------------------------------------------------------------
def udp_recv(p, ready):
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 16 << 20)
    sock.bind((p["ip"], UDP_PORT))
    cases = udp_cases(p["sizes"])
    got, bad = set(), 0
    ready()
    sock.settimeout(p["start_timeout"])
    try:
        while len(got) < len(cases):
            data = sock.recv(65535)
            sock.settimeout(p["idle_timeout"])
            if len(data) < 5:
                bad += 1
                continue
            i = struct.unpack(">I", data[1:5])[0]
            if i < len(cases) and data == udp_payload(p["seed"], i, *cases[i]):
                got.add(i)
            else:
                bad += 1
    except socket.timeout:
        pass
    return {"got": sorted(got), "bad": bad}


def udp_send(p):
    socks = []
    for _ in range(UDP_SRC_PORTS):
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.bind((p["src"], 0))
        socks.append(s)
    for i, (size, fb) in enumerate(udp_cases(p["sizes"])):
        socks[i % len(socks)].sendto(udp_payload(p["seed"], i, size, fb), (p["dst"], UDP_PORT))
        time.sleep(UDP_GAP_S)
    return {"sent": len(udp_cases(p["sizes"]))}


def tcp_recv(p, ready):
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind((p["ip"], TCP_PORT))
    srv.listen(p["streams"])
    srv.settimeout(p["start_timeout"])
    results, threads = {}, []

    def drain(conn):
        conn.settimeout(p["idle_timeout"])
        h, n, sid = hashlib.sha256(), 0, None
        try:
            sid = struct.unpack(">I", _recv_exact(conn, 4))[0]
            while True:
                data = conn.recv(1 << 20)
                if not data:
                    break
                h.update(data)
                n += len(data)
        except (socket.timeout, OSError, EOFError) as e:
            results[sid if sid is not None else f"?{id(conn)}"] = {"len": n, "sha": None, "err": str(e)}
            return
        finally:
            conn.close()
        results[sid] = {"len": n, "sha": h.hexdigest()}

    ready()
    try:
        for _ in range(p["streams"]):
            conn, _ = srv.accept()
            t = threading.Thread(target=drain, args=(conn,))
            t.start()
            threads.append(t)
    except socket.timeout:
        pass
    for t in threads:
        t.join()
    return {"streams": {str(k): v for k, v in results.items()}}


def tcp_send(p):
    results = {}

    def push(sid):
        h = hashlib.sha256()
        try:
            s = socket.create_connection((p["dst"], TCP_PORT), timeout=p["idle_timeout"],
                                         source_address=(p["src"], 0))
            s.sendall(struct.pack(">I", sid))
            for chunk in tcp_stream(p["seed"] + sid, p["nbytes"]):
                h.update(chunk)
                s.sendall(chunk)
            s.shutdown(socket.SHUT_WR)
            s.recv(1)  # wait for the receiver to close
            s.close()
            results[sid] = {"len": p["nbytes"], "sha": h.hexdigest()}
        except OSError as e:
            results[sid] = {"len": 0, "sha": None, "err": str(e)}

    threads = [threading.Thread(target=push, args=(sid,)) for sid in range(p["streams"])]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    return {"streams": {str(k): v for k, v in results.items()}}


def _recv_exact(conn, n):
    buf = b""
    while len(buf) < n:
        data = conn.recv(n - len(buf))
        if not data:
            raise EOFError("connection closed early")
        buf += data
    return buf


ROLES = {"udp_recv": udp_recv, "udp_send": udp_send, "tcp_recv": tcp_recv, "tcp_send": tcp_send}
RECEIVERS = {"udp_recv", "tcp_recv"}


def agent_main(role, params):
    """Entry point inside the card namespace: result goes to stdout as JSON."""
    p = json.loads(params)
    if role in RECEIVERS:
        res = ROLES[role](p, lambda: print("READY", flush=True))
    else:
        res = ROLES[role](p)
    print(json.dumps(res), flush=True)


# ------------------------------------------------------------------------------
# Orchestration: card side runs as a subprocess in the namespace, peer side
# runs here in a thread
# ------------------------------------------------------------------------------
class CardSide:
    def __init__(self, args):
        self.args = args

    def cmd(self, argv):
        return argv if self.args.local else ["ip", "netns", "exec", self.args.netns] + argv

    def start(self, role, params):
        proc = subprocess.Popen(self.cmd([sys.executable, "-I", __file__, "--agent", role, json.dumps(params)]),
                                stdout=subprocess.PIPE, text=True)
        if role in RECEIVERS:
            line = proc.stdout.readline().strip()
            if line != "READY":
                proc.kill()
                raise RuntimeError(f"card-side {role} did not start: {line!r}")
        return proc

    @staticmethod
    def result(proc, timeout):
        out, _ = proc.communicate(timeout=timeout)
        lines = out.strip().splitlines()
        if not lines:
            raise RuntimeError(f"card-side agent exited with status {proc.returncode} and no result")
        return json.loads(lines[-1])

    def detect_ips(self):
        """Card IP: the namespace's IPv4 address. Peer IP: the host source
        address used to reach it."""
        out = subprocess.run(["ip", "-n", self.args.netns, "-4", "-o", "addr", "show", "scope", "global"],
                             capture_output=True, text=True, check=True).stdout.split()
        if "inet" not in out:
            raise RuntimeError(f"no IPv4 address in namespace {self.args.netns}: run netns_setup.sh up")
        card_ip = out[out.index("inet") + 1].split("/")[0]
        route = subprocess.run(["ip", "-4", "route", "get", card_ip],
                               capture_output=True, text=True, check=True).stdout.split()
        return card_ip, route[route.index("src") + 1]


def run_peer(role, params):
    """Run an endpoint in this process; returns (thread, ready event, result holder)."""
    ready, holder = threading.Event(), {}

    def body():
        if role in RECEIVERS:
            holder["res"] = ROLES[role](params, ready.set)
        else:
            holder["res"] = ROLES[role](params)
    t = threading.Thread(target=body)
    t.start()
    return t, ready, holder


def ranges(vals):
    """[0,1,2,5] -> '0x00-0x02,0x05'"""
    out, vals = [], sorted(vals)
    i = 0
    while i < len(vals):
        j = i
        while j + 1 < len(vals) and vals[j + 1] == vals[j] + 1:
            j += 1
        out.append(f"0x{vals[i]:02X}" if i == j else f"0x{vals[i]:02X}-0x{vals[j]:02X}")
        i = j + 1
    return ",".join(out)


def udp_report(args, got, bad):
    cases, got = udp_cases(args.udp_sizes), set(got)
    missing = {}
    for i, (size, fb) in enumerate(cases):
        if i not in got:
            missing.setdefault(size, []).append(fb)
    ok = not missing and bad == 0
    lines = [f"{len(cases) - sum(map(len, missing.values()))}/{len(cases)} datagrams intact, {bad} corrupted"]
    for size, fbs in missing.items():
        lines.append(f"  size {size:5d}: missing first bytes {ranges(fbs)}")
    return ok, lines


def tcp_report(args, sent, recv):
    ok, lines = True, []
    for sid in range(args.tcp_streams):
        s, r = sent.get(str(sid), {}), recv.get(str(sid), {})
        good = s.get("sha") and s.get("sha") == r.get("sha") and s.get("len") == r.get("len")
        ok &= bool(good)
        if not good:
            lines.append(f"  stream {sid}: sent {s.get('len')} B {s.get('err', '')} / "
                         f"received {r.get('len')} B {r.get('err', '')}, sha256 mismatch")
    total = args.tcp_mib * args.tcp_streams
    lines.insert(0, f"{args.tcp_streams} streams x {args.tcp_mib} MiB ({total} MiB) "
                    + ("sha256 match" if ok else "FAILED"))
    return ok, lines


def test_ping(args, card):
    lost = []
    for size in PING_SIZES:
        r = subprocess.run(card.cmd(["ping", "-c", "3", "-W", "1", "-s", str(size), args.peer_ip]),
                           capture_output=True, text=True)
        if r.returncode != 0:
            lost.append(size)
    sizes = "/".join(map(str, PING_SIZES))
    return not lost, [f"{sizes} B" + (f", no reply at {lost}" if lost else " ok")]


def test_udp(args, card, direction):
    seed = random.randrange(1 << 30)
    common = {"sizes": args.udp_sizes, "seed": seed, "start_timeout": 10, "idle_timeout": 3}
    if direction == "rx":
        proc = card.start("udp_recv", dict(common, ip=args.card_ip))
        t, _, _ = run_peer("udp_send", dict(common, src=args.peer_ip, dst=args.card_ip))
        t.join()
        res = card.result(proc, 60)
    else:
        t, ready, holder = run_peer("udp_recv", dict(common, ip=args.peer_ip))
        ready.wait(10)
        proc = card.start("udp_send", dict(common, src=args.card_ip, dst=args.peer_ip))
        card.result(proc, 60)
        t.join()
        res = holder["res"]
    return udp_report(args, res["got"], res["bad"])


def test_tcp(args, card, direction):
    seed = random.randrange(1 << 30)
    common = {"streams": args.tcp_streams, "nbytes": args.tcp_mib << 20, "seed": seed,
              "start_timeout": 10, "idle_timeout": 15}
    if direction == "rx":
        proc = card.start("tcp_recv", dict(common, ip=args.card_ip))
        t, _, holder = run_peer("tcp_send", dict(common, src=args.peer_ip, dst=args.card_ip))
        t.join()
        recv, sent = card.result(proc, 300), holder["res"]
    else:
        t, ready, holder = run_peer("tcp_recv", dict(common, ip=args.peer_ip))
        ready.wait(10)
        proc = card.start("tcp_send", dict(common, src=args.card_ip, dst=args.peer_ip))
        sent = card.result(proc, 300)
        t.join()
        recv = holder["res"]
    return tcp_report(args, sent["streams"], recv["streams"])


TESTS = {
    "ping":   test_ping,
    "udp_rx": lambda a, c: test_udp(a, c, "rx"),
    "udp_tx": lambda a, c: test_udp(a, c, "tx"),
    "tcp_rx": lambda a, c: test_tcp(a, c, "rx"),
    "tcp_tx": lambda a, c: test_tcp(a, c, "tx"),
}


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--agent":
        return agent_main(sys.argv[2], sys.argv[3])

    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("-t", "--tests", default=",".join(TESTS), help="comma-separated subset of: " + ",".join(TESTS))
    ap.add_argument("--netns", default="reconic", help="namespace holding the card interface")
    ap.add_argument("--card-ip", help="default: the address in --netns")
    ap.add_argument("--peer-ip", help="default: the host address that routes to --card-ip")
    ap.add_argument("--udp-sizes", default=",".join(map(str, UDP_SIZES)),
                    type=lambda s: [int(x) for x in s.split(",")], help="UDP payload sizes, >= 5")
    ap.add_argument("--tcp-streams", type=int, default=8)
    ap.add_argument("--tcp-mib", type=int, default=16, help="MiB per TCP stream")
    ap.add_argument("--local", action="store_true", help="self-test of this script over loopback")
    args = ap.parse_args()
    card = CardSide(args)
    if args.local:
        args.card_ip = args.peer_ip = "127.0.0.1"
    elif not (args.card_ip and args.peer_ip):
        card_ip, peer_ip = card.detect_ips()
        args.card_ip = args.card_ip or card_ip
        args.peer_ip = args.peer_ip or peer_ip
    print(f"card {args.card_ip} (netns {args.netns}) <-> peer {args.peer_ip}")
    failed = []
    for name in args.tests.split(","):
        try:
            ok, lines = TESTS[name](args, card)
        except Exception as e:  # report and keep going with the other tests
            ok, lines = False, [f"error: {e!r}"]
        # lines[0] is the summary, the rest are details
        print(f"[{'PASS' if ok else 'FAIL'}] {name:7s} {lines[0]}")
        for line in lines[1:]:
            print(line)
        if not ok:
            failed.append(name)
    print("all tests passed" if not failed else f"FAILED: {', '.join(failed)}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
