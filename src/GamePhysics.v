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
   input [1:0] LEVEL_SELECT,
   input RESET,
   input START_UPDATE,
   input BTN_LEFT,
   input BTN_RIGHT,
   input BTN_RELEASE,
   input SW_IGNORE_DEATH,
   output reg STEP_COMPLETE,
   output reg HIT_WALL,
   output reg HIT_PADDLE,
   output reg HIT_BLOCK,
   output reg [2:0] HIT_BLOCK_ROW,
   output reg BALL_LOST,
   output reg [6:0] BLOCKS_LEFT,
   output [9:0] PADDLE_X_PIXEL,
   output [9:0] BALL_X_PIXEL,
   output [9:0] BALL_Y_PIXEL,
   input [6:0] BLOCK_ADDR,
   output BLOCK_ALIVE
   );

   `include "game-geometry.v"

   // State of the destroyable blocks, 1 for present. The 73th bit is just a
   // dummy value that is always 0, and used to unify handling of all the
   // edge cases in address calculation.
   reg [6:0] blockStateAddr;
   wire blockStateData;
   reg blockStateWriteEnable = 1'b0;
   reg blockStateWriteData;
   BlockState blockState(
      .CLK(CLK),
      .A_ADDR(blockStateAddr),
      .A_IN(blockStateWriteData),
      .A_WRITE_ENABLE(blockStateWriteEnable),
      .A_OUT(blockStateData),
      .B_ADDR(BLOCK_ADDR),
      .B_OUT(BLOCK_ALIVE)
   );

   // Number of timesteps already done this frame.
   reg [3:0] timestepCount;

   // Physics simulation works in three phases.
   parameter PhysPhase_extrapolate = 4'd0;
   parameter PhysPhase_computePartnerBlocks = 4'd1;
   parameter PhysPhase_beginLoad = 4'd2;
   parameter PhysPhase_loadXBlock = 4'd3;
   parameter PhysPhase_loadYBlock = 4'd4;
   parameter PhysPhase_loadDiagBlock = 4'd5;
   parameter PhysPhase_collide = 4'd6;
   parameter PhysPhase_update = 4'd7;
   parameter PhysPhase_storeYBlock = 4'd8;
   parameter PhysPhase_storeDiagBlock = 4'd9;
   parameter PhysPhase_loadLevelBegin = 4'd10;
   parameter PhysPhase_loadLevel = 4'd11;
   reg [3:0] physPhase;

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

   wire [9:0] ballEndXPixel = ballX[15:6] + ballSizePixel - 1;
   wire [6:0] ballEndXTile = ballEndXPixel[9:3];
   wire [9:0] ballEndYPixel = ballY[15:6] + ballSizePixel - 1;
   wire [6:0] ballEndYTile = ballEndYPixel[9:3];

   reg [6:0] cXTile;
   wire [6:0] cXBlockOffset = cXTile - blockStartXTile;
   wire [3:0] cXBlock = cXBlockOffset[6:3];
   wire isLeftBlock = cXBlock == 4'd0;
   wire isRightBlock = cXBlock == (blockColCount - 4'd1);
   reg [6:0] cAltXTile;
   wire [6:0] cAltXBlockOffset = cAltXTile - blockStartXTile;
   wire [3:0] cAltXBlock = cAltXBlockOffset[6:3];

   reg [6:0] cYTile;
   wire [6:0] cYBlockOffset = cYTile - blockStartYTile;
   wire [2:0] cYBlock = cYBlockOffset[3:1];
   wire isTopBlock = cYBlock == 3'd0;
   wire isBottomBlock = cYBlock == (blockRowCount - 3'd1);
   reg [6:0] cAltYTile;
   wire [6:0] cAltYBlockOffset = cAltYTile - blockStartYTile;
   wire [2:0] cAltYBlock = cAltYBlockOffset[3:1];

   // This needs to properly overflow for the first row to be handled correctly,
   // and there doesn't seem to be a way to achieve that in a single expression.
   wire [2:0] cYBlockPlusOne = cYBlock + 3'd1;

   wire cAboveFirstRow = &cYBlockOffset && !ballGoesUp;
   wire cBeneathLastRow = cYBlockOffset == {blockRowCount, 1'b0} && ballGoesUp;
   wire cInBlockArea = cYBlockOffset[6:1] < blockRowCount || cAboveFirstRow || cBeneathLastRow;

   reg canHitBlockX;
   reg canHitBlockY;
   reg atXBlockBoundary;
   reg atYBlockBoundary;

   reg [6:0] adjXBlock;
   reg adjXBlockAlive;
   reg [6:0] adjYBlock;
   reg adjYBlockAlive;
   reg [6:0] adjDiagBlock;
   reg adjDiagBlockAlive;
   parameter invalidBlock = blockRowCount * blockColCount + 7'd1;

   wire hitXBlock = cInBlockArea && canHitBlockX && adjXBlockAlive;
   wire hitYBlock = cInBlockArea && canHitBlockY && adjYBlockAlive;
   wire hitDiagBlockHoriz = cInBlockArea && canHitBlockX && !hitXBlock && atYBlockBoundary && adjDiagBlockAlive;
   wire hitDiagBlockVert = cInBlockArea && canHitBlockY && !hitYBlock && atXBlockBoundary && adjDiagBlockAlive;
   wire hitDiagBlockDiag = cInBlockArea && canHitBlockX && canHitBlockY && !hitXBlock && !hitYBlock && adjDiagBlockAlive;
   wire hitDiagBlock = hitDiagBlockHoriz || hitDiagBlockVert || hitDiagBlockDiag;
   wire hitLeftWall = ballAtTileX && ballGoesLeft && ballXTile == (leftWallXTile + 1);
   wire hitRightWall = ballAtTileX && !ballGoesLeft && ballXTile == (rightWallXTile - 1);
   wire hitCeiling = ballAtTileY && ballGoesUp && ballYTile == (ceilingYTile + 1);

   wire [9:0] ballPaddleOffset = ballEndXPixel - PADDLE_X_PIXEL;
   wire hitPaddle = ballAtTileY && !ballGoesUp && ballYTile == (paddleYTile - 1) &&
      ballPaddleOffset < (paddleLengthPixel + ballSizePixel - 1);
   wire [15:0] negBallVelocityX = -ballVelocityX;
   wire [15:0] negBallVelocityY = -ballVelocityY;

   // The ball is lost if it completely left the screen at the bottom.
   wire ballLost = cYTile == (paddleYTile + 7'd3) && !SW_IGNORE_DEATH;

   // Level loading.
   reg [6:0] romBlockAddr;
   wire romBlockData;
   LevelROM levelRom(
      .CLK(CLK),
      .ADDR({LEVEL_SELECT[0], romBlockAddr}),
      .OUT(romBlockData)
   );

   always @(posedge CLK) begin
      if (RESET) begin
         timestepCount <= 4'd0;
         ballState <= Ball_waitForRelease;
         ballX <= {10'd395, 6'h0};
         ballY <= {10'd400, 6'h0};
         ballVelocityX <= 16'h0;
         ballVelocityY <= 16'h0;
         paddleX <= {10'd370, 6'd0};
         BALL_LOST <= 1'b0;

         romBlockAddr <= 7'd0;
         BLOCKS_LEFT <= 7'd0;
         physPhase <= PhysPhase_loadLevelBegin;
      end else case (physPhase)
         PhysPhase_extrapolate: begin
            blockStateWriteEnable <= 1'b0;

            newPaddleX <= paddleX -
               BTN_LEFT * paddleSpeedSubpixel +
               BTN_RIGHT * paddleSpeedSubpixel;

            if (ballGoesLeft) begin
               cXTile <= ballEndXTile;
               cAltXTile <= ballXTile;
               canHitBlockX <= ballAtTileX &&
                  ballXTile[2:0] == blockStartXTile[2:0];
            end else begin
               cXTile <= ballXTile;
               cAltXTile <= ballEndXTile;
               canHitBlockX <= ballAtTileX &&
                  ballXTile[2:0] == (blockStartXTile[2:0] - 3'd1);
            end

            if (ballGoesUp) begin
               cYTile <= ballEndYTile;
               cAltYTile <= ballYTile;
               canHitBlockY <= ballAtTileY &&
                  (ballYTile[0] == blockStartYTile[0]);
            end else begin
               cYTile <= ballYTile;
               cAltYTile <= ballEndYTile;
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
                  adjYBlock <= (cYBlock - 3'd1) * blockColCount + cXBlock;
                  if (ballGoesLeft) begin
                     if (isLeftBlock) begin
                        adjDiagBlock <= invalidBlock;
                     end else begin
                        adjDiagBlock <= (cYBlock - 3'd1) * blockColCount + cXBlock - 1;
                     end
                  end else begin
                     if (isRightBlock) begin
                        adjDiagBlock <= invalidBlock;
                     end else begin
                        adjDiagBlock <= (cYBlock - 3'd1) * blockColCount + cXBlock + 1;
                     end
                  end
               end
            end else begin
               if (isBottomBlock) begin
                  adjYBlock <= invalidBlock;
                  adjDiagBlock <= invalidBlock;
               end else begin
                  adjYBlock <= cYBlockPlusOne * blockColCount + cXBlock;
                  if (ballGoesLeft) begin
                     if (isLeftBlock) begin
                        adjDiagBlock <= invalidBlock;
                     end else begin
                        adjDiagBlock <= cYBlockPlusOne * blockColCount + cXBlock - 1;
                     end
                  end else begin
                     if (isRightBlock) begin
                        adjDiagBlock <= invalidBlock;
                     end else begin
                        adjDiagBlock <= cYBlockPlusOne * blockColCount + cXBlock + 1;
                     end
                  end
               end
            end

            // We need to assign the result of our computation to blockStateAddr
            // as well. Unfortunately, I couldn't find a nicer way to do this
            // than just duplicating the assignment.
            if (cAboveFirstRow) begin
               adjXBlock <= invalidBlock;
               blockStateAddr <= invalidBlock;
            end else if (ballGoesLeft) begin
               if (isLeftBlock) begin
                  adjXBlock <= invalidBlock;
                  blockStateAddr <= invalidBlock;
               end else begin
                  adjXBlock <= cYBlock * blockColCount + cXBlock - 1;
                  blockStateAddr <= cYBlock * blockColCount + cXBlock - 1;
               end
            end else begin
               if (isRightBlock) begin
                  adjXBlock <= invalidBlock;
                  blockStateAddr <= invalidBlock;
               end else begin
                  adjXBlock <= cYBlock * blockColCount + cXBlock + 1;
                  blockStateAddr <= cYBlock * blockColCount + cXBlock + 1;
               end
            end

            atXBlockBoundary <= cXBlock != cAltXBlock;
            atYBlockBoundary <= cYBlock != cAltYBlock;

            // Advance phase.
            physPhase <= PhysPhase_beginLoad;
         end

         PhysPhase_beginLoad: begin
            // Advance phase.
            blockStateAddr <= adjYBlock;
            physPhase <= PhysPhase_loadXBlock;
         end

         PhysPhase_loadXBlock: begin
            adjXBlockAlive <= blockStateData;

            // Advance phase.
            blockStateAddr <= adjDiagBlock;
            physPhase <= PhysPhase_loadYBlock;
         end

         PhysPhase_loadYBlock: begin
            adjYBlockAlive <= blockStateData;

            // Advance phase.
            physPhase <= PhysPhase_loadDiagBlock;
         end

         PhysPhase_loadDiagBlock: begin
            adjDiagBlockAlive <= blockStateData;

            // Advance phase.
            physPhase <= PhysPhase_collide;
         end

         PhysPhase_collide: begin
            if (newPaddleX[15:6] == gameBeginXPixel - 1) begin
               newPaddleX <= {gameBeginXPixel, 6'd0};
            end

            if (newPaddleX[15:6] == gameEndXPixel - paddleLengthPixel + 1) begin
               newPaddleX <= {gameEndXPixel - paddleLengthPixel, 6'd0};
            end

            if (hitPaddle) begin
               case (ballPaddleOffset[6:3])
                  4'd0: begin
                     ballVelocityX <= (ballGoesLeft ? ballVelocityX : negBallVelocityX) -
                        {10'd0, 6'd6};
                     ballVelocityY <= -ballVelocityY + {10'd0, 6'd2};
                  end
                  4'd1: begin
                     ballVelocityX <= (ballGoesLeft ? ballVelocityX : negBallVelocityX) -
                        {10'd0, 6'd3};
                     ballVelocityY <= -ballVelocityY + {10'd0, 6'd1};
                  end
                  4'd2: begin
                     if (ballGoesLeft) begin
                        ballVelocityX <= ballVelocityX - {10'd0, 6'd1};
                        ballVelocityY <= -ballVelocityY;
                     end else begin
                        ballVelocityX <= -{1'b0, ballVelocityX[15:1]};
                        ballVelocityY <= -(ballVelocityY + ballVelocityX[15:1]);
                     end
                  end
                  4'd4: begin
                     ballVelocityX <= ballVelocityX +
                        (ballGoesLeft ? {10'd0, 6'd4} : -{10'd0, 6'd4});
                     ballVelocityY <= -(ballVelocityY + {10'd0, 6'd5});
                  end
                  4'd6: begin
                     if (ballGoesLeft) begin
                        ballVelocityX <= {1'b0, negBallVelocityX[15:1]};
                        ballVelocityY <= -(ballVelocityY + negBallVelocityX[15:1]);
                     end else begin
                        ballVelocityX <= ballVelocityX + {10'd0, 6'd1};
                        ballVelocityY <= -ballVelocityY;
                     end
                  end
                  4'd7: begin
                     ballVelocityX <= (ballGoesLeft ? negBallVelocityX : ballVelocityX) +
                        {10'd0, 6'd3};
                     ballVelocityY <= -ballVelocityY + {10'd0, 6'd1};
                  end
                  4'd8: begin
                     ballVelocityX <= (ballGoesLeft ? negBallVelocityX : ballVelocityX) +
                        {10'd0, 6'd6};
                     ballVelocityY <= -ballVelocityY + {10'd0, 6'd2};
                  end
                  default: begin
                     ballVelocityX <= ballVelocityX;
                     ballVelocityY <= -ballVelocityY;
                  end
               endcase
            end else begin
               if (hitLeftWall || hitRightWall || hitXBlock || hitDiagBlockHoriz || hitDiagBlockDiag) begin
                  ballVelocityX <= -ballVelocityX;
               end

               if (hitCeiling || hitYBlock || hitDiagBlockVert || hitDiagBlockDiag) begin
                  ballVelocityY <= -ballVelocityY;
               end
            end

            if (hitXBlock) begin
               adjXBlockAlive <= 1'b0;
               HIT_BLOCK <= 1'b1;
               HIT_BLOCK_ROW <= cYBlock;
            end

            if (hitYBlock) begin
               adjYBlockAlive <= 1'b0;
               HIT_BLOCK <= 1'b1;
               HIT_BLOCK_ROW <= ballGoesUp ? (cYBlock - 3'd1) : cYBlockPlusOne;
            end

            if (hitDiagBlock) begin
               adjDiagBlockAlive <= 1'b0;
               HIT_BLOCK <= 1'b1;
               HIT_BLOCK_ROW <= ballGoesUp ? (cYBlock - 3'd1) : cYBlockPlusOne;
            end

            HIT_WALL <= hitLeftWall || hitRightWall || hitCeiling;
            HIT_PADDLE <= hitPaddle && (ballState != Ball_waitForRelease);

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
                     ballVelocityX <= {10'd0, 6'd6};
                     ballVelocityY <= -{10'd0, 6'd16};
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
                  paddleX <= {10'd370, 6'd0};
                  ballState <= Ball_waitForRelease;
               end
            endcase

            BLOCKS_LEFT <= BLOCKS_LEFT - hitXBlock - hitYBlock - hitDiagBlock;

            STEP_COMPLETE <= 1'b1;

            blockStateAddr <= adjXBlock;
            blockStateWriteData <= adjXBlockAlive;
            blockStateWriteEnable <= 1'b1;

            // Advance phase.
            physPhase <= PhysPhase_storeYBlock;
         end

         PhysPhase_storeYBlock: begin
            HIT_WALL <= 1'b0;
            HIT_PADDLE <= 1'b0;
            HIT_BLOCK <= 1'b0;
            STEP_COMPLETE <= 1'b0;
            BALL_LOST <= 1'b0;

            blockStateAddr <= adjYBlock;
            blockStateWriteData <= adjYBlockAlive;

            // Advance phase.
            physPhase <= PhysPhase_storeDiagBlock;
         end

         PhysPhase_storeDiagBlock: begin
            blockStateAddr <= adjDiagBlock;
            blockStateWriteData <= adjDiagBlockAlive;

            // Advance phase.
            physPhase <= PhysPhase_extrapolate;
         end

         PhysPhase_loadLevelBegin: begin
            romBlockAddr <= 7'd1;

            // Advance phase.
            physPhase <= PhysPhase_loadLevel;
         end

         PhysPhase_loadLevel: begin
            blockStateAddr <= romBlockAddr - 7'd1;
            blockStateWriteData <= romBlockData;
            blockStateWriteEnable <= 1'b1;

            if (romBlockData) begin
               BLOCKS_LEFT <= BLOCKS_LEFT + 7'd1;
            end

            romBlockAddr <= romBlockAddr + 7'd1;

            // +1 to be sure to set the dummmy block on the first round.
            if (romBlockAddr == blockRowCount * blockColCount + 1) begin
               physPhase <= PhysPhase_extrapolate;
            end else begin
               // Keep on loading.
               physPhase <= PhysPhase_loadLevel;
            end
         end
      endcase
   end

   assign BALL_X_PIXEL = ballX[15:6];
   assign BALL_Y_PIXEL = ballY[15:6];
   assign PADDLE_X_PIXEL = paddleX[15:6];
endmodule
