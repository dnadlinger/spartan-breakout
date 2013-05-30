// Parameter definitions for the geometry of the various in-game objects.
// Pre-processor constants might be more appropriate.

// Game area housing.
parameter ceilingYTile = 7'd9;
parameter leftWallXTile = 7'd1;
parameter rightWallXTile = 7'd98;
parameter gameBeginXPixel = 10'd16;
parameter gameEndXPixel = 10'd784;

// Blocks.
parameter blockStartXTile = 7'd2;
parameter blockStartYTile = 7'd17;
parameter blockRowCount = 3'd6;
parameter blockColCount = 4'd12;

// Player paddle.
parameter paddleLengthPixel = 10'd60;
parameter paddleYTile = 7'd73;
parameter paddleYPixel = paddleYTile * 10'd8;
parameter paddleSpeedSubpixel = {10'd0, 6'd15};

// Ball.
parameter ballSizePixel = 10'd8;
