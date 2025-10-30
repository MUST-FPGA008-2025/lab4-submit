`timescale 1ns/1ps
// for testing the FSM effect

module vga_pic_framwork(
  input  wire        vga_clk,   // VGA working clock, 25MHz
  input  wire        sys_rst_n, // Reset signal. Low level is effective
  input  wire [9:0]  pix_x,     // X coordinate of current pixel
  input  wire [9:0]  pix_y,     // Y coordinate of current pixel
  input  wire [1:0]  frame,
  output reg  [15:0] pix_data   // Color information, RGB565
);

  parameter RED     = 16'hF800,
            ORANGE  = 16'hFC00,
            YELLOW  = 16'hFFE0,
            GREEN   = 16'h07E0,
            CYAN    = 16'h07FF,
            BLUE    = 16'h001F,
            PURPLE  = 16'hF81F, // Purple
            BLACK   = 16'h0000,
            WHITE   = 16'hFFFF,
            GRAY    = 16'hD69A;

  ////
  // Main Code
  ////
  always @(posedge vga_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
      pix_data <= 16'd0;
    end else begin
      if (frame == 2'b00) begin
        pix_data <= RED;
      end else if (frame == 2'b01) begin
        pix_data <= GREEN;
      end else begin
        pix_data <= BLUE;
      end
    end
  end

endmodule

