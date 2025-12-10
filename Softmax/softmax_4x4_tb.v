`timescale 1ns/1ps

module tb_softmax_4x4_rowwise;

  logic clk, rst, start, done_all;

  logic [31:0] X00,X01,X02,X03;
  logic [31:0] X10,X11,X12,X13;
  logic [31:0] X20,X21,X22,X23;
  logic [31:0] X30,X31,X32,X33;

  logic [31:0] Y00,Y01,Y02,Y03;
  logic [31:0] Y10,Y11,Y12,Y13;
  logic [31:0] Y20,Y21,Y22,Y23;
  logic [31:0] Y30,Y31,Y32,Y33;

  softmax_4x4_rowwise dut (
    .clk(clk), .rst(rst), .start(start), .done_all(done_all),

    .X00(X00), .X01(X01), .X02(X02), .X03(X03),
    .X10(X10), .X11(X11), .X12(X12), .X13(X13),
    .X20(X20), .X21(X21), .X22(X22), .X23(X23),
    .X30(X30), .X31(X31), .X32(X32), .X33(X33),

    .Y00(Y00), .Y01(Y01), .Y02(Y02), .Y03(Y03),
    .Y10(Y10), .Y11(Y11), .Y12(Y12), .Y13(Y13),
    .Y20(Y20), .Y21(Y21), .Y22(Y22), .Y23(Y23),
    .Y30(Y30), .Y31(Y31), .Y32(Y32), .Y33(Y33)
  );

  initial clk = 0;
  always #5 clk = ~clk;

  function automatic shortreal u2sr(input logic [31:0] u);
    u2sr = $bitstoshortreal(u);
  endfunction

  task automatic dump_row(input int r, input logic [31:0] a,b,c,d);
    shortreal ra,rb,rc,rd,s;
    begin
      ra=u2sr(a); rb=u2sr(b); rc=u2sr(c); rd=u2sr(d);
      s = ra+rb+rc+rd;
      $display("  Row%0d HEX : %08h %08h %08h %08h", r, a,b,c,d);
      $display("  Row%0d REAL: %f %f %f %f   sum=%f", r, ra,rb,rc,rd,s);
    end
  endtask

  task automatic dump_all_outputs;
    begin
      $display("==== OUTPUTS @%0t ====", $time);
      dump_row(0, Y00,Y01,Y02,Y03);
      dump_row(1, Y10,Y11,Y12,Y13);
      dump_row(2, Y20,Y21,Y22,Y23);
      dump_row(3, Y30,Y31,Y32,Y33);
      $display("======================");
    end
  endtask

  task automatic apply_matrix_case(
    input string tag,
    input logic [31:0] i00,i01,i02,i03,
    input logic [31:0] i10,i11,i12,i13,
    input logic [31:0] i20,i21,i22,i23,
    input logic [31:0] i30,i31,i32,i33
  );
    int cyc;
    begin
      $display("\n==== %s ====", tag);

      X00=i00; X01=i01; X02=i02; X03=i03;
      X10=i10; X11=i11; X12=i12; X13=i13;
      X20=i20; X21=i21; X22=i22; X23=i23;
      X30=i30; X31=i31; X32=i32; X33=i33;

      $display("---- INPUTS ----");
      $display("Row0: %08h %08h %08h %08h", X00,X01,X02,X03);
      $display("Row1: %08h %08h %08h %08h", X10,X11,X12,X13);
      $display("Row2: %08h %08h %08h %08h", X20,X21,X22,X23);
      $display("Row3: %08h %08h %08h %08h", X30,X31,X32,X33);
      $display("---------------");

      @(posedge clk);
      start <= 1'b1;
      @(posedge clk);
      start <= 1'b0;

      // timeout: 2,000,000 cycles (~20ms @10ns) ???
      cyc = 0;
      while (done_all !== 1'b1 && cyc < 2_000_000) begin
        @(posedge clk);
        cyc++;
        if ((cyc % 200_000) == 0) begin
          $display("[PROGRESS] cyc=%0d  dut.state=%0d row=%0d col=%0d  done_all=%b",
                   cyc, dut.state, dut.row, dut.col, done_all);
        end
      end

      if (done_all !== 1'b1) begin
        $display("[TIMEOUT] done_all not asserted");
        $display("[DBG] dut.state=%0d row=%0d col=%0d", dut.state, dut.row, dut.col);
        $finish;
      end

      @(posedge clk);
      dump_all_outputs();
    end
  endtask

  initial begin
    start = 0;

    X00=0;X01=0;X02=0;X03=0;
    X10=0;X11=0;X12=0;X13=0;
    X20=0;X21=0;X22=0;X23=0;
    X30=0;X31=0;X32=0;X33=0;

    rst = 1'b1;
    repeat(10) @(posedge clk);
    rst = 1'b0;
    repeat(5) @(posedge clk);

    apply_matrix_case(
      "CASE A: each row = {0,0.5,1,2}",
      32'h00000000,32'h3F000000,32'h3F800000,32'h40000000,
      32'h00000000,32'h3F000000,32'h3F800000,32'h40000000,
      32'h00000000,32'h3F000000,32'h3F800000,32'h40000000,
      32'h00000000,32'h3F000000,32'h3F800000,32'h40000000
    );

    apply_matrix_case(
      "CASE B: row0={0,0,0,0}, others={0,0.5,1,2}",
      32'h00000000,32'h00000000,32'h00000000,32'h00000000,
      32'h00000000,32'h3F000000,32'h3F800000,32'h40000000,
      32'h00000000,32'h3F000000,32'h3F800000,32'h40000000,
      32'h00000000,32'h3F000000,32'h3F800000,32'h40000000
    );

    $display("\n==== TB DONE ====");
    $finish;
  end

endmodule
