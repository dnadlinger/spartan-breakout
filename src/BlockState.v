`timescale 1ns / 1ps

module BlockState(
   input CLK,
   input [6:0] A_ADDR,
   input A_WRITE_ENABLE,
   input A_IN,
   output reg A_OUT,
   input [6:0] B_ADDR,
   output reg B_OUT
   );

   reg [127:0] mem;

   always @(posedge CLK) begin
      if (A_WRITE_ENABLE)
         mem[A_ADDR] <= A_IN;
      A_OUT <= mem[A_ADDR];
      B_OUT <= mem[B_ADDR];
   end
endmodule
