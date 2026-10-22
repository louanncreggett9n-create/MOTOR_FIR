`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Writes the diagnosis fields into the character plane when a display frame
// arrives:  CLASS row18 col60..67, CONF row20 col60..63,
//           SEV row22 col60, ROUTE row24 col60..67
//////////////////////////////////////////////////////////////////////////////////
module ui_text_wr(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [3:0]  cls,
    input  wire [7:0]  conf,
    input  wire [3:0]  sev,
    input  wire        route,
    output reg         wr_en,
    output reg  [11:0] wr_addr,
    output reg  [7:0]  wr_data,
    output wire        busy
);
    reg [4:0] idx;
    reg       run;

    function [7:0] cls_ch;
        input [3:0] c;
        input [3:0] i;
        begin
            cls_ch = 8'h20;
            case (c)
            4'd0: if (i == 4'd0) cls_ch = "H";
            4'd1: case (i) 4'd0: cls_ch="U"; 4'd1: cls_ch="N"; 4'd2: cls_ch="B";
                          4'd3: cls_ch="A"; 4'd4: cls_ch="L"; default: ; endcase
            4'd2: case (i) 4'd0: cls_ch="M"; 4'd1: cls_ch="I"; 4'd2: cls_ch="S";
                          4'd3: cls_ch="A"; 4'd4: cls_ch="L"; default: ; endcase
            4'd3: if (i == 4'd0) cls_ch = "B"; else if (i == 4'd1) cls_ch = "F";
            4'd4: if (i == 4'd0) cls_ch = "B"; else if (i == 4'd1) cls_ch = "O";
                  else if (i == 4'd2) cls_ch = "W";
            4'd5: case (i) 4'd0: cls_ch="B"; 4'd1: cls_ch="R"; 4'd2: cls_ch="O";
                          4'd3: cls_ch="K"; 4'd4: cls_ch="E"; 4'd5: cls_ch="N";
                          default: ; endcase
            default: if (i < 4'd3) cls_ch = "-";
            endcase
        end
    endfunction

    function [7:0] rt_ch;
        input r;
        input [3:0] i;
        begin
            case (i)
            4'd0: rt_ch = r ? "H" : "S";
            4'd1: rt_ch = r ? "W" : "O";
            4'd2: rt_ch = r ? "-" : "U";
            4'd3: rt_ch = r ? "C" : "R";
            4'd4: rt_ch = r ? "H" : "C";
            4'd5: rt_ch = r ? "A" : "E";
            4'd6: rt_ch = r ? "I" : " ";
            default: rt_ch = r ? "N" : " ";
            endcase
        end
    endfunction

    wire onehundred = (conf >= 8'd100);
    wire [3:0] cten  = onehundred ? 4'd0 : (conf / 8'd10);
    wire [3:0] cone  = onehundred ? 4'd0 : (conf % 8'd10);

    assign busy = run;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            run <= 1'b0; idx <= 5'd0; wr_en <= 1'b0; wr_addr <= 12'd0; wr_data <= 8'd0;
        end else begin
            wr_en <= 1'b0;
            if (!run) begin
                if (start) begin run <= 1'b1; idx <= 5'd0; end
            end else begin
                wr_en <= 1'b1;
                if (idx < 5'd8) begin
                    wr_addr <= 12'd1800 + 12'd60 + {7'd0, idx};
                    wr_data <= cls_ch(cls, idx[3:0]);
                end else if (idx < 5'd12) begin
                    wr_addr <= 12'd2000 + 12'd60 + {7'd0, (idx - 5'd8)};
                    case (idx)
                    5'd8:  wr_data <= "0";
                    5'd9:  wr_data <= ".";
                    5'd10: wr_data <= onehundred ? "0" : (8'h30 + {4'd0, cten});
                    default: wr_data <= onehundred ? "0" : (8'h30 + {4'd0, cone});
                    endcase
                end else if (idx == 5'd12) begin
                    wr_addr <= 12'd2200 + 12'd60;
                    wr_data <= 8'h30 + {4'd0, sev};
                end else begin
                    wr_addr <= 12'd2400 + 12'd60 + {7'd0, (idx - 5'd13)};
                    wr_data <= rt_ch(route, idx - 5'd13);
                end
                if (idx == 5'd20) begin run <= 1'b0; idx <= 5'd0; end
                else idx <= idx + 5'd1;
            end
        end
    end
endmodule