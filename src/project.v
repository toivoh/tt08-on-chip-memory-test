/*
 * Copyright (c) 2024 Toivo Henningsson
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none
`include "common.vh"

module tt_um_toivoh_on_chip_memory_test #( parameter ADDR_BITS = `ADDR_BITS, DATA_BITS = `DATA_BITS, SERIAL_BITS = `SERIAL_BITS ) (
		input  wire [7:0] ui_in,    // Dedicated inputs
		output wire [7:0] uo_out,   // Dedicated outputs
		input  wire [7:0] uio_in,   // IOs: Input path
		output wire [7:0] uio_out,  // IOs: Output path
		output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
		input  wire       ena,      // always 1 when the design is powered, so you can ignore it
		input  wire       clk,      // clock
		input  wire       rst_n     // reset_n - low to reset
	);

	wire [DATA_BITS-1:0] rdata;

`ifndef TOP_LATCH_FIFO
	memory mem(
		.clk(clk),
		.we(ui_in[7]),
		.shift_enable(ui_in[6]),
		.addr(ui_in[ADDR_BITS-1:0]),
		.wdata(uio_in[DATA_BITS-1:0]),
		.rdata(rdata)
	);
`else
	SRFIFO_latched #( .DEPTH(SERIAL_BITS), .BITS(DATA_BITS) ) fifo(
		.clk(clk), .reset(!rst_n),
		.add(ui_in[7]),
		.remove(ui_in[6]),
		.new_entry(uio_in[DATA_BITS-1:0]),
		.last_entry(rdata)
	);
`endif

	assign uo_out = { {(8-DATA_BITS){1'b0}}, rdata };

	assign uio_out = 0;
	assign uio_oe  = 0;

	// List all unused inputs to prevent warnings
	wire _unused = &{ena, rst_n, ui_in, uio_in, 1'b0};
endmodule
