`timescale 1ns / 1ps
// 100x30 character plane : async read for the renderer, clocked write for the formatter
module ui_text_plane(
    input  wire        clk,
    input  wire [11:0] addr,
    output wire [7:0]  data,
    input  wire        wr_en,
    input  wire [11:0] wr_addr,
    input  wire [7:0]  wr_data
);
    (* ram_style = "distributed" *) reg [7:0] mem [0:2999];
    initial $readmemh("ui_mem/text_plane.mem", mem);
    always @(posedge clk) if (wr_en) mem[wr_addr] <= wr_data;
    assign data = mem[addr];
endmodule