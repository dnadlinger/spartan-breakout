`timescale 1ns / 1ps

module SpartanBreakoutTest;
   // Inputs
   reg CLK_40M;
   reg BTN_LEFT;
   reg BTN_RIGHT;

   // Outputs
   wire [7:0] COLOR;
   wire HSYNC;
   wire VSYNC;
   wire AUDIO_OUT;

   // Instantiate the Unit Under Test (UUT)
   SpartanBreakout uut (
      .CLK_40M(CLK_40M),
      .BTN_LEFT(BTN_LEFT),
      .BTN_RIGHT(BTN_RIGHT),
      .COLOR(COLOR),
      .HSYNC(HSYNC),
      .VSYNC(VSYNC),
      .AUDIO_OUT(AUDIO_OUT)
   );

   initial begin
      // Initialize Inputs
      CLK_40M = 0;

      // Wait 100 ns for global reset to finish
      #100;

      // 40 MHz clock.
      forever begin
         #12.5;
         CLK_40M = ~CLK_40M;
      end
   end

   initial begin
      BTN_LEFT = 1;
      BTN_RIGHT = 0;
      #30000000
      BTN_LEFT = 0;
   end
endmodule
