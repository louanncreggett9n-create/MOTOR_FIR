`timescale 1ns / 1ps
// GT911 driver using the vendor-accepted 100 kHz I2C engine.
// Confirmed address: 7-bit 0x14 (write 0x28 / read 0x29).
module gt911_touch_v2 #(
    parameter [21:0] RST_LOW_CYCLES    = 22'd500_000,
    parameter [21:0] RST_HIGH_CYCLES   = 22'd500_000,
    parameter [21:0] INIT_WAIT_CYCLES  = 22'd2_500_000,
    parameter [21:0] POLL_GAP_CYCLES   = 22'd1_000_000
)(
    input  wire       clk, rst_n,
    inout  wire       tp_scl, tp_sda, tp_int,
    output reg        tp_rst,
    output reg [9:0]  x, y,
    output reg        down,
    output wire       ack_o,
    output wire [7:0] status_o,
    output wire [6:0] addr_o,
    output wire [7:0] id0_o, id1_o, id2_o,
    output wire [7:0] idb0_o, idb1_o, idb2_o,
    output wire [7:0] cfgver_o,
    output wire [7:0] trans_cnt_o,
    output wire [1:0] bus_idle_o,
    output wire       reg_wack_o,
    output reg [2:0]  state_o
);
    localparam WR=6'b000001, STA=6'b000010, RD=6'b000100,
               STO=6'b001000, ACK=6'b010000, NACK=6'b100000;

    reg int_low, int_high;
    assign tp_int = int_low ? 1'b0 : (int_high ? 1'b1 : 1'bz);

    reg wr_req, rd_req;
    reg [3:0] rd_num;
    reg [15:0] ra;
    reg [7:0] wd;
    wire [31:0] rddata;
    wire rw_done;
    wire nack_any;

    i2c_control u_i2c (
        .Clk(clk), .Rst_n(rst_n),
        .wrreg_req(wr_req), .rdreg_req(rd_req), .rdreg_num(rd_num),
        .addr(ra), .addr_mode(1'b1), .wrdata(wd), .rddata(rddata),
        .device_id(8'h28), .RW_Done(rw_done), .ack(nack_any),
        .i2c_sclk(tp_scl), .i2c_sdat(tp_sda)
    );

    localparam S_RST0=0, S_RST1=1, S_REL=2, S_CLR_REQ=3, S_CLR_WAIT=4,
               S_ID_REQ=5, S_ID_WAIT=6, S_CFG_REQ=7, S_CFG_WAIT=8,
               S_STA_REQ=9, S_STA_WAIT=10, S_P1_REQ=11, S_P1_WAIT=12,
               S_P2_REQ=13, S_P2_WAIT=14, S_GAP=15;
    reg [3:0] st;
    reg [21:0] dly;
    reg [7:0] id0,id1,id2,cfgver,status;
    reg [7:0] trans_cnt;
    reg [1:0] bus_idle;
    reg [15:0] stable_cnt;
    reg ack_ok, reg_wack;
    reg init_done;
    reg [7:0] p0 [0:3]; // id, xL, xH, yL
    reg [7:0] p1 [0:3]; // yL, yH, sizeL, sizeH

    assign ack_o = ack_ok;
    assign status_o = status;
    assign addr_o = 7'h14;
    assign id0_o=id0; assign id1_o=id1; assign id2_o=id2;
    assign idb0_o=id0; assign idb1_o=id1; assign idb2_o=id2;
    assign cfgver_o=cfgver;
    assign trans_cnt_o=trans_cnt;
    assign bus_idle_o=bus_idle;
    assign reg_wack_o=reg_wack;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // INT low at RST rising edge selects 7-bit address 0x14.
            int_low<=1'b1; int_high<=1'b0; tp_rst<=1'b0;
            wr_req<=0; rd_req<=0; rd_num<=0; ra<=0; wd<=0;
            st<=S_RST0; dly<=0; x<=0; y<=0; down<=0; state_o<=0;
            id0<=0; id1<=0; id2<=0; cfgver<=0; status<=0; trans_cnt<=0;
            bus_idle<=2'b11; stable_cnt<=0; ack_ok<=0; reg_wack<=0; init_done<=1'b0;
            p0[0]<=0; p0[1]<=0; p0[2]<=0; p0[3]<=0;
            p1[0]<=0; p1[1]<=0; p1[2]<=0; p1[3]<=0;
        end else begin
            state_o <= st[2:0];
            if (dly != 0) dly <= dly - 1'b1;

            // Freeze bus-level diagnostics while a transaction is active.
            if (!wr_req && !rd_req && st!=S_ID_REQ && st!=S_CFG_REQ && st!=S_STA_REQ &&
                st!=S_P1_REQ && st!=S_P2_REQ) begin
                if ({tp_scl,tp_sda} != bus_idle) begin
                    if (stable_cnt==16'hFFFF) begin
                        bus_idle <= {tp_scl,tp_sda}; stable_cnt<=0;
                    end else stable_cnt<=stable_cnt+1'b1;
                end else stable_cnt<=0;
            end else stable_cnt<=0;

            if (rw_done) begin
                trans_cnt <= trans_cnt + 1'b1;
                ack_ok <= (nack_any == 1'b0);
            end

            case (st)
            S_RST0: begin
                // Hold INT low while RST is released to latch address 0x14.
                int_low<=1'b1; int_high<=1'b0; tp_rst<=1'b0;
                if (dly==0) begin dly<=RST_LOW_CYCLES; st<=S_RST1; end
            end
            S_RST1: begin
                int_low<=1'b1; int_high<=1'b0;
                tp_rst<=1'b1;
                if (dly==0) begin dly<=RST_HIGH_CYCLES; st<=S_REL; end
            end
            S_REL: begin
                int_low<=0; int_high<=0;
                if (dly==0) begin dly<=INIT_WAIT_CYCLES; st<=S_CLR_REQ; end
            end

            S_CLR_REQ: begin
                wr_req<=1'b1; ra<=16'h814E; wd<=8'h00; st<=S_CLR_WAIT;
            end
            S_CLR_WAIT: if (rw_done) begin
                wr_req<=1'b0; reg_wack<=(nack_any==1'b0);
                if (!init_done) begin init_done<=1'b1; st<=S_ID_REQ; end
                else begin dly<=POLL_GAP_CYCLES; st<=S_GAP; end
            end

            S_ID_REQ: begin
                rd_req<=1'b1; ra<=16'h8140; rd_num<=4'd3; st<=S_ID_WAIT;
            end
            S_ID_WAIT: if (rw_done) begin
                rd_req<=1'b0;
                id0<=rddata[15:8]; id1<=rddata[23:16]; id2<=rddata[31:24];
                st<=S_CFG_REQ;
            end

            S_CFG_REQ: begin
                rd_req<=1'b1; ra<=16'h8047; rd_num<=4'd1; st<=S_CFG_WAIT;
            end
            S_CFG_WAIT: if (rw_done) begin
                rd_req<=1'b0; cfgver<=rddata[31:24]; st<=S_STA_REQ;
            end

            S_STA_REQ: begin
                rd_req<=1'b1; ra<=16'h814E; rd_num<=4'd1; st<=S_STA_WAIT;
            end
            S_STA_WAIT: if (rw_done) begin
                rd_req<=1'b0; status<=rddata[31:24];
                if (rddata[31] && rddata[27:24]!=0 && rddata[27:24]<=5)
                    st<=S_P1_REQ;
                else begin
                    down<=1'b0;
                    st<=S_CLR_REQ;
                end
            end

            S_P1_REQ: begin
                rd_req<=1'b1; ra<=16'h8150; rd_num<=4'd4; st<=S_P1_WAIT;
            end
            S_P1_WAIT: if (rw_done) begin
                rd_req<=1'b0;
                p0[0]<=rddata[7:0]; p0[1]<=rddata[15:8];
                p0[2]<=rddata[23:16]; p0[3]<=rddata[31:24];
                st<=S_P2_REQ;
            end

            S_P2_REQ: begin
                rd_req<=1'b1; ra<=16'h8153; rd_num<=4'd4; st<=S_P2_WAIT;
            end
            S_P2_WAIT: if (rw_done) begin
                rd_req<=1'b0;
                p1[0]<=rddata[7:0]; p1[1]<=rddata[15:8];
                p1[2]<=rddata[23:16]; p1[3]<=rddata[31:24];
                x <= {p0[2], p0[1]};
                y <= {rddata[15:8], p0[3]};
                down <= 1'b1;
                st<=S_CLR_REQ;
            end

            S_GAP: begin
                down<=1'b0;
                if (dly==0) st<=S_STA_REQ;
            end
            default: st<=S_RST0;
            endcase

        end
    end
endmodule
