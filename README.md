![](../../workflows/gds/badge.svg) ![](../../workflows/test/badge.svg)

tt08-on-chip-memory-test: Trying different forms of on-chip memory with sky130 / OpenLane2
==========================================================================================
This repository is an attempt to compare different ways to implement on-chip memories for [Tiny Tapeout](https://tinytapeout.com/).
The main objective is size, but the more compact solutions also turn out to come with more restrictions in how they can be used, and/or be more experimental.

Method
------
A number of different configurations have been evaluated, and are described below. This section gives a brief description of the evaluation procedure.

The file `common.vh` contains defines that choose the configuration to be used.
The actual memory is implemented in `memory.v` and instantiated into the top module in `project.v`.

The cocotb test in `test/` serves as a sanity check that the memory configuration works, and was used to check new kinds of memories. It can be used for both RTL and gate level testing.
The test writes random data in a random order into the memory once, then reads it out once in another random order, and checks that the results are as expected. _This is by no means an exhaustive test, if you want to use one of these memories, please convince yourself that it works as expected._

Some of the memory types have some restrictions on how they can be used, but the test was written as least common denominator.
The testbench module in `test/tb.v` includes some `localparams` that the test uses to get the configuration of the current memory, and test accordingly.

Each configuration was hardened locally, following https://tinytapeout.com/guides/local-hardening/.
Results were collected by running `summary.sh` and copying the summary part into `results.txt`.
The summary contains info on utilization, setup and hold timing, max slew violation, and cell counts.
The max slew violation was collected manually for each run by looking at 
`runs/wokwi/51-openroad-stapostpnr/max_ss_100C_1v60/checks.rpt` and reading out the slack for the worst pin listed under "max slew" (without the minus sign).

To collect cell counts, `project.py` in the checked out https://github.com/TinyTapeout/tt-support-tools was patched according to

	 if self.args.print_cell_summary:
	-	print("# Cell usage")
	-	print()
	-	print("| Cell Name | Description | Count |")
	-	print("|-----------|-------------|-------|")
	 	for name, count in sorted(
	 		cell_count.items(), key=lambda item: item[1], reverse=True
	 	):
	 		if count > 0:
	+			if name in ("fill", "decap", "tapvpwrvgnd"): continue
	 			total += count
	 			cell_link = f"{CELL_URL}{name}"
	 			print(
	-				f'| [{name}]({cell_link}) | {defs[name]["description"]} |{count} |'
	+				f'{name.ljust(12)}\t{count}'
	 			)

	-	print(f"| | Total | {total} |")
	+	print(f"Total {total}\n")

to reduce the clutter. `fill` and `decap` cells are used to fill out unused space, and a single tile design always seems to contain 225 `tapvpwrvgnd` cells. These cell counts are removed from the listing since they don't add any information about the design.

Memory configurations
---------------------
The memory configurations to be evaluated can be described by the parameters in `common.vh`:
- depth = `2^ADDR_BITS`
- width = number of bits that can be read/written at once
- length (used for shift registers and arrays of shift registers) = how many reads/writes are needed to access the whole contents?
- top level type: selects the overall memory organization. Not all top level types support `length != 1`.
- memory cell type
- `common.vh` also contains miscellaneous options, these will be described below if needed

Using shift register memories (`length != 1`) is more restrictive, but they also turn out to be more compact.
Not all memory elements can be used freely in shift registers, though.

The aim is to compare different memory configurations with a total of 256 bits of storage, using one Tiny Tapeout tile, comparing mainly the utilization (even the least compact memories tested can fit 256 bits into one tile).

### Memory interface
The interface to the `memory` module contains the signals

	input wire clk,

	input wire we,                    // write enable: write when high
	input shift_enable,               // shift without writing when high, used only for clock gated shift register memories
	input wire [ADDR_BITS-1:0] addr,
	input wire [DATA_BITS-1:0] wdata,
	output wire [DATA_BITS-1:0] rdata

The same address is used for both reading and writing.

### Top level types
There are five top level types:
- Two RTL memories, with/without shift register support.
- Two customized memories, with/without shift register support.
- Latch-based FIFO

The RTL memories serve as a baseline, trying to implement the memory in rather straightforward RTL code, without instantiating any sky130 specific cells.
The customized memories break the memory into a few component parts, which allow them instantiate specific sky130 cells for different purposes, including use as memory elements.

### Components of a memory
The customized memories consist of
- Demultiplexer: Decodes the address and write enable signals, producing a write enable per address
- Multiplexer: Takes the output for all memory addresses, producing the output for the supplied address
- Memory cells: These store the actual bits. A memory cell has a data input, write enable, and output value.

The evaluation has focused on trying different memory cells. There might be room for improvement in the demultiplexer and multiplexer as well, but these have mostly been left as simple RTL implementations. The multiplexer implementation is a slightly less straightforward RTL implementation, since it turned out to give more compact results, using sky130 `mux4` cells for the first level of multiplexing.

Separate read/write addresses could probably have been used without much area overhead, since the write address controls the demultiplexer and the read address controls the multiplexer (see below), but this has not been tested (and the Tiny Tapeout template doesn't have enough input pins to input two 5 bit addresses and an 8 bit `wdata` from the outside). It might add some area overhead due to more complex routing.

Cell counts
-----------
The 32 x 8 x 1 (depth x width x length) RTL memory has the following cell count:

	dfxtp           256
	mux2            256
	dlygate4sd3     256
	mux4            64
	clkbuf          58
	buf             45
	a22o            32
	conb            16
	nand2           13
	and2            11
	and3            10
	or4             8
	and3b           5
	nor3b           3
	diode           3
	dlymetal6s2s    2
	nor2            1
	nor3            1
	Total 1040

I have looked at the cell counts for different configurations, and also at the netlist (`runs/wokwi/41-openroad-detailedrouting/tt_um_toivoh_on_chip_memory_test.nl`) for some configurations, including some with smaller depth x width x length.
This is my understanding of the cell counts above:
- The 256x `dftxp` are the actual memory cells, a flipflop
- To implement a write enable signal, each `dftxp` is paired with
	- a `mux2` to feed back the current value unless the write enable is high
	- a `dlygate4sd3` for hold buffering the feedback path from the current value
- The 64x `mux4` cells are used for the first stage of the multiplexer, reducing the number of signals from 256 to 64.
	- The rest of the multiplexer is implemented using random logic.
	- I tried to force using `mux4` cells for more multiplexer levels, and at one point I got not `mux4` cells at all in the multiplexer, but a single level of `mux4` cells seems to result in the smallest utilization so far.
- `clkbuf` cells are used in the clock tree, but also for buffering regular signals in some cases. It is unclear when they are used instead of `buf` cells for this purpose.
- The output pins that are tied to constant values, in this case `uio_out` and `uio_oe`, are each driven by a `conb` cell (constant value) connected to a `buf` cell.
- Other `buf` (and `clkbuf`) cells are used to buffer inputs and to replicate signals with high fanout, such as in the demultiplexer.
- I am not sure about the purpose of the 2x `dlymetal6s2s` cells, maybe they are used as some kind of buffer?

I assume that most of the random logic is used in the demultiplexer and the multiplexer.
We can see that there is some overhead here, which leaves room for improvement.

Results
-------
The full results are collected in `results.txt`, including utilization, timing information, and cell counts for each tested configuration.
The setup and hold margin for each case should only be seen as relative figures, and were taken assuming a 50 MHz clock, connecting the memory's inputs and output directly to the design's pins to keep down area overhead.

Summary of results
------------------
Here, I try to give an overview of the results.

### RTL memories
The basic RTL memory is very simple:

	reg [DATA_BITS-1:0] data[NUM_ADDR];

	assign rdata = data[addr];
	always @(posedge clk) begin
		if (we) data[addr] <= wdata;
	end

The shift register version in slightly more complex, see `memory.v`. The shift registers in this version are shifted every cycle, whether they are written to or not. This avoids having a feedback mux for every flip flop, but one is still needed per address, feeding back the output of the shift register unless there is a write into it.

The RTL memories serve as a baseline for what you can get without resorting to sky130 specific tricks.
These are just examples of course, the tools may produce different results for different RTL code.

	Type                depth   width   length   bits   utilization

	RTL array              32       8        1    256         66.50
	RTL sreg array         32       4        2    256         55.72
	RTL sreg array         32       2        4    256         47.15
	RTL sreg array         32       1        8    256         41.99
	RTL sreg array         16       1       16    256         38.64
	RTL sreg array          8       1       32    256         36.59
	RTL sreg array          2       1      128    256         35.35

It is clear that increasing the number of serial bits makes the memory more compact, with diminishing returns as the serial length increases.
Clearly, using shift registers helps to amortize some of the overhead in terms of feedback mux, demultiplexer, multiplexer, and maybe other things.

The cell count for the 2 x 1 x 128 memory is

	dfxtp           256
	dlygate4sd3     256
	buf             25
	conb            23
	clkbuf          16
	diode           6
	a21boi          1
	nand2           1
	a31o            1
	nand2b          1
	a2bb2o          1
	mux2            1
	Total 588

We see that this version avoids more or less all of the `mux2` (feedback) and `mux4` cells from the 32 x 8 x 1 version, as well as using less random logic over all. (The number of `conb` cells has gone up since there are more outputs driven to constant values.)

### Comparing different element types
Now, let us try some different memory elements for a 32 x 8 x 1 memory: (customized memory type, no shift registers)

	Type                depth   width   length   bits   utilization   note

	dfxtp array            32       8        1    256         65.48
	edfxtp array           32       8        1    256         63.22
	dfxtp + CG array       32       8        1    256         50.65   assumes that clock gates work correctly
	n + p latch CG array   32       8        1    256         43.35   assumes that latches work correctly
	raw p latch array      32       8        1    256         39.08   timing issues (see below!) + at least 3 cycles per write

The `dfxtp` case uses the same flip flop as in the RTL array, and should come close, which it does.
The `edfxtp` cell combines a flip flop with a feedback mux, avoiding the need for a `mux2` cell and a `dlygate4sd3` cell per bit. Still, the savings are quite small. It would be better if we could avoid the feedback mux altogether.

The next memory type `dfxtp + CG array` uses clock gating in the form of a sky130 `dlclkp` cell to avoid the need for a feedback mux.
The `dlclkp` cell takes a clock input and a logical input called `gate`, and produces an output `gclk`. The gated clock `gclk` is only high when `clk` is, and `gate` was high the last time it was sampled (it is sampled when `clk` is low).
The `dlclkp` cells are built into the demultiplexer to produce one `gclk` signal per address.

Using clock gating saves the `mux2` cell and a `dlygate4sd3` cell per bit. In this case, the number of `clkbuf` cells went up from 42 to 150, using 3 big `clbuf_16` cells per clock gate (one feeding two others, each feeding four flip flops), but that is still only 3 `clkbuf` cells per 8 bits.
The option `BUFFER_CLOCK_GATE` in `common.vh` can be used to insert an explicit `clkbuf` cell after each clock gate, which substantially reduces the number of clock buffers (no extra ones are added between the inserted clock buffer and the flip flops) and does not seem to degrade the timing, but for some unknown reason it causes the utilization to increase slighlty, not to decrease as expected.

To use clock gating, we must assume that OpenLane 2 handles the `dlclkp` clock gate cell correctly.
For the next two memory types, we must also assume that it handles latches correctly.

The next memory type `n + p latch CG array` uses an array of `dlxtp` positive latches, where the gate of the latch is fed using a clock gate just as in the previous case. A normal `dfxtp` flip flop is nominally composed of a `dlxtn` negative latch followed by a `dlxtp` positive latch, and this memory uses one shared negative latch per bit to feed the memory array of positive latches. This seems to make the STA happy, and ideally, this configuration should support one write per clock cycle just like the previous ones, as long as OpenLane 2 gets the setup and hold timing correct (I think). The negative latches seem to add some more overhead than expected compared to the next memory type, however.

The `raw p latch array` memory type dispenses with both clock gating and negative latches.
Removing just the negative latches makes OpenLane 2 abort, complaining about setup violations in all corners (the setup slack is exactly zero). There is probably a way to avoid this problem, but I don't know how.
By the removing the clock gates also, each latch gate is now fed directly with the write enable signal for the corresponding address. This seems to confuse OpenLane 2 enough that it doesn't complain about the setup timing, which probably means that the STA is incomplete. We get a lot of warnings in the STA result:

	Warning: There are 256 unclocked register/latch pins.
	...
	Warning: There are 272 unconstrained endpoints.
	...

listing the gate and data input pins of the latches (the additional 16 unconstrained endpoints are unused pins and should be fine).
Keeping the write enable high for a whole cycle, and not having the support of the STA, means that we need to add some margins to make sure that the memory works as intended. To get the gate level simulation test to pass, I had to use three cycles per write, keeping the address and data fixed (data could probably be different during the first cycle) and making the write enable high only during the middle cycle. This should hopefully(?) be enough to make the memory work in a real chip, but the fact that the STA does not understand everything that is going on might lead to further issues.

### Clock gated shift registers
It is hard to connect latches into a shift register, but we can do it for the `dfxtp + CG array` memory type used above.
Due to the clock gating, a shift register is only shifted when the address matches and the write enable is high. This should save a lot of power, and avoids using a feedback mux per shift register. It also means that in order read a shift register, we must write it. The version in `memory.v` includes a `shift_enable` signal, which sets the write enable, but feeds back the output read data as new write data. Reading a shift register thus causes it to shift around, but not to lose any data. In this case, the read and write addresses must be the same, but the feedback muxes can be shared between all addresses, instead of one per address as before.

	Type                depth   width   length   bits   utilization   RTL array utilization

	dfxtp CG sreg array    32       4        2    256         44.65                   55.72
	dfxtp CG sreg array    32       2        4    256         41.54                   47.15
	dfxtp CG sreg array    32       1        8    256         40.02                   41.99

The utilization for the corresponding RTL array is listed for each configuration. The overhead is clearly smaller in this case especially for short serial lengths, but at length = 8, the two are already quite close, and it is assumed that the results for longer serial lengths are more or less the same, coming down to 35% utilization or less for length = 128.

Comparing with the `n + p latch CG array` 32 x 8 x 1 memory, it seems that the `dfxtp CG sreg array` 32 x 2 x 4 memory is slightly smaller, assuming that the serial access is ok, and some further gains can be had if longer serial lengths are acceptable.

### Latch based FIFO
It is possible to connect latches into a FIFO however, using a fall-through structure where valid entries enter at top (address 0, the input) and fall to the bottom (the output). This implementation is taken from https://github.com/toivoh/tt07-basilisc-2816-cpu-experimental, where it is used as a prefetch queue.

	Type                depth   width   length   bits   utilization   note

	latch FIFO              1       8       32    256         37.75   Timing issues, can only read/write every other cycle.
	                                                                  Read must wait for entries to fall to the output.

Just like in the `raw p latch array` case, the STA gets confused:

	Warning: There are 256 unclocked register/latch pins.
	...
	Warning: There are 280 unconstrained endpoints.
	...

The FIFO can only accept a write every other cycle, and produce a new output every other cycle. Entries fall through the FIFO at one step per cycle when there is empty space below them.
The utilization is quite low despite the fact that the FIFO includes 64 flip flops on top of the 256 latches:

	dlxtp           256
	dfxtp           64
	dlygate4sd3     59
	inv             32
	and3b           32
	a31o            32
	clkbuf          25
	buf             18
	conb            16
	dlymetal6s2s    2
	Total 536

32 flip flops are needed to keep track of which entries are valid. 32 more are used to make sure that the data input to each latch is kept stable one cycle after the gate has gone low. A 16 bit wide FIFO could amortize each flip flops over twice as many latches.
