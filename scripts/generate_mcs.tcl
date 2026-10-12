#==============================================================================
# Copyright (C) 2026, Politecnico di Milano. All rights reserved.
# SPDX-License-Identifier: MIT
#
#==============================================================================
#
#  Usage:
#    vivado -mode batch -source generate_mcs.tcl -tclargs -bitstream /path/to/file.bit
#           [-mcs_file /path/to/file.mcs]
#
#  If -mcs_file is omitted, the MCS is written next to the bitstream with the
#  same basename and a .mcs extension.
#
#==============================================================================

array set mcs_options {
    -bitstream ""
    -mcs_file  ""
}

# Expect arguments in the form of `-argument value`
for {set i 0} {$i < $argc} {incr i 2} {
    set arg [lindex $argv $i]
    set val [lindex $argv [expr $i+1]]
    if {[info exists mcs_options($arg)]} {
        set mcs_options($arg) $val
        puts "Set option $arg to $val"
    } else {
        puts "Skip unknown argument $arg and its value $val"
    }
}

foreach {key value} [array get mcs_options] {
    set [string range $key 1 end] $value
}

if {[string equal $bitstream ""]} {
    puts "Error: Please provide a bitstream with -bitstream"
    exit 1
}
if {![file exists $bitstream]} {
    puts "Error: Bitstream $bitstream not found"
    exit 1
}
set bitstream [file normalize $bitstream]

if {[string equal $mcs_file ""]} {
    set mcs_file [file rootname $bitstream].mcs
}

set interface SPIx4
set start_address 0x01002000

puts "Generating mcs file"
puts "Bitstream: $bitstream"
puts "MCS file : $mcs_file"

write_cfgmem -force -format mcs -size 128 -interface $interface \
    -loadbit "up $start_address $bitstream" -file $mcs_file
