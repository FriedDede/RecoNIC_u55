# Address Map (Alveo U55C)

How the host and the RISC-V compute engine address the RecoNIC shell. Values
come from the RTL and IP configuration; the source of each table is linked
below it. Keep this page in sync when those files change.

## Overview

```
 Host                                        RISC-V (Snitch, 1 core)
  │                                            │
  ├─ BAR0  256 KB  QDMA DMA registers          ├─ 0x0000_0000  boot ROM
  │                                            ├─ 0x0200_0000  CLINT
  ├─ BAR2  8 MB    AXI-Lite registers          ├─ 0x1000_0000  desc_mem ◄──┐
  │    └─ 0x403000 desc_mem ───────────────────┼───────────────────────────┘
  │                                            │
  └─ QDMA MM (/dev/reconic-mm) ──► device ◄────┴─ 0x8000_0000  device memory
         offset = device address    memory         (first 2 GB)
                                    (HBM 16 GB)
                                        ▲
                         RDMA engine ───┘ 0xA350_0000_0000_0000 + offset
```

## Host view

### PCIe BARs (PF0)

| BAR | Size | Type | Use |
| --- | --- | --- | --- |
| BAR0 (`resource0`) | 256 KB | QDMA DMA registers | Queue contexts and pointers, used by the driver (libqdma) |
| BAR2 (`resource2`) | 8 MB | AXI-Lite master | Shell and RecoNIC registers, see below |

There is no BAR4: `RN_RDMA_MAP_SIZE` (256 MB) in the headers refers to a BAR
this shell does not expose.

BAR2 must be 8 MB: the box windows sit above 4 MB. With a 4 MB BAR2 (older
U55C builds) the RecoNIC registers are unreachable and reads return garbage.

Source: [qdma_no_sriov_au55c.tcl](../base_nics/open-nic-shell/src/qdma_subsystem/vivado_ip/qdma_no_sriov_au55c.tcl)

### BAR2 register space

| Offset | Size | Block |
| --- | --- | --- |
| `0x000000` | 4 KB | System config (shell reset and status) |
| `0x001000` | 20 KB | QDMA subsystem (function map, RSS indirection table) |
| `0x008000` | 12 KB | CMAC #0 (link, RS-FEC, statistics) |
| `0x00B000` | 4 KB | Packet adapter #0 |
| `0x00C000` | 12 KB | CMAC #1 (not built with 1 port) |
| `0x00F000` | 4 KB | Packet adapter #1 (not built with 1 port) |
| `0x010000` | 8 KB | Sysmon |
| `0x014000` | 16 KB | QDMA AXI bridge CSR |
| `0x200000` | 2 MB | RDMA subsystem (ERNIC) |
| `0x400000` | 1 MB | **Box0 @ 250 MHz: RecoNIC** |
| `0x500000` | 1 MB | Box1 @ 322 MHz |

Source: [system_config_axi_crossbar.tcl](../base_nics/open-nic-shell/src/system_config/vivado_ip/system_config_axi_crossbar.tcl),
[system_config_address_map.sv](../base_nics/open-nic-shell/src/system_config/system_config_address_map.sv)

### RecoNIC (Box0) registers

| Offset | Size | Block | Software |
| --- | --- | --- | --- |
| `0x400000` | 8 KB | P4 parser table control (not used) | |
| `0x402000` | 4 KB | Statistics and configuration registers | `RN_SCR_*` |
| `0x403000` | 4 KB | Compute logic: desc_mem, holds the control command | `RN_CLR_*`, `ctl_cmd.h` |

`RN_PC_BASE_ADDRESS` is `0x400000` in [lib/reconic_reg.h](../lib/reconic_reg.h)
and [examples/systolic_mm/rn_register.h](../examples/systolic_mm/rn_register.h).

Source: [reconic_axil_crossbar.tcl](../base_nics/open-nic-shell/src/box_250mhz/vivado_ip/reconic_axil_crossbar.tcl),
[reconic_address_map.sv](../base_nics/open-nic-shell/src/box_250mhz/reconic_address_map.sv)

### Device memory

Through the QDMA AXI-MM channel (`/dev/reconic-mm`), the file offset is the
device memory address: `0x0`-`0x3_FFFF_FFFF` (16 GB HBM).

## RISC-V view

One Snitch core in one cluster (`CORE_NUMBER = 1`, `CLUSTER_NUMBER = 1` in
`dpa_pkg.sv`).

| Address | Size | Target | Same location from the host |
| --- | --- | --- | --- |
| `0x0000_0000` | 64 KB | Boot ROM (firmware, `bootrom.sv`) | not visible |
| `0x0200_0000` | 48 KB | CLINT (timer, software interrupts) | not visible |
| `0x1000_0000` | 256 MB window, 4 KB decoded | desc_mem | BAR2 `0x403000` |
| `0x8000_0000` | 2 GB | Device memory `0x0`-`0x7FFF_FFFF` | `/dev/reconic-mm` offset = RISC-V address − `0x8000_0000` |

- The compute logic wrapper keeps the low 31 bits of device memory accesses,
  so RISC-V `0x8000_0000 + X` is device address `X` (`CE_DRAM_ADDR()` in
  `ctl_cmd.h`). The RISC-V only reaches the first 2 GB of the HBM.
- The firmware stack starts at `0xFFFF_FFF0` (device address `0x7FFF_FFF0`)
  and grows down: keep host data away from the top of the first 2 GB.

Source: [compute_engine.sv](../base_nics/open-nic-shell/src/box_250mhz/reconic/dpa/compute_engine.sv),
[compute_logic_wrapper.sv](../base_nics/open-nic-shell/src/box_250mhz/reconic/lookside/compute_logic_wrapper.sv),
[ctl_cmd.h](../examples/systolic_mm/ctl_cmd.h)

## Device memory (HBM)

| Device address | Physical |
| --- | --- |
| `0x0_0000_0000`-`0x1_FFFF_FFFF` | HBM pseudo-channels 0-15 (512 MB each), port SAXI_15 |
| `0x2_0000_0000`-`0x3_FFFF_FFFF` | HBM pseudo-channels 16-31, port SAXI_16 |

Source: [mem_ctrl/au55c/vivado_ip/hbm_interface.tcl](../base_nics/open-nic-shell/src/mem_ctrl/au55c/vivado_ip/hbm_interface.tcl)

Every master reaches the HBM through the 3-to-1 device memory crossbar:

| Master | Address it uses |
| --- | --- |
| Host (QDMA MM) | Device address |
| RISC-V | `0x8000_0000` + device address (first 2 GB only) |
| RDMA engine | `0xA350_0000_0000_0000` + offset (64 GB window) |

The RDMA engine's memory masters go through a 5-to-2 crossbar: port M00
(`0x0`, 52-bit) reaches host memory through the QDMA AXI bridge, port M01
(`0xA350_0000_0000_0000`, 36-bit) reaches device memory.

**Not verified:** the crossbars pass the full 64-bit address and the HBM
SmartConnect decodes only `0x0`-`0x3_FFFF_FFFF`. Check that the `0xA350...`
high bits are stripped before the HBM before relying on RDMA to device memory.

Source: [sys_mem_5to2_axi_crossbar.tcl](../base_nics/open-nic-shell/src/utility/vivado_ip/sys_mem_5to2_axi_crossbar.tcl),
[axi_5to2_interconnect_to_sys_mem.sv](../base_nics/open-nic-shell/src/utility/axi_5to2_interconnect_to_sys_mem.sv),
[axi_3to1_interconnect_to_dev_mem.sv](../base_nics/open-nic-shell/src/utility/axi_3to1_interconnect_to_dev_mem.sv)
