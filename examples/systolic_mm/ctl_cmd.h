//==============================================================================
// Copyright (C) 2026, Politecnico di Milano. All rights reserved.
// SPDX-License-Identifier: MIT
//
//==============================================================================
//  Control command shared by the host (systolic_mm.c) and the RISC-V firmware
//  (bootrom_u55/src/main.c).
//
//  The command lives at the start of the 4 KB descriptor memory (desc_mem):
//    - host:   BAR offset RN_CLR_CTL_CMD (rn_register.h), 32-bit AXI-Lite
//    - RISC-V: CE_DESC_BASE
//
//  Handshake:
//    1. host writes words 0..5, then CTL_CMD_W_STATUS = CTL_CMD_START
//       (start = 1, finished = 0) as the last write
//    2. RISC-V polls the start bit, reads the command, runs the job, waits for
//       its result stores to complete, then writes CTL_CMD_W_STATUS =
//       CTL_CMD_FINISHED (start = 0, finished = 1) in a single store
//    3. host polls the finished bit, then reads C back from device memory
//==============================================================================
#ifndef __CTL_CMD_H__
#define __CTL_CMD_H__

// 32-bit word offsets (bytes) of the command in desc_mem
#define CTL_CMD_W_SIZE       0x00  // ctl_cmd_size
#define CTL_CMD_W_A_BASE     0x04  // a_baseaddr (CE / device address)
#define CTL_CMD_W_B_BASE     0x08  // b_baseaddr
#define CTL_CMD_W_C_BASE     0x0C  // c_baseaddr
#define CTL_CMD_W_A_DIM      0x10  // [31:16] a_row, [15:0] a_col
#define CTL_CMD_W_B_DIM      0x14  // [31:16] b_col, [15:0] work_id
#define CTL_CMD_W_STATUS     0x18  // [31:16] c2h_work_finished, [15:0] h2c_work_start

#define CTL_CMD_HI(w)        (((w) >> 16) & 0xffff)
#define CTL_CMD_LO(w)        ((w) & 0xffff)
#define CTL_CMD_PACK(hi, lo) ((((uint32_t)(hi) & 0xffff) << 16) | ((uint32_t)(lo) & 0xffff))

#define CTL_CMD_START        CTL_CMD_PACK(0, 1)
#define CTL_CMD_FINISHED     CTL_CMD_PACK(1, 0)

// Compute engine (RISC-V) address map, see compute_engine.sv
#define CE_ROM_BASE          0x00000000u  // bootrom
#define CE_DESC_BASE         0x10000000u  // desc_mem (only the low 4 KB decoded)
#define CE_DRAM_BASE         0x80000000u  // device memory (HBM) offset 0
#define CE_DRAM_SIZE         0x80000000u  // 2 GB: device memory 0x0-0x7FFFFFFF

// compute_logic_wrapper keeps the low 31 bits of CE DRAM accesses, so the
// device memory offset X (host side, QDMA) is CE_DRAM_ADDR(X) for the RISC-V
#define CE_DRAM_ADDR(dev_off) (CE_DRAM_BASE + (uint32_t)(dev_off))

// Firmware stack grows down from the end of the 2 GB window (startup.S):
// device memory offset 0x7FFFFFF0, 16-byte aligned as the ABI requires
#define CE_STACK_TOP         0xFFFFFFF0u

#endif
