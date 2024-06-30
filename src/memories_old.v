/*
 * Copyright (c) 2024 Toivo Henningsson
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module rtl_array #( parameter ADDR_BITS=5, DATA_BITS=8 ) (
		input wire clk, reset,

		input wire we,
		input wire [ADDR_BITS-1:0] addr,
		input wire [DATA_BITS-1:0] wdata,
		output wire [DATA_BITS-1:0] rdata
	);

	reg [DATA_BITS-1:0] data[2**ADDR_BITS];

	assign rdata = data[addr];
	always @(posedge clk) begin
		if (we) data[addr] <= wdata;
	end

endmodule


module mux4 #( parameter LOG2_BITS_IN=5 ) (
		input wire [1:0] addr,
		input wire [2**LOG2_BITS_IN-1:0] data_in,
		output wire [2**(LOG2_BITS_IN-2)-1:0] data_out
	);
	genvar i;
	generate
		for (i = 0; i < 2**(LOG2_BITS_IN-2); i++) begin
			wire [3:0] data_in_i = data_in[4*i+3 -: 4];
			/*(* keep = "true" *)*/ wire data_out_i;
			//assign data_out[i] = data_in_i[addr];
			/*(* keep = true *)*/ sky130_fd_sc_hd__mux4_1 mux4_inst(
				.A0(data_in_i[0]), .A1(data_in_i[1]), .A2(data_in_i[2]), .A3(data_in_i[3]),
				.S0(addr[0]), .S1(addr[1]),
				.X(data_out_i)
			);
			assign data_out[i] = data_out_i;

		end
	endgenerate
endmodule

module mux #( parameter ADDR_BITS=5 ) (
		input wire [ADDR_BITS-1:0] addr,
		input wire [2**ADDR_BITS-1:0] data_in,
		output wire data_out
	);

	assign data_out = data_in[addr];
/*
	wire [2**(ADDR_BITS-2)-1:0] data1;
	wire [2**(ADDR_BITS-4)-1:0] data2;
	mux4 #( .LOG2_BITS_IN(ADDR_BITS  ) ) mux4_inst1( .addr(addr[1:0]), .data_in(data_in), .data_out(data1) );
	mux4 #( .LOG2_BITS_IN(ADDR_BITS-2) ) mux4_inst2( .addr(addr[3:2]), .data_in(data1  ), .data_out(data2) );
	assign data_out = data2[addr[ADDR_BITS-1:4]];
*/
endmodule


module rtl_vector0 #( parameter ADDR_BITS=5 ) (
		input wire clk, reset,

		input wire we,
		input wire [ADDR_BITS-1:0] addr,
		input wire wdata,
		output wire rdata
	);

	localparam NUM = 2**ADDR_BITS;

	genvar i;


	// Memory array

	wire [NUM-1:0] data_we;
	reg [NUM-1:0] data;

	generate
		for (i = 0; i < NUM; i++) begin
			always @(posedge clk) begin
				if (data_we[i]) data[i] <= wdata; // data_in[i];
			end
		end
	endgenerate

	// Demux
	generate
		for (i = 0; i < NUM; i++) begin
			assign data_we[i] = (addr == i) && we;
		end
	endgenerate

	// Mux

	assign rdata = data[addr];
endmodule


module rtl_vector #( parameter ADDR_BITS=5 ) (
		input wire clk, reset,

		input wire [2**ADDR_BITS-1:0] data_we,
		input wire [ADDR_BITS-1:0] addr,
		input wire wdata,
		output wire rdata
	);

	localparam NUM = 2**ADDR_BITS;

	genvar i;


	// Memory array

	reg [NUM-1:0] data;
	generate
		for (i = 0; i < NUM; i++) begin
			always @(posedge clk) begin
				if (data_we[i]) data[i] <= wdata; // data_in[i];
			end
		end
	endgenerate

	// Mux

	assign rdata = data[addr];
endmodule


module edfxtp_vector #( parameter ADDR_BITS=5 ) (
		input wire clk, reset,

		input wire [2**ADDR_BITS-1:0] data_we,
		input wire [ADDR_BITS-1:0] addr,
		input wire wdata,
		output wire rdata
	);

	localparam NUM = 2**ADDR_BITS;

	genvar i;

	// Memory array

	wire [NUM-1:0] data;
	generate
		for (i = 0; i < NUM; i++) begin
			sky130_fd_sc_hd__edfxtp_1 eff(
				.CLK(clk), .D(wdata), .DE(data_we[i]), .Q(data[i])
			);
		end
	endgenerate

	// Mux

	assign rdata = data[addr];
