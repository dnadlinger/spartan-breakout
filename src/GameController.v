`timescale 1ns / 1ps

module GameController(CLK, RESET, FRAME_RENDERED, BTN_LEFT, BTN_RIGHT,
   BTN_RELEASE, SW_PAUSE, SW_IGNORE_DEATH, AUDIO_SELECT, AUDIO_TRIGGER,
   PADDLE_X_PIXEL, BALL_X_PIXEL, BALL_Y_PIXEL, BLOCK_ADDR, BLOCK_ALIVE,
   LIVES, SCORE_1000, SCORE_100, SCORE_10, SCORE_1);

   `include "audio-samples.v"
   `include "game-geometry.v"

   input CLK;
   input RESET;
   input FRAME_RENDERED;
   input BTN_LEFT;
   input BTN_RIGHT;
   input BTN_RELEASE;
   input SW_PAUSE;
   input SW_IGNORE_DEATH;
   output reg [sampleBits - 1:0] AUDIO_SELECT;
   output reg AUDIO_TRIGGER;
   output [9:0] PADDLE_X_PIXEL;
   output [9:0] BALL_X_PIXEL;
   output [9:0] BALL_Y_PIXEL;
   input [6:0] BLOCK_ADDR;
   output BLOCK_ALIVE;
   output reg [2:0] LIVES;
   output [3:0] SCORE_1000;
   output [3:0] SCORE_100;
   output [3:0] SCORE_10;
   output [3:0] SCORE_1;

   wire stepComplete;
   wire hitWall;
   wire hitPaddle;
   wire hitBlock;
   wire [2:0] hitBlockRow;
   wire ballLost;

   GamePhysics physics(
      .CLK(CLK),
      .RESET(RESET),
      .START_UPDATE(FRAME_RENDERED && !SW_PAUSE),
      .BTN_LEFT(BTN_LEFT),
      .BTN_RIGHT(BTN_RIGHT),
      .BTN_RELEASE(BTN_RELEASE),
      .SW_IGNORE_DEATH(SW_IGNORE_DEATH),
      .STEP_COMPLETE(stepComplete),
      .HIT_WALL(hitWall),
      .HIT_PADDLE(hitPaddle),
      .HIT_BLOCK(hitBlock),
      .HIT_BLOCK_ROW(hitBlockRow),
      .BALL_LOST(ballLost),
      .PADDLE_X_PIXEL(PADDLE_X_PIXEL),
      .BALL_X_PIXEL(BALL_X_PIXEL),
      .BALL_Y_PIXEL(BALL_Y_PIXEL),
      .BLOCK_ADDR(BLOCK_ADDR),
      .BLOCK_ALIVE(BLOCK_ALIVE)
   );

   reg [4:0] pointsToCount = 5'd0;

   always @(posedge CLK) begin
      if (stepComplete) begin
         if (ballLost) begin
            AUDIO_SELECT <= Sample_lostBall;
            AUDIO_TRIGGER <= 1'b1;
         end else if (hitBlock) begin
            AUDIO_SELECT <= Sample_blockStart + hitBlockRow;
            AUDIO_TRIGGER <= 1'b1;
            pointsToCount <= pointsToCount + (blockRowCount - hitBlockRow);
         end else if (hitPaddle) begin
            AUDIO_SELECT <= Sample_paddle;
            AUDIO_TRIGGER <= 1'b1;
         end else if (hitWall) begin
            AUDIO_SELECT <= Sample_walls;
            AUDIO_TRIGGER <= 1'b1;
         end
      end else begin
         AUDIO_TRIGGER <= 1'b0;
         if (pointsToCount != 5'd0) begin
            pointsToCount <= pointsToCount - 5'd1;
         end
      end
   end

   always @(posedge CLK) begin
      if (RESET) begin
         LIVES <= 3'd5;
      end else begin
         if (stepComplete && ballLost) begin
            LIVES <= LIVES - 3'd1;
         end
      end
   end

   wire score1Trig;
   GenericCounter #(
      .COUNTER_WIDTH(4),
      .COUNTER_MAX(9)
   ) score1Counter (
      .CLK(CLK),
      .RESET(RESET),
      .ENABLE_IN(pointsToCount != 5'd0),
      .TRIG_OUT(score1Trig),
      .COUNT(SCORE_1)
   );

   wire score10Trig;
   GenericCounter #(
      .COUNTER_WIDTH(4),
      .COUNTER_MAX(9)
   ) score10Counter (
      .CLK(CLK),
      .RESET(RESET),
      .ENABLE_IN(score1Trig),
      .TRIG_OUT(score10Trig),
      .COUNT(SCORE_10)
   );

   wire score100Trig;
   GenericCounter #(
      .COUNTER_WIDTH(4),
      .COUNTER_MAX(9)
   ) score100Counter (
      .CLK(CLK),
      .RESET(RESET),
      .ENABLE_IN(score10Trig),
      .TRIG_OUT(score100Trig),
      .COUNT(SCORE_100)
   );

   GenericCounter #(
      .COUNTER_WIDTH(4),
      .COUNTER_MAX(9)
   ) score1000Counter (
      .CLK(CLK),
      .RESET(RESET),
      .ENABLE_IN(score100Trig),
      .COUNT(SCORE_1000)
   );
endmodule
