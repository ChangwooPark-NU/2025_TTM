`timescale 1ns/1ps

module SRAM_TEST( 
input logic clk,
input logic [4:0]INPUT_MEM_ADDR,
input logic INPUT_MEM_WEN,
input logic [127:0]INPUT_MEM_DIN,
output logic [127:0]INPUT_MEM_DOUT,
input logic [9:0]Wq_MEM_ADDR,
input logic Wq_MEM_WEN,
input logic [127:0]Wq_MEM_DIN,
output logic [127:0]Wq_MEM_DOUT

);
input_mem INPUT_MEM(
.SLP(1'b0), .SD(1'b0), .CLK(clk), .CEB(1'b0), .WEB(INPUT_MEM_WEN),
.CEBM(1'b0), .WEBM(1'b0), .A(INPUT_MEM_ADDR), .D(INPUT_MEM_DIN), .BWEB(128'd0),
.AM(5'd0), .DM(128'b0), .BWEBM(128'b0), .BIST(1'b0), .RTSEL(2'b0), .WTSEL(2'b0),
.Q(INPUT_MEM_DOUT)
);

Wq_mem Wq_MEM(
.SLP(1'b0), .SD(1'b0), .CLK(clk), .CEB(1'b0), .WEB(Wq_MEM_WEN),
.CEBM(1'b0), .WEBM(1'b0), .A(Wq_MEM_ADDR), .D(Wq_MEM_DIN), .BWEB(128'd0),
.AM(10'd0), .DM(128'b0), .BWEBM(128'b0), .BIST(1'b0), .RTSEL(2'b0), .WTSEL(2'b0),
.Q(Wq_MEM_DOUT)
);
endmodule