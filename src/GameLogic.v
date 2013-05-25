`timescale 1ns / 1ps

/// The main game logic updating the game state once per frame.
///
/// To be able to use a simple collision detection approach, the logic
/// internally runs in 12 steps, i.e. effectively at 720 Hz.
///
/// All positions and velocities are internally handled in units of pixels with
/// 6 bits of extra subpixel precision (unless noted otherwise).
///
/// All position reference points (as well as the coordinate origin itself) are
/// in the top left corner of the respective object.
module GameLogic(
   input CLK,
   input START_UPDATE,
   input BTN_LEFT,
   input BTN_RIGHT,
   input BTN_RELEASE,
   output reg [9:0] PADDLE_X_PIXEL,
   output [9:0] BALL_X_PIXEL,
   output [9:0] BALL_Y_PIXEL,
   output reg [71:0] BLOCK_STATE
   );

   `include "game-geometry.v"

   initial begin
      PADDLE_X_PIXEL <= 10'd370;
      BLOCK_STATE <= 72'b111111111111010101010101101010101010010101010101101010101010111111111111;
   end

   // After we got the okay, run the update logic for 12 clock cycles.
   reg doUpdate = 1'b0;
   reg [3:0] updateCounter = 4'd0;

   always @(posedge CLK) begin
      if (doUpdate) begin
         if (updateCounter == 4'd11) begin
            doUpdate <= 1'b0;
            updateCounter <= 4'd0;
         end else begin
            updateCounter <= updateCounter + 4'd1;
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
               if (PADDLE_X_PIXEL > gameEndXPixel - paddleLengthPixel - paddleSpeed) begin
                  PADDLE_X_PIXEL <= gameEndXPixel - paddleLengthPixel;
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
   reg [15:0] ballXSubpixel = {10'd395, 6'h0};
   reg [15:0] ballYSubpixel = {10'd400, 6'h0};
   reg [15:0] ballVelocityXSubpixel = 15'h0;
   reg [15:0] ballVelocityYSubpixel = 15'h0;

   wire [15:0] tentativeBallXSubpixel = ballXSubpixel + ballVelocityXSubpixel;
   wire [9:0] tentativeBallXPixel = tentativeBallXSubpixel[15:6];
   wire [6:0] tentativeBallXTile = tentativeBallXSubpixel[15:9];
   wire [15:0] tentativeBallYSubpixel = ballYSubpixel + ballVelocityYSubpixel;
   wire [6:0] tentativeBallYTile = tentativeBallYSubpixel[15:9];
   wire bounceLeft = tentativeBallXTile == leftWallXTile;
   wire bounceRight = tentativeBallXTile == rightWallXTile - 7'd1;
   wire bounceTop = tentativeBallYTile == ceilingYTile;
   wire bounceBottom = (tentativeBallYTile == paddleYTile) &&
      (PADDLE_X_PIXEL - ballSizePixel < tentativeBallXPixel) &&
      (tentativeBallXPixel < PADDLE_X_PIXEL + paddleLengthPixel);

   always @(posedge CLK) begin
      if (doUpdate) begin
         case (ballState)
            Ball_waitForRelease: begin
               if (BTN_RELEASE) begin
                  ballState <= Ball_inGame;
                  // TODO: Generate velocity based on frame counter.
                  ballVelocityXSubpixel <= {10'd0, 6'd1};
                  ballVelocityYSubpixel <= -{10'd0, 6'd4};
               end
               ballXSubpixel <= {PADDLE_X_PIXEL + ((paddleLengthPixel - ballSizePixel) / 2), 6'd0};
               ballYSubpixel <= {(paddleYPixel - ballSizePixel), 6'd0};
            end
            Ball_inGame: begin
               if (!(bounceLeft && bounceRight)) begin
                  if (bounceLeft || bounceRight) begin
                     ballVelocityXSubpixel <= -ballVelocityXSubpixel;
                     ballXSubpixel <= ballXSubpixel - ballVelocityXSubpixel;
                  end else begin
                     ballXSubpixel <= ballXSubpixel + ballVelocityXSubpixel;
                  end
               end
               if (!(bounceTop && bounceBottom)) begin
                  if (bounceTop || bounceBottom) begin
                     ballVelocityYSubpixel <= -ballVelocityYSubpixel;
                     ballYSubpixel <= ballYSubpixel - ballVelocityYSubpixel;
                  end else begin
                     ballYSubpixel <= ballYSubpixel + ballVelocityYSubpixel;
                  end
               end
            end
            default: begin
               ballXSubpixel <= {10'd395, 3'd0};
               ballYSubpixel <= {10'd400, 3'd0};
            end
         endcase
      end
   end

   assign BALL_X_PIXEL = ballXSubpixel[15:6];
   assign BALL_Y_PIXEL = ballYSubpixel[15:6];
endmodule
