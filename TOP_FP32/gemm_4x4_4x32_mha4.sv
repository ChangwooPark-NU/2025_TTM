`timescale 1ps/1ps

module gemm_4x4_4x128_mha4_stream #(
  parameter int READ_LAT = 2,
  parameter int MEM_WAIT = (READ_LAT + 1),
  parameter logic [6:0] V_BASE = 7'd0
)(
  input  logic         clk,
  input  logic         rst,          // active-low 
  input  logic         start,        // 1-cycle pulse

  // Attention weights for all heads
  input  logic [2047:0] attn_flat_all,

  // V SRAM interface (single port)
  output logic [6:0]    V_mem_addr,
  input  logic [127:0]  V_mem_out,

  // Streamed output: one 128-bit vector per (row, tile)
  output logic [127:0]  out_vec,
  output logic [1:0]    out_row,
  output logic [4:0]    out_tile,
  output logic          out_valid,

  output logic          busy,
  output logic          done
);


  function automatic logic [31:0] getA(
    input logic [2047:0] flat_all,
    input logic [1:0]    head,
    input logic [1:0]    i,
    input logic [1:0]    j
  );
    int base;
    int idx;
    begin
      base = head * 512;
      idx  = (i * 4) + j;
      getA = flat_all[base + (idx*32) +: 32];
    end
  endfunction


  // Index regs

  logic [1:0] i_idx;  
  logic [4:0] t_idx;   
  logic [1:0] j_idx;  

  logic [1:0] head;    
  assign head = t_idx[4:3];

  // Address 
  logic [6:0] j_off;
  logic [6:0] t_off;
  always_comb begin
    j_off = {j_idx, 5'b0};   // j*32
    t_off = {2'b0, t_idx};   // 0..31
  end


  // Latch V lanes

  logic [31:0] v0, v1, v2, v3;
  always_comb begin
    v0 = V_mem_out[31:0];
    v1 = V_mem_out[63:32];
    v2 = V_mem_out[95:64];
    v3 = V_mem_out[127:96];
  end


  // FP units (4 multipliers + 4 adders)

  logic [31:0] a_scalar;

  // Multiplier I/O
  logic m_stb_a [0:3], m_stb_b [0:3];
  logic m_ack_a [0:3], m_ack_b [0:3];
  logic m_out_stb [0:3];
  logic [31:0] m_z [0:3];

  // Adder I/O
  logic a_stb_a [0:3], a_stb_b [0:3];
  logic a_ack_a [0:3], a_ack_b [0:3];
  logic a_out_stb [0:3];
  logic [31:0] a_z [0:3];

  // Lane accumulators
  logic [31:0] acc0, acc1, acc2, acc3;

  // Products latched 
  logic [31:0] p0, p1, p2, p3;

  genvar L;
  generate
    for (L = 0; L < 4; L++) begin : GEN_MUL
      logic [31:0] b_lane;

      always_comb begin
        case (L)
          0: b_lane = v0;
          1: b_lane = v1;
          2: b_lane = v2;
          default: b_lane = v3;
        endcase
      end

      multiplier u_mul (
        .input_a      (a_scalar),
        .input_b      (b_lane),
        .input_a_stb  (m_stb_a[L]),
        .input_b_stb  (m_stb_b[L]),
        .output_z_ack (1'b1),
        .clk          (clk),
        .rst          (~rst),      
        .output_z     (m_z[L]),
        .output_z_stb (m_out_stb[L]),
        .input_a_ack  (m_ack_a[L]),
        .input_b_ack  (m_ack_b[L])
      );

      // Add acc_lane + prod_lane
      logic [31:0] acc_lane_in;

      always_comb begin
        case (L)
          0: acc_lane_in = acc0;
          1: acc_lane_in = acc1;
          2: acc_lane_in = acc2;
          default: acc_lane_in = acc3;
        endcase
      end

      adder u_add (
        .input_a      (acc_lane_in),
        .input_b      (m_z[L]),
        .input_a_stb  (a_stb_a[L]),
        .input_b_stb  (a_stb_b[L]),
        .output_z_ack (1'b1),
        .clk          (clk),
        .rst          (~rst),
        .output_z     (a_z[L]),
        .output_z_stb (a_out_stb[L]),
        .input_a_ack  (a_ack_a[L]),
        .input_b_ack  (a_ack_b[L])
      );
    end
  endgenerate

  // FSM

  typedef enum logic [3:0] {
    S_IDLE      = 4'd0,
    S_SET_ADDR  = 4'd1,
    S_WAIT_MEM  = 4'd2,
    S_START_MUL = 4'd3,
    S_WAIT_MUL  = 4'd4,
    S_START_ADD = 4'd5,
    S_WAIT_ADD  = 4'd6,
    S_NEXT_J    = 4'd7,
    S_EMIT      = 4'd8,
    S_NEXT_TILE = 4'd9,
    S_DONE      = 4'd10
  } state_t;

  state_t state;
  int wait_cnt;

  // Convenience checks
  logic mul_all_done;
  logic add_all_done;
  always_comb begin
    mul_all_done = (m_out_stb[0] & m_out_stb[1] & m_out_stb[2] & m_out_stb[3]);
    add_all_done = (a_out_stb[0] & a_out_stb[1] & a_out_stb[2] & a_out_stb[3]);
  end

  // Default outputs
  always_ff @(posedge clk or negedge rst) begin
    if (!rst) begin
      busy      <= 1'b0;
      done      <= 1'b0;
      out_valid <= 1'b0;
      out_vec   <= '0;
      out_row   <= 2'd0;
      out_tile  <= 5'd0;

      i_idx     <= 2'd0;
      t_idx     <= 5'd0;
      j_idx     <= 2'd0;

      acc0      <= 32'h0000_0000;
      acc1      <= 32'h0000_0000;
      acc2      <= 32'h0000_0000;
      acc3      <= 32'h0000_0000;

      a_scalar  <= 32'h0000_0000;

      V_mem_addr <= V_BASE;

      wait_cnt  <= 0;
      state     <= S_IDLE;

      // clear strobes
      m_stb_a[0] <= 1'b0; m_stb_b[0] <= 1'b0;
      m_stb_a[1] <= 1'b0; m_stb_b[1] <= 1'b0;
      m_stb_a[2] <= 1'b0; m_stb_b[2] <= 1'b0;
      m_stb_a[3] <= 1'b0; m_stb_b[3] <= 1'b0;

      a_stb_a[0] <= 1'b0; a_stb_b[0] <= 1'b0;
      a_stb_a[1] <= 1'b0; a_stb_b[1] <= 1'b0;
      a_stb_a[2] <= 1'b0; a_stb_b[2] <= 1'b0;
      a_stb_a[3] <= 1'b0; a_stb_b[3] <= 1'b0;

    end else begin
      done      <= 1'b0;
      out_valid <= 1'b0;

      case (state)
        S_IDLE: begin
          busy <= 1'b0;

          // keep strobes low
          m_stb_a[0] <= 1'b0; m_stb_b[0] <= 1'b0;
          m_stb_a[1] <= 1'b0; m_stb_b[1] <= 1'b0;
          m_stb_a[2] <= 1'b0; m_stb_b[2] <= 1'b0;
          m_stb_a[3] <= 1'b0; m_stb_b[3] <= 1'b0;

          a_stb_a[0] <= 1'b0; a_stb_b[0] <= 1'b0;
          a_stb_a[1] <= 1'b0; a_stb_b[1] <= 1'b0;
          a_stb_a[2] <= 1'b0; a_stb_b[2] <= 1'b0;
          a_stb_a[3] <= 1'b0; a_stb_b[3] <= 1'b0;

          if (start) begin
            busy <= 1'b1;

            i_idx <= 2'd0;
            t_idx <= 5'd0;
            j_idx <= 2'd0;

            acc0  <= 32'h0000_0000;
            acc1  <= 32'h0000_0000;
            acc2  <= 32'h0000_0000;
            acc3  <= 32'h0000_0000;

            state <= S_SET_ADDR;
          end
        end

        S_SET_ADDR: begin
          // Read V row=j_idx, tile=t_idx
          V_mem_addr <= V_BASE + j_off + t_off;
          wait_cnt <= 0;
          state <= S_WAIT_MEM;
        end

        S_WAIT_MEM: begin
          if (wait_cnt == MEM_WAIT) begin
            a_scalar <= getA(attn_flat_all, head, i_idx, j_idx);
            state <= S_START_MUL;
          end else begin
            wait_cnt <= wait_cnt + 1;
          end
        end

        S_START_MUL: begin
          // Fire 4 multipliers in parallel 
          m_stb_a[0] <= 1'b1; m_stb_b[0] <= 1'b1;
          m_stb_a[1] <= 1'b1; m_stb_b[1] <= 1'b1;
          m_stb_a[2] <= 1'b1; m_stb_b[2] <= 1'b1;
          m_stb_a[3] <= 1'b1; m_stb_b[3] <= 1'b1;
          state <= S_WAIT_MUL;
        end

        S_WAIT_MUL: begin
          // Drop stbs once acks arrive
          if (m_ack_a[0]) m_stb_a[0] <= 1'b0;
          if (m_ack_b[0]) m_stb_b[0] <= 1'b0;
          if (m_ack_a[1]) m_stb_a[1] <= 1'b0;
          if (m_ack_b[1]) m_stb_b[1] <= 1'b0;
          if (m_ack_a[2]) m_stb_a[2] <= 1'b0;
          if (m_ack_b[2]) m_stb_b[2] <= 1'b0;
          if (m_ack_a[3]) m_stb_a[3] <= 1'b0;
          if (m_ack_b[3]) m_stb_b[3] <= 1'b0;

          if (mul_all_done) begin
            state <= S_START_ADD;
          end
        end

        S_START_ADD: begin
          // Add products into accumulators 
          a_stb_a[0] <= 1'b1; a_stb_b[0] <= 1'b1;
          a_stb_a[1] <= 1'b1; a_stb_b[1] <= 1'b1;
          a_stb_a[2] <= 1'b1; a_stb_b[2] <= 1'b1;
          a_stb_a[3] <= 1'b1; a_stb_b[3] <= 1'b1;
          state <= S_WAIT_ADD;
        end

        S_WAIT_ADD: begin
          if (a_ack_a[0]) a_stb_a[0] <= 1'b0;
          if (a_ack_b[0]) a_stb_b[0] <= 1'b0;
          if (a_ack_a[1]) a_stb_a[1] <= 1'b0;
          if (a_ack_b[1]) a_stb_b[1] <= 1'b0;
          if (a_ack_a[2]) a_stb_a[2] <= 1'b0;
          if (a_ack_b[2]) a_stb_b[2] <= 1'b0;
          if (a_ack_a[3]) a_stb_a[3] <= 1'b0;
          if (a_ack_b[3]) a_stb_b[3] <= 1'b0;

          if (add_all_done) begin
            // Update accumulators with adder outputs
            acc0 <= a_z[0];
            acc1 <= a_z[1];
            acc2 <= a_z[2];
            acc3 <= a_z[3];
            state <= S_NEXT_J;
          end
        end

        S_NEXT_J: begin
          if (j_idx == 2'd3) begin
            // Finished sum over j for this (i,t) 
            state <= S_EMIT;
          end else begin
            j_idx <= j_idx + 1'b1;
            state <= S_SET_ADDR;
          end
        end

        S_EMIT: begin
          out_vec   <= {acc3, acc2, acc1, acc0};
          out_row   <= i_idx;
          out_tile  <= t_idx;
          out_valid <= 1'b1;

          state <= S_NEXT_TILE;
        end

        S_NEXT_TILE: begin
          // Advance tile; reset j and accumulators for next output vector
          j_idx <= 2'd0;

          acc0 <= 32'h0000_0000;
          acc1 <= 32'h0000_0000;
          acc2 <= 32'h0000_0000;
          acc3 <= 32'h0000_0000;

          if (t_idx == 5'd31) begin
            t_idx <= 5'd0;
            if (i_idx == 2'd3) begin
              state <= S_DONE;
            end else begin
              i_idx <= i_idx + 1'b1;
              state <= S_SET_ADDR;
            end
          end else begin
            t_idx <= t_idx + 1'b1;
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
