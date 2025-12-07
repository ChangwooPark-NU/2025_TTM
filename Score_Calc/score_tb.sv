`timescale 1ps/1ps

module tb_score_calculation_4x128_regfile;

  // ------------------------
  // clock / reset
  // ------------------------
  logic clk;
  logic rst;         // DUT expects active-low
  logic Reg_WrEn;

  initial clk = 1'b0;
  always  #5000 clk = ~clk; // 10ns period

  // ------------------------
  // DUT <-> TB "SRAM" interface
  // ------------------------
  logic  [127:0] Q_mem_out;
  logic  [127:0] K_mem_out;
  wire   [6:0]   Q_mem_addr;
  wire   [6:0]   K_mem_addr;

  // score outputs
  wire [511:0] score_flat;
  logic [3:0]  score_rd_addr;
  logic        score_rd_en;
  wire [31:0]  score_rd_data;
  wire         busy;
  wire         done;

  // ------------------------
  // Instantiate DUT
  // ------------------------
  score_calculation_4x128_regfile dut (
    .clk(clk),
    .rst(rst),
    .Q_mem_out(Q_mem_out),
    .K_mem_out(K_mem_out),
    .Reg_WrEn(Reg_WrEn),

    .Q_mem_addr(Q_mem_addr),
    .K_mem_addr(K_mem_addr),

    .score_flat(score_flat),
    .score_rd_addr(score_rd_addr),
    .score_rd_en(score_rd_en),
    .score_rd_data(score_rd_data),

    .busy(busy),
    .done(done)
  );

  // ------------------------
  // SRAM model (depth 128, width 128)
  // 2-cycle synchronous read latency
  // ------------------------
  logic [127:0] Q_mem [0:127];
  logic [127:0] K_mem [0:127];

  logic [6:0] Q_addr_d1, Q_addr_d2;
  logic [6:0] K_addr_d1, K_addr_d2;

  always_ff @(posedge clk or negedge rst) begin
    if (!rst) begin
      Q_addr_d1 <= '0;
      Q_addr_d2 <= '0;
      K_addr_d1 <= '0;
      K_addr_d2 <= '0;
      Q_mem_out <= '0;
      K_mem_out <= '0;
    end else begin
      Q_addr_d1 <= Q_mem_addr;
      Q_addr_d2 <= Q_addr_d1;
      K_addr_d1 <= K_mem_addr;
      K_addr_d2 <= K_addr_d1;

      Q_mem_out <= Q_mem[Q_addr_d2];
      K_mem_out <= K_mem[K_addr_d2];
    end
  end

  // ------------------------
  // FP32 helpers (SystemVerilog)
  // ------------------------
  function automatic logic [31:0] fp32(input real r);
    shortreal sr;
    begin
      sr   = r;
      fp32 = $shortrealtobits(sr);
    end
  endfunction

  function automatic real fp32_to_real(input logic [31:0] bits);
    shortreal sr;
    begin
      sr = $bitstoshortreal(bits);
      fp32_to_real = sr;
    end
  endfunction

  function automatic logic [127:0] pack4(input logic [31:0] l0, l1, l2, l3);
    begin
      pack4 = {l3,l2,l1,l0};
    end
  endfunction

  function automatic logic [31:0] score_at(input int unsigned k);
    begin
      score_at = score_flat[32*k +: 32];
    end
  endfunction

  function automatic logic [31:0] expected_score_bits(input int unsigned i, input int unsigned j);
    real v;
    begin
      v = 64.0 * (i+1) * (j+1);
      expected_score_bits = fp32(v);
    end
  endfunction

  task automatic init_mem();
    int i, t, addr;
    logic [31:0] qv, kv;
    begin
      for (i=0; i<4; i=i+1) begin
        qv = fp32(1.0*(i+1));
        for (t=0; t<32; t=t+1) begin
          addr = i*32 + t;
          Q_mem[addr] = pack4(qv,qv,qv,qv);
        end
      end

      for (i=0; i<4; i=i+1) begin
        kv = fp32(0.5*(i+1));
        for (t=0; t<32; t=t+1) begin
          addr = i*32 + t;
          K_mem[addr] = pack4(kv,kv,kv,kv);
        end
      end
    end
  endtask

  // ------------------------
  // DEBUG MONITORS
  // ------------------------
  // Keep these localparams in TB matching DUT encoding
  localparam int S_IDLE      = 0;
  localparam int S_SET_ADDR  = 1;
  localparam int S_WAIT_MEM  = 2;
  localparam int S_LATCH_MEM = 3;
  localparam int S_START_MUL = 4;
  localparam int S_WAIT_MUL  = 5;
  localparam int S_START_L1  = 6;
  localparam int S_WAIT_L1   = 7;
  localparam int S_START_L2  = 8;
  localparam int S_WAIT_L2   = 9;
  localparam int S_START_ACC = 10;
  localparam int S_WAIT_ACC  = 11;
  localparam int S_NEXT_TILE = 12;
  localparam int S_WRITE     = 13;
  localparam int S_NEXT_IJ   = 14;

  int unsigned write_count;

  // state transitions + key fields
  logic [4:0] prev_state;
  always_ff @(posedge clk or negedge rst) begin
    if (!rst) begin
      prev_state  <= '0;
      write_count <= 0;
    end else begin
      // print on state change
      if (dut.state !== prev_state) begin
        $display("[%0t] state %0d -> %0d | i=%0d j=%0d t=%0d acc=0x%08x Qaddr=%0d Kaddr=%0d wait_cnt=%0d",
                 $time, prev_state, dut.state,
                 dut.i_idx, dut.j_idx, dut.t_idx, dut.acc,
                 dut.Q_mem_addr, dut.K_mem_addr, dut.wait_cnt);
        prev_state <= dut.state;
      end

      // print on every write
      if (dut.state == S_WRITE) begin
        write_count++;
        $display("[%0t] WRITE#%0d  (i=%0d j=%0d) idx=%0d  acc=0x%08x (%f)",
                 $time, write_count,
                 dut.i_idx, dut.j_idx, (dut.i_idx<<2)+dut.j_idx,
                 dut.acc, fp32_to_real(dut.acc));
      end

      // print when done rises
      if (done) begin
        $display("[%0t] DONE seen: write_count=%0d  final(i=%0d j=%0d t=%0d state=%0d busy=%0d)",
                 $time, write_count, dut.i_idx, dut.j_idx, dut.t_idx, dut.state, busy);
      end

      // simple sanity: detect X on addresses while busy
      if (busy) begin
        if (^Q_mem_addr === 1'bx) $display("[%0t] WARNING: Q_mem_addr has X: %b", $time, Q_mem_addr);
        if (^K_mem_addr === 1'bx) $display("[%0t] WARNING: K_mem_addr has X: %b", $time, K_mem_addr);
      end
    end
  end

`ifdef DUMP_VCD
  initial begin
    $dumpfile("waves.vcd");
    $dumpvars(0, tb_score_calculation_4x128_regfile);
  end
