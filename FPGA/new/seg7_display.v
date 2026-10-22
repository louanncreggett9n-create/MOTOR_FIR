`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: seg7_display
// Description:
//     Standalone two-digit time-multiplexed driver for the onboard 74HC595 display.
//     Right digit (SEL bit0): upload path code 1/2/3/E
//     Left adjacent digit (SEL bit1): ADC channel 0-7 in ADC mode,
//     or DDS amplitude code 1-6 in DDS mode
//
//     Amplitude code mapping:
//       1=100%, 2=75%, 3=50%, 4=25%, 5=10.16%, 6=125%
//////////////////////////////////////////////////////////////////////////////////

module seg7_display(
    input  wire       CLK,
    input  wire       Reset_n,
    input  wire [1:0] channel_sel,
    input  wire [2:0] left_sel,
    output reg        SEG7_DIO,
    output reg        SEG7_RCLK,
    output reg        SEG7_SCLK
);

    parameter CLOCK_FREQ = 50_000_000;
    parameter SRCLK_FREQ = 12_200_000;
    localparam MCNT = CLOCK_FREQ / (SRCLK_FREQ * 2) - 1;

    reg [29:0] div_counter;
    reg [4:0]  counter;
    reg [1:0]  channel_q;
    reg [2:0]  left_q;
    reg        digit_phase;
    reg [7:0]  seg_byte;
    reg [7:0]  digit_sel;

    always @(*) begin
        if (!digit_phase) begin
            digit_sel = 8'b0000_0001;
            case (channel_q)
                2'd0: seg_byte = 8'hF9; // 1
                2'd1: seg_byte = 8'hA4; // 2
                2'd2: seg_byte = 8'hB0; // 3
                2'd3: seg_byte = 8'h86; // E
                default: seg_byte = 8'hFF;
            endcase
        end else begin
            digit_sel = 8'b0000_0010;
            case (left_q)
                3'd0: seg_byte = 8'hC0; // 0
                3'd1: seg_byte = 8'hF9; // 1
                3'd2: seg_byte = 8'hA4; // 2
                3'd3: seg_byte = 8'hB0; // 3
                3'd4: seg_byte = 8'h99; // 4
                3'd5: seg_byte = 8'h92; // 5
                3'd6: seg_byte = 8'h82; // 6
                3'd7: seg_byte = 8'hF8; // 7
                default: seg_byte = 8'hFF;
            endcase
        end
    end

    always @(posedge CLK or negedge Reset_n) begin
        if (!Reset_n)
            div_counter <= 30'd0;
        else if (div_counter == MCNT)
            div_counter <= 30'd0;
        else
            div_counter <= div_counter + 1'b1;
    end

    always @(posedge CLK or negedge Reset_n) begin
        if (!Reset_n)
            counter <= 5'd0;
        else if (div_counter == MCNT)
            counter <= (counter == 5'd31) ? 5'd0 : counter + 1'b1;
    end

    always @(posedge CLK or negedge Reset_n) begin
        if (!Reset_n) begin
            channel_q   <= 2'd0;
            left_q      <= 3'd0;
            digit_phase <= 1'b0;
            SEG7_DIO    <= 1'b0;
            SEG7_SCLK   <= 1'b0;
            SEG7_RCLK   <= 1'b0;
        end else begin
            if ((counter == 5'd31) && (div_counter == MCNT)) begin
                channel_q   <= channel_sel;
                left_q      <= left_sel;
                digit_phase <= ~digit_phase;
            end

            case (counter)
                5'd0:  begin SEG7_DIO <= seg_byte[7];  SEG7_SCLK <= 1'b0; SEG7_RCLK <= 1'b1; end
                5'd1:  begin                             SEG7_SCLK <= 1'b1; SEG7_RCLK <= 1'b0; end
                5'd2:  begin SEG7_DIO <= seg_byte[6];  SEG7_SCLK <= 1'b0; end
                5'd3:  begin                             SEG7_SCLK <= 1'b1; end
                5'd4:  begin SEG7_DIO <= seg_byte[5];  SEG7_SCLK <= 1'b0; end
                5'd5:  begin                             SEG7_SCLK <= 1'b1; end
                5'd6:  begin SEG7_DIO <= seg_byte[4];  SEG7_SCLK <= 1'b0; end
                5'd7:  begin                             SEG7_SCLK <= 1'b1; end
                5'd8:  begin SEG7_DIO <= seg_byte[3];  SEG7_SCLK <= 1'b0; end
                5'd9:  begin                             SEG7_SCLK <= 1'b1; end
                5'd10: begin SEG7_DIO <= seg_byte[2];  SEG7_SCLK <= 1'b0; end
                5'd11: begin                             SEG7_SCLK <= 1'b1; end
                5'd12: begin SEG7_DIO <= seg_byte[1];  SEG7_SCLK <= 1'b0; end
                5'd13: begin                             SEG7_SCLK <= 1'b1; end
                5'd14: begin SEG7_DIO <= seg_byte[0];  SEG7_SCLK <= 1'b0; end
                5'd15: begin                             SEG7_SCLK <= 1'b1; end
                5'd16: begin SEG7_DIO <= digit_sel[7]; SEG7_SCLK <= 1'b0; end
                5'd17: begin                             SEG7_SCLK <= 1'b1; end
                5'd18: begin SEG7_DIO <= digit_sel[6]; SEG7_SCLK <= 1'b0; end
                5'd19: begin                             SEG7_SCLK <= 1'b1; end
                5'd20: begin SEG7_DIO <= digit_sel[5]; SEG7_SCLK <= 1'b0; end
                5'd21: begin                             SEG7_SCLK <= 1'b1; end
                5'd22: begin SEG7_DIO <= digit_sel[4]; SEG7_SCLK <= 1'b0; end
                5'd23: begin                             SEG7_SCLK <= 1'b1; end
                5'd24: begin SEG7_DIO <= digit_sel[3]; SEG7_SCLK <= 1'b0; end
                5'd25: begin                             SEG7_SCLK <= 1'b1; end
                5'd26: begin SEG7_DIO <= digit_sel[2]; SEG7_SCLK <= 1'b0; end
                5'd27: begin                             SEG7_SCLK <= 1'b1; end
                5'd28: begin SEG7_DIO <= digit_sel[1]; SEG7_SCLK <= 1'b0; end
                5'd29: begin                             SEG7_SCLK <= 1'b1; end
                5'd30: begin SEG7_DIO <= digit_sel[0]; SEG7_SCLK <= 1'b0; end
                5'd31: begin                             SEG7_SCLK <= 1'b1; end
                default: begin SEG7_DIO <= 1'b0; SEG7_SCLK <= 1'b0; SEG7_RCLK <= 1'b0; end
            endcase
        end
    end

endmodule
