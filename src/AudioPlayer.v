`timescale 1ns / 1ps

module AudioPlayer(CLK, FRAME_SELECT, FRAME_SET, AUDIO);
   parameter FRAME_BITS = 4;
   parameter FRAME_COUNT = 16;

   input CLK;
   input [FRAME_BITS - 1:0] FRAME_SELECT;
   input FRAME_SET;
   output AUDIO;

   reg [15:0] periods[0:FRAME_COUNT - 1];
   reg [9:0] durations[0:FRAME_COUNT - 1];
   initial begin
      $readmemh("src/audio-periods.dat", periods, 0, FRAME_COUNT - 1);
      $readmemh("src/audio-durs.dat", durations, 0, FRAME_COUNT - 1);
   end

   wire tickSequencer;
   GenericCounter #(
      .COUNTER_WIDTH(16),
      .COUNTER_MAX(48828)
   ) sequencerDivider(
      .CLK(CLK),
      .RESET(1'b0),
      .ENABLE_IN(1'b1),
      .TRIG_OUT(tickSequencer)
   );

   reg [FRAME_BITS - 1:0] currFrame = 0;
   reg [9:0] framePos = 0;
   reg [15:0] synthPeriod = 0;
   reg synthEnable = 0;

   always@(posedge CLK) begin
      if (FRAME_SET) begin
         currFrame <= FRAME_SELECT;
         framePos <= 0;
      end else if (tickSequencer) begin
         if (framePos == 0) begin
            synthEnable <= ~(periods[currFrame] == 0);
            synthPeriod <= periods[currFrame];
         end

         if (framePos == durations[currFrame]) begin
            framePos <= 0;

            if (~(durations[currFrame] == 0 && periods[currFrame] == 0))
               currFrame <= currFrame + 1;
         end else begin
            framePos <= framePos + 1;
         end
      end
   end

   wire tickSynth;
   GenericCounter #(
      .COUNTER_WIDTH(7),
      .COUNTER_MAX(7'b1111111)
   ) sampleDivider(
      .CLK(CLK),
      .RESET(1'b0),
      .ENABLE_IN(1'b1),
      .TRIG_OUT(tickSynth)
   );

   SquareSynth synth(
      .CLK(CLK),
      .ENABLE(synthEnable),
      .ADVANCE_TICK(tickSynth),
      .HALF_PERIOD(synthPeriod),
      .AUDIO(AUDIO)
   );
endmodule
