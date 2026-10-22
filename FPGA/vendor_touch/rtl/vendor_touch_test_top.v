`timescale 1ns / 1ps
// Standalone verification using the vendor GT9147 driver unchanged.
// LED0: current touch, LED7: sticky "touch ever seen", LED[6:1]: position bits.
module vendor_touch_test_top(
    input  wire       CLK,
    input  wire       Reset_n,
    inout  wire       tp_scl,
    inout  wire       tp_sda,
    inout  wire       tp_int,
    output wire       tp_rst,
    output wire [7:0] LED
);
    wire [31:0] position;
    wire        point_flag;
    reg         sticky;
    reg  [23:0] heartbeat;
    reg  [7:0]  led_reg;

    always @(posedge CLK or negedge Reset_n) begin
        if (!Reset_n) begin
            sticky <= 1'b0;
            heartbeat <= 24'd0;
        end else begin
            heartbeat <= heartbeat + 24'd1;
            if (point_flag)
                sticky <= 1'b1;
        end
    end

    always @* begin
        led_reg = {sticky, position[31:27], 1'b0, point_flag};
        if (!sticky && !point_flag)
            led_reg[0] = heartbeat[23];
    end
    assign LED = ~led_reg;   // ACX720 board LEDs are active-low

    gt9147_driver u_vendor_touch (
        .clk      (CLK),
        .rst_n    (Reset_n),
        .seg_sclk (),
        .seg_rclk (),
        .seg_dio  (),
        .position (position),
        .PointFlag(point_flag),
        .tp_scl   (tp_scl),
        .tp_sda   (tp_sda),
        .tp_int   (tp_int),
        .tp_rst   (tp_rst)
    );
endmodule
