`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/09/09 15:13:23
// Design Name: 
// Module Name: Key_shake
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


module Key_shake(
    input key,
    input CLK,
    input Reset_n,
    output reg flag_press_key,
    output reg flag_release_key,
    output reg key_state
    );
    parameter MCNT = 1_000_000 - 1;
    wire nedge_key;
    wire pedge_key;
    wire time_20ms_reached;
    reg [29:0]counter;
    assign time_20ms_reached = (counter >= MCNT);
    reg sync_key_d0;
    reg sync_key_d1;
    reg r_key;
    reg [1:0] state;
    localparam IDLE = 0;
    localparam P_FILTER = 1;
    localparam WAIT_R = 2;
    localparam R_FILTER = 3;
    always@(posedge CLK)
    begin
        sync_key_d0 <= key;
    end
    always@(posedge CLK)
    begin
        sync_key_d1 <= sync_key_d0;
    end
    always@(posedge CLK)
    begin
        r_key <= sync_key_d1;
    end 
    assign nedge_key = (sync_key_d1 == 0)&&(r_key == 1);
    assign pedge_key = (sync_key_d1 == 1)&&(r_key == 0);
   always@(posedge CLK or negedge Reset_n)
   begin
   if(!Reset_n)
   begin
        state <=IDLE;
        flag_release_key <=0;
        flag_press_key <= 0;
        counter <=0;
        key_state <= 1'd1;
   end
   else begin
        case(state)
            IDLE:
            begin
            flag_release_key <= 0;
            if(nedge_key)
                state <= P_FILTER;
            end
            P_FILTER:
            if(time_20ms_reached)
            begin
                state <= WAIT_R;
                flag_press_key <= 1;
                key_state <= 1'd0;
                counter <=0;
            end
            else if(nedge_key)
            begin
                state <= IDLE;
                counter <=0;
            end
            else begin
                state <= state;
                counter <= counter+1'd1;
                end
            WAIT_R:
            begin
            flag_press_key <= 0;
            if(pedge_key)
                state <= R_FILTER;           
            end
            R_FILTER:
            if(time_20ms_reached)
            begin
                state <= IDLE;
                flag_release_key <= 1;
                key_state <= 1'd1;
                counter <=0;
            end
            else if(nedge_key)
            begin
                state <= WAIT_R;
                counter <=0;
            end
            else 
            begin
                state <= state;
                counter <= counter+1'd1;          
            end 
         endcase
         end
   end
//   always@(posedge CLK or negedge Reset_n)
//   begin
//   if(!Reset_n)
//       counter <=0;
//   else if((state == P_FILTER)||(state == R_FILTER))
//       counter <= counter +1'd1;
//   else
//       counter <= 0;
//   end

endmodule
