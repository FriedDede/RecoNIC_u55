#==============================================================================
# Copyright (C) 2023, Advanced Micro Devices, Inc. All rights reserved.
# SPDX-License-Identifier: MIT
#
#==============================================================================
# Sourced by simulate.sh, which defines xil_lib (precompiled IP library name
# in COMPILED_LIB_DIR) and copies COMPILED_LIB_DIR/modelsim.ini here. The
# Xilinx and static IP code comes from those libraries (compile_simlib): only
# the IP wrappers generated under ../build/ip are compiled here.
VIVADO_DATA_DIR=$VIVADO_DIR/data
XVIP_INCLUDE=$VIVADO_DATA_DIR/xilinx_vip/include
USER_LIB=${build_dir}/questa_lib

vlib $USER_LIB/reco
vmap reco $USER_LIB/reco

PP=../build/ip/packet_parser
vlog -64 -work reco -sv -L $UVM_LIB -L $(xil_lib vitis_net_p4) -L $(xil_lib cam) \
-L $(xil_lib cam_blk_lib) -L $(xil_lib cdcam) \
"+incdir+$PP/hdl/include" "+incdir+$PP/hdl/fpga_asic_macros_v1_0/hdl/include/fpga" "+incdir+$PP/hdl/mcfh_v3_0/hdl/include" \
"+incdir+$PP/hdl/cue_v2_0/hdl" "+incdir+$PP/hdl/infrastructure_v6_4/ic_infrastructure/libs/axi" \
"+incdir+$PP/hdl/axil_mil_v2_4/axil_mil/sv/axil_mil" "+incdir+$PP/hdl/dbpl_v1_1/hdl" "+incdir+$PP/hdl/atom_v1_1/hdl" \
"+incdir+$PP/hdl" "+incdir+$PP/src/hw/top/hdl" "+incdir+$PP/src/hw/simulation" "+incdir+$PP/src/verilog" "+incdir+$XVIP_INCLUDE" \
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

vcom -64 -93 -work reco \
"../build/ip/axi_mm_bram/sim/axi_mm_bram.vhd" \
"../build/ip/axi_sys_mm/sim/axi_sys_mm.vhd"

for xbar in reconic_axil_crossbar axil_3to1_crossbar dev_mem_axi_crossbar dev_mem_3to1_axi_crossbar \
            sys_mem_axi_crossbar sys_mem_5to2_axi_crossbar; do
  vlog -64 -work reco "+incdir+../build/ip/$xbar/hdl" \
  "../build/ip/$xbar/sim/$xbar.v"
done

vlog -64 -work reco -sv -L $(xil_lib smartconnect) -L $(xil_lib axi_protocol_checker) \
"+incdir+../build/ip/axi_protocol_checker/hdl/verilog" \
"../build/ip/axi_protocol_checker/sim/axi_protocol_checker.sv"

vlog -64 -work reco -sv -L $(xil_lib ernic) "+incdir+../build/ip/rdma_core/hdl/common" \
"../build/ip/rdma_core/sim/rdma_core.sv"

vlog -64 -work reco \
"../build/ip/xlnx_clk_gen/xlnx_clk_gen_clk_wiz.v" \
"../build/ip/xlnx_clk_gen/xlnx_clk_gen.v"

vlog -64 -work reco -sv \
"../../hw/open-nic-shell/src/utility/generic_reset.sv" \
"../../hw/open-nic-shell/src/rdma_subsystem/rdma_subsystem.sv" \
"../../hw/open-nic-shell/src/rdma_subsystem/rdma_subsystem_wrapper.sv"

vlog -64 +define+DEBUG -work reco +incdir+../../hw/reconic/compute/lookside/interface -f ./interface.f
vlog -64 +define+DEBUG -work reco +incdir+../../hw/reconic/compute/lookside/kernel -f ./kernel.f

# Compute engine (hw/reconic/compute/dpa): same file set as the hardware build.
# QUESTA selects the Questa workarounds in the PULP sources
python3 ./gen_dpa_filelist.py -tool questasim ${DPA_BOOTROM:+-bootrom $DPA_BOOTROM}
vlog -64 -sv +define+QUESTA -L xpm -work reco -f ./dpa_inc.f -f ./dpa.f

vlog -64 -sv -L xpm -L $(xil_lib ernic) +define+DEBUG -work reco -f ./dpa_inc.f \
"../../hw/reconic/utilities/rn_reg_control.sv" \
"../../hw/reconic/packet_classification/packet_classification.sv" \
"../../hw/reconic/packet_classification/packet_filter.sv" \
"../../hw/reconic/compute/lookside/compute_logic_wrapper.sv" \
"../../hw/reconic/compute/lookside/control_command_processor.sv" \
"../../hw/open-nic-shell/src/utility/axi_interconnect_to_dev_mem.sv" \
"../../hw/open-nic-shell/src/utility/axi_interconnect_to_sys_mem.sv" \
"../../hw/reconic/plugs/rdma_onic_plugin/reconic_address_map.sv" \
"../../hw/reconic/top/reconic.sv" \
"../../hw/reconic/plugs/rdma_onic_plugin/box_250mhz.sv" \
"../../hw/reconic/plugs/rdma_onic_plugin/rdma_onic_plugin.sv"

vlog -64 -sv +define+DEBUG -L xpm -work reco \
"../src/axi_read_verify.sv" \
"../src/axil_reg_stimulus.sv" \
"../src/axil_reg_control.sv" \
"../src/axil_3to1_crossbar_wrapper.sv" \
"../src/init_mem.sv" \
"../src/rdma_rn_wrapper.sv" \
"../src/rn_tb_pkg.sv" \
"../src/rn_tb_generator.sv" \
"../src/rn_tb_driver.sv" \
"../src/rn_tb_checker.sv" \
"../src/rn_tb_top.sv" \
"../src/cl_tb_top.sv" \
"../src/rn_tb_2rdma_top.sv" \
"../src/axi_3to1_interconnect_to_dev_mem.sv" \
"../src/axi_5to2_interconnect_to_sys_mem.sv"

vlog -64 -work reco \
"$VIVADO_DATA_DIR/verilog/src/glbl.v"
