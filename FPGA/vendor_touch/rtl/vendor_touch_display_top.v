`timescale 1ns / 1ps
// Standalone vendor GT9147 touch proof on the TFT itself.
// Screen: red = no detected touch, green = driver reports touch.
module vendor_touch_display_top(
    input  wire CLK,
    input  wire Reset_n,
    inout  wire tp_scl,
    inout  wire tp_sda,
    inout  wire tp_int,
    output wire tp_rst,
    output wire [15:0] TFT_rgb,
    output wire TFT_hs,
    output wire TFT_vs,
    output wire TFT_clk,
    output wire TFT_de,
    output wire TFT_pwm
);
    wire clkfb, clkfb_buf, clk33, locked, clk33_buf;
    MMCME2_BASE #(
        .BANDWIDTH("OPTIMIZED"), .CLKIN1_PERIOD(20.000), .DIVCLK_DIVIDE(2),
        .CLKFBOUT_MULT_F(33.000), .CLKOUT0_DIVIDE_F(25.000),
        .CLKOUT0_DUTY_CYCLE(0.500), .CLKOUT0_PHASE(0.000), .STARTUP_WAIT("FALSE")
    ) u_mmcm (
        .CLKOUT0(clk33), .CLKFBOUT(clkfb), .CLKFBIN(clkfb_buf),
        .CLKIN1(CLK), .PWRDWN(1'b0), .RST(~Reset_n), .LOCKED(locked)
    );
    BUFG u_bufg_fb   (.I(clkfb), .O(clkfb_buf));
    BUFG u_bufg_pclk (.I(clk33), .O(clk33_buf));

    wire [31:0] position;
    wire        point_flag;
    reg         point_meta, point_sync;
    reg         touch_seen;
    gt9147_driver u_vendor_touch (
        .clk(CLK), .rst_n(Reset_n),
        .seg_sclk(), .seg_rclk(), .seg_dio(),
        .position(position), .PointFlag(point_flag),
        .tp_scl(tp_scl), .tp_sda(tp_sda), .tp_int(tp_int), .tp_rst(tp_rst)
    );

    wire [11:0] h_addr, v_addr;
    wire        data_req, de_int;
    wire [15:0] disp_data;
    always @(posedge clk33_buf) begin
        if (!locked) begin
            point_meta <= 1'b0;
            point_sync <= 1'b0;
            touch_seen <= 1'b0;
        end else begin
            point_meta <= point_flag;
            point_sync <= point_meta;
            if (point_sync)
                touch_seen <= 1'b1;
        end
    end

    assign disp_data = touch_seen ? 16'h07E0 : 16'hF800;

    disp_driver u_disp (
        .ClkDisp(clk33_buf), .Rst_p(~locked), .Data(disp_data), .DataReq(data_req),
        .H_Addr(h_addr), .V_Addr(v_addr),
        .Disp_HS(TFT_hs), .Disp_VS(TFT_vs),
        .Disp_Red(TFT_rgb[15:11]), .Disp_Green(TFT_rgb[10:5]), .Disp_Blue(TFT_rgb[4:0]),
        .Frame_Begin(), .Disp_DE(de_int), .Disp_PCLK(TFT_clk)
    );
    assign TFT_de = de_int;
    assign TFT_pwm = Reset_n;
endmodule
