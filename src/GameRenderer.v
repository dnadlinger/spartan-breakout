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
   input [71:0] BLOCK_STATE,
   output reg FRAME_DONE,
   output [7:0] COLOR,
   output HSYNC,
   output VSYNC
   );

   `include "game-geometry.v"

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
   wire inHousing = (
         currYTile == ceilingYTile &&
         currXTile >= leftWallXTile &&
         currXTile <= rightWallXTile
      ) || (
         currYTile > ceilingYTile && (
            currXTile == leftWallXTile ||
            currXTile == rightWallXTile
         )
      );

   wire inPaddle =
      currYTile == paddleYTile &&
      PADDLE_X_PIXEL <= currXPixel &&
      currXPixel < PADDLE_X_PIXEL + paddleLengthPixel;

   wire inBall =
      BALL_X_PIXEL <= currXPixel &&
      BALL_Y_PIXEL <= currYPixel &&
      currXPixel < BALL_X_PIXEL + ballSizePixel &&
      currYPixel < BALL_Y_PIXEL + ballSizePixel;

   wire [6:0] blockXTile = currXTile - blockStartXTile;
   wire [3:0] blockCol = blockXTile[6:3];
   wire [6:0] blockRow = currYTile - blockStartYTile;
   wire inBlock =
      blockCol < blockColCount &&
      blockRow < blockRowCount &&
      BLOCK_STATE[(blockRow[2:0] * blockColCount) + blockCol];

   reg[7:0] blockColor;
   always @(blockRow) begin
      case (blockRow)
         6'd0: blockColor <= 8'b00000111;
         6'd1: blockColor <= 8'b00011110;
         6'd2: blockColor <= 8'b00111111;
         6'd3: blockColor <= 8'b00110000;
         6'd4: blockColor <= 8'b11010000;
         6'd5: blockColor <= 8'b10000011;
         default: blockColor <= 8'b0;
      endcase
   end

   always @(inHousing or inPaddle or inBall) begin
      currColor[7:0] <=
         ((inHousing | inPaddle | inBall) * 8'b11111111) |
         (inBlock * blockColor);
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
