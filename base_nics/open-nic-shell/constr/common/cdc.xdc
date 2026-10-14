# Vivado translation of the cdc_fifo_gray constraints documented in
# src/box_250mhz/reconic/dpa/common_cells/cdc_fifo_gray.sv:
#   max delay = min(T_src, T_dst) through the async_* ports,
#   no hold check (-datapath_only).
# cdc_fifo_gray_src/_dst are also instantiated directly (e.g. axi_cdc splits
# them across axi_cdc_src/axi_cdc_dst), so every crossing is found from the
# src half. Requires keep_hierarchy on cdc_fifo_gray_src/_dst (set in RTL).
foreach src [get_cells -quiet -hier -filter {ORIG_REF_NAME == cdc_fifo_gray_src || REF_NAME == cdc_fifo_gray_src}] {
    set fwd_pins [get_pins -quiet "$src/async_data_o[*] $src/async_wptr_o[*]"]
    set bwd_pins [get_pins -quiet "$src/async_rptr_i[*]"]
    set src_clk [get_clocks -quiet -of_objects [get_pins $src/src_clk_i]]
    set dst_clk [get_clocks -quiet -of_objects [all_fanin -quiet -flat -startpoints_only $bwd_pins]]
    if {![llength $src_clk] || ![llength $dst_clk] || ![llength $fwd_pins]} {
        puts "WARNING: cdc.xdc: skipping $src (src_clk={$src_clk} dst_clk={$dst_clk})"
        continue
    }
    set t [expr {min([get_property PERIOD $src_clk], [get_property PERIOD $dst_clk])}]
    set_max_delay -datapath_only $t -from $src_clk -through $fwd_pins
    set_max_delay -datapath_only $t -from $dst_clk -through $bwd_pins
}
