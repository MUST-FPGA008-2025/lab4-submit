`timescale 1ns/1ps

module tb_vga_pic_end();

    ////
    //* Signal Declaration *//
    ////
    
    reg vga_clk;
    reg sys_rst_n;
    reg [9:0] pix_x;
    reg [9:0] pix_y;
    wire [15:0] pix_data;
    
    parameter H_VALID = 10'd640;
    parameter V_VALID = 10'd480;
    
    ////
    //* DUT Instantiation *//
    ////
    
    vga_pic_end u_vga_end (
        .vga_clk    (vga_clk),
        .sys_rst_n  (sys_rst_n),
        .pix_x      (pix_x),
        .pix_y      (pix_y),
        .pix_data   (pix_data)
    );
    
    ////
    //* Clock Generation *//
    ////
    
    initial begin
        vga_clk = 1'b0;
        forever #20 vga_clk = ~vga_clk;  // 25MHz
    end
    
    ////
    //* Main Test Process *//
    ////
    
    integer i, j;
    integer white_count;
    integer file_handle;
    
    initial begin
        // 初始化
        sys_rst_n = 1'b0;
        pix_x = 10'd0;
        pix_y = 10'd0;
        white_count = 0;
        
        // 打开文件用于记录
        file_handle = $fopen("pixel_output.txt", "w");
        
        $display("========================================");
        $display("VGA END Display Testbench Started");
        $display("========================================");
        
        // 复位
        #100;
        @(posedge vga_clk);
        sys_rst_n = 1'b1;
        $display("Reset released at %0t ns", $time);
        
        // 等待几个时钟让系统稳定
        repeat(10) @(posedge vga_clk);
        
        $display("Starting pixel scan...");
        
        // 扫描所有像素
        for (j = 0; j < V_VALID; j = j + 1) begin
            for (i = 0; i < H_VALID; i = i + 1) begin
                // 设置坐标
                pix_x = i;
                pix_y = j;
                
                // 等待一个时钟周期
                @(posedge vga_clk);
                
                // 再等待一个时钟周期让pix_data稳定
                // （因为pix_data是在always@(posedge vga_clk)中赋值的）
                @(posedge vga_clk);
                #1; // 等待信号传播
                
                // 检查输出
                if (pix_data == 16'hFFFF) begin
                    white_count = white_count + 1;
                    
                    // 记录白色像素（只记录前100个避免文件过大）
                    if (white_count <= 100) begin
                        $fwrite(file_handle, "WHITE at X=%03d Y=%03d\n", i, j);
                        $display("WHITE pixel found at X=%03d Y=%03d", i, j);
                    end
                end
                
                // 在关键位置进行测试
                if ((i == 200) && (j == 180)) begin
                    $display("----------------------------------------");
                    $display("Test Point: Letter E start (200, 180)");
                    $display("pix_data = 0x%04X", pix_data);
                    if (pix_data == 16'hFFFF)
                        $display("✓ PASS: Letter E detected");
                    else
                        $display("✗ FAIL: Letter E not found");
                    $display("----------------------------------------");
                end
                
                if ((i == 295) && (j == 180)) begin
                    $display("----------------------------------------");
                    $display("Test Point: Letter N start (295, 180)");
                    $display("pix_data = 0x%04X", pix_data);
                    if (pix_data == 16'hFFFF)
                        $display("✓ PASS: Letter N detected");
                    else
                        $display("✗ FAIL: Letter N not found");
                    $display("----------------------------------------");
                end
                
                if ((i == 390) && (j == 180)) begin
                    $display("----------------------------------------");
                    $display("Test Point: Letter D start (390, 180)");
                    $display("pix_data = 0x%04X", pix_data);
                    if (pix_data == 16'hFFFF)
                        $display("✓ PASS: Letter D detected");
                    else
                        $display("✗ FAIL: Letter D not found");
                    $display("----------------------------------------");
                end
            end
            
            // 每50行报告一次进度
            if ((j % 50) == 0) begin
                $display("Progress: Line %0d/%0d completed, white pixels so far: %0d", 
                         j, V_VALID, white_count);
            end
        end
        
        // 扫描完成
        $display("\n========================================");
        $display("Scan Completed!");
        $display("========================================");
        $display("Total white pixels found: %0d", white_count);
        $display("Total pixels scanned: %0d", H_VALID * V_VALID);
        $display("Simulation time: %0t ns", $time);
        $display("========================================\n");
        
        $fclose(file_handle);
        
        // 多等待一些时间再结束
        #1000;
        $stop;  // 使用$stop而不是$finish，这样可以在Questa中查看
    end
    
    ////
    //* Monitor for Debugging *//
    ////
    
    initial begin
        $monitor("Time=%0t pix_x=%0d pix_y=%0d pix_data=0x%04X", 
                 $time, pix_x, pix_y, pix_data);
    end

endmodule