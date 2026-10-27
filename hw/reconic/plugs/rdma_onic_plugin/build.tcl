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
# Compute engine (compute/dpa): all RTL except testbenches, simulation
# models, duplicates and unused files that include missing headers
# ------------------------------------------------------------------
set dpa_dir ${shell_dir}/compute/dpa
set dpa_skip_dirs {
    fpu_div_sqrt
    common_cells/src/deprecated
}
set dpa_skip_files {
    bootrom_u55/bootrom.sv
    dpa.sv
    dpa_tb.sv
    axi_pulp/axi_test.sv
    axi_pulp/axi_sim_mem.sv
    cache_subsystem/cache_sim.sv
    cache_subsystem/tb_cache_filter.sv
    cache_subsystem/tb_page_mover.sv
    common_cells/instr_tracer.sv
    scm/register_file_2r_1w_asymm_test_wrap.sv
    snitch/snitch_l0_tlb_tb.sv
    snitch_cluster/snitch_cluster.sv
    xdma_boot/tb_axi_boot_check.sv
}

proc dpa_collect {dir rel skip_dirs skip_files hdl_var inc_var} {
    upvar $hdl_var hdl
    upvar $inc_var inc
    if {[llength [glob -nocomplain -directory $dir -types f *.svh *.vh]]} {
        lappend inc $dir
    }
    foreach f [glob -nocomplain -directory $dir -types f *.sv *.v] {
        set r [string trimleft "$rel/[file tail $f]" /]
        if {[lsearch -exact $skip_files $r] < 0} {
            lappend hdl $f
        }
    }
    foreach d [glob -nocomplain -directory $dir -types d *] {
        set r [string trimleft "$rel/[file tail $d]" /]
        if {[lsearch -exact $skip_dirs $r] < 0} {
            dpa_collect $d $r $skip_dirs $skip_files hdl inc
        }
    }
}

set dpa_hdl {}
set dpa_inc {}
dpa_collect $dpa_dir "" $dpa_skip_dirs $dpa_skip_files dpa_hdl dpa_inc
add_files -norecurse $dpa_hdl

# Compute engine bootrom: -bootrom build option, or the one shipped with dpa
if {[info exists bootrom] && ![string equal $bootrom ""]} {
    set dpa_bootrom $bootrom
} else {
    set dpa_bootrom ${dpa_dir}/bootrom_u55/bootrom.sv
}
if {![file exists $dpa_bootrom]} {
    error "ERROR: \[dpa\] bootrom not found: $dpa_bootrom"
}
add_files -norecurse $dpa_bootrom
puts "INFO: \[dpa\] bootrom: $dpa_bootrom"
set_property include_dirs [concat [get_property include_dirs [current_fileset]] $dpa_inc] [current_fileset]
puts "INFO: \[dpa\] added [llength $dpa_hdl] RTL files, [llength $dpa_inc] include dirs"
