`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: dds_amplitude_scale
// Description:
//     Test-only DDS amplitude scaler. All outputs are saturated to signed 16 bit.
//     Amp_Sel mapping: 0=100%, 1=75%, 2=50%, 3=25%, 4=10.16%, 5=125%.
//////////////////////////////////////////////////////////////////////////////////

module dds_amplitude_scale(
    input  wire signed [15:0] sample_in,
    input  wire        [2:0] amp_sel,
    output reg  signed [15:0] sample_out
);

    reg signed [19:0] x;
    reg signed [19:0] scaled;

    always @(*) begin
        x = {{4{sample_in[15]}}, sample_in};
        case (amp_sel)
            3'd0: scaled = x;                              // 100%
            3'd1: scaled = (x >>> 1) + (x >>> 2);         // 75%
            3'd2: scaled = x >>> 1;                       // 50%
            3'd3: scaled = x >>> 2;                       // 25%
            3'd4: scaled = (x * 20'sd13) >>> 7;           // 10.15625%
            3'd5: scaled = x + (x >>> 2);                 // 125%
            default: scaled = x;
        endcase

        if (scaled > 20'sd32767)
            sample_out = 16'sh7fff;
        else if (scaled < -20'sd32768)
            sample_out = 16'sh8000;
        else
            sample_out = scaled[15:0];
    end

endmodule
