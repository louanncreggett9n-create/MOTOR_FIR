open_project [file join [pwd] MOTOR_FIR_unified_classifier.xpr]
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 2
wait_on_run impl_1
set st [get_property STATUS [get_runs impl_1]]
puts "IMPL_STATUS=$st"
if {![string match "*Complete*" $st]} { puts "IMPL_FAILED=$st"; exit 1 }
open_run impl_1 -name impl_1
report_timing_summary -file [file join [pwd] unified_impl_timing.rpt]
report_utilization -file [file join [pwd] unified_impl_utilization.rpt]
set bit [file join [pwd] MOTOR_FIR_unified_classifier.runs impl_1 MOTOR_FIR.bit]
puts "BIT_PATH=$bit"
puts "BIT_EXISTS=[file exists $bit]"
puts "UNIFIED_IMPL_BIT_OK"
close_project