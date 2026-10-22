`timescale 1ns / 1ps
// I2C address scanner for the ACX720-V3 TFT touch interface.
// RST is left high-Z so the controller keeps its power-on/default address.
// INT is pulsed high to wake the controller, then all 7-bit read addresses
// in 0x08..0x77 are probed. LED[7]=found, LED[6:0]=address.
module gt911_scan_probe_top #(
    parameter [22:0] POWER_CYCLES = 23'd5_000_000,
    parameter [22:0] WAKE_CYCLES  = 23'd250_000,
    parameter integer SCL_CLOCK  = 50_000
)(
    input  wire        CLK,
    input  wire        Reset_n,
    inout  wire        tp_scl,
    inout  wire        tp_sda,
    inout  wire        tp_int,
    inout  wire        tp_rst,
    output wire [7:0]  LED,
    output wire [15:0] TFT_rgb,
    output wire        TFT_hs,
    output wire        TFT_vs,
    output wire        TFT_clk,
    output wire        TFT_de,
    output wire        TFT_pwm
);
    localparam WR=6'b000001, STA=6'b000010, STO=6'b001000;

    // RST is deliberately never driven: use the module's own power-on state.
    assign tp_rst = 1'bz;

    reg int_high;
    assign tp_int = int_high ? 1'b1 : 1'bz;

    reg        go;
    reg [5:0]  cmd;
    reg [7:0]  tx;
    wire       done;
    wire       ack_n;

    i2c_bit_shift #( .SCL_CLOCK(SCL_CLOCK) ) u_i2c (
        .Clk(CLK), .Rst_n(Reset_n), .Cmd(cmd), .Go(go),
        .Rx_DATA(), .Tx_DATA(tx), .Trans_Done(done), .ack_o(ack_n),
        .i2c_sclk(tp_scl), .i2c_sdat(tp_sda)
    );

    localparam S_POWER=0, S_WAKE=1, S_AFTER_WAKE=2, S_SCAN=3,
               S_WAIT=4, S_FOUND=5, S_NONE=6;
    reg [2:0] st;
    reg [22:0] dly;
    reg [6:0] addr;
    reg       found;
    reg [6:0] found_addr;
    reg       scan_started;
    reg [23:0] heartbeat;

    always @(posedge CLK or negedge Reset_n) begin
        if (!Reset_n) begin
            st<=S_POWER; dly<=0; addr<=7'h08; found<=0; found_addr<=0;
            int_high<=0; go<=0; cmd<=0; tx<=0; scan_started<=0;
            heartbeat<=0;
        end else begin
            heartbeat <= heartbeat + 1'b1;
            go <= 1'b0;
            if (dly != 0) dly <= dly - 1'b1;

            case (st)
            S_POWER: begin
                int_high<=0;
                if (dly==0) begin dly<=POWER_CYCLES; st<=S_WAKE; end
            end
            S_WAKE: begin
                int_high<=1;
                if (dly==0) begin int_high<=0; dly<=WAKE_CYCLES; st<=S_AFTER_WAKE; end
            end
            S_AFTER_WAKE: begin
                int_high<=0;
                if (dly==0) begin addr<=7'h08; scan_started<=0; st<=S_SCAN; end
            end
            S_SCAN: begin
                if (addr > 7'h77) begin
                    st<=S_NONE;
                end else if (!scan_started) begin
                    cmd <= WR | STA | STO;
                    tx  <= {addr, 1'b1};
                    go  <= 1'b1;
                    scan_started <= 1'b1;
                    st <= S_WAIT;
                end
            end
            S_WAIT: begin
                if (done) begin
                    scan_started<=0;
                    if (ack_n==1'b0) begin
                        found<=1'b1;
                        found_addr<=addr;
                        st<=S_FOUND;
                    end else begin
                        addr<=addr+1'b1;
                        st<=S_SCAN;
                    end
                end
            end
            S_FOUND: begin
                found<=1'b1;
            end
            S_NONE: begin
                found<=1'b0;
            end
            default: st<=S_POWER;
            endcase
        end
    end

    assign LED[6:0] = found_addr;
    assign LED[7]   = found;

    // Display: blue=scanning, green=found, red=none.
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

    reg [1:0] res_meta, res_sync;
    always @(posedge clk33_buf) begin
        if (!locked) begin res_meta<=2'd0; res_sync<=2'd0; end
        else begin res_meta<={found, (st==S_FOUND || st==S_NONE)}; res_sync<=res_meta; end
    end
    wire [15:0] disp_data = (res_sync==2'b11) ? 16'h07E0 :
                            (res_sync==2'b01) ? 16'hF800 : 16'h001F;
    wire [11:0] h_addr, v_addr;
    wire data_req, de_int;
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