endmodule

module cg_dfxtp_vector #( parameter ADDR_BITS=5 ) (
		input wire clk,
		input wire [2**ADDR_BITS-1:0] gclk,
		input wire reset,

		input wire [ADDR_BITS-1:0] addr,
		input wire wdata,
		output wire rdata
	);

	localparam NUM = 2**ADDR_BITS;

	genvar i;

	// Memory array

	wire [NUM-1:0] data;
	generate
		for (i = 0; i < NUM; i++) begin
			sky130_fd_sc_hd__dfxtp_1 ff(
				.CLK(gclk[i]), .D(wdata), .Q(data[i])
			);
		end
	endgenerate

	// Mux
	//assign rdata = data[addr];
	mux #( .ADDR_BITS(ADDR_BITS) ) mux_inst ( .addr(addr), .data_in(data), .data_out(rdata) );
endmodule

module cg_dfxtp_sreg_vector #( parameter ADDR_BITS=4, SERIAL_BITS=2 ) (
		input wire clk,
		input wire [2**ADDR_BITS-1:0] gclk,
		input wire reset,

		input wire [ADDR_BITS-1:0] addr,
		input wire wdata,
		output wire rdata
	);

	localparam NUM = 2**ADDR_BITS;

	genvar i, j;

	// Memory array

	wire [NUM-1:0] data;
	generate
		for (i = 0; i < NUM; i++) begin
			wire [SERIAL_BITS:0] sdata;
			assign sdata[0] = wdata;
			assign data[i] = sdata[SERIAL_BITS];
			for (j = 0; j < SERIAL_BITS; j++) begin
				sky130_fd_sc_hd__dfxtp_1 ff(
					.CLK(gclk[i]), .D(sdata[j]), .Q(sdata[j+1])
				);
			end
		end
	endgenerate

	// Mux
	//assign rdata = data[addr];
	mux #( .ADDR_BITS(ADDR_BITS) ) mux_inst ( .addr(addr), .data_in(data), .data_out(rdata) );
endmodule

module cg_dlxtp_vector #( parameter ADDR_BITS=5 ) (
		input wire clk,
		input wire [2**ADDR_BITS-1:0] gclk,
		input wire reset,

		input wire [ADDR_BITS-1:0] addr,
		input wire wdata,
		output wire rdata
	);

	localparam NUM = 2**ADDR_BITS;

	genvar i;

	// Memory array
	wire wdata2;
	sky130_fd_sc_hd__dlxtn_1 nlatch( .GATE_N(clk), .D(wdata), .Q(wdata2));

	wire [NUM-1:0] data;
	generate
		for (i = 0; i < NUM; i++) begin
			sky130_fd_sc_hd__dlxtp_1 ff(
				.GATE(gclk[i]), .D(wdata2), .Q(data[i])
			);
		end
	endgenerate

	// Mux

	assign rdata = data[addr];
endmodule



module rtl_array2 #( parameter ADDR_BITS=5, DATA_BITS=8 ) (
		input wire clk, reset,

		input wire we,
		input wire [ADDR_BITS-1:0] addr,
		input wire [DATA_BITS-1:0] wdata,
		output wire [DATA_BITS-1:0] rdata
	);

	genvar i;

	generate
		for (i = 0; i < DATA_BITS; i++) begin
			rtl_vector0 #( .ADDR_BITS(ADDR_BITS) ) mem(
				.clk(clk), .reset(reset),
				.we(we),
				.addr(addr),
				.wdata(wdata[i]),
				.rdata(rdata[i])
			);
		end
	endgenerate
endmodule

module rtl_array2b #( parameter ADDR_BITS=5, DATA_BITS=8 ) (
		input wire clk, reset,

		input wire we,
		input wire [ADDR_BITS-1:0] addr,
		input wire [DATA_BITS-1:0] wdata,
		output wire [DATA_BITS-1:0] rdata
	);

	localparam NUM = 2**ADDR_BITS;

	genvar i;

	// Demux
	wire [2**ADDR_BITS-1:0] data_we;
	generate
		for (i = 0; i < NUM; i++) begin
			assign data_we[i] = (addr == i) && we;
		end
	endgenerate

	generate
		for (i = 0; i < DATA_BITS; i++) begin
