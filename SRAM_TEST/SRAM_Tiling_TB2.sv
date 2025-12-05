`timescale 1ns/1ps

module tb_sram_tiling;

	// Define parameters 
	`ifndef N 
		`define N 4
	`endif

	`ifndef M 
		`define M 128
	`endif

  localparam N=`N;
  localparam M=`M;
	localparam DATA_WIDTH = 8; // Input bitwidth of each matrix entry
  localparam SRAM_Bit_WIDTH = 128; // Output bitwidth of each matrix entry
  localparam logic WEB_WRITE = 1'b0;
  localparam logic WEB_READ  = 1'b1;

  // ------------------------
  // DUT signals
  // ------------------------
  logic         clk;
  logic [4:0]   INPUT_MEM_ADDR;
  logic         INPUT_MEM_WEN;      // connects to .WEB
  logic [127:0] INPUT_MEM_DIN;
  wire  [127:0] INPUT_MEM_DOUT;
  logic [9:0]   Wq_MEM_ADDR;
  logic         Wq_MEM_WEN;      // connects to .WEB
  logic [127:0] Wq_MEM_DIN;
  wire  [127:0] Wq_MEM_DOUT;
	// Class to randomize input matrices 
	class random_matrices1; 
		rand logic signed [DATA_WIDTH-1:0] matrix_a [N-1:0][M-1:0]; 

	endclass	
  random_matrices1 rm1;
	class random_matrices2; 
		rand logic signed [DATA_WIDTH-1:0] matrix_b [M-1:0][M-1:0]; 

	endclass	
  random_matrices2 rm2;
  // ------------------------
  // Instantiate DUT (your wrapper)
  // ------------------------
  SRAM_TEST dut (
    .clk           (clk),
    .INPUT_MEM_ADDR(INPUT_MEM_ADDR),
    .INPUT_MEM_WEN (INPUT_MEM_WEN),
    .INPUT_MEM_DIN (INPUT_MEM_DIN),
    .INPUT_MEM_DOUT(INPUT_MEM_DOUT),
    .Wq_MEM_ADDR(Wq_MEM_ADDR),
    .Wq_MEM_WEN(Wq_MEM_WEN),
    .Wq_MEM_DIN(Wq_MEM_DIN),
    .Wq_MEM_DOUT(Wq_MEM_DOUT)
  );

  // ------------------------
  // Clock
  // ------------------------
  initial clk = 1'b0;
  always #5 clk = ~clk;

  // Pack 4x4 tile from rows 0..3 and cols c0..c0+3 into 128b
  function automatic logic [127:0] pack_tile_4x4_1(input int c0);
    logic [127:0] w_1;
    int r, c, idx;
    begin
      w_1   = '0;
      idx = 0;

      // din[127:120]=A[3][c0+3] ... din[7:0]=A[0][c0+0]
      for (r = 3; r >= 0; r--) begin
        for (c = 3; c >= 0; c--) begin
          w_1[127 - 8*idx -: 8] = rm1.matrix_a[r][c0 + c];
          idx++;
        end
      end
      return w_1;
    end
  endfunction

    // Pack B 4x4 tile at tile-row tr (0..31), tile-col tc (0..31) into 128b
    function automatic logic [127:0] pack_b_tile_4x4(input int tr, input int tc);
    logic [127:0] w_2;
    int r, c, idx;
    int r0, c0;
    begin
        w_2   = '0;
        idx = 0;
        r0  = tr * 4;
        c0  = tc * 4;

        // din[127:120]=B[r0+3][c0+3] ... din[7:0]=B[r0+0][c0+0]
        for (r = 3; r >= 0; r--) begin
        for (c = 3; c >= 0; c--) begin
            w_2[127 - 8*idx -: 8] = rm2.matrix_b[r0 + r][c0 + c];
            idx++;
        end
        end
        return w_2;
    end
    endfunction


  // Write: setup before posedge, latch on posedge
  task automatic sram_write(input logic [4:0] addr, input logic [127:0] data);
    begin
      @(negedge clk);
      INPUT_MEM_ADDR <= addr;
      INPUT_MEM_DIN  <= data;
      INPUT_MEM_WEN  <= WEB_WRITE;

      @(posedge clk); // write happens here (assumption)

      @(negedge clk);
      INPUT_MEM_WEN  <= WEB_READ;
      INPUT_MEM_DIN  <= '0;
    end
  endtask

  task automatic sram_read(input logic [4:0] addr, output logic [127:0] data);
    begin
      @(negedge clk);
      INPUT_MEM_ADDR <= addr;
      INPUT_MEM_WEN  <= WEB_READ;

      // read latency? ????? ??? 2cycle ??
      @(posedge clk);
      @(posedge clk);
      data = INPUT_MEM_DOUT;
    end
  endtask
    task automatic wq_write(input logic [9:0] addr, input logic [127:0] data);
    begin
        @(negedge clk);
        Wq_MEM_ADDR <= addr;
        Wq_MEM_DIN  <= data;
        Wq_MEM_WEN  <= WEB_WRITE;

        @(posedge clk); // write latch

        @(negedge clk);
        Wq_MEM_WEN  <= WEB_READ;
        Wq_MEM_DIN  <= '0;
    end
    endtask

    task automatic wq_read(input logic [9:0] addr, output logic [127:0] data);
    begin
        @(negedge clk);
        Wq_MEM_ADDR <= addr;
        Wq_MEM_WEN  <= WEB_READ;

        @(posedge clk);
        @(posedge clk); // (Wq_mem? 2-cycle?? ??)
        data = Wq_MEM_DOUT;
    end
    endtask


  task automatic dump_a_to_csv(input string fname);
    int fd;
    fd = $fopen(fname, "w");
    if (fd == 0) begin
      $fatal(1, "Failed to open %s", fname);
    end

    // (optional) header
    // for (int c=0; c<M; c++) begin
    //   $fwrite(fd, "c%0d%s", c, (c==M-1) ? "\n" : ",");
    // end

    for (int r = 0; r < N; r++) begin
      for (int c = 0; c < M; c++) begin
        $fwrite(fd, "%0d", $signed(rm1.matrix_a[r][c]));
        if (c != M-1) $fwrite(fd, ",");
      end
      $fwrite(fd, "\n");
    end

    $fclose(fd);
    $display("Wrote Matrix A to %s", fname);
  endtask

    task automatic dump_b_to_csv(input string fname);
    int fd;
    fd = $fopen(fname, "w");
    if (fd == 0) $fatal(1, "Failed to open %s", fname);

    for (int r = 0; r < M; r++) begin
        for (int c = 0; c < M; c++) begin
        $fwrite(fd, "%0d", $signed(rm2.matrix_b[r][c]));
        if (c != M-1) $fwrite(fd, ",");
        end
        $fwrite(fd, "\n");
    end

    $fclose(fd);
    $display("Wrote Matrix B to %s", fname);
    endtask


  task automatic dump_sram_rows_to_csv(input string fname);
    int fd;
    int tile, c0;
    logic [127:0] w;

    fd = $fopen(fname, "w");
    if (fd == 0) $fatal(1, "Failed to open %s", fname);

    // header
    $fwrite(fd, "row,tile,c0,word_hex");

    for (int b = 0; b < 16; b++) $fwrite(fd, ",byte%0d", b);
    $fwrite(fd, "\n");

    for (int row = 0; row < 32; row++) begin
      sram_read(row[4:0], w);

        
        tile = row;
        c0   = row * 4;
        $fwrite(fd, "%0d,%0d,%0d,0x%032h", row, tile, c0, w);


      for (int b = 0; b < 16; b++) begin
        $fwrite(fd, ",%0d", $signed(w[127 - 8*b -: 8]));
      end
      $fwrite(fd, "\n");
    end

    $fclose(fd);
    $display("Wrote SRAM rows 0..31 to %s", fname);
  endtask

    task automatic dump_wq_rows_to_csv(input string fname);
    int fd;
    int tr, tc;
    logic [127:0] w;

    fd = $fopen(fname, "w");
    if (fd == 0) $fatal(1, "Failed to open %s", fname);

    $fwrite(fd, "row,tr,tc,word_hex");

    for (int b = 0; b < 16; b++) $fwrite(fd, ",byte%0d", b);
    $fwrite(fd, "\n");

    for (int row = 0; row < 1024; row++) begin
        wq_read(row[9:0], w);

        
        tr = row / (M/4);   // 32
        tc = row % (M/4);   // 32
        $fwrite(fd, "%0d,%0d,%0d,0x%032h", row, tr, tc, w);

        for (int b = 0; b < 16; b++) begin
        $fwrite(fd, ",%0d", $signed(w[127 - 8*b -: 8]));
        end
        $fwrite(fd, "\n");
    end

    $fclose(fd);
    $display("Wrote Wq_MEM rows 0..1023 to %s", fname);
    endtask


  initial begin
    int tile, c0;
    int tr, tc;
    int addr;

    // init
    INPUT_MEM_ADDR = '0;
    INPUT_MEM_DIN  = '0;
    INPUT_MEM_WEN  = WEB_READ;
    Wq_MEM_ADDR = '0;
    Wq_MEM_DIN  = '0;
    Wq_MEM_WEN  = WEB_READ;


    // randomize A(4x128)
    rm1 = new();
    rm1.srandom(32'hC0FFEE);
    rm2 = new();
    rm2.srandom(32'hDEADBEEF);
    assert(rm1.randomize());
    assert(rm2.randomize());
    dump_a_to_csv("matrix_a.csv");
    dump_b_to_csv("matrix_b.csv");

    // ??? ???:
    // SRAM row = tile_id
    // tile_id 0 -> cols 0..3
    // tile_id 1 -> cols 4..7
    // ...
    // tile_id 31 -> cols 124..127
    for (int tile = 0; tile < (M/4); tile++) begin
      sram_write(tile[4:0], pack_tile_4x4_1(tile * 4));
    end
    // ---- write B tiles into Wq_MEM (row-major) ----
    // addr = tr*32 + tc, where tr/tc in 0..31
    for (int tr = 0; tr < (M/4); tr++) begin
        for (int tc = 0; tc < (M/4); tc++) begin
            int addr;
            addr = tr*32 + tc;
            wq_write(addr[9:0], pack_b_tile_4x4(tr, tc));
        end
    end

    dump_sram_rows_to_csv("sram_dump_rows0_31.csv");
    dump_wq_rows_to_csv("wq_dump_rows0_1023.csv");

    $display("DONE: wrote %0d tiles into SRAM rows 0..%0d", (M/4), (M/4)-1);
    #200 $finish;
  end
endmodule
