`timescale 1ns / 1ps
`define DATALENGTH 32
`define INPUTMAX   2

`define IDLE         3'b000
`define INPUTSTREAM  3'b001
`define EXP          3'b010
`define ADD          3'b011
`define DIV          3'b100

module softmax(
    input  wire                     Clock,
    input  wire                     Reset,
    input  wire                     Start,
    input  wire [`DATALENGTH-1:0]   Datain,
    input  wire [`INPUTMAX:0]       N,

    output reg  [`DATALENGTH-1:0]   Y0,
    output reg  [`DATALENGTH-1:0]   Y1,
    output reg  [`DATALENGTH-1:0]   Y2,
    output reg  [`DATALENGTH-1:0]   Y3,
    output reg                      Done
);

  localparam integer DEPTH = (1 << `INPUTMAX);
  localparam integer LAST  = DEPTH - 1;

  integer m;

  reg  [`DATALENGTH-1:0] InputBuffer [0:LAST];
  reg  [`DATALENGTH-1:0] DivBuffer   [0:LAST];

  wire [`DATALENGTH-1:0] InputBuffer_w [0:LAST];
  wire [`DATALENGTH-1:0] OutputBuffer_w[0:LAST];

  reg  [`DATALENGTH-1:0] Acc;
  reg  [`DATALENGTH-1:0] Arg;
  wire [`DATALENGTH-1:0] Acc_w;

  reg  [LAST:0] Str;
  wire [LAST:0] Ack;

  reg  Str_Add_a;
  reg  Str_Add_b;
  reg  Str_Add_z;
  wire Ack_add1;
  wire Ack_add2;
  wire Ack_add3;

  reg  Ack_div1;
  reg  Ack_div2;
  reg  Ack_div3;
  wire [LAST:0] Ack_div_a;
  wire [LAST:0] Ack_div_b;
  wire [LAST:0] Ack_div_z;

  reg  [`INPUTMAX:0] Counter;   // input index
  reg  [`INPUTMAX:0] C;         // sum index
  reg  [`INPUTMAX:0] C_add;     // ADD phase

  reg  [2:0] NextState;

  genvar i;
  generate
    for (i = 0; i < DEPTH; i = i + 1) begin: GEN_EXP
      exponential exp_u (
        Clock,
        Reset,
        Str[i],
        InputBuffer[i],
        Ack[i],
        InputBuffer_w[i]
      );
    end
  endgenerate

  adder add_u (
    Arg,
    Acc,
    Str_Add_a,
    Str_Add_b,
    Str_Add_z,
    Clock,
    Reset,
    Acc_w,
    Ack_add3,
    Ack_add1,
    Ack_add2
  );

  genvar k;
  generate
    for (k = 0; k < DEPTH; k = k + 1) begin: GEN_DIV
      divider div_u (
        DivBuffer[k],
        Acc,
        Ack_div1,
        Ack_div2,
        Ack_div3,
        Clock,
        Reset,
        OutputBuffer_w[k],
        Ack_div_z[k],
        Ack_div_a[k],
        Ack_div_b[k]
      );
    end
  endgenerate

  always @(posedge Clock or negedge Reset) begin
    if (Reset) begin
      for (m = 0; m < DEPTH; m = m + 1) begin
        InputBuffer[m] <= 32'h00000000;
        DivBuffer[m]   <= 32'h00000000;
      end

      Counter   <= 0;
      C         <= 0;
      C_add     <= 0;

      Arg       <= 32'h00000000;
      Acc       <= 32'h00000000;

      Str       <= {DEPTH{1'b0}};

      Ack_div1  <= 1'b0;
      Ack_div2  <= 1'b0;
      Ack_div3  <= 1'b0;

      Str_Add_a <= 1'b0;
      Str_Add_b <= 1'b0;
      Str_Add_z <= 1'b0;

      Y0        <= 32'h00000000;
      Y1        <= 32'h00000000;
      Y2        <= 32'h00000000;
      Y3        <= 32'h00000000;
      Done      <= 1'b0;

      NextState <= `IDLE;
    end else begin
      Done <= 1'b0; // 1-cycle pulse

      case (NextState)
        `IDLE: begin
          Str       <= {DEPTH{1'b0}};
          Str_Add_a <= 1'b0;
          Str_Add_b <= 1'b0;
          Str_Add_z <= 1'b0;

          Ack_div1  <= 1'b0;
          Ack_div2  <= 1'b0;
          Ack_div3  <= 1'b0;

          if (Start) begin

            Counter <= 0;
            C       <= 0;
            C_add   <= 0;
            Acc     <= 32'h00000000;
            Arg     <= 32'h00000000;

            // clear strobes/acks to known state
            Str <= 0;
            Str_Add_a <= 0;
            Str_Add_b <= 0;
            Str_Add_z <= 0;
            Ack_div1  <= 0;
            Ack_div2  <= 0;
            Ack_div3  <= 0;

            NextState <= `INPUTSTREAM;
          end else begin
            NextState <= `IDLE;
          end
        end

        `INPUTSTREAM: begin
          if (Counter <= N) begin
            InputBuffer[Counter] <= Datain;
            Counter <= Counter + 1;
            NextState <= `INPUTSTREAM;
          end else begin
            Str <= {DEPTH{1'b1}};
            NextState <= `EXP;
          end
        end

        `EXP: begin
          if (Ack == {DEPTH{1'b1}}) begin
            for (m = 0; m <= N; m = m + 1)
              DivBuffer[m] <= InputBuffer_w[m];

            C         <= 0;
            C_add     <= 0;
            Acc       <= 32'h00000000; // 0.0
            Arg       <= 32'h00000000;

            Str_Add_a <= 1'b0;
            Str_Add_b <= 1'b0;
            Str_Add_z <= 1'b1;         // keep output_z_ack high

            Str <= {DEPTH{1'b0}};
            NextState <= `ADD;
          end else begin
            NextState <= `EXP;
          end
        end

        `ADD: begin
          Str_Add_z <= 1'b1;

          if (C <= N) begin
            case (C_add)
              0: begin
                Str_Add_a <= 1'b0;
                Str_Add_b <= 1'b0;
                if (Ack_add1) begin
                  Arg       <= DivBuffer[C];
                  Str_Add_a <= 1'b1;
                  C_add     <= 1;
                end
              end

              1: begin
                if (!Ack_add1) begin
                  Str_Add_a <= 1'b0;
                  C_add     <= 2;
                end
              end

              2: begin
                if (Ack_add2) begin
                  Str_Add_b <= 1'b1;
                  C_add     <= 3;
                end
              end

              3: begin
                if (!Ack_add2) begin
                  Str_Add_b <= 1'b0;
                  C_add     <= 4;
                end
              end

              4: begin
                if (Ack_add3) begin
                  Acc   <= Acc_w;
                  C     <= C + 1;
                  C_add <= 0;
                end
              end

              default: begin
                C_add <= 0;
              end
            endcase

            NextState <= `ADD;
          end else begin
            Str_Add_a <= 1'b0;
            Str_Add_b <= 1'b0;
            Str_Add_z <= 1'b1;

            Ack_div1  <= 1'b1;
            Ack_div2  <= 1'b1;
            Ack_div3  <= 1'b1;

            NextState <= `DIV;
          end
        end

        `DIV: begin
          Ack_div1 <= 1'b1;
          Ack_div2 <= 1'b1;
          Ack_div3 <= 1'b1;

          if (Ack_div_z == {DEPTH{1'b1}}) begin
            Y0   <= OutputBuffer_w[0];
            Y1   <= OutputBuffer_w[1];
            Y2   <= OutputBuffer_w[2];
            Y3   <= OutputBuffer_w[3];
            Done <= 1'b1;

            NextState <= `IDLE;
          end else begin
            NextState <= `DIV;
          end
        end

        default: begin
          NextState <= `IDLE;
        end
      endcase
    end
  end

endmodule
