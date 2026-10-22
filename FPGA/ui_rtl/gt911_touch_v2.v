`timescale 1ns / 1ps
// GT911 single-touch port based on the vendor AC620_PIANO GT9147 driver.
// Address selection is copied verbatim from the vendor reset sequence:
//   RST=0,INT=0 -> RST=0,INT=1 -> RST=1,INT=1 -> release INT.
// The I2C controller is the unmodified vendor i2c_control/i2c_bit_shift pair.
module gt911_touch_v2 #(
    parameter [21:0] RST_LOW_CYCLES    = 22'd500_000, // 10 ms @ 50 MHz
    parameter [21:0] SELECT_LOW_CYCLES = 22'd10_000,  // 200 us
    parameter [21:0] RST_HIGH_CYCLES   = 22'd500_000, // 10 ms
    parameter [21:0] INIT_WAIT_CYCLES  = 22'd250_000, // 5 ms
    parameter [21:0] POLL_GAP_CYCLES   = 22'd50_000   // 1 ms
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
    output wire [3:0] byte_nack_o,
    output reg [2:0]  state_o
);
    localparam WR=6'b000001, STA=6'b000010, RD=6'b000100,
               STO=6'b001000, ACK=6'b010000, NACK=6'b100000;

    // Vendor reset/address-selection levels.
    reg int_low, int_high;
    assign tp_int = int_low ? 1'b0 : (int_high ? 1'b1 : 1'bz);

    // Vendor debounce/synchronizer from the piano example.
    wire tp_int_state;
    key_filter u_int_filter (
        .Clk(clk), .Rst_n(rst_n), .key_in(tp_int),
        .key_flag(), .key_state(tp_int_state)
    );

    reg [7:0] device_id_r;
    reg       attempt_low;
    reg wr_req, rd_req;
    reg [3:0] rd_num;
    reg [15:0] ra;
    reg [7:0] wd;
    wire [31:0] rddata;
    wire rw_done;
    wire nack_any;
    wire [3:0] byte_nack_n;

    i2c_control u_i2c (
        .Clk(clk), .Rst_n(rst_n),
        .wrreg_req(wr_req), .rdreg_req(rd_req), .rdreg_num(rd_num),
        .addr(ra), .addr_mode(1'b1), .wrdata(wd), .rddata(rddata),
        .device_id(device_id_r), .RW_Done(rw_done), .ack(nack_any), .byte_nack(byte_nack_n),
        .i2c_sclk(tp_scl), .i2c_sdat(tp_sda)
    );

    localparam S_RST_LOW=0, S_SEL_HIGH=1, S_RST_HIGH=2, S_BOOT_WAIT=3,
               S_ID_REQ=4, S_ID_WAIT=5, S_WAIT_INT=6,
               S_STA_REQ=7, S_STA_WAIT=8, S_P1_REQ=9, S_P1_WAIT=10,
               S_P2_REQ=11, S_P2_WAIT=12, S_CLR_REQ=13, S_CLR_WAIT=14,
               S_GAP=15;

    reg [3:0] st;
    reg [21:0] dly;
    reg [7:0] id0, id1, id2, cfgver, status;
    reg [7:0] trans_cnt;
    reg [1:0] bus_idle;
    reg [15:0] stable_cnt;
    reg ack_ok, reg_wack;
    reg [7:0] p0 [0:3];
    reg [7:0] p1 [0:3];

    assign ack_o = ack_ok;
    assign status_o = status;
    assign addr_o = 7'h14;
    assign id0_o=id0; assign id1_o=id1; assign id2_o=id2;
    assign idb0_o=id0; assign idb1_o=id1; assign idb2_o=id2;
    assign cfgver_o=cfgver;
    assign trans_cnt_o=trans_cnt;
    assign bus_idle_o=bus_idle;
    assign reg_wack_o=reg_wack;
    assign byte_nack_o=byte_nack_n;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            int_low<=1'b0; int_high<=1'b1; tp_rst<=1'b1;
            device_id_r<=8'h28; attempt_low<=1'b0;
            wr_req<=0; rd_req<=0; rd_num<=0; ra<=0; wd<=0;
            st<=S_RST_LOW; dly<=0; x<=0; y<=0; down<=0; state_o<=0;
            id0<=0; id1<=0; id2<=0; cfgver<=0; status<=0; trans_cnt<=0;
            bus_idle<=2'b11; stable_cnt<=0; ack_ok<=0; reg_wack<=0;
            p0[0]<=0; p0[1]<=0; p0[2]<=0; p0[3]<=0;
            p1[0]<=0; p1[1]<=0; p1[2]<=0; p1[3]<=0;
        end else begin
            state_o <= st[2:0];
            if (dly != 0) dly <= dly - 1'b1;

            if (!wr_req && !rd_req && st!=S_ID_REQ && st!=S_STA_REQ &&
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
            // Match the known-good scan path: RST high, INT high to wake, then release INT.
            S_RST_LOW: begin
                int_low<=1'b0; int_high<=1'b1; tp_rst<=1'b1;
                if (dly==0) begin dly<=INIT_WAIT_CYCLES; st<=S_SEL_HIGH; end
            end
            S_SEL_HIGH: begin
                int_low<=1'b0; int_high<=1'b0; tp_rst<=1'b1;
                if (dly==0) st<=S_ID_REQ;
            end
            S_RST_HIGH: begin
                int_low<=1'b0; int_high<=1'b0; tp_rst<=1'b1; st<=S_ID_REQ;
            end
            S_BOOT_WAIT: begin
                int_low<=1'b0; int_high<=1'b0; tp_rst<=1'b1; st<=S_ID_REQ;
            end

            S_ID_REQ: begin
                rd_req<=1'b1; ra<=16'h8140; rd_num<=4'd3; st<=S_ID_WAIT;
            end

            S_ID_WAIT: if (rw_done) begin
                rd_req<=1'b0;
                id0<=rddata[15:8]; id1<=rddata[23:16]; id2<=rddata[31:24];
                reg_wack<=(nack_any==1'b0);
                st<=S_WAIT_INT;
            end
            S_WAIT_INT: begin
                // Keep down asserted for the whole contact interval.
                if (tp_int_state) st<=S_STA_REQ;
            end
            S_STA_REQ: begin
                rd_req<=1'b1; ra<=16'h814E; rd_num<=4'd1; st<=S_STA_WAIT;
            end
            S_STA_WAIT: if (rw_done) begin
                rd_req<=1'b0;
                status<=rddata[31:24];
                if (rddata[31] && rddata[27:24]!=0 && rddata[27:24]<=5)
                    st<=S_P1_REQ;
                else begin
                    // Buffer-ready with zero points is the release event.
                    if (rddata[31] && rddata[27:24]==0) down<=1'b0;
                    st<=S_CLR_REQ;
                end
            end

            // Start at 0x814F: track id, X low/high, Y low.
            S_P1_REQ: begin
                rd_req<=1'b1; ra<=16'h814F; rd_num<=4'd4; st<=S_P1_WAIT;
            end
            S_P1_WAIT: if (rw_done) begin
                rd_req<=1'b0;
                p0[0]<=rddata[7:0]; p0[1]<=rddata[15:8];
                p0[2]<=rddata[23:16]; p0[3]<=rddata[31:24];
                st<=S_P2_REQ;
            end

            // Continue at 0x8153: Y high, size low/high, reserved.
            S_P2_REQ: begin
                rd_req<=1'b1; ra<=16'h8153; rd_num<=4'd4; st<=S_P2_WAIT;
            end
            S_P2_WAIT: if (rw_done) begin
                rd_req<=1'b0;
                p1[0]<=rddata[7:0]; p1[1]<=rddata[15:8];
                p1[2]<=rddata[23:16]; p1[3]<=rddata[31:24];
                x <= {p0[2], p0[1]};
                y <= {rddata[7:0], p0[3]};
                down <= 1'b1;
                st<=S_CLR_REQ;
            end

            S_CLR_REQ: begin
                wr_req<=1'b1; ra<=16'h814E; wd<=8'h00; st<=S_CLR_WAIT;
            end
            S_CLR_WAIT: if (rw_done) begin
                wr_req<=1'b0;
                reg_wack<=(nack_any==1'b0);
                dly<=POLL_GAP_CYCLES;
                st<=S_GAP;
            end
            S_GAP: begin
                if (dly==0) st<=S_WAIT_INT;
            end
            default: st<=S_RST_LOW;
            endcase
        end
    end
endmodule
