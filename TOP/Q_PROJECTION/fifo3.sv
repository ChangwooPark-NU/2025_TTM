module fifo_in3 #(
    parameter int DATA_WIDTH = 8, 
    parameter int DEPTH = 14
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

    logic [DATA_WIDTH-1:0] fifo_mem[DEPTH]; 
    logic [$clog2(DEPTH):0] read_ptr, write_ptr, used_space; 

    always_ff @(posedge clk) begin
        if (rst) begin 
            read_ptr <= '0; 
            write_ptr <= '0; 
            used_space <= '0;
            read_data <= '0;
        end else begin 
            if ((write_en && (DEPTH - used_space >= 7) && (read_en && !empty))) begin 
                fifo_mem[write_ptr] <= '0;
                fifo_mem[write_ptr+1] <= '0;
                fifo_mem[write_ptr+2] <= write_data[31:24];
                fifo_mem[write_ptr+3] <= write_data[23:16]; 
                fifo_mem[write_ptr+4] <= write_data[15:8]; 
                fifo_mem[write_ptr+5] <= write_data[7:0]; 
                fifo_mem[write_ptr+6] <= '0;
                write_ptr <= (write_ptr + 7) % DEPTH; 
                read_data <= fifo_mem[read_ptr]; 
                read_ptr <= (read_ptr + 1) % DEPTH;
                used_space <= used_space + 6;
            end 
            else if (write_en && (DEPTH - used_space >= 7)) begin
                fifo_mem[write_ptr] <= '0;
                fifo_mem[write_ptr+1] <= '0;
                fifo_mem[write_ptr+2] <= write_data[31:24];
                fifo_mem[write_ptr+3] <= write_data[23:16]; 
                fifo_mem[write_ptr+4] <= write_data[15:8]; 
                fifo_mem[write_ptr+5] <= write_data[7:0]; 
                fifo_mem[write_ptr+6] <= '0;
                write_ptr <= (write_ptr + 7) % DEPTH; 
                used_space <= used_space + 7;
           
            end 
            else if (read_en && !empty) begin
                read_data <= fifo_mem[read_ptr]; 
                read_ptr <= (read_ptr + 1) % DEPTH;
                used_space <= used_space - 1; 
            end
        end
    end
    assign full = (used_space == DEPTH); 
    assign empty = (used_space == 0); 
endmodule 
