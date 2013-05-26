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
module GamePhysics(
   input CLK,
   input RESET,
   input START_UPDATE,
   input BTN_LEFT,
   input BTN_RIGHT,
   input BTN_RELEASE,
   output [9:0] PADDLE_X_PIXEL,
   output [9:0] BALL_X_PIXEL,
   output [9:0] BALL_Y_PIXEL,
   output [71:0] BLOCK_STATE,
   output reg BALL_LOST
   );

   `include "game-geometry.v"

   // State of the destroyable blocks, 1 for present. The 73th bit is just a
   // dummy value that is always 0, and used to unify handling of all the
   // edge cases in address calculation.
   reg [72:0] blockState;

   // Number of timesteps already done this frame.
   reg [3:0] timestepCount;

   // Physics simulation works in three phases.
   parameter PhysPhase_extrapolate = 2'd0;
   parameter PhysPhase_computePartnerBlocks = 2'd1;
   parameter PhysPhase_collide = 2'd2;
   parameter PhysPhase_update = 2'd3;
   reg [1:0] physPhase;

   // Ball state.
   parameter Ball_waitForRelease = 2'h0;
   parameter Ball_inGame = 2'h1;
   parameter Ball_lost = 3'h2;
   reg [1:0] ballState;
   reg [15:0] ballX;
   reg [15:0] ballY;
   reg [15:0] ballVelocityX;
   reg [15:0] ballVelocityY;

   // Paddle state.
   reg [15:0] paddleX;
   reg [15:0] newPaddleX;

   // Ball collision detection helpers.
   wire ballGoesLeft = ballVelocityX[15];
   wire ballGoesUp = ballVelocityY[15];

   wire [6:0] ballXTile = ballX[15:9];
   wire [6:0] ballYTile = ballY[15:9];
   wire ballAtTileX = ballX[8:6] == 3'd0;
   wire ballAtTileY = ballY[8:6] == 3'd0;

   reg [6:0] cXTile;
   wire [6:0] cXBlockOffset = cXTile - blockStartXTile;
   wire [3:0] cXBlock = cXBlockOffset[6:3];
   wire isLeftBlock = cXBlock == 4'd0;
   wire isRightBlock = cXBlock == blockColCount;

   reg [6:0] cYTile;
   wire [6:0] cYBlockOffset = (cYTile - blockStartYTile);
   wire [2:0] cYBlock = cYBlockOffset[3:1];
   wire isTopBlock = cYBlock == 3'd0;
   wire isBottomBlock = cYBlock == blockRowCount;

   wire cInBlockArea = cYBlockOffset[6:1] < blockRowCount ||
      (ballGoesUp && cYBlockOffset[6:1] == blockRowCount);
   reg canHitBlockX;
   reg canHitBlockY;

   reg [6:0] adjXBlock;
   reg [6:0] adjYBlock;
   reg [6:0] adjDiagBlock;
   parameter invalidBlock = 7'd72;

   wire hitBlockX = cInBlockArea && canHitBlockX && blockState[adjXBlock];
   wire hitBlockY = cInBlockArea && canHitBlockY && blockState[adjYBlock];
   wire hitBlockDiag = cInBlockArea && canHitBlockX && canHitBlockY && blockState[adjDiagBlock];
   wire hitLeftWall = ballAtTileX && ballGoesLeft && cXTile == (leftWallXTile + 1);
   wire hitRightWall = ballAtTileX && !ballGoesLeft && cXTile == rightWallXTile;
   wire hitCeiling = ballAtTileY && ballGoesUp && cYTile == (ceilingYTile + 1);
   wire hitPaddle = ballAtTileY && !ballGoesUp && cYTile == paddleYTile &&
      (PADDLE_X_PIXEL - ballSizePixel < ballX[15:6]) &&
      (ballX[15:6] < PADDLE_X_PIXEL + paddleLengthPixel);

   // The ball is lost if it completely left the screen at the bottom.
   wire ballLost = cYTile == (paddleYTile + 7'd3);

   always @(posedge CLK) begin
      if (RESET) begin
         blockState <= 73'b0111111111111111111111111111111111111111111111111111111111111111111111111;
         timestepCount <= 4'd0;
         physPhase <= PhysPhase_extrapolate;
         ballState <= Ball_waitForRelease;
         ballX <= {10'd395, 6'h0};
         ballY <= {10'd400, 6'h0};
         ballVelocityX <= 16'h0;
         ballVelocityY <= 16'h0;
         paddleX <= {10'd370, 6'd0};
         BALL_LOST <= 1'b0;
      end else case (physPhase)
         PhysPhase_extrapolate: begin
            newPaddleX <= paddleX -
               BTN_LEFT * paddleSpeedSubpixel +
               BTN_RIGHT * paddleSpeedSubpixel;

            if (ballGoesLeft) begin
               cXTile <= ballXTile;
               canHitBlockX <= ballAtTileX &&
                  ballXTile[2:0] == blockStartXTile[2:0];
            end else begin
               cXTile <= ballXTile + 7'd1;
               canHitBlockX <= ballAtTileX &&
                  ballXTile[2:0] == (blockStartXTile[2:0] - 3'd1);
            end

            if (ballGoesUp) begin
               cYTile <= ballYTile;
               canHitBlockY <= ballAtTileY &&
                  (ballYTile[0] == blockStartYTile[0]);
            end else begin
               cYTile <= ballYTile + 6'd1;
               canHitBlockY <= ballAtTileY &&
                  (ballYTile[0] != blockStartYTile[0]);
            end

            // Advance phase.
            if (timestepCount == 4'd11) begin
               if (START_UPDATE) begin
                  timestepCount <= 4'd0;
                  physPhase <= PhysPhase_computePartnerBlocks;
               end else begin
                  physPhase <= PhysPhase_extrapolate;
               end
            end else begin
               timestepCount <= timestepCount + 4'd1;
               physPhase <= PhysPhase_computePartnerBlocks;
            end
         end

         PhysPhase_computePartnerBlocks: begin
            if (ballGoesUp) begin
               if (isTopBlock) begin
                  adjYBlock <= invalidBlock;
                  adjDiagBlock <= invalidBlock;
               end else begin
                  adjYBlock <= (cYBlock - 1) * blockColCount + cXBlock;
                  if (ballGoesLeft) begin
                     if (isLeftBlock) begin
                        adjDiagBlock <= invalidBlock;
                     end else begin
                        adjDiagBlock <= (cYBlock - 1) * blockColCount + cXBlock - 1;
                     end
                  end else begin
                     if (isRightBlock) begin
                        adjDiagBlock <= invalidBlock;
                     end else begin
                        adjDiagBlock <= (cYBlock - 1) * blockColCount + cXBlock;
                     end
                  end
               end
            end else begin
               if (isBottomBlock) begin
                  adjYBlock <= invalidBlock;
                  adjDiagBlock <= invalidBlock;
               end else begin
                  adjYBlock <= cYBlock * blockColCount + cXBlock;
                  if (ballGoesLeft) begin
                     if (isLeftBlock) begin
                        adjDiagBlock <= invalidBlock;
                     end else begin
                        adjDiagBlock <= cYBlock * blockColCount + cXBlock - 1;
                     end
                  end else begin
                     if (isRightBlock) begin
                        adjDiagBlock <= invalidBlock;
                     end else begin
                        adjDiagBlock <= cYBlock * blockColCount + cXBlock;
                     end
                  end
               end
            end

            if (ballGoesLeft) begin
               if (isLeftBlock) begin
                  adjXBlock <= invalidBlock;
               end else begin
                  adjXBlock <= cYBlock * blockColCount + cXBlock - 1;
               end
            end else begin
               if (isRightBlock) begin
                  adjXBlock <= invalidBlock;
               end else begin
                  adjXBlock <= cYBlock * blockColCount + cXBlock;
               end
            end

            // Advance phase.
            physPhase <= PhysPhase_collide;
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

            if (hitLeftWall || hitRightWall || hitBlockX || (hitBlockDiag && !hitBlockY)) begin
               ballVelocityX <= -ballVelocityX;
            end

            if (hitCeiling || hitPaddle || hitBlockY || (hitBlockDiag && !hitBlockX)) begin
               ballVelocityY <= -ballVelocityY;
            end

            if (hitBlockX) begin
               blockState[adjXBlock] <= 1'b0;
            end

            if (hitBlockY) begin
               blockState[adjYBlock] <= 1'b0;
            end

            if (hitBlockDiag && !hitBlockX && !hitBlockY) begin
               blockState[adjDiagBlock] <= 1'b0;
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
                     ballVelocityX <= {10'd0, 6'd4};
                     ballVelocityY <= -{10'd0, 6'd8};
                  end
                  ballX <= {PADDLE_X_PIXEL + ((paddleLengthPixel - ballSizePixel) / 2), 6'd0};
                  ballY <= {(paddleYPixel - ballSizePixel), 6'd0};
               end
               Ball_inGame: begin
                  ballX <= ballX + ballVelocityX;
                  ballY <= ballY + ballVelocityY;

                  if (ballLost) begin
                     ballState <= Ball_lost;
                     BALL_LOST <= 1'b1;
                  end
               end
               Ball_lost: begin
                  // Do nothing, wait for reset.
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
   assign BLOCK_STATE = blockState[71:0];
endmodule
