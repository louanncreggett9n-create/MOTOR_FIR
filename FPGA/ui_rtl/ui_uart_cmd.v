`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Display command frame receiver
//   A5 5A | len | cmd | payload[len] | sum
//   sum = 8-bit sum of len, cmd and payload
//   cmd 0x10 : payload = class, conf_x100, sev, route
//     class 0..5 = H / UNBAL / MISAL / BF / BOW / BROKEN, other = ---
//     route bit0: 0 = SOURCE, 1 = HW-CHAIN
//////////////////////////////////////////////////////////////////////////////////
module ui_uart_cmd(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx_flag,
    input  wire [7:0] rx_data,
    output reg  [3:0] cls,
    output reg  [7:0] conf,
    output reg  [3:0] sev,
    output reg        route,
    output reg        upd
);
    localparam S_IDLE = 3'd0, S_SOF2 = 3'd1, S_LEN = 3'd2, S_CMD = 3'd3,
               S_PAY = 3'd4, S_SUM = 3'd5;

    reg [2:0] st;
    reg [3:0] len, cnt;
    reg [7:0] cmd, sum;
    reg [7:0] p0, p1, p2, p3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            st <= S_IDLE; len <= 4'd0; cnt <= 4'd0; cmd <= 8'd0; sum <= 8'd0;
            p0 <= 8'd0; p1 <= 8'd0; p2 <= 8'd0; p3 <= 8'd0;
            cls <= 4'd6; conf <= 8'd0; sev <= 4'd0; route <= 1'b0; upd <= 1'b0;
        end else begin
            upd <= 1'b0;
            if (rx_flag) begin
                case (st)
                S_IDLE: if (rx_data == 8'hA5) st <= S_SOF2;
                S_SOF2: st <= (rx_data == 8'h5A) ? S_LEN : S_IDLE;
                S_LEN:  begin
                            len <= (rx_data > 8'd8) ? 4'd8 : rx_data[3:0];
                            sum <= rx_data;
                            st  <= S_CMD;
                        end
                S_CMD:  begin
                            cmd <= rx_data;
                            sum <= sum + rx_data;
                            cnt <= 4'd0;
                            st  <= (len == 4'd0) ? S_SUM : S_PAY;
                        end
                S_PAY:  begin
                            sum <= sum + rx_data;
                            case (cnt)
                            4'd0: p0 <= rx_data;
                            4'd1: p1 <= rx_data;
                            4'd2: p2 <= rx_data;
                            4'd3: p3 <= rx_data;
                            default: ;
                            endcase
                            if (cnt + 4'd1 >= len) st <= S_SUM;
                            else cnt <= cnt + 4'd1;
                        end
                S_SUM:  begin
                            if (rx_data == sum) begin
                                if (cmd == 8'h10) begin
                                    cls   <= (p0 > 8'd5) ? 4'd6 : p0[3:0];
                                    conf  <= (p1 > 8'd100) ? 8'd100 : p1;
                                    sev   <= (p2 > 8'd9) ? 4'd9 : p2[3:0];
                                    route <= p3[0];
                                    upd   <= 1'b1;
                                end
                            end
                            st <= S_IDLE;
                        end
                default: st <= S_IDLE;
                endcase
            end
        end
    end
endmodule