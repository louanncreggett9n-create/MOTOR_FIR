`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: FIR_Module
// Description:
//     Wrapper for the transposed direct-form FIR filter + output scaler.
//
//     This module follows the same pattern as ADC_Sampler / DDS_Sampler:
//     - Input:  one signed 16-bit sample per SAMPLE_HZ, marked by Sample_Done
//     - Output: one filtered signed 16-bit sample, marked by Filtered_Done
//
//     The internal filter is a 31-tap low-pass with Fs = 100 Hz, Fc = 20 Hz,
//     coefficients are loaded from fir_coefficients.vh.
//////////////////////////////////////////////////////////////////////////////////

module FIR_Module(
    input                    CLK,
    input                    Reset_n,
    input      signed [15:0] Sample_Data,
    input                    Sample_Done,
    output     signed [15:0] Filtered_Data,
    output                   Filtered_Done
);

    // Full-precision FIR output
    wire               fir_valid;
    wire signed [39:0] fir_data;

    transposed_fir u_transposed_fir(
        .clk       (CLK),
        .rst_n     (Reset_n),
        .valid_in  (Sample_Done),
        .data_in   (Sample_Data),
        .valid_out (fir_valid),
        .data_out  (fir_data)
    );

    fir_output_stage u_fir_output_stage(
        .clk       (CLK),
        .rst_n     (Reset_n),
        .valid_in  (fir_valid),
        .data_in   (fir_data),
        .valid_out (Filtered_Done),
        .data_out  (Filtered_Data)
    );

endmodule
