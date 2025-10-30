`timescale 1ns/1ps

module vga_pic_end(
    input wire vga_clk,          // VGA工作时钟，25MHz
    input wire sys_rst_n,        // 复位信号，低电平有效
    input wire [9:0] pix_x,      // 当前像素X坐标
    input wire [9:0] pix_y,      // 当前像素Y坐标
    output reg [15:0] pix_data   // 颜色信息
);

    ////
    //\* Parameter and Internal Signal \//
    ////
    
    // -- 屏幕与颜色定义 --
    parameter H_VALID = 10'd640;     // 水平有效显示区域
    parameter V_VALID = 10'd480;     // 垂直有效显示区域
    parameter WHITE = 16'hFFFF;      // 白色
    parameter BLACK = 16'h0000;      // 黑色

    // -- "END" 文字布局与几何参数 --
    parameter X_START   = 10'd200,    // "END" 起始X坐标
              Y_START   = 10'd180,    // "END" 起始Y坐标
              LETTER_W  = 10'd70,     // 单个字符宽度
              LETTER_H  = 10'd120,    // 单个字符高度
              GAP       = 10'd25,     // 字符间距
              STROKE    = 10'd8;      // 笔画宽度

    // -- 各字符起始X坐标 --
    parameter E_START_X = X_START,
              N_START_X = X_START + LETTER_W + GAP,
              D_START_X = X_START + 2*(LETTER_W + GAP);

    // -- 内部信号声明 --
    wire in_e_char, in_n_char, in_d_char;     // 字符区域标志
    wire e_pixel, n_pixel, d_pixel;           // 字符像素点亮标志
    wire [9:0] local_x, local_y;              // 字符内的局部坐标

    ////
    //\* Character Area Detection \//
    ////
    
    assign in_e_char = (pix_x >= E_START_X) && (pix_x < E_START_X + LETTER_W) &&
                       (pix_y >= Y_START) && (pix_y < Y_START + LETTER_H);
    
    assign in_n_char = (pix_x >= N_START_X) && (pix_x < N_START_X + LETTER_W) &&
                       (pix_y >= Y_START) && (pix_y < Y_START + LETTER_H);
    
    assign in_d_char = (pix_x >= D_START_X) && (pix_x < D_START_X + LETTER_W) &&
                       (pix_y >= Y_START) && (pix_y < Y_START + LETTER_H);

    assign local_x = (in_e_char) ? (pix_x - E_START_X) :
                     (in_n_char) ? (pix_x - N_START_X) :
                     (in_d_char) ? (pix_x - D_START_X) : 10'd0;
                     
    assign local_y = (in_e_char || in_n_char || in_d_char) ? (pix_y - Y_START) : 10'd0;

    ////
    //\* Character Design (Geometric Method) \//
    ////
    
    // 字符 'E' 的绘制逻辑
    assign e_pixel = in_e_char && (
        (local_x < STROKE)                                     || // 左竖线
        (local_y < STROKE)                                     || // 上横线
        (local_y > (LETTER_H/2 - STROKE/2) && 
         local_y < (LETTER_H/2 + STROKE/2))                    || // 中横线
        (local_y > LETTER_H - STROKE)                             // 下横线
    );

    // 字符 'N' 的绘制逻辑
    wire [9:0] n_diag_center;
    assign n_diag_center = (local_x << 1) + (local_x >> 1); // 近似 2.5 * local_x
    
    assign n_pixel = in_n_char && (
        (local_x < STROKE)                                     || // 左竖线
        (local_x > LETTER_W - STROKE)                          || // 右竖线
        (local_y >= n_diag_center - (STROKE/2) && 
         local_y <= n_diag_center + (STROKE/2))                   // 斜线
    );

    // 字符 'D' 的绘制逻辑 (使用平方和法)
    parameter R_OUT = LETTER_H / 2;             // 外圆弧半径 (60)
    parameter R_IN  = R_OUT - STROKE;           // 内圆弧半径 (52)
    parameter R2_OUT = R_OUT * R_OUT;           // 半径的平方 (3600)
    parameter R2_IN  = R_IN  * R_IN;            // 半径的平方 (2704)
    
    wire signed [9:0] d_center_x, d_center_y;
    wire signed [10:0] dx, dy;
    wire [21:0] dist_sq;

    // 圆心坐标 (为了与左侧竖线对齐，圆心X坐标设在竖线右侧)
    assign d_center_x = STROKE;
    assign d_center_y = LETTER_H / 2;

    // 计算像素点到圆心的距离分量
    assign dx = $signed(local_x) - d_center_x;
    assign dy = $signed(local_y) - d_center_y;

    // 计算距离的平方: dx*dx + dy*dy
    assign dist_sq = dx * dx + dy * dy;
    
    assign d_pixel = in_d_char && (
        // 左竖线
        (local_x < STROKE) || 
        // 右侧圆弧 (使用精确的平方和判断)
        ( (dist_sq <= R2_OUT) && (dist_sq >= R2_IN) && (local_x >= STROKE) )
    );

    ////
    //\* Main Code: Drive Pixel Output \//
    ////
    
    always@(posedge vga_clk or negedge sys_rst_n) begin
        if(sys_rst_n == 1'b0)
            pix_data <= BLACK;
        else begin
            if(e_pixel || n_pixel || d_pixel)
                pix_data <= WHITE;
            else
                pix_data <= BLACK;
        end
    end

endmodule