# ==============================================================================
#  Copyright (C) 2026, Politecnico di Milano. All rights reserved.
#  SPDX-License-Identifier: MIT
#
# ==============================================================================
#
# Makefile
# -- Build the open-nic-shell project (RecoNIC box_250mhz plugin included) and,
#    optionally, run synthesis / implementation to generate the bitstream.
#
#    Sources are used in place from hw/open-nic-shell/src: nothing is
#    copied. Vivado output goes to $(BUILD_DIR)/$(BOARD).
#
#    make build_nic                 # project + synthesis + implementation
#    make synth                     # project + synthesis only
#    make project                   # project only
#    make build_nic OVERWRITE=1     # also regenerate all IPs from scratch
#    make synth BOOTROM_DIR=../examples/systolic_mm/bootrom_u55
#                                   # use that directory's bootrom.sv
#    make build_nic CE_CORE=mini    # riscv-mini compute engine instead of snitch
#    make mcs                       # convert $(BUILD_DIR)/$(BOARD)/bitstream/
#                                   # open_nic_shell.bit to .mcs (same dir)
#    make mcs BITSTREAM=foo.bit     # convert another bitstream
#    make program_fpga_bit TARGET_ID=<id>  # program the FPGA with the .bit
#                                          # (lost on cold reboot)
#    make program_fpga_mcs TARGET_ID=<id>  # write the .mcs to the flash
#                                          # (REMOTE_HOST=<host> for a remote hw_server)
#    make clean                     # delete $(BUILD_DIR)/$(BOARD)
#
# ==============================================================================

ROOT_DIR            := $(abspath ..)
BUILD_DIR           := $(ROOT_DIR)/build
SMARTNIC_SCRIPT_DIR := $(ROOT_DIR)/hw/open-nic-shell/script

BOARD       ?= au55c
JOBS        ?= 8
MAX_PKT_LEN ?= 9600
# 1: regenerate every IP; 0: reuse IPs already built in $(BUILD_DIR)/$(BOARD)
OVERWRITE   ?= 0
IMPL        ?= 1
SYNTH       ?= 1
# RISC-V compute engine, cores from the riscv-cores submodule:
# snitch (compute_engine) or mini (compute_engine_mini)
CE_CORE     ?= snitch
RISCV_CORES := $(ROOT_DIR)/hw/riscv-cores
CE_BUILD_DIR = $(BUILD_DIR)/$(BOARD)/compute_engine
# Directory of the bootrom.sv (module bootrom) compiled into the compute engine.
# Empty: built from $(RISCV_CORES)/bootrom_u55 for CE_CORE in $(CE_BUILD_DIR)
BOOTROM_DIR ?=
BOOTROM      = $(if $(BOOTROM_DIR),$(abspath $(BOOTROM_DIR))/bootrom.sv,$(CE_BUILD_DIR)/bootrom_$(CE_CORE)/bootrom.sv)
# riscv-mini Tile, generated from chisel (sbt) by the riscv-cores Makefile
CE_MINI_RTL  = $(CE_BUILD_DIR)/riscv_mini/Tile.sv
CE_DEPS      = $(BOOTROM) $(if $(filter mini,$(CE_CORE)),$(CE_MINI_RTL))

VIVADO      ?= vivado
PYTHON      ?= python3

IMPL_DIR      = $(BUILD_DIR)/$(BOARD)/open_nic_shell/open_nic_shell.runs/impl_1
BITSTREAM_DIR = $(BUILD_DIR)/$(BOARD)/bitstream
# Bitstream converted by `make mcs` and the resulting MCS file
BITSTREAM   ?= $(BITSTREAM_DIR)/open_nic_shell.bit
MCS_FILE    ?= $(BITSTREAM:.bit=.mcs)
# Debug probes file loaded when programming the FPGA
LTX_FILE    ?= $(BITSTREAM:.bit=.ltx)
# Hardware target name ID (Vivado Hardware Manager -> Open New Target), e.g. TARGET_ID=21770297400LA
TARGET_ID   ?=
# Optional remote hw_server hostname or IP
REMOTE_HOST ?=

