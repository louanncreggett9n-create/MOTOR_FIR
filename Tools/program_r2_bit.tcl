set script_dir [file normalize [file dirname [info script]]]
set r2_dir [file normalize [file join $script_dir ..]]
set bit_path [file join $r2_dir artifacts MOTOR_FIR_unified_classifier_fixed_20261022.bit]
if {![file exists $bit_path]} { error "Missing bit: $bit_path" }
open_hw
connect_hw_server -url localhost:3121
open_hw_target
set dev [lindex [get_hw_devices] 0]
puts "PROGRAM_DEVICE=$dev"
set_property PROGRAM.FILE $bit_path $dev
program_hw_devices $dev
refresh_hw_device -update_hw_probes false $dev
puts "R2_BIT_PROGRAMMED=$bit_path"
close_hw_target
disconnect_hw_server
close_hw
puts "PROGRAM_R2_DONE"