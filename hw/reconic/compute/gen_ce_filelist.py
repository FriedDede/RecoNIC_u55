#!/usr/bin/env python3
#==============================================================================
# Copyright (C) 2026, Politecnico di Milano. All rights reserved.
# SPDX-License-Identifier: MIT
#
#==============================================================================
#
# gen_ce_filelist.py
# -- File lists of the RISC-V compute engine, shared by the hardware build
#    (hw/reconic/plugs/rdma_onic_plugin/build.tcl) and the simulation
#    (sim/scripts/*_compile.do).
#
#    The RTL comes from the riscv-cores submodule (hw/riscv-cores), plus the
#    ReCoNIC sources in hw/reconic/compute:
#      dpa/dpa_pkg.sv                 compute engine parameters and AXI types
#      dpa/compute_engine_vex.sv      VexRiscv compute engine   (-core vex)
#      dpa/compute_engine_mini.sv     riscv-mini compute engine (-core mini)
#      dpa/compute_engine_snitch.sv   snitch compute engine     (-core snitch)
#      cache_subsystem/               dram cache in front of the compute engine
#    Only the files reachable from the roots (default: compute_logic_wrapper.sv)
#    are listed, in dependency order (definitions before users): the module
#    resolver is the one of hw/riscv-cores/tcl_scripts/filelists/gen_filelist.py.
#    The roots themselves are not listed, the caller compiles them.
#
#    Writes, in the output directory:
#      dpa_inc.f  include directories
#      dpa.f      RTL files in compile order
#
#    gen_ce_filelist.py -tool vivado|xsim|questasim -bootrom <bootrom.sv>
#                       [-core vex|mini|snitch] [-vex-rtl <VexRiscvU55.v>]
#                       [-mini-rtl <Tile.sv>] [-o <dir>]
#                       [-root <file> ...]
#
#    vivado: absolute paths, one per line. xsim/questasim: xvlog/vlog options,
#    paths relative to the output directory.
#
#==============================================================================
import argparse
import os
import sys

compute_dir = os.path.dirname(os.path.abspath(__file__))
root_dir = os.path.normpath(os.path.join(compute_dir, '../../..'))
cores_dir = os.path.join(root_dir, 'hw/riscv-cores')
sys.path.insert(0, os.path.join(cores_dir, 'tcl_scripts/filelists'))
try:
  import gen_filelist as gf
except ImportError:
  sys.exit('ERROR: [ce] %s/tcl_scripts/filelists/gen_filelist.py not found, '
           'run: git submodule update --init hw/riscv-cores' % cores_dir)

CE_TOP = {
  'vex':    os.path.join(compute_dir, 'dpa/compute_engine_vex.sv'),
  'mini':   os.path.join(compute_dir, 'dpa/compute_engine_mini.sv'),
  'snitch': os.path.join(compute_dir, 'dpa/compute_engine_snitch.sv'),
}
DEFAULT_ROOTS = [os.path.join(compute_dir, 'lookside/compute_logic_wrapper.sv')]


def reconic_sources():
  srcs = [os.path.join(compute_dir, 'dpa/dpa_pkg.sv')]
  cache_dir = os.path.join(compute_dir, 'cache_subsystem')
  for f in sorted(os.listdir(cache_dir)):
    p = os.path.join(cache_dir, f)
    if f.endswith(gf.SRC_EXT) and not gf.excluded('/' + f):
      srcs.append(p)
  return srcs


