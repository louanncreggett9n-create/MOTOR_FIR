`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: dataset_player
// Description: Replays the BF_10HZ dataset ROM at 25.6 kSPS.
//////////////////////////////////////////////////////////////////////////////////

module dataset_player(
    input  wire               clk,
    input  wire               reset_n,
    input  wire               enable,
    output reg signed [15:0]  sample_out,
    output reg                sample_done
);

    parameter CLOCK_FREQ = 50_000_000;
    parameter SAMPLE_HZ  = 25_600;
    localparam TICK_MCNT = CLOCK_FREQ / SAMPLE_HZ - 1;

    reg [24:0] tick_counter;
    reg [13:0] addr;
    reg        rom_en;
    reg        rom_read_d;
    wire signed [15:0] rom_data;

    dataset_rom_bf10hz u_rom(
        .clk  (clk),
        .en   (rom_en),
        .addr (addr),
        .data (rom_data)
    );

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            tick_counter <= 25'd0;
            addr         <= 14'd0;
            rom_en       <= 1'b0;
            rom_read_d   <= 1'b0;
            sample_out   <= 16'sd0;
            sample_done  <= 1'b0;
        end else if (!enable) begin
            tick_counter <= 25'd0;
            addr         <= 14'd0;
            rom_en       <= 1'b0;
            rom_read_d   <= 1'b0;
            sample_out   <= 16'sd0;
            sample_done  <= 1'b0;
        end else begin
            rom_en      <= 1'b0;
            sample_done <= rom_read_d;
            if (rom_read_d) sample_out <= rom_data;
            rom_read_d  <= rom_en;
            if (rom_en)
                addr <= addr + 1'b1;
            if (tick_counter == TICK_MCNT) begin
                tick_counter <= 25'd0;
                rom_en       <= 1'b1;
            end else begin
                tick_counter <= tick_counter + 1'b1;
            end
        end
    end

endmodule
