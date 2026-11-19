`include "axi_typedef.svh"
`include "axi_assign.svh"

// Compute engine, VexRiscv cores (hw/riscv-cores, hw/cores/vex):
// @ input:  ref_clk / ref_areset_n, reference of the cluster clock generators
// @ output: 64-bit AXI channels to the dram (cache) and to the descriptor memory, one per cluster
// Same ports, address map and clocking as compute_engine_snitch, selected with CE_CORE=vex
// (CE_VEX define in compute_logic_wrapper.sv).
//
// VexRiscv (as in hw/riscv-cores/hw/cluster/tops/u55_vex_top.sv): GenFullNoMmuMaxPerf, RV32IM,
// reset vector 0x0, I$ and D$ with one AXI master each (ids always 0), CLINT timer and software
// interrupts, no external interrupts. VexRiscvU55.v is generated from SpinalHDL
// (make -C hw/riscv-cores <build>/vexriscv/VexRiscvU55.v) and boots from a bootrom built for it
// (make -C hw/riscv-cores/bootrom_u55 CORE=vex).
//
// Clocking (as in u55_vex_top.sv):
//   core domain     one clock per core, each core is wrapped in its clock domain (vex_cd_wrapper)
//   cluster domain  one clock per cluster: crossbar, bootrom, clint
//   output domains  dram_axim_clk / desc_axim_clk, crossed with axi_cdc
// Every cluster has its own clock generator (cluster_clk_gen, xlnx_clk_gen_cluster IP).
// The reset is asserted asynchronously and released by a rstgen in each clock domain.

module compute_engine_vex
    import dpa_pkg::*;
(
    input   logic ref_clk, // 250Mhz
    input   logic ref_areset_n,

    // DRAM MEMORY CHANNEL
    output  axim64_core2mem_req_t [dpa_pkg::DRAM_CH_NUMBER-1 : 0] m_axim_dram_req,
    input   axim64_core2mem_resp_t [dpa_pkg::DRAM_CH_NUMBER-1 : 0] m_axim_dram_resp,
    input   logic dram_axim_clk,
    input   logic dram_axim_reset_n [dpa_pkg::DRAM_CH_NUMBER],

    // DESCRIPTOR MEMORY CHANNEL
    output  axim64_core2mem_req_t  [dpa_pkg::DRAM_CH_NUMBER-1 : 0]  m_axim_desc_req,
    input   axim64_core2mem_resp_t  [dpa_pkg::DRAM_CH_NUMBER-1 : 0] m_axim_desc_resp,
    input   logic desc_axim_clk,
    input   logic desc_axim_reset_n
);

localparam CORE_NUMBER          = dpa_pkg::CORE_NUMBER       ;
localparam CLUSTER_NUMBER       = dpa_pkg::CLUSTER_NUMBER    ;
localparam DRAM_CH_NUMBER       = dpa_pkg::DRAM_CH_NUMBER    ;
localparam AxiAddrWidth         = dpa_pkg::ce_AddrWidth      ;
localparam AxiDataWidth         = dpa_pkg::ce_DataWidth      ;
localparam AxiIdWidthToUncore   = dpa_pkg::ce_IdWidthToUncore;
localparam AxiUserWidth         = dpa_pkg::ce_UserWidth      ;
// VexRiscv: two AXI masters per core (I$, D$), 1-bit ids (always 0)
localparam VexAxiPorts          = 2;
localparam AxiIdWidthVex        = 1;
// crossbar slave ports: the crossbar prepends $clog2(VexAxiPorts * CORE_NUMBER) bits, the uncore
// id width is fixed by dpa_pkg (compute_logic_wrapper, dev-mem crossbar ID budget)
localparam AxiIdWidthCore       = AxiIdWidthToUncore - $clog2(VexAxiPorts * CORE_NUMBER);

if (AxiIdWidthCore < AxiIdWidthVex) begin : gen_id_width_check
    $error("compute_engine_vex: %0d cores (%0d AXI masters) do not fit in %0d uncore id bits",
           CORE_NUMBER, VexAxiPorts * CORE_NUMBER, AxiIdWidthToUncore);
end

// xbar config
localparam axi_pkg::xbar_cfg_t xbar_cfg = '{
    NoSlvPorts:         VexAxiPorts * CORE_NUMBER,
    NoMstPorts:         4,
    MaxMstTrans:        16,
    MaxSlvTrans:        16,
    FallThrough:        1'b0,
    LatencyMode:        axi_pkg::CUT_ALL_PORTS,
    PipelineStages:     1,
    AxiIdWidthSlvPorts: AxiIdWidthCore,
    AxiIdUsedSlvPorts:  AxiIdWidthCore,
    UniqueIds:          '0,
    AxiAddrWidth:       AxiAddrWidth,
    AxiDataWidth:       AxiDataWidth,
    NoAddrRules:        4
};

