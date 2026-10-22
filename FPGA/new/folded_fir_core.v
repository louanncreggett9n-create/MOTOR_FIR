`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: folded_fir_core
// Description:
//     Sequential folded FIR core for signed 16-bit data and signed 18-bit Q17
//     coefficients. One multiplier is time-shared across all taps.
//////////////////////////////////////////////////////////////////////////////////

module folded_fir_core #(
    parameter integer TAP_NUM = 604,
    parameter integer ADDR_W  = 10,
    parameter integer DATA_W  = 16,
    parameter integer COEF_W  = 18,
    parameter integer ACC_W   = 40,
    parameter integer SHIFT   = 17
)(
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     valid_in,
    input  wire signed [DATA_W-1:0] data_in,
    input  wire signed [COEF_W-1:0] coeff_data,
    output reg  [ADDR_W-1:0]        tap_index,
    output reg                      busy,
    output reg                      valid_out,
    output reg  signed [DATA_W-1:0] data_out
);

    localparam [2:0] S_IDLE  = 3'd0;
    localparam [2:0] S_FETCH = 3'd1;
    localparam [2:0] S_COEF  = 3'd2;
    localparam [2:0] S_MAC   = 3'd3;
    localparam [2:0] S_DONE  = 3'd4;

    (* ram_style = "block" *) reg signed [DATA_W-1:0] sample_mem [0:TAP_NUM-1];

    reg [2:0] state;
    reg [ADDR_W-1:0] wr_ptr;
    reg [ADDR_W-1:0] rd_ptr;
    reg [ADDR_W-1:0] tap_count;
    reg signed [DATA_W-1:0] sample_q;
    reg signed [COEF_W-1:0] coeff_q;
    reg signed [ACC_W-1:0]  acc;
    reg                     ram_we;
    reg [ADDR_W-1:0]        ram_wr_addr;
    reg [ADDR_W-1:0]        ram_rd_addr;
    reg signed [DATA_W-1:0] ram_wr_data;
    integer init_i;

    initial begin
        for (init_i = 0; init_i < TAP_NUM; init_i = init_i + 1)
            sample_mem[init_i] = {DATA_W{1'b0}};
    end

    always @(posedge clk) begin
        if (ram_we)
            sample_mem[ram_wr_addr] <= ram_wr_data;
        sample_q <= sample_mem[ram_rd_addr];
    end

    wire signed [DATA_W+COEF_W-1:0] product = sample_q * coeff_q;

    wire [ACC_W-1:0] acc_mag       = acc[ACC_W-1] ? (~acc + 1'b1) : acc;
    wire [ACC_W-1:0] acc_round_mag = acc_mag + (1 << (SHIFT-1));
    wire [ACC_W-1:0] acc_shift_mag = acc_round_mag >>> SHIFT;
    wire signed [ACC_W-1:0] shifted = acc[ACC_W-1] ? -$signed(acc_shift_mag)
                                                  :  $signed(acc_shift_mag);
    localparam signed [ACC_W-1:0] MAX_OUT = (1 << (DATA_W-1)) - 1;
    localparam signed [ACC_W-1:0] MIN_OUT = -(1 << (DATA_W-1));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_IDLE;
            wr_ptr    <= 'd0;
            rd_ptr    <= 'd0;
            tap_count <= 'd0;
            tap_index <= 'd0;
            coeff_q   <= 'd0;
            acc       <= 'd0;
            busy      <= 1'b0;
            valid_out <= 1'b0;
            data_out  <= 'd0;
        end else begin
            valid_out <= 1'b0;
            ram_we <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (valid_in) begin
                        ram_we             <= 1'b1;
                        ram_wr_addr        <= wr_ptr;
                        ram_wr_data        <= data_in;
                        rd_ptr             <= wr_ptr;
                        ram_rd_addr        <= wr_ptr;
                        wr_ptr             <= (wr_ptr == TAP_NUM-1) ? 'd0 : wr_ptr + 1'b1;
                        tap_count          <= 'd0;
                        tap_index          <= 'd0;
                        acc                <= 'd0;
                        busy               <= 1'b1;
                        state              <= S_FETCH;
                    end
                end

                S_FETCH: begin
                    state <= S_COEF;
                end

                S_COEF: begin
                    coeff_q <= coeff_data;
                    state   <= S_MAC;
                end

                S_MAC: begin
                    acc <= acc + product;
                    if (tap_count == TAP_NUM-1) begin
                        state <= S_DONE;
                    end else begin
                        tap_count <= tap_count + 1'b1;
                        tap_index <= tap_index + 1'b1;
                        rd_ptr       <= (rd_ptr == 0) ? TAP_NUM-1 : rd_ptr - 1'b1;
                        ram_rd_addr  <= (rd_ptr == 0) ? TAP_NUM-1 : rd_ptr - 1'b1;
                        state     <= S_FETCH;
                    end
                end

                S_DONE: begin
                    if (shifted > MAX_OUT)
                        data_out <= MAX_OUT[DATA_W-1:0];
                    else if (shifted < MIN_OUT)
                        data_out <= MIN_OUT[DATA_W-1:0];
                    else
                        data_out <= shifted[DATA_W-1:0];

                    valid_out <= 1'b1;
                    busy      <= 1'b0;
                    state     <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule


