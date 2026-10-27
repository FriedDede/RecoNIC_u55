#!/usr/bin/env python3
#==============================================================================
# Copyright (C) 2026, Politecnico di Milano. All rights reserved.
# SPDX-License-Identifier: MIT
#
#==============================================================================
#
# gen_dpa_filelist.py
# -- Generate the compute engine (hw/reconic/compute/dpa) file lists for
#    simulation, with the same file set as the hardware build: the skip lists
#    are read from the plugin build.tcl, so the two never drift apart. Only
#    the few unused files in sim_skip_files are left out on top of those.
#
#    Writes, in the output directory:
#      dpa_inc.f  include directories (also needed by compute_logic_wrapper)
#      dpa.f      RTL files, packages first in dependency order, then
#                 interfaces, then everything else
#
#    xvlog/vlog do not reorder sources, so a package must be compiled before
#    any file that imports it.
#
#    gen_dpa_filelist.py -tool xsim|questasim [-o <dir>] [-bootrom <bootrom.sv>]
#
#==============================================================================
import argparse
import os
import re
import sys

script_dir = os.path.dirname(os.path.abspath(__file__))
root_dir = os.path.normpath(os.path.join(script_dir, '../..'))
dpa_dir = os.path.join(root_dir, 'hw/reconic/compute/dpa')
plugin_build_tcl = os.path.join(root_dir, 'hw/reconic/plugs/rdma_onic_plugin/build.tcl')

# Not instantiated under compute_engine and not compilable by xvlog/vlog
# (Vivado synthesis tolerates them because it only elaborates used modules)
sim_skip_files = [
  'axi_pheripherals/rv_plic.sv',     # single-value packed range
  'fpga/AxiBramLogger.sv',           # import of the missing CfMath package
  'fpga/BramDwc.sv',
  'fpga/BramLogger.sv',
  'fpga/TdpBramArray.sv',
]


def tcl_list(name, text):
  m = re.search(r'set\s+' + name + r'\s*\{([^}]*)\}', text)
  if not m:
    sys.exit('ERROR: %s not found in %s' % (name, plugin_build_tcl))
  return m.group(1).split()


# Same walk as dpa_collect in the plugin build.tcl
def collect(skip_dirs, skip_files):
  hdl, inc = [], []
  def walk(d, rel):
    entries = sorted(os.listdir(d))
    files = [e for e in entries if os.path.isfile(os.path.join(d, e))]
    if any(e.endswith(('.svh', '.vh')) for e in files):
      inc.append(d)
    for e in files:
      r = (rel + '/' + e).lstrip('/')
      if e.endswith(('.sv', '.v')) and r not in skip_files:
        hdl.append(os.path.join(d, e))
    for e in entries:
      r = (rel + '/' + e).lstrip('/')
      if os.path.isdir(os.path.join(d, e)) and r not in skip_dirs:
        walk(os.path.join(d, e), r)
  walk(dpa_dir, '')
  return hdl, inc


def strip_comments(text):
  text = re.sub(r'/\*.*?\*/', '', text, flags=re.S)
  return re.sub(r'//[^\n]*', '', text)


def order(hdl):
  text = {f: strip_comments(open(f, errors='ignore').read()) for f in hdl}
  pkg_file = {}
  for f, t in text.items():
    for m in re.finditer(r'^\s*package\s+(\w+)\s*;', t, re.M):
      pkg_file[m.group(1)] = f
  pkg_files = sorted(set(pkg_file.values()))

  # A package file depends on every other package it references
  deps = {}
  for f in pkg_files:
    used = set(re.findall(r'\b(\w+)::', text[f]))
    deps[f] = sorted({pkg_file[p] for p in used if p in pkg_file} - {f})

  ordered, state = [], {}
  def visit(f, stack):
    if state.get(f) == 'done':
      return
    if state.get(f) == 'visiting':
      sys.exit('ERROR: package dependency cycle: ' + ' -> '.join(stack + [f]))
    state[f] = 'visiting'
    for d in deps[f]:
      visit(d, stack + [f])
    state[f] = 'done'
    ordered.append(f)
  for f in pkg_files:
    visit(f, [])

  intf = sorted(f for f in hdl if f not in state and
                re.search(r'^\s*interface\s+\w+', text[f], re.M))
  rest = sorted(f for f in hdl if f not in state and f not in intf)
  return ordered + intf + rest


def main():
  ap = argparse.ArgumentParser(description=__doc__)
  ap.add_argument('-tool', required=True, choices=['xsim', 'questasim'])
  ap.add_argument('-o', default=script_dir, help='output directory')
  ap.add_argument('-bootrom', default=os.path.join(dpa_dir, 'bootrom_u55/bootrom.sv'),
                  help='bootrom.sv compiled into the compute engine')
  args = ap.parse_args()

  tcl = open(plugin_build_tcl).read()
  hdl, inc = collect(tcl_list('dpa_skip_dirs', tcl),
                     tcl_list('dpa_skip_files', tcl) + sim_skip_files)
  if not os.path.isfile(args.bootrom):
    sys.exit('ERROR: [dpa] bootrom not found: ' + args.bootrom)
  hdl.append(os.path.abspath(args.bootrom))

  out = os.path.abspath(args.o)
  rel = lambda p: os.path.relpath(p, out)
  inc_opt = (lambda d: '-i ' + rel(d)) if args.tool == 'xsim' else (lambda d: '+incdir+' + rel(d))

  with open(os.path.join(out, 'dpa_inc.f'), 'w') as fp:
    fp.write('\n'.join(inc_opt(d) for d in inc) + '\n')
  with open(os.path.join(out, 'dpa.f'), 'w') as fp:
    fp.write('\n'.join(rel(f) for f in order(hdl)) + '\n')
  print('INFO: [dpa] %d RTL files, %d include dirs, bootrom: %s' % (len(hdl), len(inc), args.bootrom))


if __name__ == '__main__':
  main()
