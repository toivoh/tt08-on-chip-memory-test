# Copyright (c) 2024 Toivo Henningsson
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

from random import randrange, sample

@cocotb.test()
async def test_project(dut):
	dut._log.info("start")
	clock = Clock(dut.clk, 2, units="us")
	cocotb.start_soon(clock.start())

	# reset
	dut._log.info("reset")
	dut.rst_n.value = 0
	dut.ui_in.value = 0
	dut.uio_in.value = 0
	await ClockCycles(dut.clk, 10)
	dut.rst_n.value = 1

	print("\nStarting memory test")
	print(  "====================")
	ADDR_BITS = dut.ADDR_BITS.value.to_unsigned();
	DATA_BITS = dut.DATA_BITS.value.to_unsigned();
	SERIAL_BITS = dut.SERIAL_BITS.value.to_unsigned();
	PRE_POST_WRITE_DELAY = dut.PRE_POST_WRITE_DELAY.value.to_unsigned();

	NUM_ADDR = 2**ADDR_BITS
	NUM_CODES = 2**DATA_BITS

	print("ADDR_BITS =", ADDR_BITS);
	print("DATA_BITS =", DATA_BITS);
	print("SERIAL_BITS =", SERIAL_BITS);
	print("PRE_POST_WRITE_DELAY =", PRE_POST_WRITE_DELAY);

	data = [[randrange(NUM_CODES) for j in range(SERIAL_BITS)] for i in range(NUM_ADDR)]
	#data = [[i*SERIAL_BITS+j for j in range(SERIAL_BITS)] for i in range(NUM_ADDR)]
	#print("data =", data)

	# Write data into the memory in random order
	order = sample(range(NUM_ADDR), NUM_ADDR)
	#order = range(NUM_ADDR)
	#print("write order =", order)
	for addr in order:
		if PRE_POST_WRITE_DELAY > 0: # Needed to make the GL test pass for raw dlxtp
			dut.ui_in.value = addr # set addr, we = 0
			await ClockCycles(dut.clk, PRE_POST_WRITE_DELAY)

		for i in range(SERIAL_BITS):
			dut.ui_in.value = addr | 128 # set addr, we = 1
			dut.uio_in.value = data[addr][i]

			await ClockCycles(dut.clk, 1)

		if PRE_POST_WRITE_DELAY > 0: # Needed to make the test pass for raw dlxtp
			dut.ui_in.value = addr # set addr, we = 0
			await ClockCycles(dut.clk, PRE_POST_WRITE_DELAY)

		if False:
			print(f"addr = {addr}, i = {i}")
			all_data = dut.user_project.mem.all_data
			#ad = [[str(all_data[j][i].value) for i in range(SERIAL_BITS)] for j in range(NUM_ADDR)]
			ad = [[str(all_data[j*SERIAL_BITS+i].value) for i in range(SERIAL_BITS)] for j in range(NUM_ADDR)]
			print("all_data =", ad)


	# Read data in random order
	order = sample(range(NUM_ADDR), NUM_ADDR)
	#print("read order =", order)
	for addr in order:
		for i in range(SERIAL_BITS):
			dut.ui_in.value = addr | 64 # set addr, we = 0, shift_enable = 1

			await ClockCycles(dut.clk, 1)

			rdata = dut.uo_out.value.to_unsigned()
			assert rdata == data[addr][i]
			#print((rdata, data[addr][i]))

	print("\nMemory test succesful!\n")
