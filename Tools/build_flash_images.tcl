set script_dir [file normalize [file dirname [info script]]]
set r2_dir [file normalize [file join $script_dir ..]]
set project_dir [file normalize [file join $r2_dir .. 10_VIVADO_UNIFIED_PROJECT]]
set project_path [file join $project_dir MOTOR_FIR_unified_classifier.xpr]
set artifact_dir [file join $r2_dir artifacts]
set bit_path [file join $artifact_dir MOTOR_FIR_unified_classifier_fixed_20261022_spix4.bit]
set mcs_path [file join $artifact_dir MOTOR_FIR_unified_classifier_fixed_20261022_spix4.mcs]
set bin_path [file join $artifact_dir MOTOR_FIR_unified_classifier_fixed_20261022_spix4.bin]
open_project $project_path
open_run impl_1 -name impl_1
set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
write_bitstream -force $bit_path
write_cfgmem -force -format MCS -interface SPIX4 -size 16 -loadbit "up 0x00000000 $bit_path" $mcs_path
write_cfgmem -force -format BIN -interface SPIX4 -size 16 -loadbit "up 0x00000000 $bit_path" $bin_path
puts "SPIX4_BIT=$bit_path"
puts "MCS=$mcs_path"
puts "BIN=$bin_path"
puts "FLASH_IMAGE_BUILD_OK"
close_project