#==============================================================================
# Copyright (C) 2026, Politecnico di Milano. All rights reserved.
# SPDX-License-Identifier: MIT
#
#==============================================================================
# Compute engine cluster clock generator, instantiated by cluster_clk_gen
# (hw/riscv-cores/hw/cluster/cd_wrappers/cluster_clk_gen.sv), one per cluster:
#   cluster_clk   crossbar, bootrom, clint of the cluster
#   core_clk_<n>  one per core (each core is its own clock domain, <core>_cd_wrapper),
#                 the outputs of the cores that are not instantiated are trimmed
# Same ports as xlnx_clk_gen_cluster in hw/riscv-cores/tcl_scripts/gen_clock.tcl, but
# driven by the 250 MHz axis_aclk of the box_250mhz (already on a global clock buffer).
#
# Frequencies in MHz: set ce_core_freq_mhz / ce_cluster_freq_mhz before sourcing to change them.
foreach f {ce_core_freq_mhz ce_cluster_freq_mhz} {
    if {![info exists $f]} { set $f 50 }
}

set ipName xlnx_clk_gen_cluster
create_ip -name clk_wiz -vendor xilinx.com -library ip -module_name $ipName -dir ${ip_build_dir}

set props [list CONFIG.PRIM_IN_FREQ {250.000} \
                CONFIG.PRIM_SOURCE {No_buffer} \
                CONFIG.NUM_OUT_CLKS {7} \
                CONFIG.CLKIN1_JITTER_PS {50.0} \
                CONFIG.CLK_OUT1_PORT {cluster_clk} \
                CONFIG.CLKOUT1_REQUESTED_OUT_FREQ $ce_cluster_freq_mhz]
for {set n 0} {$n < 6} {incr n} {
    set o [expr {$n + 2}]
    lappend props CONFIG.CLKOUT${o}_USED {true} \
                  CONFIG.CLK_OUT${o}_PORT core_clk_$n \
                  CONFIG.CLKOUT${o}_REQUESTED_OUT_FREQ $ce_core_freq_mhz
}
set_property -dict $props [get_ips $ipName]
