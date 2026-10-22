`timescale 1ns / 1ps
// Standalone touch-line continuity probe.
// Each line is slowly pulsed for 4 s so a multimeter can see it.
// LED[2:0] = stage + 1: SCL, SDA, INT, RST, idle.
module touch_pin_test(
    input  wire CLK,
    input  wire Reset_n,
    inout  wire tp_scl,
    inout  wire tp_sda,
    inout  wire tp_int,
    output wire tp_rst,
    output wire [2:0] LED
);
    reg [26:0] cnt;
    reg        slow;
    reg [1:0]  sub;
    reg [2:0]  stage;

    wire sec_tick = (cnt == 27'd49_999_999);

    always @(posedge CLK or negedge Reset_n) begin
        if (!Reset_n) begin
            cnt <= 27'd0;
            slow <= 1'b0;
            sub <= 2'd0;
            stage <= 3'd0;
        end else if (sec_tick) begin
            cnt <= 27'd0;
            slow <= ~slow;
            sub <= sub + 2'd1;
            if (sub == 2'd3)
                stage <= (stage == 3'd4) ? 3'd0 : stage + 3'd1;
        end else begin
            cnt <= cnt + 27'd1;
        end
    end

    assign tp_scl = (stage == 3'd0 && !slow) ? 1'b0 : 1'bz;
    assign tp_sda = (stage == 3'd1 && !slow) ? 1'b0 : 1'bz;
    assign tp_int = (stage == 3'd2 && !slow) ? 1'b0 : 1'bz;
    assign tp_rst = (stage == 3'd3) ? slow : 1'b1;
    assign LED = stage + 3'd1;
endmodule
