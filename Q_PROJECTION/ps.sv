  module PulseSync (
      input  logic clk,
      input  logic rst,   // Active-high synchronous reset
      input  logic in1,
      input  logic in2,
      input  logic in3, 
      input  logic in4, 
      output logic out,
      output logic out2
  );
  
      logic seen_in1, seen_in2, seen_in3, seen_in4;
      logic pulse_triggered;
  
      always_ff @(posedge clk or posedge rst) begin
          if (rst) begin
              seen_in1 <= 0;
              seen_in2 <= 0;
              seen_in3 <= 0; 
              seen_in4 <= 0; 
              pulse_triggered <= 0;
              out  <= 0;
              out2 <= 0;
          end 
          else begin
              if (in1) seen_in1 <= 1;
              if (in2) seen_in2 <= 1;
              if (in3) seen_in3 <= 1; 
              if (in4) seen_in4 <= 1; 
  
              if (!pulse_triggered && seen_in1 && seen_in2 && seen_in3 && seen_in4) begin
                  out <= 1;
                  pulse_triggered <= 1;
					   seen_in1 <= 0;
				      seen_in2 <= 0;
				      seen_in3 <= 0;	
					   seen_in4 <= 0;	      // Ensure only one pulse sequence
              end 
              else begin
                  out <= 0;
              end
  
              if (pulse_triggered && out) begin
                  out2 <= 1;
						pulse_triggered <= 0;
              end 
              else begin
                  out2 <= 0;
              end
          end
      end
  
  endmodule
