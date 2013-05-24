`timescale 1ns / 1ps

module SpartanBreakout(
   input CLK_40M,
   input BTN_LEFT,
   input BTN_RIGHT,
   output [7:0] COLOR,
   output HSYNC,
   output VSYNC,
   output AUDIO_OUT
   );

   parameter paddleLengthPixel = 10'd60;

   wire frameDone;
   wire [9:0] paddleXPixel;
   GameLogic #(
      .PADDLE_LENGTH_PIXEL(paddleLengthPixel)
   ) logic(
      .CLK(CLK_40M),
      .START_UPDATE(frameDone),
      .BTN_LEFT(BTN_LEFT),
      .BTN_RIGHT(BTN_RIGHT),
      .PADDLE_X_PIXEL(paddleXPixel)
   );

   GameRenderer #(
      .PADDLE_LENGTH_PIXEL(paddleLengthPixel)
   ) renderer(
      .CLK(CLK_40M),
      .PADDLE_X_PIXEL(paddleXPixel),
      .FRAME_DONE(frameDone),
      .COLOR(COLOR),
      .HSYNC(HSYNC),
      .VSYNC(VSYNC)
   );

   AudioPlayer audioPlayer(.CLK(CLK_40M), .AUDIO(AUDIO_OUT));
endmodule
