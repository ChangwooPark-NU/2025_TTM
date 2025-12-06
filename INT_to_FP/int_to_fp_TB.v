`timescale 1ns/1ps

module tb_int32_to_fp32_scaled;

    // DUT parameter
    localparam FRAC_OUT = 7;

    // Inputs
    reg  signed [31:0] int_in;

    // Outputs
    wire [31:0] fp32_out;

    // Instantiate DUT
    int32_to_fp32_scaled #(
        .FRAC_OUT(FRAC_OUT)
    ) dut (
        .int_in(int_in),
        .fp32_out(fp32_out)
    );

    // Task: Print FP32 in real format
    task print_fp32;
        input [31:0] fp;
        real r;
        begin
            r = $bitstoreal({32'b0, fp}); // Trick: embed FP32 in lower 32 bits of a FP64
            $display("    FP32(hex) = %h,  real = %f", fp, r);
        end
    endtask

    initial begin
        $display("==== INT32 ? FP32 TEST START ====");

        // --------------------------
        // Case 1: int_in = 0
        // Expected FP32 = 0x00000000
        // --------------------------
        int_in = 0;
        #1;
        $display("\n[TEST] int_in = %0d", int_in);
        print_fp32(fp32_out);

        // --------------------------
        // Case 2: int_in = 128
        // Expected output = 128 / 128 = 1.0 ? FP32(0x3F800000)
        // --------------------------
        int_in = 128;
        #1;
        $display("\n[TEST] int_in = %0d", int_in);
        print_fp32(fp32_out);

        // --------------------------
        // Case 3: int_in = 256
        // Expected output = 256 / 128 = 2.0 ? FP32(0x40000000)
        // --------------------------
        int_in = 256;
        #1;
        $display("\n[TEST] int_in = %0d", int_in);
        print_fp32(fp32_out);

        // --------------------------
        // Case 4: int_in = -256
        // Expected output = -2.0 ? FP32(0xC0000000)
        // --------------------------
        int_in = -256;
        #1;
        $display("\n[TEST] int_in = %0d", int_in);
        print_fp32(fp32_out);

        // --------------------------
        // Case 5: int_in = 1024
        // Expected = 1024 / 128 = 8.0 ? FP32(0x41000000)
        // --------------------------
        int_in = 1024;
        #1;
        $display("\n[TEST] int_in = %0d", int_in);
        print_fp32(fp32_out);

        // --------------------------
        // Case 6: int_in = -1024
        // Expected = -8.0 ? FP32(0xC1000000)
        // --------------------------
        int_in = -1024;
        #1;
        $display("\n[TEST] int_in = %0d", int_in);
        print_fp32(fp32_out);

        // --------------------------
        // Case 7: Large number
        // int_in = 1,000,000
        // Expected = 1e6 / 128 ? 7812.5
        // --------------------------
        int_in = 32'd1000000;
        #1;
        $display("\n[TEST] int_in = %0d", int_in);
        print_fp32(fp32_out);

        // --------------------------
        // Case 8: Random tests
        // --------------------------
        repeat (10) begin
            int_in = $random;
            #1;
            $display("\n[TEST] Random int_in = %0d", int_in);
            print_fp32(fp32_out);
        end

        $display("\n==== TEST END ====");
        $finish;
    end

endmodule
