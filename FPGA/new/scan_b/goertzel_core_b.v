`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: goertzel_core_b
// Description:
//     Fixed-point Goertzel core for the B scheme.
//
//     The core processes exactly one N-sample block that has already been
//     stored in block_ram_512x16. The block mean is supplied as mean_q.
//
//     Fixed-point contract:
//         input sample : signed 16-bit integer
//         coefficients : signed 18-bit, 14 fractional bits
//         state        : signed 24-bit, 12 fractional bits
//         outputs      : signed 24-bit Xr / Xi in STATE_F scale
//////////////////////////////////////////////////////////////////////////////////

module goertzel_core_b #(
    parameter integer DATA_W  = 16,
    parameter integer COEF_W  = 18,
    parameter integer COEF_F  = 14,
    parameter integer STATE_W = 24,
    parameter integer STATE_F = 12,
    parameter integer OUT_W   = 24,
    parameter integer N_LOG2  = 9
)(
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     start,
    input  wire                     din_vld,
    input  wire signed [DATA_W-1:0] din,
    input  wire signed [STATE_W-1:0] mean_q,
    input  wire signed [COEF_W-1:0] coef_c,
    input  wire signed [COEF_W-1:0] coef_cos,
    input  wire signed [COEF_W-1:0] coef_sin,
    output reg                      busy,
    output reg                      done,
    output reg signed [OUT_W-1:0]   xr,
    output reg signed [OUT_W-1:0]   xi,
    output reg signed [STATE_W-1:0] s1_out,
    output reg signed [STATE_W-1:0] s2_out,
    output reg [15:0]               sat_cnt
);

    localparam integer N       = (1 << N_LOG2);
    localparam integer CNT_W   = N_LOG2 + 1;
    localparam integer NORM_SH = 15 - STATE_F;

    localparam signed [STATE_W-1:0] SMAX = {1'b0, {(STATE_W-1){1'b1}}};
    localparam signed [STATE_W-1:0] SMIN = {1'b1, {(STATE_W-1){1'b0}}};
    localparam signed [OUT_W-1:0] OUT_MAX = {1'b0, {(OUT_W-1){1'b1}}};
    localparam signed [OUT_W-1:0] OUT_MIN = {1'b1, {(OUT_W-1){1'b0}}};

    reg signed [STATE_W-1:0] s1;
    reg signed [STATE_W-1:0] s2;
    reg [CNT_W-1:0]          cnt;

    wire signed [STATE_W-1:0] din_norm = norm_sample(din);
    wire signed [STATE_W-1:0] x_dc     = din_norm - mean_q;
    wire signed [STATE_W+COEF_W-1:0] mult_s1c = s1 * coef_c;
    wire signed [STATE_W-1:0] prod_s = mult_s1c >>> COEF_F;
    wire signed [STATE_W+1:0] raw_sum  = $signed({x_dc[STATE_W-1], x_dc}) +
                                         $signed({{2{prod_s[STATE_W-1]}}, prod_s}) -
                                         $signed({{2{s2[STATE_W-1]}}, s2});

    wire                      sat_hi = (raw_sum >  $signed({{(STATE_W+2-STATE_W){1'b0}}, SMAX}));
    wire                      sat_lo = (raw_sum <  $signed({{(STATE_W+2-STATE_W){1'b1}}, SMIN}));
    wire signed [STATE_W-1:0] s_new  = sat_hi ? SMAX :
                                       sat_lo ? SMIN :
                                       raw_sum[STATE_W-1:0];

    wire signed [STATE_W-1:0] s2_next = s1;
    wire signed [STATE_W+COEF_W-1:0] mult_s2cos = s2_next * coef_cos;
    wire signed [STATE_W+1:0] cos_term = mult_s2cos >>> COEF_F;
    wire signed [STATE_W+1:0] s_new_ext = {{2{s_new[STATE_W-1]}}, s_new};
    wire signed [STATE_W+1:0] xr_full = s_new_ext - cos_term;
    wire signed [STATE_W+COEF_W-1:0] mult_s2sin = s2_next * coef_sin;
    wire signed [STATE_W+1:0] xi_full = mult_s2sin >>> COEF_F;
    wire signed [OUT_W-1:0] xr_next = sat_out(xr_full);
    wire signed [OUT_W-1:0] xi_next = sat_out(xi_full);

    always @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
        begin
            busy    <= 1'b0;
            done    <= 1'b0;
            xr      <= {OUT_W{1'b0}};
            xi      <= {OUT_W{1'b0}};
            s1      <= {STATE_W{1'b0}};
            s2      <= {STATE_W{1'b0}};
            s1_out  <= {STATE_W{1'b0}};
            s2_out  <= {STATE_W{1'b0}};
            sat_cnt <= 16'd0;
            cnt     <= {CNT_W{1'b0}};
        end
        else
        begin
            done <= 1'b0;

            if(start)
            begin
                busy    <= 1'b1;
                xr      <= {OUT_W{1'b0}};
                xi      <= {OUT_W{1'b0}};
                s1      <= {STATE_W{1'b0}};
                s2      <= {STATE_W{1'b0}};
                s1_out  <= {STATE_W{1'b0}};
                s2_out  <= {STATE_W{1'b0}};
                sat_cnt <= 16'd0;
                cnt     <= {CNT_W{1'b0}};
            end
            else if(busy && din_vld)
            begin
                if(sat_hi || sat_lo)
                    sat_cnt <= sat_cnt + 16'd1;

                if(cnt == (N-1))
                begin
                    xr      <= xr_next;
                    xi      <= xi_next;
                    s1_out  <= s_new;
                    s2_out  <= s2_next;
                    busy    <= 1'b0;
                    done    <= 1'b1;
                end
                else
                begin
                    s1  <= s_new;
                    s2  <= s2_next;
                    cnt <= cnt + {{(CNT_W-1){1'b0}}, 1'b1};
                end
            end
        end
    end

    function signed [OUT_W-1:0] sat_out;
        input signed [STATE_W+1:0] value;
        begin
            if(value > $signed(OUT_MAX))
                sat_out = OUT_MAX;
            else if(value < $signed(OUT_MIN))
                sat_out = OUT_MIN;
            else
                sat_out = value[OUT_W-1:0];
        end
    endfunction

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

