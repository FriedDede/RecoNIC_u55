# Build and programming scripts

This folder builds the open-nic-shell with the RecoNIC `box_250mhz` plugin,
turns the resulting bitstream into a flash image (MCS) and programs the
FPGA. Everything is driven by the [Makefile](Makefile); run `make` from this
directory.

| File | Purpose |
| --- | --- |
| [Makefile](Makefile) | Entry point for all the targets below |
| [generate_mcs.tcl](generate_mcs.tcl) | Converts a `.bit` into a `.mcs` for the configuration flash |
| [program_hw.tcl](program_hw.tcl) | Programs the FPGA with a `.bit` or writes a `.mcs` to the flash |

Vivado must be on your `PATH` (or set `VIVADO=/path/to/vivado`).

## Typical flow

```sh
make build_nic                          # project + synthesis + implementation
make mcs                                # .bit -> .mcs
make program_fpga_mcs TARGET_ID=<id>    # write the flash
```

Then cold-reboot the host so the FPGA loads the new image from flash.

For a quick test that doesn't touch the flash, use
`make program_fpga_bit TARGET_ID=<id>` instead of the last two steps. A
bitstream loaded this way is lost on the next cold reboot.

## Targets

### Build

| Target | What it does |
| --- | --- |
| `build_nic` | Creates the Vivado project, runs synthesis and implementation, then copies `open_nic_shell.bit` and `open_nic_shell.ltx` to `build/<BOARD>/bitstream/` |
| `synth` | Creates the project and runs synthesis only |
| `project` | Creates the project only (no synthesis or implementation) |
| `clean` | Deletes `build/<BOARD>/` |

Sources are used in place from `base_nics/open-nic-shell/src`; nothing is
copied. Vivado output goes to `build/<BOARD>/`. An existing project is
recreated without prompting.

### Flash image

| Target | What it does |
| --- | --- |
| `mcs` | Converts `BITSTREAM` into `MCS_FILE` (SPIx4, 128 MB, start address `0x01002000`) |

### Programming

Both targets need `TARGET_ID` and stop with an error if it is missing.

| Target | What it does |
| --- | --- |
| `program_fpga_bit` | Loads `BITSTREAM` into the FPGA over JTAG (volatile) |
| `program_fpga_mcs` | Erases, writes and verifies `MCS_FILE` in the configuration flash, then boots the device from it |

`program_fpga_mcs` does not build the `.mcs`: run `make mcs` first.

`TARGET_ID` is the hardware target name shown by Vivado under
*Hardware Manager → Open New Target* (for example `21770297400LA`).

## Variables

Override any of these on the command line, e.g. `make build_nic JOBS=16`.

### Build

| Variable | Default | Description |
| --- | --- | --- |
| `BOARD` | `au55c` | Target board; also the name of the folder under `build/` |
| `JOBS` | `8` | Parallel Vivado jobs |
| `MAX_PKT_LEN` | `9600` | Maximum packet length |
| `OVERWRITE` | `0` | `1` regenerates every IP; `0` reuses IPs already built in `build/<BOARD>/` |
| `BOOTROM_DIR` | `base_nics/open-nic-shell/src/box_250mhz/reconic/dpa/bootrom_u55` | Directory whose `bootrom.sv` is compiled into the RISC-V compute engine |
| `VIVADO` | `vivado` | Vivado executable |

`SYNTH` and `IMPL` are set by the `synth` and `project` targets; you
normally don't need to touch them.

### Flash image and programming

| Variable | Default | Description |
| --- | --- | --- |
| `BITSTREAM` | `build/<BOARD>/bitstream/open_nic_shell.bit` | Bitstream used by `mcs` and `program_fpga_bit` |
| `MCS_FILE` | `BITSTREAM` with a `.mcs` extension | Output of `mcs`, input of `program_fpga_mcs` |
| `LTX_FILE` | `BITSTREAM` with a `.ltx` extension | Debug probes file loaded when programming |
| `TARGET_ID` | *(none, required)* | Hardware target name ID |
| `REMOTE_HOST` | *(none)* | Hostname or IP of a remote `hw_server` (port 3121); local server if unset |

## Examples

```sh
# Rebuild everything, including all IPs, with 16 jobs
make build_nic OVERWRITE=1 JOBS=16

# Build with the bootrom of the systolic matrix-multiply example
make build_nic BOOTROM_DIR=../examples/systolic_mm/bootrom_u55

# Convert and flash a bitstream stored somewhere else
make mcs BITSTREAM=/path/to/design.bit
make program_fpga_mcs TARGET_ID=21770297400LA BITSTREAM=/path/to/design.bit

# Program a board attached to another machine
# requires ssh access to the remote host and vivado hw_server running on the remote host
make program_fpga_bit TARGET_ID=21770297400LA REMOTE_HOST=fpga-host

# To run Vivado Hardware Server on a remote host, open a shell on the host and execute
hw_server
```

## Using the Tcl scripts directly

```sh
vivado -mode batch -source generate_mcs.tcl -tclargs \
    -bitstream <file.bit> [-mcs_file <file.mcs>]

vivado -mode batch -source program_hw.tcl -tclargs \
    -target_id <id> -prog_file <file.bit|file.mcs> \
    [-config_file <file.ltx>] [-remote_host <host>]
```

If `-mcs_file` is omitted, the `.mcs` is written next to the bitstream with
the same name.
