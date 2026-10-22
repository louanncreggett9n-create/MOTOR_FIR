`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: block_ram_512x16
// Description:
//     Single-block sample storage for the B-scheme scan engine.
//     One block holds N=512 signed 16-bit samples.
//////////////////////////////////////////////////////////////////////////////////

module block_ram_512x16 #(
    parameter integer DEPTH  = 512,
    parameter integer ADDR_W = 9
)(
    input  wire                 clk,
    input  wire                 wr_en,
    input  wire [ADDR_W-1:0]    wr_addr,
    input  wire signed [15:0]   wr_data,
    input  wire [ADDR_W-1:0]    rd_addr,
    output wire signed [15:0]   rd_data
);

    reg signed [15:0] mem [0:DEPTH-1];

    always @(posedge clk)
    begin
        if(wr_en)
            mem[wr_addr] <= wr_data;
    end

    assign rd_data = mem[rd_addr];

endmodule
