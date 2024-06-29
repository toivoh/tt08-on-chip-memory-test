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

	NUM_ADDR = 2**ADDR_BITS
	NUM_CODES = 2**DATA_BITS

	print("ADDR_BITS =", ADDR_BITS);
	print("DATA_BITS =", DATA_BITS);
	print("SERIAL_BITS =", SERIAL_BITS);

	data = [randrange(NUM_CODES) for i in range(NUM_ADDR)]
	#print("data =", data)

	# Write data into the memory in random order
	order = sample(range(NUM_ADDR), NUM_ADDR)
	#print("write order =", order)
	for addr in order:
		dut.ui_in.value = addr | 128 # set addr, we = 1
		dut.uio_in.value = data[addr]

		await ClockCycles(dut.clk, 1)

	# Read data in random order
	order = sample(range(NUM_ADDR), NUM_ADDR)
	#print("read order =", order)
	for addr in order:
		dut.ui_in.value = addr # set addr, we = 0

		await ClockCycles(dut.clk, 1)

		rdata = dut.uo_out.value.to_unsigned()
		assert rdata == data[addr]
		#print((rdata, data[addr]))

	print("\nMemory test succesful!")
