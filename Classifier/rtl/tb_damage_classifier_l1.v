`timescale 1ns / 1ps
module tb_damage_classifier_l1;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg scan_start = 1'b0;
    reg scan_done = 1'b0;
    reg bin_vld = 1'b0;
    reg [6:0] bin_idx = 7'd0;
    reg signed [23:0] bin_xr = 24'sd0;
    reg signed [23:0] bin_xi = 24'sd0;

    wire result_valid;
    wire [3:0] result_cls;
    wire [7:0] result_conf;
    wire [15:0] result_best_dist;
    wire [15:0] result_second_dist;
    wire [15:0] result_margin;
    wire result_unknown;

    reg [10:0] vectors [0:223];
    integer errors = 0;
    integer case_idx;
    integer expected_cls;
    integer wait_cycles;

    damage_classifier_l1 dut (
        .clk(clk), .rst_n(rst_n),
        .scan_start(scan_start), .scan_done(scan_done),
        .bin_vld(bin_vld), .bin_idx(bin_idx),
        .bin_xr(bin_xr), .bin_xi(bin_xi),
        .result_valid(result_valid), .result_cls(result_cls),
        .result_conf(result_conf),
        .result_best_dist(result_best_dist),
        .result_second_dist(result_second_dist),
        .result_margin(result_margin),
        .result_unknown(result_unknown)
    );

    always #10 clk = ~clk;

    task send_vector;
        input integer ci;
        integer b;
        integer j;
        integer total;
        integer base;
        integer rem;
        integer value;
        begin
            scan_start = 1'b1;
            @(posedge clk); #1;
            scan_start = 1'b0;

            for (b = 0; b < 16; b = b + 1) begin
                total = vectors[ci * 16 + b];
                base  = total / 8;
                rem   = total % 8;
                for (j = 0; j < 8; j = j + 1) begin
                    value = base + ((j < rem) ? 1 : 0);
                    bin_idx = b * 8 + j;
                    bin_xr  = value << 6;
                    bin_xi  = 24'sd0;
                    bin_vld = 1'b1;
                    @(posedge clk); #1;
                end
            end
            bin_vld = 1'b0;
            @(posedge clk); #1;
            scan_done = 1'b1;
            @(posedge clk); #1;
            scan_done = 1'b0;
        end
    endtask

    initial begin
        $readmemh("classifier_test_vectors.mem", vectors);
        rst_n = 1'b0;
        repeat (5) @(posedge clk);
        #1 rst_n = 1'b1;

        for (case_idx = 0; case_idx < 14; case_idx = case_idx + 1) begin
            send_vector(case_idx);
            wait_cycles = 0;
            while (!result_valid && wait_cycles < 300) begin
                @(posedge clk); #1;
                wait_cycles = wait_cycles + 1;
            end
            if (!result_valid) begin
                $display("FAIL case=%0d timeout", case_idx);
                errors = errors + 1;
            end else begin
                if (case_idx < 10) expected_cls = case_idx / 2;
                else if (case_idx < 13) expected_cls = 5;
                else expected_cls = 7;

            if (case_idx < 13) begin
                if (result_cls != expected_cls[3:0] || result_unknown) begin
                    $display("FAIL case=%0d cls=%0d unknown=%0d best=%0d margin=%0d",
                             case_idx, result_cls, result_unknown, result_best_dist, result_margin);
                    errors = errors + 1;
                end else begin
                    $display("PASS case=%0d cls=%0d conf=%0d best=%0d second=%0d margin=%0d cycles=%0d",
                             case_idx, expected_cls, result_conf, result_best_dist,
                             result_second_dist, result_margin, wait_cycles);
                end
            end else begin
                if (result_cls != 4'd7 || !result_unknown) begin
                    $display("FAIL unknown cls=%0d unknown=%0d best=%0d margin=%0d",
                             result_cls, result_unknown, result_best_dist, result_margin);
                    errors = errors + 1;
                end else begin
                    $display("PASS unknown best=%0d margin=%0d", result_best_dist, result_margin);
                end
            end
            end
        end

        if (errors == 0) $display("CLASSIFIER_TB_PASS");
        else $display("CLASSIFIER_TB_FAIL errors=%0d", errors);
        $finish;
    end
endmodule