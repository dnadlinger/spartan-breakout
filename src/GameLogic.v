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
   output [9:0] PADDLE_X_PIXEL,
   output [9:0] BALL_X_PIXEL,
   output [9:0] BALL_Y_PIXEL,
   output reg [71:0] BLOCK_STATE
   );

   `include "game-geometry.v"

   initial begin
      BLOCK_STATE <= 72'b111111111111010101010101101010101010010101010101101010101010111111111111;
   end

   // Physics simulation works in three phases:
   parameter PhysPhase_extrapolate = 2'd0;
   parameter PhysPhase_collide = 2'd1;
   parameter PhysPhase_update = 2'd2;
   reg [1:0] physPhase = PhysPhase_extrapolate;

   // Number of timesteps already done this frame.
   reg [3:0] timestepCount = 4'd0;

   parameter Ball_waitForRelease = 2'h0;
   parameter Ball_inGame = 2'h1;
   parameter Ball_lost = 3'h2;
   reg [1:0] ballState = Ball_waitForRelease;
   reg [15:0] ballX = {10'd395, 6'h0};
   reg [15:0] ballY = {10'd400, 6'h0};
   reg [15:0] ballVelocityX = 16'h0;
   reg [15:0] ballVelocityY = 16'h0;
   reg [15:0] paddleX = {10'd370, 6'd0};

   reg [15:0] newBallX;
   wire [6:0] newBallXTile = newBallX[15:9];
   wire ballAtTileX = newBallX[8:6] == 3'd0;

   reg [15:0] newBallY;
   wire [6:0] newBallYTile = newBallY[15:9];
   wire ballAtTileY = newBallY[8:6] == 3'd0;

   reg [15:0] newPaddleX;

   wire bounceLeft = newBallXTile == leftWallXTile;
   wire bounceRight = newBallXTile == rightWallXTile - 7'd1;
   wire bounceTop = newBallYTile == ceilingYTile + 7'd1;
   wire bounceBottom = (newBallYTile == paddleYTile - 1) &&
      (PADDLE_X_PIXEL - ballSizePixel < newBallX[15:6]) &&
      (newBallX[15:6] < PADDLE_X_PIXEL + paddleLengthPixel);

   always @(posedge CLK) begin
      case (physPhase)
         PhysPhase_extrapolate: begin
            newBallX <= ballX + ballVelocityX;
            newBallY <= ballY + ballVelocityY;

            newPaddleX <= paddleX -
               BTN_LEFT * paddleSpeedSubpixel +
               BTN_RIGHT * paddleSpeedSubpixel;

            // Advance phase.
            if (timestepCount == 4'd11) begin
               if (START_UPDATE) begin
                  timestepCount <= 4'd0;
                  physPhase <= PhysPhase_collide;
               end else begin
                  physPhase <= PhysPhase_extrapolate;
               end
            end else begin
               timestepCount <= timestepCount + 4'd1;
               physPhase <= PhysPhase_collide;
            end
         end
         PhysPhase_collide: begin
            if (newPaddleX[15:6] == gameBeginXPixel - 1) begin
               newPaddleX <= {gameBeginXPixel, 6'd0};
               // SOUND: Hit wall.
            end

            if (newPaddleX[15:6] == gameEndXPixel - paddleLengthPixel + 1) begin
               newPaddleX <= {gameEndXPixel - paddleLengthPixel, 6'd0};
               // SOUND: Hit wall.
            end

            if (ballAtTileX && (bounceLeft || bounceRight)) begin
               ballVelocityX <= -ballVelocityX;
            end

            if (ballAtTileY && (bounceTop || bounceBottom)) begin
               ballVelocityY <= -ballVelocityY;
            end

            // Advance phase.
            physPhase <= PhysPhase_update;
         end
         PhysPhase_update: begin
            paddleX <= newPaddleX;

            case (ballState)
               Ball_waitForRelease: begin
                  if (BTN_RELEASE) begin
                     ballState <= Ball_inGame;
                     // TODO: Generate velocity based on frame counter.
                     ballVelocityX <= {10'd0, 6'd2};
                     ballVelocityY <= -{10'd0, 6'd8};
                  end
                  ballX <= {PADDLE_X_PIXEL + ((paddleLengthPixel - ballSizePixel) / 2), 6'd0};
                  ballY <= {(paddleYPixel - ballSizePixel), 6'd0};
               end
               Ball_inGame: begin
                  ballX <= ballX + ballVelocityX;
                  ballY <= ballY + ballVelocityY;
               end
               default: begin // Unused.
                  ballX <= {10'd395, 6'd0};
                  ballY <= {10'd400, 6'd0};
               end
            endcase

            // Advance phase.
            physPhase <= PhysPhase_extrapolate;
         end
      endcase
   end

   assign BALL_X_PIXEL = ballX[15:6];
   assign BALL_Y_PIXEL = ballY[15:6];
   assign PADDLE_X_PIXEL = paddleX[15:6];
endmodule
