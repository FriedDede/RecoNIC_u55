//==============================================================================
// Copyright (C) 2023, Advanced Micro Devices, Inc. All rights reserved.
// SPDX-License-Identifier: MIT
//
//==============================================================================
`timescale 1ns/1ps
`include "axi_assign.svh"
`include "axi_typedef.svh"
`include "hbm_axi.svh"

module compute_logic_wrapper
  import axi_pkg::*;
  import dpa_pkg::*; 
# (
  parameter AXIL_ADDR_WIDTH  = 12,
  parameter AXIL_DATA_WIDTH  = 32,
  parameter AXIS_DATA_WIDTH  = 512,
  parameter AXIS_KEEP_WIDTH  = 64,
  // 1: CE reaches DRAM through the cache, 0: cache bypassed
  parameter bit ENABLE_CACHE = 1'b1
) (
  // register control interface
  input         s_axil_awvalid,
  input  [31:0] s_axil_awaddr,
  output        s_axil_awready,
  input         s_axil_wvalid,
  input  [31:0] s_axil_wdata,
  output        s_axil_wready,
  output        s_axil_bvalid,
  output  [1:0] s_axil_bresp,
  input         s_axil_bready,
  input         s_axil_arvalid,
  input  [31:0] s_axil_araddr,
  output        s_axil_arready,
  output        s_axil_rvalid,
  output [31:0] s_axil_rdata,
  output  [1:0] s_axil_rresp,
  input         s_axil_rready,
  
  // master AXI interface for device memory access
  output    [4 : 0] m_axi_dram_awid,
  output   [63 : 0] m_axi_dram_awaddr,
  output    [3 : 0] m_axi_dram_awqos,
  output    [7 : 0] m_axi_dram_awlen,
  output    [2 : 0] m_axi_dram_awsize,
  output    [1 : 0] m_axi_dram_awburst,
  output    [3 : 0] m_axi_dram_awcache,
  output    [2 : 0] m_axi_dram_awprot,
  output            m_axi_dram_awvalid,
  input             m_axi_dram_awready,
  output  [511 : 0] m_axi_dram_wdata,
  output   [63 : 0] m_axi_dram_wstrb,
  output            m_axi_dram_wlast,
  output            m_axi_dram_wvalid,
  input             m_axi_dram_wready,
  output            m_axi_dram_awlock,
  input     [4 : 0] m_axi_dram_bid,
  input     [1 : 0] m_axi_dram_bresp,
  input             m_axi_dram_bvalid,
  output            m_axi_dram_bready,
  output    [4 : 0] m_axi_dram_arid,
  output   [63 : 0] m_axi_dram_araddr,
  output    [7 : 0] m_axi_dram_arlen,
  output    [2 : 0] m_axi_dram_arsize,
  output    [1 : 0] m_axi_dram_arburst,
  output    [3 : 0] m_axi_dram_arcache,
  output    [2 : 0] m_axi_dram_arprot,
  output            m_axi_dram_arvalid,
  input             m_axi_dram_arready,
  input     [4 : 0] m_axi_dram_rid,
  input   [511 : 0] m_axi_dram_rdata,
  input     [1 : 0] m_axi_dram_rresp,
  input             m_axi_dram_rlast,
  input             m_axi_dram_rvalid,
  output            m_axi_dram_rready,
  output            m_axi_dram_arlock,
  output     [3:0]  m_axi_dram_arqos,
  output    [3 : 0] m_axi_dram_awregion,
  output    [3 : 0] m_axi_dram_arregion,
  output [cache_ss_pkg::UserWidth-1 : 0] m_axi_dram_awuser,
  output [cache_ss_pkg::UserWidth-1 : 0] m_axi_dram_wuser,
  output [cache_ss_pkg::UserWidth-1 : 0] m_axi_dram_aruser,
  input  [cache_ss_pkg::UserWidth-1 : 0] m_axi_dram_buser,
  input  [cache_ss_pkg::UserWidth-1 : 0] m_axi_dram_ruser,

  input          axil_aclk,
  input          axil_rstn,
  input          axis_aclk,
  input          axis_rstn
);

// -----------------------------------------------------------------------------------------------------------------------------------------
// AXIL CTRL FROM HOST
// Register control: s_axil reads/writes the descriptor memory directly
// (axil_aclk domain); the descriptor memory is shared by the host and all CEs
// -----------------------------------------------------------------------------------------------------------------------------------------

