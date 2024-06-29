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

// RTL array (assumes SERIAL_BITS = 1)
// ===================================
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

// Array (assumes SERIAL_BITS = 1)
// ===============================
`ifdef TOP_ARRAY

	// Demux
	// -----
	wire [NUM_ADDR-1:0] data_we;
	wire [NUM_ADDR-1:0] gclk;
	generate
		for (j = 0; j < NUM_ADDR; j++) begin
			assign data_we[j] = (addr == j) && we;

			`ifndef BUFFER_CLOCK_GATE
			sky130_fd_sc_hd__dlclkp_1 clock_gate( .CLK(clk), .GATE(data_we[j]), .GCLK(gclk[j]) );
			`else
			// Reduces the number of clock buffers, but still seems to increase the utilization:
			wire _gclk;
			sky130_fd_sc_hd__dlclkp_1 clock_gate( .CLK(clk), .GATE(data_we[j]), .GCLK(_gclk) );
			sky130_fd_sc_hd__clkbuf_4 clock_buffer( .A(_gclk), .X(gclk[j]) );
			`endif
		end
	endgenerate

	// Memory array
	// ------------
	wire [DATA_BITS-1:0] data[NUM_ADDR];

	wire [DATA_BITS-1:0] all_data[NUM_ADDR];

	generate
		for (j = 0; j < NUM_ADDR; j++) begin
			for (i = 0; i < DATA_BITS; i++) begin
`ifdef ELEMENT_DFXTP
				sky130_fd_sc_hd__dfxtp_1 dff(.CLK(clk), .D(data_we[j] ? wdata[i] : data[j][i]), .Q(data[j][i]));
`endif
`ifdef ELEMENT_EDFXTP
				sky130_fd_sc_hd__edfxtp_1 edff(.CLK(clk), .D(wdata[i]), .DE(data_we[j]), .Q(data[j][i]));
`endif
`ifdef ELEMENT_DFXTP_CG
				sky130_fd_sc_hd__dfxtp_1 dff(.CLK(gclk[j]), .D(wdata[i]), .Q(data[j][i]));
`endif
			end
			assign all_data[j] = data[j];
		end
	endgenerate

	// Mux
	// ---
	assign rdata = data[addr];
`endif

endmodule : memory
