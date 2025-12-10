`timescale 1ps/1ps

module gemm_4x4_4x128_tb;


  // clock / reset

  logic clk;
  logic rst_n;

  initial clk = 1'b0;
  always  #5000 clk = ~clk; // 10ns


  // DUT signals

  logic start;

  logic [31:0] A [0:3][0:3];

  wire [6:0]   B_mem_addr;
  logic [127:0] B_mem_out;

  wire         out_valid;
  wire [1:0]   out_row;
  wire [4:0]   out_group;
  wire [127:0] out_data;
  wire         busy;
  wire         done;


  // Instantiate DUT

  gemm_4x4_4x128 #(
    .READ_LAT(2),
    .MEM_WAIT(3)
  ) dut (
    .clk       (clk),
    .rst_n     (rst_n),
    .start     (start),

    .A         (A),

    .B_mem_addr(B_mem_addr),
    .B_mem_out (B_mem_out),

    .out_valid (out_valid),
    .out_row   (out_row),
    .out_group (out_group),
    .out_data  (out_data),
    .busy      (busy),
    .done      (done)
  );


  // TB "SRAM" model:

  logic [127:0] B_mem [0:127];
  logic [6:0]   addr_d1, addr_d2;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      addr_d1   <= '0;
      addr_d2   <= '0;
      B_mem_out <= '0;
    end else begin
      addr_d1   <= B_mem_addr;
      addr_d2   <= addr_d1;
      B_mem_out <= B_mem[addr_d2];  
    end
  end


  // FP32 helpers

  function automatic logic [31:0] fp32(input real r);
    shortreal sr;
    begin
      sr = r;
      fp32 = $shortrealtobits(sr);
    end
  endfunction

  function automatic shortreal bits_to_sr(input logic [31:0] bits);
    shortreal sr;
    begin
      sr = $bitstoshortreal(bits);
      bits_to_sr = sr;
    end
  endfunction

  function automatic shortreal abs_sr(input shortreal x);
    begin
      abs_sr = (x < 0.0) ? -x : x;
    end
  endfunction

  function automatic logic [127:0] pack4(input logic [31:0] l0, l1, l2, l3);
    begin
      pack4 = {l3, l2, l1, l0};
    end
  endfunction

  // expected B
  function automatic shortreal expected_B(input int k, input int col);
    shortreal base;
    shortreal val;
    begin
      base = 0.0;
      if (k == 0) base = 1.0;
      else if (k == 1) base = 2.0;
      else if (k == 2) base = 4.0;
      else if (k == 3) base = 8.0;
      val = base + 0.001 * shortreal'(col);
      expected_B = val;
    end
  endfunction

  // init B_mem
  task automatic init_B();
    int g, k;
    int col0, col1, col2, col3;
    int addr;
    shortreal f0, f1, f2, f3;
    logic [127:0] w;
    begin
      for (g = 0; g < 32; g = g + 1) begin
        for (k = 0; k < 4; k = k + 1) begin
          addr = g*4 + k;
          col0 = 4*g + 0;
          col1 = 4*g + 1;
          col2 = 4*g + 2;
          col3 = 4*g + 3;

          f0 = expected_B(k, col0);
          f1 = expected_B(k, col1);
          f2 = expected_B(k, col2);
          f3 = expected_B(k, col3);

          w = pack4(fp32(f0), fp32(f1), fp32(f2), fp32(f3));
          B_mem[addr] = w;
        end
      end
    end
  endtask

  // init A
  task automatic init_A_identity();
    int r, c;
    begin
      for (r = 0; r < 4; r = r + 1) begin
        for (c = 0; c < 4; c = c + 1) begin
          if (r == c) A[r][c] = fp32(1.0);
          else        A[r][c] = fp32(0.0);
        end
      end
    end
  endtask


  // Output monitor / checker

  int out_count;
  int err_count;

  initial begin
    shortreal got0, got1, got2, got3;
    shortreal exp0, exp1, exp2, exp3;
    shortreal d0, d1, d2, d3;
    shortreal eps;
    int row_i, grp_i;
    int col_base;

    out_count = 0;
    err_count = 0;
    eps = 1e-3;

    forever begin
      @(posedge clk);

      if (out_valid) begin
        row_i = out_row;
        grp_i = out_group;
        col_base = 4*grp_i;

        got0 = bits_to_sr(out_data[31:0]);
        got1 = bits_to_sr(out_data[63:32]);
        got2 = bits_to_sr(out_data[95:64]);
        got3 = bits_to_sr(out_data[127:96]);


        exp0 = expected_B(row_i, col_base + 0);
        exp1 = expected_B(row_i, col_base + 1);
        exp2 = expected_B(row_i, col_base + 2);
        exp3 = expected_B(row_i, col_base + 3);

        d0 = abs_sr(got0 - exp0);
        d1 = abs_sr(got1 - exp1);
        d2 = abs_sr(got2 - exp2);
        d3 = abs_sr(got3 - exp3);

        $display("OUT row=%0d group=%0d out_data lanes fp32=%f %f %f %f",
                 row_i, grp_i, got0, got1, got2, got3);

        if ((d0 > eps) || (d1 > eps) || (d2 > eps) || (d3 > eps)) begin
          err_count = err_count + 1;
          $display("  MISMATCH exp=%f %f %f %f | diff=%f %f %f %f",
                   exp0, exp1, exp2, exp3, d0, d1, d2, d3);
        end

        out_count = out_count + 1;
      end

      if (done) begin
        $display("DONE pulse. out_count=%0d (expect 128) err_count=%0d", out_count, err_count);
      end
    end
  end


  // Main test

  initial begin
    int cyc;

    start = 1'b0;

    init_A_identity();
    init_B();

    // reset
    rst_n = 1'b0;
    repeat (8) @(posedge clk);
    rst_n = 1'b1;
    repeat (5) @(posedge clk);

    // start pulse (1 cycle)
    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;

    // wait done with timeout
    for (cyc = 0; cyc < 200000; cyc = cyc + 1) begin
      @(posedge clk);
      if (done) begin
        $display("DONE at cycle %0d (busy=%0d)", cyc, busy);
        break;
      end
    end

    if (!done) begin
      $display("TIMEOUT: done not asserted. out_count=%0d err_count=%0d", out_count, err_count);
      $fatal(1);
    end

    // final checks
    if (out_count != 128) begin
      $display("FAIL: out_count=%0d expected 128", out_count);
      $fatal(1);
    end
    if (err_count != 0) begin
      $display("FAIL: err_count=%0d", err_count);
      $fatal(1);
    end

    $display("PASS!");
    repeat (10) @(posedge clk);
    #100 $finish;
  end

endmodule
