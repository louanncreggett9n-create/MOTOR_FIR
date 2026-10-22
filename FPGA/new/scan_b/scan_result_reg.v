`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: scan_result_reg
// Description:
//     Captures one bin result and maintains the peak-power result.
//////////////////////////////////////////////////////////////////////////////////

module scan_result_reg #(
    parameter integer BIN_W   = 8,
    parameter integer OUT_W   = 24,
    parameter integer STATE_W = 24
)(
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     scan_start,
    input  wire                     bin_load,
    input  wire [BIN_W-1:0]         bin_idx_in,
    input  wire signed [OUT_W-1:0]  xr_in,
    input  wire signed [OUT_W-1:0]  xi_in,
    input  wire signed [STATE_W-1:0] s1_in,
    input  wire signed [STATE_W-1:0] s2_in,
    input  wire signed [15:0]       mean_in,
    input  wire [15:0]              sat_in,
    output reg                      bin_vld,
    output reg  [BIN_W-1:0]         bin_idx,
    output reg  signed [OUT_W-1:0]  xr,
    output reg  signed [OUT_W-1:0]  xi,
    output reg  signed [STATE_W-1:0] s1,
    output reg  signed [STATE_W-1:0] s2,
    output reg  signed [15:0]       mean_q,
    output reg  [15:0]              sat_total,
    output reg  [BIN_W-1:0]         peak_bin,
    output reg  signed [OUT_W-1:0]  peak_xr,
    output reg  signed [OUT_W-1:0]  peak_xi,
    output reg  [47:0]              peak_pow
);

    wire signed [47:0] xr_sq = $signed(xr_in) * $signed(xr_in);
    wire signed [47:0] xi_sq = $signed(xi_in) * $signed(xi_in);
    wire        [47:0] pow_calc = xr_sq + xi_sq;

    always @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
        begin
            bin_vld   <= 1'b0;
            bin_idx   <= {BIN_W{1'b0}};
            xr        <= {OUT_W{1'b0}};
            xi        <= {OUT_W{1'b0}};
            s1        <= {STATE_W{1'b0}};
            s2        <= {STATE_W{1'b0}};
            mean_q    <= 16'sd0;
            sat_total <= 16'd0;
            peak_bin  <= {BIN_W{1'b0}};
            peak_xr   <= {OUT_W{1'b0}};
            peak_xi   <= {OUT_W{1'b0}};
            peak_pow  <= 48'd0;
        end
        else if(scan_start)
        begin
            bin_vld   <= 1'b0;
            sat_total <= 16'd0;
            peak_bin  <= {BIN_W{1'b0}};
            peak_xr   <= {OUT_W{1'b0}};
            peak_xi   <= {OUT_W{1'b0}};
            peak_pow  <= 48'd0;
        end
        else
        begin
            bin_vld <= bin_load;

            if(bin_load)
            begin
                bin_idx   <= bin_idx_in;
                xr        <= xr_in;
                xi        <= xi_in;
                s1        <= s1_in;
                s2        <= s2_in;
                mean_q    <= mean_in;
                sat_total <= sat_total + sat_in;

                if(pow_calc >= peak_pow)
                begin
                    peak_bin <= bin_idx_in;
                    peak_xr  <= xr_in;
                    peak_xi  <= xi_in;
                    peak_pow <= pow_calc;
                end
            end
        end
    end

endmodule

