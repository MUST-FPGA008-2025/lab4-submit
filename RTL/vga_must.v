`timescale 1ns/1ns

module vga_must(
    input wire vga_clk,          // VGA工作时钟，25MHz
    input wire sys_rst_n,        // 复位信号，低电平有效
    input wire [9:0] pix_x,      // 当前像素X坐标
    input wire [9:0] pix_y,      // 当前像素Y坐标
    output reg [15:0] pix_data   // 颜色信息
);

    ////
    //\* Parameter and Internal Signal \//
    ////
    
    parameter H_VALID = 10'd640,     // 最大X值
              V_VALID = 10'd480;     // 最大Y值

    parameter WHITE = 16'hFFFF,      // 白色
              BLACK = 16'h0000;      // 黑色

    // MUST文字显示区域参数
    parameter MUST_START_X = 10'd160,    // MUST起始X坐标
              MUST_START_Y = 10'd200,    // MUST起始Y坐标
              CHAR_WIDTH   = 10'd60,     // 单个字符宽度
              CHAR_HEIGHT  = 10'd80,     // 单个字符高度
              CHAR_SPACING = 10'd25;     // 字符间距
    
    parameter R2_SMALL = 289,     // 17^2 = 289
              R2_LARGE = 529,     // 23^2 = 529
              CENTER_X = 30,
              TOP_CENTER_Y = 20,
              BOTTOM_CENTER_Y = 60;

    // 字符起始X坐标
    parameter M_START_X = MUST_START_X,
              U_START_X = MUST_START_X + CHAR_WIDTH + CHAR_SPACING,
              S_START_X = MUST_START_X + 2*(CHAR_WIDTH + CHAR_SPACING),
              T_START_X = MUST_START_X + 3*(CHAR_WIDTH + CHAR_SPACING);

    parameter LINE_WIDTH = 3'd6;         // 线宽（稍微加粗）

    wire in_m_char, in_u_char, in_s_char, in_t_char;
    wire m_pixel, u_pixel, s_pixel, t_pixel;
    wire [9:0] local_x, local_y;
    
    // 计算圆相关参数
    wire [9:0] radius = (CHAR_WIDTH - 2*LINE_WIDTH) / 2; // 圆半径
    wire [9:0] center_x = CHAR_WIDTH / 2;          // 圆心X坐标
    wire [9:0] bottom_y = CHAR_HEIGHT - 30; // 圆心Y坐标

    ////
    //\* Character Area Detection \//
    ////
    
    assign in_m_char = (pix_x >= M_START_X) && (pix_x < M_START_X + CHAR_WIDTH) &&
                       (pix_y >= MUST_START_Y) && (pix_y < MUST_START_Y + CHAR_HEIGHT);
    
    assign in_u_char = (pix_x >= U_START_X) && (pix_x < U_START_X + CHAR_WIDTH) &&
                       (pix_y >= MUST_START_Y) && (pix_y < MUST_START_Y + CHAR_HEIGHT);
    
    assign in_s_char = (pix_x >= S_START_X) && (pix_x < S_START_X + CHAR_WIDTH) &&
                       (pix_y >= MUST_START_Y) && (pix_y < MUST_START_Y + CHAR_HEIGHT);
    
    assign in_t_char = (pix_x >= T_START_X) && (pix_x < T_START_X + CHAR_WIDTH) &&
                       (pix_y >= MUST_START_Y) && (pix_y < MUST_START_Y + CHAR_HEIGHT);

    assign local_x = (in_m_char) ? (pix_x - M_START_X) :
                     (in_u_char) ? (pix_x - U_START_X) :
                     (in_s_char) ? (pix_x - S_START_X) :
                     (in_t_char) ? (pix_x - T_START_X) : 10'd0;
                     
    assign local_y = (in_m_char || in_u_char || in_s_char || in_t_char) ? 
                     (pix_y - MUST_START_Y) : 10'd0;

    ////
    //\* Simple Character Design \//
    ////
    
    // M字符 - 标准大写M
    assign m_pixel = in_m_char && (
                     // 左垂线
                     ((local_x >= 0) &&
                      (local_x <= LINE_WIDTH) &&
                      (local_y <= CHAR_HEIGHT))
                     ||
                     // 右垂线
                     ((local_x >= CHAR_WIDTH - LINE_WIDTH) &&
                      (local_x <= CHAR_WIDTH) &&
                      (local_y <= CHAR_HEIGHT))
                     ||
                     // 左斜线
                     ((local_x >= (27*local_y)/80) && 
                      (local_x <= (27*local_y)/80 + LINE_WIDTH) && 
                      (local_y <= CHAR_HEIGHT)) 
                     ||
                     // 右斜线
                     ((local_x >= CHAR_WIDTH - (27*local_y)/80 - LINE_WIDTH) && 
                      (local_x <= CHAR_WIDTH - (27*local_y)/80) && 
                      (local_y <= CHAR_HEIGHT))
                     );
    
    // U字符 - 标准大写U
    assign u_pixel = in_u_char && (
                     // 左垂线
                     ((local_x < LINE_WIDTH) && (local_y < CHAR_HEIGHT) && local_y <= bottom_y) ||
                     // 右垂线
                     ((local_x >= CHAR_WIDTH - LINE_WIDTH) && (local_x <= CHAR_WIDTH) && (local_y <= bottom_y)) ||
                     // 底部弧线
                     (local_y >= bottom_y && 
     ((local_x - center_x)*(local_x - center_x) + (local_y - bottom_y)*(local_y - bottom_y) <= 900) &&
     ((local_x - center_x)*(local_x - center_x) + (local_y - bottom_y)*(local_y - bottom_y) >= (radius)*(radius)))
);
    
    // S字符 - 标准大写S
    assign s_pixel = in_s_char && (
                     // 反向S的上半部分 (y <= 40) - 使用下圆
                     (((local_y <= 20) && 
                       ((local_x - CENTER_X)*(local_x - CENTER_X) + (local_y - TOP_CENTER_Y)*(local_y - TOP_CENTER_Y) <= R2_LARGE) &&
                       ((local_x - CENTER_X)*(local_x - CENTER_X) + (local_y - TOP_CENTER_Y)*(local_y -TOP_CENTER_Y) >= R2_SMALL))
                     ||
                     // 上水平连接部分 (右侧)
                     ((local_y >= 15) && (local_y <= 25) && (local_x >= 8) && (local_x <= 15))
                     ||
                     // 中间部分
                     ((local_y >= 20) && (local_y <= 40) && (local_x <= 30) &&
                      ((local_x - CENTER_X)*(local_x - CENTER_X) + (local_y - TOP_CENTER_Y)*(local_y - TOP_CENTER_Y) <= R2_LARGE) &&
                      ((local_x - CENTER_X)*(local_x - CENTER_X) + (local_y - TOP_CENTER_Y)*(local_y - TOP_CENTER_Y) >= R2_SMALL))
                     ||
                     // 反向S的下半部分 (y > 40) - 使用上圆
                     ((local_y >= 60) &&
                      ((local_x - CENTER_X)*(local_x - CENTER_X) + (local_y - BOTTOM_CENTER_Y)*(local_y - BOTTOM_CENTER_Y) <= R2_LARGE) &&
                      ((local_x - CENTER_X)*(local_x - CENTER_X) + (local_y - BOTTOM_CENTER_Y)*(local_y - BOTTOM_CENTER_Y) >= R2_SMALL))
                     ||
                     // 下水平连接部分 (左侧)
                     ((local_y >= 55) && (local_y <= 65) && (local_x >= 47) && (local_x <= 53))
                     ||
                     // 中间下半部分
                     ((local_y >= 40) && (local_y <= 60) && (local_x >= 30) &&
                      ((local_x - CENTER_X)*(local_x - CENTER_X) + (local_y - BOTTOM_CENTER_Y)*(local_y - BOTTOM_CENTER_Y) <= R2_LARGE) &&
                      ((local_x - CENTER_X)*(local_x - CENTER_X) + (local_y - BOTTOM_CENTER_Y)*(local_y - BOTTOM_CENTER_Y) >= R2_SMALL))
                     ));
    
    // T字符 - 标准大写T
    assign t_pixel = in_t_char && (
                     // 上横线
                     ((local_y < LINE_WIDTH) && (local_x >= 0) && (local_x <= CHAR_WIDTH)) ||
                     // 中间竖线
                     ((local_x >= CHAR_WIDTH/2 - LINE_WIDTH/2) && (local_x < CHAR_WIDTH/2 + LINE_WIDTH/2) && (local_y >= 0) && (local_y <= CHAR_HEIGHT))
                     );

    ////
    //\* Main Code \//
    ////
    
    always@(posedge vga_clk or negedge sys_rst_n) begin
        if(sys_rst_n == 1'b0)
            pix_data <= BLACK;
        else begin
            if(m_pixel || u_pixel || s_pixel || t_pixel)
                pix_data <= WHITE;
            else
                pix_data <= BLACK;
        end
    end

endmodule