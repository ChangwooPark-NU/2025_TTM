`timescale 1ps/1ps

module attn_top_4x4_128_mha4 #(
  parameter int READ_LAT = 2
)(
  input  logic        clk,
  input  logic        rst_n,           // active-low 

  input  logic        start,           // start attention pipeline after Q/K/V ready

  // Q/K/V SRAM read interfaces (128-bit = 4 lanes fp32)
  output logic [6:0]  Q_mem_addr,
  output logic [6:0]  K_mem_addr,
  output logic [6:0]  V_mem_addr,

  input  logic [127:0] Q_mem_out,
  input  logic [127:0] K_mem_out,
  input  logic [127:0] V_mem_out,

  // Output stream
  output logic        out_valid,
  output logic [1:0]  out_row,
  output logic [4:0]  out_group,       // 0..31
  output logic [127:0] out_data,

  output logic        done
);

  localparam int MEM_WAIT = READ_LAT + 1;


  // SCORE (QK^T) 

  logic        score_busy, score_done;
  logic [2047:0] score_flat_all;


  logic [5:0]  score_rd_addr;
  logic        score_rd_en;
  logic [31:0] score_rd_data;

  logic score_start_pulse;

  score_calculation_4x128_regfile_mha4 U_SCORE (
    .clk(clk),
    .rst(rst_n),              
    .Q_mem_out(Q_mem_out),
    .K_mem_out(K_mem_out),
    .Reg_WrEn(score_start_pulse),

    .Q_mem_addr(Q_mem_addr),
    .K_mem_addr(K_mem_addr),

    .score_flat_all(score_flat_all),
    .score_rd_addr(score_rd_addr),
    .score_rd_en(score_rd_en),
    .score_rd_data(score_rd_data),

    .busy(score_busy),
    .done(score_done)
  );


  // SCALE

  logic        scale_start;
  logic        scale_done;
  logic [511:0] score_head_flat;
  logic [511:0] scaled_head_flat;

  scale U_SCALE (
    .clk(clk),
    .rst(~rst_n),              
    .start(scale_start),
    .score(score_flat_all[511:0]),
    .scaled_score(scaled_head_flat),
    .done(scale_done)
  );


  // SOFTMAX

  logic        sm_start[0:3];
  logic [31:0] sm_datain[0:3];
  logic [31:0] sm_y0[0:3], sm_y1[0:3], sm_y2[0:3], sm_y3[0:3];
  logic        sm_done[0:3];

  genvar r;
  generate
    for (r=0; r<4; r++) begin : GEN_SOFTMAX
      softmax U_SM (
        .Clock(clk),
        .Reset(~rst_n),          
        .Start(sm_start[r]),
        .Datain(sm_datain[r]),
        .N(3),                   
        .Y0(sm_y0[r]),
        .Y1(sm_y1[r]),
        .Y2(sm_y2[r]),
        .Y3(sm_y3[r]),
        .Done(sm_done[r])
      );
    end
  endgenerate

  // Pack weights for GEMM
  logic [511:0] W_flat;

  always_comb begin
    W_flat = '0;
    // row0
    W_flat[ 0*32 +: 32] = sm_y0[0];
    W_flat[ 1*32 +: 32] = sm_y1[0];
    W_flat[ 2*32 +: 32] = sm_y2[0];
    W_flat[ 3*32 +: 32] = sm_y3[0];
    // row1
    W_flat[ 4*32 +: 32] = sm_y0[1];
    W_flat[ 5*32 +: 32] = sm_y1[1];
    W_flat[ 6*32 +: 32] = sm_y2[1];
    W_flat[ 7*32 +: 32] = sm_y3[1];
    // row2
    W_flat[ 8*32 +: 32] = sm_y0[2];
    W_flat[ 9*32 +: 32] = sm_y1[2];
    W_flat[10*32 +: 32] = sm_y2[2];
    W_flat[11*32 +: 32] = sm_y3[2];
    // row3
    W_flat[12*32 +: 32] = sm_y0[3];
    W_flat[13*32 +: 32] = sm_y1[3];
    W_flat[14*32 +: 32] = sm_y2[3];
    W_flat[15*32 +: 32] = sm_y3[3];
  end


  // GEMM

  logic        gemm_start;
  logic [1:0]  head_sel;
  logic        gemm_busy, gemm_done;
  logic        gemm_out_valid;
  logic [1:0]  gemm_out_row;
  logic [2:0]  gemm_out_tile;
  logic [127:0] gemm_out_data;

  gemm_4x4_4x32_stream #(
    .READ_LAT(READ_LAT),
    .MEM_WAIT(MEM_WAIT),
    .V_BASE(7'd0)
  ) U_GEMM32 (
    .clk(clk),
    .rst_n(rst_n),
    .start(gemm_start),
    .head_sel(head_sel),
    .A_flat(W_flat),
    .V_mem_addr(V_mem_addr),
    .V_mem_out(V_mem_out),
    .out_valid(gemm_out_valid),
    .out_row(gemm_out_row),
    .out_tile_in_head(gemm_out_tile),
    .out_data(gemm_out_data),
    .busy(gemm_busy),
    .done(gemm_done)
  );


  always_comb begin
    out_valid = gemm_out_valid;
    out_row   = gemm_out_row;
    out_group = {head_sel, gemm_out_tile}; 
    out_data  = gemm_out_data;
  end


  // TOP FSM

  typedef enum logic [3:0] {
    T_IDLE          = 4'd0,
    T_SCORE_START   = 4'd1,
    T_SCORE_WAIT    = 4'd2,
    T_LOAD_ADDR     = 4'd3,
    T_LOAD_CAP      = 4'd4,
    T_SCALE_START   = 4'd5,
    T_SCALE_WAIT    = 4'd6,
    T_SM_START      = 4'd7,
    T_SM_STREAM     = 4'd8,
    T_SM_WAIT       = 4'd9,
    T_GEMM_START    = 4'd10,
    T_GEMM_WAIT     = 4'd11,
    T_NEXT_HEAD     = 4'd12,
    T_DONE          = 4'd13
  } top_state_t;

  top_state_t tstate;


  logic [31:0] score_head [0:15];
  logic [3:0]  load_idx;
  logic        load_phase; 


  logic [1:0] sm_col;

  // start edge detect for top start
  logic start_d;
  wire  start_pulse = start & ~start_d;


  always_ff @(posedge clk or negedge rst_n) begin
    int i;
    if (!rst_n) begin
      start_d <= 1'b0;

      tstate <= T_IDLE;
      done   <= 1'b0;

      score_start_pulse <= 1'b0;

      score_rd_en   <= 1'b0;
      score_rd_addr <= 6'd0;

      scale_start <= 1'b0;
      score_head_flat <= 512'd0;

      for (i=0; i<16; i++) score_head[i] <= 32'd0;

      for (i=0; i<4; i++) begin
        sm_start[i]  <= 1'b0;
        sm_datain[i] <= 32'd0;
      end

      head_sel <= 2'd0;

      load_idx   <= 4'd0;
      load_phase <= 1'b0;

      sm_col <= 2'd0;

      gemm_start <= 1'b0;

    end else begin
      start_d <= start;
      done   <= 1'b0;

      score_start_pulse <= 1'b0;
      gemm_start  <= 1'b0;

      // default: no new softmax start unless asserted in state
      sm_start[0] <= 1'b0;
      sm_start[1] <= 1'b0;
      sm_start[2] <= 1'b0;
      sm_start[3] <= 1'b0;

      case (tstate)
        T_IDLE: begin
          score_rd_en <= 1'b0;
          if (start_pulse) begin
            head_sel <= 2'd0;
            tstate <= T_SCORE_START;
          end
        end

        T_SCORE_START: begin
          score_start_pulse <= 1'b1; // pulse Reg_WrEn into SCORE
          tstate <= T_SCORE_WAIT;
        end

        T_SCORE_WAIT: begin
          if (score_done) begin
            // prepare to load 16 scores for head 0
            load_idx   <= 4'd0;
            load_phase <= 1'b0;
            tstate <= T_LOAD_ADDR;
          end
        end

        // Load score_reg[ head*16 + idx ] via score_rd port
        T_LOAD_ADDR: begin
          score_rd_en   <= 1'b1;
          score_rd_addr <= {head_sel, load_idx}; // 6-bit
          load_phase    <= 1'b1;
          tstate        <= T_LOAD_CAP;
        end

        T_LOAD_CAP: begin
          // capture registered output from previous cycle's addr
          score_head[load_idx] <= score_rd_data;

          if (load_idx == 4'd15) begin
            score_rd_en <= 1'b0;
            tstate <= T_SCALE_START;
          end else begin
            load_idx <= load_idx + 4'd1;
            tstate <= T_LOAD_ADDR;
          end
        end

        T_SCALE_START: begin
          // pack 16 scores LSB-first
          score_head_flat <= {
            score_head[15], score_head[14], score_head[13], score_head[12],
            score_head[11], score_head[10], score_head[ 9], score_head[ 8],
            score_head[ 7], score_head[ 6], score_head[ 5], score_head[ 4],
            score_head[ 3], score_head[ 2], score_head[ 1], score_head[ 0]
          };
          scale_start <= 1'b1;
          tstate <= T_SCALE_WAIT;
        end

        T_SCALE_WAIT: begin
	  scale_start <= 1'b1;	
	  if (scale_done) begin
            tstate <= T_SM_START;
          end
        end

        T_SM_START: begin
          // start 4 row-softmax engines simultaneously
          sm_start[0] <= 1'b1;
          sm_start[1] <= 1'b1;
          sm_start[2] <= 1'b1;
          sm_start[3] <= 1'b1;

          sm_col <= 2'd0;
          tstate <= T_SM_STREAM;
        end

        T_SM_STREAM: begin
          // stream 4 cycles: each cycle feeds column sm_col to all 4 rows
          sm_datain[0] <= scaled_head_flat[(0*4 + sm_col)*32 +: 32];
          sm_datain[1] <= scaled_head_flat[(1*4 + sm_col)*32 +: 32];
          sm_datain[2] <= scaled_head_flat[(2*4 + sm_col)*32 +: 32];
          sm_datain[3] <= scaled_head_flat[(3*4 + sm_col)*32 +: 32];

          if (sm_col == 2'd3) begin
            tstate <= T_SM_WAIT;
          end else begin
            sm_col <= sm_col + 2'd1;
          end
        end

        T_SM_WAIT: begin
          if (sm_done[0] && sm_done[1] && sm_done[2] && sm_done[3]) begin
            tstate <= T_GEMM_START;
          end
        end

        T_GEMM_START: begin
          gemm_start <= 1'b1;
          tstate <= T_GEMM_WAIT;
        end

        T_GEMM_WAIT: begin
          if (gemm_done) begin
            tstate <= T_DONE;
          end
        end

        T_NEXT_HEAD: begin
          if (head_sel == 2'd3) begin
            tstate <= T_DONE;
          end else begin
            head_sel <= head_sel + 2'd1;
            load_idx <= 4'd0;
            tstate <= T_LOAD_ADDR;
          end
        end

        T_DONE: begin
          done <= 1'b1;
          tstate <= T_IDLE;
        end

        default: tstate <= T_IDLE;
      endcase
    end
  end

endmodule
