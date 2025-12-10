`timescale 1ps/1ps

module gemm_4x4_4x32_stream #(
  parameter int READ_LAT = 2,
  parameter int MEM_WAIT = READ_LAT + 1,
  parameter logic [6:0] V_BASE = 7'd0
)(
  input  logic         clk,
  input  logic         rst_n,

  input  logic         start,
  input  logic [1:0]   head_sel,
  input  logic [511:0] A_flat,

  output logic [6:0]   V_mem_addr,
  input  logic [127:0] V_mem_out,

  output logic         out_valid,
  output logic [1:0]   out_row,
  output logic [2:0]   out_tile_in_head,
  output logic [127:0] out_data,

  output logic         busy,
  output logic         done
);

  logic [31:0] A [0:15];
  genvar ai;
  generate
    for (ai=0; ai<16; ai++) begin : GEN_A_UNPACK
      assign A[ai] = A_flat[ai*32 +: 32];
    end
  endgenerate

  logic [31:0] v_lane [0:3];
  assign v_lane[0] = V_mem_out[ 31:  0];
  assign v_lane[1] = V_mem_out[ 63: 32];
  assign v_lane[2] = V_mem_out[ 95: 64];
  assign v_lane[3] = V_mem_out[127: 96];

  logic [31:0] v_lat[0:3];

  logic rst_fp;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) rst_fp <= 1'b1;
    else        rst_fp <= 1'b0;
  end

  logic [1:0] i_idx;
  logic [2:0] t_idx;
  logic [1:0] j_idx;

  logic [4:0] global_tile;
  assign global_tile = {head_sel, t_idx};

  logic [6:0] j_off;
  assign j_off = {j_idx, 5'b0};

  logic [31:0] acc_lane [0:3];
  logic [31:0] prod_lane[0:3];

  logic [31:0] w_ij;
  assign w_ij = A[{i_idx, j_idx}];

  logic [3:0] m_a_stb, m_b_stb;
  logic [3:0] m_a_ack, m_b_ack;
  logic [3:0] m_out_stb;
  logic [31:0] m_z[0:3];

  genvar ml;
  generate
    for (ml=0; ml<4; ml++) begin : GEN_MUL
      multiplier MUL_U (
        .input_a(w_ij),
        .input_b(v_lat[ml]),
        .input_a_stb(m_a_stb[ml]),
        .input_b_stb(m_b_stb[ml]),
        .output_z_ack(1'b1),
        .clk(clk),
        .rst(rst_fp),
        .output_z(m_z[ml]),
        .output_z_stb(m_out_stb[ml]),
        .input_a_ack(m_a_ack[ml]),
        .input_b_ack(m_b_ack[ml])
      );
    end
  endgenerate

  logic [3:0] a_a_stb, a_b_stb;
  logic [3:0] a_a_ack, a_b_ack;
  logic [3:0] a_out_stb;
  logic [31:0] a_z[0:3];

  genvar al;
  generate
    for (al=0; al<4; al++) begin : GEN_ADD
      adder ADD_U (
        .input_a(acc_lane[al]),
        .input_b(prod_lane[al]),
        .input_a_stb(a_a_stb[al]),
        .input_b_stb(a_b_stb[al]),
        .output_z_ack(1'b1),
        .clk(clk),
        .rst(rst_fp),
        .output_z(a_z[al]),
        .output_z_stb(a_out_stb[al]),
        .input_a_ack(a_a_ack[al]),
        .input_b_ack(a_b_ack[al])
      );
    end
  endgenerate

  typedef enum logic [3:0] {
    S_IDLE      = 4'd0,
    S_SET_ADDR  = 4'd1,
    S_WAIT_MEM  = 4'd2,
    S_LATCH_V   = 4'd3,
    S_START_MUL = 4'd4,
    S_WAIT_MUL  = 4'd5,
    S_START_ADD = 4'd6,
    S_WAIT_ADD  = 4'd7,
    S_NEXT_J    = 4'd8,
    S_EMIT      = 4'd9,
    S_NEXT_T    = 4'd10,
    S_NEXT_I    = 4'd11,
    S_DONE      = 4'd12
  } state_t;

  state_t state;
  int wait_cnt;

  logic [3:0] m_done;
  logic [3:0] a_done;

  always_ff @(posedge clk or negedge rst_n) begin
    int l;
    if (!rst_n) begin
      state <= S_IDLE;
      busy  <= 1'b0;
      done  <= 1'b0;

      i_idx <= 2'd0;
      t_idx <= 3'd0;
      j_idx <= 2'd0;

      V_mem_addr <= V_BASE;

      out_valid <= 1'b0;
      out_row   <= 2'd0;
      out_tile_in_head <= 3'd0;
      out_data  <= 128'd0;

      wait_cnt <= 0;

      for (l=0; l<4; l++) begin
        acc_lane[l] <= 32'h00000000;
        prod_lane[l] <= 32'h00000000;
        v_lat[l] <= 32'h00000000;
      end

      m_a_stb <= 4'b0000;
      m_b_stb <= 4'b0000;
      a_a_stb <= 4'b0000;
      a_b_stb <= 4'b0000;

      m_done  <= 4'b0000;
      a_done  <= 4'b0000;

    end else begin
      done      <= 1'b0;
      out_valid <= 1'b0;

      case (state)
        S_IDLE: begin
          busy <= 1'b0;
          if (start) begin
            busy <= 1'b1;
            i_idx <= 2'd0;
            t_idx <= 3'd0;
            j_idx <= 2'd0;

            for (l=0; l<4; l++) begin
              acc_lane[l] <= 32'h00000000;
              prod_lane[l] <= 32'h00000000;
            end

            state <= S_SET_ADDR;
          end
        end

        S_SET_ADDR: begin
          V_mem_addr <= V_BASE + j_off + global_tile;
          wait_cnt <= 0;
          state <= S_WAIT_MEM;
        end

        S_WAIT_MEM: begin
          if (wait_cnt == MEM_WAIT) state <= S_LATCH_V;
          else wait_cnt <= wait_cnt + 1;
        end

        S_LATCH_V: begin
          for (l=0; l<4; l++) begin
            v_lat[l] <= v_lane[l];
          end
          state <= S_START_MUL;
        end

        S_START_MUL: begin
          m_a_stb <= 4'b1111;
          m_b_stb <= 4'b1111;
          m_done  <= 4'b0000;
          state <= S_WAIT_MUL;
        end

        S_WAIT_MUL: begin
          for (l=0; l<4; l++) begin
            if (m_a_ack[l]) m_a_stb[l] <= 1'b0;
            if (m_b_ack[l]) m_b_stb[l] <= 1'b0;
            if (m_out_stb[l] && !m_done[l]) begin
              prod_lane[l] <= m_z[l];
              m_done[l] <= 1'b1;
            end
          end
          if (&m_done) begin
            state <= S_START_ADD;
          end
        end

        S_START_ADD: begin
          a_a_stb <= 4'b1111;
          a_b_stb <= 4'b1111;
          a_done  <= 4'b0000;
          state <= S_WAIT_ADD;
        end

        S_WAIT_ADD: begin
          for (l=0; l<4; l++) begin
            if (a_a_ack[l]) a_a_stb[l] <= 1'b0;
            if (a_b_ack[l]) a_b_stb[l] <= 1'b0;
            if (a_out_stb[l] && !a_done[l]) begin
              acc_lane[l] <= a_z[l];
              a_done[l] <= 1'b1;
            end
          end
          if (&a_done) begin
            state <= S_NEXT_J;
          end
        end

        S_NEXT_J: begin
          if (j_idx == 2'd3) begin
            state <= S_EMIT;
          end else begin
            j_idx <= j_idx + 2'd1;
            state <= S_SET_ADDR;
          end
        end

        S_EMIT: begin
          out_valid <= 1'b1;
          out_row   <= i_idx;
          out_tile_in_head <= t_idx;
          out_data  <= {acc_lane[3], acc_lane[2], acc_lane[1], acc_lane[0]};

          j_idx <= 2'd0;
          for (l=0; l<4; l++) begin
            acc_lane[l] <= 32'h00000000;
            prod_lane[l] <= 32'h00000000;
          end

          state <= S_NEXT_T;
        end

        S_NEXT_T: begin
          if (t_idx == 3'd7) begin
            t_idx <= 3'd0;
            state <= S_NEXT_I;
          end else begin
            t_idx <= t_idx + 3'd1;
            state <= S_SET_ADDR;
          end
        end

        S_NEXT_I: begin
          if (i_idx == 2'd3) begin
            state <= S_DONE;
          end else begin
            i_idx <= i_idx + 2'd1;
            state <= S_SET_ADDR;
          end
        end

        S_DONE: begin
          done <= 1'b1;
          busy <= 1'b0;
          state <= S_IDLE;
        end

        default: state <= S_IDLE;
      endcase
    end
  end

endmodule
