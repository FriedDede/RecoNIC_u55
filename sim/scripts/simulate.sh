#!/bin/bash
#==============================================================================
# Copyright (C) 2023, Advanced Micro Devices, Inc. All rights reserved.
# SPDX-License-Identifier: MIT
#
#==============================================================================
set -Eeuo pipefail

echo -e "simulate.sh - RecoNIC simulation with RoCEv2 packets"

# Default to the Vivado found in PATH
if [[ -z "${VIVADO_DIR:-}" ]]; then
  VIVADO_DIR=$(dirname "$(dirname "$(readlink -f "$(command -v vivado)")")")
fi
export VIVADO_DIR

# Name of the precompiled Vivado IP library for an IP, at the version found in
# XIL_LIB_DIR (e.g. xil_lib ernic -> ernic_v4_2_0). XIL_LIB_DIR is the xsim
# library shipped with Vivado, or COMPILED_LIB_DIR for Questa
xil_lib()
{
  local lib
  lib=$(ls -d "$XIL_LIB_DIR"/${1}_v[0-9]* 2>/dev/null | sort -V | tail -1)
  if [[ -z "$lib" ]]; then
    echo "ERROR: no precompiled library for $1 in $XIL_LIB_DIR" >&2
    return 1
  fi
  basename "$lib"
}

# Libraries the testbenches are elaborated against
xil_sim_libs()
{
  local libs="-L reco -L $UVM_LIB -L xilinx_vip -L xpm" ip
  for ip in ernic vitis_net_p4 cam cam_blk_lib cdcam blk_mem_gen lib_bmg fifo_generator lib_fifo \
            axi_bram_ctrl axi_crossbar axi_data_fifo axi_register_slice axi_infrastructure \
            generic_baseblocks smartconnect axi_protocol_checker; do
    libs+=" -L $(xil_lib $ip)" || return 1
  done
  echo "$libs -L unisims_ver -L unimacro_ver -L secureip"
}

sim_script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
sim_dir=$(dirname $sim_script_dir)
build_dir=${sim_dir}/build
root_dir=$(dirname $sim_dir)
sim_src_dir=${sim_dir}/src

# The simulators run in ${build_dir}/<simulator>: compiled libraries, logs,
# waveforms and the testcase data stay out of sim/scripts
enter_work_dir()
{
  work_dir=${build_dir}/$1
  mkdir -p $work_dir
  cd $work_dir
}

# Questasim main
run_questasim()
{
  if [[ -z "${COMPILED_LIB_DIR:-}" ]]; then
    echo "ERROR: COMPILED_LIB_DIR is not set (Vivado simulation library compiled for Questa)"
    exit 1
  fi
  XIL_LIB_DIR=$COMPILED_LIB_DIR
  UVM_LIB=mtiUvm
  enter_work_dir questasim
  echo "current directory: $(pwd)"

  if [[ ! -d "${build_dir}/questa_lib" ]]; then
    mkdir -p ${build_dir}/questa_lib
  fi

  # library mappings of the precompiled Xilinx libraries
  cp ${COMPILED_LIB_DIR}/modelsim.ini .

  copy_test_data $1
  
  top_module_name="$3"
  top_module_opt="${top_module_name}_opt"

  # Compile
  source ${sim_script_dir}/questasim_compile.do 2>&1 | tee questasim_compile.log

  # Elaborate, reco - RecoNIC work library
  vopt -64 +acc=npr $(xil_sim_libs) -work reco reco.$top_module_name reco.glbl -o $top_module_opt -l questasim_elaborate.log

  # Simulate
  if [[ $2 == "off" ]]; then
    # Batch: no waveform logging, exit when the testbench calls $finish
    vsim -64 -c -onfinish exit -work reco $top_module_opt -do 'run -all; quit -f' -l questasim_simulate.log
  else
    vsim -64 -work reco $top_module_opt -do 'add wave -r /*; run -all' -l questasim_simulate.log
  fi
}

