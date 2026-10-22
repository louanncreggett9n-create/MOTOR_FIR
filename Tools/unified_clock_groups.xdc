# sys_clk and the 33 MHz display clock are asynchronous.
set_clock_groups -asynchronous -group [get_clocks sys_clk] -group [get_clocks clk33]
set_false_path -from [get_clocks sys_clk] -to [get_clocks clk33]
set_false_path -from [get_clocks clk33] -to [get_clocks sys_clk]