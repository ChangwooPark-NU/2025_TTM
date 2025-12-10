`timescale 1ps/1ps

module gemm_4x4_4x128 #(
  parameter int READ_LAT = 2,
  parameter int MEM_WAIT = READ_LAT + 1   // =3
)(
  input  logic         clk,
  input  logic         rst_n,      // active-low
  input  logic         start,      // 1-cycle pulse 

  input  logic [31:0]  A [0:3][0:3],   // A[row][k] FP32

  // external "SRAM" interface
  output logic [6:0]   B_mem_addr,
  input  logic [127:0] B_mem_out,

  // stream output
  output logic         out_valid,
  output logic [1:0]   out_row,
  output logic [4:0]   out_group,
  output logic [127:0] out_data,
  output logic         busy,
  output logic         done
);


  // helpers

  function automatic logic [6:0] calc_addr(input logic [4:0] g, input logic [1:0] k);
    logic [6:0] t;
    begin
      t = {g, 2'b00} + {{5{1'b0}}, k}; // g*4 + k
      calc_addr = t;
    end
  endfunction

  function automatic logic [31:0] lane_pick(input logic [127:0] w, input logic [1:0] lane);
    logic [31:0] t;
    begin
      t = 32'h0;
      case (lane)
        2'd0: t = w[31:0];
        2'd1: t = w[63:32];
        2'd2: t = w[95:64];
        2'd3: t = w[127:96];
        default: t = 32'h0;
      endcase
      lane_pick = t;
    end
  endfunction


  // start edge detect

  logic start_d;
  logic start_pulse;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) start_d <= 1'b0;
    else       start_d <= start;
  end
  assign start_pulse = start & ~start_d;


  // FP reset (adder/mul are async active-high)

  logic rst_fp;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) rst_fp <= 1'b1;
    else        rst_fp <= 1'b0;
  end


  // Dawson handshake multiplier/adder (1 mul + 1 add)

  logic [31:0] mul_a, mul_b;
  logic        mul_a_stb, mul_b_stb;
  logic        mul_a_ack, mul_b_ack;
  logic [31:0] mul_z;
  logic        mul_z_stb;
  wire         mul_z_ack = 1'b1;   // ?? ?? (??? ?? ???)

  logic [31:0] add_a, add_b;
  logic        add_a_stb, add_b_stb;
  logic        add_a_ack, add_b_ack;
  logic [31:0] add_z;
  logic        add_z_stb;
  wire         add_z_ack = 1'b1;   // ?? ??

  multiplier U_MUL (
    .input_a      (mul_a),
    .input_b      (mul_b),
    .input_a_stb  (mul_a_stb),
    .input_b_stb  (mul_b_stb),
    .output_z_ack (mul_z_ack),
    .clk          (clk),
    .rst          (rst_fp),
    .output_z     (mul_z),
    .output_z_stb (mul_z_stb),
    .input_a_ack  (mul_a_ack),
    .input_b_ack  (mul_b_ack)
  );

  adder U_ADD (
    .input_a      (add_a),
    .input_b      (add_b),
    .input_a_stb  (add_a_stb),
    .input_b_stb  (add_b_stb),
    .output_z_ack (add_z_ack),
    .clk          (clk),
    .rst          (rst_fp),
    .output_z     (add_z),
    .output_z_stb (add_z_stb),
    .input_a_ack  (add_a_ack),
    .input_b_ack  (add_b_ack)
  );


  // FSM

  typedef enum logic [3:0] {
    S_IDLE      = 4'd0,
    S_INIT      = 4'd1,
    S_SET_ADDR  = 4'd2,
    S_WAIT_MEM  = 4'd3,
    S_LATCH_MEM = 4'd4,
    S_MUL_SEND  = 4'd5,
    S_MUL_WAIT  = 4'd6,
    S_ADD_SEND  = 4'd7,
    S_ADD_WAIT  = 4'd8,
    S_NEXT_LANE = 4'd9,
    S_NEXT_K    = 4'd10,
    S_EMIT      = 4'd11,
    S_NEXT_G    = 4'd12,
    S_NEXT_R    = 4'd13,
    S_DONE      = 4'd14
  } state_t;

  state_t state;

  logic [1:0]   r_row;
  logic [4:0]   r_group;
  logic [1:0]   r_k;
  logic [1:0]   r_lane;

  integer       wait_cnt;

  logic [127:0] bword_latched;
  logic [31:0]  acc_lane [0:3];

  // handshake progress flags 
  logic mul_a_accepted, mul_b_accepted;
  logic add_a_accepted, add_b_accepted;

  integer ii;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= S_IDLE;

      r_row      <= 2'd0;
      r_group    <= 5'd0;
      r_k        <= 2'd0;
      r_lane     <= 2'd0;

      B_mem_addr <= 7'd0;
      bword_latched <= 128'd0;
      wait_cnt   <= 0;

      for (ii=0; ii<4; ii=ii+1) begin
        acc_lane[ii] <= 32'h0000_0000;
      end

      mul_a <= 32'h0;
      mul_b <= 32'h0;
      mul_a_stb <= 1'b0;
      mul_b_stb <= 1'b0;

      add_a <= 32'h0;
      add_b <= 32'h0;
      add_a_stb <= 1'b0;
      add_b_stb <= 1'b0;

      mul_a_accepted <= 1'b0;
      mul_b_accepted <= 1'b0;
      add_a_accepted <= 1'b0;
      add_b_accepted <= 1'b0;

      out_valid <= 1'b0;
      out_row   <= 2'd0;
      out_group <= 5'd0;
      out_data  <= 128'd0;
      busy      <= 1'b0;
      done      <= 1'b0;

    end else begin
      // defaults
      out_valid <= 1'b0;
      done      <= 1'b0;

      case (state)

        S_IDLE: begin
          busy <= 1'b0;
          mul_a_stb <= 1'b0;
          mul_b_stb <= 1'b0;
          add_a_stb <= 1'b0;
          add_b_stb <= 1'b0;

          if (start_pulse) begin
            busy  <= 1'b1;
            state <= S_INIT;
          end
        end

        S_INIT: begin
          r_row   <= 2'd0;
          r_group <= 5'd0;
          r_k     <= 2'd0;
          r_lane  <= 2'd0;

          acc_lane[0] <= 32'h0000_0000;
          acc_lane[1] <= 32'h0000_0000;
          acc_lane[2] <= 32'h0000_0000;
          acc_lane[3] <= 32'h0000_0000;

          state <= S_SET_ADDR;
        end

        S_SET_ADDR: begin
          B_mem_addr <= calc_addr(r_group, r_k);
          wait_cnt   <= 0;
          state      <= S_WAIT_MEM;
        end

        S_WAIT_MEM: begin
          if (wait_cnt == MEM_WAIT) state <= S_LATCH_MEM;
          else wait_cnt <= wait_cnt + 1;
        end

        S_LATCH_MEM: begin
          bword_latched <= B_mem_out;
          r_lane        <= 2'd0;
          state         <= S_MUL_SEND;
        end

  
        // MUL handshake 

        S_MUL_SEND: begin
      
          mul_a_accepted <= 1'b0;
          mul_b_accepted <= 1'b0;

          mul_a <= A[r_row][r_k];
          mul_b <= lane_pick(bword_latched, r_lane);

          mul_a_stb <= 1'b1;
          mul_b_stb <= 1'b1;

          state <= S_MUL_WAIT;
        end

        S_MUL_WAIT: begin
          // ack
          if (mul_a_ack && !mul_a_accepted) begin
            mul_a_accepted <= 1'b1;
            mul_a_stb <= 1'b0;
          end
          if (mul_b_ack && !mul_b_accepted) begin
            mul_b_accepted <= 1'b1;
            mul_b_stb <= 1'b0;
          end

          // output_z_stb
          if (mul_z_stb) begin
            // add 
            add_a <= acc_lane[r_lane];
            add_b <= mul_z;
            state <= S_ADD_SEND;
          end
        end


        // ADD handshake 

        S_ADD_SEND: begin
          add_a_accepted <= 1'b0;
          add_b_accepted <= 1'b0;

          add_a_stb <= 1'b1;
          add_b_stb <= 1'b1;

          state <= S_ADD_WAIT;
        end

        S_ADD_WAIT: begin
          if (add_a_ack && !add_a_accepted) begin
            add_a_accepted <= 1'b1;
            add_a_stb <= 1'b0;
          end
          if (add_b_ack && !add_b_accepted) begin
            add_b_accepted <= 1'b1;
            add_b_stb <= 1'b0;
          end

          if (add_z_stb) begin
            acc_lane[r_lane] <= add_z;
            state <= S_NEXT_LANE;
          end
        end

        S_NEXT_LANE: begin
          if (r_lane == 2'd3) begin
            state <= S_NEXT_K;
          end else begin
            r_lane <= r_lane + 1'b1;
            state  <= S_MUL_SEND;
          end
        end

        S_NEXT_K: begin
          if (r_k == 2'd3) begin
            state <= S_EMIT;
          end else begin
            r_k   <= r_k + 1'b1;
            state <= S_SET_ADDR;
          end
        end

        S_EMIT: begin
          out_valid <= 1'b1;
          out_row   <= r_row;
          out_group <= r_group;
          out_data  <= {acc_lane[3], acc_lane[2], acc_lane[1], acc_lane[0]};
          state     <= S_NEXT_G;
        end

        S_NEXT_G: begin
          acc_lane[0] <= 32'h0000_0000;
          acc_lane[1] <= 32'h0000_0000;
          acc_lane[2] <= 32'h0000_0000;
          acc_lane[3] <= 32'h0000_0000;

          r_k <= 2'd0;

          if (r_group == 5'd31) begin
            state <= S_NEXT_R;
          end else begin
            r_group <= r_group + 1'b1;
            state   <= S_SET_ADDR;
          end
        end

        S_NEXT_R: begin
          r_group <= 5'd0;
          r_k     <= 2'd0;

          acc_lane[0] <= 32'h0000_0000;
          acc_lane[1] <= 32'h0000_0000;
          acc_lane[2] <= 32'h0000_0000;
          acc_lane[3] <= 32'h0000_0000;

          if (r_row == 2'd3) begin
            state <= S_DONE;
          end else begin
            r_row <= r_row + 1'b1;
            state <= S_SET_ADDR;
          end
        end

        S_DONE: begin
          done  <= 1'b1;
          busy  <= 1'b0;
          state <= S_IDLE;
        end

        default: state <= S_IDLE;
      endcase
    end
  end

endmodule
