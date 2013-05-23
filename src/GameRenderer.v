`timescale 1ns / 1ps

module GameRenderer(
   input CLK,
   output [7:0] COLOR,
   output HSYNC,
   output VSYNC
   );

   wire frameStart;
   wire [7:0] dummyColor;
   GenericCounter #(
      .COUNTER_WIDTH(8),
      .COUNTER_MAX(8'b11111111)
   ) dummyFrameColorCounter (
      .CLK(CLK),
      .RESET(1'b0),
      .ENABLE_IN(frameStart),
      .COUNT(dummyColor)
   );

   SVGAInterface videoInterface(
      .CLK(CLK),
      .COLOR_IN(dummyColor),
      .FRAME_START(frameStart),
      .COLOR_OUT(COLOR),
      .HSYNC(HSYNC),
      .VSYNC(VSYNC)
   );
endmodule
