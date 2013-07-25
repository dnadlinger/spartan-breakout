`timescale 1ns / 1ps

module GameLogicTest;

   // Inputs
   reg CLK;
   reg START_UPDATE;
   reg BTN_LEFT;
   reg BTN_RIGHT;

   // Outputs
   wire [9:0] PADDLE_X_PIXEL;

   // Instantiate the Unit Under Test (UUT)
   GameLogic uut (
      .CLK(CLK),
      .START_UPDATE(START_UPDATE),
      .BTN_LEFT(BTN_LEFT),
      .BTN_RIGHT(BTN_RIGHT),
      .PADDLE_X_PIXEL(PADDLE_X_PIXEL)
   );

   // 40 MHz clock.
   always begin
      #1.25;
      CLK = ~CLK;
   end

   initial begin
      // Initialize Inputs
      CLK = 0;
      START_UPDATE = 0;
      BTN_LEFT = 0;
      BTN_RIGHT = 0;

      // Wait 100 ns for global reset to finish
      #100;

      #100;
      START_UPDATE = 1;
      #12.5;
      START_UPDATE = 0;

      #100;
      BTN_LEFT = 1;
      START_UPDATE = 1;
      #1.25
      START_UPDATE = 0;
      #10000;
      BTN_LEFT = 0;
   end
endmodule

