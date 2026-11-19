#==============================================================================
# Copyright (C) 2023, Advanced Micro Devices, Inc. All rights reserved.
# SPDX-License-Identifier: MIT
#
#==============================================================================
# Sourced by simulate.sh from the work directory ($build_dir/<simulator>),
# with root_dir, sim_dir, build_dir and sim_script_dir set; which defines xil_lib (precompiled IP library name
# for the installed Vivado). The static IP code comes from those libraries
# (export_simulation -use_ip_compiled_libs): only the IP wrappers generated
# under $build_dir/ip are compiled here.
VIVADO_DATA_DIR=$VIVADO_DIR/data
XVIP_PATH=$VIVADO_DATA_DIR/xilinx_vip
XVIP_INCLUDE=$XVIP_PATH/include

xvlog_opts="--relax --incr"
xvhdl_opts="--relax --incr"

PP=$build_dir/ip/packet_parser
xvlog $xvlog_opts -work reco -sv -L uvm -L $(xil_lib vitis_net_p4) -L $(xil_lib cam) \
-L $(xil_lib cam_blk_lib) -L $(xil_lib cdcam) \
-i $PP/hdl/include -i $PP/hdl/fpga_asic_macros_v1_0/hdl/include/fpga -i $PP/hdl/mcfh_v3_0/hdl/include \
-i $PP/hdl/cue_v2_0/hdl -i $PP/hdl/infrastructure_v6_4/ic_infrastructure/libs/axi \
-i $PP/hdl/axil_mil_v2_4/axil_mil/sv/axil_mil -i $PP/hdl/dbpl_v1_1/hdl -i $PP/hdl/atom_v1_1/hdl \
-i $PP/hdl -i $PP/src/hw/top/hdl -i $PP/src/hw/simulation -i $PP/src/verilog -i "$XVIP_INCLUDE" \
"$PP/src/verilog/packet_parser_top_pkg.sv" \
"$PP/src/verilog/packet_parser_counter_top.sv" \
"$PP/src/verilog/packet_parser_counter_extern.sv" \
"$PP/src/verilog/packet_parser_sync_fifos.sv" \
"$PP/src/verilog/packet_parser_extern_wrapper.sv" \
"$PP/src/verilog/packet_parser_header_sequence_identifier.sv" \
"$PP/src/verilog/packet_parser_header_field_extractor.sv" \
"$PP/src/verilog/packet_parser_error_check_module.sv" \
"$PP/src/verilog/packet_parser_parser_engine.sv" \
"$PP/src/verilog/packet_parser_deparser_engine.sv" \
"$PP/src/verilog/packet_parser_action_engine.sv" \
"$PP/src/verilog/packet_parser_lookup_engine.sv" \
"$PP/src/verilog/packet_parser_axi4lite_interconnect.sv" \
"$PP/src/verilog/packet_parser_statistics_registers.sv" \
"$PP/src/verilog/packet_parser_match_action_engine.sv" \
"$PP/src/verilog/packet_parser_top.sv" \
"$PP/src/verilog/packet_parser.sv"

xvhdl $xvhdl_opts -work reco -L $(xil_lib axi_bram_ctrl) \
"$build_dir/ip/axi_mm_bram/sim/axi_mm_bram.vhd" \
"$build_dir/ip/axi_sys_mm/sim/axi_sys_mm.vhd"

for xbar in reconic_axil_crossbar axil_3to1_crossbar dev_mem_axi_crossbar dev_mem_3to1_axi_crossbar \
            sys_mem_axi_crossbar sys_mem_5to2_axi_crossbar; do
  xvlog $xvlog_opts -work reco -L $(xil_lib axi_crossbar) -i $build_dir/ip/$xbar/hdl \
  "$build_dir/ip/$xbar/sim/$xbar.v"
done

xvlog $xvlog_opts -work reco -sv -L $(xil_lib smartconnect) -L $(xil_lib axi_protocol_checker) \
-i $build_dir/ip/axi_protocol_checker/hdl/verilog \
"$build_dir/ip/axi_protocol_checker/sim/axi_protocol_checker.sv"

xvlog $xvlog_opts -work reco -sv -L $(xil_lib ernic) -i $build_dir/ip/rdma_core/hdl/common \
"$build_dir/ip/rdma_core/sim/rdma_core.sv"

xvlog $xvlog_opts -work reco \
"$build_dir/ip/xlnx_clk_gen_cluster/xlnx_clk_gen_cluster_clk_wiz.v" \
"$build_dir/ip/xlnx_clk_gen_cluster/xlnx_clk_gen_cluster.v"

