#==============================================================================
# Copyright (C) 2023, Advanced Micro Devices, Inc. All rights reserved.
# SPDX-License-Identifier: MIT
#
#==============================================================================
array set build_options {
  -ip ""
  -board_repo ""
}

# Expect arguments in the form of `-argument value`
for {set i 0} {$i < $argc} {incr i 2} {
    set arg [lindex $argv $i]
    set val [lindex $argv [expr $i+1]]
    if {[info exists build_options($arg)]} {
        set build_options($arg) $val
        puts "Set build option $arg to $val"
    } elseif {[info exists design_params($arg)]} {
        set design_params($arg) $val
        puts "Set design parameter $arg to $val"
    } else {
        puts "Skip unknown argument $arg and its value $val"
    }
}

# Settings based on defaults or passed in values
foreach {key value} [array get build_options] {
    set [string range $key 1 end] $value
}

if {[string equal $ip ""]} {
  puts "ERROR: Please provide correct IP name"
  exit
}

# Default to the board files shipped with open-nic-shell
if {[string equal $board_repo ""]} {
  set board_repo [file normalize ../../hw/open-nic-shell/board_files]
}
set_param board.repoPaths $board_repo

set vivado_version 2021.2
set board au250
set part xcu250-figd2104-2l-e
set board_part xilinx.com:au250:part0:1.3

set root_dir [file normalize ../..]
set ip_src_dir $root_dir/hw/reconic/plugs/rdma_onic_plugin
set sim_dir $root_dir/sim
# IP scripts, first match wins: sim-only ones, then those shared with the build
set ip_tcl_dirs [list $sim_dir/tcl $root_dir/hw/reconic/plugs/rdma_onic_plugin/vivado_ip \
                      $root_dir/hw/open-nic-shell/src/rdma_subsystem/vivado_ip]
proc source_ip_tcl {ip} {
  foreach d $::ip_tcl_dirs {
    if {[file exists $d/${ip}.tcl]} {
      uplevel #0 [list source $d/${ip}.tcl]
      return
    }
  }
  error "ERROR: no IP script for $ip in $::ip_tcl_dirs"
}
set build_dir $sim_dir/build
set ip_build_dir $build_dir/ip
set build_managed_ip_dir $build_dir/managed_ip
set ip_src $root_dir/hw/reconic/plugs/rdma_onic_plugin
set p4_dir $root_dir/hw/reconic/packet_classification

file mkdir $ip_build_dir
file mkdir $build_managed_ip_dir
if {[file exist ${ip_build_dir}/${ip}]} {
  # delete the original IP folder
  file delete -force -- ${ip_build_dir}/${ip}
}

puts "INFO: Building required IPs"
create_project -force managed_ip_project $build_managed_ip_dir -part $part
set_property BOARD_PART $board_part [current_project]

set xci_file ${ip_build_dir}/$ip/$ip.xci
source_ip_tcl $ip

# Simulation only needs the generated HDL, no out-of-context synthesis
generate_target all [get_files  $xci_file]
puts "INFO: $ip is generated"

puts "INFO: ${ip} for simulation is generated"

