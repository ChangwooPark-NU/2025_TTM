`timescale 1ns/1ps

module int32_to_fp32_scaled #(
    parameter FRAC_OUT = 7
)(
    input  wire signed [31:0] int_in,
    output reg  [31:0]        fp32_out
);

    reg        sign;
    reg [31:0] abs_val;

    integer i;
    integer msb_index;

    reg [7:0]  exponent;
    reg [22:0] mantissa;

    reg [31:0] norm_shifted;

    always @(*) begin


        // ZERO-GATING: int_in == 0 -> FP32 zero

        if (int_in == 0) begin
            fp32_out = 32'h00000000;
        end 
        else begin

            // sign + absolute value

            sign    = int_in[31];
            abs_val = sign ? (~int_in + 1) : int_in;

            // MSB 

            msb_index = 0;
            for (i = 0; i < 32; i++)
                if (abs_val[i])
                    msb_index = i;


            // exponent = msb + 127 - FRAC_OUT

            exponent = msb_index + 127 - FRAC_OUT;


            // mantissa 

            norm_shifted = abs_val << (31 - msb_index);
            mantissa     = norm_shifted[30:8];


            fp32_out = {sign, exponent, mantissa};
        end
    end

endmodule
