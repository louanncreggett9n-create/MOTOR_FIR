`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/09/11 18:30:00
// Design Name: 
// Module Name: Frame_Send
// Project Name: FIR_DSP_test
// Target Devices: xc7a35tfgg484-2
// Tool Versions: Vivado 2018.3
// Description: 
//     把一路 16bit 采样值打成 5 字节的串口帧，一个字节一个字节推给 UART_Send
// 
// Dependencies: 
//     UART_Send.v
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//     帧格式（这就是 B 和 A 要对齐的"板子到电脑"接口，要改就两边一起改）：
//       +--------+--------+--------+--------+--------+
//       |  0xAA  |  0x55  |  高字节 |  低字节 | 累加和 |
//       +--------+--------+--------+--------+--------+
//       累加和 = (0xAA + 0x55 + 高字节 + 低字节) 取低 8 位
// 
//     为什么要有 WAIT 这个状态：
//       UART_Send 收到 Send_go 之后，要过一拍才会真正开始发。
//       如果不确认"它已经忙起来了"就接着发下一个字节，
//       下一个字节会把当前这个顶掉，帧里会莫名少一个字节。
// 
//////////////////////////////////////////////////////////////////////////////////


module Frame_Send(
    input                CLK,
    input                Reset_n,
    input                Send,
    input  signed [15:0] Value,
    input                Tx_Flag,
    output reg [7:0]     Tx_Data,
    output reg           Tx_Go,
    output reg           Frame_Busy
);

// 状态定义
localparam IDLE = 0;
localparam SEND = 1;
localparam WAIT = 2;

// 内部信号定义
reg [1:0]         state;
reg [2:0]         byte_idx;
reg signed [15:0] r_Value;
reg [7:0]         r_Byte;

// 累加和：四个字节相加取低 8 位
wire [7:0] W_Sum = 8'hAA + 8'h55 + r_Value[15:8] + r_Value[7:0];

// 当前要发哪个字节（组合逻辑）
always@(*)
begin
    case(byte_idx)
        3'd0:    r_Byte = 8'hAA;
        3'd1:    r_Byte = 8'h55;
        3'd2:    r_Byte = r_Value[15:8];
        3'd3:    r_Byte = r_Value[7:0];
        3'd4:    r_Byte = W_Sum;
        default: r_Byte = 8'h00;
    endcase
end

// 主状态机
always@(posedge CLK or negedge Reset_n)
begin
    if(!Reset_n)
    begin
        state      <= IDLE;
        byte_idx   <= 3'd0;
        r_Value    <= 16'sd0;
        Tx_Go      <= 1'b0;
        Tx_Data    <= 8'h00;
        Frame_Busy <= 1'b0;
    end
    else
    begin
        case(state)
            IDLE:
            begin
                Tx_Go      <= 1'b0;
                Frame_Busy <= 1'b0;
                if(Send)
                begin
                    r_Value  <= Value;
                    byte_idx <= 3'd0;
                    state    <= SEND;
                end
            end
            // 给 UART_Send 一个单拍 Send_go，同时把数据摆好
            SEND:
            begin
                Tx_Go      <= 1'b1;
                Tx_Data    <= r_Byte;
                Frame_Busy <= 1'b1;
                state      <= WAIT;
            end
            // 等这一字节发完（tx_flag 给一拍脉冲），再发下一个
            WAIT:
            begin
                Tx_Go <= 1'b0;
                if(Tx_Flag)
                begin
                    if(byte_idx == 3'd4)
                    begin
                        state      <= IDLE;
                        Frame_Busy <= 1'b0;
                    end
                    else
                    begin
                        byte_idx <= byte_idx + 1'b1;
                        state    <= SEND;
                    end
                end
            end
            default: state <= IDLE;
        endcase
    end
end

endmodule
