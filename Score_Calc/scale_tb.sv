`timescale 1ns/1ps 

module scale_tb; 
	logic clk = 0; 
	always #5 clk = ~clk; 

	logic rst; 
	logic start; 
	logic [511:0] score, scaled_score; 
	logic done; 

	scale dut ( 
		.clk(clk), 
		.rst(rst),
		.start(start), 	
		.score(score), 
		.scaled_score(scaled_score),
		.done(done) 
	); 	

	class random_input; 
		rand logic [511:0] rand_score; 
	endclass 

	random_input obj; 

	initial begin
		obj = new(); 
		assert(obj.randomize()); 
		score = obj.rand_score;	
		$display("%x", score); 
		rst = 1; 
		repeat (2) @(posedge clk); 
		rst = 0; 	
		start = 1; 
		@(posedge clk); 	
		repeat (1000) @(posedge clk); 
		$display("%x", scaled_score); 
		$finish; 
	end 
endmodule 
	
