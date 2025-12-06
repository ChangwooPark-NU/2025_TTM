module cap #(
    parameter int count = 10
)( 
    input logic clk, 
    input logic rst, 
    input logic write_en, 
    output logic [3:0] count_reg, 
    output logic out
); 

logic active; 

always_ff @(posedge clk or posedge rst) begin 
    if (rst) begin 
        count_reg <= 3'd0; 
        active <= 1'b0; 
        out <= 1'b0; 
    end
    else if (write_en  && !active) begin
        active <= 1'b1; 
        count_reg <= 3'd0; 
    	out <= 1'b0; 
    end
    else if (!active) begin 
        out <= 1'b0;
    end
    else if (active) begin 
        if (count_reg < count - 1) begin 
            count_reg <= count_reg + 1; 
        end
        else begin 
            active <= 1'b0; 
            out <= 1'b1;
	    count_reg <= count_reg + 1;
        end
    end
end

endmodule
