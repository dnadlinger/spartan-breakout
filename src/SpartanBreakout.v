`timescale 1ns / 1ps

module SpartanBreakout(
   input CLK_40M,
   output [7:0] COLOR,
   output HSYNC,
   output VSYNC,
   output AUDIO_OUT
   );

   parameter paddleLengthPixel = 10'd60;

   wire [9:0] paddleXPixel;
   GameLogic #(
      .PADDLE_LENGTH_PIXEL(paddleLengthPixel)
   ) logic(
      .CLK(CLK_40M),
      .START_UPDATE(1'b0),
      .PADDLE_X_PIXEL(paddleXPixel)
   );

   GameRenderer #(
      .PADDLE_LENGTH_PIXEL(paddleLengthPixel)
   ) renderer(
      .CLK(CLK_40M),
      .PADDLE_X_PIXEL(paddleXPixel),
      .COLOR(COLOR),
      .HSYNC(HSYNC),
      .VSYNC(VSYNC)
   );

   AudioPlayer audioPlayer(.CLK(CLK_40M), .AUDIO(AUDIO_OUT));
endmodule
