`timescale 1ns/1ps 

module q_projection_tb();
	
	// Clock generation 
	logic clk = 0; 
	always #5 clk = ~clk; 

	// Define signals 
	logic rst;
       	logic en;
        logic [127:0] INPUT_MEM_DOUT;
        logic INPUT_MEM_WEN;
        logic INPUT_MEM_CEB;
        logic [4:0] INPUT_MEM_ADDR;
        logic [127:0] Wq_MEM_DOUT;
        logic Wq_MEM_WEN;
        logic Wq_MEM_CEB;
        logic [9:0] Wq_MEM_ADDR;
        logic [127:0] OUTPUT_MEM_DOUT;
        logic OUTPUT_MEM_WEN;
        logic OUTPUT_MEM_CEB;
        logic [6:0] OUTPUT_MEM_ADDR;
	logic [127:0] INPUT_MEM_DIN; 
	logic [127:0] Wq_MEM_DIN; 
 	logic [127:0] OUTPUT_MEM_DIN; 	
	logic [4:0] init_input_addr;
  	logic [9:0] init_w_addr;
  	logic init_input_wen, init_w_wen; 
 	logic init;  
	logic fin; 
	logic [6:0] fin_output_addr; 
	logic fin_output_wen; 
	logic done; 	
	logic [511:0] out; 
	logic valid; 
	logic [31:0] fp32_d; 
	logic [511:0] fp32_q; 
	
	// Instantiate DUT 
	Q_Projection dut ( 
		.clk(clk), 
		.rst(rst), 
		.en(en),
		.out(out),
		.valid(valid), 	
		.INPUT_MEM_DOUT(INPUT_MEM_DOUT),
		.INPUT_MEM_WEN(INPUT_MEM_WEN), 
		.INPUT_MEM_CEB(INPUT_MEM_CEB), 
		.INPUT_MEM_ADDR(INPUT_MEM_ADDR),
		.Wq_MEM_DOUT(Wq_MEM_DOUT), 
		.Wq_MEM_WEN(Wq_MEM_WEN), 
		.Wq_MEM_CEB(Wq_MEM_CEB), 
		.Wq_MEM_ADDR(Wq_MEM_ADDR), 
		.OUTPUT_MEM_DOUT(OUTPUT_MEM_DOUT), 
		.OUTPUT_MEM_WEN(OUTPUT_MEM_WEN), 
		.OUTPUT_MEM_CEB(OUTPUT_MEM_CEB), 
		.OUTPUT_MEM_DIN(OUTPUT_MEM_DIN),
		.OUTPUT_MEM_ADDR(OUTPUT_MEM_ADDR)
	); 
	
	// Define input, weight, and output mems 
	input_mem INPUT_MEM (
		.SLP(1'b0), .SD(1'b0), .CLK(clk), .CEB(1'b0 /*init ? 1'b0 : INPUT_MEM_CEB*/), .WEB(init ? init_input_wen : INPUT_MEM_WEN),
		.CEBM(1'b0), .WEBM(1'b0), .A(init ? init_input_addr : INPUT_MEM_ADDR), .D(INPUT_MEM_DIN), .BWEB(128'd0),
		.AM(5'd0), .DM(128'b0), .BWEBM(128'b0), .BIST(1'b0), .RTSEL(2'b0), .WTSEL(2'b0),
		.Q(INPUT_MEM_DOUT)
	);

	Wq_mem Wq_MEM (
		.SLP(1'b0), .SD(1'b0), .CLK(clk), .CEB(1'b0 /*init ? 1'b0 : Wq_MEM_CEB*/), .WEB(init ? init_w_wen : Wq_MEM_WEN),
		.CEBM(1'b0), .WEBM(1'b0), .A(init ? init_w_addr : Wq_MEM_ADDR), .D(Wq_MEM_DIN), .BWEB(128'd0),
		.AM(10'd0), .DM(128'b0), .BWEBM(128'b0), .BIST(1'b0), .RTSEL(2'b0), .WTSEL(2'b0),
		.Q(Wq_MEM_DOUT)
	);
	
	q_proj_mem OUTPUT_MEM (
		.SLP(1'b0), .SD(1'b0), .CLK(clk), .CEB(1'b0), .WEB(fin ? fin_output_wen : OUTPUT_MEM_WEN),
		.CEBM(1'b0), .WEBM(1'b0), .A(fin ? fin_output_addr : OUTPUT_MEM_ADDR), .D(OUTPUT_MEM_DIN), .BWEB(128'd0),
		.AM(5'd0), .DM(128'b0), .BWEBM(128'b0), .BIST(1'b0), .RTSEL(2'b0), .WTSEL(2'b0),
		.Q(OUTPUT_MEM_DOUT)
	); 

	// ======================= SRAM INIT ==========================
	
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

	class random_matrices; 
		rand logic signed [DATA_WIDTH-1:0] matrix_a [N-1:0][M-1:0]; 
		rand logic signed [DATA_WIDTH-1:0] matrix_b [M-1:0][M-1:0]; 
	endclass	
  
	random_matrices obj;


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
		  w_1[127 - 8*idx -: 8] = obj.matrix_a[r][c0 + c];
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
		    w_2[127 - 8*idx -: 8] = obj.matrix_b[r0 + r][c0 + c];
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
	      init_input_addr <= addr;
	      INPUT_MEM_DIN  <= data;
	      init_input_wen  <= WEB_WRITE;

	      @(posedge clk); // write happens here (assumption)

	      @(negedge clk);
	      init_input_wen  <= WEB_READ;
	      INPUT_MEM_DIN  <= '0;
	    end
	  endtask

	  task automatic sram_read(input logic [4:0] addr, output logic [127:0] data);
	    begin
	      @(negedge clk);
	      init_input_addr <= addr;
	      init_input_wen  <= WEB_READ;

	      // read latency? ????? ??? 2cycle ??
	      @(posedge clk);
	      @(posedge clk);
	      data = INPUT_MEM_DOUT;
	    end
	  endtask

	  task automatic output_read(input logic [6:0] addr, output logic [127:0] data);
	    begin
	      @(negedge clk);
	      fin_output_addr <= addr;
	      fin_output_wen  <= WEB_READ;

	      // read latency? ????? ??? 2cycle ??
	      @(posedge clk);
	      @(posedge clk);
	      data = OUTPUT_MEM_DOUT;
	    end
	  endtask

	    task automatic wq_write(input logic [9:0] addr, input logic [127:0] data);
	    begin
		@(negedge clk);
		init_w_addr <= addr;
		Wq_MEM_DIN  <= data;
		init_w_wen  <= WEB_WRITE;

		@(posedge clk); // write latch

		@(negedge clk);
		init_w_wen  <= WEB_READ;
		Wq_MEM_DIN  <= '0;
	    end
	    endtask

	    task automatic wq_read(input logic [9:0] addr, output logic [127:0] data);
	    begin
		@(negedge clk);
		init_w_addr <= addr;
		init_w_wen  <= WEB_READ;

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
		$fwrite(fd, "%0d", $signed(obj.matrix_a[r][c]));
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
		$fwrite(fd, "%0d", $signed(obj.matrix_b[r][c]));
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
	    //$display("Wrote SRAM rows 0..31 to %s", fname);
	  endtask

	task automatic dump_output_rows_to_csv(input string fname);
		    int fd;
		    int tile, c0;
		    logic [127:0] w;

		    fd = $fopen("output.csv", "w");
		    if (fd == 0) $fatal(1, "Failed to open %s", fname);

		    // header
		    $fwrite(fd, "row,tile,c0,word_hex");

		    for (int b = 0; b < 16; b++) $fwrite(fd, ",byte%0d", b);
		    $fwrite(fd, "\n");

		    for (int row = 0; row < 128; row++) begin
		      output_read(row[6:0], w);

			tile = row;
			c0   = row * 4;
			$fwrite(fd, "%0d,%0d,%0d,0x%032h", row, tile, c0, w);


		      for (int b = 0; b < 16; b++) begin
			$fwrite(fd, ",%0d", $signed(w[127 - 8*b -: 8]));
		      end
		      $fwrite(fd, "\n");
		    end

		    $fclose(fd);
		    //$display("Wrote SRAM rows 0..31 to %s", fname);
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
	    //$display("Wrote Wq_MEM rows 0..1023 to %s", fname);
	    endtask
	    
	    logic [511:0] prev;   
	    integer my_f;
	    integer my_t;
	     
	    initial begin
		    int tile, c0;
		    int tr, tc;
		    int addr;  
		    
		    my_f = $fopen("q_out.txt", "w");
		    assert(my_f); 
		    my_t = $fopen("t_out.txt", "w"); 
		    assert(my_t); 
		    
		    // init
		    init_input_addr = '0;
		    INPUT_MEM_DIN  = '0;
		    init_input_wen  = WEB_READ;
		    init_w_addr = '0;
		    Wq_MEM_DIN  = '0;
		    init_w_wen  = WEB_READ;
		    init = 1;
		    fin = 0; 
		    // randomize A(4x128)
		    obj = new();
		    assert(obj.randomize());

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
			
		    init = 1; 
		    dump_sram_rows_to_csv("sram_dump_rows0_31.csv");
		    dump_wq_rows_to_csv("wq_dump_rows0_1023.csv");
		    init = 0;
		    rst = 1; 
		    #10 
		    rst = 0;
		    #10
		    en = 1;
		    #10
		    en = 0;  
		    for (int i = 0; i < 20000; i++) begin 	
			#10
			if (out !== prev) begin 
				$fwrite(my_t,"%x\n", out); 
				prev = out;
			end	
			if (valid) begin 
				for (int j = 0; j < 16; j++) begin 
					$fwrite(my_f, "%11d ", $signed(out[j*32+:32]));
				end 
				$fwrite(my_f, "\n");
			end 
		    end 	
		
		    $display("DONE: Wrote RTL result into q_out.txt");
		    
		    fin = 1; 
		    dump_output_rows_to_csv("output.csv"); 
		    $finish;   
	end
endmodule 



	
	
