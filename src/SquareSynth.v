`timescale 1ns / 1ps

/// Simple square wave synthesizer.
///
/// Generates a square wave in AUDIO with a period of 2 * HALF_PERIOD ticks.
/// The internal timer is advanced by a tick every clock cycle where
/// (ENABLE && ADVANCE_TICK) is true. If ENABLE is false, internal state and
/// output are reset.
module SquareSynth(
   input CLK,
   input ADVANCE_TICK,
   input ENABLE,
   input[15:0] HALF_PERIOD,
   output reg AUDIO
   );

   reg[15:0] tick;
   reg[15:0] currHalfPeriod;

   initial begin
      tick = 0;
      AUDIO = 0;
      currHalfPeriod = 0;
   end

   always@(posedge CLK) begin
      if (ENABLE) begin
         if (ADVANCE_TICK) begin
            if (tick == currHalfPeriod) begin
               AUDIO <= ~AUDIO;
               currHalfPeriod <= HALF_PERIOD;
               tick <= 0;
            end else begin
               tick <= tick + 1;
            end
         end
      end else begin
         tick <= 0;
         AUDIO <= 0;
      end
   end
endmodule
