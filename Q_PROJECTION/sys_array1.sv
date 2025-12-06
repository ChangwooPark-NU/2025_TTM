  module SystolicArray #(
      parameter int N = 4,         // N x N Systolic Array
      parameter int DATA_WIDTH = 8, // Matrix Element Bit Width
      parameter int ACC_WIDTH = 32  // Accumulator Width
  )( 
      input logic clk, 
      input logic rst, 
      input logic [DATA_WIDTH-1:0] in_a[N], 
      input logic [DATA_WIDTH-1:0] in_b[N], 
      output logic [N*N*ACC_WIDTH-1:0] out_flat // Single packed output
  ); 
  
      logic [DATA_WIDTH-1:0] a[N][N]; // Connections between PEs (left->right)
      logic [DATA_WIDTH-1:0] b[N][N]; // Connections between PEs (top->bottom)
      logic [ACC_WIDTH-1:0] out[N][N]; // Local PE outputs
  
      genvar i, j;
      generate
          for (i = 0; i < N; i++) begin : row_loop
              for (j = 0; j < N; j++) begin : col_loop
                  PE #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) pe_inst (
                      .clk(clk),
                      .rst(rst),
                      .in_a((j == 0) ? in_a[i] : a[i][j-1]), // First column gets input_a
                      .in_b((i == 0) ? in_b[j] : b[i-1][j]), // First row gets input_b
                      .out(out[i][j]),  // Local accumulation output
                      .out_a(a[i][j]), 
                      .out_b(b[i][j])
                  );
              end
          end
      endgenerate
      
      assign out_flat = { out[3][3], out[3][2], out[3][1], out[3][0],
                          out[2][3], out[2][2], out[2][1], out[2][0],
                          out[1][3], out[1][2], out[1][1], out[1][0],
                          out[0][3], out[0][2], out[0][1], out[0][0] };
    
  
  endmodule
  
