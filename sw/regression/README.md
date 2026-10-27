# Datapath regression tests

Checks that the RecoNIC card still passes ordinary traffic correctly after a
change to the shell, the P4 classifier or the driver.

| File | Purpose |
| --- | --- |
| [datapath_test.py](datapath_test.py) | ICMP, UDP RX/TX and TCP RX/TX, with every byte verified |
| [netns_setup.sh](netns_setup.sh) | Puts the card in its own network namespace so traffic really goes over the wire |
| [udp_rx_test.py](udp_rx_test.py) | Quick UDP RX check using only the switch's DNS server, no setup needed |
| [reset_card.sh](reset_card.sh) | Cleans up after a stuck run: removes the namespace, unloads the driver, resets the PCIe function, reloads |

## Setup

The card and a second NIC of the same host both connect to the switch, which
routes between their two subnets:

```
[netns reconic] enp1s0 192.168.1.50 ──100G── switch ── enxd0c0bf267d20 192.168.88.254 [host]
                                     192.168.1.1   192.168.88.1
```

Without the namespace, Linux would deliver traffic between its own two
addresses internally and the card would never see it.

```sh
sudo ./netns_setup.sh up       # move the card into namespace "reconic"
sudo ./datapath_test.py        # run all tests
sudo ./netns_setup.sh down     # give the card back to the host
```

Interface names and addresses default to the lab setup. Override them through
the environment for `netns_setup.sh` (`CARD_IF`, `CARD_IP`, `CARD_GW`,
`PEER_IF`, `PEER_GW`, `NS`). `PEER_GW` is the switch's address on the peer
subnet and defaults to `PEER_IF`'s default gateway. `datapath_test.py` reads
the card address from the namespace and the peer address from the routing
table; `--card-ip`, `--peer-ip` and `--netns` override them.

## Tests

RX means peer → card, TX means card → peer.

| Test | What it checks |
| --- | --- |
| `ping` | ICMP echo at 56, 1472 and 4000 bytes (the last one is fragmented) |
| `udp_rx`, `udp_tx` | Every first payload byte 0x00–0xFF at sizes 5–8000 bytes (1792 datagrams), each first byte from its own source port (256 flows, so almost every RX queue is hit). Each datagram is compared byte for byte. |
| `tcp_rx`, `tcp_tx` | 8 parallel streams of 16 MiB each, compared by length and SHA-256 |

**Why every first byte:** the RecoNIC classifier used to treat any UDP
packet whose first payload byte looked like a RoCE opcode (0x00–0x1F) as
RDMA, and those packets never reached the host. That's how DHCP broke. A
failure of this kind is reported as:

```
[FAIL] udp_rx  1344/1792 datagrams intact, 0 corrupted
  size    64: missing first bytes 0x00-0x1F
```

**Why several ports and streams:** the shell spreads received IP traffic
over the RX queues by hashing the flow, so a single flow only exercises one
queue. A queue that is never serviced shows up as the same first bytes
missing at every size; the classifier bug shows up as the range 0x00-0x1F.

Run a subset with `-t udp_rx,tcp_tx`, change the load with `--tcp-streams`,
`--tcp-mib` and `--udp-sizes`, and check the script itself without a card
with `./datapath_test.py --local` (loopback).

The script exits with status 1 if any test fails.

## Quick check without setup

`udp_rx_test.py` needs only an address on the card and DNS enabled on the
switch (`/ip dns set allow-remote-requests=yes` and
`/ip dns static add name=reconic-test.lan address=10.0.0.1`):

```sh
python3 udp_rx_test.py 192.168.1.50 192.168.1.1
```

It covers UDP RX only, for a handful of first bytes.
