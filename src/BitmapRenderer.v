`timescale 1ns / 1ps

module BitmapRenderer(CLK, RESET, INIT_ADDR, CURR_X_PIXEL, CURR_Y_PIXEL, COLOR);
   `include "bitmaps.v"
   input CLK;
   input RESET;
   input [bitmapAddrBits - 1:0] INIT_ADDR;
   input [9:0] CURR_X_PIXEL;
   input [9:0] CURR_Y_PIXEL;
   output [7:0] COLOR;

   parameter RenderPhase_beginRead = 4'd0;
   parameter RenderPhase_loadStartX = 4'd1;
   parameter RenderPhase_loadStartY = 4'd2;
   parameter RenderPhase_loadColCount = 4'd3;
   parameter RenderPhase_loadRowCount = 4'd4;
   parameter RenderPhase_loadSizeBlink = 4'd5;
   parameter RenderPhase_loadFirstData = 4'd6;
   parameter RenderPhase_render = 4'd7;
   parameter RenderPhase_waitForReset = 4'd8;
   reg [3:0] phase;

   reg [bitmapAddrBits - 1:0] romAddr;
   reg [4:0] dataBit;
   wire [9:0] romData;

   BitmapROM bitmapROM(
      .CLK(CLK),
      .ADDR(romAddr),
      .DATA(romData)
   );

   reg waitForXStart;
   reg waitForYStart;
   reg [9:0] startX;
   reg [9:0] startY;
   reg [9:0] colCount;
   reg [9:0] rowCount;
   reg [3:0] blockSize;
   reg blink;

   reg [9:0] xBlock;
   reg [9:0] yBlock;
   reg [3:0] blockOffsetX;
   reg [3:0] blockOffsetY;
   reg [bitmapAddrBits - 1:0] rowStartRomAddr;
   reg [4:0] rowStartDataBit;

   assign COLOR = (!waitForXStart && !waitForYStart &&
      phase == RenderPhase_render && romData[dataBit]) * 8'b11111111;

   always @(posedge CLK) begin
      if (RESET) begin
         romAddr <= Bitmap_gameIntro;
         dataBit <= 9;
         phase <= RenderPhase_beginRead;
      end else begin
         case (phase)
            RenderPhase_beginRead: begin
               romAddr <= romAddr + 1;
               phase <= RenderPhase_loadStartX;
            end
            RenderPhase_loadStartX: begin
               startX <= romData;
               romAddr <= romAddr + 1;
               phase <= RenderPhase_loadStartY;
            end
            RenderPhase_loadStartY: begin
               startY <= romData;
               romAddr <= romAddr + 1;
               phase <= RenderPhase_loadColCount;
            end
            RenderPhase_loadColCount: begin
               colCount <= romData;
               romAddr <= romAddr + 1;
               phase <= RenderPhase_loadRowCount;
            end
            RenderPhase_loadRowCount: begin
               rowCount <= romData;
               romAddr <= romAddr + 1;
               phase <= RenderPhase_loadSizeBlink;
            end
            RenderPhase_loadSizeBlink: begin
               blockSize <= romData[9:6];
               blink <= romData[5];
               // Do not increment address, the pixel data will start to arrive
               // in the next clock cycle.

               waitForXStart <= 1'b1;
               waitForYStart <= 1'b1;
               xBlock <= 10'd0;
               yBlock <= 10'd0;
               blockOffsetX <= 4'd0;
               blockOffsetY <= 4'd0;
               phase <= RenderPhase_render;
            end
            RenderPhase_render: begin
               if (!waitForXStart && !waitForYStart) begin
                  if (blockOffsetX == blockSize - 1) begin
                     blockOffsetX <= 0;
                     if (xBlock == colCount - 1) begin
                        xBlock <= 0;
                        if (blockOffsetY == blockSize - 1) begin
                           blockOffsetY <= 0;

                           yBlock <= yBlock + 1;
                           if (dataBit == 0) begin
                              dataBit <= 9;
                           end else begin
                              dataBit <= dataBit - 1;
                           end
                        end else begin
                           blockOffsetY <= blockOffsetY + 1;

                           romAddr <= rowStartRomAddr;
                           dataBit <= rowStartDataBit;
                        end
                        waitForXStart <= 1'b1;
                     end else begin
                        if (dataBit == 0) begin
                           dataBit <= 9;
                        end else begin
                           dataBit <= dataBit - 1;
                        end

                        xBlock <= xBlock + 1;

                        if (blockSize == 1 && dataBit == 1) begin
                           romAddr <= romAddr + 1;
                        end
                     end
                  end else begin
                     blockOffsetX <= blockOffsetX + 1;

                     if (blockSize != 1 && blockOffsetX == blockSize - 2 && dataBit == 0) begin
                        romAddr <= romAddr + 1;
                     end
                  end
               end

               if (!waitForYStart && waitForXStart) begin
                  if (yBlock == rowCount) begin
                     if (romAddr == bitmapDataWords - 1) begin
                        phase <= RenderPhase_waitForReset;
                     end else begin
                        romAddr <= romAddr + 1;
                        dataBit <= 9;
                        phase <= RenderPhase_beginRead;
                     end
                  end else if (CURR_X_PIXEL == startX - 1) begin
                     waitForXStart <= 1'b0;
                     rowStartRomAddr <= romAddr;
                     rowStartDataBit <= dataBit;

                     // Need to prefetch if address will change on second
                     // pixel in row.
                     if (blockSize == 1 && dataBit == 0) begin
                        romAddr <= romAddr + 1;
                     end
                  end
               end

               if (waitForYStart) begin
                  if (CURR_Y_PIXEL == startY) begin
                     waitForYStart <= 1'b0;
                  end
               end
            end
            default: begin
               // Do nothing.
               phase <= RenderPhase_waitForReset;
            end
         endcase
      end
   end

endmodule
