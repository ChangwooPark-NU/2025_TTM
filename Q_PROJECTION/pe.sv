module PE #( 
    parameter int DATA_WIDTH = 8, 
    parameter int ACC_WIDTH = 32
)( 
    input logic clk, 
    input logic rst,
    input logic load_bias, 			// Flag to load bias 
    input logic signed [ACC_WIDTH-1:0] bias,    // Bias  
    input logic signed [DATA_WIDTH-1:0] in_a,   // Input from left neighbor
    input logic signed [DATA_WIDTH-1:0] in_b,   // Input from top neighbor
    output logic signed [DATA_WIDTH-1:0] out_a, // Output to right neighbor
    output logic signed [DATA_WIDTH-1:0] out_b, // Output to bottom neighbor
    output logic signed [ACC_WIDTH-1:0] out     // PE Output
); 

    logic signed [ACC_WIDTH-1:0] local_sum; // Accumulation

    // Zero gating 
    logic do_mult; 
    logic signed [DATA_WIDTH-1:0] gated_in_a, gated_in_b; 
 	 
    assign do_mult = (in_a != '0 && in_b != '0); 
    assign gated_in_a = do_mult ? $signed(in_a) : '0; 
    assign gated_in_b = do_mult ? $signed(in_b) : '0; 

    always_ff @ (posedge clk or posedge rst) begin
        if (rst) begin 
            local_sum <= '0; 
            out_a <= '0; 
            out_b <= '0; 
        end else if (load_bias) begin
	    local_sum <= bias; 
	end 	
	else begin 
            local_sum <= $signed(local_sum) + ($signed(gated_in_a) * $signed(gated_in_b)); 
            out_a <= in_a; 
            out_b <= in_b; 
        end
    end

    assign out = local_sum; 

endmodule

    
