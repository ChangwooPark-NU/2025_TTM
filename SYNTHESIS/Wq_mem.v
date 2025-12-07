module Wq_mem (
            SLP,
            SD,
            CLK, CEB, WEB,
            CEBM, WEBM,
            A, D,
            BWEB,
            AM, DM, 
            BWEBM,
            BIST,
            RTSEL,
            WTSEL,
            Q);

parameter numWord = 1024;
parameter numRow = 256;
parameter numCM = 4;
parameter numIOBit = 128;
parameter numBit = 128;
parameter numWordAddr = 10;
parameter numRowAddr = 8;
parameter numCMAddr = 2;
parameter numRowRedSize = 0;
parameter numColRedSize = 0;
parameter numSRSize = numRowRedSize + numColRedSize;
parameter numRR = 2;
parameter numCR = 1;
parameter numDC = 0;
parameter numStuckAt = 20;

//=== IO Ports ===//

// Mode Control
input BIST;
// Normal Mode Input
input SLP;
input SD;
input CLK;
input CEB;
input WEB;
input [9:0] A;
input [127:0] D;
input [127:0] BWEB;

// BIST Mode Input
input CEBM;
input WEBM;
input [9:0] AM;
input [127:0] DM;
input [127:0] BWEBM;

// Data Output
output [127:0] Q;


// Test Mode
input [1:0] RTSEL;
input [1:0] WTSEL;

endmodule 

