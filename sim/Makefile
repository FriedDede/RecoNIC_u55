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
#                                   # Vivado IPs (build/ip), DPA file lists,
#                                   # Python packages check
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
# Optional bootrom.sv for the RISC-V compute engine (default: the one in dpa)
DPA_BOOTROM ?=
export DPA_BOOTROM

# Everything the IPs are generated from (sim/tcl first, see gen_vivado_ip.tcl)
IP_SRCS := $(wildcard $(SIM_DIR)/tcl/*.tcl) \
           $(wildcard $(ROOT_DIR)/hw/reconic/plugs/rdma_onic_plugin/vivado_ip/*.tcl) \
           $(ROOT_DIR)/hw/open-nic-shell/src/rdma_subsystem/vivado_ip/rdma_core.tcl \
           $(ROOT_DIR)/hw/reconic/compute/dpa/vivado_ip/xlnx_clk_gen.tcl \
           $(wildcard $(ROOT_DIR)/hw/reconic/packet_classification/*.p4)
IP_STAMP := $(IP_DIR)/.generated

RUN_ARGS = $(if $(filter 1,$(ROCE)),-roce) $(if $(filter questasim,$(SIM)),-questasim) \
           $(if $(filter 1,$(GUI)),-gui)

.PHONY: prepare_sim ips dpa_filelist check_python sim regression clean distclean

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

dpa_filelist:
	cd $(SCRIPT_DIR); $(PYTHON) gen_dpa_filelist.py -tool $(SIM) $(if $(DPA_BOOTROM),-bootrom $(abspath $(DPA_BOOTROM)))

check_python:
	@$(PYTHON) -c "import scapy, numpy" 2>/dev/null || \
	  { echo "ERROR: missing Python packages, run: pip install scapy numpy"; exit 1; }

sim: $(IP_STAMP) check_python
	cd $(SIM_DIR); $(PYTHON) run_testcase.py $(RUN_ARGS) -tc $(TC)

regression: $(IP_STAMP) check_python
	cd $(SIM_DIR); $(PYTHON) run_testcase.py $(RUN_ARGS) regression

clean:
	cd $(SCRIPT_DIR); ./simulate.sh -c || true
	rm -f $(SCRIPT_DIR)/dpa.f $(SCRIPT_DIR)/dpa_inc.f

distclean: clean
	rm -rf $(BUILD_DIR)
