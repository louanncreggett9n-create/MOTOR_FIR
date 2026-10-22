`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/09/13 15:07:56
// Design Name: 
// Module Name: DDS_Module
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
//     DDS 波形发生器。相位累加器 + 三张波形查找表 ROM，输出 14bit 波形数据。
//       1. 相位累加器：每个时钟 Freq_ACC = Freq_ACC + Fword
//          输出频率 fout = Fword * fclk / 2^32
//          取 32bit 累加器的高 12 位当 ROM 地址，所以一个波形周期是 4096 个点
//       2. 相位偏移：ROM_addr = Freq_ACC[31:20] + Pword
//          给地址加一个固定常数，用来做两路 DDS 之间的固定相位差
//       3. 输出选择：Mode_Sel = 0 正弦，= 1 方波，= 2 三角波
// 
//     三种波形都用 ROM 查表产生，同一时刻三张表一起吃同一个地址，
//     最后按 Mode_Sel 选一个输出。ROM 输出打一拍，选择再打一拍，
//     所以 Data 相对 ROM_addr 一共延迟 2 拍。
// 
// Dependencies: 
//     sine_wave_rom       —— 14bit x 4096，初始化文件 sine_wave.coe
//     square_wave_rom     —— 14bit x 4096，初始化文件 square_wave.coe
//     triangular_wave_rom —— 14bit x 4096，初始化文件 triangular_wave.coe
//     三张表都是偏移二进制，0 对应最小值，2048 对应中点，4095 对应最大值
// 
// Revision:
// Revision 0.01 - File Created
// Revision 0.02 - 2026/09/13 方波和三角波改为查表产生，删去原来用
//                   ROM_addr[11] 搭出来的方波逻辑
// Additional Comments:
//     Fword 换算举例：50MHz 时钟下要出 1kHz，
//         Fword = 1000 * 2^32 / 50_000_000 = 85899
// 
//////////////////////////////////////////////////////////////////////////////////


module DDS_Module(
    input CLK,
    input Reset_n,
    input [2:0] Mode_Sel,
    input [31:0] Fword,
    input [11:0] Pword,
    output reg[13:0] Data
    );
    reg[31:0] r_Fword;
    reg[11:0] r_Pword;
    reg[31:0] Freq_ACC; 
    wire [11:0] ROM_addr;
    wire [13:0]Data_sine;
    wire [13:0]Data_square;
    wire [13:0]Data_Triangular;
    always@(posedge CLK)
        r_Fword <= Fword;
     always@(posedge CLK)
        r_Pword <= Pword;
    always@(posedge CLK or negedge Reset_n)
    if(!Reset_n)
        Freq_ACC <=0;
    else
        Freq_ACC <= r_Fword + Freq_ACC;
    assign ROM_addr = Freq_ACC[31:20] + r_Pword;

    // 正弦查找表：4096 x 14bit，初始化文件 sine_wave.coe
    sine_wave_rom u_sine_wave_rom(
        .clka   (CLK),
        .addra  (ROM_addr),
        .douta  (Data_sine)
    );

    // 方波查找表：4096 x 14bit，初始化文件 square_wave.coe
    square_wave_rom u_square_wave_rom(
        .clka   (CLK),
        .addra  (ROM_addr),
        .douta  (Data_square)
    );

    // 三角波查找表：4096 x 14bit，初始化文件 triangular_wave.coe
    triangular_wave_rom u_triangular_wave_rom(
        .clka   (CLK),
        .addra  (ROM_addr),
        .douta  (Data_Triangular)
    );

    // 波形选择
    always@(posedge CLK or negedge Reset_n)
    if(!Reset_n)
        Data <=14'd0;
    else
        case(Mode_Sel)
            3'd1    : Data <= Data_square;
            3'd2    : Data <= Data_Triangular;
            default : Data <= Data_sine;
        endcase

endmodule