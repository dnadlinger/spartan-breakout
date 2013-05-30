`timescale 1ns / 1ps

module GameController(
   input CLK,
   input RESET,
   input FRAME_RENDERED,
   input BTN_LEFT,
   input BTN_RIGHT,
   input BTN_RELEASE,
   input SW_PAUSE,
   input SW_IGNORE_DEATH,
   output [9:0] PADDLE_X_PIXEL,
   output [9:0] BALL_X_PIXEL,
   output [9:0] BALL_Y_PIXEL,
   input [6:0] BLOCK_ADDR,
   output BLOCK_ALIVE
   );

   GamePhysics physics(
      .CLK(CLK),
      .RESET(RESET),
      .START_UPDATE(FRAME_RENDERED && !SW_PAUSE),
      .BTN_LEFT(BTN_LEFT),
      .BTN_RIGHT(BTN_RIGHT),
      .BTN_RELEASE(BTN_RELEASE),
      .SW_IGNORE_DEATH(SW_IGNORE_DEATH),
      .PADDLE_X_PIXEL(PADDLE_X_PIXEL),
      .BALL_X_PIXEL(BALL_X_PIXEL),
      .BALL_Y_PIXEL(BALL_Y_PIXEL),
      .BLOCK_ADDR(BLOCK_ADDR),
      .BLOCK_ALIVE(BLOCK_ALIVE)
   );
endmodule
