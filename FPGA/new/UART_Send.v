//`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////////
//// Company: 
//// Engineer: 
//// 
//// Create Date: 2026/09/08 10:48:12
//// Design Name: 
//// Module Name: UART0
//// Project Name: 
//// Target Devices: 
//// Tool Versions: 
//// Description: 
//// 
//// Dependencies: 
//// 
//// Revision:
//// Revision 0.01 - File Created
//// Additional Comments:
//// 
////////////////////////////////////////////////////////////////////////////////////


//module UART0(
//    Data,
//    CLK,
//    Reset_n,
//    UART_tx,
//    Send_go,
////    LED,
//    tx_flag
//    );
//    input [7:0]Data;
//    input CLK;
//    input Reset_n;
//    input Send_go;
//    output reg UART_tx;
////    output reg LED;
//    output reg tx_flag;
//    wire W_tx_flag;
//    reg [25:0]baud_counter;
//    reg [1:0]en_baud_counter;
//    reg [3:0] bit_counter;
////    reg [25:0]delay_counter;
//    reg [7:0]r_Data;
    
//    parameter Baud = 9600;
//    parameter CLOCK_FREQ = 50_000_000;
//    parameter baud_MCNT = CLOCK_FREQ / Baud - 1;
//    parameter bit_MCNT = 9;
////    parameter delay_MCNT = 50_000_000 - 1;

//    //波特率计数器
//    assign W_tx_flag = (bit_counter == bit_MCNT)&&(baud_counter == baud_MCNT);
//    always@(posedge CLK or negedge Reset_n)
//    begin
//        if(!Reset_n)
//            baud_counter <= 0;
//        else if(en_baud_counter)
//        begin
//            if(baud_counter == baud_MCNT)
//                baud_counter <= 0;
//            else
//                baud_counter <=baud_counter + 1'd1;
//        end
//        else
//            baud_counter <= 0;
//    end
//    always@(posedge CLK or negedge Reset_n)
//    begin
//        if(!Reset_n)
//            en_baud_counter <=0;
//        else if(Send_go)
//            en_baud_counter <=1;
//        else if(W_tx_flag)
//            en_baud_counter <=0;
//    end
//    //位计数器
//     always@(posedge CLK or negedge Reset_n)
//    begin
//        if(!Reset_n)
//            bit_counter <= 0;
//        else if(baud_counter == baud_MCNT)
//            begin
//                if(bit_counter == bit_MCNT)
//                    bit_counter <= 0;
//                else
//                    bit_counter <=bit_counter + 1'd1;
//            end
//    end
//    //延时计数器（D触发器储存）

    
////    always@(posedge CLK or negedge Reset_n)
////    begin
////         if(!Reset_n)
////            delay_counter <=0;
////         else if(delay_counter ==delay_MCNT)
////            delay_counter <=0;
////         else
////            delay_counter <= delay_counter +1'd1;

////    end
    
//    always@(posedge CLK or negedge Reset_n)
//    begin
//         if(!Reset_n)
//            r_Data <=0;
//         else if(Send_go)
//            r_Data  <=Data;
//    end
//    //位发送
//     always@(posedge CLK or negedge Reset_n)
//    begin
//        if(!Reset_n)
//            UART_tx <= 1'd1;
//        else if(en_baud_counter)
//            begin
//            case(bit_counter)
//                0:UART_tx <= 1'd0;
//                1:UART_tx <= r_Data[0];
//                2:UART_tx <= r_Data[1];
//                3:UART_tx <= r_Data[2];
//                4:UART_tx <= r_Data[3];
//                5:UART_tx <= r_Data[4];
//                6:UART_tx <= r_Data[5];
//                7:UART_tx <= r_Data[6];
//                8:UART_tx <= r_Data[7];
//                9:UART_tx <= 1'd1;
//                default:UART_tx <= UART_tx;
//            endcase
//            end
//         else
//            UART_tx <= 1'b1;
//   end
//   always@(posedge CLK or negedge Reset_n)
//    begin
//        tx_flag <=W_tx_flag;
//    end
//   //LED翻转
////   always@(posedge CLK or negedge Reset_n)
////    begin
////        if(!Reset_n)
////            LED <= 1'b0;
////        else if((bit_counter == bit_MCNT)&&(baud_counter == baud_MCNT))
////            LED <= !LED;

