module Black_Box #( 
    parameter int N = 4,
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH = 32,
    parameter int DEPTH = 14,
    parameter int COUNT = 7,
    parameter int CAP = 11
)( 
    input logic clk, 
    input logic rst,
    input logic tile_done,
    input logic load_bias, 
    input logic [127:0] bias, 
    input logic [127:0] matrix_a,
    input logic [127:0] matrix_b,
    output logic [511:0] matrix_c,
    input logic write_en,
    output logic [3:0] counter,
    output logic valid 
); 
   
    logic read_en; 

    always_ff @ (posedge clk or posedge rst) begin 
	if (rst) begin 
		read_en <= 0; 
		valid <= 0; 
	end
	else begin 
		read_en <= write_en;
	        valid <= tile_done; 	
	end
    end 

    logic [DATA_WIDTH-1:0] in_a[N];
    logic [DATA_WIDTH-1:0] in_b[N]; 
    logic [511:0] huh; 
 
    logic [DATA_WIDTH-1:0] read_data1;
    logic [DATA_WIDTH-1:0] read_data2;
    logic [DATA_WIDTH-1:0] read_data3;
    logic [DATA_WIDTH-1:0] read_data4;
    logic [DATA_WIDTH-1:0] read_data5;
    logic [DATA_WIDTH-1:0] read_data6;
    logic [DATA_WIDTH-1:0] read_data7;
    logic [DATA_WIDTH-1:0] read_data8;

    logic full1, empty1;
    logic full2, empty2;
    logic full3, empty3;
    logic full4, empty4;
    logic full5, empty5;
    logic full6, empty6;
    logic full7, empty7;
    logic full8, empty8;
    
    logic re7; // Read enable for 7 cycles
    logic capture;

    logic [31:0] bias_arr[N]; 

    always_comb begin 
	    for (int i = 0; i < 4; i++) begin 
		    bias_arr[i] = bias[i*32+:32]; 	
            end   
    end 

    // Instantiate Systolic Array
    SystolicArray #(.N(N), .DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) dut (        
	.clk(clk), 
        .rst(rst),
	.load_bias(load_bias), 
        .bias(bias_arr), 
	.in_a(in_a), 
        .in_b(in_b), 
        .out_flat(huh) 
    ); 

    // FIFO Instances
    fifo_in1 #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(DEPTH)) fut1 ( 
        .clk(clk),
        .rst(rst), 
        .write_en(write_en),
        .read_en(re7), 
        .write_data(matrix_a[127: 96]), 
        .read_data(read_data1), 
        .full(full1),
        .empty(empty1)
    );

    fifo_in1 #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(DEPTH)) fut2 ( 
        .clk(clk),
        .rst(rst), 
        .write_en(write_en),
        .read_en(re7), 
        .write_data({matrix_b[127:120], matrix_b[95:88], matrix_b[63:56], matrix_b[31:24]}), 
        .read_data(read_data2), 
        .full(full2),
        .empty(empty2)
    );

    fifo_in2 #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(DEPTH)) fut3 ( 
        .clk(clk),
        .rst(rst), 
        .write_en(write_en),
        .read_en(re7), 
        .write_data(matrix_a[95: 64]), 
        .read_data(read_data3), 
        .full(full3),
        .empty(empty3)
    );

    fifo_in2 #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(DEPTH)) fut4 ( 
        .clk(clk),
        .rst(rst), 
        .write_en(write_en),
        .read_en(re7), 
        .write_data({matrix_b[119:112], matrix_b[87:80], matrix_b[55:48], matrix_b[23:16]}), 
        .read_data(read_data4), 
        .full(full4),
        .empty(empty4)
    );

    fifo_in3 #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(DEPTH)) fut5 ( 
        .clk(clk),
        .rst(rst), 
        .write_en(write_en),
        .read_en(re7), 
        .write_data(matrix_a[63: 32]), 
        .read_data(read_data5), 
        .full(full5),
        .empty(empty5)
    );

    fifo_in3 #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(DEPTH)) fut6 ( 
        .clk(clk),
        .rst(rst), 
        .write_en(write_en),
        .read_en(re7), 
        .write_data({matrix_b[111:104], matrix_b[79:72], matrix_b[47:40], matrix_b[15:8]}), 
        .read_data(read_data6), 
        .full(full6),
        .empty(empty6)
    );

    logic d_re7; 

    always_ff @ (posedge clk or posedge rst) begin 
	    if (rst) begin 
		    d_re7 <= 0; 		
	    end 
	    else begin 
		    d_re7 <= re7; 
	    end
    end

    fifo_in4 #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(DEPTH)) fut7 ( 
        .clk(clk),
        .rst(rst), 
        .write_en(write_en),
        .read_en(re7 || d_re7), 
        .write_data(matrix_a[31: 0]), 
        .read_data(read_data7), 
        .full(full7),
        .empty(empty7)
    );

    fifo_in4 #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(DEPTH)) fut8 ( 
        .clk(clk),
        .rst(rst), 
        .write_en(write_en),
        .read_en(re7 || d_re7), 
        .write_data({matrix_b[103:96], matrix_b[71:64], matrix_b[39:32], matrix_b[7:0]}), 
        .read_data(read_data8), 
        .full(full8),
        .empty(empty8)
    );

    // Counter and Capture Modules
    counter #(.count(COUNT)) cut ( 
        .clk(clk), 
        .rst(rst),
        .write_en(read_en),
        .out(re7)
    );

    cap #(.count(CAP)) cut1 ( 
        .clk(clk), 
        .rst(rst),
        .write_en(read_en),
        .out(capture),
	.count_reg(counter) 
    );

    // Output FIFO
    outputfifo out1 (
        .clk(clk),
        .rst(rst), 
        .wen(tile_done), 
        .in(huh),
        .out_reg(matrix_c)
    ); 

    // Properly Assign in_a and in_b Using always_comb
    always_comb begin
        in_a[0] = read_data1;
        in_a[1] = read_data3;
        in_a[2] = read_data5;
        in_a[3] = read_data7;
        in_b[0] = read_data2;
        in_b[1] = read_data4;
        in_b[2] = read_data6;
        in_b[3] = read_data8;
    end
        
endmodule
