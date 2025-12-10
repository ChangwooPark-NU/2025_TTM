// QKV Projection module of self attention block. 

`timescale 1ns/1ps

module QKV_Projection( 
	input logic clk,
	input logic rst, 
	input logic en,
    output logic valid,
	output logic [511:0] out, 	
	input logic [127:0] INPUT_MEM_DOUT,
	output logic INPUT_MEM_WEN,
	output logic INPUT_MEM_CEB, 
	output logic [4:0] INPUT_MEM_ADDR, 
	input logic [127:0] Wq_MEM_DOUT,
	output logic Wq_MEM_WEN,
	output logic Wq_MEM_CEB, 
	output logic [9:0] Wq_MEM_ADDR,
	input logic [127:0] OUTPUT_MEM_DOUT,
	output logic OUTPUT_MEM_WEN,
	output logic OUTPUT_MEM_CEB, 
	output logic [6:0] OUTPUT_MEM_ADDR,
	output logic [127:0] OUTPUT_MEM_DIN,
	output logic finished 	
);

	// Input mem addr signal (combinational)   
	logic [4:0] INPUT_MEM_ADDR_c; 
	
	// Wq mem addr signal (combinational) 
	logic [9:0]  Wq_MEM_ADDR_c; 

	// Output mem addr signal (combinational) 
	logic [6:0] OUTPUT_MEM_ADDR_c; 

	// Indicates when inputs to systollic array are valid 
	logic write_en;

	// Flattened matrix output
	logic [511:0] out_matrix; 	

	// Number of cycles in current operation in systollic array 
	logic [3:0] cycle_counter; 

	// Number of tiles calculated within current out tile 
	logic [5:0] tile_counter, tile_counter_c;

	// Number of out tiles calculated 
	logic [5:0] out_counter, out_counter_c;
	
	// Flag to reset systolic array if computing a new tile 
	logic new_tile; 

	// Flag to signal when tile has been computed
	logic done; 

	// D/Q Input of FP32 Matrix FF
	logic [511:0] fp32_d, fp32_q;
	
	// Flag to signal when to load bias 
	logic load_bias; 

	// Pulse to signal when bias_reg is valid 
	logic bias_valid; 

	// Register/wire to hold bias 
	logic [127:0] bias_reg; 
	logic [127:0] bias;
	
	// Registers to hold bias reg file addresses 
	logic [6:0] a1, a2, a3, a4; 

	// Fin shift reg (add 3 cycle delay) 
	logic fin, fin_reg1, fin_reg2, fin_reg3;

	// Drive output ports 
	assign out = out_matrix; 
	assign finished = fin_reg3; 

	// Instantiate systolic array 	
	Black_Box #(.N(4), .DATA_WIDTH(8), .ACC_WIDTH(32), .DEPTH(7), .COUNT(7), .CAP(11)) SYS_ARRAY ( 
	    .clk(clk),
	    .rst(rst || new_tile),
	    .tile_done(done), 
	    .valid(valid),
	    .load_bias(bias_valid),
	    .bias(bias_reg), 
	    .matrix_a(INPUT_MEM_DOUT),
	    .matrix_b(Wq_MEM_DOUT),
	    .matrix_c(out_matrix),
	    .write_en(write_en),
	    .counter(cycle_counter) 
	);

	genvar i; 
	generate
		for (i = 0; i < 16; i++) begin 
			// Instantiate 16 INT32->FP32 Modules 
			int32_to_fp32_scaled #(.FRAC_OUT(14)) i_to_f ( 
				.int_in(out_matrix[i*32+:32]), 
				.fp32_out(fp32_d[i*32+:32])
			); 
		end 
	endgenerate 

	// Register to store FP32 matrix
	always_ff @ (posedge clk or posedge rst) begin 
		if (rst) begin 
			fp32_q <= '0; 
		end
		else if (valid) begin 
			fp32_q <= fp32_d; 
		end
	end

	// Registers to store bias + valid signals 
	always_ff @ (posedge clk or posedge rst) begin 
		if (rst) begin 
			bias_reg <= 0; 
			bias_valid <= 0; 
			a1 <= 0; 
			a2 <= 1; 
			a3 <= 2; 
			a4 <= 3; 
		end
		else begin
			bias_valid <= load_bias; 
			if (load_bias) begin  
				bias_reg <= bias;
		       		a1 <= a1 + 4; 
				a2 <= a2 + 4; 
			 	a3 <= a3 + 4; 
				a4 <= a4 + 4; 
			end 	
		end 
	end

	// Register File to store biases 
	regfile rf ( 
		.clk(clk), 
		.a1(a1), 
		.a2(a2), 
		.a3(a3),
		.a4(a4),
		.bias(bias)
	);

	// Define FSM states 
	typedef enum logic [3:0] { 
		IDLE, 
		LOAD1,
		LOAD2, 	
		CALC, 
		WRITE1, 
	    WRITE2, 
		WRITE3, 
		WRITE4,
	    WRITE5, 	
		RESET 	
	} state_t; 

	state_t state, next; 

	always_ff @ (posedge clk or posedge rst) begin 
		if (rst) begin 
			state <= IDLE;
		    INPUT_MEM_ADDR <= '0; 
			Wq_MEM_ADDR <= '0;
			OUTPUT_MEM_ADDR <= '0; 
			tile_counter <= '0; 
			out_counter <= '0; 
			fin_reg1 <= 0; 
			fin_reg2 <= 0;
		        fin_reg3 <= 0; 	
		end
		else begin 
			state <= next;
		    INPUT_MEM_ADDR <= INPUT_MEM_ADDR_c; 
			Wq_MEM_ADDR <= Wq_MEM_ADDR_c; 
			OUTPUT_MEM_ADDR <= OUTPUT_MEM_ADDR_c;
			tile_counter <= tile_counter_c; 
			out_counter <= out_counter_c; 
			fin_reg1 <= fin;
			fin_reg2 <= fin_reg1;
			fin_reg3 <= fin_reg2; 	
		end 
	end 

	always_comb begin 
		next = state; 
		INPUT_MEM_CEB = 1; 
		Wq_MEM_CEB = 1; 
		OUTPUT_MEM_CEB = 1;
		INPUT_MEM_WEN = 1; 
		Wq_MEM_WEN = 1; 
		OUTPUT_MEM_WEN = 1;
	    write_en = 0; 	
		INPUT_MEM_ADDR_c = INPUT_MEM_ADDR; 
		Wq_MEM_ADDR_c = Wq_MEM_ADDR;
		OUTPUT_MEM_ADDR_c = OUTPUT_MEM_ADDR; 
		OUTPUT_MEM_DIN = '0;	
		tile_counter_c = tile_counter; 
		out_counter_c = out_counter; 
		new_tile = 0;
	    done = 0;
    		load_bias = 0; 	    
		fin = fin_reg1; 
		case (state) 
			IDLE: begin 
				if (en) begin 
					load_bias = 1; 
					next = LOAD1; 
				end	
			end
	       		LOAD1: begin 
				INPUT_MEM_CEB = 0; 
				Wq_MEM_CEB = 0; 
			    next = LOAD2; 	
			end 
			LOAD2: begin 
				write_en = 1;	
				next = CALC; 
			end 
			CALC: begin 
				if (cycle_counter == 1) begin 
					INPUT_MEM_ADDR_c = INPUT_MEM_ADDR + 1;
				    Wq_MEM_ADDR_c = Wq_MEM_ADDR + 32; 	
				end 
				if (cycle_counter == 5) begin 
					INPUT_MEM_CEB = 0; 
					Wq_MEM_CEB = 0; 
				end 
				if ((cycle_counter == 10) && (tile_counter != 32)) begin 
					write_en = 1;
				    tile_counter_c = tile_counter + 1; 	
				end 
				if ((cycle_counter == 11) && (tile_counter == 32)) begin 
					out_counter_c = out_counter + 1; 
					next = WRITE1; 
					done = 1; 
				end 
			end
			WRITE1: begin 
				if (out_counter != 32) begin 
					INPUT_MEM_ADDR_c = '0;  
					Wq_MEM_ADDR_c = out_counter;
				end 	
				next = WRITE2; 	
			end
			WRITE2: begin 
				OUTPUT_MEM_DIN = fp32_q[127:0];
				OUTPUT_MEM_ADDR_c = OUTPUT_MEM_ADDR + 1; 
				OUTPUT_MEM_CEB = '0; 
				OUTPUT_MEM_WEN = '0; 
				if (out_counter != 32) begin 
					INPUT_MEM_CEB = 0; 
					Wq_MEM_CEB = 0; 
				end
				next = WRITE3; 
			end
			WRITE3: begin 
				OUTPUT_MEM_DIN = fp32_q[255:128];	
				OUTPUT_MEM_ADDR_c = OUTPUT_MEM_ADDR + 1; 
				OUTPUT_MEM_CEB = '0; 
				OUTPUT_MEM_WEN = '0; 
				next = WRITE4; 
			end
			WRITE4: begin 
				OUTPUT_MEM_DIN = fp32_q[383:256];	
				OUTPUT_MEM_ADDR_c = OUTPUT_MEM_ADDR + 1; 
				OUTPUT_MEM_CEB = '0; 
				OUTPUT_MEM_WEN = '0; 
				next = WRITE5; 
			end 
			WRITE5: begin 
				OUTPUT_MEM_DIN = fp32_q[511:384]; 
				OUTPUT_MEM_CEB = '0; 
				OUTPUT_MEM_WEN = '0; 
				if (out_counter != 32) begin 	
					OUTPUT_MEM_ADDR_c = OUTPUT_MEM_ADDR + 1; 
					tile_counter_c = '0;  
					next = RESET;  
				end 
				else begin 
					next = IDLE;
					fin = 1; 
				end
			end
		        RESET: begin 
				new_tile = 1;
			        load_bias = 1; 	
				next = LOAD2; 
			end	
		endcase
	end 
endmodule
