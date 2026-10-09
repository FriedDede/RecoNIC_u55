# This is a generated file. Do not modify by hand
# cmd: ../scripts/build_tcl.py -nic rdma-opennic

add_files ./box_250mhz.sv
add_files ./rdma_onic_plugin.sv
add_files ./reconic_address_map.sv
add_files ./reconic/packet_classification/packet_filter.sv
add_files ./reconic/packet_classification/packet_classification.sv
add_files ./reconic/top/reconic.sv
add_files ./reconic/lookside/cl_box.v
add_files ./reconic/lookside/mmult_systolic_m_axi.v
add_files ./reconic/lookside/cl_box_cl_box_Pipeline_1.v
add_files ./reconic/lookside/control_command_processor.sv
add_files ./reconic/lookside/mmult_mmult_Pipeline_4.v
add_files ./reconic/lookside/cl_box_cl_box_Pipeline_VITIS_LOOP_22_1.v
add_files ./reconic/lookside/mmult_mul_32s_32s_32_2_1.v
add_files ./reconic/lookside/mmult_flow_control_loop_pipe_sequential_init.v
add_files ./reconic/lookside/cl_box_cmd_array_RAM_AUTO_1R1W.v
add_files ./reconic/lookside/mmult_mmult_Pipeline_1.v
add_files ./reconic/lookside/mmult_localA_RAM_AUTO_1R1W.v
add_files ./reconic/lookside/mmult_mmult_Pipeline_2.v
add_files ./reconic/lookside/mmult_mmult_Pipeline_systolic1.v
add_files ./reconic/lookside/cl_box_flow_control_loop_pipe_sequential_init.v
add_files ./reconic/lookside/mmult_sparsemux_33_4_32_1_1.v
add_files ./reconic/lookside/compute_logic_wrapper.sv
add_files ./reconic/lookside/mmult.v
add_files ./reconic/utilities/rn_reg_control.sv


# ------------------------------------------------------------------
# Compute engine (reconic/dpa): all RTL except testbenches, simulation
# models, duplicates and unused files that include missing headers
# ------------------------------------------------------------------
set dpa_dir [file normalize ./reconic/dpa]
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