def collect(core, bootrom, core_rtl, roots):
  rel_srcs, rel_hdrs = gf.scan()
  sources = [os.path.join(gf.REPO, s) for s in rel_srcs]
  headers = [os.path.join(gf.REPO, h) for h in rel_hdrs]
  sources += reconic_sources() + [CE_TOP[core], bootrom]
  # generated core rtl: riscv-mini Tile (chisel), VexRiscvU55 (SpinalHDL)
  if core_rtl:
    sources.append(core_rtl)

  info = {s: gf.parse(s) for s in sources + roots}
  owner = {}
  for s in sources:
    for d in info[s][0]:
      if d in owner and owner[d] != s:
        sys.exit('ERROR: [ce] %s defined in %s and %s' % (d, owner[d], s))
      owner[d] = s

  order, visited, incdirs, missing = [], set(), [], set()

  def visit(src):
    if src in visited:
      return
    visited.add(src)
    defs, incs, idents = info[src]
    idents = set(idents)
    # included headers (recursively): include dirs, their references count as src ones
    pending, seen = [(inc, src) for inc in incs], set()
    while pending:
      inc, frm = pending.pop()
      d = gf.resolve_include(inc, frm, headers)
      if d is None:
        missing.add('`include "%s" (%s)' % (inc, frm))
        continue
      if d not in incdirs:
        incdirs.append(d)
      hdr = os.path.normpath(os.path.join(d, inc))
      if hdr in seen:
        continue
      seen.add(hdr)
      _, hincs, hidents = gf.parse(hdr)
      idents |= hidents
      pending += [(i, hdr) for i in hincs]
    for ident in sorted(idents - set(defs)):
      if ident in owner:
        visit(owner[ident])
    order.append(src)

  for r in roots:
    visit(r)
  for m in sorted(missing):
    print('WARNING: [ce] unresolved %s' % m, file=sys.stderr)

  # the compute engine must be reachable from the roots
  if CE_TOP[core] not in order:
    sys.exit('ERROR: [ce] %s is not instantiated from %s'
             % (os.path.basename(CE_TOP[core]), ' '.join(roots)))
  return [f for f in order if f not in roots], incdirs


def main():
  ap = argparse.ArgumentParser(description='RISC-V compute engine file lists')
  ap.add_argument('-tool', required=True, choices=['vivado', 'xsim', 'questasim'])
  ap.add_argument('-core', default='vex', choices=list(CE_TOP))
  ap.add_argument('-bootrom', required=True,
                  help='bootrom.sv compiled into the compute engine (module bootrom)')
  ap.add_argument('-mini-rtl', default='',
                  help='riscv-mini Tile.sv, generated from chisel (-core mini only)')
  ap.add_argument('-vex-rtl', default='',
                  help='VexRiscvU55.v, generated from SpinalHDL (-core vex only)')
  ap.add_argument('-root', action='append', default=[],
                  help='file instantiating the compute engine (default: compute_logic_wrapper.sv)')
  ap.add_argument('-o', default='.', help='output directory')
  args = ap.parse_args()

  bootrom = os.path.abspath(args.bootrom)
  if not os.path.isfile(bootrom):
    sys.exit('ERROR: [ce] bootrom not found: ' + args.bootrom)
  core_rtl = ''
  for core, arg, name in (('mini', args.mini_rtl, 'riscv-mini Tile.sv (-mini-rtl)'),
                          ('vex', args.vex_rtl, 'VexRiscvU55.v (-vex-rtl)')):
    if args.core == core:
      core_rtl = os.path.abspath(arg) if arg else ''
      if not os.path.isfile(core_rtl):
        sys.exit('ERROR: [ce] %s not found: %r' % (name, arg))
  roots = [os.path.abspath(r) for r in args.root] or DEFAULT_ROOTS

  hdl, inc = collect(args.core, bootrom, core_rtl, roots)

  out = os.path.abspath(args.o)
  os.makedirs(out, exist_ok=True)
  if args.tool == 'vivado':
    path, inc_opt = (lambda p: p), (lambda d: d)
  else:
    path = lambda p: os.path.relpath(p, out)
    inc_opt = (lambda d: '-i ' + path(d)) if args.tool == 'xsim' else (lambda d: '+incdir+' + path(d))

  with open(os.path.join(out, 'dpa_inc.f'), 'w') as fp:
    fp.write(''.join(inc_opt(d) + '\n' for d in inc))
  with open(os.path.join(out, 'dpa.f'), 'w') as fp:
    fp.write(''.join(path(f) + '\n' for f in hdl))
  print('INFO: [ce] %s compute engine: %d RTL files, %d include dirs, bootrom: %s'
        % (args.core, len(hdl), len(inc), bootrom))


if __name__ == '__main__':
  main()
