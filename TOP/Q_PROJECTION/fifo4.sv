module fifo_in4 #(
    parameter int DATA_WIDTH = 8, 
    parameter int DEPTH = 7 
)( 
    input logic clk, 
    input logic rst, 
    input logic write_en,
    input logic read_en, 
    input logic [((DATA_WIDTH*4)-1):0] write_data, 
    output logic [DATA_WIDTH-1:0] read_data, 
    output logic full, 
    output logic empty
);
    localparam d1 = DEPTH+1; 
    logic [DATA_WIDTH-1:0] fifo_mem[d1]; 
    logic [$clog2(DEPTH):0] read_ptr, write_ptr, used_space; 
    
    always_ff @(posedge clk) begin
        if (rst) begin 
            read_ptr <= '0; 
            write_ptr <= '0; 
            used_space <= '0;
            read_data <= '0;
        end else begin 
            if ((write_en && (d1 - used_space >= d1) && (read_en && !empty))) begin 
                fifo_mem[write_ptr] <= '0; 
                fifo_mem[write_ptr+1] <= '0;
                fifo_mem[write_ptr+2] <= '0;
                fifo_mem[write_ptr+3] <= write_data[31:24]; 
                fifo_mem[write_ptr+4] <= write_data[23:16]; 
                fifo_mem[write_ptr+5] <= write_data[15:8]; 
                fifo_mem[write_ptr+6] <= write_data[7:0];
		fifo_mem[write_ptr+7] <= '0;
                write_ptr <= (write_ptr + d1) % d1; 
                read_data <= fifo_mem[read_ptr]; 
                read_ptr <= (read_ptr + 1) % d1;
                used_space <= used_space + (d1-1);
            end 
            else if (write_en && (d1 - used_space >= d1)) begin
                fifo_mem[write_ptr] <= '0; 
                fifo_mem[write_ptr+1] <= '0;
                fifo_mem[write_ptr+2] <= '0;
                fifo_mem[write_ptr+3] <= write_data[31:24]; 
                fifo_mem[write_ptr+4] <= write_data[23:16]; 
                fifo_mem[write_ptr+5] <= write_data[15:8]; 
                fifo_mem[write_ptr+6] <= write_data[7:0];
		fifo_mem[write_ptr+7] <= '0; 
                write_ptr <= (write_ptr + d1) % d1; 
                used_space <= used_space + d1;
           
            end 
            else if (read_en && !empty) begin
                read_data <= fifo_mem[read_ptr]; 
                read_ptr <= (read_ptr + 1) % d1;
                used_space <= used_space - 1; 
            end
        end
    end
    assign full = (used_space == d1); 
    assign empty = (used_space == 0); 
endmodule 
