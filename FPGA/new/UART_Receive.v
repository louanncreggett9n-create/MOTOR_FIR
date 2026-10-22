`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/09/08 20:23:44
// Design Name: 
// Module Name: UART1
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


module UART_Receive(
    input CLK,
    input Reset_n,
    input UART_rx,
    output reg flag_rx,
    output reg [7:0] Rx_Data
    );
    //波特率计数器
    reg [29:0]Baud_counter;
    reg en_Baud_counter;
    reg [3:0]bit_counter;
    reg r_UART_rx;
    reg dff0_UART_rx;
    reg dff1_UART_rx;
    reg [7:0] r_Rx_Data;
    wire W_flag_rx;
    wire nedge_UART_rx;
    wire abort_start_detect;
    parameter Baud = 9600;
    parameter CLOCK_FREQ = 50_000_000;
    parameter Baud_CMNT = CLOCK_FREQ / Baud - 1;
    always@(posedge CLK or negedge Reset_n)
    begin
        if(!Reset_n)
            Baud_counter <= 0;
        else if(en_Baud_counter)
        begin
            if(abort_start_detect)
                Baud_counter <= 0;
            else if(Baud_counter == Baud_CMNT)
                Baud_counter <= 0;
            else
                Baud_counter <= Baud_counter + 1'b1;
        end
        else
            Baud_counter <= 0;
    end
   //UART边沿检测
    always@(posedge  CLK)
        dff0_UART_rx <=UART_rx;
    always@(posedge  CLK)
        dff1_UART_rx <=dff0_UART_rx;        
    always@(posedge  CLK)
        r_UART_rx <= dff1_UART_rx;
    assign  nedge_UART_rx = (r_UART_rx == 1)&&(dff1_UART_rx == 0);
    assign  abort_start_detect = (Baud_counter == Baud_CMNT/2)&&(dff1_UART_rx == 1)&&(bit_counter == 0);
   //波特率计数器使能 
    always@(posedge CLK or negedge Reset_n)
    begin
        if(!Reset_n)
            en_Baud_counter <= 0;
        else if(nedge_UART_rx)
            en_Baud_counter <= 1;
        else if(abort_start_detect)
             en_Baud_counter <= 0;
        else if((Baud_counter == Baud_CMNT)&&(bit_counter == 9))
             en_Baud_counter <= 0;
    end
    //位计数器
    always@(posedge CLK or negedge Reset_n)
    begin
        if(!Reset_n)
            bit_counter <= 0;
        else if(Baud_counter == Baud_CMNT)
        begin
            if(bit_counter == 9)
                bit_counter <= 0;
            else
                bit_counter <= bit_counter + 1'b1;
        end
    end
    //位接受
always@(posedge CLK or negedge Reset_n)
begin
    if(!Reset_n)
        r_Rx_Data <= 8'd0;
    else if(Baud_counter == Baud_CMNT/2)
    begin
        case(bit_counter)    
            1:r_Rx_Data[0] <= dff1_UART_rx;    
            2:r_Rx_Data[1] <= dff1_UART_rx;
            3:r_Rx_Data[2] <= dff1_UART_rx;
            4:r_Rx_Data[3] <= dff1_UART_rx;
            5:r_Rx_Data[4] <= dff1_UART_rx;
            6:r_Rx_Data[5] <= dff1_UART_rx;
            7:r_Rx_Data[6] <= dff1_UART_rx;
            8:r_Rx_Data[7] <= dff1_UART_rx;     
            default : Rx_Data <= Rx_Data;
        endcase
    end
end
//接收完成标志位
    assign W_flag_rx = (Baud_counter == Baud_CMNT)&&(bit_counter == 9);
    always@(posedge  CLK)
        flag_rx <= W_flag_rx;
    always@(posedge  CLK)
    if(W_flag_rx)
        Rx_Data <= r_Rx_Data;
endmodule
