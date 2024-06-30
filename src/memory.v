/*
 * Copyright (c) 2024 Toivo Henningsson
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none
`include "common.vh"


module mux4 #( parameter LOG2_BITS_IN=5 ) (
		input wire [1:0] addr,
		input wire [2**LOG2_BITS_IN-1:0] data_in,
		output wire [2**(LOG2_BITS_IN-2)-1:0] data_out
	);
	genvar i;
	generate
		for (i = 0; i < 2**(LOG2_BITS_IN-2); i++) begin
			wire [3:0] data_in_i = data_in[4*i+3 -: 4];
			wire data_out_i;
			//assign data_out[i] = data_in_i[addr];
			sky130_fd_sc_hd__mux4_1 mux4_inst(
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


module memory #( parameter ADDR_BITS = `ADDR_BITS, DATA_BITS = `DATA_BITS, SERIAL_BITS = `SERIAL_BITS ) (
		input wire clk,

		input wire we,                    // write enable: write when high
		input shift_enable,               // shift without writing when high, used only for clock gated shift register memories
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
	wire [DATA_BITS-1:0] all_data[NUM_ADDR*SERIAL_BITS]; // for debugging

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

	wire [DATA_BITS-1:0] all_data[NUM_ADDR]; // for debugging

	generate
`ifdef ELEMENT_DLXTNP_CG
		wire [DATA_BITS-1:0] wdata2;
		for (i = 0; i < DATA_BITS; i++) begin
			sky130_fd_sc_hd__dlxtn_1 n_latch( .GATE_N(clk), .D(wdata[i]), .Q(wdata2[i]));
		end
`endif

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
`ifdef ELEMENT_DLXTNP_CG
				sky130_fd_sc_hd__dlxtp_1 p_latch(.GATE(gclk[j]), .D(wdata2[i]), .Q(data[j][i]));
`endif
`ifdef ELEMENT_DLXTP
				sky130_fd_sc_hd__dlxtp_1 p_latch(.GATE(data_we[j]), .D(wdata[i]), .Q(data[j][i]));
`endif
			end
			assign all_data[j] = data[j];
		end
	endgenerate

	// Mux
	// ---
	//assign rdata = data[addr];
	generate
		for (i = 0; i < DATA_BITS; i++) begin
			wire [NUM_ADDR-1:0] data_in;
			for (j = 0; j < NUM_ADDR; j++) begin
				assign data_in[j] = data[j][i];
			end
			mux #( .ADDR_BITS(ADDR_BITS) ) mux_inst ( .addr(addr), .data_in(data_in), .data_out(rdata[i]) );
		end
	endgenerate
`endif


// Array of shift registers
// ========================
`ifdef TOP_SREG_ARRAY
	genvar k;

	wire se = we || shift_enable;
	wire [DATA_BITS-1:0] wdata2 = we ? wdata : rdata; // recirculate (write back) output data if not writing

	// Demux
	// -----
	wire [NUM_ADDR-1:0] data_we;
	wire [NUM_ADDR-1:0] gclk;
	generate
		for (j = 0; j < NUM_ADDR; j++) begin
			assign data_we[j] = (addr == j) && se;

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
	wire [DATA_BITS-1:0] data_out[NUM_ADDR];
	wire [DATA_BITS-1:0] all_data[NUM_ADDR*SERIAL_BITS]; // for debugging

	generate
		for (j = 0; j < NUM_ADDR; j++) begin
			for (i = 0; i < DATA_BITS; i++) begin
				wire [SERIAL_BITS:0] sdata;
				assign sdata[0] = wdata[i];

				assign data_out[j][i] = sdata[SERIAL_BITS];
				for (k = 0; k < SERIAL_BITS; k++) begin
					sky130_fd_sc_hd__dfxtp_1 dff( .CLK(gclk[j]), .D(sdata[k]), .Q(sdata[k+1]) );

					assign all_data[j*SERIAL_BITS+k][i] = sdata[k+1];
				end
			end
		end
	endgenerate

	// Mux
	// ---
	//assign rdata = data[addr];
	generate
		for (i = 0; i < DATA_BITS; i++) begin
			wire [NUM_ADDR-1:0] data_in;
			for (j = 0; j < NUM_ADDR; j++) begin
				assign data_in[j] = data_out[j][i];
			end
			mux #( .ADDR_BITS(ADDR_BITS) ) mux_inst ( .addr(addr), .data_in(data_in), .data_out(rdata[i]) );
		end
	endgenerate
`endif


endmodule : memory
