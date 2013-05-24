`timescale 1ns / 1ps

/// Renders the game screen for the given game state.
///
/// We generally do not care about what happens outside the 800x600 region, the
/// video interface will blank the output anyway.
///
/// There are two fundamental units: Raw pixels, and 10 px by 10 px "blocks".
module GameRenderer(
   input CLK,
   input [9:0] PADDLE_X_PIXEL,
   output [7:0] COLOR,
   output HSYNC,
   output VSYNC
   );

   parameter PADDLE_LENGTH_PIXEL = 10'd60;

   // The whole logic is driven by the SVGA interface.
   wire lineStart;
   wire [9:0] currXPixel;
   wire [9:0] currYPixel;
   reg [7:0] currColor;
   SVGAInterface videoInterface(
      .CLK(CLK),
      .COLOR_IN(currColor),
      .X_PIXEL(currXPixel),
      .Y_PIXEL(currYPixel),
      .LINE_START(lineStart),
      .COLOR_OUT(COLOR),
      .HSYNC(HSYNC),
      .VSYNC(VSYNC)
   );

   // Horizontal block position.
   reg [6:0] currXBlock = 0;
   reg [3:0] xBlockSubpos = 0;
   reg waitForLineStart = 1'b1;

   always @(posedge CLK) begin
      if (lineStart) begin
          xBlockSubpos <= 4'd1;
          waitForLineStart <= 1'b0;
      end else if (currXBlock == 7'd80) begin
         currXBlock <= 7'd0;
         xBlockSubpos <= 4'd0;
         waitForLineStart <= 1'b1;
      end else if (~waitForLineStart) begin
         if (xBlockSubpos == 4'd9) begin
            currXBlock <= currXBlock + 7'd1;
            xBlockSubpos <= 4'd0;
         end else begin
            xBlockSubpos <= xBlockSubpos + 4'd1;
         end
      end
   end

   // Vertical block position.
   reg [5:0] currYBlock = 0;
   reg [3:0] yBlockSubpos = 0;
   reg waitForFrameStart = 1'b1;

   always @(posedge CLK) begin
      if (currXPixel == 10'd800) begin
         if (currYPixel == 10'd0) begin
             yBlockSubpos <= 4'd1;
             waitForFrameStart <= 1'b0;
         end else if (currYBlock == 6'd60) begin
            currYBlock <= 6'd0;
            yBlockSubpos <= 4'd0;
            waitForFrameStart <= 1'b1;
         end else if (~waitForFrameStart) begin
            if (yBlockSubpos == 4'd9) begin
               currYBlock <= currYBlock + 6'd1;
               yBlockSubpos <= 4'd0;
            end else begin
               yBlockSubpos <= yBlockSubpos + 4'd1;
            end
         end
      end
   end

   // Draw the game housing.
   parameter ceilingPosBlock = 6'd7;
   parameter leftWallPosBlock = 7'd0;
   parameter rightWallPosBlock = 7'd79;
   parameter paddleYBlock = 6'd58;

   wire inHousing =
      (currYBlock == ceilingPosBlock) |
      ((currYBlock > ceilingPosBlock) &
      ((currXBlock == leftWallPosBlock) |
      (currXBlock == rightWallPosBlock)));

   wire inPaddle =
      currYBlock == paddleYBlock &&
      PADDLE_X_PIXEL <= currXPixel &&
      currXPixel < PADDLE_X_PIXEL + PADDLE_LENGTH_PIXEL;

   always @(inHousing or inPaddle) begin
      currColor[7:0] <= (inHousing | inPaddle) * 8'b11111111;
   end
endmodule
