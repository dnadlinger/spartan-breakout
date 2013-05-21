`timescale 1ns / 1ps

module SquareSynth(
    input[15:0] HALF_PERIOD,
    input ENABLE,
    input CLK,
	 input SAMPLE_TRIGGER,
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
			if (SAMPLE_TRIGGER) begin
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
		end
	end
endmodule
