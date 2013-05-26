`timescale 1ns / 1ps

module SpartanBreakout(
   input CLK_40M,
   input BTN_LEFT,
   input BTN_RIGHT,
   input BTN_A,
   input BTN_B,
   input SW_RESET,
   input SW_PAUSE,
   output [7:0] COLOR,
   output HSYNC,
   output VSYNC,
   output AUDIO_OUT
   );

   reg initialReset = 1'b1;
   always @(posedge CLK_40M) begin
      initialReset <= 1'b0;
   end
   wire reset = initialReset | SW_RESET;

   wire frameDone;
   wire [9:0] paddleXPixel;
   wire [9:0] ballXPixel;
   wire [9:0] ballYPixel;
   wire [71:0] blockState;
   GameController controller(
      .CLK(CLK_40M),
      .RESET(reset),
      .FRAME_RENDERED(frameDone),
      .BTN_LEFT(BTN_LEFT),
      .BTN_RIGHT(BTN_RIGHT),
      .BTN_RELEASE(BTN_A | BTN_B),
      .SW_PAUSE(SW_PAUSE),
      .PADDLE_X_PIXEL(paddleXPixel),
      .BALL_X_PIXEL(ballXPixel),
      .BALL_Y_PIXEL(ballYPixel),
      .BLOCK_STATE(blockState)
   );

   GameRenderer renderer(
      .CLK(CLK_40M),
      .PADDLE_X_PIXEL(paddleXPixel),
      .BALL_X_PIXEL(ballXPixel),
      .BALL_Y_PIXEL(ballYPixel),
      .BLOCK_STATE(blockState),
      .FRAME_DONE(frameDone),
      .COLOR(COLOR),
      .HSYNC(HSYNC),
      .VSYNC(VSYNC)
   );

   AudioPlayer audioPlayer(.CLK(CLK_40M), .AUDIO(AUDIO_OUT));
endmodule
