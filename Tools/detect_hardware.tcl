open_hw
connect_hw_server -url localhost:3121
open_hw_target
set devs [get_hw_devices]
puts "HW_DEVICE_COUNT=[llength $devs]"
foreach d $devs { puts "HW_DEVICE=$d PART=[get_property PART $d]" }
close_hw_target
disconnect_hw_server
close_hw
puts "HW_DETECT_DONE"