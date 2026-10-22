`timescale 1ns / 1ps
// Writes three touch diagnostic lines into rows 26/27/28 of the 100x30
// character plane, columns 60..75:
//   X:XXX Y:XXX D:X
//   I:39 31 31 N:xx
//   S:XX A:XX K:X
//   B:11 W:1 N:xx
//   J:39 31 31
module ui_touch_dbg(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [9:0]  x,
    input  wire [9:0]  y,
    input  wire        down,
    input  wire [7:0]  status,
    input  wire [6:0]  addr,
    input  wire        ack,
    input  wire [7:0]  id0,
    input  wire [7:0]  id1,
    input  wire [7:0]  id2,
    input  wire [7:0]  idb0, idb1, idb2,
    input  wire [7:0]  cfgver,
    input  wire [7:0]  trans_cnt,
    input  wire [1:0]  bus_idle,
    input  wire        reg_wack,
    input  wire [3:0]  byte_nack,
    output reg         wr_en,
    output reg  [11:0] wr_addr,
    output reg  [7:0]  wr_data
);
    reg [23:0] tick;
    reg [6:0]  idx;
    reg        run;

    function [7:0] hex_ch;
        input [3:0] v;
        begin
            case (v)
            4'h0: hex_ch = "0"; 4'h1: hex_ch = "1"; 4'h2: hex_ch = "2"; 4'h3: hex_ch = "3";
            4'h4: hex_ch = "4"; 4'h5: hex_ch = "5"; 4'h6: hex_ch = "6"; 4'h7: hex_ch = "7";
            4'h8: hex_ch = "8"; 4'h9: hex_ch = "9"; 4'hA: hex_ch = "A"; 4'hB: hex_ch = "B";
            4'hC: hex_ch = "C"; 4'hD: hex_ch = "D"; 4'hE: hex_ch = "E"; default: hex_ch = "F";
            endcase
        end
    endfunction

    wire [11:0] x12 = {2'b0, x};
    wire [11:0] y12 = {2'b0, y};

    function [7:0] row_x;       // row 26: coordinates and down
        input [3:0] i;
        begin
            row_x = 8'h20;
            case (i)
            4'd0: row_x = "X"; 4'd1: row_x = ":";
            4'd2: row_x = hex_ch(x12[11:8]);
            4'd3: row_x = hex_ch(x12[7:4]);
            4'd4: row_x = hex_ch(x12[3:0]);
            4'd5: row_x = " ";
            4'd6: row_x = "Y"; 4'd7: row_x = ":";
            4'd8: row_x = hex_ch(y12[11:8]);
            4'd9: row_x = hex_ch(y12[7:4]);
            4'd10: row_x = hex_ch(y12[3:0]);
            4'd11: row_x = " ";
            4'd12: row_x = "D"; 4'd13: row_x = ":";
            4'd14: row_x = down ? "1" : "0";
            default: row_x = 8'h20;
            endcase
        end
    endfunction

    function [7:0] row_id;      // row 27: product ID and config version
        input [3:0] i;
        begin
            row_id = 8'h20;
            case (i)
            4'd0: row_id = "I"; 4'd1: row_id = ":";
            4'd2: row_id = hex_ch(id0[7:4]);
            4'd3: row_id = hex_ch(id0[3:0]);
            4'd4: row_id = " ";
            4'd5: row_id = hex_ch(id1[7:4]);
            4'd6: row_id = hex_ch(id1[3:0]);
            4'd7: row_id = " ";
            4'd8: row_id = hex_ch(id2[7:4]);
            4'd9: row_id = hex_ch(id2[3:0]);
            4'd10: row_id = " ";
            4'd11: row_id = " ";
            4'd12: row_id = " ";
            4'd13: row_id = " ";
            4'd14: row_id = " ";
            default: row_id = 8'h20;
            endcase
        end
    endfunction

    function [7:0] row_idb;     // row 29: per-byte NACK flags
        input [3:0] i;
        begin
            row_idb = 8'h20;
            case (i)
            4'd0: row_idb = "Q"; 4'd1: row_idb = ":";
            4'd2: row_idb = byte_nack[3] ? "1" : "0";
            4'd3: row_idb = byte_nack[2] ? "1" : "0";
            4'd4: row_idb = byte_nack[1] ? "1" : "0";
            4'd5: row_idb = byte_nack[0] ? "1" : "0";
            default: row_idb = 8'h20;
            endcase
        end
    endfunction

    function [7:0] row_st;      // row 28: status, current address, address ACK
        input [3:0] i;
        begin
            row_st = 8'h20;
            case (i)
            4'd0: row_st = "S"; 4'd1: row_st = ":";
            4'd2: row_st = hex_ch(status[7:4]);
            4'd3: row_st = hex_ch(status[3:0]);
            4'd4: row_st = " ";
            4'd5: row_st = "A"; 4'd6: row_st = ":";
            4'd7: row_st = (addr == 7'h5D) ? "5" : (addr == 7'h14) ? "1" : "?";
            4'd8: row_st = (addr == 7'h5D) ? "D" : (addr == 7'h14) ? "4" : "?";
            4'd9: row_st = " ";
            4'd10: row_st = "K"; 4'd11: row_st = ":";
            4'd12: row_st = ack ? "1" : "0";
            default: row_st = 8'h20;
            endcase
        end
    endfunction

    function [7:0] row_bus;    // row 25: idle bus levels, register-write ACK, transaction count
        input [3:0] i;
        begin
            row_bus = 8'h20;
            case (i)
            4'd0: row_bus = "B"; 4'd1: row_bus = ":";
            4'd2: row_bus = bus_idle[1] ? "1" : "0";
            4'd3: row_bus = bus_idle[0] ? "1" : "0";
            4'd4: row_bus = " ";
            4'd5: row_bus = "W"; 4'd6: row_bus = ":";
            4'd7: row_bus = reg_wack ? "1" : "0";
            4'd8: row_bus = " ";
            4'd9: row_bus = "N"; 4'd10: row_bus = ":";
            4'd11: row_bus = hex_ch(trans_cnt[7:4]);
            4'd12: row_bus = hex_ch(trans_cnt[3:0]);
            default: row_bus = 8'h20;
            endcase
        end
    endfunction

    function [7:0] dbg_ch;
        input [6:0] i;
        begin
            if (i < 7'd16)
                dbg_ch = row_x(i[3:0]);
            else if (i < 7'd32)
                dbg_ch = row_id(i[3:0]);
            else if (i < 7'd48)
                dbg_ch = row_st(i[3:0]);
            else if (i < 7'd64)
                dbg_ch = row_bus(i[3:0]);
            else
                dbg_ch = row_idb(i[3:0]);
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tick <= 24'd0; idx <= 7'd0; run <= 1'b0;
            wr_en <= 1'b0; wr_addr <= 12'd0; wr_data <= 8'd0;
        end else begin
            wr_en <= 1'b0;
            if (tick == 24'd9_999_999) begin
                tick <= 24'd0;
                run  <= 1'b1;
                idx  <= 7'd0;
            end else begin
                tick <= tick + 24'd1;
            end

            if (run) begin
                wr_en <= 1'b1;
                if (idx < 7'd16)
                    wr_addr <= 12'd2600 + 12'd60 + {6'd0, idx};
                else if (idx < 7'd32)
                    wr_addr <= 12'd2700 + 12'd60 + {6'd0, idx[3:0]};
                else if (idx < 7'd48)
                    wr_addr <= 12'd2800 + 12'd60 + {6'd0, idx[3:0]};
                else if (idx < 7'd64)
                    wr_addr <= 12'd2500 + 12'd60 + {6'd0, idx[3:0]};
                else
                    wr_addr <= 12'd2900 + 12'd60 + {6'd0, idx[3:0]};
                wr_data <= dbg_ch(idx);
                if (idx == 7'd79) begin
                    run <= 1'b0;
                    idx <= 7'd0;
                end else begin
                    idx <= idx + 7'd1;
                end
            end
        end
    end
endmodule
