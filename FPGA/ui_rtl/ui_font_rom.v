`timescale 1ns / 1ps
module ui_font_rom(
    input  wire [9:0] addr,
    output wire [7:0] data
);
    (* ram_style = "distributed" *) reg [7:0] rom [0:1023];
    initial $readmemh("ui_mem/font8x16.mem", rom);
    assign data = rom[addr];
endmodule