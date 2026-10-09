# start sequence of the bootloader
#
#
#include <smp.h>
// end of the CE DRAM window (device memory offset 0x7FFFFFF0), 16-byte
// aligned; keep in sync with CE_STACK_TOP in ../ctl_cmd.h
#define STACK_TOP 0xFFFFFFF0
  .section .text.init
  .option norvc
  .globl _prog_start
_prog_start:
// initalize trap handler
  la      t0, handle_trap
  csrrw   zero, mtvec, t0
// initialize fpu: set mstatus.FS without touching the other fields (on
// Snitch FS is hardwired to Dirty when the FPU is present, so this is a no-op
// there; kept for cores where FS gates the FPU)
  li t0, 1 << 13
  csrs mstatus, t0
// initialize stack pointer at the end of the DRAM window
  li sp, STACK_TOP
  call main

_end:
  j _end