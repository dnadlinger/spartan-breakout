`timescale 1ns / 1ps

module AudioPlayer(
   input CLK,
   output AUDIO
   );

   parameter frameBits = 4;
   parameter audioFrameCount = 10;

   reg [15:0] audioPeriods[0:audioFrameCount - 1];
   reg [9:0] audioDurs[0:audioFrameCount - 1];
   initial begin
      $readmemh("audio-periods.dat", audioPeriods, 0, audioFrameCount - 1);
      $readmemh("audio-durs.dat", audioDurs, 0, audioFrameCount - 1);
   end

   wire sequencerTrigger;
   GenericCounter #(
      .COUNTER_WIDTH(16),
      .COUNTER_MAX(48828)
   ) sequencerDivider(
      .CLK(CLK),
      .RESET(1'b0),
      .ENABLE_IN(1'b1),
      .TRIG_OUT(sequencerTrigger)
   );

   reg [frameBits - 1:0] currFrame = 0;
   reg [9:0] framePos = 0;
   reg [15:0] synthPeriod = 0;
   reg synthEnable = 0;

   always@(posedge CLK) begin
      if (sequencerTrigger) begin
         if (framePos == 0) begin
            synthEnable <= ~(audioPeriods[currFrame] == 0);
            synthPeriod <= audioPeriods[currFrame];
         end

         if (framePos == audioDurs[currFrame]) begin
            framePos <= 0;

            if (~(audioDurs[currFrame] == 0 && audioPeriods[currFrame] == 0))
               currFrame <= currFrame + 1;
         end else begin
            framePos <= framePos + 1;
         end
      end
   end

   wire sampleTrigger;
   GenericCounter #(
      .COUNTER_WIDTH(7),
      .COUNTER_MAX(7'b1111111)
   ) sampleDivider(
      .CLK(CLK),
      .RESET(1'b0),
      .ENABLE_IN(1'b1),
      .TRIG_OUT(sampleTrigger)
   );

   SquareSynth synth(
      .HALF_PERIOD(synthPeriod),
      .ENABLE(synthEnable),
      .CLK(CLK),
      .SAMPLE_TRIGGER(sampleTrigger),
      .AUDIO(AUDIO)
   );
endmodule