`endif

  // ------------------------
  // Main test
  // ------------------------
  initial begin
    int unsigned cyc;
    int ii, jj, k;
    logic [31:0] got, exp;
    int errors;

    Reg_WrEn      = 1'b0;
    score_rd_addr = 4'd0;
    score_rd_en   = 1'b0;

    init_mem();

    // reset (active-low)
    rst = 1'b0;
    repeat(8) @(posedge clk);
    rst = 1'b1;
    repeat(5) @(posedge clk);

    // start pulse (1 cycle)
    @(posedge clk);
    Reg_WrEn <= 1'b1;
    @(posedge clk);
    Reg_WrEn <= 1'b0;

    // wait done
    for (cyc=0; cyc<400000; cyc=cyc+1) begin
      @(posedge clk);
      if (done) begin
        $display("[%0t] DONE at cycle %0d (busy=%0d)", $time, cyc, busy);
        break;
      end
    end
    if (!done) $fatal(1, "TIMEOUT: done not asserted");

    // check all 16 scores
    errors = 0;
    for (ii=0; ii<4; ii=ii+1) begin
      for (jj=0; jj<4; jj=jj+1) begin
        k   = ii*4 + jj;
        got = score_at(k);
        exp = expected_score_bits(ii,jj);

        if (got !== exp) begin
          errors++;
          $display("MISMATCH score(%0d,%0d) idx=%0d: got=0x%08x (%f) exp=0x%08x (%f)",
                   ii, jj, k,
                   got, fp32_to_real(got),
                   exp, fp32_to_real(exp));
        end else begin
          $display("OK score(%0d,%0d) = %f (0x%08x)",
                   ii, jj, fp32_to_real(got), got);
        end
      end
    end

    if (errors == 0) $display("ALL PASSED");
    else $fatal(1, "FAILED: %0d mismatches", errors);

    repeat(10) @(posedge clk);
    
    #100 $finish;
  end

endmodule
