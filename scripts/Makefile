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
#    Sources are used in place from base_nics/open-nic-shell/src: nothing is
#    copied. Vivado output goes to $(BUILD_DIR)/$(BOARD).
#
#    make build_nic                 # project + synthesis + implementation
#    make synth                     # project + synthesis only
#    make project                   # project only
#    make build_nic OVERWRITE=1     # also regenerate all IPs from scratch
#    make synth BOOTROM_DIR=../examples/systolic_mm/bootrom_u55
#                                   # use that directory's bootrom.sv
#    make clean                     # delete $(BUILD_DIR)/$(BOARD)
#
# ==============================================================================

ROOT_DIR            := $(abspath ..)
BUILD_DIR           := $(ROOT_DIR)/build
SMARTNIC_SCRIPT_DIR := $(ROOT_DIR)/base_nics/open-nic-shell/script

BOARD       ?= au55c
JOBS        ?= 8
MAX_PKT_LEN ?= 9600
# 1: regenerate every IP; 0: reuse IPs already built in $(BUILD_DIR)/$(BOARD)
OVERWRITE   ?= 0
IMPL        ?= 1
SYNTH       ?= 1
# Directory of the bootrom.sv compiled into the RISC-V compute engine
BOOTROM_DIR ?= $(ROOT_DIR)/base_nics/open-nic-shell/src/box_250mhz/reconic/dpa/bootrom_u55

VIVADO      ?= vivado

# -rebuild 1: recreate the top-level project without the interactive prompt
# build.tcl shows when $(BUILD_DIR)/$(BOARD) already exists
VIVADO_ARGS = -board $(BOARD) -max_pkt_len $(MAX_PKT_LEN) -jobs $(JOBS) \
              -overwrite $(OVERWRITE) -rebuild 1 -synth $(SYNTH) -impl $(IMPL) \
              -bootrom $(abspath $(BOOTROM_DIR))/bootrom.sv

.PHONY: build_nic synth project clean

build_nic:
	cd $(SMARTNIC_SCRIPT_DIR); $(VIVADO) -mode batch -source build.tcl -tclargs $(VIVADO_ARGS) < /dev/null

synth:
	$(MAKE) build_nic SYNTH=1 IMPL=0

project:
	$(MAKE) build_nic SYNTH=0 IMPL=0

clean:
	rm -rf $(BUILD_DIR)/$(BOARD)
