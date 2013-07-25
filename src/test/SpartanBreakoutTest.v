`timescale 1ns / 1ps

module SpartanBreakoutTest;
   // Inputs
   reg CLK_40M;
   reg BTN_LEFT;
   reg BTN_RIGHT;
   reg BTN_A;
   reg BTN_B;
   reg SW_RESET;
   reg SW_PAUSE;
   reg SW_IGNORE_DEATH;

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
      .BTN_A(BTN_A),
      .BTN_B(BTN_B),
      .SW_RESET(SW_RESET),
      .SW_PAUSE(SW_PAUSE),
      .SW_IGNORE_DEATH(SW_IGNORE_DEATH),
      .COLOR(COLOR),
      .HSYNC(HSYNC),
      .VSYNC(VSYNC),
      .AUDIO_OUT(AUDIO_OUT)
   );

   initial begin
      // Initialize Inputs
      CLK_40M = 0;

      BTN_LEFT <= 0;
      BTN_RIGHT <= 0;
      BTN_A <= 0;
      BTN_B <= 0;
      SW_RESET <= 0;
      SW_PAUSE <= 0;
      SW_IGNORE_DEATH <= 0;

      // Wait 100 ns for global reset to finish
      #100;

      // 40 MHz clock.
      forever begin
         #12.5;
         CLK_40M = ~CLK_40M;
      end
   end
endmodule
