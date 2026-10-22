`timescale 1ns / 1ps
// GT911/GT9147 address ACK probe using the vendor 100 kHz I2C bit engine.
// Vendor address select: INT high at RST rise -> 0x14 (write 0x28); INT low -> 0x5D (write 0xBA).
// Tests READ addresses (LSB=1) to avoid false ACK from a preceding zero bit.
// Red = no ACK, Green = 0x14 read address 0x29 ACK, Blue = 0x5D read address 0xBB ACK.
module gt911_ack_probe_top(
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
    localparam WR=6'b000001, STA=6'b000010, STO=6'b001000;

    reg        int_low, int_high;
    reg        rst;
    reg        attempt;
    reg [2:0]  st;
    reg [21:0] dly;
    reg        go;
    reg [5:0]  cmd;
    reg [7:0]  tx;
    reg [1:0]  result;
    wire       done;
    wire       ack_n;

    assign tp_int = int_low ? 1'b0 : (int_high ? 1'b1 : 1'bz);
    assign tp_rst = rst;

    i2c_bit_shift #( .SCL_CLOCK(50_000) ) u_i2c (
        .Clk(CLK), .Rst_n(Reset_n), .Cmd(cmd), .Go(go),
        .Rx_DATA(), .Tx_DATA(tx), .Trans_Done(done), .ack_o(ack_n),
        .i2c_sclk(tp_scl), .i2c_sdat(tp_sda)
    );

    localparam P_RST0=0, P_INT=1, P_RST1=2, P_REL=3, P_GO=4, P_WAIT=5,
               P_NEXT=6, P_DONE=7;

    always @(posedge CLK or negedge Reset_n) begin
        if (!Reset_n) begin
            int_low<=1'b1; int_high<=1'b0; rst<=1'b0; attempt<=1'b0;
            st<=P_RST0; dly<=22'd0; go<=1'b0; cmd<=6'd0; tx<=8'd0; result<=2'd0;
        end else begin
            go <= 1'b0;
            if (dly != 0) dly <= dly - 1'b1;
            case (st)
            P_RST0: begin
                int_low<=1'b1; int_high<=1'b0; rst<=1'b0;
                if (dly==0) begin dly<=22'd500_000; st<=P_INT; end
            end
            P_INT: begin
                // Vendor sequence: INT high selects 0x28; INT low selects 0xBA.
                int_low  <= ~attempt;
                int_high <= attempt;
                if (dly==0) begin dly<=22'd250_000; st<=P_RST1; end
            end
            P_RST1: begin
                rst<=1'b1;
                if (dly==0) begin dly<=22'd2_500_000; st<=P_REL; end
            end
            P_REL: begin
                int_low<=1'b0; int_high<=1'b0;
                if (dly==0) begin
                    cmd <= WR | STA | STO;
                    tx  <= attempt ? 8'hBB : 8'h29;
                    go  <= 1'b1;
                    st  <= P_GO;
                end
            end
            P_GO: st <= P_WAIT;
            P_WAIT: if (done) begin
                if (ack_n == 1'b0)
                    begin result <= attempt ? 2'd2 : 2'd1; st<=P_DONE; end
                else if (attempt == 1'b0)
                    begin attempt<=1'b1; st<=P_NEXT; end
                else
                    begin result<=2'd0; st<=P_DONE; end
            end
            P_NEXT: st <= P_RST0;
            P_DONE: st <= P_DONE;
            default: st <= P_RST0;
            endcase
        end
    end

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
        else begin res_meta<=result; res_sync<=res_meta; end
    end
    wire [15:0] disp_data = (res_sync==2'd1) ? 16'h07E0 :
                            (res_sync==2'd2) ? 16'h001F : 16'hF800;
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
