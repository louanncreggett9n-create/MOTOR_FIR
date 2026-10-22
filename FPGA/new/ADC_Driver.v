`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/09/10 15:41:41
// Design Name: 
// Module Name: ADC_Driver
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


module ADC_Driver(
    input [2:0]Addr,
    input DOUT,
    input Conv_Go,
    input CLK,
    input Reset_n,
    output reg SCLK,
    output reg Conv_flag,
    output reg DIN,
    output reg CS_N,
    output reg [11:0]data
    );
    reg [7:0] div_counter;
    reg [5:0] LSM_counter;
    reg [11:0] r_data;
    reg [2:0] r_Addr;
    reg en_Conv;
    parameter CLOCK_FREQ = 50_000_000;
    parameter SCLK_FREQ = 12_500_000;
    parameter DIV_MCNT = CLOCK_FREQ/(SCLK_FREQ*2) - 1;
    always@(posedge CLK or negedge Reset_n)
    begin
        if(!Reset_n)
            r_Addr <= 3'd0;
        else if(Conv_Go)
            r_Addr <= Addr;
    end
    always@(posedge CLK or negedge Reset_n)
    begin
        if(!Reset_n)
           en_Conv <=0;
        else if(Conv_Go)
           en_Conv <= 1 ;
        else if((LSM_counter == 6'd34)&&(div_counter == DIV_MCNT - 1))
           en_Conv <=0;
        else
            en_Conv <= en_Conv;
    end
    
    always@(posedge CLK or negedge Reset_n)
    begin
        if(!Reset_n)
           div_counter <=0;
        else if(en_Conv)
        begin
            if(div_counter == DIV_MCNT)
                div_counter <=0;
            else
                div_counter <= div_counter + 1;
        end
        else
            div_counter <= 0;
    end
    always@(posedge CLK or negedge Reset_n)
    begin
        if(!Reset_n)
           LSM_counter <=0;
        else if(div_counter == DIV_MCNT)
        begin
            if(LSM_counter == 6'd34)
               LSM_counter <=0;
            else
               LSM_counter <= LSM_counter + 1;
        end
        else
            LSM_counter <= LSM_counter;
    end
    always@(posedge CLK or negedge Reset_n)
    begin
       if(!Reset_n)
       begin
            r_data <=0;
            SCLK <= 1;
            DIN <= 1;
            CS_N <= 1;
       end
       else if(div_counter == DIV_MCNT)
       begin
            case(LSM_counter)
                0:begin CS_N <=1; SCLK <= 0; end
                1:begin CS_N <= 0; end
                2:begin SCLK <= 0 ; end
                3:begin SCLK <= 1 ; end
                4:begin SCLK <= 0 ; end
                5:begin SCLK <= 1 ; end
                6:begin SCLK <= 0 ; DIN <= r_Addr[2];end
                7:begin SCLK <= 1 ; end
                8:begin SCLK <= 0 ; DIN <= r_Addr[1];end
                9:begin SCLK <= 1 ; end
                10:begin SCLK <= 0 ; DIN <= r_Addr[0];end
                11:begin SCLK <= 1 ; r_data[11] <= DOUT;end
                12:begin SCLK <= 0 ; end
                13:begin SCLK <= 1 ; r_data[10] <= DOUT;end
                14:begin SCLK <= 0 ; end
                15:begin SCLK <= 1 ; r_data[9] <= DOUT;end
                16:begin SCLK <= 0 ; end
                17:begin SCLK <= 1 ; r_data [8] <= DOUT;end
                18:begin SCLK <= 0 ; end
                19:begin SCLK <= 1 ; r_data[7] <= DOUT;end
                20:begin SCLK <= 0 ; end
                21:begin SCLK <= 1 ; r_data[6] <= DOUT;end
                22:begin SCLK <= 0 ; end
                23:begin SCLK <= 1 ; r_data[5] <= DOUT;end
                24:begin SCLK <= 0 ; end
                25:begin SCLK <= 1 ; r_data[4] <= DOUT;end      
                26:begin SCLK <= 0 ; end
                27:begin SCLK <= 1 ; r_data[3] <= DOUT;end
                28:begin SCLK <= 0 ; end
                29:begin SCLK <= 1 ; r_data[2] <= DOUT;end
                30:begin SCLK <= 0 ; end
                31:begin SCLK <= 1 ; r_data[1] <= DOUT;end
                32:begin SCLK <= 0 ; end
                33:begin SCLK <= 1 ;r_data[0] <= DOUT ; CS_N <= 0; end
                34:begin CS_N <= 1 ; end                             
            endcase
       end
    end
    always@(posedge CLK or negedge Reset_n)
    begin
        if(!Reset_n)
        begin
           data <= 0;
           Conv_flag <= 1'b0;
        end
        else
        begin
           Conv_flag <= 1'b0;
           if((LSM_counter == 6'd34)&&(div_counter == DIV_MCNT - 1))
           begin
              Conv_flag <= 1'b1;
              data <= r_data;
           end
        end
    end
endmodule
