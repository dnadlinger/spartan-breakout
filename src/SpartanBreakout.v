`timescale 1ns / 1ps

module SpartanBreakout(
   input CLK_40M,
   output AUDIO_OUT
   );

   AudioPlayer player(.CLK(CLK_40M), .AUDIO(AUDIO_OUT));
endmodule
