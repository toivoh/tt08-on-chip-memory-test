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



module rtl_array3 #( parameter ADDR_BITS=5, DATA_BITS=8 ) (
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

module rtl_array3b #( parameter ADDR_BITS=5, DATA_BITS=8 ) (
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
