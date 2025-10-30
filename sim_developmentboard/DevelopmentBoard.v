`timescale 1ns / 1ns

module DevelopmentBoard(
    input wire clk, //50MHz
    input wire reset, B2, B3, B4, B5,
	 // reset is "a", connect to your rst_n
	 // B2 is "s", if the design need
	 // B3 is "d"
	 // B4 is "f"
	 // B5 is "g"
    output wire h_sync, v_sync, // three signals for VGA
    output wire [15:0] rgb,
	
	output wire led1,// if the design need
	output wire led2,
	output wire led3,
	output wire led4,
	output wire led5
);

// like pin planner: inst the top module
screen screen_instance
 (
 .clk (clk ), // pin of board
 .rstn (reset ), 
 .button (B2),
 
 .hsync (h_sync ), 
 .vsync (v_sync ), 
 .rgb (rgb ) 
 );
    


endmodule
