# ==============================================================================
#  Copyright (C) 2026, Politecnico di Milano. All rights reserved.
#  SPDX-License-Identifier: MIT
#
# ==============================================================================
#
# Makefile
# -- Prepare and run the RecoNIC simulation.
#
#    make prepare_sim               # build everything the simulation needs:
#                                   # Vivado IPs (build/ip), compute engine
#                                   # bootrom and file lists, Python packages check
#    make sim TC=write CE_CORE=mini # riscv-mini compute engine instead of snitch
#    make prepare_sim OVERWRITE=1   # regenerate all IPs from scratch
#    make sim TC=write              # run a testcase (xsim, RDMA configuration)
#    make sim TC=read_2rdma SIM=questasim GUI=1
#    make regression                # run every testcase under testcases/
#    make clean                     # delete simulation outputs, keep the IPs
#    make distclean                 # also delete the generated IPs
#
#    The IPs are regenerated only when one of their scripts or the P4 program
#    changes. VIVADO_DIR defaults to the Vivado in PATH; Questa also needs
#    COMPILED_LIB_DIR (see README.md).
#
# ==============================================================================

ROOT_DIR   := $(abspath ..)
SIM_DIR    := $(ROOT_DIR)/sim
SCRIPT_DIR := $(SIM_DIR)/scripts
BUILD_DIR  := $(SIM_DIR)/build
IP_DIR     := $(BUILD_DIR)/ip

VIVADO     ?= vivado
PYTHON     ?= python3
# Simulator: xsim or questasim
SIM        ?= xsim
TC         ?= write
# 1: open the simulator GUI
GUI        ?= 0
# 1: RDMA (RoCEv2) testcase configuration, 0: plain Ethernet
ROCE       ?= 1
# 1: regenerate every IP even if its scripts did not change
OVERWRITE  ?= 0
# RISC-V compute engine, cores from the riscv-cores submodule: snitch or mini
CE_CORE     ?= snitch
RISCV_CORES := $(ROOT_DIR)/hw/riscv-cores
CE_BUILD_DIR = $(BUILD_DIR)/compute_engine
# Optional bootrom.sv (module bootrom) for the compute engine.
# Default: built from $(RISCV_CORES)/bootrom_u55 for CE_CORE
BOOTROM_DIR ?=
DPA_BOOTROM  = $(if $(BOOTROM_DIR),$(abspath $(BOOTROM_DIR))/bootrom.sv,$(CE_BUILD_DIR)/bootrom_$(CE_CORE)/bootrom.sv)
# riscv-mini Tile, generated from chisel (sbt) by the riscv-cores Makefile
CE_MINI_RTL  = $(CE_BUILD_DIR)/riscv_mini/Tile.sv
CE_DEPS      = $(DPA_BOOTROM) $(if $(filter mini,$(CE_CORE)),$(CE_MINI_RTL))
# read by scripts/*_compile.do
export CE_CORE DPA_BOOTROM CE_MINI_RTL

# Everything the IPs are generated from (sim/tcl first, see gen_vivado_ip.tcl)
IP_SRCS := $(wildcard $(SIM_DIR)/tcl/*.tcl) \
           $(wildcard $(ROOT_DIR)/hw/reconic/plugs/rdma_onic_plugin/vivado_ip/*.tcl) \
           $(ROOT_DIR)/hw/open-nic-shell/src/rdma_subsystem/vivado_ip/rdma_core.tcl \
           $(wildcard $(ROOT_DIR)/hw/reconic/packet_classification/*.p4)
IP_STAMP := $(IP_DIR)/.generated

RUN_ARGS = $(if $(filter 1,$(ROCE)),-roce) $(if $(filter questasim,$(SIM)),-questasim) \
           $(if $(filter 1,$(GUI)),-gui)

.PHONY: prepare_sim ips ce dpa_filelist check_python sim regression clean distclean FORCE

prepare_sim: ips dpa_filelist check_python
	@echo "INFO: simulation prepared, run e.g. 'make sim TC=$(TC)'"

ips: $(IP_STAMP)

ifeq ($(OVERWRITE),1)
.PHONY: $(IP_STAMP)
endif

$(IP_STAMP): $(IP_SRCS)
	rm -rf $(IP_DIR) $(BUILD_DIR)/managed_ip
	cd $(SCRIPT_DIR); $(VIVADO) -mode batch -nojournal -log $(BUILD_DIR)/gen_vivado_ip.log \
	  -source gen_vivado_ip.tcl < /dev/null
	touch $@

# compute engine sources generated from the riscv-cores submodule
ce: $(CE_DEPS)

# Default compute engine bootrom: bootrom_u55 of riscv-cores built for CE_CORE
# (bootrom_<core>.img), converted to bootrom.sv so that the module is named bootrom
$(CE_BUILD_DIR)/bootrom_%/bootrom.sv: FORCE
	@test -f $(RISCV_CORES)/bootrom_u55/Makefile || \
	  { echo "ERROR: $(RISCV_CORES) is empty, run: git submodule update --init --recursive hw/riscv-cores"; exit 1; }
	$(MAKE) -C $(RISCV_CORES)/bootrom_u55 CORE=$* BUILD_DIR=$(@D) all
	cp $(@D)/bootrom_$*.img $(@D)/bootrom.img
	cd $(RISCV_CORES)/bootrom_u55 && $(PYTHON) ./gen_rom.py $(@D)/bootrom.img > /dev/null

# riscv-mini Tile (riscv-cores Makefile rule $(BUILD_DIR)/<run>/riscv_mini/Tile.sv)
$(CE_MINI_RTL):
	@test -f $(RISCV_CORES)/hw/cores/riscv-mini/Makefile || \
	  { echo "ERROR: no riscv-mini sources, run: git submodule update --init --recursive hw/riscv-cores"; exit 1; }
	$(MAKE) -C $(RISCV_CORES) BUILD_DIR=$(BUILD_DIR) $@

# also written by scripts/*_compile.do at every compilation
dpa_filelist: ce
	cd $(SCRIPT_DIR); $(PYTHON) -I $(ROOT_DIR)/hw/reconic/compute/gen_ce_filelist.py -tool $(SIM) \
	  -core $(CE_CORE) -bootrom $(DPA_BOOTROM) $(if $(filter mini,$(CE_CORE)),-mini-rtl $(CE_MINI_RTL))

check_python:
	@$(PYTHON) -c "import scapy, numpy" 2>/dev/null || \
	  { echo "ERROR: missing Python packages, run: pip install scapy numpy"; exit 1; }

sim: $(IP_STAMP) ce check_python
	cd $(SIM_DIR); $(PYTHON) run_testcase.py $(RUN_ARGS) -tc $(TC)

regression: $(IP_STAMP) ce check_python
	cd $(SIM_DIR); $(PYTHON) run_testcase.py $(RUN_ARGS) regression

clean:
	cd $(SCRIPT_DIR); ./simulate.sh -c || true
	rm -f $(SCRIPT_DIR)/dpa.f $(SCRIPT_DIR)/dpa_inc.f

distclean: clean
	rm -rf $(BUILD_DIR)
