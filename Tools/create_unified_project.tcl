# Rebuild the unified Vivado 2018.3 project from the archived source bundle.
# Usage:
#   vivado -mode batch -source create_unified_project.tcl
#   vivado -mode gui MOTOR_FIR_unified_classifier.xpr

set project_dir [file normalize [file dirname [info script]]]
set summary_root [file normalize [file join $project_dir ..]]
set fpga_dir [file join $summary_root 09_FULL_SOURCE_PROJECTS FPGA]
set classifier_dir [file join $summary_root 03_CLASSIFIER_DEMO]

set new_dir [file join $fpga_dir new]
set scan_dir [file join $new_dir scan_b]
set ui_dir [file join $fpga_dir ui_rtl]
set vendor_dir [file join $fpga_dir vendor_touch rtl]
set ip_dir [file join $fpga_dir ip]
set constr_dir [file join $fpga_dir ui_constr]
set build_dir [file join $fpga_dir build]
set classifier_rtl [file join $classifier_dir rtl]

proc add_group {fileset group files} {
    if {[llength $files] == 0} {
        return
    }
    add_files -fileset $fileset -norecurse $files
}

set proj_name MOTOR_FIR_unified_classifier
create_project -force $proj_name $project_dir -part xc7a35tfgg484-2
create_fileset -srcset reference_1
create_fileset -srcset headers_1
create_fileset -srcset memory_1
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
set_property source_mgmt_mode None [current_project]

# Core RTL. MOTOR_FIR.v is the pre-UI top kept below as a disabled reference;
# MOTOR_FIR_p3.v is the top used by the touch/UI builds.
set core_files {}
foreach f [glob -nocomplain [file join $new_dir *.v]] {
    if {[file tail $f] ne "MOTOR_FIR.v"} {
        lappend core_files $f
    }
}
add_group sources_1 "RTL/01_Core_Logic" $core_files
add_group sources_1 "RTL/02_Scan_B" [glob -nocomplain [file join $scan_dir *.v]]

set touch_files [list \
    [file join $ui_dir gt911_touch_v2.v] \
    [file join $vendor_dir i2c_control.v] \
    [file join $vendor_dir i2c_bit_shift.v] \
    [file join $vendor_dir key_filter.v] \
]
add_group sources_1 "RTL/03_Touch_GT911" $touch_files

set ui_files [list \
    [file join $ui_dir MOTOR_FIR_p3.v] \
    [file join $ui_dir ui_font_rom.v] \
    [file join $ui_dir ui_text_plane.v] \
    [file join $ui_dir ui_info_plane.v] \
    [file join $ui_dir ui_num_fmt.v] \
    [file join $ui_dir ui_uart_cmd.v] \
    [file join $ui_dir ui_text_wr.v] \
    [file join $ui_dir ui_touch_dbg.v] \
    [file join $ui_dir ui_touch_ctrl.v] \
    [file join $ui_dir disp_driver.v] \
]
add_group sources_1 "RTL/04_UI_Active" $ui_files

set classifier_files [list \
    [file join $classifier_rtl ui_live_top_classifier.v] \
    [file join $classifier_rtl damage_classifier_l1.v] \
]
add_group sources_1 "RTL/05_Classifier_Active" $classifier_files

set optional_files [list \
    [file join $ui_dir gt911_touch.v] \
    [file join $ui_dir touch_pin_test.v] \
]
add_group sources_1 "RTL/06_Optional_Modules" $optional_files

# These two modules have the same names as the active top modules. They remain
# visible in the separate reference_1 fileset and are not part of synth_1.
set reference_files [list \
    [file join $new_dir MOTOR_FIR.v] \
    [file join $ui_dir ui_live_top.v] \
]
add_group reference_1 "Reference_Not_Synthesized" $reference_files

# disp_parameter_cfg.v is included by disp_driver.v; compiling it also as a
# top-level source would duplicate its definitions.
set included_verilog [file join $ui_dir disp_parameter_cfg.v]
add_group headers_1 "Verilog_Includes_And_Headers" [list $included_verilog [file join $new_dir fir_coefficients.vh] [file join $classifier_rtl classifier_templates_16band.vh]]

set memory_files [list \
    [file join $new_dir fir_coefficients.coe] \
    [file join $project_dir font8x16.mem] \
    [file join $project_dir info_plane.mem] \
    [file join $project_dir text_plane.mem] \
]
set memory_files [concat $memory_files [glob -nocomplain [file join $summary_root vivado_out3.0 fir_compiler *.coe]]]
set memory_files [concat $memory_files [glob -nocomplain [file join $summary_root *wave.coe]]]
add_group memory_1 "Memory_Init" $memory_files

# All ten custom/configured IP cores.
set ip_files [glob -nocomplain [file join $ip_dir * *.xci]]
add_group sources_1 "IP_All_10" $ip_files
# Use the original per-filter COE files copied into vivado_out3.0/fir_compiler.
# Each FIR must keep its own coefficients; a shared vector breaks L1/L2 and SCAN.
foreach fir_ip {fir_L1 fir_L2 fir_N1 fir_N2 fir_N3 fir_RB fir_ENV} {
    set_property CONFIG.CoefficientSource {COE_File} [get_ips $fir_ip]
}
# Synthesize IP in context. This keeps the project portable and avoids an OOC
# DCP launch step that depends on Windows Script Host.
foreach ip [get_ips] {
    set ip_name [get_property name $ip]
    set_property GENERATE_SYNTH_CHECKPOINT false [get_files "$ip_name.xci"]
}

add_group constrs_1 "Constraints/Board" [list [file join $build_dir Top_touch.xdc]]
add_group constrs_1 "Constraints/UI" [list [file join $constr_dir ui_p3.xdc] [file join $project_dir unified_clock_groups.xdc]]

add_group sim_1 "Simulation/Classifier" [list \
    [file join $classifier_rtl tb_damage_classifier_l1.v] \
    [file join $project_dir classifier_test_vectors.mem] \
]

set_property top MOTOR_FIR [get_filesets sources_1]
set_property top tb_damage_classifier_l1 [get_filesets sim_1]
set_property include_dirs [list $ui_dir $classifier_rtl $new_dir] [get_filesets sources_1]
set_property include_dirs [list $ui_dir $classifier_rtl $new_dir] [get_filesets sim_1]

# The project's default flow is the complete classifier/UI system.
set_property generic {ADC_ENABLE=1} [get_filesets sources_1]
set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY rebuilt [get_runs synth_1]
add_files -fileset utils_1 -norecurse [file join $project_dir pre_synth_memory_copy.tcl]
set_property STEPS.SYNTH_DESIGN.TCL.PRE [file join $project_dir pre_synth_memory_copy.tcl] [get_runs synth_1]
catch {set_property STEPS.SYNTH_DESIGN.ARGS.INCLUDE_DIRS [list $ui_dir $classifier_rtl $new_dir] [get_runs synth_1]}
catch {set_property STEPS.SYNTH_DESIGN.ARGS.GENERIC {ADC_ENABLE=1} [get_runs synth_1]}

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "UNIFIED_PROJECT_CREATED=[file join $project_dir $proj_name.xpr]"
puts "TOP=[get_property top [get_filesets sources_1]]"
puts "SOURCE_FILES=[llength [get_files -of_objects [get_filesets sources_1]]]"
puts "IP_COUNT=[llength [get_ips]]"
close_project