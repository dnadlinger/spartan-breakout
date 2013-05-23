`timescale 1ns / 1ps

/// Renders the game screen for the given game state.
///
/// We generally do not care about what happens outside the 800x600 region, the
/// video interface will blank the output anyway.
///
/// There are two fundamental units: Raw pixels, and 10 px by 10 px "blocks".
module GameRenderer(
   input CLK,
   output [7:0] COLOR,
   output HSYNC,
   output VSYNC
   );

   // The whole logic is driven by the SVGA interface.
   wire frameStart;
   wire lineStart;
   wire [9:0] currXPixel;
   wire [9:0] currYPixel;
   reg [7:0] currColor;
   SVGAInterface videoInterface(
      .CLK(CLK),
      .COLOR_IN(currColor),
      .X_PIXEL(currXPixel),
      .Y_PIXEL(currYPixel),
      .FRAME_START(frameStart),
      .LINE_START(lineStart),
      .COLOR_OUT(COLOR),
      .HSYNC(HSYNC),
      .VSYNC(VSYNC)
   );

   // Horizontal block position.
   reg [6:0] currXBlock;
   wire xBlockStart;
   GenericCounter #(
      .COUNTER_WIDTH(4),
      .COUNTER_MAX(9)
   ) xBlockDivider (
      .CLK(CLK),
      .RESET(lineStart),
      .ENABLE_IN(1'b1),
      .TRIG_OUT(xBlockStart)
   );

   always @(posedge CLK) begin
      if (lineStart) begin
         currXBlock <= 0;
      end else if (xBlockStart) begin
         currXBlock <= currXBlock + 1;
      end
   end

   // Vertical block position.
   reg [5:0] currYBlock;
   wire yBlockStart;
   GenericCounter #(
      .COUNTER_WIDTH(4),
      .COUNTER_MAX(9)
   ) yBlockDivider (
      .CLK(CLK),
      .RESET(frameStart),
      .ENABLE_IN(lineStart),
      .TRIG_OUT(yBlockStart)
   );

   always @(posedge CLK) begin
      if (frameStart) begin
         currYBlock <= 0;
      end else if (yBlockStart) begin
         currYBlock <= currYBlock + 1;
      end
   end

   parameter ceilingPosBlock = 6'd7;
   parameter leftWallPosBlock = 7'd0;
   parameter rightWallPosBlock = 7'd79;

   wire inHousing =
      (currYBlock == ceilingPosBlock) |
      ((currYBlock > ceilingPosBlock) &
      ((currXBlock == leftWallPosBlock) |
      (currXBlock == rightWallPosBlock)));

   always @(posedge CLK) begin
      currColor[7:0] <= inHousing * 8'b11111111;
   end
endmodule
