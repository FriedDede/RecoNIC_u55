# RecoNIC - <ins>R</ins>DMA-<ins>e</ins>nabled <ins>C</ins>ompute <ins>O</ins>ffloading on Smart<ins>NIC</ins>

To meet the explosive growth of data and scale-out workloads/applications, today's data centers comprise sea of network connected hosts, each with multi-core CPUs and accelerators in the form of ASICs, FPGAs, and/or GPUs. The interaction between these hosts takes place through network interface cards (NICs) operating at speeds of 40Gbps or higher. Such data center architecture provides an ideal environment for distributed applications. When computation tasks are offloaded to accelerators, data received from remote application components through the network is first stored in the host’s memory and then copied to the memory of accelerators via the PCIe bus. Once computation tasks are completed, results destined for remote peers are often copied back to the host’s memory. This CPU-centric solution introduces multiple data copies, leading to a notable decrease in overall performance and increased latency.

To address these challenges, we propose RecoNIC, an RDMA-enabled SmartNIC platform with compute acceleration, designed to minimize the overhead associated with data copies and to bring data as close to computation as feasible. The platform consists of a hardware shell and software stacks. The hardware shell of RecoNIC encompasses basic NIC functionalities, an RDMA engine, and two programmable compute logic modules for lookaside and streaming computations, respectively. Developers have the flexibility to design their accelerators using RTL, HLS or Vitis Networking P4 within the RecoNIC's programmable compute logic modules. This allows for the processing of network data without resorting to the multiple copies’ characteristic of traditional CPU-centric solutions. The logic executed within these programmable modules can access both RecoNIC and host memory in remote peers via RDMA.

