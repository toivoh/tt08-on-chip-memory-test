`default_nettype none
`timescale 1ns / 1ps

`include "../src/common.vh"

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/
module tb ();

// Dump the signals to a VCD file. You can view it with gtkwave.
	initial begin
		$dumpfile("tb.vcd");
		$dumpvars(0, tb);
		#1;
	end

	// Wire up the inputs and outputs:
	reg clk;
	reg rst_n;
	reg ena;
	reg [7:0] ui_in;
	reg [7:0] uio_in;
	wire [7:0] uo_out;
	wire [7:0] uio_out;
	wire [7:0] uio_oe;

	tt_um_toivoh_on_chip_memory_test user_project (

		// Include power ports for the Gate Level test:
`ifdef GL_TEST
		.VPWR(1'b1),
		.VGND(1'b0),
`endif

		.ui_in  (ui_in),    // Dedicated inputs
		.uo_out (uo_out),   // Dedicated outputs
		.uio_in (uio_in),   // IOs: Input path
		.uio_out(uio_out),  // IOs: Output path
		.uio_oe (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
		.ena    (ena),      // enable - goes high when design is selected
		.clk    (clk),      // clock
		.rst_n  (rst_n)     // not reset
	);

	// Expose parameters for testing:
	localparam ADDR_BITS = `ADDR_BITS;
	localparam DATA_BITS = `DATA_BITS;
	localparam SERIAL_BITS = `SERIAL_BITS;

`ifdef ELEMENT_DLXTP
	localparam PRE_POST_WRITE_DELAY = 1;
`else
	localparam PRE_POST_WRITE_DELAY = 0;
`endif

`ifdef TOP_LATCH_FIFO
	localparam LATCH_FIFO = 1;
`else
	localparam LATCH_FIFO = 0;
`endif

/*
	// For debugging
	wire [`DATA_BITS-1:0] data0 = user_project.mem.all_data[0];
	wire [`DATA_BITS-1:0] data1 = user_project.mem.all_data[1];
	wire [`DATA_BITS-1:0] data2 = user_project.mem.all_data[2];
	wire [`DATA_BITS-1:0] data3 = user_project.mem.all_data[3];
*/

endmodule
