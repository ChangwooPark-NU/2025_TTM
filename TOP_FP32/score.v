`timescale 1ps/1ps

module score_calculation_4x128_regfile_mha4 (
  input         clk,
  input         rst,         // active-low (top)
  input  [127:0] Q_mem_out,
  input  [127:0] K_mem_out,
  input         Reg_WrEn,    // start pulse (rising edge)

  output reg [6:0] Q_mem_addr,
  output reg [6:0] K_mem_addr,

  // score register file export options
  // 64 scores total: head(0..3) x i(0..3) x j(0..3)
  output [2047:0] score_flat_all, // {score[63],...,score[0]}
  input  [5:0]    score_rd_addr,  // 0..63
  input           score_rd_en,
  output reg [31:0] score_rd_data,

  output reg busy,
  output reg done
);
   logic [4:0] x; 
  // constants
  localparam [6:0] Q_BASE = 7'd0;
  localparam [6:0] K_BASE = 7'd0;

  localparam integer ROW_TILES = 32;  // 128/4
  localparam integer READ_LAT  = 2;   // TB SRAM pipeline latency
  localparam integer MEM_WAIT  = READ_LAT + 1; // =3 when READ_LAT=2

  // start pulse detect
  reg reg_wren_d;
  wire start = Reg_WrEn & ~reg_wren_d;

  // indices
  reg [1:0] i_idx, j_idx;
  reg [4:0] t_idx; // 0..31

  // Safe width-explicit offsets / indices
  wire [6:0] i_off = {i_idx, 5'b0};   // i*32
  wire [6:0] j_off = {j_idx, 5'b0};   // j*32
  wire [6:0] t_off = {2'b0, t_idx};   // 0..31 as 7-bit

  // (i,j) index
  wire [3:0] ij    = {i_idx, j_idx};  // 0..15
  // head index: 0..3 (8 tiles per head)
  wire [1:0] head  = t_idx[4:3];
  // head-local tile idx: 0..7
  wire [2:0] t_in_head = t_idx[2:0];
  wire       head_last = (t_in_head == 3'd7);

  // score register file: 64 regs (4 heads * 16 (i,j))
  reg [31:0] score_reg [0:63];

  // linear address: head*16 + ij
  wire [5:0] sidxH = x; // concatenation = head as MSBs + ij

  // export all scores as flat bus {score[63],...,score[0]}
  assign score_flat_all = {
    score_reg[63], score_reg[62], score_reg[61], score_reg[60],
    score_reg[59], score_reg[58], score_reg[57], score_reg[56],
    score_reg[55], score_reg[54], score_reg[53], score_reg[52],
    score_reg[51], score_reg[50], score_reg[49], score_reg[48],
    score_reg[47], score_reg[46], score_reg[45], score_reg[44],
    score_reg[43], score_reg[42], score_reg[41], score_reg[40],
    score_reg[39], score_reg[38], score_reg[37], score_reg[36],
    score_reg[35], score_reg[34], score_reg[33], score_reg[32],
    score_reg[31], score_reg[30], score_reg[29], score_reg[28],
    score_reg[27], score_reg[26], score_reg[25], score_reg[24],
    score_reg[23], score_reg[22], score_reg[21], score_reg[20],
    score_reg[19], score_reg[18], score_reg[17], score_reg[16],
    score_reg[15], score_reg[14], score_reg[13], score_reg[12],
    score_reg[11], score_reg[10], score_reg[ 9], score_reg[ 8],
    score_reg[ 7], score_reg[ 6], score_reg[ 5], score_reg[ 4],
    score_reg[ 3], score_reg[ 2], score_reg[ 1], score_reg[ 0]
  };

  // read port
  always @(posedge clk or negedge rst) begin
    if (!rst) begin
      score_rd_data <= 32'b0;
      x <= 0; 
    end else begin
      if (score_rd_en) begin
        score_rd_data <= score_reg[score_rd_addr];
      end
    end
  end

  // latch tile lanes
  reg [31:0] q0,q1,q2,q3;
  reg [31:0] k0,k1,k2,k3;

  wire [31:0] Q_lane0 = Q_mem_out[31:0];
  wire [31:0] Q_lane1 = Q_mem_out[63:32];
  wire [31:0] Q_lane2 = Q_mem_out[95:64];
  wire [31:0] Q_lane3 = Q_mem_out[127:96];

  wire [31:0] K_lane0 = K_mem_out[31:0];
  wire [31:0] K_lane1 = K_mem_out[63:32];
  wire [31:0] K_lane2 = K_mem_out[95:64];
  wire [31:0] K_lane3 = K_mem_out[127:96];

  // FP units reset (adder/mul are async active-high reset)
  // top rst is active-low -> generate a clean rst_fp pulse
  reg rst_fp;
  always @(posedge clk or negedge rst) begin
    if (!rst) rst_fp <= 1'b1;
    else      rst_fp <= 1'b0;
  end

  // multipliers (4) + handshake
  reg  m0_a_stb, m0_b_stb, m1_a_stb, m1_b_stb, m2_a_stb, m2_b_stb, m3_a_stb, m3_b_stb;
  wire m0_a_ack, m0_b_ack, m1_a_ack, m1_b_ack, m2_a_ack, m2_b_ack, m3_a_ack, m3_b_ack;
  wire m0_out_stb, m1_out_stb, m2_out_stb, m3_out_stb;
  wire [31:0] m0_z, m1_z, m2_z, m3_z;

  multiplier M0(
    .input_a(q0), .input_b(k0),
    .input_a_stb(m0_a_stb), .input_b_stb(m0_b_stb),
    .output_z_ack(1'b1),
    .clk(clk), .rst(rst_fp),
    .output_z(m0_z), .output_z_stb(m0_out_stb),
    .input_a_ack(m0_a_ack), .input_b_ack(m0_b_ack)
  );
  multiplier M1(
    .input_a(q1), .input_b(k1),
    .input_a_stb(m1_a_stb), .input_b_stb(m1_b_stb),
    .output_z_ack(1'b1),
    .clk(clk), .rst(rst_fp),
    .output_z(m1_z), .output_z_stb(m1_out_stb),
    .input_a_ack(m1_a_ack), .input_b_ack(m1_b_ack)
  );
  multiplier M2(
    .input_a(q2), .input_b(k2),
    .input_a_stb(m2_a_stb), .input_b_stb(m2_b_stb),
    .output_z_ack(1'b1),
    .clk(clk), .rst(rst_fp),
    .output_z(m2_z), .output_z_stb(m2_out_stb),
    .input_a_ack(m2_a_ack), .input_b_ack(m2_b_ack)
  );
  multiplier M3(
    .input_a(q3), .input_b(k3),
    .input_a_stb(m3_a_stb), .input_b_stb(m3_b_stb),
    .output_z_ack(1'b1),
    .clk(clk), .rst(rst_fp),
    .output_z(m3_z), .output_z_stb(m3_out_stb),
    .input_a_ack(m3_a_ack), .input_b_ack(m3_b_ack)
  );

  reg [31:0] p0,p1,p2,p3;
  reg p0_done, p1_done, p2_done, p3_done;

  // adders: partial tree + accumulator add
  reg  a01_a_stb, a01_b_stb, a23_a_stb, a23_b_stb, af_a_stb, af_b_stb, aa_a_stb, aa_b_stb;
  wire a01_a_ack, a01_b_ack, a23_a_ack, a23_b_ack, af_a_ack, af_b_ack, aa_a_ack, aa_b_ack;
  wire a01_out_stb, a23_out_stb, af_out_stb, aa_out_stb;
  wire [31:0] s01_w, s23_w, partial_w, acc_w;

  reg [31:0] s01, s23, partial;
  reg [31:0] acc;
  reg s01_done, s23_done;

  adder A01(
    .input_a(p0), .input_b(p1),
    .input_a_stb(a01_a_stb), .input_b_stb(a01_b_stb),
    .output_z_ack(1'b1),
    .clk(clk), .rst(rst_fp),
    .output_z(s01_w), .output_z_stb(a01_out_stb),
    .input_a_ack(a01_a_ack), .input_b_ack(a01_b_ack)
  );

  adder A23(
    .input_a(p2), .input_b(p3),
    .input_a_stb(a23_a_stb), .input_b_stb(a23_b_stb),
    .output_z_ack(1'b1),
    .clk(clk), .rst(rst_fp),
    .output_z(s23_w), .output_z_stb(a23_out_stb),
    .input_a_ack(a23_a_ack), .input_b_ack(a23_b_ack)
  );

  adder AF(
    .input_a(s01), .input_b(s23),
    .input_a_stb(af_a_stb), .input_b_stb(af_b_stb),
    .output_z_ack(1'b1),
    .clk(clk), .rst(rst_fp),
    .output_z(partial_w), .output_z_stb(af_out_stb),
    .input_a_ack(af_a_ack), .input_b_ack(af_b_ack)
  );

  adder AACC(
    .input_a(acc), .input_b(partial),
    .input_a_stb(aa_a_stb), .input_b_stb(aa_b_stb),
    .output_z_ack(1'b1),
    .clk(clk), .rst(rst_fp),
    .output_z(acc_w), .output_z_stb(aa_out_stb),
    .input_a_ack(aa_a_ack), .input_b_ack(aa_b_ack)
  );

  // FSM
  localparam [4:0]
    S_IDLE      = 5'd0,
    S_SET_ADDR  = 5'd1,
    S_WAIT_MEM  = 5'd2,
    S_LATCH_MEM = 5'd3,
    S_START_MUL = 5'd4,
    S_WAIT_MUL  = 5'd5,
    S_START_L1  = 5'd6,
    S_WAIT_L1   = 5'd7,
    S_START_L2  = 5'd8,
    S_WAIT_L2   = 5'd9,
    S_START_ACC = 5'd10,
    S_WAIT_ACC  = 5'd11,
    S_NEXT_TILE = 5'd12,
    S_NEXT_IJ   = 5'd13;

  reg [4:0] state;
  integer wait_cnt;
  integer idx;

  always @(posedge clk or negedge rst) begin
    if (!rst) begin
      reg_wren_d <= 1'b0;

      state <= S_IDLE;
      busy  <= 1'b0;
      done  <= 1'b0;

      i_idx <= 2'd0; j_idx <= 2'd0; t_idx <= 5'd0;
      Q_mem_addr <= Q_BASE;
      K_mem_addr <= K_BASE;
      wait_cnt <= 0;

      // clear stbs
      m0_a_stb<=0; m0_b_stb<=0; m1_a_stb<=0; m1_b_stb<=0;
      m2_a_stb<=0; m2_b_stb<=0; m3_a_stb<=0; m3_b_stb<=0;
      a01_a_stb<=0; a01_b_stb<=0; a23_a_stb<=0; a23_b_stb<=0;
      af_a_stb<=0;  af_b_stb<=0;  aa_a_stb<=0;  aa_b_stb<=0;

      q0<=0; q1<=0; q2<=0; q3<=0;
      k0<=0; k1<=0; k2<=0; k3<=0;

      p0<=0; p1<=0; p2<=0; p3<=0;
      p0_done<=0; p1_done<=0; p2_done<=0; p3_done<=0;

      s01<=0; s23<=0; partial<=0;
      acc<=32'h0000_0000;
      s01_done <= 0;
      s23_done <= 0;

      for (idx=0; idx<64; idx=idx+1) begin
        score_reg[idx] <= 32'b0;
      end

    end else begin
      reg_wren_d <= Reg_WrEn;
      done <= 1'b0; // default pulse

      case (state)
        S_IDLE: begin
          busy <= 1'b0;
          if (start) begin
            busy <= 1'b1;
            i_idx <= 0; j_idx <= 0; t_idx <= 0;
            acc   <= 32'h0000_0000;
            state <= S_SET_ADDR;
          end
        end

        S_SET_ADDR: begin
          Q_mem_addr <= Q_BASE + i_idx + t_off;
          K_mem_addr <= K_BASE + j_idx + t_off;
          wait_cnt <= 0;
          state <= S_WAIT_MEM;
 
  	end

        S_WAIT_MEM: begin
          if (wait_cnt == MEM_WAIT) state <= S_LATCH_MEM;
          else wait_cnt <= wait_cnt + 1;
        end

        S_LATCH_MEM: begin
          q0 <= Q_lane0; q1 <= Q_lane1; q2 <= Q_lane2; q3 <= Q_lane3;
          k0 <= K_lane0; k1 <= K_lane1; k2 <= K_lane2; k3 <= K_lane3;
          state <= S_START_MUL;
        end

        S_START_MUL: begin
          p0_done<=0; p1_done<=0; p2_done<=0; p3_done<=0;
          m0_a_stb<=1; m0_b_stb<=1;
          m1_a_stb<=1; m1_b_stb<=1;
          m2_a_stb<=1; m2_b_stb<=1;
          m3_a_stb<=1; m3_b_stb<=1;
          state <= S_WAIT_MUL;
        end

        S_WAIT_MUL: begin
          if (m0_a_ack) m0_a_stb<=0; if (m0_b_ack) m0_b_stb<=0;
          if (m1_a_ack) m1_a_stb<=0; if (m1_b_ack) m1_b_stb<=0;
          if (m2_a_ack) m2_a_stb<=0; if (m2_b_ack) m2_b_stb<=0;
          if (m3_a_ack) m3_a_stb<=0; if (m3_b_ack) m3_b_stb<=0;

          if (m0_out_stb && !p0_done) begin p0<=m0_z; p0_done<=1; end
          if (m1_out_stb && !p1_done) begin p1<=m1_z; p1_done<=1; end
          if (m2_out_stb && !p2_done) begin p2<=m2_z; p2_done<=1; end
          if (m3_out_stb && !p3_done) begin p3<=m3_z; p3_done<=1; end

          if (p0_done && p1_done && p2_done && p3_done) state <= S_START_L1;
        end

        S_START_L1: begin
          s01_done <= 0;
          s23_done <= 0;
          a01_a_stb<=1; a01_b_stb<=1;
          a23_a_stb<=1; a23_b_stb<=1;
          state <= S_WAIT_L1;
        end

        S_WAIT_L1: begin
          if (a01_a_ack) a01_a_stb <= 0;
          if (a01_b_ack) a01_b_stb <= 0;
          if (a23_a_ack) a23_a_stb <= 0;
          if (a23_b_ack) a23_b_stb <= 0;

          if (a01_out_stb && !s01_done) begin
            s01 <= s01_w;
            s01_done <= 1'b1;
          end

          if (a23_out_stb && !s23_done) begin
            s23 <= s23_w;
            s23_done <= 1'b1;
          end

          if (s01_done && s23_done) begin
            state <= S_START_L2;
          end
        end

        S_START_L2: begin
          af_a_stb<=1; af_b_stb<=1;
          state <= S_WAIT_L2;
        end

        S_WAIT_L2: begin
          if (af_a_ack) af_a_stb<=0;
          if (af_b_ack) af_b_stb<=0;

          if (af_out_stb) begin
            partial <= partial_w;
            state <= S_START_ACC;
          end
        end

        S_START_ACC: begin
          aa_a_stb<=1; aa_b_stb<=1;
          state <= S_WAIT_ACC;
        end

        S_WAIT_ACC: begin
          if (aa_a_ack) aa_a_stb<=0;
          if (aa_b_ack) aa_b_stb<=0;

          if (aa_out_stb) begin
            // head boundary: store acc_w and reset accumulator for next head
            if (head_last) begin
              score_reg[sidxH] <= acc;
            end else begin
              acc <= acc_w;
            end
            state <= S_NEXT_TILE;
          end
        end

        S_NEXT_TILE: begin
          if (t_idx == 28) begin
            state <= S_NEXT_IJ;
          end else begin
            t_idx <= t_idx + 4;
            state <= S_SET_ADDR;
          end
        end

        S_NEXT_IJ: begin
          // next (i,j), restart t_idx and accumulator (already reset at head_last when t_idx==31)
          t_idx <= 0;
          score_reg[x] <= acc_w;
	  acc<= 32'h0000_0000;
	  x <= x + 1; 
	  
            if (i_idx == 3 && j_idx == 3) begin
              done <= 1'b1;
              state <= S_IDLE;
              busy <= 1'b0;
            end else begin
	      if (j_idx == 3) begin 
		      j_idx <= 0; 
		      i_idx <= i_idx + 1; 
	      end 
	      else j_idx <= j_idx + 1; 
	      state <= S_SET_ADDR;
            end
        end

        default: state <= S_IDLE;
      endcase
    end
  end

endmodule