////    end

//endmodule
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/09/08 10:48:12
// Design Name: 
// Module Name: UART0
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module UART_Send(
    input       [7:0] Data,
    input             CLK,
    input             Reset_n,
    input             Send_go,
    output reg        UART_tx,
    output reg        tx_flag
);

// 内部信号定义
wire W_tx_flag;
reg  [25:0] baud_counter;
reg         en_baud_counter;  // 修正：位宽从2位改为1位，消除冗余
reg  [3:0]  bit_counter;
reg  [7:0]  r_Data;

// 参数定义
parameter Baud       = 9600;
parameter CLOCK_FREQ = 50_000_000;
parameter baud_MCNT  = CLOCK_FREQ / Baud - 1;
parameter bit_MCNT   = 9;

// 发送完成标志组合逻辑
assign W_tx_flag = (bit_counter == bit_MCNT) && (baud_counter == baud_MCNT);

// 1. 波特率计数器
always@(posedge CLK or negedge Reset_n)
begin
    if(!Reset_n)
        baud_counter <= 0;
    else if(en_baud_counter)
    begin
        if(baud_counter == baud_MCNT)
            baud_counter <= 0;
        else
            baud_counter <= baud_counter + 1'b1;  // 修正：统一用1'b1二进制位常量
    end
    else
        baud_counter <= 0;
end

// 2. 发送使能信号
always@(posedge CLK or negedge Reset_n)
begin
    if(!Reset_n)
        en_baud_counter <= 1'b0;
    else if(Send_go)
        en_baud_counter <= 1'b1;
    else if(W_tx_flag)
        en_baud_counter <= 1'b0;
end

// 3. 位计数器
always@(posedge CLK or negedge Reset_n)
begin
    if(!Reset_n)
        bit_counter <= 0;
    else if(baud_counter == baud_MCNT)
    begin
        if(bit_counter == bit_MCNT)
            bit_counter <= 0;
        else
            bit_counter <= bit_counter + 1'b1;
    end
end

// 4. 发送数据锁存
always@(posedge CLK or negedge Reset_n)
begin
    if(!Reset_n)
        r_Data <= 8'd0;
    else if(Send_go)
        r_Data <= Data;
end

// 5. 串口发送移位逻辑
always@(posedge CLK or negedge Reset_n)
begin
    if(!Reset_n)
        UART_tx <= 1'b1;  // 空闲位为高电平
    else if(en_baud_counter)
    begin
        case(bit_counter)
            0       : UART_tx <= 1'b0;       // 起始位
            1       : UART_tx <= r_Data[0];  // 数据位0（LSB先发）
            2       : UART_tx <= r_Data[1];
            3       : UART_tx <= r_Data[2];
            4       : UART_tx <= r_Data[3];
            5       : UART_tx <= r_Data[4];
            6       : UART_tx <= r_Data[5];
            7       : UART_tx <= r_Data[6];
            8       : UART_tx <= r_Data[7];  // 数据位7（MSB后发）
            9       : UART_tx <= 1'b1;       // 停止位
            default : UART_tx <= 1'b1;
        endcase
    end
    else
        UART_tx <= 1'b1;  // 空闲状态保持高电平
end

// 6. 发送完成标志打拍（修正：补充复位逻辑，消除时钟歧义报错）
always@(posedge CLK or negedge Reset_n)
begin
    if(!Reset_n)
        tx_flag <= 1'b0;
    else
        tx_flag <= W_tx_flag;
end

endmodule
