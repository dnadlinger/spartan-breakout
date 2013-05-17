`timescale 1ns / 1ps

module AudioPlayer(
    input CLK,
	 output AUDIO
    );
	 
   wire clk391k;
	GenericCounter #(
		.COUNTER_WIDTH(7),
		.COUNTER_MAX(7'b1111111)
	)
	divider(
		.CLK(CLK),
		.RESET(1'b0),
		.ENABLE_IN(1'b1),
		.TRIG_OUT(clk12k)
	);
	
	SquareSynth synth(
		.HALF_PERIOD(15'd391),
		.ENABLE(1'b1),
		.CLK(clk391k),
		.AUDIO(AUDIO)
	);
endmodule
