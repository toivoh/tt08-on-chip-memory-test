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
	localparam NUM_ADDR = 2**ADDR_BITS;

	genvar i;
	genvar j;

// RTL array
// =========
`ifdef TOP_RTL_ARRAY

	reg [DATA_BITS-1:0] data[NUM_ADDR];

	assign rdata = data[addr];
	always @(posedge clk) begin
		if (we) data[addr] <= wdata;
	end
`endif

// RTL array of shift registers
// ============================
`ifdef TOP_RTL_SREG_ARRAY

	wire [DATA_BITS-1:0] data_out[NUM_ADDR];
	//wire [DATA_BITS-1:0] all_data[NUM_ADDR][SERIAL_BITS];
	wire [DATA_BITS-1:0] all_data[NUM_ADDR*SERIAL_BITS];

	assign rdata = data_out[addr];
	generate
		for (j = 0; j < NUM_ADDR; j++) begin
			wire [DATA_BITS-1:0] data[SERIAL_BITS+1];
			reg [DATA_BITS-1:0] data_reg[SERIAL_BITS];

			assign data_out[j] = data[SERIAL_BITS];

			// Recirculate or write new data
			assign data[0] = we && (addr == j) ? wdata : data[SERIAL_BITS];

			for (i = 0; i < SERIAL_BITS; i++) begin
				assign data[i+1] = data_reg[i];
				always @(posedge clk) begin
					data_reg[i] <= data[i];
				end

				assign all_data[j*SERIAL_BITS + i] = data_reg[i];
			end
		end
	endgenerate
`endif

endmodule : memory
