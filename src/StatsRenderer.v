`timescale 1ns / 1ps

module StatsRenderer(
   input CLK,
   input [10:0] CURR_X_PIXEL,
   input [9:0] CURR_Y_PIXEL,
   input [2:0] LIVES,
   input [3:0] SCORE_1000,
   input [3:0] SCORE_100,
   input [3:0] SCORE_10,
   input [3:0] SCORE_1,
   output [7:0] COLOR
   );

   parameter yStartTile = 8'd2;
   parameter score10000Tile = 8'd2;
   parameter score1000Tile = 8'd6;
   parameter score100Tile = 8'd10;
   parameter score10Tile = 8'd14;
   parameter score1Tile = 8'd18;
   parameter lives100Tile = 8'd86;
   parameter lives10Tile = 8'd90;
   parameter lives1Tile = 8'd94;

   // Actually renders the digits from the data setup below.
   wire [7:0] xTile = CURR_X_PIXEL[10:3];
   wire [6:0] yTile = CURR_Y_PIXEL[9:3];

   reg [6:0] xStartTile;
   reg [3:0] digit;
   reg inDigitX;
   reg inDigitY;

   reg [0:14] sprites[0:9];
   initial $readmemb("src/number-sprites.dat", sprites, 0, 9);

   wire [1:0] xOffset = xTile - xStartTile;
   wire [2:0] yOffset = yTile - yStartTile;
   wire [0:14] currSprite = sprites[digit];
   assign COLOR = (inDigitX && inDigitY && currSprite[yOffset * 2'd3 + xOffset]) *
      8'b11111111;

   // Determine next tile to render. As no digit touches the vertical edge,
   // we do not need to worry about the wraparound.
   wire [10:0] nextXPixel = CURR_X_PIXEL + 11'd1;
   wire [7:0] nextXTile = nextXPixel[10:3];
   always @(posedge CLK) begin
      if (nextXTile == 8'd0) begin
         inDigitX <= 1'b0;
      end

      if (nextXTile == score10000Tile || nextXTile == lives100Tile ||
         nextXTile == lives10Tile
      ) begin
         xStartTile = nextXTile;
         digit <= 4'd0;
         inDigitX <= 1'b1;
      end

      if (nextXTile == score1000Tile) begin
         xStartTile = score1000Tile;
         digit <= SCORE_1000;
         inDigitX <= 1'b1;
      end

      if (nextXTile == score100Tile) begin
         xStartTile = score100Tile;
         digit <= SCORE_100;
         inDigitX <= 1'b1;
      end

      if (nextXTile == score10Tile) begin
         xStartTile = score10Tile;
         digit <= SCORE_10;
         inDigitX <= 1'b1;
      end

      if (nextXTile == score1Tile) begin
         xStartTile = score1Tile;
         digit <= SCORE_1;
         inDigitX <= 1'b1;
      end

      if (nextXTile == lives1Tile) begin
         xStartTile = lives1Tile;
         digit <= LIVES;
         inDigitX <= 1'b1;
      end

      if (nextXTile == xStartTile + 3) begin
         inDigitX <= 1'b0;
      end

      if (yTile == yStartTile) begin
         inDigitY <= 1'b1;
      end

      if (yTile == yStartTile + 5) begin
         inDigitY <= 1'b0;
      end
   end
endmodule
