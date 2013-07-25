`timescale 1ns / 1ps

module BitmapROM(CLK, ADDR, DATA);
   `include "bitmaps.v"
   input CLK;
   input [bitmapAddrBits - 1:0] ADDR;
   output reg [9:0] DATA;

   reg [9:0] bitmapData [0:bitmapDataWords - 1];
   initial $readmemb("src/bitmaps.dat", bitmapData, 0, bitmapDataWords - 1);

   always @(posedge CLK) begin
      DATA <= bitmapData[ADDR];
   end
endmodule
