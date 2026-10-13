#!/usr/bin/env bash
# ==============================================================================
#  Copyright (C) 2026, Politecnico di Milano. All rights reserved.
#  SPDX-License-Identifier: MIT
#
# ==============================================================================
#
# netns_setup.sh
# -- Move the RecoNIC interface into its own network namespace so that traffic
#    between it and a second host NIC (the "peer") really goes over the wire
#    through the switch, instead of being short-circuited by the local stack.
#
#      [netns NS] CARD_IF CARD_IP --100G--> switch --> PEER_IF PEER_IP [host]
#
#    The switch routes between its two subnets (CARD_GW and PEER_GW are its
#    addresses on each side).
#
#    sudo ./netns_setup.sh up      # create the namespace and routes
#    sudo ./netns_setup.sh down    # give the interface back to the host
#
#    Defaults match the lab setup; override through the environment, e.g.
#    sudo CARD_IF=enp2s0 ./netns_setup.sh up
#
# ==============================================================================
set -euo pipefail

NS=${NS:-reconic}
CARD_IF=${CARD_IF:-enp1s0}
CARD_IP=${CARD_IP:-192.168.1.15/24}
CARD_GW=${CARD_GW:-192.168.1.1}
PEER_IF=${PEER_IF:-enxd0c0bf267d20}
# The switch's address on the peer subnet (not the peer's own address):
# default to the peer interface's default gateway
PEER_GW=${PEER_GW:-$(ip -4 route show default dev "$PEER_IF" | awk '{print $3; exit}')}
PEER_GW=${PEER_GW:-192.168.88.1}

card_net() { python3 -c "import ipaddress,sys; print(ipaddress.ip_interface(sys.argv[1]).network)" "$CARD_IP"; }

up() {
    if ip -4 -o addr show dev "$PEER_IF" | grep -qw "inet ${PEER_GW}"; then
        echo "PEER_GW=$PEER_GW is $PEER_IF's own address: it must be the switch" >&2
        exit 1
    fi
    ip netns add "$NS"
    # NetworkManager would otherwise keep reconfiguring the interface
    nmcli dev set "$CARD_IF" managed no 2>/dev/null || true
    ip link set "$CARD_IF" netns "$NS"
    ip -n "$NS" link set lo up
    ip -n "$NS" link set "$CARD_IF" up
    ip -n "$NS" addr add "$CARD_IP" dev "$CARD_IF"
    ip -n "$NS" route add default via "$CARD_GW"
    # Reach the card's subnet through the switch, not through the default route
    ip route replace "$(card_net)" via "$PEER_GW" dev "$PEER_IF"
    echo "namespace $NS: $CARD_IF $CARD_IP via $CARD_GW; host route $(card_net) via $PEER_GW dev $PEER_IF"
}

down() {
    ip route del "$(card_net)" via "$PEER_GW" dev "$PEER_IF" 2>/dev/null || true
    ip -n "$NS" link set "$CARD_IF" netns 1 2>/dev/null || true
    ip netns del "$NS" 2>/dev/null || true
    nmcli dev set "$CARD_IF" managed yes 2>/dev/null || true
    echo "namespace $NS removed, $CARD_IF back in the host namespace"
}

case "${1:-}" in
    up)   up ;;
    down) down ;;
    *)    echo "usage: $0 up|down" >&2; exit 1 ;;
esac
