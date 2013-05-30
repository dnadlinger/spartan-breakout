`timescale 1ns / 1ps

module SampleBank(CLK, SELECT, TRIGGER, AUDIO);
   `include "audio-samples.v"

   input CLK;
   input [sampleBits - 1:0] SELECT;
   input TRIGGER;
   output AUDIO;

   parameter frameBits = 5;
   parameter frameCount = 27;

   reg [frameBits - 1:0] sampleStart[0:sampleCount - 1];
   initial begin
      $readmemh("src/audio-samples.dat", sampleStart, 0, sampleCount - 1);
   end

   AudioPlayer #(
      .FRAME_BITS(frameBits),
      .FRAME_COUNT(frameCount)
   ) player (
      .CLK(CLK),
      .FRAME_SELECT(sampleStart[SELECT]),
      .FRAME_SET(TRIGGER),
      .AUDIO(AUDIO)
   );
endmodule
