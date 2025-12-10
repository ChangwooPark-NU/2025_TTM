`timescale 1ns/1ps

module scale ( 
	input logic clk, 
	input logic rst,
       	input logic start, 	
	input logic [511:0] score, 
	output logic [511:0] scaled_score,
       	output logic done	
);
	
	// Fp32 div signals 
  	logic [15:0] input_a_ack;
  	logic [15:0] input_b_ack;
  	logic [15:0] output_z_stb;
	
	genvar i; 
	generate 
		for (i = 0; i < 16; i++) begin 
			divider fp32_div (
				.input_a(score[i*32+:32]),
				.input_b(32'h40B504F3),
				.input_a_stb(start),
				.input_b_stb(start),
				.output_z_ack(rst),
				.clk(clk),
				.rst(rst),
				.output_z(scaled_score[i*32+:32]),
				.output_z_stb(output_z_stb[i]),
				.input_a_ack(input_a_ack[i]),
				.input_b_ack(input_b_ack[i])
			);
		end
	endgenerate

	assign done = &output_z_stb; 	
endmodule 