# Vivado xsim main
run_xsim()
{
  XIL_LIB_DIR=$VIVADO_DIR/data/xsim/ip
  UVM_LIB=uvm
  enter_work_dir xsim
  echo "current directory: $(pwd)"
  # library mappings, relative to sim/scripts in xsim.ini
  sed "s|\.\./build|${build_dir}|" ${sim_script_dir}/xsim.ini > xsim.ini
  copy_test_data $1

  top_module_name="$3"
  top_module_opt="${top_module_name}_opt"

  # Compile
  source ${sim_script_dir}/xsim_compile.do 2>&1 | tee xsim_compile.log

  # Elaborate reco
  xelab --incr --relax --debug typical --mt auto $(xil_sim_libs) --snapshot $top_module_opt reco.$top_module_name reco.glbl -log xsim_elaborate.log

  # Simulate
  if [[ $2 == "off" ]]; then
    xsim ${top_module_name}_opt -key {Behavioral:sim_1:Functional:${top_module_name}} -tclbatch ${sim_script_dir}/xsim_tb_top.tcl -log xsim_simulate.log
  else
    xsim -g $top_module_opt -key {Behavioral:sim_1:Functional:${top_module_name}} -tclbatch ${sim_script_dir}/xsim_tb_top.tcl -log xsim_simulate.log
  fi
}

# Copy test data
copy_test_data()
{
  # testcase data, read by the testbenches from the working directory
  rm -f ./*.txt
  if [[ ($1 != "") ]]; then
    test_data_path=${sim_dir}/testcases/"$1"
  fi
  echo "INFO: testcase data path: $test_data_path"
  cp ${test_data_path}/*.txt .
}

clean()
{
  # simulator work directories and the Questa libraries; the IPs and the
  # compute engine sources in ${build_dir} are kept
  rm -rf ${build_dir}/questasim ${build_dir}/xsim ${build_dir}/questa_lib ${build_dir}/xsim.dir
  echo -e "INFO: Simulation files are deleted.\n"
  exit 0
}

# Script usage
usage()
{
  msg="Usage: simulate.sh [-h|--help]\n\
Usage: simulate.sh -top rn_tb_top -g on|off [-t <testcase folder name>] [-s xsim]\n\
[-h|--help]\n\
\t Print help information for this script\n\
[-top top_module]\n\
\t Top module name in testbenches
[-s|--simulator questasim|xsim]\n\
\t Use questa-sim or xsim for simulation. Default is questa-sim\n\
[-t|--testcase <testcase_folder_name>]\n\
\t Testcase folder name\n\
[-g|--gui on|off]\n\
\t Open questasim/xsim in gui or command-line mode\n\
[-c|--clean]\n\
\t Clean build folder\n\n\
Example: ./simulate -t get -s questasim -g on\n"
  echo -e $msg
  exit 1
}

while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
    -h|--help)
      usage
      ;;
    -top)
      top_module=$2
      shift
      shift
      ;;
    -g|--gui)
      gui="$2"
      shift
      shift
      ;;
    -s|--simulatior)
      simulator="$2"
      shift
      shift
      ;;
    -t|--testcase)
      testcase="$2"
      shift
      shift
      ;;
    -c|--clean)
      clean
      shift 
      ;;
    *) # Invalid option
      echo "ERROR: Invalid option"
      usage
      ;;
  esac
done

if [[ $top_module == "" ]]; then
  echo "ERROR: Please provide top module name of the testbenches"
  usage
fi

if [[ $simulator == "questasim" ]]; then
  echo "INFO: Start questasim simulation"
  run_questasim $testcase $gui $top_module
elif [[ $simulator == "xsim" ]]; then
  echo "INFO: Start xsim simulation"
  run_xsim $testcase $gui $top_module
else
  echo "ERROR: Simulator not supported. Please use either questasim or xsim"
  usage
fi