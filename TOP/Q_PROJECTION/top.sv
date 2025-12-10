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
	input logic [127:0] INPUT_MEM_DIN_q, 
	output logic [127:0] OUTPUT_MEM_DIN_q, 
	input logic [127:0] Wq_MEM_DIN, 
	output logic [511:0] out_q, 
	output logic valid_q,
	output logic [127:0] INPUT_MEM_DOUT_q, 	
	output logic [127:0] OUTPUT_MEM_DOUT_q,
	output logic [127:0] Wq_MEM_DOUT, 

	input logic [127:0] INPUT_MEM_DIN_k, 
	output logic [127:0] OUTPUT_MEM_DIN_k, 
	input logic [127:0] Wk_MEM_DIN, 
	output logic [511:0] out_k, 
	output logic valid_k,
	output logic [127:0] INPUT_MEM_DOUT_k, 	
	output logic [127:0] OUTPUT_MEM_DOUT_k,
	output logic [127:0] Wk_MEM_DOUT, 

	input logic [127:0] INPUT_MEM_DIN_v, 
	output logic [127:0] OUTPUT_MEM_DIN_v, 
	input logic [127:0] Wv_MEM_DIN, 
	output logic [511:0] out_v, 
	output logic valid_v,
	output logic [127:0] INPUT_MEM_DOUT_v, 	
	output logic [127:0] OUTPUT_MEM_DOUT_v,
	output logic [127:0] Wv_MEM_DOUT 
	
); 
	// Define signals 
        logic INPUT_MEM_WEN_q;
        logic INPUT_MEM_CEB_q;
        logic [4:0] INPUT_MEM_ADDR_q;
        logic Wq_MEM_WEN;
        logic Wq_MEM_CEB;
        logic [9:0] Wq_MEM_ADDR;
        logic OUTPUT_MEM_WEN_q;
        logic OUTPUT_MEM_CEB_q;
        logic [6:0] OUTPUT_MEM_ADDR_q;
	logic finished_q; 
	logic INPUT_MEM_WEN_k;
        logic INPUT_MEM_CEB_k;
        logic [4:0] INPUT_MEM_ADDR_k;
        logic Wk_MEM_WEN;
        logic Wk_MEM_CEB;
        logic [9:0] Wk_MEM_ADDR;
        logic OUTPUT_MEM_WEN_k;
        logic OUTPUT_MEM_CEB_k;
        logic [6:0] OUTPUT_MEM_ADDR_k;
	logic finished_k; 
	logic INPUT_MEM_WEN_v;
        logic INPUT_MEM_CEB_v;
        logic [4:0] INPUT_MEM_ADDR_v;
        logic Wv_MEM_WEN;
        logic Wv_MEM_CEB;
        logic [9:0] Wv_MEM_ADDR;
        logic OUTPUT_MEM_WEN_v;
        logic OUTPUT_MEM_CEB_v;
        logic [6:0] OUTPUT_MEM_ADDR_v;
	logic finished_v; 
	logic finished; 

	assign finished = finished_q & finished_k & finished_v; 

	// Instantiate DUT 
	QKV_Projection qut ( 
		.clk(clk), 
		.rst(rst), 
		.en(en),
		.out(out_q),
		.valid(valid_q), 	
		.INPUT_MEM_DOUT(INPUT_MEM_DOUT_q),
		.INPUT_MEM_WEN(INPUT_MEM_WEN_q), 
		.INPUT_MEM_CEB(INPUT_MEM_CEB_q), 
		.INPUT_MEM_ADDR(INPUT_MEM_ADDR_q),
		.Wq_MEM_DOUT(Wq_MEM_DOUT), 
		.Wq_MEM_WEN(Wq_MEM_WEN), 
		.Wq_MEM_CEB(Wq_MEM_CEB), 
		.Wq_MEM_ADDR(Wq_MEM_ADDR), 
		.OUTPUT_MEM_DOUT(OUTPUT_MEM_DOUT_q), 
		.OUTPUT_MEM_WEN(OUTPUT_MEM_WEN_q), 
		.OUTPUT_MEM_CEB(OUTPUT_MEM_CEB_q), 
		.OUTPUT_MEM_DIN(OUTPUT_MEM_DIN_q),
		.OUTPUT_MEM_ADDR(OUTPUT_MEM_ADDR_q),
		.finished(finished_q)
	); 

	QKV_Projection kut ( 
		.clk(clk), 
		.rst(rst), 
		.en(en),
		.out(out_k),
		.valid(valid_k), 	
		.INPUT_MEM_DOUT(INPUT_MEM_DOUT_k),
		.INPUT_MEM_WEN(INPUT_MEM_WEN_k), 
		.INPUT_MEM_CEB(INPUT_MEM_CEB_k), 
		.INPUT_MEM_ADDR(INPUT_MEM_ADDR_k),
		.Wq_MEM_DOUT(Wk_MEM_DOUT), 
		.Wq_MEM_WEN(Wk_MEM_WEN), 
		.Wq_MEM_CEB(Wk_MEM_CEB), 
		.Wq_MEM_ADDR(Wk_MEM_ADDR), 
		.OUTPUT_MEM_DOUT(OUTPUT_MEM_DOUT_k), 
		.OUTPUT_MEM_WEN(OUTPUT_MEM_WEN_k), 
		.OUTPUT_MEM_CEB(OUTPUT_MEM_CEB_k), 
		.OUTPUT_MEM_DIN(OUTPUT_MEM_DIN_k),
		.OUTPUT_MEM_ADDR(OUTPUT_MEM_ADDR_k),
		.finished(finished_k)
	); 

	QKV_Projection vut ( 
		.clk(clk), 
		.rst(rst), 
		.en(en),
		.out(out_v),
		.valid(valid_v), 	
		.INPUT_MEM_DOUT(INPUT_MEM_DOUT_v),
		.INPUT_MEM_WEN(INPUT_MEM_WEN_v), 
		.INPUT_MEM_CEB(INPUT_MEM_CEB_v), 
		.INPUT_MEM_ADDR(INPUT_MEM_ADDR_v),
		.Wq_MEM_DOUT(Wv_MEM_DOUT), 
		.Wq_MEM_WEN(Wv_MEM_WEN), 
		.Wq_MEM_CEB(Wv_MEM_CEB), 
		.Wq_MEM_ADDR(Wv_MEM_ADDR), 
		.OUTPUT_MEM_DOUT(OUTPUT_MEM_DOUT_v), 
		.OUTPUT_MEM_WEN(OUTPUT_MEM_WEN_v), 
		.OUTPUT_MEM_CEB(OUTPUT_MEM_CEB_v), 
		.OUTPUT_MEM_DIN(OUTPUT_MEM_DIN_v),
		.OUTPUT_MEM_ADDR(OUTPUT_MEM_ADDR_v),
		.finished(finished_v)
	); 

	
	logic [6:0] fp_q_addr, fp_k_addr, fp_v_addr;  
	logic fp_valid;
	logic [1:0] fp_row; 
	logic [4:0] fp_group; 
	logic [127:0] fp_out; 
	logic fp_done; 

	attn_top_4x4_128_mha4 #(.READ_LAT(2)) fp ( 

	  .clk(clk),
	  .rst_n(~rst),           // active-low 
	  .start(finished),           // start attention pipeline after Q/K/V ready

	  // Q/K/V SRAM read interfaces (128-bit = 4 lanes fp32)
	  .Q_mem_addr(fp_q_addr),
	  .K_mem_addr(fp_k_addr),
	  .V_mem_addr(fp_v_addr),

	  .Q_mem_out(OUTPUT_MEM_DOUT_q),
	  .K_mem_out(OUTPUT_MEM_DOUT_k),
	  .V_mem_out(OUTPUT_MEM_DOUT_v),

	  // Output stream
	  .out_valid(fp_valid),
	  .out_row(fp_row),
	  .out_group(fp_group),       // 0..31
	  .out_data(fp_out),

	  .done(fp_done)
	);
		

	// Define input, weight, and output mems 
	input_mem INPUT_MEM_q (
		.SLP(1'b0), .SD(1'b0), .CLK(clk), .CEB(1'b0 /*init ? 1'b0 : INPUT_MEM_CEB*/), .WEB(init ? init_input_wen : INPUT_MEM_WEN_q),
		.CEBM(1'b0), .WEBM(1'b0), .A(init ? init_input_addr : INPUT_MEM_ADDR_q), .D(INPUT_MEM_DIN_q), .BWEB(128'd0),
		.AM(5'd0), .DM(128'b0), .BWEBM(128'b0), .BIST(1'b0), .RTSEL(2'b0), .WTSEL(2'b0),
		.Q(INPUT_MEM_DOUT_q)
	);

	Wq_mem Wq_MEM (
		.SLP(1'b0), .SD(1'b0), .CLK(clk), .CEB(1'b0 /*init ? 1'b0 : Wq_MEM_CEB*/), .WEB(init ? init_w_wen : Wq_MEM_WEN),
		.CEBM(1'b0), .WEBM(1'b0), .A(init ? init_w_addr : Wq_MEM_ADDR), .D(Wq_MEM_DIN), .BWEB(128'd0),
		.AM(10'd0), .DM(128'b0), .BWEBM(128'b0), .BIST(1'b0), .RTSEL(2'b0), .WTSEL(2'b0),
		.Q(Wq_MEM_DOUT)
	);
	
	q_proj_mem OUTPUT_MEM (
		.SLP(1'b0), .SD(1'b0), .CLK(clk), .CEB(1'b0), .WEB(!finished ? (fin ? fin_output_wen : OUTPUT_MEM_WEN_q) : 1'b1),
		.CEBM(1'b0), .WEBM(1'b0), .A(!finished ? (fin ? fin_output_addr : OUTPUT_MEM_ADDR_q):  fp_q_addr), .D(OUTPUT_MEM_DIN_q), .BWEB(128'd0),
		.AM(5'd0), .DM(128'b0), .BWEBM(128'b0), .BIST(1'b0), .RTSEL(2'b0), .WTSEL(2'b0),
		.Q(OUTPUT_MEM_DOUT_q)
	);

	input_mem INPUT_MEM_k (
		.SLP(1'b0), .SD(1'b0), .CLK(clk), .CEB(1'b0 /*init ? 1'b0 : INPUT_MEM_CEB*/), .WEB(init ? init_input_wen : INPUT_MEM_WEN_k),
		.CEBM(1'b0), .WEBM(1'b0), .A(init ? init_input_addr : INPUT_MEM_ADDR_k), .D(INPUT_MEM_DIN_k), .BWEB(128'd0),
		.AM(5'd0), .DM(128'b0), .BWEBM(128'b0), .BIST(1'b0), .RTSEL(2'b0), .WTSEL(2'b0),
		.Q(INPUT_MEM_DOUT_k)
	);

	Wq_mem Wk_MEM (
		.SLP(1'b0), .SD(1'b0), .CLK(clk), .CEB(1'b0 /*init ? 1'b0 : Wq_MEM_CEB*/), .WEB(init ? init_w_wen : Wk_MEM_WEN),
		.CEBM(1'b0), .WEBM(1'b0), .A(init ? init_w_addr : Wk_MEM_ADDR), .D(Wk_MEM_DIN), .BWEB(128'd0),
		.AM(10'd0), .DM(128'b0), .BWEBM(128'b0), .BIST(1'b0), .RTSEL(2'b0), .WTSEL(2'b0),
		.Q(Wk_MEM_DOUT)
	);
	
	q_proj_mem OUTPUT_MEM_k (
		.SLP(1'b0), .SD(1'b0), .CLK(clk), .CEB(1'b0), .WEB(!finished ? (fin ? fin_output_wen : OUTPUT_MEM_WEN_k) : 1'b1),
		.CEBM(1'b0), .WEBM(1'b0), .A(!finished ? (fin ? fin_output_addr : OUTPUT_MEM_ADDR_k) : fp_k_addr), .D(OUTPUT_MEM_DIN_k), .BWEB(128'd0),
		.AM(5'd0), .DM(128'b0), .BWEBM(128'b0), .BIST(1'b0), .RTSEL(2'b0), .WTSEL(2'b0),
		.Q(OUTPUT_MEM_DOUT_k)
	);

	input_mem INPUT_MEM_v (
		.SLP(1'b0), .SD(1'b0), .CLK(clk), .CEB(1'b0 /*init ? 1'b0 : INPUT_MEM_CEB*/), .WEB(init ? init_input_wen : INPUT_MEM_WEN_v),
		.CEBM(1'b0), .WEBM(1'b0), .A(init ? init_input_addr : INPUT_MEM_ADDR_v), .D(INPUT_MEM_DIN_v), .BWEB(128'd0),
		.AM(5'd0), .DM(128'b0), .BWEBM(128'b0), .BIST(1'b0), .RTSEL(2'b0), .WTSEL(2'b0),
		.Q(INPUT_MEM_DOUT_v)
	);

	Wq_mem Wv_MEM (
		.SLP(1'b0), .SD(1'b0), .CLK(clk), .CEB(1'b0 /*init ? 1'b0 : Wq_MEM_CEB*/), .WEB(init ? init_w_wen : Wv_MEM_WEN),
		.CEBM(1'b0), .WEBM(1'b0), .A(init ? init_w_addr : Wv_MEM_ADDR), .D(Wv_MEM_DIN), .BWEB(128'd0),
		.AM(10'd0), .DM(128'b0), .BWEBM(128'b0), .BIST(1'b0), .RTSEL(2'b0), .WTSEL(2'b0),
		.Q(Wv_MEM_DOUT)
	);
	
	q_proj_mem OUTPUT_MEM_v (
		.SLP(1'b0), .SD(1'b0), .CLK(clk), .CEB(1'b0), .WEB(!finished ? (fin ? fin_output_wen : OUTPUT_MEM_WEN_v) : 1'b1),
		.CEBM(1'b0), .WEBM(1'b0), .A(!finished ? (fin ? fin_output_addr : OUTPUT_MEM_ADDR_v) :  fp_v_addr), .D(OUTPUT_MEM_DIN_v), .BWEB(128'd0),
		.AM(5'd0), .DM(128'b0), .BWEBM(128'b0), .BIST(1'b0), .RTSEL(2'b0), .WTSEL(2'b0),
		.Q(OUTPUT_MEM_DOUT_v)
	);

endmodule 
	
