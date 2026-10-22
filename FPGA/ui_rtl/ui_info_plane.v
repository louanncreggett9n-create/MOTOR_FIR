`timescale 1ns / 1ps
// static information page, 100x30 characters
module ui_info_plane(
    input  wire [11:0] addr,
    output wire [7:0]  data
);
    (* ram_style = "distributed" *) reg [7:0] mem [0:2999];
    initial $readmemh("ui_mem/info_plane.mem", mem);
    assign data = mem[addr];
endmodule