xvlog $xvlog_opts -work reco -sv \
"$root_dir/hw/open-nic-shell/src/utility/generic_reset.sv" \
"$root_dir/hw/open-nic-shell/src/rdma_subsystem/rdma_subsystem.sv" \
"$root_dir/hw/open-nic-shell/src/rdma_subsystem/rdma_subsystem_wrapper.sv"

# interface.f / kernel.f list paths relative to sim/scripts: rewritten for the work directory
for lst in interface kernel; do
  sed "s|^\.\./\.\./|$root_dir/|" $sim_script_dir/$lst.f > ./$lst.f
done
xvlog $xvlog_opts -d DEBUG -work reco -i $root_dir/hw/reconic/compute/lookside/interface -f ./interface.f
xvlog $xvlog_opts -d DEBUG -work reco -i $root_dir/hw/reconic/compute/lookside/kernel -f ./kernel.f

# Compute engine (hw/riscv-cores + hw/reconic/compute): same file list as the hardware
# build (hw/reconic/compute/gen_ce_filelist.py). CE_CORE (vex, mini or snitch), DPA_BOOTROM,
# CE_VEX_RTL and CE_MINI_RTL come from sim/Makefile (make ce builds the bootrom and the
# VexRiscv / riscv-mini rtl).
# XSIM selects the xsim workarounds in the PULP sources
CE_CORE=${CE_CORE:-vex}
CE_VEX_RTL=${CE_VEX_RTL:-$build_dir/compute_engine/vexriscv/VexRiscvU55.v}
CE_MINI_RTL=${CE_MINI_RTL:-$build_dir/compute_engine/riscv_mini/Tile.sv}
DPA_BOOTROM=${DPA_BOOTROM:-$build_dir/compute_engine/bootrom_$CE_CORE/bootrom.sv}
python3 -I $root_dir/hw/reconic/compute/gen_ce_filelist.py -tool xsim -core $CE_CORE -bootrom $DPA_BOOTROM \
  -mini-rtl $CE_MINI_RTL -vex-rtl $CE_VEX_RTL
CE_DEFINE=""
[ "$CE_CORE" = mini ] && CE_DEFINE="-d CE_MINI"
[ "$CE_CORE" = vex ] && CE_DEFINE="-d CE_VEX"
xvlog $xvlog_opts -sv -d XSIM -L xpm -work reco -f ./dpa_inc.f -f ./dpa.f

xvlog $xvlog_opts -sv -L xpm -L $(xil_lib ernic) -L $(xil_lib axi_bram_ctrl) -d DEBUG $CE_DEFINE -work reco -f ./dpa_inc.f \
"$root_dir/hw/reconic/utilities/rn_reg_control.sv" \
"$root_dir/hw/reconic/packet_classification/packet_classification.sv" \
"$root_dir/hw/reconic/packet_classification/packet_filter.sv" \
"$root_dir/hw/reconic/compute/lookside/compute_logic_wrapper.sv" \
"$root_dir/hw/reconic/compute/lookside/control_command_processor.sv" \
"$root_dir/hw/open-nic-shell/src/utility/axi_interconnect_to_dev_mem.sv" \
"$root_dir/hw/open-nic-shell/src/utility/axi_interconnect_to_sys_mem.sv" \
"$root_dir/hw/reconic/plugs/rdma_onic_plugin/reconic_address_map.sv" \
"$root_dir/hw/reconic/top/reconic.sv" \
"$root_dir/hw/reconic/plugs/rdma_onic_plugin/box_250mhz.sv" \
"$root_dir/hw/reconic/plugs/rdma_onic_plugin/rdma_onic_plugin.sv"

xvlog $xvlog_opts -sv -d DEBUG -L $(xil_lib axi_bram_ctrl) -L xpm -work reco \
"$sim_dir/src/axi_read_verify.sv" \
"$sim_dir/src/axil_reg_stimulus.sv" \
"$sim_dir/src/axil_reg_control.sv" \
"$sim_dir/src/axil_3to1_crossbar_wrapper.sv" \
"$sim_dir/src/init_mem.sv" \
"$sim_dir/src/rdma_rn_wrapper.sv" \
"$sim_dir/src/rn_tb_pkg.sv" \
"$sim_dir/src/rn_tb_generator.sv" \
"$sim_dir/src/rn_tb_driver.sv" \
"$sim_dir/src/rn_tb_checker.sv" \
"$sim_dir/src/rn_tb_top.sv" \
"$sim_dir/src/cl_tb_top.sv" \
"$sim_dir/src/rn_tb_2rdma_top.sv" \
"$sim_dir/src/axi_3to1_interconnect_to_dev_mem.sv" \
"$sim_dir/src/axi_5to2_interconnect_to_sys_mem.sv"

xvlog $xvlog_opts -work reco \
"$VIVADO_DATA_DIR/verilog/src/glbl.v"
