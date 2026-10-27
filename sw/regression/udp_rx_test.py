#!/usr/bin/env python3
"""UDP RX test for the RecoNIC packet classifier.

Sends DNS queries to a DNS server reachable through the card (e.g. the
MikroTik on 192.168.1.1) and checks which replies make it to the host.

A DNS reply's first UDP payload byte is the high byte of the query ID, which
the classifier's parser reads as the RoCE BTH opcode. The unfixed classifier
marks the packet as RDMA when the top 3 bits of that byte are 000
(connType RC), i.e. for first bytes 0x00-0x1F, and the reply never reaches
the host. Bytes 0x20-0xFF must always pass.

Usage: udp_rx_test.py <card IPv4 address> <dns server> [name]
"""
import random
import socket
import struct
import sys

TRIES = 3
TIMEOUT = 1.0
FIRST_BYTES = [0x02, 0x10, 0x1F, 0x20, 0x41, 0x81, 0xFF]


def dns_query(qid, name):
    header = struct.pack(">HHHHHH", qid, 0x0100, 1, 0, 0, 0)  # RD, 1 question
    qname = b"".join(bytes([len(p)]) + p.encode() for p in name.split(".")) + b"\0"
    return header + qname + struct.pack(">HH", 1, 1)  # A, IN


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    src, server = sys.argv[1], sys.argv[2]
    name = sys.argv[3] if len(sys.argv) > 3 else "reconic-test.lan"

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind((src, 0))
    sock.settimeout(TIMEOUT)

    print(f"{'1st byte':>8}  {'connType':>8}  {'expected (old bitstream)':>24}  replies")
    for b in FIRST_BYTES:
        got = 0
        for _ in range(TRIES):
            qid = (b << 8) | random.randrange(256)
            sock.sendto(dns_query(qid, name), (server, 53))
            try:
                while True:
                    data, _ = sock.recvfrom(2048)
                    if len(data) >= 2 and struct.unpack(">H", data[:2])[0] == qid:
                        got += 1
                        break
            except socket.timeout:
                pass
        expected = "dropped" if b < 0x20 else "delivered"
        print(f"    0x{b:02X}  {b >> 5:>8}  {expected:>24}  {got}/{TRIES}")


if __name__ == "__main__":
    main()
