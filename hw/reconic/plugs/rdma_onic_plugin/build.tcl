# box_250mhz module of open-nic-shell: sourced by
# hw/open-nic-shell/script/build.tcl with this directory as cwd.
# The RTL files at this directory's top level are read by that script.

set shell_dir [file normalize ../..]

add_files ${shell_dir}/packet_classification/packet_filter.sv
add_files ${shell_dir}/packet_classification/packet_classification.sv
add_files ${shell_dir}/top/reconic.sv
add_files ${shell_dir}/utilities/rn_reg_control.sv
add_files ${shell_dir}/compute/lookside/control_command_processor.sv
add_files ${shell_dir}/compute/lookside/compute_logic_wrapper.sv
add_files -norecurse [glob ${shell_dir}/compute/lookside/interface/*.v]
add_files -norecurse [glob ${shell_dir}/compute/lookside/kernel/*.v]


# ------------------------------------------------------------------
# Compute engine: RTL from the riscv-cores submodule (hw/riscv-cores) and
# compute/{dpa,cache_subsystem}, listed in dependency order by
# compute/gen_ce_filelist.py (also used by the simulation)
#   -ce_core      mini (compute_engine_mini, default) or snitch (compute_engine)
#   -bootrom      bootrom.sv of the compute engine (module bootrom)
#   -ce_mini_rtl  riscv-mini Tile.sv, generated from chisel (-ce_core mini)
# scripts/Makefile builds the bootrom and the riscv-mini Tile.
# ------------------------------------------------------------------
if {![info exists ce_core] || [string equal $ce_core ""]} {
    set ce_core mini
}
if {![info exists bootrom] || [string equal $bootrom ""]} {
    error "ERROR: \[ce\] no bootrom: pass -bootrom <bootrom.sv> (scripts/Makefile builds one)"
}
set ce_gen_args [list -tool vivado -core $ce_core -bootrom $bootrom -o ${top_build_dir}/ce_filelist]
if {[string equal $ce_core mini]} {
    if {![info exists ce_mini_rtl] || [string equal $ce_mini_rtl ""]} {
        error "ERROR: \[ce\] -ce_core mini needs -ce_mini_rtl <Tile.sv> (scripts/Makefile builds it)"
    }
    lappend ce_gen_args -mini-rtl [file normalize $ce_mini_rtl]
}
if {[catch {exec python3 -I ${shell_dir}/compute/gen_ce_filelist.py {*}$ce_gen_args 2>@1} ce_gen_log]} {
    error "ERROR: \[ce\] gen_ce_filelist.py failed:\n$ce_gen_log"
}
puts $ce_gen_log

proc ce_read_list {f} {
    set fp [open $f r]
    set l [split [string trim [read $fp]] "\n"]
    close $fp
    return $l
}
set ce_hdl [ce_read_list ${top_build_dir}/ce_filelist/dpa.f]
set ce_inc [ce_read_list ${top_build_dir}/ce_filelist/dpa_inc.f]
add_files -norecurse $ce_hdl
set_property include_dirs [concat [get_property include_dirs [current_fileset]] $ce_inc] [current_fileset]
# compute_logic_wrapper.sv instantiates compute_engine_mini under CE_MINI
if {[string equal $ce_core mini]} {
    set_property verilog_define [concat [get_property verilog_define [current_fileset]] CE_MINI] [current_fileset]
}
puts "INFO: \[ce\] $ce_core compute engine: [llength $ce_hdl] RTL files, [llength $ce_inc] include dirs, bootrom: $bootrom"
