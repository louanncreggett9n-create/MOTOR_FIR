`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/09/05 16:29:03
// Design Name: 
// Module Name: led_twinkle
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


module led_twinkle(
    CLK,
    Reset_n,
    LED
    );
    input CLK;
    input Reset_n;
    output reg LED;
    reg[24:0] counter;
    always@(posedge CLK or negedge Reset_n )
        if(!Reset_n)
            counter <= 0;
        else if(counter == 25_000_000 - 1)
            counter <= 0;
        else
            counter <= counter + 1'd1;
     always@(posedge CLK or negedge Reset_n )
        if(!Reset_n)
            LED <= 1'b0;
        else if(counter == 25_000_000 - 1)
            LED <= !LED;
        else
           LED <=LED;    
        
endmodule
