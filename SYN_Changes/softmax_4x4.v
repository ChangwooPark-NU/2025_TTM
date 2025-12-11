`timescale 1ns/1ps

module softmax_4x4_rowwise (
  input  wire        clk,
  input  wire        rst,      // active-high (softmax? ??)
  input  wire        start,

  input  wire [31:0] X00, input wire [31:0] X01, input wire [31:0] X02, input wire [31:0] X03,
  input  wire [31:0] X10, input wire [31:0] X11, input wire [31:0] X12, input wire [31:0] X13,
  input  wire [31:0] X20, input wire [31:0] X21, input wire [31:0] X22, input wire [31:0] X23,
  input  wire [31:0] X30, input wire [31:0] X31, input wire [31:0] X32, input wire [31:0] X33,

  output reg         done_all,

  output reg [31:0]  Y00, output reg [31:0] Y01, output reg [31:0] Y02, output reg [31:0] Y03,
  output reg [31:0]  Y10, output reg [31:0] Y11, output reg [31:0] Y12, output reg [31:0] Y13,
  output reg [31:0]  Y20, output reg [31:0] Y21, output reg [31:0] Y22, output reg [31:0] Y23,
  output reg [31:0]  Y30, output reg [31:0] Y31, output reg [31:0] Y32, output reg [31:0] Y33
);

  localparam S_IDLE   = 4'd0;
  localparam S_PULSE  = 4'd1;
  localparam S_FEED0  = 4'd2;
  localparam S_FEED1  = 4'd3;
  localparam S_FEED2  = 4'd4;
  localparam S_FEED3  = 4'd5;
  localparam S_WAIT   = 4'd6;
  localparam S_NEXT   = 4'd7;
  localparam S_DONE   = 4'd8;

  reg [3:0] state;
  reg [1:0] row;
  reg [1:0] col;

  wire sm_start = (state == S_PULSE);

  function [31:0] sel_x;
    input [1:0] r;
    input [1:0] c;
    begin
      sel_x = 32'h0;
      case (r)
        2'd0: case (c) 2'd0: sel_x=X00; 2'd1: sel_x=X01; 2'd2: sel_x=X02; default: sel_x=X03; endcase
        2'd1: case (c) 2'd0: sel_x=X10; 2'd1: sel_x=X11; 2'd2: sel_x=X12; default: sel_x=X13; endcase
        2'd2: case (c) 2'd0: sel_x=X20; 2'd1: sel_x=X21; 2'd2: sel_x=X22; default: sel_x=X23; endcase
        default: case (c) 2'd0: sel_x=X30; 2'd1: sel_x=X31; 2'd2: sel_x=X32; default: sel_x=X33; endcase
      endcase
    end
  endfunction

  wire [31:0] sm_din = sel_x(row, col);
  wire [31:0] sm_y0, sm_y1, sm_y2, sm_y3;
  wire        sm_done;

  softmax u_softmax (
    .Clock (clk),
    .Reset (rst),
    .Start (sm_start),
    .Datain(sm_din),
    .N     (3'd3),
    .Y0    (sm_y0),
    .Y1    (sm_y1),
    .Y2    (sm_y2),
    .Y3    (sm_y3),
    .Done  (sm_done)
  );

  always @(posedge clk or posedge rst) begin
    if (rst) begin
      state    <= S_IDLE;
      row      <= 2'd0;
      col      <= 2'd0;
      done_all <= 1'b0;

      Y00<=0;Y01<=0;Y02<=0;Y03<=0;
      Y10<=0;Y11<=0;Y12<=0;Y13<=0;
      Y20<=0;Y21<=0;Y22<=0;Y23<=0;
      Y30<=0;Y31<=0;Y32<=0;Y33<=0;
    end else begin
      done_all <= 1'b0;

      case (state)
        S_IDLE: begin
          if (start) begin
            row   <= 2'd0;
            col   <= 2'd0;
            state <= S_PULSE;
          end
        end

        S_PULSE: begin
          // Start=1 for this cycle, softmax? ?? ????? ?? ??? ??
          col   <= 2'd0;
          state <= S_FEED0;
        end

        S_FEED0: begin col <= 2'd1; state <= S_FEED1; end
        S_FEED1: begin col <= 2'd2; state <= S_FEED2; end
        S_FEED2: begin col <= 2'd3; state <= S_FEED3; end
        S_FEED3: begin             state <= S_WAIT;  end

        S_WAIT: begin
          if (sm_done) begin
            case (row)
              2'd0: begin Y00<=sm_y0; Y01<=sm_y1; Y02<=sm_y2; Y03<=sm_y3; end
              2'd1: begin Y10<=sm_y0; Y11<=sm_y1; Y12<=sm_y2; Y13<=sm_y3; end
              2'd2: begin Y20<=sm_y0; Y21<=sm_y1; Y22<=sm_y2; Y23<=sm_y3; end
              default: begin Y30<=sm_y0; Y31<=sm_y1; Y32<=sm_y2; Y33<=sm_y3; end
            endcase
            state <= S_NEXT;
          end
        end

        S_NEXT: begin
          if (row == 2'd3) begin
            state <= S_DONE;
          end else begin
            row   <= row + 2'd1;
            col   <= 2'd0;
            state <= S_PULSE;
          end
        end

        S_DONE: begin
          done_all <= 1'b1;
          state    <= S_IDLE;
        end

        default: state <= S_IDLE;
      endcase
    end
  end

endmodule
