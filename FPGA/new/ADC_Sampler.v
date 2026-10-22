`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/09/11 18:30:00
// Design Name: 
// Module Name: ADC_Sampler
// Project Name: FIR_DSP_test
// Target Devices: xc7a35tfgg484-2
// Tool Versions: Vivado 2018.3
// Description: 
//     ADC 采样时序 + 数据缩放。ADC_Driver 只负责把 12bit 数据从 SPI 读出，
//     其余采样控制由本模块完成：
//       1. 按固定节拍（每 SAMPLE_HZ 次）启动 ADC_Driver 的一次转换；
//       2. 将 12bit 无符号原始值转换为 16bit 有符号，便于后续滤波。
// 
// Dependencies: 
//     ADC_Driver.v
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//     ADC128S102 输出码 0~4095 为无符号数，中间值 2048 对应“零电平”。
//     将输入值减 2048 后得到 -2048~+2047，再左移 4 位
//     得到 -32768~+32752，即 16bit 有符号数。
//     这段逻辑对应“ADC 采样”支路的接口，要求 C 代码一致。
// 
//////////////////////////////////////////////////////////////////////////////////


module ADC_Sampler(
    input                    CLK,
    input                    Reset_n,
    input      [11:0]        ADC_Data,
    input                    ADC_Done,
    output reg               Conv_Go,
    output reg [11:0]        Raw_Data,
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
reg        Conv_Busy;

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

// 2. 转换启动脉冲：ADC_Driver 要求 Conv_Go 为单周期脉冲：
//    如果一直拉高，内部 en_Conv 将无法复位，会卡住。
always@(posedge CLK or negedge Reset_n)
begin
    if(!Reset_n)
        Conv_Go <= 1'b0;
    else
        Conv_Go <= sample_tick && !Conv_Busy;
end

// 3. 转换忙标志：防止一次转换尚未完成时再次启动。
always@(posedge CLK or negedge Reset_n)
begin
    if(!Reset_n)
        Conv_Busy <= 1'b0;
    else if(sample_tick && !Conv_Busy)
        Conv_Busy <= 1'b1;
    else if(ADC_Done)
        Conv_Busy <= 1'b0;
end

// 4. 可调更新点：保存原始值，并将 12bit 无符号数转换为 16bit 有符号数。
//    ADC_Driver 的 data 与 Conv_flag 在同一时钟边沿更新。
//    因此 Conv_flag 为 1 的下一拍，ADC_Data 已经稳定。
always@(posedge CLK or negedge Reset_n)
begin
    if(!Reset_n)
    begin
        Raw_Data    <= 12'd0;
        Signed_Data <= 16'sd0;
        Sample_Done <= 1'b0;
    end
    else if(ADC_Done)
    begin
        Raw_Data    <= ADC_Data;
        Signed_Data <= ($signed({4'b0000, ADC_Data}) - 16'sd2048) <<< 4;
        Sample_Done <= 1'b1;
    end
    else
        Sample_Done <= 1'b0;
end

endmodule

