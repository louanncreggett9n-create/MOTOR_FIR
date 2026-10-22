`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: fir_output_stage
// Description:
//     Convert the full-precision signed output of transposed_fir back to a
//     16-bit signed integer suitable for Frame_Send or downstream modules.
//
//     - Right-shifts by SHIFT (default 15 for Q15 coefficients).
//     - Rounds by adding 0.5 LSB before truncation.
//     - Saturates to the 16-bit signed range [-32768, +32767].
//     - Passes valid_in to valid_out with one-clock latency.
//////////////////////////////////////////////////////////////////////////////////

module fir_output_stage #(
    parameter DATA_IN_W  = 40,
    parameter DATA_OUT_W = 16,
    parameter SHIFT      = 15
)(
    input  wire                       clk,
    input  wire                       rst_n,
    input  wire                       valid_in,
    input  wire signed [DATA_IN_W-1:0] data_in,
    output reg                        valid_out,
    output reg  signed [DATA_OUT_W-1:0] data_out
);

    // Half-LSB for rounding: 1 << (SHIFT - 1)
    localparam ROUND = (1 << (SHIFT - 1));

    // Maximum and minimum values for the output range
    localparam signed [DATA_OUT_W-1:0] MAX_VAL = {1'b0, {(DATA_OUT_W-1){1'b1}}};
    localparam signed [DATA_OUT_W-1:0] MIN_VAL = {1'b1, {(DATA_OUT_W-1){1'b0}}};

    // -------------------------------------------------------------------------
    // Round and saturate
    // -------------------------------------------------------------------------
    wire signed [DATA_IN_W-1:0] rounded = data_in + ROUND;
    wire signed [DATA_IN_W-1:0] shifted = rounded >>> SHIFT;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 1'b0;
            data_out  <= 'd0;
        end else begin
            valid_out <= valid_in;
            if (shifted > MAX_VAL)
                data_out <= MAX_VAL;
            else if (shifted < MIN_VAL)
                data_out <= MIN_VAL;
            else
                data_out <= shifted[DATA_OUT_W-1:0];
        end
    end

endmodule