AXI_BUS #(
    .AXI_ADDR_WIDTH ( dpa_pkg::ce_AddrWidth     ),
    .AXI_DATA_WIDTH ( dpa_pkg::ce_DataWidth     ),
    .AXI_ID_WIDTH   ( dpa_pkg::IdWidth          ),
    .AXI_USER_WIDTH ( dpa_pkg::ce_UserWidth     )
) axi_ctrl_to_desc ();

AXI_LITE #(
  .AXI_ADDR_WIDTH ( dpa_pkg::ce_AddrWidth ),
  .AXI_DATA_WIDTH ( AXIL_DATA_WIDTH       )
) axil_ctrl ();

AXI_BUS #(
  .AXI_ADDR_WIDTH ( dpa_pkg::ce_AddrWidth ),
  .AXI_DATA_WIDTH ( AXIL_DATA_WIDTH       ),
  .AXI_ID_WIDTH   ( dpa_pkg::IdWidth      ),
  .AXI_USER_WIDTH ( dpa_pkg::ce_UserWidth )
) axi_ctrl_narrow ();

assign axil_ctrl.aw_addr  = s_axil_awaddr;
assign axil_ctrl.aw_prot  = '0;
assign axil_ctrl.aw_valid = s_axil_awvalid;
assign s_axil_awready     = axil_ctrl.aw_ready;

assign axil_ctrl.w_data   = s_axil_wdata;
assign axil_ctrl.w_strb   = '1; // s_axil carries no wstrb: full-word writes
assign axil_ctrl.w_valid  = s_axil_wvalid;
assign s_axil_wready      = axil_ctrl.w_ready;

assign s_axil_bresp       = axil_ctrl.b_resp;
assign s_axil_bvalid      = axil_ctrl.b_valid;
assign axil_ctrl.b_ready  = s_axil_bready;

assign axil_ctrl.ar_addr  = s_axil_araddr;
assign axil_ctrl.ar_prot  = '0;
assign axil_ctrl.ar_valid = s_axil_arvalid;
assign s_axil_arready     = axil_ctrl.ar_ready;

assign s_axil_rdata       = axil_ctrl.r_data;
assign s_axil_rresp       = axil_ctrl.r_resp;
assign s_axil_rvalid      = axil_ctrl.r_valid;
assign axil_ctrl.r_ready  = s_axil_rready;

// AXI-Lite -> AXI4 (single-beat, ID 0)
axi_lite_to_axi_intf #(
  .AXI_DATA_WIDTH ( AXIL_DATA_WIDTH )
) i_ctrl_lite_to_axi (
  .in             ( axil_ctrl       ),
  .slv_aw_cache_i ( '0              ),
  .slv_ar_cache_i ( '0              ),
  .out            ( axi_ctrl_narrow )
);

// 32 -> 64 bit to match the descriptor memory data width
axi_dw_converter_intf #(
  .AXI_ID_WIDTH            ( dpa_pkg::IdWidth      ),
  .AXI_ADDR_WIDTH          ( dpa_pkg::ce_AddrWidth ),
  .AXI_SLV_PORT_DATA_WIDTH ( AXIL_DATA_WIDTH       ),
  .AXI_MST_PORT_DATA_WIDTH ( dpa_pkg::ce_DataWidth ),
  .AXI_USER_WIDTH          ( dpa_pkg::ce_UserWidth )
) i_ctrl_dw_upsize (
  .clk_i  ( axil_aclk           ),
  .rst_ni ( axil_rstn           ),
  .slv    ( axi_ctrl_narrow     ),
  .mst    ( axi_ctrl_to_desc    )
);

// -----------------------------------------------------------------------------------------------------------------------------------------
// CLOCK AND RESET SIGNALS
// -----------------------------------------------------------------------------------------------------------------------------------------
                          
logic internal_axis_rstn;
assign internal_axis_rstn = axis_rstn;

// descriptor memory clock domain
logic desc_mem_clk;
logic desc_mem_reset_n;
assign desc_mem_clk     = axis_aclk;
assign desc_mem_reset_n = internal_axis_rstn;

// cache memory clock domain
logic cache_arstn;
logic cache_aclk;
logic cache_pu_rstn [dpa_pkg::DRAM_CH_NUMBER];
assign cache_aclk = axis_aclk;

// -----------------------------------------------------------------------------------------------------------------------------------------
// MEMORY CHANNELS TO DRAM
// -----------------------------------------------------------------------------------------------------------------------------------------

AXI_BUS #(
  .AXI_ADDR_WIDTH (cache_ss_pkg::AddrWidth),
  .AXI_DATA_WIDTH (cache_ss_pkg::DataWidth),
  .AXI_ID_WIDTH   (cache_ss_pkg::IdWidth),
  .AXI_USER_WIDTH (cache_ss_pkg::UserWidth)
) axim_dpa_to_dram[dpa_pkg::DRAM_CH_NUMBER-1:0]();

