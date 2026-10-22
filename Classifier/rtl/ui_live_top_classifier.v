`timescale 1ns / 1ps
// P3 live UI : ACX720-V3 J1 FPC, 800x480 RGB565
// live data : adc waveform envelope, 128-bin Goertzel spectrum, N1..ENV bars
module ui_live_top(
    input  wire               clk50M,
    input  wire               reset_n,
    input  wire signed [15:0] adc_s,
    input  wire               adc_valid,
    input  wire signed [15:0] n1,
    input  wire signed [15:0] n2,
    input  wire signed [15:0] n3,
    input  wire signed [15:0] env,
    input  wire               n1_valid,
    input  wire signed [23:0] bin_xr,
    input  wire signed [23:0] bin_xi,
    input  wire [7:0]         bin_idx,
    input  wire               bin_vld,
    input  wire               rx_flag,
    input  wire [7:0]         rx_data,
    input  wire [1:0]         page_sel,
    input  wire               ctl_mode,
    input  wire               ctl_src,
    input  wire [1:0]         ctl_wave,
    input  wire [3:0]         ctl_freq,
    input  wire [2:0]         ctl_channel,
    input  wire [2:0]         ctl_amp,
    input  wire [1:0]         ctl_nsel,
    output wire [4:0]         touch_cmd,
    inout  wire               tp_scl,
    inout  wire               tp_sda,
    inout wire               tp_int,
    output wire               tp_rst,
    input  wire [7:0]         scan_bin,
    input  wire               scan_busy,
    input  wire               scan_done,
    input  wire [7:0]         peak_bin,
    input  wire               peak_vld,
    output wire [15:0]        TFT_rgb,
    output wire               TFT_hs,
    output wire               TFT_vs,
    output wire               TFT_clk,
    output wire               TFT_de,
    output wire               TFT_pwm
);
    wire clkfb, clkfb_buf, clk33, locked, clk33_buf;
    MMCME2_BASE #(
        .BANDWIDTH("OPTIMIZED"), .CLKIN1_PERIOD(20.000), .DIVCLK_DIVIDE(2),
        .CLKFBOUT_MULT_F(33.000), .CLKOUT0_DIVIDE_F(25.000),
        .CLKOUT0_DUTY_CYCLE(0.500), .CLKOUT0_PHASE(0.000), .STARTUP_WAIT("FALSE")
    ) u_mmcm (
        .CLKOUT0(clk33), .CLKFBOUT(clkfb), .CLKFBIN(clkfb_buf),
        .CLKIN1(clk50M), .PWRDWN(1'b0), .RST(~reset_n), .LOCKED(locked)
    );
    BUFG u_bufg_fb   (.I(clkfb), .O(clkfb_buf));
    BUFG u_bufg_pclk (.I(clk33), .O(clk33_buf));
    wire rst = ~locked;

    // Auto classifier: scan_busy rising edge resets the band accumulator before
    // the first scan result arrives. Classification runs once after scan_done.
    reg scan_busy_d;
    always @(posedge clk50M or negedge reset_n) begin
        if (!reset_n) scan_busy_d <= 1'b0;
        else scan_busy_d <= scan_busy;
    end
    wire classifier_scan_start = scan_busy && !scan_busy_d;
    wire classifier_result_valid;
    wire [3:0] classifier_result_cls;
    wire [7:0] classifier_result_conf;
    wire [15:0] classifier_best_dist;
    wire [15:0] classifier_second_dist;
    wire [15:0] classifier_margin;
    wire classifier_unknown;

    damage_classifier_l1 u_classifier (
        .clk(clk50M),
        .rst_n(reset_n),
        .scan_start(classifier_scan_start),
        .scan_done(scan_done),
        .bin_vld(bin_vld),
        .bin_idx(bin_idx[6:0]),
        .bin_xr(bin_xr),
        .bin_xi(bin_xi),
        .result_valid(classifier_result_valid),
        .result_cls(classifier_result_cls),
        .result_conf(classifier_result_conf),
        .result_best_dist(classifier_best_dist),
        .result_second_dist(classifier_second_dist),
        .result_margin(classifier_margin),
        .result_unknown(classifier_unknown)
    );

    wire [11:0] h_addr, v_addr;
    wire        frame_begin;
    wire        data_req, de_int;
    wire [15:0] disp_data;
    disp_driver u_disp (
        .ClkDisp(clk33_buf), .Rst_p(rst), .Data(disp_data), .DataReq(data_req),
        .H_Addr(h_addr), .V_Addr(v_addr),
        .Disp_HS(TFT_hs), .Disp_VS(TFT_vs),
        .Disp_Red(TFT_rgb[15:11]), .Disp_Green(TFT_rgb[10:5]), .Disp_Blue(TFT_rgb[4:0]),
        .Frame_Begin(frame_begin), .Disp_DE(de_int), .Disp_PCLK(TFT_clk)
    );
    assign TFT_de = de_int;

    // ---------------- 50 MHz capture ----------------
    // wf_ram is the continuous 40 ms acquisition ring. wf_disp_ram is a
    // frozen 30 ms raster snapshot rebuilt during vertical blanking.
    reg signed [7:0] wf_ram [0:1023];
    reg signed [7:0] wf_disp_ram [0:767];
    reg [9:0] wf_col;
    reg signed [7:0] wf_prev;

    // DAT uses a soft-knee display compressor, not a hard clip. Small
    // signals keep the 16x gain; large peaks are compressed smoothly so the
    // displayed trace keeps its shape instead of developing square flat tops.
    wire wf_dat_view = ctl_mode && !ctl_src && (ctl_wave == 2'd3);
    wire signed [15:0] wf_dat_abs_s = adc_s[15] ? (~adc_s + 16'd1) : adc_s;
    wire [15:0] wf_dat_abs = wf_dat_abs_s;
    wire [7:0] wf_dat_mag = (wf_dat_abs <= 16'd1536) ? wf_dat_abs[11:4] :
                            (wf_dat_abs >= 16'd17408) ? 8'd127 :
                            (8'd96 + ((wf_dat_abs - 16'd1536) >> 9));
    wire signed [7:0] wf_dat_sample = adc_s[15] ? (~wf_dat_mag + 8'd1) : wf_dat_mag;
    wire signed [7:0] wf_sample = wf_dat_view ? wf_dat_sample : adc_s[15:8];
    wire wf_ext_adc = !ctl_src && (ctl_wave == 2'd0);
    reg [1:0] wf_dec_cnt;

    // Synchronize Frame_Begin from the 33 MHz raster into the 50 MHz domain.
    reg fb_meta, fb_sync, fb_sync_d;

    // Snapshot FSM: find the first rising zero crossing in the acquisition
    // ring, then copy 768 samples starting there. This keeps the waveform
    // phase-stable and guarantees enough samples for 3 cycles at 100 Hz.
    localparam WFS_IDLE = 2'd0, WFS_SEARCH = 2'd1, WFS_COPY = 2'd2;
    reg [1:0] wf_snap_state;
    reg [9:0] wf_search_idx, wf_copy_idx, wf_snap_base, wf_copy_base;

    wire [10:0] wf_search_sum = {1'b0, wf_snap_base} + {1'b0, wf_search_idx};
    wire [10:0] wf_search_addr11 = (wf_search_sum >= 11'd1024) ?
                                    (wf_search_sum - 11'd1024) : wf_search_sum;
    wire [9:0] wf_search_addr = wf_search_addr11[9:0];
    wire [10:0] wf_search_next_sum = wf_search_addr11 + 11'd1;
    wire [10:0] wf_search_next_addr11 = (wf_search_next_sum >= 11'd1024) ?
                                         (wf_search_next_sum - 11'd1024) : wf_search_next_sum;
    wire [9:0] wf_search_next_addr = wf_search_next_addr11[9:0];
    wire signed [7:0] wf_search_cur = wf_ram[wf_search_addr];
    wire signed [7:0] wf_search_nxt = wf_ram[wf_search_next_addr];

    wire [10:0] wf_copy_sum = {1'b0, wf_copy_base} + {1'b0, wf_copy_idx};
    wire [10:0] wf_copy_addr11 = (wf_copy_sum >= 11'd1024) ?
                                  (wf_copy_sum - 11'd1024) : wf_copy_sum;
    wire [9:0] wf_copy_addr = wf_copy_addr11[9:0];

    reg signed [7:0] wf_min_acc, wf_max_acc;
    reg signed [7:0] wf_center_latched;
    reg [8:0] wf_span_latched;
    wire signed [7:0] wf_copy_sample = wf_ram[wf_copy_addr];
    wire signed [7:0] wf_min_next = (wf_copy_sample < wf_min_acc) ? wf_copy_sample : wf_min_acc;
    wire signed [7:0] wf_max_next = (wf_copy_sample > wf_max_acc) ? wf_copy_sample : wf_max_acc;
    wire [8:0] wf_min_u = {1'b0, (wf_min_next ^ 8'h80)};
    wire [8:0] wf_max_u = {1'b0, (wf_max_next ^ 8'h80)};
    wire [8:0] wf_span_next = wf_max_u - wf_min_u;
    wire [8:0] wf_center_u_next = (wf_min_u + wf_max_u) >> 1;
    wire signed [7:0] wf_center_next = wf_center_u_next[7:0] ^ 8'h80;

    // External ADC display gain is based on snapshot peak-to-peak span after
    // removing the DC midpoint. This avoids wasting dynamic range on the
    // AD7606/DAC offset while keeping the trace inside the plotting area.
    function [2:0] wf_auto_shift_for_span;
        input [8:0] span;
        begin
            if (span >= 9'd128) wf_auto_shift_for_span = 3'd0;
            else if (span >= 9'd64) wf_auto_shift_for_span = 3'd1;
            else if (span >= 9'd32) wf_auto_shift_for_span = 3'd2;
            else if (span >= 9'd16) wf_auto_shift_for_span = 3'd3;
            else if (span >= 9'd8)  wf_auto_shift_for_span = 3'd4;
            else wf_auto_shift_for_span = 3'd5;
        end
    endfunction
    wire [2:0] wf_auto_shift = wf_auto_shift_for_span(wf_span_latched);

    // The previous snapshot's midpoint/span scale the current copy. This
    // reuses one scaler instead of four parallel pixel-path scalers and keeps
    // the 33 MHz TFT output path short.
    wire signed [8:0] wf_copy_ac = $signed({wf_copy_sample[7], wf_copy_sample}) -
                                   $signed({wf_center_latched[7], wf_center_latched});
    wire signed [12:0] wf_copy_gain = {{4{wf_copy_ac[8]}}, wf_copy_ac} <<< wf_auto_shift;
    wire signed [7:0] wf_copy_view = (wf_copy_gain > 13'sd127) ? 8'sd127 :
                                     (wf_copy_gain < -13'sd128) ? -8'sd128 :
                                     wf_copy_gain[7:0];
    wire signed [7:0] wf_copy_disp = wf_ext_adc ? wf_copy_view : wf_copy_sample;

    always @(posedge clk50M or negedge reset_n) begin
        if (!reset_n) begin
            wf_col <= 10'd0;
            wf_prev <= 8'sd0;
            wf_dec_cnt <= 2'd0;
            fb_meta <= 1'b0; fb_sync <= 1'b0; fb_sync_d <= 1'b0;
            wf_snap_state <= WFS_IDLE;
            wf_search_idx <= 10'd0; wf_copy_idx <= 10'd0;
            wf_snap_base <= 10'd0; wf_copy_base <= 10'd0;
            wf_min_acc <= 8'sd127; wf_max_acc <= -8'sd128;
            wf_center_latched <= 8'sd0; wf_span_latched <= 9'd255;
        end else begin
            fb_meta <= frame_begin;
            fb_sync <= fb_meta;
            fb_sync_d <= fb_sync;

            if (adc_valid) begin
                // External datasets are 10 Hz condition records. Keep every
                // fourth sample so a 1024-sample ring covers about 160 ms.
                if (!wf_ext_adc || (wf_dec_cnt == 2'd3)) begin
                    wf_ram[wf_col] <= wf_sample;
                    wf_prev <= wf_sample;
                    wf_col <= (wf_col == 10'd1023) ? 10'd0 : wf_col + 10'd1;
                    wf_dec_cnt <= 2'd0;
                end else begin
                    wf_dec_cnt <= wf_dec_cnt + 2'd1;
                end
            end

            if (fb_sync && !fb_sync_d) begin
                wf_snap_base <= wf_col;
                wf_search_idx <= 10'd0;
                wf_min_acc <= 8'sd127;
                wf_max_acc <= -8'sd128;
                wf_snap_state <= WFS_SEARCH;
            end else begin
                case (wf_snap_state)
                WFS_SEARCH: begin
                    if ((wf_search_cur < 8'sd0) && (wf_search_nxt >= 8'sd0)) begin
                        wf_copy_base <= wf_search_next_addr;
                        wf_copy_idx <= 10'd0;
                        wf_snap_state <= WFS_COPY;
                    end else if (wf_search_idx == 10'd1022) begin
                        wf_copy_base <= wf_snap_base;
                        wf_copy_idx <= 10'd0;
                        wf_snap_state <= WFS_COPY;
                    end else begin
                        wf_search_idx <= wf_search_idx + 10'd1;
                    end
                end
                WFS_COPY: begin
                    wf_disp_ram[wf_copy_idx] <= wf_copy_disp;
                    wf_min_acc <= wf_min_next;
                    wf_max_acc <= wf_max_next;
                    if (wf_copy_idx == 10'd767) begin
                        wf_center_latched <= wf_center_next;
                        wf_span_latched <= wf_span_next;
                        wf_snap_state <= WFS_IDLE;
                    end else begin
                        wf_copy_idx <= wf_copy_idx + 10'd1;
                    end
                end
                default: ;
                endcase
            end
        end
    end

    reg [7:0] spec_ram [0:127];
    wire [23:0] xr_abs = bin_xr[23] ? (~bin_xr + 24'd1) : bin_xr;
    wire [23:0] xi_abs = bin_xi[23] ? (~bin_xi + 24'd1) : bin_xi;
    wire [23:0] bin_mag = xr_abs + xi_abs;
    wire [23:0] bin_mag_c = (bin_mag > 24'd9600) ? 24'd9600 : bin_mag;
    wire [7:0]  bin_h = bin_mag_c[13:6];
    always @(posedge clk50M) if (bin_vld) spec_ram[bin_idx] <= bin_h;

    wire [15:0] n1a = n1[15]  ? (~n1  + 16'd1) : n1;
    wire [15:0] n2a = n2[15]  ? (~n2  + 16'd1) : n2;
    wire [15:0] n3a = n3[15]  ? (~n3  + 16'd1) : n3;
    wire [15:0] enva= env[15] ? (~env + 16'd1) : env;

    wire [15:0] fbar_max01 = (n1a > n2a) ? n1a : n2a;
    wire [15:0] fbar_max23 = (n3a > enva) ? n3a : enva;
    wire [15:0] fbar_max = (fbar_max01 > fbar_max23) ? fbar_max01 : fbar_max23;
    reg [2:0] fbar_shift;
    always @(*) begin
        if (fbar_max >= 16'd200) fbar_shift = 3'd0;
        else if (fbar_max >= 16'd100) fbar_shift = 3'd1;
        else if (fbar_max >= 16'd50) fbar_shift = 3'd2;
        else if (fbar_max >= 16'd25) fbar_shift = 3'd3;
        else if (fbar_max >= 16'd12) fbar_shift = 3'd4;
        else fbar_shift = 3'd5;
    end
    wire [17:0] n1s = n1a << fbar_shift;
    wire [17:0] n2s = n2a << fbar_shift;
    wire [17:0] n3s = n3a << fbar_shift;
    wire [17:0] envs = enva << fbar_shift;
    reg [7:0] b1, b2, b3, b4, fcnt;
    reg [15:0] m1, m2, m3, m4;
    reg ftog, fmt_start;
    wire strobe = n1_valid && (fcnt == 8'd255);

    always @(posedge clk50M or negedge reset_n) begin
        if (!reset_n) begin
            fcnt <= 8'd0; ftog <= 1'b0; fmt_start <= 1'b0;
            b1 <= 8'd0; b2 <= 8'd0; b3 <= 8'd0; b4 <= 8'd0;
            m1 <= 16'd0; m2 <= 16'd0; m3 <= 16'd0; m4 <= 16'd0;
        end else begin
            fmt_start <= strobe;
            if (n1_valid) begin
                if (fcnt == 8'd255) begin
                    fcnt <= 8'd0; ftog <= ~ftog;
                    b1 <= (n1s > 18'd255) ? 8'd255 : n1s[7:0];
                    b2 <= (n2s > 18'd255) ? 8'd255 : n2s[7:0];
                    b3 <= (n3s > 18'd255) ? 8'd255 : n3s[7:0];
                    b4 <= (envs > 18'd255) ? 8'd255 : envs[7:0];
                    m1 <= n1a; m2 <= n2a; m3 <= n3a; m4 <= enva;
                end else fcnt <= fcnt + 8'd1;
            end
        end
    end

    // ---------------- 33 MHz latch ----------------
    reg t1, t2, t3;
    reg [7:0] h1, h2, h3, h4;
    always @(posedge clk33_buf or posedge rst) begin
        if (rst) begin
            t1 <= 1'b0; t2 <= 1'b0; t3 <= 1'b0;
            h1 <= 8'd0; h2 <= 8'd0; h3 <= 8'd0; h4 <= 8'd0;
        end else begin
            t1 <= ftog; t2 <= t1; t3 <= t2;
            if (t2 != t3) begin h1 <= b1; h2 <= b2; h3 <= b3; h4 <= b4; end
        end
    end


    wire [9:0] tp_x, tp_y;
    wire       tp_down;
    wire [2:0] tp_state;
    wire       tp_ack;
    wire [7:0] tp_status;
    wire [6:0] tp_addr;
    wire [7:0] tp_id0, tp_id1, tp_id2, tp_idb0, tp_idb1, tp_idb2;
    wire [7:0] tp_cfgver, tp_trans_cnt;
    wire [1:0] tp_bus_idle;
    wire       tp_reg_wack;
    wire [3:0] tp_byte_nack;
    gt911_touch_v2 u_tp (
        .clk(clk50M), .rst_n(reset_n),
        .tp_scl(tp_scl), .tp_sda(tp_sda), .tp_int(tp_int), .tp_rst(tp_rst),
        .x(tp_x), .y(tp_y), .down(tp_down), .state_o(tp_state), .ack_o(tp_ack),
        .status_o(tp_status), .addr_o(tp_addr),
        .id0_o(tp_id0), .id1_o(tp_id1), .id2_o(tp_id2),
        .idb0_o(tp_idb0), .idb1_o(tp_idb1), .idb2_o(tp_idb2), .cfgver_o(tp_cfgver),
        .trans_cnt_o(tp_trans_cnt), .bus_idle_o(tp_bus_idle), .reg_wack_o(tp_reg_wack), .byte_nack_o(tp_byte_nack)
    );

    reg        touch_used;
    reg [1:0]  touch_page;

    ui_touch_ctrl u_touch_ctrl (
        .clk(clk50M), .rst_n(reset_n),
        .page(touch_used ? touch_page : page_sel),
        .x(tp_x), .y(tp_y), .down(tp_down), .cmd(touch_cmd)
    );
    wire [1:0] tp_idx = (tp_x < 10'd200) ? 2'd0 : (tp_x < 10'd400) ? 2'd1 :
                        (tp_x < 10'd600) ? 2'd2 : 2'd3;
    always @(posedge clk33_buf or posedge rst) begin
        if (rst) begin touch_used <= 1'b0; touch_page <= 2'd0; end
        else if (tp_down && (tp_y < 10'd32)) begin
            touch_used <= 1'b1;
            touch_page <= tp_idx;
        end
    end

    // ---------------- render ----------------
    wire [11:0] x = h_addr, y = v_addr;
    wire [1:0]  page = touch_used ? touch_page : page_sel;

    wire single_area = (x >= 12'd8 && x <= 12'd791 && y >= 12'd40 && y <= 12'd471);
    wire p1_area = (page == 2'd0) && (x >= 12'd8   && x <= 12'd399 && y >= 12'd40  && y <= 12'd239);
    wire p2_area = (page == 2'd0) && (x >= 12'd408 && x <= 12'd791 && y >= 12'd40  && y <= 12'd239);
    wire p3_area = (page == 2'd0) && (x >= 12'd8   && x <= 12'd399 && y >= 12'd248 && y <= 12'd471);
    wire p4_area = (page == 2'd0) && (x >= 12'd408 && x <= 12'd791 && y >= 12'd248 && y <= 12'd471);
    wire top_area = (y <= 12'd31);

    wire border0 = (p1_area && (x <= 12'd9   || x >= 12'd398 || y <= 12'd41  || y >= 12'd238)) ||
                   (p2_area && (x <= 12'd409 || x >= 12'd790 || y <= 12'd41  || y >= 12'd238)) ||
                   (p3_area && (x <= 12'd9   || x >= 12'd398 || y <= 12'd249 || y >= 12'd470)) ||
                   (p4_area && (x <= 12'd409 || x >= 12'd790 || y <= 12'd249 || y >= 12'd470));
    wire borderS = (page != 2'd0) && single_area &&
                   (x <= 12'd9 || x >= 12'd790 || y <= 12'd41 || y >= 12'd470);
    wire border = border0 || borderS;

    wire grid = ((p1_area || p2_area) ||
                 ((page == 2'd1) && single_area && !borderS)) &&
                (x[4:0] == 5'd0 || y[4:0] == 5'd0);

    // ---- waveform: frequency-aware frozen snapshot ----
    // pixels per sample are chosen so the full waveform page shows about
    // three complete DDS periods at every frequency setting.
    function [4:0] wf_pps_zoom;
        input [3:0] f;
        begin
            case (f)
            4'd0:  wf_pps_zoom = 5'd1;
            4'd1:  wf_pps_zoom = 5'd2;
            4'd2:  wf_pps_zoom = 5'd3;
            4'd3:  wf_pps_zoom = 5'd4;
            4'd4:  wf_pps_zoom = 5'd5;
            4'd5:  wf_pps_zoom = 5'd6;
            4'd6:  wf_pps_zoom = 5'd7;
            4'd7:  wf_pps_zoom = 5'd8;
            4'd8:  wf_pps_zoom = 5'd9;
            4'd9:  wf_pps_zoom = 5'd10;
            4'd10: wf_pps_zoom = 5'd11;
            4'd11: wf_pps_zoom = 5'd12;
            4'd12: wf_pps_zoom = 5'd13;
            4'd13: wf_pps_zoom = 5'd14;
            4'd14: wf_pps_zoom = 5'd15;
            default: wf_pps_zoom = 5'd20;
            endcase
        end
    endfunction

    function [4:0] wf_pps_overview;
        input [3:0] f;
        begin
            case (f)
            4'd0:  wf_pps_overview = 5'd1;
            4'd1:  wf_pps_overview = 5'd1;
            4'd2:  wf_pps_overview = 5'd2;
            4'd3:  wf_pps_overview = 5'd2;
            4'd4:  wf_pps_overview = 5'd3;
            4'd5:  wf_pps_overview = 5'd3;
            4'd6:  wf_pps_overview = 5'd4;
            4'd7:  wf_pps_overview = 5'd4;
            4'd8:  wf_pps_overview = 5'd5;
            4'd9:  wf_pps_overview = 5'd5;
            4'd10: wf_pps_overview = 5'd6;
            4'd11: wf_pps_overview = 5'd6;
            4'd12: wf_pps_overview = 5'd7;
            4'd13: wf_pps_overview = 5'd7;
            4'd14: wf_pps_overview = 5'd8;
            default: wf_pps_overview = 5'd10;
            endcase
        end
    endfunction

    function [9:0] wf_age_zoom;
        input [9:0] xr;
        input [3:0] f;
        input dat;
        begin
            if (dat) wf_age_zoom = xr;
            else case (f)
            4'd0:  wf_age_zoom = xr;
            4'd1:  wf_age_zoom = xr >> 1;
            4'd2:  wf_age_zoom = xr / 3;
            4'd3:  wf_age_zoom = xr >> 2;
            4'd4:  wf_age_zoom = xr / 5;
            4'd5:  wf_age_zoom = xr / 6;
            4'd6:  wf_age_zoom = xr / 7;
            4'd7:  wf_age_zoom = xr >> 3;
            4'd8:  wf_age_zoom = xr / 9;
            4'd9:  wf_age_zoom = xr / 10;
            4'd10: wf_age_zoom = xr / 11;
            4'd11: wf_age_zoom = xr / 12;
            4'd12: wf_age_zoom = xr / 13;
            4'd13: wf_age_zoom = xr / 14;
            4'd14: wf_age_zoom = xr / 15;
            default: wf_age_zoom = xr / 20;
            endcase
        end
    endfunction

    function [9:0] wf_age_overview;
        input [9:0] xr;
        input [3:0] f;
        input dat;
        begin
            if (dat) wf_age_overview = xr;
            else case (f)
            4'd0:  wf_age_overview = xr;
            4'd1:  wf_age_overview = xr;
            4'd2:  wf_age_overview = xr >> 1;
            4'd3:  wf_age_overview = xr >> 1;
            4'd4:  wf_age_overview = xr / 3;
            4'd5:  wf_age_overview = xr / 3;
            4'd6:  wf_age_overview = xr >> 2;
            4'd7:  wf_age_overview = xr >> 2;
            4'd8:  wf_age_overview = xr / 5;
            4'd9:  wf_age_overview = xr / 5;
            4'd10: wf_age_overview = xr / 6;
            4'd11: wf_age_overview = xr / 6;
            4'd12: wf_age_overview = xr / 7;
            4'd13: wf_age_overview = xr / 7;
            4'd14: wf_age_overview = xr >> 3;
            default: wf_age_overview = xr / 10;
            endcase
        end
    endfunction

    wire [9:0] wf_xrel = (x >= 12'd8) ? (x[9:0] - 10'd8) : 10'd0;
    wire [4:0] wf_pps1 = (wf_ext_adc || wf_dat_view) ? 5'd1 : wf_pps_zoom(ctl_freq);
    wire [4:0] wf_pps0 = (wf_ext_adc || wf_dat_view) ? 5'd1 : wf_pps_overview(ctl_freq);
    wire [9:0] wf_age0 = wf_age_overview(wf_xrel, ctl_freq, wf_dat_view || wf_ext_adc);
    wire [9:0] wf_age1 = wf_age_zoom(wf_xrel, ctl_freq, wf_dat_view || wf_ext_adc);
    wire [9:0] wf_age0n = (wf_age0 == 10'd767) ? 10'd767 : wf_age0 + 10'd1;
    wire [9:0] wf_age1n = (wf_age1 == 10'd767) ? 10'd767 : wf_age1 + 10'd1;
    wire [9:0] wf_phase0 = wf_xrel - (wf_age0 * wf_pps0);
    wire [9:0] wf_phase1 = wf_xrel - (wf_age1 * wf_pps1);
    wire wf_transition0 = (wf_phase0 == 10'd0);
    wire wf_transition1 = (wf_phase1 == 10'd0);

    wire signed [7:0] wf_s0  = wf_disp_ram[wf_age0];
    wire signed [7:0] wf_s0n = wf_disp_ram[wf_age0n];
    wire signed [7:0] wf_s1  = wf_disp_ram[wf_age1];
    wire signed [7:0] wf_s1n = wf_disp_ram[wf_age1n];

    // External ADC snapshots were centered and scaled while being copied.
    wire signed [11:0] wf_view0 = {{5{wf_s0[7]}}, wf_s0[7:1]};
    wire signed [11:0] wf_view0n = {{5{wf_s0n[7]}}, wf_s0n[7:1]};
    wire signed [12:0] wf_view1 = {{5{wf_s1[7]}}, wf_s1};
    wire signed [12:0] wf_view1n = {{5{wf_s1n[7]}}, wf_s1n};

    wire signed [11:0] wf_y0_a = 12'sd140 - wf_view0;
    wire signed [11:0] wf_y0_b = 12'sd140 - wf_view0n;
    wire signed [11:0] wf_lo0 = (wf_y0_a < wf_y0_b) ? wf_y0_a : wf_y0_b;
    wire signed [11:0] wf_hi0 = (wf_y0_a < wf_y0_b) ? wf_y0_b : wf_y0_a;
    wire signed [12:0] wf_y1_a = 13'sd256 - wf_view1;
    wire signed [12:0] wf_y1_b = 13'sd256 - wf_view1n;
    wire signed [12:0] wf_lo1 = (wf_y1_a < wf_y1_b) ? wf_y1_a : wf_y1_b;
    wire signed [12:0] wf_hi1 = (wf_y1_a < wf_y1_b) ? wf_y1_b : wf_y1_a;

    wire [11:0] wf_lo0_u = wf_lo0;
    wire [11:0] wf_hi0_u = wf_hi0;
    wire [11:0] wf_line0 = wf_y0_a;
    wire [12:0] wf_lo1_u = wf_lo1;
    wire [12:0] wf_hi1_u = wf_hi1;
    wire [12:0] wf_line1 = wf_y1_a;
    wire wf_h0 = (y >= wf_line0 - 12'd1) && (y <= wf_line0 + 12'd1);
    wire wf_h1 = (y >= wf_line1 - 13'd1) && (y <= wf_line1 + 13'd1);

    wire wf_px0 = p1_area && !border &&
                  (wf_transition0 ? ((y >= wf_lo0_u) && (y <= wf_hi0_u)) : wf_h0);
    wire wf_px1 = (page == 2'd1) && single_area && !border &&
                  (wf_transition1 ? ((y >= wf_lo1_u) && (y <= wf_hi1_u)) : wf_h1);

    // ---- spectrum (page 0 short / page 2 tall) ----
    wire [8:0] bx0 = (x > 12'd409) ? (x - 12'd410) : 9'd0;
    wire [6:0] sbin0 = (bx0 > 9'd383) ? 7'd127 : bx0 / 7'd3;
    wire [7:0] sh0 = spec_ram[sbin0];
    wire spec_px0 = p2_area && !border && (x >= 12'd410) && (sh0 != 8'd0) &&
                    (y <= 12'd232) && (y >= 12'd232 - {4'd0, sh0});

    wire [9:0] sx = (x > 12'd15) ? (x - 12'd16) : 10'd0;
    wire [6:0] sbin1 = (sx > 10'd767) ? 7'd127 : sx / 7'd6;
    wire [7:0] sh1 = spec_ram[sbin1];
    wire [9:0] h1x = {1'b0, sh1} + {2'b0, sh1[7:1]};
    wire spec_px1 = (page == 2'd2) && single_area && !border && (x >= 12'd16) && (sh1 != 8'd0) &&
                    (y <= 12'd460) && (y >= 12'd460 - h1x);

    // ---- feature bars (page 0 only) ----
    wire [9:0] w1 = {2'd0, h1};
    wire [9:0] w2 = {2'd0, h2};
    wire [9:0] w3 = {2'd0, h3};
    wire [9:0] w4 = {2'd0, h4};
    wire f_en = (page == 2'd0);
    wire f1 = f_en && (y >= 12'd290 && y <= 12'd302 && x >= 12'd120 && x <= 12'd120 + {2'd0, w1});
    wire f2 = f_en && (y >= 12'd322 && y <= 12'd334 && x >= 12'd120 && x <= 12'd120 + {2'd0, w2});
    wire f3 = f_en && (y >= 12'd354 && y <= 12'd366 && x >= 12'd120 && x <= 12'd120 + {2'd0, w3});
    wire f4 = f_en && (y >= 12'd386 && y <= 12'd398 && x >= 12'd120 && x <= 12'd120 + {2'd0, w4});

    // ---- text ----
    wire [11:0] tcell = ({6'd0, y[10:4]} * 12'd100) + {6'd0, x[10:3]};
    wire [7:0] code_live, code_info;
    wire        fmt_wr_en, txt_wr_en, fmt_busy, txt_busy;
    wire [11:0] fmt_addr, txt_addr;
    wire [7:0]  fmt_data, txt_data;
    wire [3:0]  uart_cls; wire [7:0] uart_conf; wire [3:0] uart_sev;
    wire uart_route; wire uart_cmd_upd;
    reg [3:0] auto_cls;
    reg [7:0] auto_conf;
    reg [3:0] auto_sev;
    reg auto_route;
    reg auto_pending;
    wire txt_start;
    wire [3:0] txt_cls;
    wire [7:0] txt_conf;
    wire [3:0] txt_sev;
    wire txt_route;

    ui_uart_cmd u_cmd (
        .clk(clk50M), .rst_n(reset_n), .rx_flag(rx_flag), .rx_data(rx_data),
        .cls(uart_cls), .conf(uart_conf), .sev(uart_sev),
        .route(uart_route), .upd(uart_cmd_upd)
    );

    always @(posedge clk50M or negedge reset_n) begin
        if (!reset_n) begin
            auto_cls <= 4'd7;
            auto_conf <= 8'd0;
            auto_sev <= 4'd0;
            auto_route <= 1'b1;
            auto_pending <= 1'b0;
        end else begin
            if (classifier_result_valid) begin
                auto_cls <= classifier_result_cls;
                auto_conf <= classifier_result_conf;
                auto_sev <= (classifier_result_cls == 4'd0 ||
                             classifier_result_cls == 4'd7) ? 4'd0 : 4'd3;
                auto_route <= 1'b1;
                auto_pending <= 1'b1;
            end else if (txt_start) begin
                auto_pending <= 1'b0;
            end
        end
    end

    assign txt_start = (uart_cmd_upd || auto_pending) && !fmt_busy && !txt_busy;
    assign txt_cls   = uart_cmd_upd ? uart_cls   : auto_cls;
    assign txt_conf  = uart_cmd_upd ? uart_conf  : auto_conf;
    assign txt_sev   = uart_cmd_upd ? uart_sev   : auto_sev;
    assign txt_route = uart_cmd_upd ? uart_route : auto_route;

    ui_num_fmt u_fmt (
        .clk(clk50M), .rst_n(reset_n), .start(fmt_start && !txt_busy),
        .v1(m1), .v2(m2), .v3(m3), .v4(m4),
        .wr_en(fmt_wr_en), .wr_addr(fmt_addr), .wr_data(fmt_data), .busy(fmt_busy)
    );
    ui_text_wr u_txt (
        .clk(clk50M), .rst_n(reset_n), .start(txt_start),
        .cls(txt_cls), .conf(txt_conf), .sev(txt_sev), .route(txt_route),
        .wr_en(txt_wr_en), .wr_addr(txt_addr), .wr_data(txt_data), .busy(txt_busy)
    );
    wire        dbg_wr_en;
    wire [11:0] dbg_addr;
    wire [7:0]  dbg_data;
    ui_touch_dbg u_touch_dbg (
        .clk(clk50M), .rst_n(reset_n),
        .x(tp_x), .y(tp_y), .down(tp_down),
        .status(tp_status), .addr(tp_addr), .ack(tp_ack),
        .id0(tp_id0), .id1(tp_id1), .id2(tp_id2),
        .idb0(tp_idb0), .idb1(tp_idb1), .idb2(tp_idb2), .cfgver(tp_cfgver),
        .trans_cnt(tp_trans_cnt), .bus_idle(tp_bus_idle), .reg_wack(tp_reg_wack), .byte_nack(tp_byte_nack),
        .wr_en(dbg_wr_en), .wr_addr(dbg_addr), .wr_data(dbg_data)
    );

    wire        wr_en   = dbg_wr_en | fmt_wr_en | txt_wr_en;
    wire [11:0] wr_addr = dbg_wr_en ? dbg_addr : (txt_wr_en ? txt_addr : fmt_addr);
    wire [7:0]  wr_data = dbg_wr_en ? dbg_data : (txt_wr_en ? txt_data : fmt_data);

    ui_text_plane u_text (
        .clk(clk50M), .addr(tcell[11:0]), .data(code_live),
        .wr_en(wr_en), .wr_addr(wr_addr), .wr_data(wr_data)
    );
    ui_info_plane u_info (.addr(tcell[11:0]), .data(code_info));

    wire [7:0] code = ((page == 2'd3) && (y > 12'd31)) ? code_info : code_live;
    wire text_en = (page == 2'd0) || (page == 2'd3) || (y <= 12'd31);
    wire code_ok = (code >= 8'h20) && (code <= 8'h5F);
    wire [9:0] faddr = ({4'd0, (code - 8'h20)} * 10'd16) + {6'd0, y[3:0]};
    wire [7:0] fbits;
    ui_font_rom u_font (.addr(faddr), .data(fbits));
    wire text_px = text_en && code_ok && fbits[3'd7 - x[2:0]];

    // ---- touch tab bar (second text row inside the 32-pixel header) ----
    function [7:0] tab_ch;
        input [1:0] t;
        input [4:0] i;
        begin
            tab_ch = 8'h20;
            case (t)
            2'd0: case (i)
                5'd0: tab_ch="O"; 5'd1: tab_ch="V"; 5'd2: tab_ch="E"; 5'd3: tab_ch="R";
                5'd4: tab_ch="V"; 5'd5: tab_ch="I"; 5'd6: tab_ch="E"; 5'd7: tab_ch="W";
                default: ;
            endcase
            2'd1: case (i)
                5'd0: tab_ch="W"; 5'd1: tab_ch="A"; 5'd2: tab_ch="V"; 5'd3: tab_ch="E";
                5'd4: tab_ch="F"; 5'd5: tab_ch="O"; 5'd6: tab_ch="R"; 5'd7: tab_ch="M";
                default: ;
            endcase
            2'd2: case (i)
                5'd0: tab_ch="S"; 5'd1: tab_ch="P"; 5'd2: tab_ch="E"; 5'd3: tab_ch="C";
                5'd4: tab_ch="T"; 5'd5: tab_ch="R"; 5'd6: tab_ch="U"; 5'd7: tab_ch="M";
                default: ;
            endcase
            default: case (i)
                5'd0: tab_ch="C"; 5'd1: tab_ch="T"; 5'd2: tab_ch="R"; 5'd3: tab_ch="L";
                default: ;
            endcase
            endcase
        end
    endfunction

    wire [1:0]  tab_sel = (x < 12'd200) ? 2'd0 : (x < 12'd400) ? 2'd1 :
                          (x < 12'd600) ? 2'd2 : 2'd3;
    reg  [11:0] tab_x0, tab_lx0;
    reg  [4:0]  tab_len;
    always @(*) begin
        case (tab_sel)
        2'd0: begin tab_x0=12'd0;   tab_lx0=12'd64;  tab_len=5'd8; end
        2'd1: begin tab_x0=12'd200; tab_lx0=12'd264; tab_len=5'd8; end
        2'd2: begin tab_x0=12'd400; tab_lx0=12'd464; tab_len=5'd8; end
        default: begin tab_x0=12'd600; tab_lx0=12'd680; tab_len=5'd4; end
        endcase
    end
    wire [4:0]  tab_ci = (x >= tab_lx0) ? ((x - tab_lx0) >> 3) : 5'd0;
    wire [7:0]  tab_code = tab_ch(tab_sel, tab_ci);
    wire [9:0]  tab_faddr = ({4'd0, (tab_code - 8'h20)} * 10'd16) + {6'd0, y[3:0]};
    wire [7:0]  tab_fbits;
    ui_font_rom u_tab_font (.addr(tab_faddr), .data(tab_fbits));
    wire tab_strip = (y >= 12'd16) && (y <= 12'd31) && (x >= tab_x0) && (x < tab_x0 + 12'd200);
    wire tab_sep   = (y >= 12'd16) && (y <= 12'd31) && (x == 12'd200 || x == 12'd400 || x == 12'd600);
    wire tab_text_px = (y >= 12'd16) && (y <= 12'd31) &&
                       (x >= tab_lx0) && (x < tab_lx0 + ({7'd0, tab_len} * 12'd8)) &&
                       (tab_code >= 8'h20) && (tab_code <= 8'h5F) &&
                       tab_fbits[3'd7 - x[2:0]];

    // ---- scan cursor / peak / progress ----
    wire [11:0] cur_x0 = 12'd410 + ({4'd0, scan_bin} * 12'd3);
    wire [11:0] cur_x1 = 12'd16  + ({4'd0, scan_bin} * 12'd6);
    wire cursor0 = p2_area && !border && scan_busy &&
                   (x >= cur_x0) && (x <= cur_x0 + 12'd1) && (y >= 12'd70) && (y <= 12'd232);
    wire cursor1 = (page == 2'd2) && single_area && !border && scan_busy &&
                   (x >= cur_x1) && (x <= cur_x1 + 12'd2) && (y >= 12'd70) && (y <= 12'd460);

    wire [11:0] pk_x0 = 12'd410 + ({4'd0, peak_bin} * 12'd3);
    wire [11:0] pk_x1 = 12'd16  + ({4'd0, peak_bin} * 12'd6);
    wire peak0 = p2_area && !border && (peak_bin != 8'd0) &&
                 (x >= pk_x0) && (x <= pk_x0 + 12'd1) && (y >= 12'd220) && (y <= 12'd232);
    wire peak1 = (page == 2'd2) && single_area && !border && (peak_bin != 8'd0) &&
                 (x >= pk_x1) && (x <= pk_x1 + 12'd2) && (y >= 12'd444) && (y <= 12'd460);

    wire [8:0] pw = scan_done ? 9'd160 : ({1'b0, scan_bin} + {2'b0, scan_bin[7:2]});
    wire prog_track = (y >= 12'd4) && (y <= 12'd13) && (x >= 12'd620) && (x <= 12'd780);
    wire prog_fill  = prog_track && (x <= 12'd620 + {3'd0, pw});

    wire [11:0] cx = {2'b0, tp_x};
    wire [11:0] cy = {2'b0, tp_y};
    wire cur_on = tp_down && (tp_x > 10'd4) && (tp_y > 10'd4) &&
                  (x >= cx - 12'd3) && (x <= cx + 12'd3) &&
                  (y >= cy - 12'd3) && (y <= cy + 12'd3);
    wire [15:0] tp_col = (tp_state <= 3'd2) ? 16'h001F : (tp_ack ? 16'h07E0 : 16'hF800);
    wire tp_ind = (x >= 12'd760) && (x <= 12'd790) && (y >= 12'd4) && (y <= 12'd13);
    localparam [15:0] C_BG=16'h0000, C_TOP=16'h0320, C_PANEL=16'h10A2,
                      C_GRID=16'h2945, C_BORDER=16'h5AEB,
                      C_BAR=16'h07E0, C_BAR2=16'hFFE0, C_TEXT=16'hFFFF,
                      C_CUR=16'hFFE0, C_PEAK=16'hF800, C_TRACK=16'h18C3,
                      C_TAB_ACT=16'h05B5, C_TAB_INA=16'h2124,
                      C_BTN=16'h2124, C_BTN_ON=16'h05B5, C_BTN_OFF=16'h10A2;

    function [0:0] rect;
        input [11:0] px, py, x0, x1, y0, y1;
        begin
            rect = (px >= x0) && (px <= x1) && (py >= y0) && (py <= y1);
        end
    endfunction

    wire c3 = (page == 2'd3);
    // Page-3 touch-control regions, aligned with ui_touch_ctrl.v.
    wire btn_mode_loop = c3 && rect(x,y,12'd8,12'd196,12'd64,12'd103);
    wire btn_mode_up   = c3 && rect(x,y,12'd204,12'd392,12'd64,12'd103);
    wire btn_src_adc   = c3 && rect(x,y,12'd408,12'd596,12'd64,12'd103);
    wire btn_src_dds   = c3 && rect(x,y,12'd604,12'd791,12'd64,12'd103);
    wire btn_wave_sin  = c3 && rect(x,y,12'd8,12'd196,12'd112,12'd151);
    wire btn_wave_sqr  = c3 && rect(x,y,12'd204,12'd392,12'd112,12'd151);
    wire btn_wave_tri  = c3 && rect(x,y,12'd408,12'd596,12'd112,12'd151);
    wire btn_wave_dat  = c3 && rect(x,y,12'd604,12'd791,12'd112,12'd151);
    wire btn_freq_dec  = c3 && rect(x,y,12'd8,12'd72,12'd160,12'd199);
    wire btn_freq_inc  = c3 && rect(x,y,12'd718,12'd791,12'd160,12'd199);
    wire btn_ch_dec    = c3 && rect(x,y,12'd8,12'd72,12'd208,12'd247);
    wire btn_ch_inc    = c3 && rect(x,y,12'd718,12'd791,12'd208,12'd247);
    wire btn_amp_dec   = c3 && rect(x,y,12'd8,12'd72,12'd256,12'd295);
    wire btn_amp_inc   = c3 && rect(x,y,12'd438,12'd510,12'd256,12'd295);
    wire btn_scan      = c3 && rect(x,y,12'd560,12'd791,12'd256,12'd295);
    wire btn_n1        = c3 && rect(x,y,12'd8,12'd196,12'd304,12'd343);
    wire btn_n2        = c3 && rect(x,y,12'd204,12'd392,12'd304,12'd343);
    wire btn_n3        = c3 && rect(x,y,12'd408,12'd596,12'd304,12'd343);
    wire btn_env       = c3 && rect(x,y,12'd604,12'd791,12'd304,12'd343);

    wire ctl_btn = btn_mode_loop|btn_mode_up|btn_src_adc|btn_src_dds|
                   btn_wave_sin|btn_wave_sqr|btn_wave_tri|btn_wave_dat|
                   btn_freq_dec|btn_freq_inc|btn_ch_dec|btn_ch_inc|
                   btn_amp_dec|btn_amp_inc|btn_scan|btn_n1|btn_n2|btn_n3|btn_env;
    wire wave_btn = btn_wave_sin | btn_wave_sqr | btn_wave_tri | btn_wave_dat;
    wire wave_btn_dim = wave_btn && !ctl_src && (ctl_wave != 2'd3);
    wire ctl_btn_on = (btn_mode_loop && !ctl_mode) || (btn_mode_up && ctl_mode) ||
                      (btn_src_adc && !ctl_src) || (btn_src_dds && ctl_src) ||
                      (btn_wave_sin && ctl_src && ctl_wave==2'd0) ||
                      (btn_wave_sqr && ctl_src && ctl_wave==2'd1) ||
                      (btn_wave_tri && ctl_src && ctl_wave==2'd2) ||
                      (btn_wave_dat && !ctl_src && ctl_wave==2'd3) ||
                      (btn_n1 && ctl_nsel==2'd0) || (btn_n2 && ctl_nsel==2'd1) ||
                      (btn_n3 && ctl_nsel==2'd2) || (btn_env && ctl_nsel==2'd3) ||
                      (btn_scan && scan_busy);
    wire freq_track = c3 && rect(x,y,12'd80,12'd710,12'd168,12'd191);
    wire [3:0] freq_seg = (x >= 12'd80) ? ((x - 12'd80) / 12'd39) : 4'd0;
    wire freq_on = freq_track && (freq_seg == ctl_freq);
    wire ch_track = c3 && rect(x,y,12'd80,12'd710,12'd216,12'd239);
    wire [2:0] ch_seg = (x >= 12'd80) ? ((x - 12'd80) / 12'd79) : 3'd0;
    wire ch_on = ch_track && (ch_seg == ctl_channel);
    wire amp_track = c3 && rect(x,y,12'd80,12'd430,12'd264,12'd287);
    wire [2:0] amp_seg = (x >= 12'd80) ? ((x - 12'd80) / 12'd58) : 3'd0;
    wire amp_on = amp_track && (amp_seg == ctl_amp);

    reg [15:0] pix;
    always @(*) begin
        pix = C_BG;
        if (top_area) pix = C_TOP;
        if (tab_strip) pix = (tab_sel == page) ? C_TAB_ACT : C_TAB_INA;
        if (tab_sep) pix = C_BORDER;
        if (p1_area || p2_area || p3_area || p4_area) pix = C_PANEL;
        if ((page != 2'd0) && single_area) pix = C_PANEL;
        if (grid) pix = C_GRID;
        if (prog_track) pix = C_TRACK;
        if (prog_fill)  pix = C_BAR;
        if (spec_px0 || spec_px1) pix = C_BAR;
        if (wf_px0 || wf_px1)     pix = C_BAR;
        if (f1 || f2 || f3 || f4) pix = C_BAR2;
        if (cursor0 || cursor1)   pix = C_CUR;
        if (peak0 || peak1)       pix = C_PEAK;
        if (border) pix = C_BORDER;
        if (c3 && (freq_track || ch_track || amp_track)) pix = C_BTN;
        if (c3 && (freq_on || ch_on || amp_on)) pix = C_BAR;
        if (ctl_btn) pix = ctl_btn_on ? C_BTN_ON : C_BTN;
        if (wave_btn_dim) pix = C_BTN_OFF;
        if (c3 && (btn_mode_loop|btn_mode_up|btn_src_adc|btn_src_dds|
                   btn_wave_sin|btn_wave_sqr|btn_wave_tri|btn_wave_dat|
                   btn_freq_dec|btn_freq_inc|btn_ch_dec|btn_ch_inc|
                   btn_amp_dec|btn_amp_inc|btn_scan|btn_n1|btn_n2|btn_n3|btn_env) &&
            (x==12'd8 || x==12'd196 || x==12'd204 || x==12'd392 ||
             x==12'd408 || x==12'd596 || x==12'd604 || x==12'd791 ||
             x==12'd72 || x==12'd718 || x==12'd438 || x==12'd510 || x==12'd560 ||
             y==12'd64 || y==12'd103 || y==12'd112 || y==12'd151 ||
             y==12'd160 || y==12'd199 || y==12'd208 || y==12'd247 ||
             y==12'd256 || y==12'd295 || y==12'd304 || y==12'd343)) pix = C_BORDER;
        if (text_px) pix = C_TEXT;
        if (tab_text_px) pix = C_TEXT;
        if (tp_ind)  pix = tp_col;
        if (cur_on)  pix = C_TEXT;
    end
    assign disp_data = data_req ? pix : 16'h0000;
    assign TFT_pwm   = 1'b1;
endmodule
