`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: block_mean
// Description:
//     Accumulates the normalized Q12 values of one 512-sample block and
//     computes the rounded block mean after the block is full.
//////////////////////////////////////////////////////////////////////////////////

module block_mean #(
    parameter integer DATA_W  = 16,
    parameter integer STATE_W = 24,
    parameter integer STATE_F = 12,
    parameter integer N_LOG2  = 9
)(
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     clear,
    input  wire                     fill_en,
    input  wire                     din_vld,
    input  wire signed [DATA_W-1:0] din,
    output wire signed [STATE_W-1:0] mean_q
);

    localparam integer N       = (1 << N_LOG2);
    localparam integer NORM_SH = 15 - STATE_F;

    reg signed [31:0] acc;

    wire signed [STATE_W-1:0] din_q = norm_sample(din);
    wire signed [31:0] mean_calc;

    assign mean_calc = (acc >= 0) ?
                       ((acc + (N/2)) >>> N_LOG2) :
                       -(((-acc) + (N/2)) >>> N_LOG2);

    assign mean_q = mean_calc[STATE_W-1:0];

    always @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
            acc <= 32'sd0;
        else if(clear)
            acc <= 32'sd0;
        else if(fill_en && din_vld)
            acc <= acc + {{(32-(STATE_W)){din_q[STATE_W-1]}}, din_q};
    end

    function signed [STATE_W-1:0] norm_sample;
        input signed [DATA_W-1:0] x;
        reg signed [DATA_W:0] x_ext;
        reg signed [DATA_W:0] mag;
        begin
            x_ext = {x[DATA_W-1], x};
            if(x >= 0) begin
                mag = x_ext + (1 << (NORM_SH-1));
                norm_sample = mag >>> NORM_SH;
            end else begin
                mag = -x_ext + (1 << (NORM_SH-1));
                norm_sample = -(mag >>> NORM_SH);
            end
        end
    endfunction

endmodule