PROGRAM_ARGS = -config_file $(LTX_FILE) -target_id $(TARGET_ID) \
               $(if $(REMOTE_HOST),-remote_host $(REMOTE_HOST))

# -rebuild 1: recreate the top-level project without the interactive prompt
# build.tcl shows when $(BUILD_DIR)/$(BOARD) already exists
VIVADO_ARGS = -board $(BOARD) -max_pkt_len $(MAX_PKT_LEN) -jobs $(JOBS) \
              -overwrite $(OVERWRITE) -rebuild 1 -synth $(SYNTH) -impl $(IMPL) \
              -bootrom $(BOOTROM) -ce_core $(CE_CORE) \
              $(if $(filter mini,$(CE_CORE)),-ce_mini_rtl $(CE_MINI_RTL))

.PHONY: build_nic mcs program_fpga_bit program_fpga_mcs check_target_id synth project clean FORCE

build_nic: $(CE_DEPS)
	cd $(SMARTNIC_SCRIPT_DIR); $(VIVADO) -mode batch -source build.tcl -tclargs $(VIVADO_ARGS) < /dev/null
ifeq ($(IMPL),1)
	mkdir -p $(BITSTREAM_DIR)
	cp $(IMPL_DIR)/open_nic_shell.ltx $(IMPL_DIR)/open_nic_shell.bit $(BITSTREAM_DIR)
endif

mcs:
	$(VIVADO) -mode batch -source generate_mcs.tcl -nojournal -nolog \
	  -tclargs -bitstream $(BITSTREAM) -mcs_file $(MCS_FILE) < /dev/null

program_fpga_bit: check_target_id
	$(VIVADO) -mode batch -source program_hw.tcl -nojournal -nolog \
	  -tclargs -prog_file $(BITSTREAM) $(PROGRAM_ARGS) < /dev/null

program_fpga_mcs: check_target_id
	$(VIVADO) -mode batch -source program_hw.tcl -nojournal -nolog \
	  -tclargs -prog_file $(MCS_FILE) $(PROGRAM_ARGS) < /dev/null

check_target_id:
	@test -n "$(TARGET_ID)" || { echo "Error: set TARGET_ID=<hw target name ID>"; exit 1; }

synth:
	$(MAKE) build_nic SYNTH=1 IMPL=0

project:
	$(MAKE) build_nic SYNTH=0 IMPL=0

# Default compute engine bootrom: bootrom_u55 of riscv-cores built for CE_CORE
# (bootrom_<core>.img), converted to bootrom.sv so that the module is named bootrom.
# FORCE: the bootrom_u55 Makefile decides what to rebuild
$(CE_BUILD_DIR)/bootrom_%/bootrom.sv: FORCE
	@test -f $(RISCV_CORES)/bootrom_u55/Makefile || \
	  { echo "Error: $(RISCV_CORES) is empty, run: git submodule update --init --recursive hw/riscv-cores"; exit 1; }
	$(MAKE) -C $(RISCV_CORES)/bootrom_u55 CORE=$* BUILD_DIR=$(@D) all
	cp $(@D)/bootrom_$*.img $(@D)/bootrom.img
	cd $(RISCV_CORES)/bootrom_u55 && $(PYTHON) ./gen_rom.py $(@D)/bootrom.img > /dev/null

# riscv-mini Tile (riscv-cores Makefile rule $(BUILD_DIR)/<run>/riscv_mini/Tile.sv)
$(CE_MINI_RTL):
	@test -f $(RISCV_CORES)/hw/cores/riscv-mini/Makefile || \
	  { echo "Error: no riscv-mini sources, run: git submodule update --init --recursive hw/riscv-cores"; exit 1; }
	$(MAKE) -C $(RISCV_CORES) BUILD_DIR=$(BUILD_DIR)/$(BOARD) $@

clean:
	rm -rf $(BUILD_DIR)/$(BOARD)