// The CE sees device memory in its 2 GB window 0x8000_0000-0xFFFF_FFFF
// (compute_engine.sv address map). Keep only the offset in that window, so
// CE 0x8000_0000 + X reaches device memory (HBM) address X.
localparam int unsigned CE_DRAM_OFFSET_WIDTH = 31;

AXI_BUS #(
  .AXI_ADDR_WIDTH (64),
  .AXI_DATA_WIDTH (cache_ss_pkg::DataWidth),
  .AXI_ID_WIDTH   (cache_ss_pkg::IdWidth),
  .AXI_USER_WIDTH (cache_ss_pkg::UserWidth)
) axim_dram_remap ();

axi_modify_address_intf #(
  .AXI_SLV_PORT_ADDR_WIDTH ( cache_ss_pkg::AddrWidth  ),
  .AXI_MST_PORT_ADDR_WIDTH ( 64                       ),
  .AXI_DATA_WIDTH          ( cache_ss_pkg::DataWidth  ),
  .AXI_ID_WIDTH            ( cache_ss_pkg::IdWidth    ),
  .AXI_USER_WIDTH          ( cache_ss_pkg::UserWidth  )
) i_dram_remap (
  .slv           ( axim_dpa_to_dram[0] ),
  // 16GB HBM ADDRESSING: 34bit
  // 63 : 34  - unused
  // 33       - HBM STACK
  // 32 : 31  - Which 2GB block (4 blocks in a 8GB stack)
  // 30 : 0   - 2GB address space for each compute engine
  .mst_aw_addr_i ( {30'b0, 1'b0, 2'b0, (axim_dpa_to_dram[0].aw_addr[CE_DRAM_OFFSET_WIDTH-1:0])} ),
  .mst_ar_addr_i ( {30'b0, 1'b0, 2'b0, (axim_dpa_to_dram[0].ar_addr[CE_DRAM_OFFSET_WIDTH-1:0])} ),
  .mst           ( axim_dram_remap     )
);

`AXI_ASSIGN_MASTER(m_axi_dram,axim_dram_remap)

// -----------------------------------------------------------------------------------------------------------------------------------------
// Compute engine 
// -----------------------------------------------------------------------------------------------------------------------------------------

// ce to descriptor ring
  dpa_pkg::axim64_core2mem_req_t [dpa_pkg::DRAM_CH_NUMBER-1 : 0] m_axim_ce2desc_req;
  dpa_pkg::axim64_core2mem_resp_t [dpa_pkg::DRAM_CH_NUMBER-1 : 0] m_axim_ce2desc_resp;
  // ce to cache
  dpa_pkg::axim64_core2mem_req_t [dpa_pkg::DRAM_CH_NUMBER-1 : 0] m_axim_ce2cache_req;
  dpa_pkg::axim64_core2mem_resp_t [dpa_pkg::DRAM_CH_NUMBER-1 : 0] m_axim_ce2cache_resp;

// Compute engine parameters are in dpa_pkg.sv
compute_engine compute_engine_instance (

  .ref_clk(axis_aclk),
  .ref_areset_n(internal_axis_rstn),

  .m_axim_dram_req(m_axim_ce2cache_req),
  .m_axim_dram_resp(m_axim_ce2cache_resp),
  .dram_axim_clk(cache_aclk),
  .dram_axim_reset_n(cache_pu_rstn),

  .m_axim_desc_req(m_axim_ce2desc_req),
  .m_axim_desc_resp(m_axim_ce2desc_resp),
  .desc_axim_clk(desc_mem_clk),
  .desc_axim_reset_n(desc_mem_reset_n)
);

// -----------------------------------------------------------------------------------------------------------------------------------------
//  DESCRIPTOR/COMPLETION RING Memory
// -----------------------------------------------------------------------------------------------------------------------------------------

// One 4 KB descriptor memory shared by the host (register control) and every
// CE. desc_mux prepends its slave-port index to the ID, so its master port is
// dpa_pkg::desc_bram_id_width wide. desc_mem is built with that same ID
// width: dropping the port-select bits misroutes B/R responses between the
// masters.

localparam int unsigned DESC_MEM_ADDR_WIDTH = 12;                       // 4 KB
localparam int unsigned DESC_MUX_SLV_PORTS  = dpa_pkg::DRAM_CH_NUMBER + 1; // CEs + host
localparam int unsigned DESC_MUX_HOST_PORT  = dpa_pkg::DRAM_CH_NUMBER;

// desc_mux slave ports: [DRAM_CH_NUMBER-1:0] CEs, [DESC_MUX_HOST_PORT] host
AXI_BUS #(
    .AXI_ADDR_WIDTH ( dpa_pkg::ce_AddrWidth       ),
    .AXI_DATA_WIDTH ( dpa_pkg::ce_DataWidth       ),
    .AXI_ID_WIDTH   ( dpa_pkg::ce_IdWidthToUncore ),
    .AXI_USER_WIDTH ( dpa_pkg::ce_UserWidth       )
) axi_cdc2mux_desc [DESC_MUX_SLV_PORTS-1:0] ();

// axim channels: riscv_desc_output -> desc_mem, one per CE
for (genvar i = 0; i < dpa_pkg::DRAM_CH_NUMBER; i++) begin : desc_assign

  `AXI_ASSIGN_FROM_REQ (axi_cdc2mux_desc[i], m_axim_ce2desc_req[i])
  `AXI_ASSIGN_TO_RESP  (m_axim_ce2desc_resp[i], axi_cdc2mux_desc[i])

end : desc_assign

// clock domain conversion: axil_aclk (register control) -> desc_mem

AXI_BUS #(
  .AXI_ADDR_WIDTH (dpa_pkg::ce_AddrWidth),
  .AXI_DATA_WIDTH (dpa_pkg::ce_DataWidth),
  .AXI_ID_WIDTH   (dpa_pkg::IdWidth),
  .AXI_USER_WIDTH (dpa_pkg::ce_UserWidth)
) axi_ctrl_cdc2mem ();

axi_cdc_intf #(
  .AXI_ID_WIDTH   (dpa_pkg::IdWidth),
  .AXI_ADDR_WIDTH (dpa_pkg::ce_AddrWidth),
  .AXI_DATA_WIDTH (dpa_pkg::ce_DataWidth),
  .AXI_USER_WIDTH (dpa_pkg::ce_UserWidth),
  .LOG_DEPTH(3),
  .SYNC_STAGES(2)
) axi_cdc_ctrl_desc (
    .src_clk_i  (axil_aclk),
    .src_rst_ni (axil_rstn),
    .src        (axi_ctrl_to_desc),

    .dst_clk_i  (desc_mem_clk),
    .dst_rst_ni (desc_mem_reset_n),
    .dst        (axi_ctrl_cdc2mem)
);

// host ID (dpa_pkg::IdWidth) zero-extended to the CE ID width on the way in,
// truncated back on B/R: the mux returns the ID it was given, so nothing is lost
`AXI_ASSIGN(axi_cdc2mux_desc[DESC_MUX_HOST_PORT], axi_ctrl_cdc2mem)

// host + CEs -> descriptor memory access mux

AXI_BUS #(
    .AXI_ADDR_WIDTH ( dpa_pkg::ce_AddrWidth       ),
    .AXI_DATA_WIDTH ( dpa_pkg::ce_DataWidth       ),
    .AXI_ID_WIDTH   ( dpa_pkg::desc_bram_id_width ),
    .AXI_USER_WIDTH ( dpa_pkg::ce_UserWidth       )
) axi_cdc2desc_mem();

axi_mux_intf #(
    .SLV_AXI_ID_WIDTH (dpa_pkg::ce_IdWidthToUncore),
    .MST_AXI_ID_WIDTH (dpa_pkg::desc_bram_id_width),
    .AXI_ADDR_WIDTH   (dpa_pkg::ce_AddrWidth       ),
    .AXI_DATA_WIDTH   (dpa_pkg::ce_DataWidth       ),
    .AXI_USER_WIDTH   (dpa_pkg::ce_UserWidth       ),
    .NO_SLV_PORTS     (DESC_MUX_SLV_PORTS),
    .MAX_W_TRANS      (1),
    .FALL_THROUGH     (0),
    .SPILL_AW (1), .SPILL_W (1), .SPILL_B (1),
    .SPILL_AR (1), .SPILL_R (1)
  ) desc_mux (
    .clk_i  (desc_mem_clk),
    .rst_ni (desc_mem_reset_n),
    .test_i ('0),
    .slv    (axi_cdc2mux_desc),
    .mst    (axi_cdc2desc_mem)
  );

// Descriptor memory: RTL block RAM behind axi_to_mem (rtl_bram),
// DESC_MEM_ADDR_WIDTH bits of storage, 1-cycle read latency
rtl_bram #(
    .ADDR_WIDTH       ( dpa_pkg::ce_AddrWidth       ),
    .CACHE_ADDR_WIDTH ( DESC_MEM_ADDR_WIDTH         ),
    .DATA_WIDTH       ( dpa_pkg::ce_DataWidth       ),
    .ID_WIDTH         ( dpa_pkg::desc_bram_id_width )
) desc_mem (
    .aclk    ( desc_mem_clk     ),
    .aresetn ( desc_mem_reset_n ),
    .slv     ( axi_cdc2desc_mem )
);

// -----------------------------------------------------------------------------------------------------------------------------------------
//  CACHE SUBSYSTEM AND MEMORY ACCESS
// -----------------------------------------------------------------------------------------------------------------------------------------

for (genvar i = 0; i < dpa_pkg::DRAM_CH_NUMBER; i++) begin : cache_pu_rst
  logic [1:0] rst_q;
  (* MAX_FANOUT = 256 *) logic rstn_q;

  always_ff @(posedge cache_aclk or negedge cache_arstn) begin
    if (!cache_arstn) begin
      rst_q  <= 2'b00;
      rstn_q <= 1'b0;
    end else begin
      rst_q  <= {rst_q[0], 1'b1};
      rstn_q <= rst_q[1];
    end
  end

  assign cache_pu_rstn[i] = rstn_q;
end : cache_pu_rst

AXI_BUS #(
  .AXI_ADDR_WIDTH (cache_ss_pkg::AddrWidth),
  .AXI_DATA_WIDTH (cache_ss_pkg::DataWidth),
  .AXI_ID_WIDTH   (cache_ss_pkg::IdWidth),
  .AXI_USER_WIDTH (cache_ss_pkg::UserWidth)
) axim_ce_to_cache[dpa_pkg::DRAM_CH_NUMBER-1:0]();

for (genvar i = 0; i < dpa_pkg::DRAM_CH_NUMBER; i++) begin : dw_cache

    AXI_BUS #(
        .AXI_ADDR_WIDTH ( dpa_pkg::ce_AddrWidth       ),
        .AXI_DATA_WIDTH ( dpa_pkg::ce_DataWidth       ),
        .AXI_ID_WIDTH   ( dpa_pkg::ce_IdWidthToUncore ),
        .AXI_USER_WIDTH ( dpa_pkg::ce_UserWidth       )
    ) axim_ce2dw ();

    AXI_BUS #(
        .AXI_ADDR_WIDTH ( cache_ss_pkg::AddrWidth  ),
        .AXI_DATA_WIDTH ( cache_ss_pkg::DataWidth  ),
        .AXI_ID_WIDTH   ( cache_ss_pkg::IdWidth    ),
        .AXI_USER_WIDTH ( cache_ss_pkg::UserWidth  )
    ) axim_dw2cut ();

    `AXI_ASSIGN_FROM_REQ (axim_ce2dw, m_axim_ce2cache_req[i])
    `AXI_ASSIGN_TO_RESP  (m_axim_ce2cache_resp[i], axim_ce2dw)

    axi_dw_converter_intf #(
      .AXI_ID_WIDTH            (dpa_pkg::ce_IdWidthToUncore),
      .AXI_ADDR_WIDTH          (dpa_pkg::ce_AddrWidth),
      .AXI_SLV_PORT_DATA_WIDTH (dpa_pkg::ce_DataWidth),

      .AXI_MST_PORT_DATA_WIDTH (cache_ss_pkg::DataWidth),
      .AXI_USER_WIDTH          (dpa_pkg::ce_UserWidth),

      .AXI_MAX_READS(4)
    ) i_ce_dw_upsize (
      .clk_i  (cache_aclk),
      .rst_ni (cache_pu_rstn[i]),

      .slv    (axim_ce2dw),
      .mst    (axim_dw2cut)
    );

    // register slice: breaks the upsizer R/B logic -> dev_mem crossbar ready path
    axi_cut_intf #(
      .ADDR_WIDTH (cache_ss_pkg::AddrWidth),
      .DATA_WIDTH (cache_ss_pkg::DataWidth),
      .ID_WIDTH   (cache_ss_pkg::IdWidth),
      .USER_WIDTH (cache_ss_pkg::UserWidth)
    ) i_ce_dw_cut (
      .clk_i  (cache_aclk),
      .rst_ni (cache_pu_rstn[i]),
      .in     (axim_dw2cut),
      .out    (axim_ce_to_cache[i])
    );

