#==============================================================================
# Copyright (C) 2023, Advanced Micro Devices, Inc. All rights reserved.
# SPDX-License-Identifier: MIT
#
#==============================================================================
set ips {
  reconic_axil_crossbar
  packet_parser
  xlnx_clk_gen_cluster
}

# The shell reuses cached IPs (overwrite=0): drop the compute engine clock generator when it
# was built with other frequencies (ce_core_freq_mhz / ce_cluster_freq_mhz), so it is rebuilt
if {[info exists ip_build_dir] && [llength [get_ips -quiet xlnx_clk_gen_cluster]]} {
    set _clk_ip [get_ips xlnx_clk_gen_cluster]
    if {[expr {[get_property CONFIG.CLKOUT1_REQUESTED_OUT_FREQ $_clk_ip] != $ce_cluster_freq_mhz ||
               [get_property CONFIG.CLKOUT2_REQUESTED_OUT_FREQ $_clk_ip] != $ce_core_freq_mhz}]} {
        puts "INFO: \[xlnx_clk_gen_cluster\] frequencies changed (core $ce_core_freq_mhz, cluster $ce_cluster_freq_mhz MHz), rebuilding"
        set _clk_xci [get_files -quiet ${ip_build_dir}/xlnx_clk_gen_cluster/xlnx_clk_gen_cluster.xci]
        export_ip_user_files -of_objects $_clk_xci -no_script -reset -force -quiet
        remove_files -quiet $_clk_xci
        file delete -force ${ip_build_dir}/xlnx_clk_gen_cluster
    }
}