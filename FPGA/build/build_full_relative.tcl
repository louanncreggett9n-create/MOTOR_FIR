set script_dir [file normalize [file dirname [info script]]]
set fpga_dir [file normalize [file join $script_dir ..]]
set ipdir [file join $fpga_dir ip]
set newdir [file join $fpga_dir new]
set ui_rtl_dir [file join $fpga_dir ui_rtl]
set ui_mem_dir [file join $fpga_dir ui_mem]
set ui_constr_dir [file join $fpga_dir ui_constr]
set vendor_touch_dir [file join $fpga_dir vendor_touch]
cd $fpga_dir
create_project -in_memory -part xc7a35tfgg484-2
foreach ip {fir_L1 fir_L2 fir_N1 fir_N2 fir_N3 fir_RB fir_ENV sine_wave_rom square_wave_rom triangular_wave_rom} {
    read_ip [file join $ipdir $ip "$ip.xci"]
}
generate_target all [get_ips]
foreach f [glob -nocomplain [file join $newdir *.v]] {
    if {[file tail $f] eq "MOTOR_FIR.v"} { continue }
    read_verilog $f
}
foreach f [glob -nocomplain [file join $newdir scan_b *.v]] { read_verilog $f }
read_verilog [file join $ui_rtl_dir MOTOR_FIR_p3.v]
read_verilog [file join $ui_rtl_dir ui_live_top.v]
read_verilog [file join $ui_rtl_dir ui_font_rom.v]
read_verilog [file join $ui_rtl_dir ui_text_plane.v]
read_verilog [file join $ui_rtl_dir ui_info_plane.v]
read_verilog [file join $ui_rtl_dir ui_num_fmt.v]
read_verilog [file join $ui_rtl_dir gt911_touch_v2.v]
read_verilog [file join $vendor_touch_dir rtl i2c_control.v]
read_verilog [file join $vendor_touch_dir rtl i2c_bit_shift.v]
read_verilog [file join $vendor_touch_dir rtl key_filter.v]
read_verilog [file join $ui_rtl_dir ui_uart_cmd.v]
read_verilog [file join $ui_rtl_dir ui_text_wr.v]
read_verilog [file join $ui_rtl_dir ui_touch_dbg.v]
read_verilog [file join $ui_rtl_dir ui_touch_ctrl.v]
read_verilog [file join $ui_rtl_dir disp_driver.v]
read_xdc [file join $script_dir Top_touch.xdc]
read_xdc [file join $ui_constr_dir ui_p3.xdc]
synth_design -top MOTOR_FIR -part xc7a35tfgg484-2 -include_dirs [list $ui_rtl_dir $newdir] -flatten_hierarchy rebuilt -generic ADC_ENABLE=1
set_clock_groups -asynchronous -group [get_clocks sys_clk] -group [get_clocks clk33]
set_false_path -from [get_clocks sys_clk] -to [get_clocks clk33]
set_false_path -from [get_clocks clk33] -to [get_clocks sys_clk]
opt_design
place_design
route_design
report_utilization -file [file join $script_dir util_bundle.rpt]
report_timing_summary -file [file join $script_dir timing_bundle.rpt]
write_bitstream -force [file join $script_dir MOTOR_FIR_system_touch_rebuilt.bit]
puts "FULL_SOURCE_BUNDLE_BUILD_OK"
