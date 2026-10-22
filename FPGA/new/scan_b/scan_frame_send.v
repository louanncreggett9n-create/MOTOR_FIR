`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: scan_frame_send
// Description:
//     UART frame sender for the B-scheme scan results.
//     It sends 128 bin frames followed automatically by one summary frame.
//     Frame: 0xAB, bin_idx, Xr[23:16], Xr[15:8], Xr[7:0],
//            Xi[23:16], Xi[15:8], Xi[7:0], status, checksum.
//////////////////////////////////////////////////////////////////////////////////

module scan_frame_send(
    input                CLK,
    input                Reset_n,
    input                Send,
    input      [7:0]     Bin_Idx,
    input      signed [23:0] Xr,
    input      signed [23:0] Xi,
    input      [7:0]     Status,
    input      [7:0]     Summary_Bin_Idx,
    input      signed [23:0] Summary_Xr,
    input      signed [23:0] Summary_Xi,
    input      [7:0]     Summary_Status,
    input                Tx_Flag,
    output reg [7:0]     Tx_Data,
    output reg           Tx_Go,
    output reg           Frame_Busy
);

    localparam IDLE = 2'd0;
    localparam SEND = 2'd1;
    localparam WAIT = 2'd2;

    reg [1:0]  state;
    reg [3:0]  byte_idx;
    reg [7:0]  r_idx;
    reg signed [23:0] r_xr;
    reg signed [23:0] r_xi;
    reg [7:0]  r_status;
    reg [7:0]  r_byte;
    reg        is_summary;
    reg [7:0]  frame_count;

    wire [7:0] W_Sum = 8'hAB + r_idx +
                       r_xr[23:16] + r_xr[15:8] + r_xr[7:0] +
                       r_xi[23:16] + r_xi[15:8] + r_xi[7:0] +
                       r_status;

    always @(*)
    begin
        case(byte_idx)
            4'd0: r_byte = 8'hAB;
            4'd1: r_byte = r_idx;
            4'd2: r_byte = r_xr[23:16];
            4'd3: r_byte = r_xr[15:8];
            4'd4: r_byte = r_xr[7:0];
            4'd5: r_byte = r_xi[23:16];
            4'd6: r_byte = r_xi[15:8];
            4'd7: r_byte = r_xi[7:0];
            4'd8: r_byte = r_status;
            4'd9: r_byte = W_Sum;
            default: r_byte = 8'h00;
        endcase
    end

    always @(posedge CLK or negedge Reset_n)
    begin
        if(!Reset_n)
        begin
            state       <= IDLE;
            byte_idx    <= 4'd0;
            r_idx       <= 8'd0;
            r_xr        <= 24'sd0;
            r_xi        <= 24'sd0;
            r_status    <= 8'd0;
            is_summary  <= 1'b0;
            frame_count <= 8'd0;
            Tx_Go       <= 1'b0;
            Tx_Data     <= 8'h00;
            Frame_Busy  <= 1'b0;
        end
        else
        begin
            case(state)
                IDLE:
                begin
                    Tx_Go      <= 1'b0;
                    Frame_Busy <= 1'b0;
                    if(Send)
                    begin
                        r_idx      <= Bin_Idx;
                        r_xr       <= Xr;
                        r_xi       <= Xi;
                        r_status   <= Status;
                        is_summary <= 1'b0;
                        byte_idx   <= 4'd0;
                        state      <= SEND;
                    end
                end

                SEND:
                begin
                    Tx_Go      <= 1'b1;
                    Tx_Data    <= r_byte;
                    Frame_Busy <= 1'b1;
                    state      <= WAIT;
                end

                WAIT:
                begin
                    Tx_Go <= 1'b0;
                    if(Tx_Flag)
                    begin
                        if(byte_idx == 4'd9)
                        begin
                            if(!is_summary && (frame_count == 8'd127))
                            begin
                                r_idx       <= Summary_Bin_Idx;
                                r_xr        <= Summary_Xr;
                                r_xi        <= Summary_Xi;
                                r_status    <= Summary_Status;
                                is_summary  <= 1'b1;
                                frame_count <= 8'd0;
                                byte_idx    <= 4'd0;
                                state       <= SEND;
                                Frame_Busy  <= 1'b1;
                            end
                            else if(!is_summary)
                            begin
                                frame_count <= frame_count + 8'd1;
                                state       <= IDLE;
                                Frame_Busy  <= 1'b0;
                            end
                            else
                            begin
                                is_summary  <= 1'b0;
                                frame_count <= 8'd0;
                                state       <= IDLE;
                                Frame_Busy  <= 1'b0;
                            end
                        end
                        else
                        begin
                            byte_idx <= byte_idx + 4'd1;
                            state    <= SEND;
                        end
                    end
                end

                default:
                    state <= IDLE;
            endcase
        end
    end

endmodule
