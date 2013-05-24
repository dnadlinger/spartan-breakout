`timescale 1ns / 1ps

/// The main game logic updating the game state once per frame.
module GameLogic(
   input CLK,
   input START_UPDATE,
   output reg [9:0] PADDLE_X_PIXEL
   );

   parameter PADDLE_LENGTH_PIXEL = 10'd60;

   always @(posedge CLK) begin
      PADDLE_X_PIXEL <= 10'd370;
   end
endmodule
