`timescale 1ns/1ps
`define DATALENGTH 32

module exponential (
  input  wire                     Clock,
  input  wire                     Reset,   // active-high (softmax ???)
  input  wire                     Str,     // level-enable
  input  wire [`DATALENGTH-1:0]   Datain,
  output reg                      Ack,
  output reg  [`DATALENGTH-1:0]   DataOut
);

  // ---- constants ----
  wire [`DATALENGTH-1:0] one      = 32'h3f800000; // 1.0
  wire [`DATALENGTH-1:0] half     = 32'h3f000000; // 0.5
  wire [`DATALENGTH-1:0] oversix  = 32'h3e2aaaab; // 1/6

  // ---- datapath regs/wires ----
  reg  [`DATALENGTH-1:0] T0;
  wire [`DATALENGTH-1:0] T1, Ts, Tsh, T2, Tc, Td, To;

  // handshake wires (?? ?? ?? ??)
  wire wa_add_1, wb_add_1, wz_add_1;
  wire wa_mul_1, wb_mul_1, wz_mul_1;
  wire wa_sh_1,  wb_sh_1,  wz_sh_1;
  wire wa_add_2, wb_add_2, wz_add_2;
  wire wa_mul_2, wb_mul_2, wz_mul_2;
  wire wa_div_1, wb_div_1, wz_div_1;
  wire wa_add_3, wb_add_3, wz_add_3;

  // ---- module chain (?? ? ?? ??) ----
  adder A1 (
    one, T0,
    Str, Str, Str,
    Clock, Reset,
    T1, wz_add_1, wa_add_1, wb_add_1
  );

  multiplier Ms (
    T0, T0,
    wa_add_1, wb_add_1, wz_add_1,
    Clock, Reset,
    Ts, wz_mul_1, wa_mul_1, wb_mul_1
  );

  multiplier Msh (
    half, Ts,
    wa_mul_1, wb_mul_1, wz_mul_1,
    Clock, Reset,
    Tsh, wz_sh_1, wa_sh_1, wb_sh_1
  );

  adder A2 (
    T1, Tsh,
    wa_sh_1, wb_sh_1, wz_sh_1,
    Clock, Reset,
    T2, wz_add_2, wa_add_2, wb_add_2
  );

  multiplier Mc (
    T0, Ts,
    wa_add_2, wb_add_2, wz_add_2,
    Clock, Reset,
    Tc, wz_mul_2, wa_mul_2, wb_mul_2
  );

  multiplier Dm (
    Tc, oversix,
    wa_mul_2, wb_mul_2, wz_mul_2,
    Clock, Reset,
    Td, wz_div_1, wa_div_1, wb_div_1
  );

  adder A3 (
    Td, T2,
    wa_div_1, wb_div_1, wz_div_1,
    Clock, Reset,
    To, wz_add_3, wa_add_3, wb_add_3
  );

  // ---- control ----
  localparam integer LAT = 140;   // ?? ?? ? ???
  integer count;

  always @(posedge Clock or negedge Reset) begin
    if (Reset) begin
      T0      <= 32'h00000000;
      DataOut <= 32'h00000000;
      Ack     <= 1'b0;
      count   <= 0;
    end else begin
      if (!Str) begin
        // *** run ??? ???? ??? ??? ***
        T0    <= 32'h00000000;
        Ack   <= 1'b0;
        count <= 0;
      end else begin
        // enable ?? ?? ??
        T0 <= Datain;

        // ?? ?? ? ack
        if (count >= LAT) begin
          Ack     <= 1'b1;   // level? ?? (softmax? Ack==1111 ?????)
          DataOut <= To;
        end else begin
          count   <= count + 1;
          Ack     <= 1'b0;
          DataOut <= To;     // ?????? ?? ????
        end
      end
    end
  end

endmodule
