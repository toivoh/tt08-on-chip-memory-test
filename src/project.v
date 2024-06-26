/*
 * Copyright (c) 2024 Toivo Henningsson
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_toivoh_on_chip_memory_test #( parameter ADDR_BITS=5, DATA_BITS=8 ) (
		input  wire [7:0] ui_in,    // Dedicated inputs
		output wire [7:0] uo_out,   // Dedicated outputs
		input  wire [7:0] uio_in,   // IOs: Input path
		output wire [7:0] uio_out,  // IOs: Output path
		output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
		input  wire       ena,      // always 1 when the design is powered, so you can ignore it
		input  wire       clk,      // clock
		input  wire       rst_n     // reset_n - low to reset
	);

	wire reset =!rst_n;


//	rtl_array #( .ADDR_BITS(ADDR_BITS), .DATA_BITS(DATA_BITS) ) mem(
//	rtl_vector0 #( .ADDR_BITS(ADDR_BITS) ) mem(
//	rtl_array2 #( .ADDR_BITS(ADDR_BITS), .DATA_BITS(DATA_BITS) ) mem(
	rtl_array2b #( .ADDR_BITS(ADDR_BITS), .DATA_BITS(DATA_BITS) ) mem(
		.clk(clk), .reset(reset),
		.we(ui_in[7]),
		.addr(ui_in[ADDR_BITS-1:0]),
		.wdata(uio_in),
		.rdata(uo_out)
	);

	assign uio_out = 0;
	assign uio_oe  = 0;

	// List all unused inputs to prevent warnings
	wire _unused = &{ena, 1'b0};

endmodule
