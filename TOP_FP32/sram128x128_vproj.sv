module sram128x128_vproj #(
  parameter int READ_LAT = 2
)(
  input  logic         clk,
  input  logic         rst_n,

  input  logic         init_en,
  input  logic         init_we_n,
  input  logic [6:0]   init_addr,
  input  logic [127:0] init_din,

  input  logic [6:0]   rd_addr,
  output logic [127:0] rd_dout
);

  logic        web_n;
  logic [6:0]  a;
  logic [127:0] d;
  logic [127:0] q;

  always_comb begin
    if (init_en) begin
      a     = init_addr;
      d     = init_din;
      web_n = init_we_n;      // active-low write enable
    end else begin
      a     = rd_addr;
      d     = 128'd0;
      web_n = 1'b1;           // read mode (no write)
    end
  end

  v_proj_mem V_PROJ_MEM (
    .SLP   (1'b0),
    .SD    (1'b0),
    .CLK   (clk),
    .CEB   (1'b0),
    .WEB   (web_n),
    .CEBM  (1'b0),
    .WEBM  (1'b0),
    .A     (a),
    .D     (d),
    .BWEB  (128'd0),
    .AM    (7'd0),
    .DM    (128'd0),
    .BWEBM (128'd0),
    .BIST  (1'b0),
    .RTSEL (2'b0),
    .WTSEL (2'b0),
    .Q     (q)
  );

  generate
    if (READ_LAT <= 0) begin : GEN_LAT0
      always_comb rd_dout = q;
    end else begin : GEN_LAT
      logic [127:0] pipe [0:READ_LAT-1];
      int i;

      always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
          for (i = 0; i < READ_LAT; i++) pipe[i] <= 128'd0;
        end else begin
          pipe[0] <= q;
          for (i = 1; i < READ_LAT; i++) pipe[i] <= pipe[i-1];
        end
      end

      always_comb rd_dout = pipe[READ_LAT-1];
    end
  endgenerate

endmodule
