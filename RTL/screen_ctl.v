`timescale 1ns/1ps

// Screen controller (Moore FSM).
// Recommended "edge-triggered" version: each button press (falling edge) advances one step:
// COLORBAR -> MUST -> END_ -> COLORBAR -> ...
module screen_ctl (
    input  wire       clk,
    input  wire       rstn,     // active-low asynchronous reset
    input  wire       button,   // raw button input, assumed idle=1, pressed=0

    output wire [1:0] frame     // Moore output: equals current state
);
    // ============= Two-flop synchronizer (no reset on sync flops) =============
    // Safely bring the asynchronous button into the clk domain.
    reg btn_ff1, btn_ff2;
    always @(posedge clk) begin
        btn_ff1 <= button;   // first stage: may go metastable
        btn_ff2 <= btn_ff1;  // second stage: metastability greatly reduced
    end
    wire button_sync = btn_ff2;  // synchronized button level
// why the above safe ?

    // ============= Falling-edge detection =============
    // Generate a 1-clock pulse on the press moment (1 -> 0 transition).
    reg button_d;  // delayed copy of button_sync
    always @(posedge clk or negedge rstn) begin
        if (!rstn) button_d <= 1'b1;       // idle assumed high
        else       button_d <= button_sync;
    end
    wire btn_fall = (button_d == 1'b1) && (button_sync == 1'b0); 
    // one-cycle pulse has been maintained for the later operations, through the () && ()

// Before : button
    // ============= State encoding (Moore) =============
    localparam [1:0] COLORBAR = 2'd0,
                     MUST     = 2'd1,
                     END_     = 2'd3; 

    reg [1:0] st_cur, st_next;

    // ============= State register =============
    // Reset handled only here; combination logic does not check rstn.
    always @(posedge clk or negedge rstn) begin// only part for the rstn 
        if (!rstn) st_cur <= COLORBAR;
        else       st_cur <= st_next;
    end

    // ============= Next-state logic (combinational) =============
    // Advance exactly one step per falling edge; otherwise hold.
    always @(*) begin
        st_next = st_cur; // hold state, if no rstn and no btn_fall
        case (st_cur)
            COLORBAR: if (btn_fall) st_next = MUST;
            MUST    : if (btn_fall) st_next = END_;
            END_    : if (btn_fall) st_next = COLORBAR;
            default : st_next = COLORBAR;// no real use, but essential
        endcase
    end

    // ============= Moore output =============
    //assign frame = st_cur;
    reg [1:0] frame_r;

    always@(posedge clk)
        frame_r <= st_cur;
    
    assign frame = frame_r;
endmodule
