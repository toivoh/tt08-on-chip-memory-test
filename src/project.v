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

	localparam BITS = 2**ADDR_BITS * DATA_BITS;

	wire reset =!rst_n;

/*
	wire [7:0] uo_out0;
	reg [7:0] ui_in_reg, uio_in_reg, uo_out_reg;
	always @(posedge clk) begin
		ui_in_reg <= ui_in;
		uio_in_reg <= uio_in;
		uo_out_reg <= uo_out0;
	end
	assign uo_out = uo_out_reg;
*/


//	rtl_array #( .ADDR_BITS(ADDR_BITS), .DATA_BITS(DATA_BITS) ) mem(
//	rtl_vector0 #( .ADDR_BITS(ADDR_BITS) ) mem(
//	rtl_array2 #( .ADDR_BITS(ADDR_BITS), .DATA_BITS(DATA_BITS) ) mem(
	rtl_array2b #( .ADDR_BITS(ADDR_BITS), .DATA_BITS(DATA_BITS) ) mem(
//	rtl_array2c #( .ADDR_BITS(ADDR_BITS), .DATA_BITS(DATA_BITS) ) mem(
		.clk(clk), .reset(reset),
		.we(ui_in[7]),
		.addr(ui_in[ADDR_BITS-1:0]),
		.wdata(uio_in),
		.rdata(uo_out)
		/*
		.addr(ui_in_reg[ADDR_BITS-1:0]),
		.wdata(uio_in_reg),
		.rdata(uo_out0)
		*/
	);

	/*

	wire data_out;
	shift_register #( .BITS(BITS) ) sreg(
		.clk(clk), .reset(reset),
		.we(ui_in[7]),
		.data_in(ui_in[0]),
		.data_out(data_out)
	);
	assign uo_out = data_out;

	*/


	assign uio_out = 0;
	assign uio_oe  = 0;

	// List all unused inputs to prevent warnings
	wire _unused = &{ena, 1'b0};

endmodule
