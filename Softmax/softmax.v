`timescale 1ns / 1ps
`define DATALENGTH 32
`define INPUTMAX 2 
`define IDLE 			3'b000
`define INPUTSTREAM 	3'b001
`define EXP				3'b010
`define ADD				3'b011
`define DIV				3'b100
`define OUTPUTSTREAM    3'b101
`define NUMBER 2'b11

module softmax(
		input wire 						Clock,
		input wire 						Reset,
		input wire						Start,
		input wire [`DATALENGTH-1:0] 	Datain,
		input wire	[`INPUTMAX:0]		N,
		output reg  [`DATALENGTH-1:0] Dataout
		);

integer m;
// reg [`DATALENGTH-1:0]	Dataout;
reg [`DATALENGTH-1:0] 	InputBuffer[2**`INPUTMAX - 1:0];
reg [`DATALENGTH-1:0] 	DivBuffer[2**`INPUTMAX - 1:0];

reg [`DATALENGTH-1:0] 	OutputBuffer[2**`INPUTMAX -1 :0];
reg [`DATALENGTH-1:0]	Acc;
reg [`DATALENGTH-1:0]	Arg;

wire [`DATALENGTH-1:0]	Acc_w;

reg 					[3:0]Str;

wire [`DATALENGTH-1:0] 	InputBuffer_w[2**`INPUTMAX -1 :0];
wire [`DATALENGTH-1:0] 	OutputBuffer_w[2**`INPUTMAX -1 :0];

wire 					[3:0]Ack;
reg 					Str_Add_a;
reg 					Str_Add_b;
reg 					Str_Add_z;


wire 					Ack_add1;
wire 					Ack_add2;
wire 					Ack_add3;
reg Ack_div1;
reg Ack_div2;
reg Ack_div3;
wire 					[3:0]Ack_div_a;
wire 					[3:0]Ack_div_b;
wire 					[3:0]Ack_div_z;

reg [`INPUTMAX:0] 	Counter;
reg [`INPUTMAX:0] 	C,C_add;

reg [2:0] 				NextState;
reg Ack_add3_d;

genvar i;
generate
for (i = 0; i <= 2**`INPUTMAX -1; i = i +1) begin
exponential exp (
	Clock,
	Reset,
	Str[i],
	InputBuffer[i],
	Ack[i],
	InputBuffer_w[i]
	) 	;
end
endgenerate

// genvar j;
// generate
// for (j = 0; j < `NUMBER; j= j+1) begin 


adder add (
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
	) ;
// end
// endgenerate


genvar k;
generate
for (k = 0; k <= 2**`INPUTMAX -1; k= k+1) begin 
divider div (
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
	) ;
end
endgenerate


always @(posedge Clock or negedge Reset) begin
	if (Reset) begin
		// reset
		for (m = 0; m <= 2**`INPUTMAX -1;m = m+1)begin 
			InputBuffer[m] <= 0;
			OutputBuffer[m] <= 0;
			DivBuffer[m] <= 0;
		end
		Counter <= 0;
		C <= 0;
		Arg <= 0;
		C_add <= 0;
		Dataout <= 0;
		Acc <= 0;
		Str <= 0;
		Ack_div1 <=0;
		Ack_div2 <=0;
		Ack_div3 <=0;
		Str_Add_a <= 0;
		Str_Add_b <= 0;
		Str_Add_z <= 0;
		NextState <= `IDLE;
		Ack_add3_d <= 1'b0;

	end
	else begin
	case(NextState)
		
		`IDLE: begin
		if (Start)
			NextState <= `INPUTSTREAM;	
		else
			NextState <= `IDLE;

		end

		`INPUTSTREAM: begin
			if (Counter <= N) begin
				InputBuffer[Counter] <= Datain;
				Counter <= Counter + 1;
				NextState <= `INPUTSTREAM;
			end
			else begin
				NextState <= `EXP;
				Str <= 4'b1111;
			end		
		end


		`EXP: begin
		if (Ack == 4'b1111) begin
			for (m = 0; m <= N; m = m + 1)
			DivBuffer[m] <= InputBuffer_w[m];

			// ---- ADD ???(??) ----
			C     <= 0;                 // sum index
			C_add <= 0;                 // phase
			Acc   <= 32'h00000000;      // 0.0

			// adder handshake default
			Str_Add_a <= 1'b0;
			Str_Add_b <= 1'b0;
			Str_Add_z <= 1'b1;          // output_z_ack? ?? 1? ??(??)

			NextState <= `ADD;
		end else begin
			NextState <= `EXP;
		end
		end

		`ADD: begin
		// output ack? ?? 1 (adder? put_z?? get_a? ????? ??)
		Str_Add_z <= 1'b1;

		if (C <= N) begin
			case (C_add)
			0: begin
				// A ?? ?? (get_a??? input_a_ack=1)
				Str_Add_a <= 1'b0;
				Str_Add_b <= 1'b0;

				if (Ack_add1) begin
				Arg       <= DivBuffer[C];   // input_a = exp(x_i)
				Str_Add_a <= 1'b1;           // input_a_stb ???
				C_add     <= 1;
				end
			end

			1: begin
				// A? ??? input_a_ack? 0?? ??? (get_b? ??)
				if (!Ack_add1) begin
				Str_Add_a <= 1'b0;
				C_add     <= 2;
				end
			end

			2: begin
				// B ?? ?? (get_b??? input_b_ack=1)
				if (Ack_add2) begin
				Str_Add_b <= 1'b1;           // input_b_stb ??? (input_b? Acc? ??? ??)
				C_add     <= 3;
				end
			end

			3: begin
				// B? ??? input_b_ack? 0?? ???
				if (!Ack_add2) begin
				Str_Add_b <= 1'b0;
				C_add     <= 4;
				end
			end

			4: begin
				// ?? ???? (output_z_stb)
				if (Ack_add3) begin
				Acc   <= Acc_w;              // Acc = Acc + Arg
				C     <= C + 1;              // next element
				C_add <= 0;                  // next transaction
				end
			end

			default: begin
				C_add <= 0;
			end
			endcase

			NextState <= `ADD;
		end else begin
			// ? ? -> DIV?
			Str_Add_a <= 1'b0;
			Str_Add_b <= 1'b0;
			Str_Add_z <= 1'b1;   // ???? ??
			NextState <= `DIV;
		end
		end



		`DIV: begin
    			Ack_div1 <= 1;
    			Ack_div2 <= 1;
    			Ack_div3 <= 1;    			
			if (Ack_div_z == 4'b1111) begin
			for (m = 0; m <= N;m = m+1)begin 
             		OutputBuffer[m] <=  OutputBuffer_w[m];
			end
				NextState <= `OUTPUTSTREAM;
			end
			else
				NextState <= `DIV;
			
		end

		`OUTPUTSTREAM: begin
				Counter <= Counter - 1;
			if (Counter != 0) begin
				Dataout <= OutputBuffer[Counter];
				NextState <= `OUTPUTSTREAM;
				end
			else begin
				NextState <= `IDLE;				
			end
		end

		default: begin
			NextState <= `IDLE;
		end

		endcase
	end
end
	
endmodule
