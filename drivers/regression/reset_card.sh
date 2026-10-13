#!/usr/bin/env bash
# ==============================================================================
#  Copyright (C) 2026, Politecnico di Milano. All rights reserved.
#  SPDX-License-Identifier: MIT
#
# ==============================================================================
#
# reset_card.sh
# -- Bring the card back to a clean state between test runs: stop leftover
#    tests, remove the test namespace, unload the driver, reset the PCIe
#    function (QDMA and the logic behind it) and load the driver again.
#
#    sudo ./reset_card.sh                  # reload with default parameters
#    sudo ./reset_card.sh rsfec=0          # extra arguments go to insmod
#
#    This does not reload the FPGA image: if the card is still stuck, program
#    it again (scripts/: make program_fpga_bit TARGET_ID=...) or cold-reboot.
#
# ==============================================================================
set -uo pipefail

BDF=${BDF:-0000:01:00.0}
NS=${NS:-reconic}
HERE=$(dirname "$(readlink -f "$0")")
KO=${KO:-$HERE/../onic-driver/onic.ko}

step() { echo "== $*"; }

step "stopping leftover tests"
pkill -f datapath_test.py && sleep 1

if ip netns list | grep -qw "$NS"; then
    step "removing namespace $NS"
    "$HERE/netns_setup.sh" down
fi

if lsmod | grep onic; then
    step "unloading onic"
    if ! timeout 30 rmmod onic; then
        echo "rmmod onic did not complete: reprogram the FPGA or reboot" >&2
        exit 1
    fi
fi

step "PCIe reset of $BDF ($(cat /sys/bus/pci/devices/$BDF/reset_method))"
echo 1 > "/sys/bus/pci/devices/$BDF/reset" || { echo "reset failed" >&2; exit 1; }

step "loading $KO $*"
insmod "$KO" "$@" || exit 1
sleep 3

dmesg | tail -n 40 | grep -E "onic|qdma|ERROR" | tail -n 8
echo
grep qdma /proc/interrupts | awk '{s=0; for (i=2;i<=NF;i++) if ($i ~ /^[0-9]+$/) s+=$i; printf "%s %-8s %s\n", $1, s, $NF}'
