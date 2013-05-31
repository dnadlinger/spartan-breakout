`timescale 1ns / 1ps

/// Renders the game screen for the given game state.
///
/// We generally do not care about what happens outside the 800x600 region, the
/// video interface will blank the output anyway.
///
/// There are two fundamental units: Raw pixels, and 8 px by 8 px "blocks".
module GameRenderer(
   input CLK,
   input [1:0] SCREEN_SELECT,
   input [9:0] PADDLE_X_PIXEL,
   input [9:0] BALL_X_PIXEL,
   input [9:0] BALL_Y_PIXEL,
   output [6:0] BLOCK_ADDR,
   input BLOCK_ALIVE,
   input [2:0] LIVES,
   input [3:0] SCORE_1000,
   input [3:0] SCORE_100,
   input [3:0] SCORE_10,
   input [3:0] SCORE_1,
   output reg FRAME_DONE,
   output [7:0] COLOR,
   output HSYNC,
   output VSYNC
   );

   `include "game-geometry.v"
   `include "screens.v"

   // The whole logic is driven by the SVGA interface.
   wire [10:0] currXPixel;
   wire [9:0] currYPixel;
   wire [7:0] gameAreaColor;
   wire [7:0] statsColor;

   parameter introColor = 8'b11000000;
   parameter gameOverColor = 8'b00000100;

   wire [7:0] finalColor =
      ((SCREEN_SELECT == Screen_intro) * introColor) |
      ((SCREEN_SELECT == Screen_gameOver) * gameOverColor) |
      ((SCREEN_SELECT == Screen_inGame) * gameAreaColor) |
      ((SCREEN_SELECT != Screen_intro) * statsColor);

   SVGAInterface videoInterface(
      .CLK(CLK),
      .COLOR_IN(finalColor),
      .X_PIXEL(currXPixel),
      .Y_PIXEL(currYPixel),
      .COLOR_OUT(COLOR),
      .HSYNC(HSYNC),
      .VSYNC(VSYNC)
   );

   GameAreaRenderer gameAreaRenderer(
      .CURR_X_PIXEL(currXPixel[9:0]),
      .CURR_Y_PIXEL(currYPixel),
      .PADDLE_X_PIXEL(PADDLE_X_PIXEL),
      .BALL_X_PIXEL(BALL_X_PIXEL),
      .BALL_Y_PIXEL(BALL_Y_PIXEL),
      .BLOCK_ADDR(BLOCK_ADDR),
      .BLOCK_ALIVE(BLOCK_ALIVE),
      .COLOR(gameAreaColor)
   );

   StatsRenderer statsRenderer(
      .CLK(CLK),
      .CURR_X_PIXEL(currXPixel),
      .CURR_Y_PIXEL(currYPixel),
      .LIVES(LIVES),
      .SCORE_1000(SCORE_1000),
      .SCORE_100(SCORE_100),
      .SCORE_10(SCORE_10),
      .SCORE_1(SCORE_1),
      .COLOR(statsColor)
   );

   // Synchronously generate the syncing signal for the game logic.
   always @(posedge CLK) begin
      if (currXPixel == 10'd0 && currYPixel == 10'd600) begin
         FRAME_DONE <= 1;
      end else begin
         FRAME_DONE <= 0;
      end
   end
endmodule
