`timescale 1ns / 1ps

/// Renders the game screen for the given game state.
///
/// We generally do not care about what happens outside the 800x600 region, the
/// video interface will blank the output anyway.
///
/// There are two fundamental units: Raw pixels, and 8 px by 8 px "blocks".
module GameRenderer(
   input CLK,
   input [9:0] PADDLE_X_PIXEL,
   input [9:0] BALL_X_PIXEL,
   input [9:0] BALL_Y_PIXEL,
   output [6:0] BLOCK_ADDR,
   input BLOCK_ALIVE,
   output reg FRAME_DONE,
   output [7:0] COLOR,
   output HSYNC,
   output VSYNC
   );

   `include "game-geometry.v"

   // The whole logic is driven by the SVGA interface.
   wire [10:0] currXPixelFull;
   wire [9:0] currXPixel = currXPixelFull[9:0];
   wire [9:0] currYPixel;
   wire [7:0] gameAreaColor;
   SVGAInterface videoInterface(
      .CLK(CLK),
      .COLOR_IN(gameAreaColor),
      .X_PIXEL(currXPixelFull),
      .Y_PIXEL(currYPixel),
      .COLOR_OUT(COLOR),
      .HSYNC(HSYNC),
      .VSYNC(VSYNC)
   );

   GameAreaRenderer gameAreaRenderer(
      .CURR_X_PIXEL(currXPixel),
      .CURR_Y_PIXEL(currYPixel),
      .PADDLE_X_PIXEL(PADDLE_X_PIXEL),
      .BALL_X_PIXEL(BALL_X_PIXEL),
      .BALL_Y_PIXEL(BALL_Y_PIXEL),
      .BLOCK_ADDR(BLOCK_ADDR),
      .BLOCK_ALIVE(BLOCK_ALIVE),
      .COLOR(gameAreaColor)
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
