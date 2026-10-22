`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/09/11 18:30:00
// Design Name: 
// Module Name: Loopback_Buffer
// Project Name: FIR_DSP_test
// Target Devices: xc7a35tfgg484-2
// Tool Versions: Vivado 2018.3
// Description: 
//     串口回环用的一字节缓冲。收到一个字节先存着，
//     等串口把上一个发完了再回显
// 
// Dependencies: 
//     无
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//     为什么需要它：收和发的速度是一模一样的（都是 115200，一位不差）。
//     如果收到就立刻回，上一字节刚好发完的同一瞬间，下一个字节也刚好收完，
//     这个字节就没地方去，只能丢掉——粘贴一段文字会掉一半。
//     加一个字节的缓冲，正好抹平这个"刚好撞上"的时间点。
// 
//     注意：这只是缓一个字节的应急办法，最多只能扛住一字节的抖动。
//     以后采样率提高、数据量变大，要换成真正的 FIFO。
// 
//////////////////////////////////////////////////////////////////////////////////


module Loopback_Buffer(
    input            CLK,
    input            Reset_n,
    input            Rx_Flag,
    input      [7:0] Rx_Data,
    input            Tx_Busy,
    output reg       Echo_Go,
    output reg [7:0] Echo_Data
);

// 内部信号定义
reg       Flag_Pending;
reg [7:0] r_Hold;

always@(posedge CLK or negedge Reset_n)
begin
    if(!Reset_n)
    begin
        Flag_Pending <= 1'b0;
        r_Hold       <= 8'd0;
        Echo_Go      <= 1'b0;
        Echo_Data    <= 8'd0;
    end
    else
    begin
        Echo_Go <= 1'b0;            // 默认只给一拍
        if(Rx_Flag)
        begin
            // 新收到一个，先压着
            r_Hold       <= Rx_Data;
            Flag_Pending <= 1'b1;
        end
        else if(Flag_Pending && !Tx_Busy)
        begin
            // 串口空了，把手上的发出去
            Echo_Go      <= 1'b1;
            Echo_Data    <= r_Hold;
            Flag_Pending <= 1'b0;
        end
    end
end

endmodule
