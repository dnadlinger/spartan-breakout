`timescale 1ns / 1ps

/// The main game logic updating the game state once per frame.
///
/// To be able to use a simple collision detection approach, the logic
/// internally runs in three steps, i.e. effectively at 180 Hz.
///
/// The ball position is internally handled with 3 bits of extra subpixel
/// position to be able to handle lower velocities smoothly.
module GameLogic(
   input CLK,
   input START_UPDATE,
   input BTN_LEFT,
   input BTN_RIGHT,
   input BTN_RELEASE,
   output reg [9:0] PADDLE_X_PIXEL,
   output [9:0] BALL_X_PIXEL,
   output [9:0] BALL_Y_PIXEL
   );

   parameter PADDLE_LENGTH_PIXEL = 10'd60;

   initial begin
      PADDLE_X_PIXEL <= 10'd370;
   end

   parameter paddleSpeed = 10'd1;
   parameter gameBeginXPixel = 10'd8;
   parameter gameEndXPixel = 10'd792;
   parameter paddleYPixel = 10'd584;
   parameter ballSizePixel = 10'd8;

   // After we got the okay, run the update logic for three clock cycles.
   reg doUpdate = 1'b0;
   reg [1:0] updateCounter = 2'h0;

   always @(posedge CLK) begin
      if (doUpdate) begin
         if (updateCounter == 2'h2) begin
            doUpdate <= 1'b0;
            updateCounter <= 2'h0;
         end else begin
            updateCounter <= updateCounter + 2'h1;
         end
      end else if (START_UPDATE) begin
         doUpdate <= 1'b1;
      end
   end

   // Handle button input.
   always @(posedge CLK) begin
      if (doUpdate) begin
         if (!(BTN_LEFT && BTN_RIGHT)) begin
            if (BTN_LEFT) begin
               if (PADDLE_X_PIXEL < gameBeginXPixel + paddleSpeed) begin
                  PADDLE_X_PIXEL <= gameBeginXPixel;
               end else begin
                  PADDLE_X_PIXEL <= PADDLE_X_PIXEL - paddleSpeed;
               end
            end

            if (BTN_RIGHT) begin
               if (PADDLE_X_PIXEL > gameEndXPixel - PADDLE_LENGTH_PIXEL - paddleSpeed) begin
                  PADDLE_X_PIXEL <= gameEndXPixel - PADDLE_LENGTH_PIXEL;
               end else begin
                  PADDLE_X_PIXEL <= PADDLE_X_PIXEL + paddleSpeed;
               end
            end
         end
      end
   end

   // Handle ball motion.
   parameter Ball_waitForRelease = 2'h0;
   parameter Ball_inGame = 2'h1;
   parameter Ball_lost = 3'h2;
   reg [1:0] ballState = Ball_waitForRelease;
   reg [12:0] ballXSubpixel = {10'd395, 3'h0};
   reg [12:0] ballYSubpixel = {10'd400, 3'h0};
   reg [12:0] ballVelocityXSubpixel = 12'h0;
   reg [12:0] ballVelocityYSubpixel = 12'h0;

   always @(posedge CLK) begin
      if (doUpdate) begin
         case (ballState)
            Ball_waitForRelease: begin
               if (BTN_RELEASE) begin
                  ballState <= Ball_inGame;
                  // TODO: Generate velocity based on frame counter.
                  ballVelocityXSubpixel <= {9'd0, 3'd1};
                  ballVelocityYSubpixel <= -{9'd1, 3'd0};
               end
               ballXSubpixel <= {PADDLE_X_PIXEL + ((PADDLE_LENGTH_PIXEL - ballSizePixel) / 2), 3'd0};
               ballYSubpixel <= {(paddleYPixel - ballSizePixel), 3'd0};
            end
            Ball_inGame: begin
               ballXSubpixel <= ballXSubpixel + ballVelocityXSubpixel;
               ballYSubpixel <= ballYSubpixel + ballVelocityYSubpixel;
            end
            default: begin
               ballXSubpixel <= {10'd395, 3'd0};
               ballYSubpixel <= {10'd400, 3'd0};
            end
         endcase
      end
   end

   assign BALL_X_PIXEL = ballXSubpixel[12:3];
   assign BALL_Y_PIXEL = ballYSubpixel[12:3];
endmodule