/*
//			rtl_vector #( .ADDR_BITS(ADDR_BITS) ) mem(
			edfxtp_vector #( .ADDR_BITS(ADDR_BITS) ) mem(
				.clk(clk), .reset(reset),
				.data_we(data_we),
				.addr(addr),
				.wdata(wdata[i]),
				.rdata(rdata[i])
			);
*/
			cg_dlxtp_vector #( .ADDR_BITS(ADDR_BITS) ) mem(
				.gclk(data_we), .reset(reset),
				.addr(addr),
				.wdata(wdata[i]),
				.rdata(rdata[i])
			);
		end
	endgenerate
endmodule


module rtl_array2c #( parameter ADDR_BITS=5, DATA_BITS=8, SERIAL_BITS=1 ) (
		input wire clk, reset,

		input wire we,
		input wire [ADDR_BITS-1:0] addr,
		input wire [DATA_BITS-1:0] wdata,
		output wire [DATA_BITS-1:0] rdata
	);

	localparam NUM = 2**ADDR_BITS;

	genvar i;

	// Demux
	wire [NUM-1:0] data_we;
	wire [NUM-1:0] gclk;
	generate
		for (i = 0; i < NUM; i++) begin
			assign data_we[i] = (addr == i) && we;
			
			//sky130_fd_sc_hd__dlclkp_4 clock_gate( .CLK(clk), .GATE(data_we[i]), .GCLK(gclk[i]) );
			sky130_fd_sc_hd__dlclkp_1 clock_gate( .CLK(clk), .GATE(data_we[i]), .GCLK(gclk[i]) );

			/*
			// Reduces the number of clock buffers, but still seems to increase the utilization:
			wire _gclk;
			sky130_fd_sc_hd__dlclkp_1 clock_gate( .CLK(clk), .GATE(data_we[i]), .GCLK(_gclk) );
			sky130_fd_sc_hd__clkbuf_4 clock_buffer( .A(_gclk), .X(gclk[i]) );
			*/
		end
	endgenerate

	generate
		for (i = 0; i < DATA_BITS; i++) begin
			//cg_dfxtp_vector #( .ADDR_BITS(ADDR_BITS) ) mem(
			//cg_dlxtp_vector #( .ADDR_BITS(ADDR_BITS) ) mem(
			cg_dfxtp_sreg_vector #( .ADDR_BITS(ADDR_BITS), .SERIAL_BITS(SERIAL_BITS) ) mem(
				.clk(clk),
				.gclk(gclk), .reset(reset),
				.addr(addr),
				.wdata(wdata[i]),
				.rdata(rdata[i])
			);
		end
	endgenerate
endmodule



module shift_register #( parameter BITS=256 ) (
		input wire clk, reset,

		input wire we,
		input wire data_in,
		output wire data_out
	);

	genvar i;

	wire [BITS:0] data;
	assign data[0] = data_in;
	assign data_out = data[BITS];


	wire gclk;
	sky130_fd_sc_hd__dlclkp_4 clock_gate( .CLK(clk), .GATE(we), .GCLK(gclk) );
	generate
		for (i = 0; i < BITS; i++) begin
			//sky130_fd_sc_hd__dfxtp_1 dff( .CLK(clk), .D(data[i]), .Q(data[i+1]) );
			//sky130_fd_sc_hd__edfxtp_1 edff( .CLK(clk), .D(data[i]), .DE(we), .Q(data[i+1]) );
			//sky130_fd_sc_hd__dfxtp_1 dff( .CLK(gclk), .D(data[i]), .Q(data[i+1]) );

			// n-latch feeding p-latch avoids setup timing problems
			if (i&1) sky130_fd_sc_hd__dlxtp_1 latch(   .GATE(gclk),   .D(data[i]), .Q(data[i+1]) );
			else     sky130_fd_sc_hd__dlxtn_1 latch_n( .GATE_N(gclk), .D(data[i]), .Q(data[i+1]) );

			/*
			wire q;
			sky130_fd_sc_hd__dfxtp_1 dff( .CLK(clk), .D(data[i]), .Q(q) );
			//sky130_fd_sc_hd__buf_1 buffer( .A(q), .X(data[i+1]) );
			sky130_fd_sc_hd__clkbuf_1 buffer( .A(q), .X(data[i+1]) );
			*/
		end
	endgenerate

endmodule
