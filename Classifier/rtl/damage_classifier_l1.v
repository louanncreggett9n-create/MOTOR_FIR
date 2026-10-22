`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Serial 16-band L1 nearest-centroid classifier.
// Bins arrive in ascending order from the existing scan result stream.
//////////////////////////////////////////////////////////////////////////////////
module damage_classifier_l1 (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               scan_start,
    input  wire               scan_done,
    input  wire               bin_vld,
    input  wire [6:0]         bin_idx,
    input  wire signed [23:0] bin_xr,
    input  wire signed [23:0] bin_xi,
    output reg                result_valid,
    output reg  [3:0]         result_cls,
    output reg  [7:0]         result_conf,
    output reg  [15:0]        result_best_dist,
    output reg  [15:0]        result_second_dist,
    output reg  [15:0]        result_margin,
    output reg                result_unknown
);

    localparam S_IDLE  = 2'd0;
    localparam S_CALC  = 2'd1;
    localparam S_DONE  = 2'd2;

    localparam [15:0] REJECT_DISTANCE = 16'd600;
    localparam [15:0] REJECT_MARGIN   = 16'd300;

    `include "classifier_templates_16band.vh"

    reg [1:0]  state;
    reg [10:0] band_sum [0:15];
    reg [3:0]  band_scan;
    reg [2:0]  class_scan;
    reg [15:0] dist_acc;
    reg [15:0] best_dist;
    reg [15:0] second_dist;
    reg [2:0]  best_cls;
    reg [2:0]  second_cls;

    reg [10:0] band_value;
    reg [11:0] centroid_value;
    reg [11:0] delta_value;
    reg [16:0] candidate_value;

    integer i;

    wire [23:0] xr_abs = bin_xr[23] ? (~bin_xr + 24'd1) : bin_xr;
    wire [23:0] xi_abs = bin_xi[23] ? (~bin_xi + 24'd1) : bin_xi;
    wire [24:0] mag_sum = {1'b0, xr_abs} + {1'b0, xi_abs};
    wire [24:0] mag_clip = (mag_sum > 25'd9600) ? 25'd9600 : mag_sum;
    wire [7:0]  bin_height = mag_clip[13:6];
    wire [15:0] calc_margin = (second_dist > best_dist) ? (second_dist - best_dist) : 16'd0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= S_IDLE;
            result_valid    <= 1'b0;
            result_cls      <= 4'd7;
            result_conf     <= 8'd0;
            result_best_dist <= 16'hFFFF;
            result_second_dist <= 16'hFFFF;
            result_margin   <= 16'd0;
            result_unknown  <= 1'b1;
            band_scan       <= 4'd0;
            class_scan      <= 3'd0;
            dist_acc        <= 16'd0;
            best_dist       <= 16'hFFFF;
            second_dist     <= 16'hFFFF;
            best_cls        <= 3'd0;
            second_cls      <= 3'd0;
            band_value      <= 11'd0;
            centroid_value  <= 12'd0;
            delta_value     <= 12'd0;
            candidate_value <= 17'd0;
            for (i = 0; i < 16; i = i + 1)
                band_sum[i] <= 11'd0;
        end else begin
            result_valid <= 1'b0;

            if (scan_start) begin
                state           <= S_IDLE;
                result_cls      <= 4'd7;
                result_conf     <= 8'd0;
                result_best_dist <= 16'hFFFF;
                result_second_dist <= 16'hFFFF;
                result_margin   <= 16'd0;
                result_unknown  <= 1'b1;
                band_scan       <= 4'd0;
                class_scan      <= 3'd0;
                dist_acc        <= 16'd0;
                best_dist       <= 16'hFFFF;
                second_dist     <= 16'hFFFF;
                best_cls        <= 3'd0;
                second_cls      <= 3'd0;
                for (i = 0; i < 16; i = i + 1)
                    band_sum[i] <= 11'd0;
            end else begin
                if (bin_vld) begin
                    if (bin_idx[2:0] == 3'd0)
                        band_sum[bin_idx[6:3]] <= {3'd0, bin_height};
                    else
                        band_sum[bin_idx[6:3]] <= band_sum[bin_idx[6:3]] + {3'd0, bin_height};
                end

                case (state)
                S_IDLE: begin
                    if (scan_done) begin
                        state        <= S_CALC;
                        class_scan   <= 3'd0;
                        band_scan    <= 4'd0;
                        dist_acc     <= 16'd0;
                        best_dist    <= 16'hFFFF;
                        second_dist  <= 16'hFFFF;
                        best_cls     <= 3'd0;
                        second_cls   <= 3'd0;
                    end
                end

                S_CALC: begin
                    band_value     = band_sum[band_scan];
                    centroid_value = classifier_centroid(class_scan, band_scan);
                    delta_value    = (band_value >= centroid_value) ?
                                     (band_value - centroid_value) :
                                     (centroid_value - band_value);

                    if (band_scan == 4'd15) begin
                        candidate_value = {1'b0, dist_acc} + {5'd0, delta_value};
                        if (candidate_value < {1'b0, best_dist}) begin
                            second_dist <= best_dist;
                            second_cls  <= best_cls;
                            best_dist   <= candidate_value[15:0];
                            best_cls    <= class_scan;
                        end else if (candidate_value < {1'b0, second_dist}) begin
                            second_dist <= candidate_value[15:0];
                            second_cls  <= class_scan;
                        end

                        band_scan  <= 4'd0;
                        dist_acc   <= 16'd0;
                        if (class_scan == 3'd5)
                            state <= S_DONE;
                        else
                            class_scan <= class_scan + 3'd1;
                    end else begin
                        dist_acc  <= dist_acc + {5'd0, delta_value};
                        band_scan <= band_scan + 4'd1;
                    end
                end

                S_DONE: begin
                    result_best_dist   <= best_dist;
                    result_second_dist <= second_dist;
                    result_margin      <= calc_margin;
                    if ((best_dist > REJECT_DISTANCE) || (calc_margin < REJECT_MARGIN)) begin
                        result_cls     <= 4'd7;
                        result_conf    <= 8'd0;
                        result_unknown <= 1'b1;
                    end else begin
                        result_cls     <= {1'b0, best_cls};
                        result_conf    <= (calc_margin >= 16'd1600) ? 8'd99 : calc_margin[11:4];
                        result_unknown <= 1'b0;
                    end
                    result_valid <= 1'b1;
                    state        <= S_IDLE;
                end

                default: state <= S_IDLE;
                endcase
            end
        end
    end

endmodule