// generate the address map (same as compute_engine_snitch)
typedef axi_pkg::xbar_rule_32_t  rule_t;
function rule_t [3:0] addr_map_gen ();
    // rom address 0x0 -> 0xffff (VexRiscv resets at 0x0)
    addr_map_gen[0] = rule_t'{
        idx:        unsigned'(0),
        start_addr: 32'h0000_0000,
        end_addr:   32'h0001_0000,
        default:    '0
    };
    // dram address 0x8000000 -> 0x8000000 + clog2(size)
    addr_map_gen[1] = rule_t'{
        idx:        unsigned'(1),
        start_addr: 32'h8000_0000,
        end_addr:   32'h8000_0000 + 32'h8000_0000, // 2GB per cluster here
        default:    '0
    };
    // DESC BRAM
    addr_map_gen[2] = rule_t'{
        idx:        unsigned'(2),
        start_addr: 32'h1000_0000,
        end_addr:   32'h2000_0000, // 256MB aperture
        default:    '0
    };
    // CLINT (Pulp Specs RISC-V privilege spec 1.11 compatible CLINT )
    addr_map_gen[3] = rule_t'{
        idx:        unsigned'(3),
        start_addr: 32'h0200_0000,
        end_addr:   32'h0200_C000,
        default:    '0
    };
endfunction

localparam rule_t [3:0] AddrMapUncore = addr_map_gen();

// axi busses: [CLUSTER_NUMBER-1:0] clusters, cluster domain

AXI_BUS #(
    .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
    .AXI_DATA_WIDTH ( AxiDataWidth     ),
    .AXI_ID_WIDTH   ( AxiIdWidthToUncore ),
    .AXI_USER_WIDTH ( AxiUserWidth     )
) axi_dram[CLUSTER_NUMBER-1:0](), axi_desc[CLUSTER_NUMBER-1:0]();

// output domains
AXI_BUS #(
    .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
    .AXI_DATA_WIDTH ( AxiDataWidth     ),
    .AXI_ID_WIDTH   ( AxiIdWidthToUncore ),
    .AXI_USER_WIDTH ( AxiUserWidth     )
) axi_cdc2out_dram[DRAM_CH_NUMBER-1:0](), axi_cdc2out_desc[DRAM_CH_NUMBER-1:0]();

// clocking and reset declaration: core and cluster (crossbar) domains,
// the core resets are generated inside the vex_cd_wrapper
logic [CLUSTER_NUMBER-1:0][CORE_NUMBER-1:0] clk_core;
logic [CLUSTER_NUMBER-1:0]                  clk_cluster, rst_cluster_n, cluster_locked;
(* keep = "true" *) logic ce_rst_async_n;

// the logic is in reset until all the cluster plls lock and the reference reset is released
assign ce_rst_async_n = ref_areset_n & (&cluster_locked);

// ---------------
// Clusters
// ---------------

