/* Copyright 2018 ETH Zurich and University of Bologna.
 * Copyright and related rights are licensed under the Solderpad Hardware
 * License, Version 0.51 (the "License"); you may not use this file except in
 * compliance with the License.  You may obtain a copy of the License at
 * http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
 * or agreed to in writing, software, hardware and materials distributed under
 * this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations under the License.
 *
 * File: $filename.v
 *
 * Description: Auto-generated bootrom
 */

// Auto-generated code
// 09/10/2026 17:56:54
module bootrom (
   input  logic         clk_i,
   input  logic         req_i,
   input  logic [63:0]  addr_i,
   output logic [63:0]  rdata_o,
   output logic         rvalid_o
);
    localparam int RomSize = 140;

    const logic [RomSize-1:0][63:0] mem = {
        64'h00000000_f41ff06f,
        64'h0142a023_0330000f,
        64'hf91ff06f_00e80833,
        64'h00d888b3_00130313,
        64'hfd9ff06f_00000e13,
        64'h00000e93_00050f13,
        64'h01860633_00259613,
        64'h00b68e63_00478793,
        64'h00158593_01c7a023,
        64'hffd712e3_01fe0e33,
        64'h01960633_03af8fb3,
        64'h004f0f13_001e8e93,
        64'h00062d03_000f2f83,
        64'h0300006f_00000593,
        64'h01550533_016787b3,
        64'h00281513_00289793,
        64'h066b8a63_00000313,
        64'h00000893_00269c93,
        64'h01075713_01071713,
        64'h0106d693_01075b93,
        64'h00000813_0009a683,
        64'h00092703_0004ab03,
        64'h00042c03_0003aa83,
        64'hfe078ae3_0107d793,
        64'h01079793_0002a783,
        64'h00010a37_01498993,
        64'h01090913_00c48493,
        64'h00840413_00438393,
        64'h01828293_01a12223,
        64'h01912423_01812623,
        64'h01712823_01612a23,
        64'h01512c23_01412e23,
        64'h100009b7_10000937,
        64'h100004b7_10000437,
        64'h100003b7_100002b7,
        64'h03312023_03212223,
        64'h02912423_02812623,
        64'hfd010113_0000006f,
        64'h00000000_00000000,
        64'h00000000_00000000,
        64'h00000000_00000000,
        64'h00000000_00000000,
        64'h00000000_00000000,
        64'h00000000_00000000,
        64'h00000000_00000000,
        64'h00000000_00000000,
        64'h00000000_00000000,
        64'h00000000_00000000,
        64'h00000000_00000000,
        64'h00000000_00000000,
        64'h00000000_00000000,
        64'h00000000_00000000,
        64'h00000000_00000000,
        64'h00000000_00000000,
        64'h00000000_00000000,
        64'h00000000_00000000,
        64'h00000000_00000000,
        64'h00000000_00000000,
        64'h00000000_00000000,
        64'h00000000_00000000,
        64'h00000000_00000000,
        64'h00000000_00000000,
        64'h00000000_00000000,
        64'h00000000_00000000,
        64'h00000000_00000000,
        64'h00000000_00000000,
        64'h0000006f_0ec000ef,
        64'hff000113_3002a073,
        64'h000022b7_30529073,
        64'h10028293_00000297
    };

    logic [$clog2(RomSize)-1:0] addr_q;

    always_ff @(posedge clk_i) begin
        if (req_i) begin
            addr_q <= addr_i[$clog2(RomSize)-1+3:3];
            rvalid_o <= 1;
        end else begin
            rvalid_o <= 0;
        end
    end

    // this prevents spurious Xes from propagating into
    // the speculative fetch stage of the core
    assign rdata_o = (addr_q < RomSize) ? mem[addr_q] : '0;
endmodule
