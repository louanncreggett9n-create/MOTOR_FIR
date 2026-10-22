`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Formats four 16-bit magnitudes into 5 right-aligned ASCII digits each and
// writes them into the character plane:
//     row 18 / 20 / 22 / 24, columns 6..10
// Binary -> BCD by double-dabble (16 iterations), leading zeros blanked.
//////////////////////////////////////////////////////////////////////////////////
module ui_num_fmt(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [15:0] v1,
    input  wire [15:0] v2,
    input  wire [15:0] v3,
    input  wire [15:0] v4,
    output reg         wr_en,
    output reg  [11:0] wr_addr,
    output reg  [7:0]  wr_data,
    output wire        busy
);
    localparam S_IDLE = 2'd0, S_CONV = 2'd1, S_WR = 2'd2;
    assign busy = (st != S_IDLE);

    reg [1:0]  st;
    reg [1:0]  sel;
    reg [15:0] v;
    reg [19:0] bcd;
    reg [4:0]  bitcnt;
    reg [2:0]  widx;
    reg        started;

    wire [15:0] vin = (sel == 2'd0) ? v1 : (sel == 2'd1) ? v2 : (sel == 2'd2) ? v3 : v4;
    wire [11:0] rowsel = (sel == 2'd0) ? 12'd1800 :
                         (sel == 2'd1) ? 12'd2000 :
                         (sel == 2'd2) ? 12'd2200 : 12'd2400;

    wire [3:0] n0 = bcd[3:0], n1 = bcd[7:4], n2 = bcd[11:8], n3 = bcd[15:12], n4 = bcd[19:16];
    wire [19:0] adj = bcd
        + ((n0 >= 4'd5) ? 20'd3      : 20'd0)
        + ((n1 >= 4'd5) ? 20'd48     : 20'd0)
        + ((n2 >= 4'd5) ? 20'd768    : 20'd0)
        + ((n3 >= 4'd5) ? 20'd12288  : 20'd0)
        + ((n4 >= 4'd5) ? 20'd196608 : 20'd0);

    wire [3:0] dg = (widx == 3'd0) ? bcd[19:16] :
                    (widx == 3'd1) ? bcd[15:12] :
                    (widx == 3'd2) ? bcd[11:8]  :
                    (widx == 3'd3) ? bcd[7:4]   : bcd[3:0];
    wire       last = (widx == 3'd4);
    wire       blank = (!started) && (dg == 4'd0) && (!last);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            st <= S_IDLE; wr_en <= 1'b0; wr_addr <= 12'd0; wr_data <= 8'd0;
            sel <= 2'd0; v <= 16'd0; bcd <= 20'd0; bitcnt <= 5'd0; widx <= 3'd0;
            started <= 1'b0;
        end else begin
            wr_en <= 1'b0;
            case (st)
            S_IDLE: begin
                if (start) begin
                    sel <= 2'd0; v <= v1; bcd <= 20'd0; bitcnt <= 5'd0;
                    widx <= 3'd0; started <= 1'b0; st <= S_CONV;
                end
            end
            S_CONV: begin
                bcd <= {adj[18:0], v[15]};
                v   <= {v[14:0], 1'b0};
                if (bitcnt == 5'd15) begin
                    bitcnt <= 5'd0; widx <= 3'd0; st <= S_WR;
                end else begin
                    bitcnt <= bitcnt + 5'd1;
                end
            end
            S_WR: begin
                wr_en   <= 1'b1;
                wr_addr <= rowsel + 12'd6 + {9'd0, widx};
                wr_data <= blank ? 8'h20 : (8'h30 + {4'd0, dg});
                if (!blank && dg != 4'd0) started <= 1'b1;

                if (last) begin
                    if (sel == 2'd3) begin
                        st <= S_IDLE;
                    end else begin
                        sel    <= sel + 2'd1;
                        v      <= (sel == 2'd0) ? v2 : (sel == 2'd1) ? v3 : v4;
                        bcd    <= 20'd0;
                        bitcnt <= 5'd0;
                        widx   <= 3'd0;
                        started<= 1'b0;
                        st     <= S_CONV;
                    end
                end else begin
                    widx <= widx + 3'd1;
                end
            end
            default: st <= S_IDLE;
            endcase
        end
    end
endmodule