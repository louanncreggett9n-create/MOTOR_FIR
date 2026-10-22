`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/09/13 21:00:00
// Design Name: 
// Module Name: DDS_Sampler
// Project Name: FIR_DSP_test
// Target Devices: xc7a35tfgg484-2
// Tool Versions: Vivado 2018.3
// Description: 
//     DDS 采样时序 + 数据缩放。与 ADC_Sampler 是对称的，包括：
//       1. 按固定节拍（每 SAMPLE_HZ 次）从 DDS_Module 取一个样点；
//       2. 将 14bit 无符号数转换为 16bit 有符号数，与 ADC 支路统一。
// 
//     DDS_Module 输出的数据在 50MHz 每个时钟都更新，
//     要上传的数据先按固定节拍抽取，再由 UART 端发送。
//     这样 DDS 和 ADC 支路使用同一个 SAMPLE_HZ，两条支路数据一致，
//     端到端测试时便于比较谁发送的数据。
// 
// Dependencies: 
//     DDS_Module.v
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//     DDS_Module 输出的 0~16383 为偏移二进制，中间值 8192 对应“零电平”。
//     将输入值减 8192 后得到 -8192~+8191，再左移 2 位
//     得到 -32768~+32764，即 16bit 有符号数。
//     与 ADC_Sampler 的 (12bit-2048)<<4 使用同一数据路径。
// 
//     例化的 n 是 DDS 波形的相位位置，由 DDS 的 Fword 决定。
//     要输出正弦波，DDS 输出频率应明显低于 SAMPLE_HZ。
// 
//////////////////////////////////////////////////////////////////////////////////


module DDS_Sampler(
    input                    CLK,
    input                    Reset_n,
    input      [13:0]        DDS_Data,
    output reg signed [15:0] Signed_Data,
    output reg               Sample_Done
);

// 采样参数
parameter CLOCK_FREQ = 50_000_000;
parameter SAMPLE_HZ  = 25600;
parameter TICK_MCNT  = CLOCK_FREQ / SAMPLE_HZ - 1;

// 内部信号定义
reg [24:0] tick_counter;
reg        sample_tick;

// 1. 采样节拍：每 TICK_MCNT+1 个周期产生一次单周期脉冲。
//    注意：这里只使用单周期脉冲，全程保持时序一致。
always@(posedge CLK or negedge Reset_n)
begin
    if(!Reset_n)
    begin
        tick_counter <= 0;
        sample_tick  <= 1'b0;
    end
    else if(tick_counter == TICK_MCNT)
    begin
        tick_counter <= 0;
        sample_tick  <= 1'b1;
    end
    else
    begin
        tick_counter <= tick_counter + 1'b1;
        sample_tick  <= 1'b0;
    end
end

// 2. 可调更新点：保存当前样点，并将 14bit 无符号数转换为 16bit 有符号数。
//    Sample_Done 与样点在同一时钟边沿更新，因此 Frame_Send 在
//    Sample_Done 为 1 的下一拍读取 Value，取到的就是稳定值。
always@(posedge CLK or negedge Reset_n)
begin
    if(!Reset_n)
    begin
        Signed_Data <= 16'sd0;
        Sample_Done <= 1'b0;
    end
    else if(sample_tick)
    begin
        Signed_Data <= ($signed({2'b00, DDS_Data}) - 16'sd8192) <<< 2;
        Sample_Done <= 1'b1;
    end
    else
        Sample_Done <= 1'b0;
end

endmodule
