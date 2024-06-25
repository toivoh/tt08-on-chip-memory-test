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
