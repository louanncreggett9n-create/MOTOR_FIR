`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: motor_filter_chain
// Description:
//     Dataset-backed 25.6 kSPS motor vibration FIR chain.
//
//     IP configuration follows the new MATLAB coefficient set:
//       L1 : 25.6 kSPS -> decimate by 8 -> 3.2 kSPS
//       L2 : 3.2 kSPS  -> decimate by 4 -> 800 SPS
//       N1 : single rate 800 SPS, centered at 100 Hz
//       N2 : single rate 800 SPS, centered at 200 Hz
//       N3 : single rate 800 SPS, centered at 300 Hz
//       RB : single rate 25.6 kSPS, 700-1500 Hz band-pass
//       ENV: single rate 25.6 kSPS, envelope low-pass
//
//     The signed FIR Compiler IPs keep 17 output bits so that the integer Q17
//     coefficient scaling matches the MATLAB reference. ENV uses a 16-bit
//     output because its all-positive coefficients are optimized as unsigned.
//     All module outputs are saturated back to the original 16-bit interface.
//////////////////////////////////////////////////////////////////////////////////

module motor_filter_chain(
    input  wire               clk,
    input  wire               rst_n,
    input  wire               sample_valid,
    input  wire signed [15:0] sample_in,
    output wire signed [15:0] l1_out,
    output wire signed [15:0] l2_out,
    output wire signed [15:0] n1_out,
    output wire signed [15:0] n2_out,
    output wire signed [15:0] n3_out,
    output wire signed [15:0] rb_out,
    output wire signed [15:0] env_out,
    output wire               l1_valid,
    output wire               l1_dec_valid,
    output wire               l2_valid,
    output wire               l2_dec_valid,
    output wire               n1_valid,
    output wire               n2_valid,
    output wire               n3_valid,
    output wire               rb_valid,
    output wire               env_valid
);

    wire signed [23:0] l1_ip_data;
    wire signed [23:0] l2_ip_data;
    wire signed [23:0] n1_ip_data;
    wire signed [23:0] n2_ip_data;
    wire signed [23:0] n3_ip_data;
    wire signed [23:0] rb_ip_data;
    wire signed [23:0] env_ip_data;

    wire l1_ip_valid;
    wire l2_ip_valid;
    wire n1_ip_valid;
    wire n2_ip_valid;
    wire n3_ip_valid;
    wire rb_ip_valid;
    wire env_ip_valid;

    wire l1_ip_ready;
    wire l2_ip_ready;
    wire n1_ip_ready;
    wire n2_ip_ready;
    wire n3_ip_ready;
    wire rb_ip_ready;
    wire env_ip_ready;
    wire all_ip_ready;

    function signed [15:0] sat16;
        input signed [23:0] value;
        begin
            if (value > 24'sd32767)
                sat16 = 16'sh7fff;
            else if (value < -24'sd32768)
                sat16 = 16'sh8000;
            else
                sat16 = value[15:0];
        end
    endfunction

    assign l1_out = sat16(l1_ip_data);
    assign l2_out = sat16(l2_ip_data);
    assign n1_out = sat16(n1_ip_data);
    assign n2_out = sat16(n2_ip_data);
    assign n3_out = sat16(n3_ip_data);
    assign rb_out = sat16(rb_ip_data);
    assign env_out = sat16(env_ip_data);

    assign all_ip_ready = l1_ip_ready & l2_ip_ready & n1_ip_ready &
                         n2_ip_ready & n3_ip_ready & rb_ip_ready &
                         env_ip_ready;

    wire signed [15:0] rb_abs = (rb_out == 16'sh8000) ?
                                16'sh7fff :
                                (rb_out[15] ? -rb_out : rb_out);

    fir_L1 u_l1_ip (
        .aresetn            (rst_n),
        .aclk               (clk),
        .s_axis_data_tvalid (sample_valid),
        .s_axis_data_tready (l1_ip_ready),
        .s_axis_data_tdata  (sample_in),
        .m_axis_data_tvalid (l1_ip_valid),
        .m_axis_data_tdata  (l1_ip_data)
    );

    fir_L2 u_l2_ip (
        .aresetn            (rst_n),
        .aclk               (clk),
        .s_axis_data_tvalid (l1_ip_valid),
        .s_axis_data_tready (l2_ip_ready),
        .s_axis_data_tdata  (l1_out),
        .m_axis_data_tvalid (l2_ip_valid),
        .m_axis_data_tdata  (l2_ip_data)
    );

    fir_N1 u_n1_ip (
        .aresetn            (rst_n),
        .aclk               (clk),
        .s_axis_data_tvalid (l2_ip_valid),
        .s_axis_data_tready (n1_ip_ready),
        .s_axis_data_tdata  (l2_out),
        .m_axis_data_tvalid (n1_ip_valid),
        .m_axis_data_tdata  (n1_ip_data)
    );

    fir_N2 u_n2_ip (
        .aresetn            (rst_n),
        .aclk               (clk),
        .s_axis_data_tvalid (l2_ip_valid),
        .s_axis_data_tready (n2_ip_ready),
        .s_axis_data_tdata  (l2_out),
        .m_axis_data_tvalid (n2_ip_valid),
        .m_axis_data_tdata  (n2_ip_data)
    );

    fir_N3 u_n3_ip (
        .aresetn            (rst_n),
        .aclk               (clk),
        .s_axis_data_tvalid (l2_ip_valid),
        .s_axis_data_tready (n3_ip_ready),
        .s_axis_data_tdata  (l2_out),
        .m_axis_data_tvalid (n3_ip_valid),
        .m_axis_data_tdata  (n3_ip_data)
    );

    fir_RB u_rb_ip (
        .aresetn            (rst_n),
        .aclk               (clk),
        .s_axis_data_tvalid (sample_valid),
        .s_axis_data_tready (rb_ip_ready),
        .s_axis_data_tdata  (sample_in),
        .m_axis_data_tvalid (rb_ip_valid),
        .m_axis_data_tdata  (rb_ip_data)
    );

    fir_ENV u_env_ip (
        .aresetn            (rst_n),
        .aclk               (clk),
        .s_axis_data_tvalid (rb_ip_valid),
        .s_axis_data_tready (env_ip_ready),
        .s_axis_data_tdata  (rb_abs),
        .m_axis_data_tvalid (env_ip_valid),
        .m_axis_data_tdata  (env_ip_data)
    );

    // The IP cores perform the L1/L2 integer decimation internally.
    assign l1_valid     = l1_ip_valid;
    assign l1_dec_valid = l1_ip_valid;
    assign l2_valid     = l2_ip_valid;
    assign l2_dec_valid = l2_ip_valid;

    assign n1_valid  = n1_ip_valid;
    assign n2_valid  = n2_ip_valid;
    assign n3_valid  = n3_ip_valid;
    assign rb_valid  = rb_ip_valid;
    assign env_valid = env_ip_valid;

endmodule




