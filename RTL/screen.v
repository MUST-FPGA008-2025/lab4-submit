`timescale 1ns/1ps

module screen (
    input wire clk,
    input wire rstn,
    input wire button,

    output wire hsync,
    output wire vsync,
    output wire [15:0] rgb
);
    wire [1:0] connector; // for frame

// instance screen_ctl
screen_ctl instance1 (
.clk (clk),
.rstn (rstn),
.button (button),

.frame (connector)
);
// instance vga_colorbar
vga_colorbar instance2(
    .sys_clk (clk),
    .sys_rst_n (rstn),
    .frame (connector),

    .hsync (hsync),
    .vsync (vsync),
    .rgb (rgb)
);

endmodule