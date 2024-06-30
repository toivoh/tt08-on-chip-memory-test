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


/*
Latch based register
*/
module latch_register #( parameter BITS=16 ) (
		input wire clk, reset,

		input wire [BITS-1:0] in,
		output wire [BITS-1:0] out,

		input wire we, // Initiate write, in must be stable between next cycle and the one after.
		output wire sampling_in, // When high, in must not be changed during the next cycle.
//		output wire in_sampled, // When high, in can be changed next cycle. Doesn't go high until we goes low.
		input wire invalidate,
		output wire out_valid // out is valid. Goes high after writing, low after invalidate.
	);

	genvar i;

	(* keep = "true" *) reg we_reg;
//	reg in_sampled_reg;
	reg valid_reg;

	always @(posedge clk) begin
		if (reset) begin
			we_reg <= 0;
//			in_sampled_reg <= 0;
			valid_reg <= 0;
		end else begin
			we_reg <= we;
//			in_sampled_reg <= we_reg && !we;
			valid_reg <= (valid_reg && !invalidate) || we;
		end
	end

`ifdef TEST_LATE_OPEN_LATCHES
	// Assume that the gate stays open an additional cycle
	reg late_we_reg;
	wire gate = we_reg || late_we_reg;

	// Model the latch with a flipflop and a mux
	reg [BITS-1:0] value;
	assign out = gate ? in : value;

	always @(posedge clk) begin
		if (reset) late_we_reg <= 0;
		else late_we_reg <= we_reg;

		if (gate) value <= in;
	end
`else
	wire gate = we_reg;
`ifdef SIM
	// Infer latches
	reg [BITS-1:0] out_latch;
	always @(*) if (gate) out_latch <= in;
	assign out = out_latch;
`else
	generate
		for (i = 0; i < BITS; i++) begin
			(* keep = "true" *) sky130_fd_sc_hd__dlxtp_1 latch(
				.D(in[i]), .GATE(gate), .Q(out[i])
			);
		end
	endgenerate
`endif
`endif

	assign sampling_in = we_reg;
//	assign in_sampled = in_sampled_reg;
	assign out_valid = valid_reg;
endmodule : latch_register


/*
Shift register based FIFO using latches.
Entries start at the top (depth=0) and fall to the bottom if there is no valid entry at the next depth.
Has a latency of at least DEPTH, but should be more area efficient.
new_entry must be stable between the cycle after add is raised and the next cycle.
*/
module SRFIFO_latched #( parameter DEPTH=32, BITS=8 ) (
		input wire clk, reset,

		input wire add, remove, // only add when can_add is high, only remove when last_valid is
		input wire [BITS-1:0] new_entry, // new_entry must be stable between the cycle after add is raised and the next cycle.
		output wire new_entry_sampled, // when high, new_entry can be changed next cycle
		output wire [BITS-1:0] last_entry,
		output wire can_add, last_valid
	);

	genvar i;

	wire [BITS-1:0] data[DEPTH+1];
	assign data[0] = new_entry;
	assign last_entry = data[DEPTH];

	wire [DEPTH:0] valid; // 1 .. DEPTH are for the latch registers
	assign valid[0] = add;
	assign can_add = !valid[1];
	assign last_valid = valid[DEPTH];

	wire [DEPTH:0] sampling_in; // 0 .. DEPTH - 1 are the latch registers
	assign sampling_in[DEPTH] = remove;

	// Transfer if the current position is valid and the next one is free
	wire [DEPTH-1:0] we = valid[DEPTH-1:0] & ~valid[DEPTH:1];
	// Invalidate when the next register reads ==> can update one cycle after the read.
	wire [DEPTH-1:0] invalidate = sampling_in[DEPTH:1];
	assign new_entry_sampled = sampling_in[0];

	generate
		for (i = 0; i < DEPTH; i++) begin
			latch_register #(.BITS(BITS)) register(
				.clk(clk), .reset(reset),
				.in(data[i]), .out(data[i+1]),
				.we(we[i]), .sampling_in(sampling_in[i]),
				.invalidate(invalidate[i]), .out_valid(valid[i+1])
			);
		end
	endgenerate
endmodule : SRFIFO_latched
