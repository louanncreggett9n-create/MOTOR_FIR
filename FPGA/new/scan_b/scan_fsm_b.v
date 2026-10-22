`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: scan_fsm_b
// Description:
//     Scan controller for the B scheme:
//         FILL one 512-sample block, compute mean, process the same block,
//         output the result, then move to the next bin.
//////////////////////////////////////////////////////////////////////////////////

module scan_fsm_b #(
    parameter integer N       = 512,
    parameter integer NBIN    = 128,
    parameter integer ADDR_W  = 9,
    parameter integer BIN_W   = 8
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  scan_start,
    input  wire                  din_vld,
    input  wire                  core_done,
    output reg                   fill_en,
    output reg                   mean_clear,
    output reg                   process_start,
    output reg                   process_en,
    output reg  [ADDR_W-1:0]     wr_addr,
    output reg  [ADDR_W-1:0]     rd_addr,
    output reg  [BIN_W-1:0]      bin_idx,
    output reg                   result_load,
    output reg                   scan_busy,
    output reg                   scan_done,
    output reg                   scan_error,
    output wire                  samp_taken
);

    localparam S_IDLE      = 4'd0;
    localparam S_LOAD      = 4'd1;
    localparam S_FILL      = 4'd2;
    localparam S_MEAN      = 4'd3;
    localparam S_PROC_START= 4'd4;
    localparam S_PROCESS   = 4'd5;
    localparam S_WAIT_CORE = 4'd6;
    localparam S_RESULT    = 4'd7;
    localparam S_NEXT_BIN  = 4'd8;
    localparam S_DONE      = 4'd9;

    reg [3:0]             state;
    reg [ADDR_W-1:0]      sample_cnt;
    reg [ADDR_W-1:0]      proc_cnt;
    reg [ADDR_W+3:0]      wait_cnt;

    assign samp_taken = fill_en && din_vld;

    always @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
        begin
            state         <= S_IDLE;
            fill_en       <= 1'b0;
            mean_clear    <= 1'b0;
            process_start <= 1'b0;
            process_en    <= 1'b0;
            wr_addr       <= {ADDR_W{1'b0}};
            rd_addr       <= {ADDR_W{1'b0}};
            bin_idx       <= {BIN_W{1'b0}};
            result_load   <= 1'b0;
            scan_busy     <= 1'b0;
            scan_done     <= 1'b0;
            scan_error    <= 1'b0;
            sample_cnt    <= {ADDR_W{1'b0}};
            proc_cnt      <= {ADDR_W{1'b0}};
            wait_cnt      <= {(ADDR_W+4){1'b0}};
        end
        else
        begin
            result_load   <= 1'b0;
            scan_done     <= 1'b0;
            process_start <= 1'b0;

            if(scan_start && (state != S_IDLE))
                scan_error <= 1'b1;

            case(state)
                S_IDLE:
                begin
                    fill_en     <= 1'b0;
                    mean_clear  <= 1'b0;
                    process_en  <= 1'b0;
                    scan_busy   <= 1'b0;
                    sample_cnt  <= {ADDR_W{1'b0}};
                    proc_cnt    <= {ADDR_W{1'b0}};
                    wait_cnt    <= {(ADDR_W+4){1'b0}};

                    if(scan_start)
                    begin
                        scan_error <= 1'b0;
                        bin_idx    <= {BIN_W{1'b0}};
                        state      <= S_LOAD;
                    end
                end

                S_LOAD:
                begin
                    scan_busy   <= 1'b1;
                    mean_clear  <= 1'b1;
                    fill_en     <= 1'b0;
                    wr_addr     <= {ADDR_W{1'b0}};
                    rd_addr     <= {ADDR_W{1'b0}};
                    sample_cnt  <= {ADDR_W{1'b0}};
                    state       <= S_FILL;
                end

                S_FILL:
                begin
                    scan_busy   <= 1'b1;
                    mean_clear  <= 1'b0;
                    fill_en     <= 1'b1;
                    wr_addr     <= sample_cnt;

                    if(din_vld)
                    begin
                        if(sample_cnt == (N-1))
                            state <= S_MEAN;
                        else
                            sample_cnt <= sample_cnt + {{(ADDR_W-1){1'b0}},1'b1};
                    end
                end

                S_MEAN:
                begin
                    fill_en     <= 1'b0;
                    state       <= S_PROC_START;
                end

                S_PROC_START:
                begin
                    scan_busy     <= 1'b1;
                    process_start <= 1'b1;
                    proc_cnt      <= {ADDR_W{1'b0}};
                    wait_cnt      <= {(ADDR_W+4){1'b0}};
                    rd_addr       <= {ADDR_W{1'b0}};
                    state         <= S_PROCESS;
                end

                S_PROCESS:
                begin
                    scan_busy <= 1'b1;
                    process_en <= 1'b1;
                    rd_addr    <= proc_cnt;

                    if(proc_cnt == (N-1))
                        state <= S_WAIT_CORE;
                    else
                        proc_cnt <= proc_cnt + {{(ADDR_W-1){1'b0}},1'b1};
                end

                S_WAIT_CORE:
                begin
                    scan_busy  <= 1'b1;
                    process_en <= 1'b0;
                    wait_cnt   <= wait_cnt + {{(ADDR_W+3){1'b0}},1'b1};

                    if(core_done)
                        state <= S_RESULT;
                    else if(wait_cnt > (N + 16))
                    begin
                        scan_error <= 1'b1;
                        state      <= S_DONE;
                    end
                end

                S_RESULT:
                begin
                    scan_busy   <= 1'b1;
                    result_load <= 1'b1;
                    state       <= S_NEXT_BIN;
                end

                S_NEXT_BIN:
                begin
                    scan_busy <= 1'b1;
                    if(bin_idx == (NBIN-1))
                        state <= S_DONE;
                    else
                    begin
                        bin_idx <= bin_idx + {{(BIN_W-1){1'b0}},1'b1};
                        state   <= S_LOAD;
                    end
                end

                S_DONE:
                begin
                    scan_busy <= 1'b0;
                    scan_done <= 1'b1;
                    state     <= S_IDLE;
                end

                default:
                begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule

