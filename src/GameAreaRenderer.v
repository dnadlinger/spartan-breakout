`timescale 1ns / 1ps

module GameAreaRenderer(
   input [9:0] CURR_X_PIXEL,
   input [9:0] CURR_Y_PIXEL,
   input [9:0] PADDLE_X_PIXEL,
   input [9:0] BALL_X_PIXEL,
   input [9:0] BALL_Y_PIXEL,
   output [6:0] BLOCK_ADDR,
   input BLOCK_ALIVE,
   output reg [7:0] COLOR
   );

   `include "game-geometry.v"

   // Horizontal block position.
   wire [6:0] currXTile = CURR_X_PIXEL[9:3];
   wire [6:0] currYTile = CURR_Y_PIXEL[9:3];

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
      PADDLE_X_PIXEL <= CURR_X_PIXEL &&
      CURR_X_PIXEL < PADDLE_X_PIXEL + paddleLengthPixel;

   // Ball.
   reg [7:0] ballSprite[7:0];
   initial
      $readmemb("src/ball-sprite.dat", ballSprite, 0, 7);

   wire [9:0] ballOffsetXPixel = CURR_X_PIXEL - BALL_X_PIXEL;
   wire [9:0] ballOffsetYPixel = CURR_Y_PIXEL - BALL_Y_PIXEL;
   wire [7:0] spriteLine = ballSprite[ballOffsetYPixel[2:0]];
   wire inBall = ~|ballOffsetXPixel[9:3] && ~|ballOffsetYPixel[9:3] &&
      spriteLine[ballOffsetXPixel[2:0]];

   // Block state reading logic.
   // The blocks never touch the vertical screen edges, so we can get away with
   // not updating the y coordinate.
   wire [6:0] blockXTile = CURR_X_PIXEL[9:3] - blockStartXTile;
   wire [3:0] blockCol = blockXTile[6:3];
   wire [9:0] nextXPixel = CURR_X_PIXEL + 10'd1;
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
      COLOR <= ((inHousing | inPaddle | inBall) * 8'b11111111) |
         (inBlock * blockColor);
   end
endmodule
