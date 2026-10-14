#==============================================================================
# Copyright (C) 2023, Advanced Micro Devices, Inc. All rights reserved.
# SPDX-License-Identifier: MIT
#
#==============================================================================
set prj_root [file normalize ..]
set p4_filepath ${prj_root}/src/box_250mhz/reconic/packet_classification

if {[info exists p4_dir]} {
  set p4file [glob -directory ${p4_dir} *.p4]
} else {
  set p4file [glob -directory ${p4_filepath} *.p4]
}

puts "p4file = ${p4file}"
create_ip -name vitis_net_p4 -vendor xilinx.com -library ip -module_name packet_parser -dir ${ip_build_dir}

set_property CONFIG.P4_FILE "${p4file}" [get_ips packet_parser]

# The IP cache key only covers the IP parameters, not the P4 source: derive
# JSON_TIMESTAMP from the P4 content so that editing the P4 invalidates the
# cached netlist (a fixed value made Vivado reuse a stale parser)
if {[catch {exec cksum $p4file} p4sum]} {
  set p4_stamp [file mtime $p4file]
} else {
  set p4_stamp [expr {[lindex $p4sum 0] & 0x7FFFFFFF}]
}
puts "p4 JSON_TIMESTAMP = ${p4_stamp}"

set_property -dict [list CONFIG.JSON_TIMESTAMP $p4_stamp CONFIG.TOTAL_LATENCY {23} CONFIG.EN_STATS_REGS {true} CONFIG.Component_Name {packet_parser}] [get_ips packet_parser]
