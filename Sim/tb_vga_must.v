`timescale 1ns/1ns

module tb_vga_must();

    // 输入信号
    reg vga_clk;
    reg sys_rst_n;
    
    // 输出信号
    wire [15:0] pix_data;
    
    // VGA时序参数
    parameter H_SYNC = 10'd96,    // 行同步脉冲
              H_BACK = 10'd48,    // 行后沿
              H_VALID = 10'd640,  // 行有效像素
              H_FRONT = 10'd16,   // 行前沿
              H_TOTAL = 10'd800;  // 行总像素
              
    parameter V_SYNC = 10'd2,     // 场同步脉冲  
              V_BACK = 10'd33,    // 场后沿
              V_VALID = 10'd480,  // 场有效像素
              V_FRONT = 10'd10,   // 场前沿
              V_TOTAL = 10'd525;  // 场总行数
    
    // 像素坐标计数器
    reg [9:0] h_cnt;  // 行计数器 (0-799)
    reg [9:0] v_cnt;  // 场计数器 (0-524)
    
    // 有效显示区域标志
    wire valid_area;
    
    // 提供给模块的像素坐标（只在有效区域内）
    wire [9:0] pix_x = (h_cnt >= H_SYNC + H_BACK) && (h_cnt < H_SYNC + H_BACK + H_VALID) ? 
                       (h_cnt - H_SYNC - H_BACK) : 10'd0;
                       
    wire [9:0] pix_y = (v_cnt >= V_SYNC + V_BACK) && (v_cnt < V_SYNC + V_BACK + V_VALID) ? 
                       (v_cnt - V_SYNC - V_BACK) : 10'd0;
    
    assign valid_area = (h_cnt >= H_SYNC + H_BACK) && (h_cnt < H_SYNC + H_BACK + H_VALID) &&
                       (v_cnt >= V_SYNC + V_BACK) && (v_cnt < V_SYNC + V_BACK + V_VALID);

    // 实例化被测试模块
    vga_must u_vga_must(
        .vga_clk(vga_clk),
        .sys_rst_n(sys_rst_n),
        .pix_x(pix_x),
        .pix_y(pix_y),
        .pix_data(pix_data)
    );
    
    // 时钟生成
    always #20 vga_clk = ~vga_clk; // 25MHz时钟，周期40ns
    
    // 行计数器 - 修复：使用 >= 比较确保不会错过
    always @(posedge vga_clk or negedge sys_rst_n) begin
        if (!sys_rst_n)
            h_cnt <= 10'd0;
        else if (h_cnt >= H_TOTAL - 1)  // 改为 >= 确保触发
            h_cnt <= 10'd0;
        else
            h_cnt <= h_cnt + 10'd1;
    end
    
    // 场计数器 - 修复：使用行结束标志
    always @(posedge vga_clk or negedge sys_rst_n) begin
        if (!sys_rst_n)
            v_cnt <= 10'd0;
        else if (h_cnt >= H_TOTAL - 1) begin  // 使用相同的条件
            if (v_cnt >= V_TOTAL - 1)         // 同样使用 >=
                v_cnt <= 10'd0;
            else
                v_cnt <= v_cnt + 10'd1;
        end
    end
    
    // 测试激励 - 添加调试信息
    initial begin
        // 初始化信号
        vga_clk = 0;
        sys_rst_n = 0;
        
        // 生成VCD文件用于波形分析
        $dumpfile("vga_must.vcd");
        $dumpvars(0, tb_vga_must);
        
        // 复位
        #100;
        sys_rst_n = 1;
        $display("复位完成，开始VGA显示测试...");
        $display("H_TOTAL = %0d, V_TOTAL = %0d", H_TOTAL, V_TOTAL);
        
        // 等待几帧时间，观察输出
        #33000000; // 约3帧 @ 25MHz (800*525*40ns ≈ 16.8ms per frame)
        
        // 完成测试
        $display("测试完成!");
        #100;
        $finish;
    end
    
    // 监视器：在字符区域显示信息
    integer frame_count = 0;
    
    // 调试：监控计数器行为
    reg [9:0] last_h_cnt = 0;
    reg [9:0] last_v_cnt = 0;
    
    always @(posedge vga_clk) begin
        // 检测帧开始（场计数器归零）
        if (v_cnt == 0 && h_cnt == 0) begin
            frame_count <= frame_count + 1;
            $display("第 %0d 帧开始", frame_count);
        end
        
        // 监控计数器变化
        if (h_cnt !== last_h_cnt || v_cnt !== last_v_cnt) begin
            if (h_cnt == H_TOTAL - 1) 
                $display("时间=%t: h_cnt=%0d (行结束), v_cnt=%0d", $time, h_cnt, v_cnt);
            last_h_cnt <= h_cnt;
            last_v_cnt <= v_cnt;
        end
        
        // 在MUST字符区域内显示像素信息
        if (valid_area && pix_x >= 160 && pix_x < 475 && pix_y >= 200 && pix_y < 280) begin
            if (pix_data == 16'hFFFF) begin
                $display("帧%0d 坐标(%0d, %0d): 白色像素", frame_count, pix_x, pix_y);
            end
        end
    end
    
    // 超时保护
    initial begin
        #50000000; // 50ms超时
        $display("测试超时!");
        $display("最终状态: h_cnt=%0d, v_cnt=%0d, frame_count=%0d", h_cnt, v_cnt, frame_count);
        $finish;
    end

endmodule