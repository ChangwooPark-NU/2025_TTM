module outputfifo (
    input  logic clk,                  // Clock signal
    input  logic rst,                  // Active-high reset
    input  logic wen,                  // Write enable
    input  logic [511:0] in,      // 16 input signals, each 32-bit wide
    output logic [511:0] out_reg        // 256-bit registered output
);

    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            out_reg <= '0;  // Reset the output to zero
        else if (wen)
            out_reg <= in;
    end
endmodule

