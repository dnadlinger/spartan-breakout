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
   reg [7:0] currColor;
   SVGAInterface videoInterface(
      .CLK(CLK),
      .COLOR_IN(currColor),
      .X_PIXEL(currXPixelFull),
      .Y_PIXEL(currYPixel),
      .COLOR_OUT(COLOR),
      .HSYNC(HSYNC),
      .VSYNC(VSYNC)
   );

   // Horizontal block position.
   wire [6:0] currXTile = currXPixel[9:3];
   wire [6:0] currYTile = currYPixel[9:3];

   // Game housing and paddle.
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

   // Ball.
   reg [7:0] ballSprite[7:0];
   initial
      $readmemb("src/ball-sprite.dat", ballSprite, 0, 7);

   wire [9:0] ballOffsetXPixel = currXPixel - BALL_X_PIXEL;
   wire [9:0] ballOffsetYPixel = currYPixel - BALL_Y_PIXEL;
   wire [7:0] spriteLine = ballSprite[ballOffsetYPixel[2:0]];
   wire inBall = ~|ballOffsetXPixel[9:3] && ~|ballOffsetYPixel[9:3] &&
      spriteLine[ballOffsetXPixel[2:0]];

   // Block state reading logic.
   // The blocks never touch the vertical screen edges, so we can get away with
   // not updating the y coordinate.
   wire [6:0] blockXTile = currXPixel[9:3] - blockStartXTile;
   wire [3:0] blockCol = blockXTile[6:3];
   wire [9:0] nextXPixel = currXPixel + 10'd1;
   wire [6:0] nextXTile = nextXPixel[9:3] - blockStartXTile;
   wire [3:0] nextCol = nextXTile[6:3];
   wire [6:0] blockYTile = currYTile - blockStartYTile;
   wire [5:0] blockRow = blockYTile[6:1];
   assign BLOCK_ADDR = (blockRow[2:0] * blockColCount) + nextCol;
   wire inBlock = blockCol < blockColCount && blockRow < blockRowCount && BLOCK_ALIVE;

   reg[7:0] blockColor;
   always @(blockRow) begin
      case (blockRow)
         6'd0: blockColor <= 8'b00001111;
         6'd1: blockColor <= 8'b00011110;
         6'd2: blockColor <= 8'b00111111;
         6'd3: blockColor <= 8'b00110000;
         6'd4: blockColor <= 8'b11101000;
         6'd5: blockColor <= 8'b11001001;
         6'd6: blockColor <= 8'b10000011;
         default: blockColor <= 8'b0;
      endcase
   end

   always @(inHousing or inPaddle or inBall or inBlock or blockColor) begin
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
