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
   output reg FRAME_DONE,
   output [7:0] COLOR,
   output HSYNC,
   output VSYNC
   );

   parameter PADDLE_LENGTH_PIXEL = 10'd60;
   parameter ballSizePixel = 8;

   // The whole logic is driven by the SVGA interface.
   wire [9:0] currXPixel;
   wire [9:0] currYPixel;
   reg [7:0] currColor;
   SVGAInterface videoInterface(
      .CLK(CLK),
      .COLOR_IN(currColor),
      .X_PIXEL(currXPixel),
      .Y_PIXEL(currYPixel),
      .COLOR_OUT(COLOR),
      .HSYNC(HSYNC),
      .VSYNC(VSYNC)
   );

   // Horizontal block position.
   wire [6:0] currXTile = currXPixel[9:3];
   wire [6:0] currYTile = currYPixel[9:3];

   // Draw the game housing.
   parameter ceilingYTile = 7'd9;
   parameter leftWallXTile = 7'd0;
   parameter rightWallXTile = 7'd99;
   parameter paddleYTile = 7'd73;

   wire inHousing =
      (currYTile == ceilingYTile) |
      ((currYTile > ceilingYTile) &
      ((currXTile == leftWallXTile) |
      (currXTile == rightWallXTile)));

   wire inPaddle =
      currYTile == paddleYTile &&
      PADDLE_X_PIXEL <= currXPixel &&
      currXPixel < PADDLE_X_PIXEL + PADDLE_LENGTH_PIXEL;

   wire inBall =
      BALL_X_PIXEL <= currXPixel &&
      BALL_Y_PIXEL <= currYPixel &&
      currXPixel < BALL_X_PIXEL + ballSizePixel &&
      currYPixel < BALL_Y_PIXEL + ballSizePixel;

   always @(inHousing or inPaddle or inBall) begin
      currColor[7:0] <= (inHousing | inPaddle | inBall) * 8'b11111111;
   end

   // Synchronously generate the syncing signal for the game logic.
   always @(posedge CLK) begin
      if (currXPixel == 10'd0 && currYPixel == 10'd600) begin
         FRAME_DONE <= 1;
      end else begin
         FRAME_DONE <= 0;
      end
   end
endmodule
