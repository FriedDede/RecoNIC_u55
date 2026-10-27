#==============================================================================
# Copyright (C) 2023, Advanced Micro Devices, Inc. All rights reserved.
# SPDX-License-Identifier: MIT
#
#==============================================================================
# Sourced by simulate.sh, which defines xil_lib (precompiled IP library name
# for the installed Vivado). The static IP code comes from those libraries
# (export_simulation -use_ip_compiled_libs): only the IP wrappers generated
# under ../build/ip are compiled here.
VIVADO_DATA_DIR=$VIVADO_DIR/data
XVIP_PATH=$VIVADO_DATA_DIR/xilinx_vip
XVIP_INCLUDE=$XVIP_PATH/include

xvlog_opts="--relax --incr"
xvhdl_opts="--relax --incr"

PP=../build/ip/packet_parser
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
"../build/ip/axi_mm_bram/sim/axi_mm_bram.vhd" \
"../build/ip/axi_sys_mm/sim/axi_sys_mm.vhd"

for xbar in reconic_axil_crossbar axil_3to1_crossbar dev_mem_axi_crossbar dev_mem_3to1_axi_crossbar \
            sys_mem_axi_crossbar sys_mem_5to2_axi_crossbar; do
  xvlog $xvlog_opts -work reco -L $(xil_lib axi_crossbar) -i ../build/ip/$xbar/hdl \
  "../build/ip/$xbar/sim/$xbar.v"
done

xvlog $xvlog_opts -work reco -sv -L $(xil_lib smartconnect) -L $(xil_lib axi_protocol_checker) \
-i ../build/ip/axi_protocol_checker/hdl/verilog \
"../build/ip/axi_protocol_checker/sim/axi_protocol_checker.sv"

xvlog $xvlog_opts -work reco -sv -L $(xil_lib ernic) -i ../build/ip/rdma_core/hdl/common \
"../build/ip/rdma_core/sim/rdma_core.sv"

xvlog $xvlog_opts -work reco \
"../build/ip/xlnx_clk_gen/xlnx_clk_gen_clk_wiz.v" \
"../build/ip/xlnx_clk_gen/xlnx_clk_gen.v"

xvlog $xvlog_opts -work reco -sv \
"../../hw/open-nic-shell/src/utility/generic_reset.sv" \
"../../hw/open-nic-shell/src/rdma_subsystem/rdma_subsystem.sv" \
"../../hw/open-nic-shell/src/rdma_subsystem/rdma_subsystem_wrapper.sv"

xvlog $xvlog_opts -d DEBUG -work reco -i ../../hw/reconic/compute/lookside/interface -f ./interface.f
xvlog $xvlog_opts -d DEBUG -work reco -i ../../hw/reconic/compute/lookside/kernel -f ./kernel.f

# Compute engine (hw/reconic/compute/dpa): same file set as the hardware build.
# XSIM selects the xsim workarounds in the PULP sources
python3 ./gen_dpa_filelist.py -tool xsim ${DPA_BOOTROM:+-bootrom $DPA_BOOTROM}
xvlog $xvlog_opts -sv -d XSIM -L xpm -work reco -f ./dpa_inc.f -f ./dpa.f

xvlog $xvlog_opts -sv -L xpm -L $(xil_lib ernic) -L $(xil_lib axi_bram_ctrl) -d DEBUG -work reco -f ./dpa_inc.f \
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

xvlog $xvlog_opts -sv -d DEBUG -L $(xil_lib axi_bram_ctrl) -L xpm -work reco \
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

xvlog $xvlog_opts -work reco \
"$VIVADO_DATA_DIR/verilog/src/glbl.v"
