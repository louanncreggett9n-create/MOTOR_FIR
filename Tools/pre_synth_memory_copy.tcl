# Vivado runs project synthesis from the run directory. The UI RTL uses
# $readmemh("ui_mem/...") so make that relative path valid for every clean run.
set project_dir [file normalize [file dirname [info script]]]
set dest [file join [pwd] ui_mem]
file mkdir $dest
foreach name {font8x16.mem info_plane.mem text_plane.mem} {
    file copy -force [file join $project_dir $name] [file join $dest $name]
}
puts "UI_MEMORY_COPIED_TO=[file normalize $dest]"