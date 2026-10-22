set project_path [file join [pwd] MOTOR_FIR_unified_classifier.xpr]
if {![file exists $project_path]} { error "Project not found: $project_path" }
open_project $project_path

set top_name [get_property top [get_filesets sources_1]]
set generic_value [get_property generic [get_filesets sources_1]]
set include_dirs [get_property include_dirs [get_filesets sources_1]]
set ip_count [llength [get_ips]]
set missing [get_files -all -quiet -filter {IS_AVAILABLE == 0}]
set ref_count [llength [get_files -of_objects [get_filesets reference_1]]]
set header_count [llength [get_files -of_objects [get_filesets headers_1]]]
set memory_count [llength [get_files -of_objects [get_filesets memory_1]]]
set constraint_count [llength [get_files -of_objects [get_filesets constrs_1]]]
set sim_top [get_property top [get_filesets sim_1]]
set synth_status [get_property STATUS [get_runs synth_1]]
set impl_status [get_property STATUS [get_runs impl_1]]

puts "PROJECT=$project_path"
puts "TOP=$top_name"
puts "GENERIC=$generic_value"
puts "INCLUDE_DIRS=$include_dirs"
puts "IP_COUNT=$ip_count"
puts "REFERENCE_COUNT=$ref_count"
puts "HEADER_COUNT=$header_count"
puts "MEMORY_COUNT=$memory_count"
puts "CONSTRAINT_COUNT=$constraint_count"
puts "SIM_TOP=$sim_top"
puts "SYNTH_STATUS=$synth_status"
puts "IMPL_STATUS=$impl_status"
puts "MISSING_FILE_COUNT=[llength $missing]"

foreach n {fir_L1 fir_L2 fir_N1 fir_N2 fir_N3 fir_RB fir_ENV} {
    set ip [get_ips $n]
    set source [get_property CONFIG.CoefficientSource $ip]
    set coeff_rel [get_property CONFIG.Coefficient_File $ip]
    set xci [get_files "$n.xci"]
    set coeff_file [file normalize [file join [file dirname $xci] $coeff_rel]]
    puts "FIR=$n SOURCE=$source COE=$coeff_file EXISTS=[file exists $coeff_file]"
    if {$source ne "COE_File"} { error "$n must use COE_File" }
    if {![file exists $coeff_file]} { error "Missing coefficient file for $n: $coeff_file" }
}
foreach ip [get_ips] { puts "IP=[get_property name $ip]" }
foreach f $missing { puts "MISSING=$f" }

if {$top_name ne "MOTOR_FIR"} { error "Unexpected top: $top_name" }
if {$generic_value ne "ADC_ENABLE=1"} { error "Unexpected generic: $generic_value" }
if {$ip_count != 10} { error "Expected 10 IPs, got $ip_count" }
if {[llength $missing] != 0} { error "Project has missing files" }
if {$ref_count != 2} { error "Expected 2 reference files, got $ref_count" }
if {$header_count != 3} { error "Expected 3 header/include files, got $header_count" }
if {$memory_count != 14} { error "Expected 14 memory files, got $memory_count" }
if {$constraint_count != 3} { error "Expected 3 constraints, got $constraint_count" }
if {$sim_top ne "tb_damage_classifier_l1"} { error "Unexpected sim top: $sim_top" }
if {![string match "*Complete*" $synth_status]} { error "Synthesis run is not complete: $synth_status" }
if {![string match "*Complete*" $impl_status]} { error "Implementation run is not complete: $impl_status" }

puts "UNIFIED_PROJECT_VERIFY_OK"
close_project