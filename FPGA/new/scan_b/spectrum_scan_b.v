`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: spectrum_scan_b
// Description:
//     B-scheme Goertzel scan branch.
//
//     Data source is the L2 output stream at 800 SPS. The branch is read-only:
//     it never applies backpressure to the source and never changes the
//     existing N1/N2/N3 processing path.
//
//     Processing:
//         FILL 512 samples into a block RAM
//         compute the mean of that same block
//         read the same block and run fixed-point Goertzel
//         output Xr/Xi for one bin
//         advance to the next bin
//////////////////////////////////////////////////////////////////////////////////

module spectrum_scan_b #(
    parameter integer DATA_W   = 16,
    parameter integer COEF_W   = 18,
    parameter integer COEF_F   = 14,
    parameter integer STATE_W  = 24,
    parameter integer STATE_F  = 12,
    parameter integer OUT_W    = 24,
    parameter integer N_LOG2   = 9,
    parameter integer NBIN     = 128,
    parameter integer BIN_W    = 8,
    parameter integer ADDR_W   = 9
)(
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     scan_start,
    input  wire                     din_vld,
    input  wire signed [DATA_W-1:0] din,
    output wire                     scan_busy,
    output wire                     scan_done,
    output wire                     scan_error,
    output wire [BIN_W-1:0]         bin_idx,
    output wire                     bin_vld,
    output wire signed [OUT_W-1:0]  bin_xr,
    output wire signed [OUT_W-1:0]  bin_xi,
    output wire signed [15:0]       bin_mean,
    output wire signed [STATE_W-1:0] bin_s1,
    output wire signed [STATE_W-1:0] bin_s2,
    output wire                     peak_vld,
    output wire [BIN_W-1:0]         peak_bin,
    output wire signed [OUT_W-1:0]  peak_xr,
    output wire signed [OUT_W-1:0]  peak_xi,
    output wire [47:0]              peak_pow,
    output wire [15:0]              sat_cnt,
    output wire                     samp_taken
);

    localparam integer N = (1 << N_LOG2);

    wire                     fill_en;
    wire                     mean_clear;
    wire                     process_start;
    wire                     process_en;
    wire                     wr_en;
    wire [ADDR_W-1:0]        wr_addr;
    wire [ADDR_W-1:0]        rd_addr;
    wire [BIN_W-1:0]         fsm_bin_idx;
    wire                     result_load;
    wire                     core_done;
    wire                     core_busy;
    wire signed [STATE_W-1:0] mean_q;
    wire signed [DATA_W-1:0]  ram_rd_data;
    wire signed [COEF_W-1:0]  coef_c;
    wire signed [COEF_W-1:0]  coef_cos;
    wire signed [COEF_W-1:0]  coef_sin;
    wire signed [OUT_W-1:0]   core_xr;
    wire signed [OUT_W-1:0]   core_xi;
    wire signed [STATE_W-1:0] core_s1;
    wire signed [STATE_W-1:0] core_s2;
    wire [15:0]               core_sat;
    wire                     result_bin_vld;
    wire signed [OUT_W-1:0]   result_xr;
    wire signed [OUT_W-1:0]   result_xi;
    wire signed [STATE_W-1:0] result_s1;
    wire signed [STATE_W-1:0] result_s2;
    wire signed [15:0]        result_mean;
    wire [15:0]               result_sat;
    wire [BIN_W-1:0]          result_bin_idx;

    assign wr_en = fill_en && din_vld;

    block_ram_512x16 #(
        .DEPTH  (N),
        .ADDR_W (ADDR_W)
    ) u_block_ram (
        .clk     (clk),
        .wr_en   (wr_en),
        .wr_addr (wr_addr),
        .wr_data (din),
        .rd_addr (rd_addr),
        .rd_data (ram_rd_data)
    );

    block_mean #(
        .DATA_W  (DATA_W),
        .STATE_W (STATE_W),
        .STATE_F (STATE_F),
        .N_LOG2  (N_LOG2)
    ) u_block_mean (
        .clk     (clk),
        .rst_n   (rst_n),
        .clear   (mean_clear),
        .fill_en (fill_en),
        .din_vld (din_vld),
        .din     (din),
        .mean_q  (mean_q)
    );

    coef_rom_b #(
        .ADDR_W  (BIN_W),
        .COEF_W  (COEF_W)
    ) u_coef_rom (
        .addr  (fsm_bin_idx),
        .c     (coef_c),
        .cos_w (coef_cos),
        .sin_w (coef_sin)
    );

    goertzel_core_b #(
        .DATA_W  (DATA_W),
        .COEF_W  (COEF_W),
        .COEF_F  (COEF_F),
        .STATE_W (STATE_W),
        .STATE_F (STATE_F),
        .OUT_W   (OUT_W),
        .N_LOG2  (N_LOG2)
    ) u_goertzel_core (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (process_start),
        .din_vld   (process_en),
        .din       (ram_rd_data),
        .mean_q    (mean_q),
        .coef_c    (coef_c),
        .coef_cos  (coef_cos),
        .coef_sin  (coef_sin),
        .busy      (core_busy),
        .done      (core_done),
        .xr        (core_xr),
        .xi        (core_xi),
        .s1_out    (core_s1),
        .s2_out    (core_s2),
        .sat_cnt   (core_sat)
    );

    scan_fsm_b #(
        .N      (N),
        .NBIN   (NBIN),
        .ADDR_W (ADDR_W),
        .BIN_W  (BIN_W)
    ) u_scan_fsm (
        .clk          (clk),
        .rst_n        (rst_n),
        .scan_start   (scan_start),
        .din_vld      (din_vld),
        .core_done    (core_done),
        .fill_en      (fill_en),
        .mean_clear   (mean_clear),
        .process_start(process_start),
        .process_en   (process_en),
        .wr_addr      (wr_addr),
        .rd_addr      (rd_addr),
        .bin_idx      (fsm_bin_idx),
        .result_load  (result_load),
        .scan_busy    (scan_busy),
        .scan_done    (scan_done),
        .scan_error   (scan_error),
        .samp_taken   (samp_taken)
    );

    scan_result_reg #(
        .BIN_W  (BIN_W),
        .OUT_W  (OUT_W),
        .STATE_W(STATE_W)
    ) u_scan_result_reg (
        .clk         (clk),
        .rst_n       (rst_n),
        .scan_start  (scan_start),
        .bin_load    (result_load),
        .bin_idx_in  (fsm_bin_idx),
        .xr_in       (core_xr),
        .xi_in       (core_xi),
        .s1_in       (core_s1),
        .s2_in       (core_s2),
        .mean_in     (mean_q[15:0]),
        .sat_in      (core_sat),
        .bin_vld     (result_bin_vld),
        .bin_idx     (result_bin_idx),
        .xr          (result_xr),
        .xi          (result_xi),
        .s1          (result_s1),
        .s2          (result_s2),
        .mean_q      (result_mean),
        .sat_total   (result_sat),
        .peak_bin    (peak_bin),
        .peak_xr     (peak_xr),
        .peak_xi     (peak_xi),
        .peak_pow    (peak_pow)
    );

    assign bin_idx  = result_bin_idx;
    assign bin_vld  = result_bin_vld;
    assign bin_xr   = result_xr;
    assign bin_xi   = result_xi;
    assign bin_mean = result_mean;
    assign bin_s1   = result_s1;
    assign bin_s2   = result_s2;
    assign peak_vld = scan_done;
    assign sat_cnt  = result_sat;

endmodule



