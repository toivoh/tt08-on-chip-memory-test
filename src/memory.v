/*
 * Copyright (c) 2024 Toivo Henningsson
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none
`include "common.vh"


module memory #( parameter ADDR_BITS = `ADDR_BITS, DATA_BITS = `DATA_BITS, SERIAL_BITS = `SERIAL_BITS ) (
		input wire clk,

		input wire we,
		input wire [ADDR_BITS-1:0] addr,
		input wire [DATA_BITS-1:0] wdata,
		output wire [DATA_BITS-1:0] rdata
	);

// RTL array
// =========

	reg [DATA_BITS-1:0] data[2**ADDR_BITS];

	assign rdata = data[addr];
	always @(posedge clk) begin
		if (we) data[addr] <= wdata;
	end

endmodule : memory