end : dw_cache


for (genvar i = 0; i < dpa_pkg::DRAM_CH_NUMBER; i++) begin : rx_cache
  if (ENABLE_CACHE) begin : gen_cache
    cache_axi_wrapper #(
    .ADDR_WIDTH(cache_ss_pkg::AddrWidth),
    .DATA_WIDTH(cache_ss_pkg::DataWidth),
    .ID_WIDTH(cache_ss_pkg::IdWidth),
    .CACHE_BLOCK_SIZE(cache_ss_pkg::CACHE_BLOCK_SIZE),
    .CACHE_SIZE(cache_ss_pkg::CACHE_SIZE)
  ) cache_axi_wrapper_instance (
    .aclk(cache_aclk),
    .aresetn(cache_pu_rstn[i]),

    .s_axi(axim_ce_to_cache[i]),

    .m_axi_mem(axim_dpa_to_dram[i]),

    .invalid_valid        ('0),
    .invalid_address_start('0),
    .invalid_address_end  ('0),
    .invalid_done         ()
  );
  end : gen_cache
  else begin : gen_no_cache
    // cache bypassed: upsized CE bus goes to DRAM (same bus params)
    `AXI_ASSIGN(axim_dpa_to_dram[i], axim_ce_to_cache[i])
  end : gen_no_cache
end: rx_cache

rstgen i_rstgen_cache (
    .clk_i        ( cache_aclk                  ),
    .rst_ni       ( internal_axis_rstn          ),
    .test_mode_i  ( '0                          ),
    .rst_no       ( cache_arstn                 ),
    .init_no      (                             ) // keep open
);

// -----------------------------------------------------------------------------------------------------------------------------------------
// DESIGN CONSTRAINT COMPLIANCE
// -----------------------------------------------------------------------------------------------------------------------------------------

// single channel memory 
// TODO: Multi channel support
initial begin
  if (dpa_pkg::DRAM_CH_NUMBER != 1) begin
    $fatal(1, "DRAM_CH_NUMBER must be equal to 1, as multichannel is not yet supported. Current value: %0d", dpa_pkg::DRAM_CH_NUMBER);
  end
end

// CE -> cache path has no ID width converter: the cache must take the CE's
// full ID, or the crossbar port-select bits are lost and responses misroute
initial begin
  assert (cache_ss_pkg::IdWidth == dpa_pkg::ce_IdWidthToUncore)
    else $fatal(1, "cache_ss_pkg::IdWidth (%0d) must equal dpa_pkg::ce_IdWidthToUncore (%0d)", cache_ss_pkg::IdWidth, dpa_pkg::ce_IdWidthToUncore);
end

// m_axi_dram ID ports are 5 bits (dev_mem_3to1_axi_crossbar ID_WIDTH); the
// DRAM bus ID is zero-extended onto them, so it must not be wider
initial begin
  assert (cache_ss_pkg::IdWidth <= 5)
    else $fatal(1, "cache_ss_pkg::IdWidth (%0d) exceeds the m_axi_dram ID width (5)", cache_ss_pkg::IdWidth);
end


endmodule: compute_logic_wrapper
