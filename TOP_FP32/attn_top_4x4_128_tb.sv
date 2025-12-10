`timescale 1ns/1ps

module attn_top_4x4_128_mha4_tb;

  localparam int  READ_LAT   = 2;
  localparam int  TOTAL_OUT  = 4 * 32;   // row(4) * group(32)
  localparam real TOL        = 1e-3;     // compare tolerance
  localparam real SQRT32     = 5.656854249492380; // sqrt(32)

  logic clk;
  logic rst_n;
  logic start;

  // init ports
  logic         q_init_en;
  logic         q_init_we_n;
  logic [6:0]   q_init_addr;
  logic [127:0] q_init_din;

  logic         k_init_en;
  logic         k_init_we_n;
  logic [6:0]   k_init_addr;
  logic [127:0] k_init_din;

  logic         v_init_en;
  logic         v_init_we_n;
  logic [6:0]   v_init_addr;
  logic [127:0] v_init_din;

  // outputs
  logic         out_valid;
  logic [1:0]   out_row;
  logic [4:0]   out_group;
  logic [127:0] out_data;

  logic         busy;
  logic         done;

  // DUT
  // If your DUT module name is different, change it here.
  attn_top_4x4_128_mha4 #(.READ_LAT(READ_LAT)) dut (
    .clk        (clk),
    .rst_n      (rst_n),
    .start      (start),

    .q_init_en  (q_init_en),
    .q_init_we_n(q_init_we_n),
    .q_init_addr(q_init_addr),
    .q_init_din (q_init_din),

    .k_init_en  (k_init_en),
    .k_init_we_n(k_init_we_n),
    .k_init_addr(k_init_addr),
    .k_init_din (k_init_din),

    .v_init_en  (v_init_en),
    .v_init_we_n(v_init_we_n),
    .v_init_addr(v_init_addr),
    .v_init_din (v_init_din),

    .out_valid  (out_valid),
    .out_row    (out_row),
    .out_group  (out_group),
    .out_data   (out_data),

    .busy       (busy),
    .done       (done)
  );

  // clock
  initial clk = 1'b0;
  always #5 clk = ~clk;

  // pack helpers
  function automatic logic [127:0] pack4(
    input logic [31:0] l0,
    input logic [31:0] l1,
    input logic [31:0] l2,
    input logic [31:0] l3
  );
    pack4 = {l3, l2, l1, l0};
  endfunction

  function automatic logic [31:0] fp32_from_real(input real r);
    shortreal sr;
    begin
      sr = r;
      fp32_from_real = $shortrealtobits(sr);
    end
  endfunction

  function automatic real real_from_fp32(input logic [31:0] x);
    shortreal sr;
    begin
      sr = $bitstoshortreal(x);
      real_from_fp32 = sr;
    end
  endfunction

  function automatic real abs_real(input real x);
    if (x < 0.0) abs_real = -x;
    else        abs_real =  x;
  endfunction

  // Taylor exp: 1 + x + x^2/2 + x^3/6
  function automatic real taylor_exp3(input real x);
    real x2, x3;
    begin
      x2 = x * x;
      x3 = x2 * x;
      taylor_exp3 = 1.0 + x + 0.5*x2 + (1.0/6.0)*x3;
    end
  endfunction

  // init write tasks
  task automatic q_write(input logic [6:0] addr, input logic [127:0] data);
    begin
      @(negedge clk);
      q_init_en   = 1'b1;
      q_init_we_n = 1'b0;
      q_init_addr = addr;
      q_init_din  = data;
      @(posedge clk);
      @(negedge clk);
      q_init_we_n = 1'b1;
      q_init_en   = 1'b0;
    end
  endtask

  task automatic k_write(input logic [6:0] addr, input logic [127:0] data);
    begin
      @(negedge clk);
      k_init_en   = 1'b1;
      k_init_we_n = 1'b0;
      k_init_addr = addr;
      k_init_din  = data;
      @(posedge clk);
      @(negedge clk);
      k_init_we_n = 1'b1;
      k_init_en   = 1'b0;
    end
  endtask

  task automatic v_write(input logic [6:0] addr, input logic [127:0] data);
    begin
      @(negedge clk);
      v_init_en   = 1'b1;
      v_init_we_n = 1'b0;
      v_init_addr = addr;
      v_init_din  = data;
      @(posedge clk);
      @(negedge clk);
      v_init_we_n = 1'b1;
      v_init_en   = 1'b0;
    end
  endtask

 
  // Expected weight table for MHA4 (Taylor-softmax after scaling)

  real W [0:3][0:3][0:3];
  real Wsum [0:3][0:3];

  task automatic build_weights_mha4;
    integer h, r, c;
    real x, e, s;
    begin
      for (h = 0; h < 4; h = h + 1) begin
        for (r = 0; r < 4; r = r + 1) begin
          s = 0.0;
          for (c = 0; c < 4; c = c + 1) begin
            if (h == 0) begin
              x = (r == c) ? 0.0 : (-100.0 / SQRT32);
            end else begin
              x = 0.0;
            end
            e = taylor_exp3(x);
            W[h][r][c] = e; // store exp temporarily
            s = s + e;
          end
          Wsum[h][r] = s;
          for (c = 0; c < 4; c = c + 1) begin
            W[h][r][c] = W[h][r][c] / s;
          end
        end
      end

      $display("--------------------------------------------------");
      $display("[TB_EXPECT] Taylor-softmax weights per head (after scaling by 1/sqrt(32))");
      for (h = 0; h < 4; h = h + 1) begin
        $display("  HEAD %0d:", h);
        for (r = 0; r < 4; r = r + 1) begin
          $display("    row%0d: W=%f %f %f %f | sumW=%f",
            r, W[h][r][0], W[h][r][1], W[h][r][2], W[h][r][3],
            (W[h][r][0]+W[h][r][1]+W[h][r][2]+W[h][r][3])
          );
        end
      end
      $display("--------------------------------------------------");
    end
  endtask

 
  // init & stimulus
 
  integer i, t, lane;
  integer k, g;
  integer idx;
  integer col;

  logic [31:0] w0, w1, w2, w3;
  logic [6:0]  addr7;

  real got0, got1, got2, got3;
  real exp0, exp1, exp2, exp3;
  real diff0, diff1, diff2, diff3;

  int out_count;
  int err_count;

  initial begin
    // init signals
    rst_n = 1'b0;
    start = 1'b0;

    q_init_en = 1'b0; q_init_we_n = 1'b1; q_init_addr = 7'd0; q_init_din = 128'd0;
    k_init_en = 1'b0; k_init_we_n = 1'b1; k_init_addr = 7'd0; k_init_din = 128'd0;
    v_init_en = 1'b0; v_init_we_n = 1'b1; v_init_addr = 7'd0; v_init_din = 128'd0;

    out_count = 0;
    err_count = 0;

    repeat (5) @(posedge clk);
    rst_n = 1'b1;
    repeat (2) @(posedge clk);

    // -------------------------
    // Q init:
    // row i => one-hot at global dim idx==i (only dims 0..3 are 1.0)
    // addr = i*32 + tile(0..31)
    // -------------------------
    for (i = 0; i < 4; i = i + 1) begin
      for (t = 0; t < 32; t = t + 1) begin
        for (lane = 0; lane < 4; lane = lane + 1) begin
          idx = t*4 + lane;
          if (idx == i) begin
            if (lane == 0) w0 = 32'h3f800000; // 1.0
            if (lane == 1) w1 = 32'h3f800000;
            if (lane == 2) w2 = 32'h3f800000;
            if (lane == 3) w3 = 32'h3f800000;
          end else begin
            if (lane == 0) w0 = 32'h00000000;
            if (lane == 1) w1 = 32'h00000000;
            if (lane == 2) w2 = 32'h00000000;
            if (lane == 3) w3 = 32'h00000000;
          end
        end
        addr7 = (i*32 + t);
        q_write(addr7, pack4(w0,w1,w2,w3));
      end
    end

    // -------------------------
    // K init:
    // row j => element[j]=0.0, others=-100.0 (for all 128 dims)
    // addr = j*32 + tile(0..31)
    // -------------------------
    for (i = 0; i < 4; i = i + 1) begin
      for (t = 0; t < 32; t = t + 1) begin
        for (lane = 0; lane < 4; lane = lane + 1) begin
          idx = t*4 + lane;
          if (idx == i) begin
            if (lane == 0) w0 = 32'h00000000;
            if (lane == 1) w1 = 32'h00000000;
            if (lane == 2) w2 = 32'h00000000;
            if (lane == 3) w3 = 32'h00000000;
          end else begin
            if (lane == 0) w0 = 32'hc2c80000; // -100.0
            if (lane == 1) w1 = 32'hc2c80000;
            if (lane == 2) w2 = 32'hc2c80000;
            if (lane == 3) w3 = 32'hc2c80000;
          end
        end
        addr7 = (i*32 + t);
        k_write(addr7, pack4(w0,w1,w2,w3));
      end
    end

    // -------------------------
    // V init (IMPORTANT: matches V address map used by head-tiling GEMM)
    //
    // V is 4x128 (k=0..3 rows, col=0..127).
    // We store by row-major tiles:
    //   addr = k*32 + tile(0..31)
    //   word lanes = V[k][4*tile + lane]
    //
    // Value pattern:
    //   V[k][col] = (1<<k) + 0.001*col
    // -------------------------
    for (k = 0; k < 4; k = k + 1) begin
      for (t = 0; t < 32; t = t + 1) begin
        col = 4*t + 0; w0 = fp32_from_real((1<<k) + 0.001*col);
        col = 4*t + 1; w1 = fp32_from_real((1<<k) + 0.001*col);
        col = 4*t + 2; w2 = fp32_from_real((1<<k) + 0.001*col);
        col = 4*t + 3; w3 = fp32_from_real((1<<k) + 0.001*col);
        addr7 = (k*32 + t);
        v_write(addr7, pack4(w0,w1,w2,w3));
      end
    end

    // build expected weights (Taylor-softmax, per head, after scaling)
    build_weights_mha4();

    repeat (5) @(posedge clk);

    // start pulse
    @(negedge clk);
    start = 1'b1;
    @(posedge clk);
    @(negedge clk);
    start = 1'b0;

    // timeout guard
    repeat (600000) @(posedge clk);
    $display("TIMEOUT: out_count=%0d err_count=%0d", out_count, err_count);
    $fatal(1);
  end


  // checker (compare against Taylor-softmax expected per head)
 
  int head;
  always @(posedge clk) begin
    if (out_valid) begin
      head = out_group[4:3];

      got0 = real_from_fp32(out_data[31:0]);
      got1 = real_from_fp32(out_data[63:32]);
      got2 = real_from_fp32(out_data[95:64]);
      got3 = real_from_fp32(out_data[127:96]);

      // lane0
      col  = 4*out_group + 0;
      exp0 = (W[head][out_row][0]*(1<<0) + W[head][out_row][1]*(1<<1)
            + W[head][out_row][2]*(1<<2) + W[head][out_row][3]*(1<<3))
           + 0.001*col*(W[head][out_row][0]+W[head][out_row][1]+W[head][out_row][2]+W[head][out_row][3]);

      // lane1
      col  = 4*out_group + 1;
      exp1 = (W[head][out_row][0]*(1<<0) + W[head][out_row][1]*(1<<1)
            + W[head][out_row][2]*(1<<2) + W[head][out_row][3]*(1<<3))
           + 0.001*col*(W[head][out_row][0]+W[head][out_row][1]+W[head][out_row][2]+W[head][out_row][3]);

      // lane2
      col  = 4*out_group + 2;
      exp2 = (W[head][out_row][0]*(1<<0) + W[head][out_row][1]*(1<<1)
            + W[head][out_row][2]*(1<<2) + W[head][out_row][3]*(1<<3))
           + 0.001*col*(W[head][out_row][0]+W[head][out_row][1]+W[head][out_row][2]+W[head][out_row][3]);

      // lane3
      col  = 4*out_group + 3;
      exp3 = (W[head][out_row][0]*(1<<0) + W[head][out_row][1]*(1<<1)
            + W[head][out_row][2]*(1<<2) + W[head][out_row][3]*(1<<3))
           + 0.001*col*(W[head][out_row][0]+W[head][out_row][1]+W[head][out_row][2]+W[head][out_row][3]);

      diff0 = abs_real(got0 - exp0);
      diff1 = abs_real(got1 - exp1);
      diff2 = abs_real(got2 - exp2);
      diff3 = abs_real(got3 - exp3);

      $display("OUT head=%0d row=%0d group=%0d got=%f %f %f %f | exp(TaylorSM)=%f %f %f %f | diff=%f %f %f %f",
               head, out_row, out_group, got0, got1, got2, got3, exp0, exp1, exp2, exp3, diff0, diff1, diff2, diff3);

      if ((diff0 > TOL) || (diff1 > TOL) || (diff2 > TOL) || (diff3 > TOL)) begin
        err_count++;
        $display("  MISMATCH(head=%0d row=%0d group=%0d) tol=%e", head, out_row, out_group, TOL);
      end

      out_count++;
    end

    if (done) begin
      $display("DONE pulse. out_count=%0d (expect %0d) err_count=%0d", out_count, TOTAL_OUT, err_count);
      if (out_count != TOTAL_OUT) $fatal(1, "FAIL: out_count mismatch");
      if (err_count != 0)         $fatal(1, "FAIL: err_count=%0d", err_count);
      $display("PASS (matched Taylor-softmax expectation, MHA4+scale)");
      $finish;
    end
  end

endmodule