For more information, please refer to the [RecoNIC primer](https://arxiv.org/abs/2312.06207).

## RecoNIC System Overview

<img src="doc/image/RecoNIC.png">

The above figure shows the hardware shell architecture and software stacks of RecoNIC. The hardware shell consists of a basic NIC module (including a MAC subsystem and DMA subsystem - QDMA), a packet classification module, an RDMA engine, two programmable compute logic modules (Lookaside Compute and Streaming Compute), along with supplementary modules such as system/memory crossbars and an arbiter.

The RDMA engine is responsible for processing RDMA traffic, allowing payload data from the network to be stored in either the host's memory or the RecoNIC device's memory. User defined accelerators implemented in the Streaming Compute and Lookaside Compute modules can directly process data, including network-received data, within the device memory.

The software encompasses the network stack, consisting of RDMA APIs and network driver to handle non-RDMA traffic (such as TCP/IP, UDP/IP, and ARP). Additionally, the memory driver facilitates seamless memory transfers between the host and RecoNIC memory. Finally, the control driver serves to configure and control various components in the hardware shell.

## Repository Layout

```
hw/
  open-nic-shell/    OpenNIC shell (QDMA, CMAC, RDMA subsystem, HBM) and its build script
  reconic/           RecoNIC shell, plugged into open-nic-shell as its box_250mhz module
    plugs/rdma_onic_plugin/   box_250mhz top, address map, IP scripts, build.tcl
    top/                      reconic.sv
    packet_classification/    P4 packet parser and classifier
    compute/lookside/         lookaside compute logic (HLS systolic-array MM)
    compute/dpa/              RISC-V compute engine (Snitch cluster) and its bootrom
    utilities/
sw/
  onic-driver/       kernel driver (network + device memory access)
  regression/        datapath regression tests on the real card
  lib/               libreconic user-space library
examples/             RDMA, DMA and matrix-multiply applications
scripts/              hardware build, MCS generation and FPGA programming (Makefile)
sim/                  simulation framework (Makefile, testbenches, testcases)
doc/                  address map and figures
build/                hardware build output (generated)
```

Sources are used in place: the hardware build reads `hw/open-nic-shell` and
`hw/reconic` directly, nothing is copied or patched.

## System Requirement

* Two servers, each with an AMD Alveo U55C board
* The two boards connected through a 100 Gbps cable or a 100 Gbps switch

## Prerequisites

* Vivado 2024.2, installed with the Vitis Networking P4 option. To make the
  option visible, run `export VitisNetP4_Option_VISIBLE=true` before starting
  the installer.
* ERNIC license. You can purchase it or apply for it through the
  [AMD University Program](https://www.xilinx.com/support/university.html); see
  the [AMD ERNIC](https://www.xilinx.com/products/intellectual-property/ef-di-ernic.html) page.
* Python >= 3.8 with `scapy` and `numpy` (simulation stimulus generation)
* Questa 2023.4 and a Vivado 2024.2 simulation library compiled for it
  (optional, for simulation with Questa)
* A RISC-V toolchain (`riscv64-unknown-elf-`), only to rebuild a compute engine bootrom
* netplan, to configure static IPs for RecoNIC
* Doxygen, to generate the library documentation

## Hardware Generation and Programming

The build is driven by [scripts/Makefile](scripts/Makefile); see
[scripts/README.md](scripts/README.md) for all targets and variables. Vivado
must be on your `PATH`.

* Generate the bitstream
```
$ cd scripts
$ make build_nic
```
The Vivado project is created under `build/au55c/open_nic_shell`, and the
bitstream and debug probes are copied to `build/au55c/bitstream/`. Add
`OVERWRITE=1` to regenerate all IPs, or `BOOTROM_DIR=<dir>` to compile another
`bootrom.sv` into the RISC-V compute engine (default:
`hw/reconic/compute/dpa/bootrom_u55`).

* Program the FPGA

`TARGET_ID` is the hardware target name shown by Vivado under *Hardware
Manager → Open New Target* (for example `21770297400LA`).
```
# Volatile: load the bitstream over JTAG (lost on cold reboot)
$ make program_fpga_bit TARGET_ID=<id>

# Persistent: write the configuration flash, then cold-reboot the host
$ make mcs
$ make program_fpga_mcs TARGET_ID=<id>
```
Add `REMOTE_HOST=<host>` if the JTAG cable is attached to another machine
running `hw_server`.

After programming, check that the board is up
```
$ lspci | grep Xilinx
d8:00.0 Memory controller: Xilinx Corporation Device 903f
```
The PCIe BDF (Bus, Device, Function) number and device ID might be different depending on your system.

## Driver Installation

* Build and load the onic driver
```
$ cd sw/onic-driver
$ make
$ sudo insmod onic.ko
```

* Get MAC address and ethernet interface name assigned by the driver
```
$ dmesg | grep "Set MAC address to"
onic 0000:d8:00.0 onic216s0f0 (uninitialized): Set MAC address to 0:a:35:29:33:0
```

In this example, the new MAC address is [0x00, 0x0a, 0x35, 0x29, 0x33, 0x00], while the ethernet interface name assigned is 'onic216s0f0'. It is possible that the ethernet interface, 'onic216s0f0', might be renamed by the operating system. You can check with the following commands.
```
$ dmesg | grep "renamed from"
[  146.932392] onic 0000:d8:00.0 ens8: renamed from onic216s0f0
```
In this case, the ethernet interface is renamed as "ens8" from "onic216s0f0".

* Set IP addresses for the two peers

We can set the IP addresses either via a netplan configuration file or *ifconfig*. Assuming the ethernet interface name is "onic216s0f0".

&emsp;&emsp;**1. Using *netplan* to set IPs**

You need to create a configuration file, onic216s0f0.yaml, at "/etc/netplan/" and copy the below code snippet in this file.

&emsp;&emsp;&emsp;**Peer 1**
```
network:
  version: 2
  renderer: networkd
  ethernets:
    onic216s0f0:
      dhcp4: no
      dhcp6: no
      addresses: [192.100.51.1/16]
```
&emsp;&emsp;&emsp;**Peer 2**
```
network:
  version: 2
  renderer: networkd
  ethernets:
    onic216s0f0:
      dhcp4: no
      dhcp6: no
      addresses: [192.100.52.1/16]
```

Once done, you need to enable the configuration by "sudo netplan apply" or simply do warm reboot for your system.

&emsp;&emsp;**2. Using *ifconfig* to set IPs**

&emsp;&emsp;&emsp;**Peer 1**
```
$ sudo ifconfig onic216s0f0 192.100.51.1 netmask 255.255.0.0 broadcast 192.100.255.255
```
&emsp;&emsp;&emsp;**Peer 2**
```
$ sudo ifconfig onic216s0f0 192.100.52.1 netmask 255.255.0.0 broadcast 192.100.255.255
```

* Test network connectivity

&emsp;&emsp;**Peer 1**
```
$ ping 192.100.52.1
PING 192.100.52.1 (192.100.52.1) 56(84) bytes of data.
64 bytes from 192.100.52.1: icmp_seq=1 ttl=64 time=0.188 ms
64 bytes from 192.100.52.1: icmp_seq=2 ttl=64 time=0.194 ms
64 bytes from 192.100.52.1: icmp_seq=3 ttl=64 time=0.222 ms
```

&emsp;&emsp;**Peer 2**
```
$ ping 192.100.51.1
PING 192.100.51.1 (192.100.51.1) 56(84) bytes of data.
64 bytes from 192.100.51.1: icmp_seq=1 ttl=64 time=0.248 ms
64 bytes from 192.100.51.1: icmp_seq=2 ttl=64 time=0.174 ms
64 bytes from 192.100.51.1: icmp_seq=3 ttl=64 time=0.201 ms
```

If everything works fine, it should return similar output from your terminals. After verifying, you can stop *ping*. The system is now up.

To check the datapath (ICMP, UDP and TCP, with every byte verified) after a
change to the shell, the P4 classifier or the driver, use the regression tests
in [sw/regression](sw/regression/README.md).

## RecoNIC user-space library
RecoNIC user-space library (green boxes shown in the above RecoNIC system overview figure) contains all necessary APIs for RDMA, memory and control operations. To obtain the document for source codes, you can simply run with
```
$ cd ./sw/lib
$ doxygen
```
The source code documents will be generated at ./sw/lib/html.

Before we run test cases and applications, we need to build the libreconic library.
```
$ make
$ export LD_LIBRARY_PATH=/your/path/to/RecoNIC/sw/lib:$LD_LIBRARY_PATH
```
The generated static, *libreconic.a*, and shared library, *libreconic.so*, are located at ./sw/lib folder. We are ready to play test cases and applications.

## RDMA Test Cases
The *rdma_test* folder contains RDMA read, write and send/receive test cases using libreconic.

Build RDMA read, write and send/recv program.
```
$ cd examples/rdma_test
$ make
```

### RDMA Read
RDMA Read operation: The client node issues RDMA read request to the server node first. The server node then replies with the RDMA read response packet.
```
$ ./read -h
  usage: ./read [OPTIONS]

    -d (--device) character device name (defaults to /dev/reconic-mm)
    -p (--pcie_resource) PCIe resource
    -r (--src_ip) Source IP address
    -i (--dst_ip) Destination IP address
    -u (--udp_sport) UDP source port
    -t (--tcp_sport) TCP source port
    -q (--dst_qp) Destination QP number
    -z (--payload_size) Payload size in bytes
    -l (--qp_location) QP/mem-registered buffers' location: [host_mem | dev_mem]
    -s (--server) Server node
    -c (--client) Client node
    -g (--debug) Debug mode
    -h (--help) print usage help and exit 
```

#### On the client node (192.100.51.1)
Run the program
```
sudo ./read -r 192.100.51.1 -i 192.100.52.1 -p /sys/bus/pci/devices/0000\:d8\:00.0/resource2 -z 128 -l host_mem -d /dev/reconic-mm -c -u 22222 -t 11111 --dst_qp 2 -g 2>&1 | tee client_debug.log
```

#### On the server node (192.100.52.1)
Run the program
```
sudo ./read -r 192.100.52.1 -i 192.100.51.1 -p /sys/bus/pci/devices/0000\:d8\:00.0/resource2 -z 128 -l host_mem -d /dev/reconic-mm -s -u 22222 -t 11111 --dst_qp 2 -g 2>&1 | tee server_debug.log
```

If the program exits with an error saying libreconic.so is not found, you can try with "sudo env LD_LIBRARY_PATH=$LD_LIBRARY_PATH ./read", instead of "sudo ./read".

The above example allocates the QP (SQ, CQ and RQ) in the host memory. If you want the QP to be allocated in the host memory, you can simply replace "-l host_mem" with "-l dev_mem" on both receiver and sender nodes.

### RDMA Write
RDMA Write operation: The client node issues RDMA write request to the server node directly. Usage of the RDMA write program is the same with RDMA read program above.

#### On the client node (192.100.51.1)
Run the program
```
sudo ./write -r 192.100.51.1 -i 192.100.52.1 -p /sys/bus/pci/devices/0000\:d8\:00.0/resource2 -z 128 -l host_mem -d /dev/reconic-mm -c -u 22222 -t 11111 --dst_qp 2 -g 2>&1 | tee client_debug.log
```

#### On the server node (192.100.52.1)
Run the program
```
sudo ./write -r 192.100.52.1 -i 192.100.51.1 -p /sys/bus/pci/devices/0000\:d8\:00.0/resource2 -z 128 -l host_mem -d /dev/reconic-mm -s -u 22222 -t 11111 --dst_qp 2 -g 2>&1 | tee server_debug.log
```

If the program exits with an error saying libreconic.so is not found, you can try with "sudo env LD_LIBRARY_PATH=$LD_LIBRARY_PATH ./write", instead of "sudo ./write".

The above example allocates the QP (SQ, CQ and RQ) in the host memory. You can allocate QPs on device memory as well by using "-l dev_mem" on both receiver and sender nodes.

### RDMA Send/Receive
RDMA send/recv operation: The server node posts an RDMA receive request, waiting for a RDMA send request to its allocated receive queue. The client node then issues an RDMA send request to the server node. Usage of the RDMA send/receive program is the same iwth RDMA read program above.

#### On the receiver node (192.100.51.1)
Run the program in the receiver mode
```
sudo ./send_recv -r 192.100.51.1 -i 192.100.52.1 -p /sys/bus/pci/devices/0000\:d8\:00.0/resource2 -z 128 -l host_mem -d /dev/reconic-mm -c -u 22222 --dst_qp 2 -g 2>&1 | tee client_debug.log
```

#### On the sender node (192.100.52.1)
Run the program in the sender mode
```
sudo ./send_recv -r 192.100.52.1 -i 192.100.51.1 -p /sys/bus/pci/devices/0000\:d8\:00.0/resource2 -z 16384 -l dev_mem -d /dev/reconic-mm -s -u 22222 --dst_qp 2 -g 2>&1 | tee server_debug.log
```

If the program exits with an error saying libreconic.so is not found, you can try with "sudo env LD_LIBRARY_PATH=$LD_LIBRARY_PATH ./send_recv", instead of "sudo ./send_recv".

The above example allocates the QP (SQ, CQ and RQ) in the host memory. You can allocate QPs on device memory as well by using "-l dev_mem" on both receiver and sender nodes.

## Applications

### Built-in example - network systolic-array matrix multiplication

In the current implementation, we have [matrix multiplication](examples/network_systolic_mm) as an example to demonstrate how to use RecoNIC. In this example, array A and B are stored in the host memory of the remote peer, and the computation is done in the local peer. 

**Execution flow**: The local host first issues two RDMA read requests to the remote peer for acquiring array A and B and store it in the device memory. Once detecting the readiness of the two arrays, the local host issues a compute control command to the Compute Logic to start computation. Once the computation is finished, the host reads the result back to the host memory for verification.

The [hardware implementation](hw/reconic/compute/lookside) of the MM computation is a systolic-array version and written in HLS C from the [Vitis_Accel_Examples](https://github.com/Xilinx/Vitis_Accel_Examples/blob/master/cpp_kernels/systolic_array/src/mmult.cpp).

Data (Array A and B) is stored in a server node (Peer 1), while computation is executed in a client node (Peer 2).

Before we run the example, we need to configure hugepages in both servers.
```
# 1. Edit /etc/sysctl.conf file and configure number of hugepages by setting 'vm.nr_hugepages'. Each 
#    hugepage will have 2MB size
$ vm.nr_hugepages = 2048
# 2. Refresh the kernel parameters
$ sudo sysctl -p
```
Compilation
```
$ cd examples/network_systolic_mm
$ make
$ ./network_systolic_mm -h
usage: ./network_systolic_mm [OPTIONS]

  -d (--device) character device name (defaults to /dev/reconic-mm)
  -p (--pcie_resource) PCIe resource
  -r (--src_ip) Source IP address
  -i (--dst_ip) Destination IP address
  -u (--udp_sport) UDP source port
  -t (--tcp_sport) TCP source port
  -q (--dst_qp) Destination QP number
  -s (--server) Server node
  -c (--client) Client node
  -h (--help) print usage help and exit

```

**Peer 1** - Server (192.100.51.1)
```
$ sudo ./network_systolic_mm -d /dev/reconic-mm -p /sys/bus/pci/devices/0000\:d8\:00.0/resource2 -r 192.100.51.1 -i 192.100.52.1 -u 22222 -t 11111 --dst_qp 2 -s 2>&1 | tee server_debug.log
```

**Peer 2** - Client (192.100.52.1)
```
$ cd examples/network_systolic_mm
$ make
$ sudo ./network_systolic_mm -d /dev/reconic-mm -p /sys/bus/pci/devices/0000\:d8\:00.0/resource2 -r 192.100.52.1 -i 192.100.51.1 -u 22222 -t 11111 --dst_qp 2 -c 2>&1 | tee client_debug.log
```

## Performance Evaluation

### DMA testing

The [dma_test](examples/dma_test) folder is used to test data copy functionality between host and device's memory. It supports both read and write from/to the NIC's memory. In this example, the host acts as a master.

```
$ cd examples/dma_test
$ make
$ ./dma_test -help
usage: ./dma_test [OPTIONS]

  -d (--device) device
  -a (--address) the start address on the AXI bus
  -s (--size) size of a single transfer in bytes, default 32,
  -o (--offset) page offset of transfer
  -c (--count) number of transfers, default 1
  -f (--data infile) filename to read the data from (ignored for read scenario)
  -w (--data outfile) filename to write the data of the transfers
  -h (--help) print usage help and exit
  -v (--verbose) verbose output
  -r (--read) use read scenario (write scenario without this flag)
```

* dma_test write
```
$ ./dma_test -d /dev/reconic-mm -s 65536000 -c 200
```

* dma_test read
```
$ ./dma_test -d /dev/reconic-mm -s 65536000 -c 200 -r
```

* PCIe bandwidth measurement for data copy

Before measuring the bandwidth, we need to determine which CPU core is bound to the specific PCIe slot used for RecoNIC. To do so, we need to find the NUMA node bound to the PCIe slot. It's fine if you measure bandwidth without setting the CPU affinity. This might end up with lower performance if the system schedules other NUMA node that's not bound to the corresponding PCIe slot.

```
$ lspci | grep Xilinx
d8:00.0 Memory controller: Xilinx Corporation Device 903f
$ sudo lspci -vv -s d8:00.0 | grep 'NUMA node'
        NUMA node: 1
$ cat /sys/devices/system/node/node1/cpulist
1,3,5,7,9,11,13,15
```

Now, we are ready to test the bandwidth
```
$ taskset -c 1,3,5,7 ./measure_dma.sh /dev/reconic-mm 4 write 65536000

Number of dma_test (write) threads: 4
Calculate total write bandwidth achieved:
-- The total write bandwidth is: 13.065046 GB/sec

$ taskset -c 1,3,5,7 ./measure_dma.sh /dev/reconic-mm 4 read 65536000

Number of dma_test (read) threads: 4
Calculate total read bandwidth achieved:
-- The total read bandwidth is: 12.998869 GB/sec

```

## Hardware Simulation

The simulation framework supports self-testing and regression testing.
Stimulus, control metadata and golden data are generated by a Python script,
*packet_gen.py*, from a JSON description of each testcase under
[sim/testcases](sim/testcases). The testbenches read the generated files, drive
packets as AXI-Stream traffic plus the control signals, and check the results
against the golden data. Both xsim and Questa are supported. Everything is
driven by [sim/Makefile](sim/Makefile).

The simulation uses the same RTL as the hardware build; the RISC-V compute
engine file list is generated from the plugin's
[build.tcl](hw/reconic/plugs/rdma_onic_plugin/build.tcl), so the two stay in
sync.

1. Prepare the simulation

```
$ cd sim
$ make prepare_sim
```
This generates the Vivado IPs under `sim/build/ip`, generates the compute
engine file lists and checks the Python packages. The IPs are regenerated only
when one of their scripts or the P4 program changes; add `OVERWRITE=1` to force
it. `VIVADO_DIR` defaults to the Vivado found in your `PATH`.

2. Run a testcase

```
# xsim
$ make sim TC=write
# Questa
$ export COMPILED_LIB_DIR=/your/vivado/compiled_lib_dir/for/questasim
$ make sim TC=write SIM=questasim
# GUI
$ make sim TC=read_2rdma SIM=questasim GUI=1
# every testcase under sim/testcases
$ make regression SIM=questasim
```
A passing testcase ends with `SUCCESS - Simulation is passed!` in the
simulator log under `sim/scripts`. `ROCE=0` generates a plain Ethernet
configuration instead of an RDMA one. `make clean` deletes the simulation
outputs, and `make distclean` also deletes the generated IPs.

`COMPILED_LIB_DIR` points to the output of Vivado's `compile_simlib` for
Questa; see [this article](https://support.xilinx.com/s/article/64083?language=en_US)
if you need to build it.

> **Note:** the RDMA testcases currently run correctly in Questa only. In xsim
> they compile and elaborate, but the simulation stops making progress after
> RDMA configuration.

The Makefile calls *run_testcase.py*, which can also be used directly from `sim`:
```
$ python run_testcase.py -h
INFO:run_testcase:Usage:
INFO:run_testcase:  python run_testcase.py [options] regression,
INFO:run_testcase:  python run_testcase.py [options] -tc "testcase1 testcase2 ... testcasek"
INFO:run_testcase:Options:
INFO:run_testcase:  -debug     : Debug mode
INFO:run_testcase:  -questasim : Use Questa Sim as the simulator. Default is Vivado XSIM
INFO:run_testcase:  -roce      : Generate configuration files for RDMA simulation
INFO:run_testcase:  -no_pktgen : Run testcases without re-generating packets
INFO:run_testcase:  -no_sim    : Only run analysis on the previous simulation results
INFO:run_testcase:  -gui       : Use gui mode with the simulator
```

You can write your own configuration file to construct a new testcase. The configuration file is in the form of 'json'. Here is an example for generating configuration files for RDMA read operations
```
{
  "top_module"            : "rn_tb_2rdma_top",
  "pkt_type"              : "rocev2",
  "pkt_op"                : "read",
  "non_roce_traffic"      : "no",
  "noise_roce_en"         : "no",
  "payload_size"          : 64,
  "src_baseaddr_location" :"dev_mem",
  "src_baseaddr"          : 2048,
  "dst_baseaddr"          : 1024,
  "num_data_buffer"       : 4,
  "mr_buf_size"           : 32768,
  "data_buffer_size"      : 4096,
  "num_qp"                : 4,
  "udp_sport"             : 17185,
  "destination_qpid"      : 2,
  "sq_depth"              : 4,
  "rq_depth"              : 4,
  "mtu_size"              : 4096,
  "rq_buffer_size"        : 2048,
  "partition_key"         : 4660,
  "r_key"                 : 22,
  "sq_psn"                : 10
}
```
"src_baseaddr_location" is used to specify the source buffer location either at host memory ("sys_mem") or device memory ("dev_mem").

The testbenches are in [sim/src](sim/src). IP scripts used only by the
simulation are in [sim/tcl](sim/tcl); the others are shared with the hardware
build.

## Citation

If you use RecoNIC in your research and projects, please cite
```
@misc{zhong2023primer,
      title={A Primer on RecoNIC: RDMA-enabled Compute Offloading on SmartNIC}, 
      author={Guanwen Zhong and Aditya Kolekar and Burin Amornpaisannon and Inho Choi and Haris Javaid and Mario Baldi},
      year={2023},
      eprint={2312.06207},
      archivePrefix={arXiv},
      primaryClass={cs.DC}
}
```

If you find this project helpful, please consider giving it a star! Your support is greatly appreciated.⭐

-----

<p align="center">Copyright&copy; 2021-2023 Advanced Micro Devices, Inc.</p>
