`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: ad7606_sampler
// Description:
//     Select one AD7606 channel and present it as a signed 16-bit sample.
//     AD7606 parallel data is two's-complement for the bipolar input range.
//////////////////////////////////////////////////////////////////////////////////

module ad7606_sampler(
    input  wire               CLK,
    input  wire               Reset_n,
    input  wire [15:0]        data1,
    input  wire [15:0]        data2,
    input  wire [15:0]        data3,
    input  wire [15:0]        data4,
    input  wire [15:0]        data5,
    input  wire [15:0]        data6,
    input  wire [15:0]        data7,
    input  wire [15:0]        data8,
    input  wire [2:0]         Channel,
    input  wire               Conv_Done,
    output reg signed [15:0]  Signed_Data,
    output reg               Sample_Done
);

    reg [15:0] selected_data;

    always @(*) begin
        case (Channel)
            3'd0: selected_data = data1;
            3'd1: selected_data = data2;
            3'd2: selected_data = data3;
            3'd3: selected_data = data4;
            3'd4: selected_data = data5;
            3'd5: selected_data = data6;
            3'd6: selected_data = data7;
            default: selected_data = data8;
        endcase
    end

    always @(posedge CLK or negedge Reset_n) begin
        if (!Reset_n) begin
            Signed_Data <= 16'sd0;
            Sample_Done <= 1'b0;
        end else begin
            Sample_Done <= Conv_Done;
            if (Conv_Done)
                Signed_Data <= $signed(selected_data);
        end
    end

endmodule
