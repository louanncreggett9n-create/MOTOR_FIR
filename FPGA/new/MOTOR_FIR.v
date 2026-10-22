`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: MOTOR_FIR
// Project Name: MOTOR_FIR
// Target Devices: xc7a35tfgg484-2
// Tool Versions: Vivado 2018.3
//
// Description:
//     Motor vibration FIR test top.
//
//     Mode_SW = 0: UART loopback.
//     Mode_SW = 1: upload mode.
//       Src_SW = 0: AD7606 ADC source
//       Src_SW = 1: DDS source
//     In DDS upload mode, S0 cycles the uploaded channel:
//       N1 -> N2 -> N3 -> ENV -> N1
//       ENV is decimated from 25.6 kSPS to 800 SPS for UART.
//
//     Dataset injection mode (temporary):
//       Mode_SW = 1, Src_SW = 0, Wave_SW = 3
//       Replays dataset_rom_bf10hz at 25.6 kSPS instead of AD7606.
//       S0 then selects the upload path N1/N2/N3/ENV.
//
//     Dataset injection mode (temporary):
//       Mode_SW = 1, Src_SW = 0, Wave_SW = 3
//       Replays dataset_rom_bf10hz at 25.6 kSPS instead of AD7606.
//       S0 then selects the upload path N1/N2/N3/ENV.
//
//     S1 cycles the DDS amplitude test levels:
//       100% -> 75% -> 50% -> 25% -> 10% -> 125% -> 100%
//       LED[5:3] shows the amplitude level code.
//
//     The selected source is sampled at 25600 Hz and processed by the
//     seven-filter motor_filter_chain:
//
//       25.6k -> L1 /8 -> 3.2k -> L2 /4 -> 800
//                                      -> N1/N2/N3
//       25.6k -> RB -> abs -> ENV
//
//     Key S0:
//       Src_SW = 0: cycles the ADC channel
//       Src_SW = 1: cycles the uploaded N1/N2/N3/ENV selection
//
//     The UART frame format is unchanged.
//////////////////////////////////////////////////////////////////////////////////

module MOTOR_FIR(
    input             CLK,
    input             Reset_n,
    input             UART_rx,
    output            UART_tx,
    input             Mode_SW,
    input             Src_SW,
    input             Key,
    input             Key_S1,
    input      [1:0]  Wave_SW,
    input      [3:0]  Freq_SW,
    output     [7:0]  LED,
    output            SEG7_DIO,
    output            SEG7_RCLK,
    output            SEG7_SCLK,
    output            ad7606_cs_n_o,
    output            ad7606_rd_n_o,
    input             ad7606_busy_i,
    input      [15:0] ad7606_db_i,
    output     [2:0]  ad7606_os_o,
    output            ad7606_reset_o,
    output            ad7606_convst_o,
    output            sync_25k6_o
);

parameter CLOCK_FREQ = 50_000_000;
parameter SAMPLE_HZ  = 25_600;
parameter FILTER_ENABLE = 1'b1;

wire        Rx_Flag;
wire [7:0]  Rx_Data;
reg  [2:0]  Channel;
reg  [1:0]  N_Sel;
reg  [31:0] Fword;

wire [15:0] ad7606_data1;
wire [15:0] ad7606_data2;
wire [15:0] ad7606_data3;
wire [15:0] ad7606_data4;
wire [15:0] ad7606_data5;
wire [15:0] ad7606_data6;
wire [15:0] ad7606_data7;
wire [15:0] ad7606_data8;
wire        ad7606_conv_done;
wire signed [15:0] ADC_Sample_Signed;
wire        ADC_Sample_Done;
reg  [5:0]  Sync_Pulse_Cnt;
reg         Sync_Pulse_Reg;

wire [13:0] DDS_Data;
wire signed [15:0] DDS_Sample_Signed;
wire signed [15:0] DDS_Sample_Scaled;
wire        DDS_Sample_Done;
reg  [2:0]  Amp_Sel;
wire        Key_S1_Press;

wire signed [15:0] Src_Sample_Signed;
wire        Src_Sample_Done;
wire        Raw_Adc_Debug;
reg  [4:0]  Raw_Adc_Dec_Cnt;
wire        Matrix_Mode;
reg  [10:0] Matrix_Count;
reg  [3:0]  Matrix_Index;
reg  [3:0]  Matrix_Marker_Count;
wire        Matrix_Marker_Active;
wire [3:0]  Matrix_Next;
reg signed [15:0] Raw_Adc_Uplink_Data;
reg         Raw_Adc_Uplink_Valid;
wire               Dataset_Mode;
wire signed [15:0] Dataset_Sample_Signed;
wire               Dataset_Sample_Done;

wire signed [15:0] chain_l1_out;
wire signed [15:0] chain_l2_out;
wire signed [15:0] chain_n1_out;
wire signed [15:0] chain_n2_out;
wire signed [15:0] chain_n3_out;
wire signed [15:0] chain_rb_out;
wire signed [15:0] chain_env_out;
wire chain_l1_valid;
wire chain_l1_dec_valid;
wire chain_l2_valid;
wire chain_l2_dec_valid;
wire chain_n1_valid;
wire chain_n2_valid;
wire chain_n3_valid;
wire chain_rb_valid;
wire chain_env_valid;


// B-scheme read-only scan branch

wire               Scan_Start;
wire [7:0]         Scan_Frame_Data;
wire               Scan_Frame_Go;
wire               Scan_Frame_Busy;
wire               Scan_Selected;
wire [7:0]         Scan_Status;
reg                Scan_Summary_Pending;
reg                Scan_Bin_Pending;
reg                Scan_Frame_Launched;
reg  [7:0]         Scan_Bin_Idx_Q;
reg  signed [23:0] Scan_Bin_Xr_Q;
reg  signed [23:0] Scan_Bin_Xi_Q;
reg  [7:0]         Scan_Bin_Status_Q;
wire               Scan_Any_Pending;
wire               Scan_Summary_Select;
wire               Scan_Frame_Start;
wire [7:0]         Scan_Frame_Idx;
wire signed [23:0] Scan_Frame_Xr;
wire signed [23:0] Scan_Frame_Xi;
wire [7:0]         Scan_Frame_Status;
wire               Frame_Go_Mux;
wire               Frame_Busy;
wire               Frame_Send_Start;
wire signed [15:0] Frame_Send_Value;
reg  signed [15:0] Raw_L2_Fifo [0:7];
reg  [2:0]         Raw_L2_Wr_Ptr;
reg  [2:0]         Raw_L2_Rd_Ptr;
reg  [3:0]         Raw_L2_Count;
reg                Raw_L2_Sending;
wire               Raw_L2_Frame_Start;
wire               Raw_L2_Pop;
wire signed [15:0] Raw_L2_Frame_Value;

wire               scan_busy;

wire               scan_done;

wire               scan_error;

wire               scan_bin_vld;

wire [7:0]         scan_bin_idx;

wire signed [23:0] scan_bin_xr;

wire signed [23:0] scan_bin_xi;

wire signed [15:0] scan_bin_mean;

wire signed [23:0] scan_bin_s1;

wire signed [23:0] scan_bin_s2;

wire               scan_peak_vld;

wire [7:0]         scan_peak_bin;

wire signed [23:0] scan_peak_xr;

wire signed [23:0] scan_peak_xi;

wire [47:0]        scan_peak_pow;

wire [15:0]        scan_sat_cnt;

wire               scan_samp_taken;


wire               Env_Selected;
reg  [4:0]         Env_Dec_Cnt;
reg  signed [15:0] Env_Uplink_Data;
reg                Env_Uplink_Valid;

reg  signed [15:0] Selected_N_Data;
reg                Selected_N_Done;

wire signed [15:0] Upload_Sample_Data;
wire               Upload_Sample_Done;

wire [7:0]  Frame_Data;
wire        Frame_Go;
wire        Tx_Flag;
reg         Tx_Busy;
wire        Echo_Go;
wire [7:0]  Echo_Data;
wire        Send_Go_Req;
wire        Send_Go;
wire [7:0]  Send_Data;
wire        Key_Press;
wire        Led_Heartbeat;
reg         Led_Rx_Toggle;
reg         Led_Sample_Toggle;
wire [2:0]  Led_State;
wire [2:0]  Display_Left;

UART_Receive #(
    .Baud       (2_000_000),
    .CLOCK_FREQ (50_000_000)
) u_UART_Receive(
    .CLK        (CLK),
    .Reset_n    (Reset_n),
    .UART_rx    (UART_rx),
    .flag_rx    (Rx_Flag),
    .Rx_Data    (Rx_Data)
);

ad7606_driver u_ad7606_driver(
    .Clk                 (CLK),
    .Reset_n             (Reset_n),
    .Go                  (1'b1),
    .Speed_Set           (25'd1952),
    .Conv_Done           (ad7606_conv_done),
    .ad7606_cs_n_o       (ad7606_cs_n_o),
    .ad7606_rd_n_o       (ad7606_rd_n_o),
    .ad7606_busy_i       (ad7606_busy_i),
    .ad7606_db_i         (ad7606_db_i),
    .ad7606_os_o         (ad7606_os_o),
    .ad7606_reset_o      (ad7606_reset_o),
    .ad7606_convst_o     (ad7606_convst_o),
    .data_flag           (),
    .data_mult_ch        (),
    .data1               (ad7606_data1),
    .data2               (ad7606_data2),
    .data3               (ad7606_data3),
    .data4               (ad7606_data4),
    .data5               (ad7606_data5),
    .data6               (ad7606_data6),
    .data7               (ad7606_data7),
    .data8               (ad7606_data8)
);

ad7606_sampler u_ad7606_sampler(
    .CLK                 (CLK),
    .Reset_n             (Reset_n),
    .data1               (ad7606_data1),
    .data2               (ad7606_data2),
    .data3               (ad7606_data3),
    .data4               (ad7606_data4),
    .data5               (ad7606_data5),
    .data6               (ad7606_data6),
    .data7               (ad7606_data7),
    .data8               (ad7606_data8),
    .Channel             (Channel),
    .Conv_Done           (ad7606_conv_done),
    .Signed_Data         (ADC_Sample_Signed),
    .Sample_Done         (ADC_Sample_Done)
);

// 2026-09-23: one pulse per AD7606 sample for STM32 TIM2_ETR.
// 50 MHz clock, 50 cycles = 1 us pulse width, 25.6016 kSPS.
always @(posedge CLK or negedge Reset_n) begin
    if (!Reset_n) begin
        Sync_Pulse_Cnt <= 6'd0;
        Sync_Pulse_Reg <= 1'b0;
    end else if (ADC_Sample_Done) begin
        Sync_Pulse_Cnt <= 6'd49;
        Sync_Pulse_Reg <= 1'b1;
    end else if (Sync_Pulse_Cnt != 6'd0) begin
        Sync_Pulse_Cnt <= Sync_Pulse_Cnt - 1'b1;
        if (Sync_Pulse_Cnt == 6'd1)
            Sync_Pulse_Reg <= 1'b0;
    end else begin
        Sync_Pulse_Reg <= 1'b0;
    end
end

assign sync_25k6_o = Sync_Pulse_Reg;

DDS_Module u_DDS_Module(
    .CLK        (CLK),
    .Reset_n    (Reset_n),
    .Mode_Sel   ({1'b0, Wave_SW}),
    .Fword      (Fword),
    .Pword      (12'd0),
    .Data       (DDS_Data)
);

DDS_Sampler #(
    .CLOCK_FREQ (CLOCK_FREQ),
    .SAMPLE_HZ  (SAMPLE_HZ)
) u_DDS_Sampler(
    .CLK         (CLK),
    .Reset_n     (Reset_n),
    .DDS_Data    (DDS_Data),
    .Signed_Data (DDS_Sample_Signed),
    .Sample_Done (DDS_Sample_Done)
);

dds_amplitude_scale u_dds_amplitude_scale(
    .sample_in (DDS_Sample_Signed),
    .amp_sel   (Amp_Sel),
    .sample_out(DDS_Sample_Scaled)
);

// DDS test frequencies: 100,200,...,1500 and 2000 Hz.
always @(*) begin
    case (Freq_SW)
        4'd0:  Fword = 32'd8590;    // 100 Hz
        4'd1:  Fword = 32'd17180;   // 200 Hz
        4'd2:  Fword = 32'd25770;   // 300 Hz
        4'd3:  Fword = 32'd34360;   // 400 Hz
        4'd4:  Fword = 32'd42950;   // 500 Hz
        4'd5:  Fword = 32'd51540;   // 600 Hz
        4'd6:  Fword = 32'd60130;   // 700 Hz
        4'd7:  Fword = 32'd68719;   // 800 Hz
        4'd8:  Fword = 32'd77309;   // 900 Hz
        4'd9:  Fword = 32'd85899;   // 1000 Hz
        4'd10: Fword = 32'd94489;   // 1100 Hz
        4'd11: Fword = 32'd103079;  // 1200 Hz
        4'd12: Fword = 32'd111669;  // 1300 Hz
        4'd13: Fword = 32'd120259;  // 1400 Hz
        4'd14: Fword = 32'd128849;  // 1500 Hz
        default: Fword = 32'd171799; // 2000 Hz
    endcase
end

assign Dataset_Mode = Mode_SW & ~Src_SW & (Wave_SW == 2'd3);
assign Raw_Adc_Debug = Mode_SW & ~Src_SW & (Wave_SW == 2'd2);
assign Matrix_Mode = Mode_SW & ~Src_SW & (Wave_SW == 2'd1);
assign Matrix_Marker_Active = Matrix_Mode && (Matrix_Marker_Count != 4'd0);
assign Matrix_Next = Matrix_Index + 1'b1;

dataset_player u_dataset_player(
    .clk         (CLK),
    .reset_n     (Reset_n),
    .enable      (Dataset_Mode),
    .sample_out  (Dataset_Sample_Signed),
    .sample_done (Dataset_Sample_Done)
);

// Raw ADC diagnostic uplink: every 32nd 25.6 kSPS ADC sample is sent at 800 SPS.
always @(posedge CLK or negedge Reset_n) begin
    if (!Reset_n) begin
        Raw_Adc_Dec_Cnt      <= 5'd0;
        Raw_Adc_Uplink_Data  <= 16'sd0;
        Raw_Adc_Uplink_Valid <= 1'b0;
    end else if (!Raw_Adc_Debug) begin
        Raw_Adc_Dec_Cnt      <= 5'd0;
        Raw_Adc_Uplink_Data  <= 16'sd0;
        Raw_Adc_Uplink_Valid <= 1'b0;
    end else begin
        Raw_Adc_Uplink_Valid <= 1'b0;
        if (ADC_Sample_Done) begin
            if (Raw_Adc_Dec_Cnt == 5'd31) begin
                Raw_Adc_Dec_Cnt      <= 5'd0;
                Raw_Adc_Uplink_Data  <= ADC_Sample_Signed;
                Raw_Adc_Uplink_Valid <= 1'b1;
            end else begin
                Raw_Adc_Dec_Cnt <= Raw_Adc_Dec_Cnt + 1'b1;
            end
        end
    end
end

assign Src_Sample_Signed = Src_SW ? DDS_Sample_Scaled :
                           Dataset_Mode ? Dataset_Sample_Signed : ADC_Sample_Signed;
assign Src_Sample_Done   = Src_SW ? DDS_Sample_Done :
                           Dataset_Mode ? Dataset_Sample_Done : ADC_Sample_Done;

motor_filter_chain u_motor_filter_chain(
    .clk               (CLK),
    .rst_n             (Reset_n),
    .sample_valid      (Src_Sample_Done),
    .sample_in         (Src_Sample_Signed),
    .l1_out            (chain_l1_out),
    .l2_out            (chain_l2_out),
    .n1_out            (chain_n1_out),
    .n2_out            (chain_n2_out),
    .n3_out            (chain_n3_out),
    .rb_out            (chain_rb_out),
    .env_out           (chain_env_out),
    .l1_valid          (chain_l1_valid),
    .l1_dec_valid      (chain_l1_dec_valid),
    .l2_valid          (chain_l2_valid),
    .l2_dec_valid      (chain_l2_dec_valid),
    .n1_valid          (chain_n1_valid),
    .n2_valid          (chain_n2_valid),
    .n3_valid          (chain_n3_valid),
    .rb_valid          (chain_rb_valid),
    .env_valid         (chain_env_valid)
);



assign Scan_Start = (Key_S1_Press && Dataset_Mode) ||
                    (Mode_SW && Rx_Flag && (Rx_Data == 8'h53));



spectrum_scan_b u_spectrum_scan_b (

    .clk        (CLK),

    .rst_n      (Reset_n),

    .scan_start (Scan_Start),

    .din_vld    (chain_l2_valid),

    .din        (chain_l2_out),

    .scan_busy  (scan_busy),

    .scan_done  (scan_done),

    .scan_error (scan_error),

    .bin_idx    (scan_bin_idx),

    .bin_vld    (scan_bin_vld),

    .bin_xr     (scan_bin_xr),

    .bin_xi     (scan_bin_xi),

    .bin_mean   (scan_bin_mean),

    .bin_s1     (scan_bin_s1),

    .bin_s2     (scan_bin_s2),

    .peak_vld   (scan_peak_vld),

    .peak_bin   (scan_peak_bin),

    .peak_xr    (scan_peak_xr),

    .peak_xi    (scan_peak_xi),

    .peak_pow   (scan_peak_pow),

    .sat_cnt    (scan_sat_cnt),

    .samp_taken (scan_samp_taken)

);




assign Scan_Any_Pending    = Scan_Bin_Pending;
assign Scan_Summary_Select = Scan_Summary_Pending && ~Scan_Bin_Pending;
assign Scan_Selected       = scan_busy || Scan_Frame_Busy ||
                             Scan_Bin_Pending || Scan_Summary_Pending;
assign Scan_Frame_Start    = Scan_Any_Pending && ~Scan_Frame_Launched &&
                             ~Scan_Frame_Busy && ~Frame_Busy && ~Tx_Busy && Mode_SW;
assign Raw_L2_Frame_Start  = (Raw_L2_Count != 4'd0) && ~Frame_Busy &&
                             ~Tx_Busy && ~Scan_Frame_Busy &&
                             ~Raw_L2_Sending && ~Scan_Any_Pending && Mode_SW;
assign Raw_L2_Pop          = Frame_Go && Raw_L2_Sending;
assign Raw_L2_Frame_Value  = Raw_L2_Fifo[Raw_L2_Rd_Ptr];

assign Scan_Frame_Idx    = Scan_Bin_Idx_Q;
assign Scan_Frame_Xr     = Scan_Bin_Xr_Q;
assign Scan_Frame_Xi     = Scan_Bin_Xi_Q;
assign Scan_Frame_Status = Scan_Bin_Status_Q;

always @(posedge CLK or negedge Reset_n)
begin
    if(!Reset_n)
    begin
        Scan_Summary_Pending <= 1'b0;
        Scan_Bin_Pending     <= 1'b0;
        Scan_Frame_Launched  <= 1'b0;
        Scan_Bin_Idx_Q       <= 8'd0;
        Scan_Bin_Xr_Q        <= 24'sd0;
        Scan_Bin_Xi_Q        <= 24'sd0;
        Scan_Bin_Status_Q    <= 8'd0;
        Raw_L2_Fifo[0]       <= 16'sd0;
        Raw_L2_Fifo[1]       <= 16'sd0;
        Raw_L2_Fifo[2]       <= 16'sd0;
        Raw_L2_Fifo[3]       <= 16'sd0;
        Raw_L2_Fifo[4]       <= 16'sd0;
        Raw_L2_Fifo[5]       <= 16'sd0;
        Raw_L2_Fifo[6]       <= 16'sd0;
        Raw_L2_Fifo[7]       <= 16'sd0;
        Raw_L2_Wr_Ptr        <= 3'd0;
        Raw_L2_Rd_Ptr        <= 3'd0;
        Raw_L2_Count         <= 4'd0;
        Raw_L2_Sending       <= 1'b0;
    end
    else
    begin
        if(scan_bin_vld)
        begin
            Scan_Bin_Pending  <= 1'b1;
            Scan_Bin_Idx_Q    <= scan_bin_idx;
            Scan_Bin_Xr_Q     <= scan_bin_xr;
            Scan_Bin_Xi_Q     <= scan_bin_xi;
            Scan_Bin_Status_Q <= {1'b0, 3'b000, 1'b0, scan_busy,
                                  (scan_sat_cnt != 16'd0), scan_error};
        end
        else if(Scan_Frame_Go && Scan_Bin_Pending)
        begin
            Scan_Bin_Pending <= 1'b0;
        end

        if(Scan_Frame_Start)
            Scan_Frame_Launched <= 1'b1;
        else if(Scan_Frame_Go)
            Scan_Frame_Launched <= 1'b0;

        if(scan_samp_taken)
        begin
            if(Raw_L2_Count < 4'd8)
            begin
                Raw_L2_Fifo[Raw_L2_Wr_Ptr] <= chain_l2_out;
                Raw_L2_Wr_Ptr <= Raw_L2_Wr_Ptr + 3'd1;
            end
        end

        if(Raw_L2_Frame_Start)
            Raw_L2_Sending <= 1'b1;
        else if(Raw_L2_Pop || Scan_Frame_Start)
            Raw_L2_Sending <= 1'b0;

        if(Raw_L2_Pop)
            Raw_L2_Rd_Ptr <= Raw_L2_Rd_Ptr + 3'd1;

        case({(scan_samp_taken && (Raw_L2_Count < 4'd8)), Raw_L2_Pop})
            2'b10: Raw_L2_Count <= Raw_L2_Count + 4'd1;
            2'b01: Raw_L2_Count <= Raw_L2_Count - 4'd1;
            default: Raw_L2_Count <= Raw_L2_Count;
        endcase
    end
end

scan_frame_send u_scan_frame_send (
    .CLK        (CLK),
    .Reset_n    (Reset_n),
    .Send       (Scan_Frame_Start),
    .Bin_Idx    (Scan_Frame_Idx),
    .Xr         (Scan_Frame_Xr),
    .Xi         (Scan_Frame_Xi),
    .Status     (Scan_Frame_Status),
    .Summary_Bin_Idx(scan_peak_bin),
    .Summary_Xr     (scan_peak_xr),
    .Summary_Xi     (scan_peak_xi),
    .Summary_Status ({1'b1, 3'b000, 1'b1, 1'b0,
                      (scan_sat_cnt != 16'd0), scan_error}),
    .Tx_Flag    (Tx_Flag),
    .Tx_Data    (Scan_Frame_Data),
    .Tx_Go      (Scan_Frame_Go),
    .Frame_Busy (Scan_Frame_Busy)
);

// S0 selects N1/N2/N3/ENV for the UART upload.
always @(*) begin
    case (N_Sel)
        2'd0: begin
            Selected_N_Data = chain_n1_out;
            Selected_N_Done = chain_n1_valid;
        end
        2'd1: begin
            Selected_N_Data = chain_n2_out;
            Selected_N_Done = chain_n2_valid;
        end
        2'd2: begin
            Selected_N_Data = chain_n3_out;
            Selected_N_Done = chain_n3_valid;
        end
        2'd3: begin
            Selected_N_Data = Env_Uplink_Data;
            Selected_N_Done = Env_Uplink_Valid;
        end
        default: begin
            Selected_N_Data = chain_n1_out;
            Selected_N_Done = chain_n1_valid;
        end
    endcase
end

assign Env_Selected = (N_Sel == 2'd3);

// Keep the ENV diagnostic uplink at exactly 25.6 kSPS / 32 = 800 SPS.
// The counter is cleared unless ENV is selected, so each entry starts from
// a known phase.
always @(posedge CLK or negedge Reset_n) begin
    if (!Reset_n) begin
        Env_Dec_Cnt       <= 5'd0;
        Env_Uplink_Data   <= 16'sd0;
        Env_Uplink_Valid  <= 1'b0;
    end else if (!Env_Selected) begin
        Env_Dec_Cnt       <= 5'd0;
        Env_Uplink_Data   <= 16'sd0;
        Env_Uplink_Valid  <= 1'b0;
    end else begin
        Env_Uplink_Valid  <= 1'b0;
        if (chain_env_valid) begin
            if (Env_Dec_Cnt == 5'd31) begin
                Env_Dec_Cnt      <= 5'd0;
                Env_Uplink_Data  <= chain_env_out;
                Env_Uplink_Valid <= 1'b1;
            end else begin
                Env_Dec_Cnt <= Env_Dec_Cnt + 1'b1;
            end
        end
    end
end

assign Upload_Sample_Data = Matrix_Marker_Active ? 16'sh7FFF :
                           Raw_Adc_Debug ? ADC_Sample_Signed :
                           FILTER_ENABLE ? Selected_N_Data : Src_Sample_Signed;
assign Upload_Sample_Done = Matrix_Marker_Active ? Selected_N_Done :
                           Raw_Adc_Debug ? ADC_Sample_Done :
                           FILTER_ENABLE ? Selected_N_Done : Src_Sample_Done;

assign Frame_Send_Start = Raw_L2_Frame_Start ||
                          (Upload_Sample_Done & Mode_SW & ~Scan_Selected);
assign Frame_Send_Value = Raw_L2_Frame_Start ? Raw_L2_Frame_Value :
                          Upload_Sample_Data;

Frame_Send u_Frame_Send(
    .CLK        (CLK),
    .Reset_n    (Reset_n),
    .Send       (Frame_Send_Start),
    .Value      (Frame_Send_Value),
    .Tx_Flag    (Tx_Flag),
    .Tx_Data    (Frame_Data),
    .Tx_Go      (Frame_Go),
    .Frame_Busy (Frame_Busy)
);

Loopback_Buffer u_Loopback_Buffer(
    .CLK        (CLK),
    .Reset_n    (Reset_n),
    .Rx_Flag    (Rx_Flag),
    .Rx_Data    (Rx_Data),
    .Tx_Busy    (Tx_Busy),
    .Echo_Go    (Echo_Go),
    .Echo_Data  (Echo_Data)
);

assign Frame_Go_Mux = Scan_Frame_Go | Frame_Go;

mux2 u_mux2_Send_Go(
    .a          (Echo_Go),
    .b          (Frame_Go_Mux),
    .sel        (Mode_SW),
    .out        (Send_Go_Req)
);

assign Send_Data = Mode_SW ? (Scan_Frame_Go ? Scan_Frame_Data : Frame_Data) : Echo_Data;

always @(posedge CLK or negedge Reset_n) begin
    if (!Reset_n)
        Tx_Busy <= 1'b0;
    else if (Send_Go)
        Tx_Busy <= 1'b1;
    else if (Tx_Flag)
        Tx_Busy <= 1'b0;
end

assign Send_Go = Send_Go_Req & ~Tx_Busy;

UART_Send #(
    .Baud       (2_000_000),
    .CLOCK_FREQ (50_000_000)
) u_UART_Send(
    .CLK        (CLK),
    .Reset_n    (Reset_n),
    .Data       (Send_Data),
    .Send_go    (Send_Go),
    .UART_tx    (UART_tx),
    .tx_flag    (Tx_Flag)
);

Key_shake u_Key_shake_S1(
    .key             (Key_S1),
    .CLK             (CLK),
    .Reset_n         (Reset_n),
    .flag_press_key  (Key_S1_Press),
    .flag_release_key(),
    .key_state       ()
);

Key_shake u_Key_shake(
    .key             (Key),
    .CLK             (CLK),
    .Reset_n         (Reset_n),
    .flag_press_key  (Key_Press),
    .flag_release_key(),
    .key_state       ()
);

// S1 cycles the DDS amplitude test levels.
// 0=100%, 1=75%, 2=50%, 3=25%, 4=10%, 5=125%.
always @(posedge CLK or negedge Reset_n) begin
    if (!Reset_n)
        Amp_Sel <= 3'd0;
    else if (Key_S1_Press && Src_SW)
        Amp_Sel <= (Amp_Sel == 3'd5) ? 3'd0 : Amp_Sel + 1'b1;
end

// S0 selects the ADC channel in ADC mode, and N1/N2/N3/ENV in DDS mode.
always @(posedge CLK or negedge Reset_n) begin
    if (!Reset_n) begin
        Channel      <= 3'd0;
        N_Sel        <= 2'd0;
        Matrix_Count        <= 11'd0;
        Matrix_Index        <= 4'd0;
        Matrix_Marker_Count <= 4'd10;
    end else if (Matrix_Mode) begin
        if (Matrix_Marker_Count != 4'd0) begin
            if (Selected_N_Done)
                Matrix_Marker_Count <= Matrix_Marker_Count - 1'b1;
        end else if (Selected_N_Done) begin
            if (Matrix_Count == 11'd1599) begin
                Matrix_Count <= 11'd0;
                if (Matrix_Index == 4'd15) begin
                    Matrix_Index <= 4'd0;
                    Channel      <= 3'd0;
                    N_Sel        <= 2'd0;
                end else begin
                    Matrix_Index <= Matrix_Next;
                    Channel      <= Matrix_Next[3:2];
                    N_Sel        <= Matrix_Next[1:0];
                end
            end else begin
                Matrix_Count <= Matrix_Count + 1'b1;
            end
        end
    end else begin
        Matrix_Count        <= 11'd0;
        Matrix_Index        <= 4'd0;
        Matrix_Marker_Count <= 4'd10;
        if (Key_Press) begin
            if (Dataset_Mode)
                N_Sel <= N_Sel + 1'b1;
            else if (Src_SW)
                N_Sel <= N_Sel + 1'b1;
            else
                Channel <= Channel + 1'b1;
        end else if (Key_S1_Press && !Src_SW && !Dataset_Mode) begin
            N_Sel <= N_Sel + 1'b1;
        end
    end
end

assign Display_Left = (Mode_SW & ~Src_SW) ? Channel : Amp_Sel;

seg7_display u_seg7_display(
    .CLK         (CLK),
    .Reset_n     (Reset_n),
    .channel_sel (N_Sel),
    .left_sel    (Display_Left),
    .SEG7_DIO    (SEG7_DIO),
    .SEG7_RCLK   (SEG7_RCLK),
    .SEG7_SCLK   (SEG7_SCLK)
);

led_twinkle u_led_twinkle(
    .CLK        (CLK),
    .Reset_n    (Reset_n),
    .LED        (Led_Heartbeat)
);

always @(posedge CLK or negedge Reset_n) begin
    if (!Reset_n)
        Led_Rx_Toggle <= 1'b0;
    else if (Rx_Flag)
        Led_Rx_Toggle <= ~Led_Rx_Toggle;
end

always @(posedge CLK or negedge Reset_n) begin
    if (!Reset_n)
        Led_Sample_Toggle <= 1'b0;
    else if (Dataset_Mode ? scan_bin_vld : Upload_Sample_Done)
        Led_Sample_Toggle <= ~Led_Sample_Toggle;
end

assign Led_State = (Mode_SW & Src_SW) ? Amp_Sel : Channel;
assign LED = {Dataset_Mode ? scan_error : Src_SW, Mode_SW, Led_State, Led_Sample_Toggle, Led_Rx_Toggle, Led_Heartbeat};

endmodule




