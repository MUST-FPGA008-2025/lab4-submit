`timescale 1ns/1ps

module tb_screen_ctl;

  // DUT ports
  reg        clk;
  reg        rstn;   // active-low
  reg        btn;    // idle=1, press=0
  wire [1:0] frame;

  // 20 ns period clock
  initial clk = 1'b0;
  always #10 clk = ~clk;

  // --- helper: one press that stays low for N full cycles
  task automatic press(input integer low_cycles);
    begin
      @(negedge clk); btn <= 1'b0;               // press on negedge (远离采样沿)
      repeat (low_cycles) @(posedge clk);        // hold low across posedges
      @(negedge clk); btn <= 1'b1;               // release on negedge
    end
  endtask

  // stimulus
  initial begin
    // init
    btn  = 1'b1;
    rstn = 1'b0;

    // power-on reset: hold for 2 posedges
    repeat (2) @(posedge clk);
    rstn = 1'b1;

    // warm-up
    repeat (2) @(posedge clk);

    // 5 次按压，每次低 1 个完整周期（足够被同步器采到）
    press(1);
    press(1);
    press(1);
    press(1);
    press(1);
	 
	 repeat (2) @(posedge clk);
	 repeat (2) @(posedge clk);
	 
    // 中途复位：验证回到 COLORBAR
    @(posedge clk);
    rstn <= 1'b0;
    @(posedge clk);
    rstn <= 1'b1;

    // 再按两次
    press(1);
    press(1);

    // 再来一次“短按但仍跨过一个 posedge”的情形
    press(1);

    // 结束
    repeat (2) @(posedge clk);
	 repeat (2) @(posedge clk);
	 
    $stop;
  end

  // DUT
  screen_ctl dut (
    .clk    (clk),
    .rstn   (rstn),
    .button (btn),
    .frame  (frame)
  );

  // 观察：打印每次状态变化
  initial begin
    $display("  time   rstn btn  frame");
    $monitor("%6t   %b    %b    %02b", $time, rstn, btn, frame);
    // 如需波形：
    // $dumpfile("tb_screen_ctl.vcd");
    // $dumpvars(0,tb_screen_ctl);
  end

endmodule
