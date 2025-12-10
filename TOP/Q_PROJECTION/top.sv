`timescale 1ns/1ps 

module top (
	input logic clk, 
	input logic rst,
       	input logic en, 	
	input logic [4:0] init_input_addr,
  	input logic [9:0] init_w_addr,
  	input logic init_w_wen, 
	input logic init_input_wen, 
 	input logic init, 
	input logic fin, 
	input logic [6:0] fin_output_addr, 
	input logic fin_output_wen, 
        // tb 
	input logic [127:0] INPUT_MEM_DIN, 
	output logic [127:0] OUTPUT_MEM_DIN, 
	input logic [127:0] Wq_MEM_DIN, 
	output logic [511:0] out, 
	output logic valid,
	output logic [127:0] INPUT_MEM_DOUT, 	
	output logic [127:0] OUTPUT_MEM_DOUT,
	output logic [127:0] Wq_MEM_DOUT 
); 
	// Define signals 
        logic INPUT_MEM_WEN;
        logic INPUT_MEM_CEB;
        logic [4:0] INPUT_MEM_ADDR;
        logic Wq_MEM_WEN;
        logic Wq_MEM_CEB;
        logic [9:0] Wq_MEM_ADDR;
        logic OUTPUT_MEM_WEN;
        logic OUTPUT_MEM_CEB;
        logic [6:0] OUTPUT_MEM_ADDR;
	
	// Instantiate DUT 
	Q_Projection dut ( 
		.clk(clk), 
		.rst(rst), 
		.en(en),
		.out(out),
		.valid(valid), 	
		.INPUT_MEM_DOUT(INPUT_MEM_DOUT),
		.INPUT_MEM_WEN(INPUT_MEM_WEN), 
		.INPUT_MEM_CEB(INPUT_MEM_CEB), 
		.INPUT_MEM_ADDR(INPUT_MEM_ADDR),
		.Wq_MEM_DOUT(Wq_MEM_DOUT), 
		.Wq_MEM_WEN(Wq_MEM_WEN), 
		.Wq_MEM_CEB(Wq_MEM_CEB), 
		.Wq_MEM_ADDR(Wq_MEM_ADDR), 
		.OUTPUT_MEM_DOUT(OUTPUT_MEM_DOUT), 
		.OUTPUT_MEM_WEN(OUTPUT_MEM_WEN), 
		.OUTPUT_MEM_CEB(OUTPUT_MEM_CEB), 
		.OUTPUT_MEM_DIN(OUTPUT_MEM_DIN),
		.OUTPUT_MEM_ADDR(OUTPUT_MEM_ADDR)
	); 
	
	// Define input, weight, and output mems 
	input_mem INPUT_MEM (
		.SLP(1'b0), .SD(1'b0), .CLK(clk), .CEB(1'b0 /*init ? 1'b0 : INPUT_MEM_CEB*/), .WEB(init ? init_input_wen : INPUT_MEM_WEN),
		.CEBM(1'b0), .WEBM(1'b0), .A(init ? init_input_addr : INPUT_MEM_ADDR), .D(INPUT_MEM_DIN), .BWEB(128'd0),
		.AM(5'd0), .DM(128'b0), .BWEBM(128'b0), .BIST(1'b0), .RTSEL(2'b0), .WTSEL(2'b0),
		.Q(INPUT_MEM_DOUT)
	);

	Wq_mem Wq_MEM (
		.SLP(1'b0), .SD(1'b0), .CLK(clk), .CEB(1'b0 /*init ? 1'b0 : Wq_MEM_CEB*/), .WEB(init ? init_w_wen : Wq_MEM_WEN),
		.CEBM(1'b0), .WEBM(1'b0), .A(init ? init_w_addr : Wq_MEM_ADDR), .D(Wq_MEM_DIN), .BWEB(128'd0),
		.AM(10'd0), .DM(128'b0), .BWEBM(128'b0), .BIST(1'b0), .RTSEL(2'b0), .WTSEL(2'b0),
		.Q(Wq_MEM_DOUT)
	);
	
	q_proj_mem OUTPUT_MEM (
		.SLP(1'b0), .SD(1'b0), .CLK(clk), .CEB(1'b0), .WEB(fin ? fin_output_wen : OUTPUT_MEM_WEN),
		.CEBM(1'b0), .WEBM(1'b0), .A(fin ? fin_output_addr : OUTPUT_MEM_ADDR), .D(OUTPUT_MEM_DIN), .BWEB(128'd0),
		.AM(5'd0), .DM(128'b0), .BWEBM(128'b0), .BIST(1'b0), .RTSEL(2'b0), .WTSEL(2'b0),
		.Q(OUTPUT_MEM_DOUT)
	);

endmodule 
	
