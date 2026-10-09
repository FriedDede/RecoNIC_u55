//==============================================================================
// Copyright (C) 2026, Politecnico di Milano. All rights reserved.
// SPDX-License-Identifier: MIT
//
//==============================================================================
//  Matrix multiplication firmware, run from the bootrom by the RISC-V compute
//  engine: C[a_row x b_col] = A[a_row x a_col] * B[a_col x b_col], int32,
//  row-major, all matrices in device memory (CE_DRAM_BASE window).
//
//  Waits for h2c_work_start in the control command (ctl_cmd.h), runs the job
//  and reports completion through c2h_work_finished.
//
//  Constraints of running from ROM: no writable globals (.data/.bss are not
//  backed by RAM), no libc, no UART (its old address now decodes to desc_mem).
//==============================================================================
#include <stdint.h>
#include "ctl_cmd.h"

#define DESC_REG(off) (*(volatile uint32_t *)(CE_DESC_BASE + (off)))

static void mmult(const volatile int32_t *a, const volatile int32_t *b,
                  volatile int32_t *c, uint32_t a_row, uint32_t a_col,
                  uint32_t b_col)
{
    for (uint32_t i = 0; i < a_row; i++) {
        for (uint32_t j = 0; j < b_col; j++) {
            int32_t acc = 0;
            for (uint32_t k = 0; k < a_col; k++)
                acc += a[i * a_col + k] * b[k * b_col + j];
            c[i * b_col + j] = acc;
        }
    }
}

int main(void)
{
    while (1) {
        // wait for the host to issue a command
        while (CTL_CMD_LO(DESC_REG(CTL_CMD_W_STATUS)) == 0)
            ;

        uint32_t a_base = DESC_REG(CTL_CMD_W_A_BASE);
        uint32_t b_base = DESC_REG(CTL_CMD_W_B_BASE);
        uint32_t c_base = DESC_REG(CTL_CMD_W_C_BASE);
        uint32_t a_dim  = DESC_REG(CTL_CMD_W_A_DIM);
        uint32_t b_dim  = DESC_REG(CTL_CMD_W_B_DIM);

        mmult((const volatile int32_t *)a_base, (const volatile int32_t *)b_base,
              (volatile int32_t *)c_base, CTL_CMD_HI(a_dim), CTL_CMD_LO(a_dim),
              CTL_CMD_HI(b_dim));

        // C goes to device memory and the status to desc_mem over different
        // AXI paths: fence waits for every store's write response, so C is
        // in memory before the host can see finished
        asm volatile("fence rw, rw" ::: "memory");

        // finished = 1 and start = 0 in one store
        DESC_REG(CTL_CMD_W_STATUS) = CTL_CMD_FINISHED;
    }
    return 0;
}

void handle_trap(void)
{
    while (1) {}
}