for ( genvar i=0; i<CLUSTER_NUMBER; ++i) begin  : vex_cluster_gen

    // cluster clock generator: crossbar clock and one clock per core
    cluster_clk_gen #(
        .NumCores      ( CORE_NUMBER       )
    ) i_cluster_clk_gen (
        .clk_in1       ( ref_clk           ), // 250 Mhz ref clk
        .reset         ( ~ref_areset_n     ),
        .locked        ( cluster_locked[i] ),
        .clk_cluster_o ( clk_cluster[i]    ),
        .clk_core_o    ( clk_core[i]       )
    );
    rstgen i_rstgen_cluster (
        .clk_i        ( clk_cluster[i]     ),
        .rst_ni       ( ce_rst_async_n     ),
        .test_mode_i  ( '0                 ),
        .rst_no       ( rst_cluster_n[i]   ),
        .init_no      (                    ) // keep open
    );

    // CLINT interrupts, cluster domain (synchronized in the vex_cd_wrapper)
    logic [CORE_NUMBER-1:0] timer_irq, ipi;

    // crossbar slave ports: core j I$ at 2*j, D$ at 2*j+1
    AXI_BUS #(
        .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
        .AXI_DATA_WIDTH ( AxiDataWidth     ),
        .AXI_ID_WIDTH   ( AxiIdWidthCore   ),
        .AXI_USER_WIDTH ( AxiUserWidth     )
    ) axi_vex2xbar[VexAxiPorts * CORE_NUMBER - 1 : 0]();

    for ( genvar j=0; j<CORE_NUMBER; ++j) begin  : core_gen
        AXI_BUS #(
            .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
            .AXI_DATA_WIDTH ( AxiDataWidth     ),
            .AXI_ID_WIDTH   ( AxiIdWidthVex    ),
            .AXI_USER_WIDTH ( AxiUserWidth     )
        ) axi_vex[VexAxiPorts-1:0]();

        // enumeration restarts in each cluster: hart id = core index in the cluster
        vex_cd_wrapper #(
            .AxiAddrWidth   ( AxiAddrWidth   ),
            .AxiDataWidth   ( AxiDataWidth   ),
            .AxiUserWidth   ( AxiUserWidth   ),
            .AxiIdWidth     ( AxiIdWidthVex  )
        ) i_vex (
            .clk_core_i     ( clk_core[i][j]   ),
            .clk_cluster_i  ( clk_cluster[i]   ),
            .rst_cluster_ni ( rst_cluster_n[i] ),
            .rst_ni         ( ce_rst_async_n   ),
            .hart_id_i      ( 32'(j)           ),
            .timer_irq_i    ( timer_irq[j]     ),
            .soft_irq_i     ( ipi[j]           ),
            .ext_irq_i      ( 1'b0             ),
            .ibus           ( axi_vex[0]       ),
            .dbus           ( axi_vex[1]       )
        );

        // 1-bit core ids -> crossbar slave port ids, zero extended (no remapping logic)
        for (genvar k = 0; k < VexAxiPorts; ++k) begin : gen_iw
            axi_iw_converter_intf #(
                .AXI_SLV_PORT_ID_WIDTH        ( AxiIdWidthVex      ),
                .AXI_MST_PORT_ID_WIDTH        ( AxiIdWidthCore     ),
                .AXI_SLV_PORT_MAX_UNIQ_IDS    ( 2**AxiIdWidthVex   ),
                .AXI_SLV_PORT_MAX_TXNS_PER_ID ( 4                  ),
                .AXI_SLV_PORT_MAX_TXNS        ( 8                  ),
                .AXI_MST_PORT_MAX_UNIQ_IDS    ( 2**AxiIdWidthVex   ),
                .AXI_MST_PORT_MAX_TXNS_PER_ID ( 4                  ),
                .AXI_ADDR_WIDTH               ( AxiAddrWidth       ),
                .AXI_DATA_WIDTH               ( AxiDataWidth       ),
                .AXI_USER_WIDTH               ( AxiUserWidth       )
            ) i_iw_converter (
                .clk_i  ( clk_cluster[i]                       ),
                .rst_ni ( rst_cluster_n[i]                     ),
                .slv    ( axi_vex[k]                           ),
                .mst    ( axi_vex2xbar[VexAxiPorts * j + k]    )
            );
        end : gen_iw
    end : core_gen

    AXI_BUS #(
        .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
        .AXI_DATA_WIDTH ( AxiDataWidth     ),
        .AXI_ID_WIDTH   ( AxiIdWidthToUncore),
        .AXI_USER_WIDTH ( AxiUserWidth     )
    ) axi_xbar2uncore[3:0]();
    AXI_BUS #(
        .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
        .AXI_DATA_WIDTH ( AxiDataWidth     ),
        .AXI_ID_WIDTH   ( AxiIdWidthToUncore ),
        .AXI_USER_WIDTH ( AxiUserWidth     )
    ) axi_rom(), axi_clint();

    axi_xbar_intf #(
        .AXI_USER_WIDTH(AxiUserWidth),
        .Cfg(xbar_cfg),
        .rule_t(rule_t)
    ) i_axi_xbar_intf (
        .clk_i(clk_cluster[i]),
        .rst_ni(rst_cluster_n[i]),
        .test_i('0),
        .slv_ports(axi_vex2xbar),
        .mst_ports(axi_xbar2uncore),
        .addr_map_i(AddrMapUncore),
        .en_default_mst_port_i('0),
        .default_mst_port_i('0)
    );

    // to hbm
    `AXI_ASSIGN(axi_dram[i], axi_xbar2uncore[1])
    // to descriptor memory
    `AXI_ASSIGN(axi_desc[i], axi_xbar2uncore[2])
    // to uncore
    `AXI_ASSIGN(axi_rom, axi_xbar2uncore[0])
    `AXI_ASSIGN(axi_clint, axi_xbar2uncore[3])

    // CLINT: mtime / mtimecmp, timer and software interrupts of the cores
    logic rtc;
    always_ff @(posedge clk_cluster[i] or negedge rst_cluster_n[i]) begin
        if (~rst_cluster_n[i]) begin
            rtc <= 0;
        end else begin
            rtc <= rtc ^ 1'b1;
        end
    end
    axi_clint #(
        .AddrWidth(AxiAddrWidth),
        .DataWidth(AxiDataWidth),
        .IdWidthIn(AxiIdWidthToUncore),
        .UserWidth(AxiUserWidth),
        .NR_CORES(CORE_NUMBER)
    ) axi_clint_instance(
        .clk_i(clk_cluster[i]),
        .rst_ni(rst_cluster_n[i]),
        .testmode_i('0),
        .clint(axi_clint),
        .rtc_i(rtc),
        .timer_irq_o(timer_irq),
        .ipi_o(ipi)
    );

    // ROM
    logic                    rom_req;
    logic [AxiAddrWidth-1:0] rom_addr;
    logic [AxiDataWidth-1:0] rom_rdata;
    logic                    rom_rvalid;
    axi_to_mem_intf #(
        .ADDR_WIDTH ( AxiAddrWidth),
        .DATA_WIDTH ( AxiDataWidth),
        .ID_WIDTH   ( AxiIdWidthToUncore),
        .USER_WIDTH ( AxiUserWidth),
        .NUM_BANKS  ( 1)
    ) i_axi_to_mem (
        .clk_i       ( clk_cluster[i]),
        .rst_ni      ( rst_cluster_n[i]),
        .busy_o      ( ),
        .slv         ( axi_rom),
        .mem_req_o   ( rom_req),
        .mem_gnt_i   ( '1),
        .mem_addr_o  ( rom_addr),
        .mem_wdata_o ( ),
        .mem_strb_o  ( ),
        .mem_atop_o  ( ),
        .mem_we_o    ( ),
        .mem_rvalid_i( rom_rvalid),
        .mem_rdata_i ( rom_rdata)
    );
    // module of the -bootrom build option, an rv32im bootrom with the code at 0x0
    // (bootrom_u55 CORE=vex, renamed to bootrom.sv by scripts/Makefile)
    bootrom i_bootrom (
        .clk_i      ( clk_cluster[i] ),
        .req_i      ( rom_req   ),
        .addr_i     ( rom_addr  ),
        .rdata_o    ( rom_rdata ),
        .rvalid_o   ( rom_rvalid)
    );
end : vex_cluster_gen

// -----------------
// OUTPUT CDC
// -----------------

// clock domain conversion: cluster -> desc_mem, one per cluster
for (genvar i = 0; i < DRAM_CH_NUMBER; i++) begin : desc_cdc

    axi_cdc_intf #(
      .AXI_ID_WIDTH   (AxiIdWidthToUncore),
      .AXI_ADDR_WIDTH (AxiAddrWidth),
      .AXI_DATA_WIDTH (AxiDataWidth),
      .AXI_USER_WIDTH (AxiUserWidth),
      .LOG_DEPTH(3),
      .SYNC_STAGES(2)
    ) axi_cdc_rv_desc (
      .src_clk_i  (clk_cluster[i]),
      .src_rst_ni (rst_cluster_n[i]),
      .src        (axi_desc[i]),

      .dst_clk_i  (desc_axim_clk),
      .dst_rst_ni (desc_axim_reset_n),
      .dst        (axi_cdc2out_desc[i])
    );

    `AXI_ASSIGN_TO_REQ(m_axim_desc_req[i], axi_cdc2out_desc[i])
    `AXI_ASSIGN_FROM_RESP(axi_cdc2out_desc[i], m_axim_desc_resp[i])
end : desc_cdc

// clock domain conversion: cluster -> dram, one per cluster
for (genvar i = 0; i < DRAM_CH_NUMBER; i++) begin : dram_cdc

    axi_cdc_intf #(
      .AXI_ID_WIDTH   (AxiIdWidthToUncore),
      .AXI_ADDR_WIDTH (AxiAddrWidth),
      .AXI_DATA_WIDTH (AxiDataWidth),
      .AXI_USER_WIDTH (AxiUserWidth),
      .LOG_DEPTH(3),
      .SYNC_STAGES(2)
    ) axi_cdc_rv_mem (
      .src_clk_i  (clk_cluster[i]),
      .src_rst_ni (rst_cluster_n[i]),
      .src        (axi_dram[i]),

      .dst_clk_i  (dram_axim_clk),
      .dst_rst_ni (dram_axim_reset_n[i]),
      .dst        (axi_cdc2out_dram[i])
    );

    `AXI_ASSIGN_TO_REQ(m_axim_dram_req[i], axi_cdc2out_dram[i])
    `AXI_ASSIGN_FROM_RESP(axi_cdc2out_dram[i], m_axim_dram_resp[i])
end : dram_cdc

// -----------------
// END
// -----------------

endmodule
