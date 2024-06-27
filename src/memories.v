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
//			rtl_vector #( .ADDR_BITS(ADDR_BITS) ) mem(
			edfxtp_vector #( .ADDR_BITS(ADDR_BITS) ) mem(
				.clk(clk), .reset(reset),
				.data_we(data_we),
				.addr(addr),
				.wdata(wdata[i]),
				.rdata(rdata[i])
			);
		end
	endgenerate
endmodule


module rtl_array2c #( parameter ADDR_BITS=5, DATA_BITS=8 ) (
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
			cg_dfxtp_vector #( .ADDR_BITS(ADDR_BITS) ) mem(
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
			sky130_fd_sc_hd__dfxtp_1 dff( .CLK(gclk), .D(data[i]), .Q(data[i+1]) );

			/*
			wire q;
			sky130_fd_sc_hd__dfxtp_1 dff( .CLK(clk), .D(data[i]), .Q(q) );
			//sky130_fd_sc_hd__buf_1 buffer( .A(q), .X(data[i+1]) );
			sky130_fd_sc_hd__clkbuf_1 buffer( .A(q), .X(data[i+1]) );
			*/
		end
	endgenerate

endmodule
