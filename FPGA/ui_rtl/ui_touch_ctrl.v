`timescale 1ns / 1ps
// One-shot / hold-repeat touch command decoder for the page-3 control panel.
module ui_touch_ctrl(
    input  wire       clk,
    input  wire       rst_n,
    input  wire [1:0] page,
    input  wire [9:0] x,
    input  wire [9:0] y,
    input  wire       down,
    output reg  [4:0] cmd
);
    localparam CMD_NONE      = 5'd0,
               CMD_MODE_LOOP = 5'd1,
               CMD_MODE_UP   = 5'd2,
               CMD_SRC_ADC   = 5'd3,
               CMD_SRC_DDS   = 5'd4,
               CMD_WAVE_SIN  = 5'd5,
               CMD_WAVE_SQR  = 5'd6,
               CMD_WAVE_TRI  = 5'd7,
               CMD_WAVE_DAT  = 5'd8,
               CMD_FREQ_DEC  = 5'd9,
               CMD_FREQ_INC  = 5'd10,
               CMD_CH_DEC    = 5'd11,
               CMD_CH_INC    = 5'd12,
               CMD_AMP_DEC   = 5'd13,
               CMD_AMP_INC   = 5'd14,
               CMD_NSEL_0    = 5'd15,
               CMD_NSEL_1    = 5'd16,
               CMD_NSEL_2    = 5'd17,
               CMD_NSEL_3    = 5'd18,
               CMD_SCAN      = 5'd19;

    localparam [25:0] LOCKOUT_TIME  = 26'd15_000_000, // 300 ms
                      HOLD_DELAY    = 26'd50_000_000, // 1000 ms
                      REPEAT_PERIOD = 26'd30_000_000; // 600 ms

    reg down_d;
    reg [4:0] hold_cmd;
    reg [25:0] hold_cnt, repeat_cnt, lockout_cnt;

    function in_box;
        input [9:0] px, py, x0, x1, y0, y1;
        begin
            in_box = (px >= x0) && (px <= x1) && (py >= y0) && (py <= y1);
        end
    endfunction

    function [4:0] hit_cmd;
        input [9:0] px, py;
        begin
            hit_cmd = CMD_NONE;
            if (in_box(px,py,10'd8,10'd196,10'd64,10'd103)) hit_cmd=CMD_MODE_LOOP;
            else if (in_box(px,py,10'd204,10'd392,10'd64,10'd103)) hit_cmd=CMD_MODE_UP;
            else if (in_box(px,py,10'd408,10'd596,10'd64,10'd103)) hit_cmd=CMD_SRC_ADC;
            else if (in_box(px,py,10'd604,10'd791,10'd64,10'd103)) hit_cmd=CMD_SRC_DDS;
            else if (in_box(px,py,10'd8,10'd196,10'd112,10'd151)) hit_cmd=CMD_WAVE_SIN;
            else if (in_box(px,py,10'd204,10'd392,10'd112,10'd151)) hit_cmd=CMD_WAVE_SQR;
            else if (in_box(px,py,10'd408,10'd596,10'd112,10'd151)) hit_cmd=CMD_WAVE_TRI;
            else if (in_box(px,py,10'd604,10'd791,10'd112,10'd151)) hit_cmd=CMD_WAVE_DAT;
            else if (in_box(px,py,10'd8,10'd72,10'd160,10'd199)) hit_cmd=CMD_FREQ_DEC;
            else if (in_box(px,py,10'd718,10'd791,10'd160,10'd199)) hit_cmd=CMD_FREQ_INC;
            else if (in_box(px,py,10'd8,10'd72,10'd208,10'd247)) hit_cmd=CMD_CH_DEC;
            else if (in_box(px,py,10'd718,10'd791,10'd208,10'd247)) hit_cmd=CMD_CH_INC;
            else if (in_box(px,py,10'd8,10'd72,10'd256,10'd295)) hit_cmd=CMD_AMP_DEC;
            else if (in_box(px,py,10'd438,10'd510,10'd256,10'd295)) hit_cmd=CMD_AMP_INC;
            else if (in_box(px,py,10'd560,10'd791,10'd256,10'd295)) hit_cmd=CMD_SCAN;
            else if (in_box(px,py,10'd8,10'd196,10'd304,10'd343)) hit_cmd=CMD_NSEL_0;
            else if (in_box(px,py,10'd204,10'd392,10'd304,10'd343)) hit_cmd=CMD_NSEL_1;
            else if (in_box(px,py,10'd408,10'd596,10'd304,10'd343)) hit_cmd=CMD_NSEL_2;
            else if (in_box(px,py,10'd604,10'd791,10'd304,10'd343)) hit_cmd=CMD_NSEL_3;
        end
    endfunction

    function repeatable;
        input [4:0] c;
        begin
            repeatable = (c == CMD_FREQ_DEC) || (c == CMD_FREQ_INC) ||
                         (c == CMD_CH_DEC)   || (c == CMD_CH_INC)   ||
                         (c == CMD_AMP_DEC)  || (c == CMD_AMP_INC);
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            down_d <= 1'b0;
            cmd <= CMD_NONE;
            hold_cmd <= CMD_NONE;
            hold_cnt <= 26'd0;
            repeat_cnt <= 26'd0;
            lockout_cnt <= 26'd0;
        end else begin
            down_d <= down;
            cmd <= CMD_NONE;
            if (lockout_cnt != 26'd0) lockout_cnt <= lockout_cnt - 1'b1;

            if (down && !down_d && (page == 2'd3) && (lockout_cnt == 26'd0)) begin
                hold_cmd <= hit_cmd(x, y);
                hold_cnt <= 26'd0;
                repeat_cnt <= 26'd0;
                lockout_cnt <= LOCKOUT_TIME;
                cmd <= hit_cmd(x, y);
            end else if (down && (page == 2'd3) &&
                         repeatable(hold_cmd) && (hit_cmd(x, y) == hold_cmd)) begin
                if (hold_cnt < HOLD_DELAY) begin
                    hold_cnt <= hold_cnt + 1'b1;
                end else begin
                    if (repeat_cnt >= REPEAT_PERIOD - 1'b1) begin
                        repeat_cnt <= 26'd0;
                        lockout_cnt <= LOCKOUT_TIME;
                        cmd <= hold_cmd;
                    end else begin
                        repeat_cnt <= repeat_cnt + 1'b1;
                    end
                end
            end else begin
                hold_cmd <= CMD_NONE;
                hold_cnt <= 26'd0;
                repeat_cnt <= 26'd0;
            end
        end
    end
endmodule