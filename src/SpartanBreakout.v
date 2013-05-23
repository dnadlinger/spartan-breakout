`timescale 1ns / 1ps

module SpartanBreakout(
   input CLK_40M,
   output [7:0] COLOR,
   output HSYNC,
   output VSYNC,
   output AUDIO_OUT
   );

   GameRenderer renderer(
      .CLK(CLK_40M),
      .COLOR(COLOR),
      .HSYNC(HSYNC),
      .VSYNC(VSYNC)
   );
   AudioPlayer player(.CLK(CLK_40M), .AUDIO(AUDIO_OUT));
endmodule
