`timescale 1ns/1ps
// for testing the FSM effect

module vga_pic(
  input  wire        vga_clk,   // VGA working clock, 25MHz
  input  wire        sys_rst_n, // Reset signal. Low level is effective
  input  wire [9:0]  pix_x,     // X coordinate of current pixel
  input  wire [9:0]  pix_y,     // Y coordinate of current pixel
  input  wire [1:0]  frame,
  output reg  [15:0] pix_data   // Color information, RGB565
);

  ////
  // Parameter and Internal Signal
  ////
  parameter H_VALID = 10'd640,  // Maximum x value
            V_VALID = 10'd480;  // Maximum y value

  parameter RED     = 16'hF800,
            ORANGE  = 16'hFC00,
            YELLOW  = 16'hFFE0,
            GREEN   = 16'h07E0,
            CYAN    = 16'h07FF,
            BLUE    = 16'h001F,
            PURPPLE = 16'hF81F, // 紫色（拼写保留）
            BLACK   = 16'h0000,
            WHITE   = 16'hFFFF,
            GRAY    = 16'hD69A;

  // =========================
  // END 文本参数（统一 END_ 前缀）
  // =========================
  parameter END_X_START = 10'd200,
            END_Y_START = 10'd180,
            END_W       = 10'd70,
            END_H       = 10'd120,
            END_GAP     = 10'd25,
            END_STROKE  = 10'd8;

  parameter E_START_X = END_X_START,
            N_START_X = END_X_START + END_W + END_GAP,
            D_START_X = END_X_START + 2*(END_W + END_GAP);

  wire in_e_char, in_n_char, in_d_char;
  wire e_pixel, n_pixel, d_pixel;
  wire [9:0] end_lx, end_ly; // END 局部坐标

  // END 区域判定
  assign in_e_char = (pix_x >= E_START_X) && (pix_x < E_START_X + END_W) &&
                     (pix_y >= END_Y_START) && (pix_y < END_Y_START + END_H);

  assign in_n_char = (pix_x >= N_START_X) && (pix_x < N_START_X + END_W) &&
                     (pix_y >= END_Y_START) && (pix_y < END_Y_START + END_H);

  assign in_d_char = (pix_x >= D_START_X) && (pix_x < D_START_X + END_W) &&
                     (pix_y >= END_Y_START) && (pix_y < END_Y_START + END_H);

  assign end_lx = (in_e_char) ? (pix_x - E_START_X) :
                  (in_n_char) ? (pix_x - N_START_X) :
                  (in_d_char) ? (pix_x - D_START_X) : 10'd0;

  assign end_ly = (in_e_char || in_n_char || in_d_char) ? (pix_y - END_Y_START) : 10'd0;

  // 'E'
  assign e_pixel = in_e_char && (
      (end_lx < END_STROKE)                                      || // 左竖
      (end_ly < END_STROKE)                                      || // 上横
      (end_ly > (END_H/2 - END_STROKE/2) && end_ly < (END_H/2 + END_STROKE/2)) || // 中横
      (end_ly > END_H - END_STROKE)                                 // 下横
  );

  // 'N'：用通用比例 y ≈ END_H * x / END_W
  wire [17:0] n_diag_mul  = end_lx * END_H;    // up to ~ (1023*1023) < 2^20，18位足够
  wire [9:0]  n_diag_center = n_diag_mul / END_W;

  assign n_pixel = in_n_char && (
      (end_lx < END_STROKE) ||
      (end_lx > END_W - END_STROKE) ||
      ( (end_ly + (END_STROKE>>1) >= n_diag_center) &&
        (end_ly <= n_diag_center + (END_STROKE>>1)) )
  );

  // 'D'：平方和
  parameter END_R_OUT  = END_H / 2;
  parameter END_R_IN   = END_R_OUT - END_STROKE;
  parameter END_R2_OUT = END_R_OUT * END_R_OUT;
  parameter END_R2_IN  = END_R_IN  * END_R_IN;

  wire signed [9:0]  d_center_x, d_center_y;
  wire signed [10:0] dx, dy;
  wire [21:0]        dist_sq;

  assign d_center_x = END_STROKE;
  assign d_center_y = END_H / 2;

  assign dx = $signed(end_lx) - d_center_x;
  assign dy = $signed(end_ly) - d_center_y;
  assign dist_sq = dx*dx + dy*dy;

  assign d_pixel = in_d_char && (
      (end_lx < END_STROKE) ||
      ( (dist_sq <= END_R2_OUT) && (dist_sq >= END_R2_IN) && (end_lx >= END_STROKE) )
  );

  // =========================
  // MUST 文本参数（统一 MUST_ 前缀）
  // =========================
  parameter MUST_X_START   = 10'd160,
            MUST_Y_START   = 10'd200,
            MUST_W         = 10'd60,
            MUST_H         = 10'd80,
            MUST_GAP       = 10'd25,
            MUST_LINE      = 10'd6;

  parameter MUST_R2_SMALL  = 16'd289, // 17^2
            MUST_R2_LARGE  = 16'd529, // 23^2
            MUST_CENTER_X  = 10'd30,
            MUST_TOP_CY    = 10'd20,
            MUST_BOT_CY    = 10'd60;

  parameter M_START_X = MUST_X_START,
            U_START_X = MUST_X_START + MUST_W + MUST_GAP,
            S_START_X = MUST_X_START + 2*(MUST_W + MUST_GAP),
            T_START_X = MUST_X_START + 3*(MUST_W + MUST_GAP);

  wire in_m_char, in_u_char, in_s_char, in_t_char;
  wire m_pixel, u_pixel, s_pixel, t_pixel;
  wire [9:0] must_lx, must_ly;

  // 圆相关（U 用）
  wire [9:0] must_radius  = (MUST_W - 2*MUST_LINE) / 2;
  wire [9:0] must_center_x = MUST_W / 2;
  wire [9:0] must_bottom_y = MUST_H - 10'd30;

  // MUST 区域判定
  assign in_m_char = (pix_x >= M_START_X) && (pix_x < M_START_X + MUST_W) &&
                     (pix_y >= MUST_Y_START) && (pix_y < MUST_Y_START + MUST_H);

  assign in_u_char = (pix_x >= U_START_X) && (pix_x < U_START_X + MUST_W) &&
                     (pix_y >= MUST_Y_START) && (pix_y < MUST_Y_START + MUST_H);

  assign in_s_char = (pix_x >= S_START_X) && (pix_x < S_START_X + MUST_W) &&
                     (pix_y >= MUST_Y_START) && (pix_y < MUST_Y_START + MUST_H);

  assign in_t_char = (pix_x >= T_START_X) && (pix_x < T_START_X + MUST_W) &&
                     (pix_y >= MUST_Y_START) && (pix_y < MUST_Y_START + MUST_H);

  assign must_lx = (in_m_char) ? (pix_x - M_START_X) :
                   (in_u_char) ? (pix_x - U_START_X) :
                   (in_s_char) ? (pix_x - S_START_X) :
                   (in_t_char) ? (pix_x - T_START_X) : 10'd0;

  assign must_ly = (in_m_char || in_u_char || in_s_char || in_t_char) ?
                   (pix_y - MUST_Y_START) : 10'd0;

  // M
  assign m_pixel = in_m_char && (
      // 左竖
      ((must_lx <= MUST_LINE) && (must_ly <= MUST_H)) ||
      // 右竖
      ((must_lx >= MUST_W - MUST_LINE) && (must_ly <= MUST_H)) ||
      // 左斜
      ((must_lx >= (27*must_ly)/80) &&
       (must_lx <= (27*must_ly)/80 + MUST_LINE) &&
       (must_ly <= MUST_H)) ||
      // 右斜
      ((must_lx >= MUST_W - (27*must_ly)/80 - MUST_LINE) &&
       (must_lx <= MUST_W - (27*must_ly)/80) &&
       (must_ly <= MUST_H))
  );

  // U
  wire [19:0] u_dx2_top, u_dy2_top; // 适当留足位宽
  wire [19:0] u_sum_top;
  assign u_dx2_top = (must_lx - must_center_x)*(must_lx - must_center_x);
  assign u_dy2_top = (must_ly - must_bottom_y)*(must_ly - must_bottom_y);
  assign u_sum_top = u_dx2_top + u_dy2_top;

  assign u_pixel = in_u_char && (
      // 左竖
      ((must_lx < MUST_LINE) && (must_ly <= must_bottom_y)) ||
      // 右竖
      ((must_lx >= MUST_W - MUST_LINE) && (must_ly <= must_bottom_y)) ||
      // 底部弧
      ( (must_ly >= must_bottom_y) &&
        (u_sum_top <= 20'd900) &&            // 30^2
        (u_sum_top >= must_radius*must_radius) )
  );

  // S
  wire [19:0] s_dx2_t = (must_lx - MUST_CENTER_X)*(must_lx - MUST_CENTER_X);
  wire [19:0] s_dy2_t = (must_ly - MUST_TOP_CY)*(must_ly - MUST_TOP_CY);
  wire [19:0] s_sum_t = s_dx2_t + s_dy2_t;

  wire [19:0] s_dx2_b = (must_lx - MUST_CENTER_X)*(must_lx - MUST_CENTER_X);
  wire [19:0] s_dy2_b = (must_ly - MUST_BOT_CY)*(must_ly - MUST_BOT_CY);
  wire [19:0] s_sum_b = s_dx2_b + s_dy2_b;

  assign s_pixel = in_s_char && (
      // 上半圆环 & 中段
      ( (must_ly <= 10'd20) &&
        (s_sum_t <= MUST_R2_LARGE) && (s_sum_t >= MUST_R2_SMALL) ) ||
      // 上水平连接（右侧）
      ( (must_ly >= 10'd15) && (must_ly <= 10'd25) && (must_lx >= 10'd8) && (must_lx <= 10'd15) ) ||
      // 中上过渡
      ( (must_ly >= 10'd20) && (must_ly <= 10'd40) && (must_lx <= 10'd30) &&
        (s_sum_t <= MUST_R2_LARGE) && (s_sum_t >= MUST_R2_SMALL) ) ||
      // 下半圆环
      ( (must_ly >= 10'd60) &&
        (s_sum_b <= MUST_R2_LARGE) && (s_sum_b >= MUST_R2_SMALL) ) ||
      // 下水平连接（左侧）
      ( (must_ly >= 10'd55) && (must_ly <= 10'd65) && (must_lx >= 10'd47) && (must_lx <= 10'd53) ) ||
      // 中下过渡
      ( (must_ly >= 10'd40) && (must_ly <= 10'd60) && (must_lx >= 10'd30) &&
        (s_sum_b <= MUST_R2_LARGE) && (s_sum_b >= MUST_R2_SMALL) )
  );

  // T
  assign t_pixel = in_t_char && (
      // 上横
      (must_ly < MUST_LINE) ||
      // 中竖
      ((must_lx >= MUST_W/2 - MUST_LINE/2) && (must_lx < MUST_W/2 + MUST_LINE/2))
  );

  ////
  // Main Code
  ////
  always @(posedge vga_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
      pix_data <= 16'd0;
    end else begin
      if (frame == 2'b00) begin
        if      (pix_x < (H_VALID/10)*1) pix_data <= RED;
        else if (pix_x < (H_VALID/10)*2) pix_data <= ORANGE;
        else if (pix_x < (H_VALID/10)*3) pix_data <= YELLOW;
        else if (pix_x < (H_VALID/10)*4) pix_data <= GREEN;
        else if (pix_x < (H_VALID/10)*5) pix_data <= CYAN;
        else if (pix_x < (H_VALID/10)*6) pix_data <= BLUE;
        else if (pix_x < (H_VALID/10)*7) pix_data <= PURPPLE;
        else if (pix_x < (H_VALID/10)*8) pix_data <= BLACK;
        else if (pix_x < (H_VALID/10)*9) pix_data <= WHITE;
        else if (pix_x < H_VALID)        pix_data <= GRAY;
        else                             pix_data <= BLACK;
      end else if (frame == 2'b01) begin
        // MUST
        pix_data <= (in_m_char || in_u_char || in_s_char || in_t_char) ?
                    ((m_pixel || u_pixel || s_pixel || t_pixel) ? WHITE : BLACK) : BLACK;
      end else begin
        // END
        pix_data <= (in_e_char || in_n_char || in_d_char) ?
                    ((e_pixel || n_pixel || d_pixel) ? WHITE : BLACK) : BLACK;
      end
    end
  end

endmodule