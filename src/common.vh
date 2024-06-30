/*
 * Copyright (c) 2024 Toivo Henningsson
 * SPDX-License-Identifier: Apache-2.0
 */

`define ADDR_BITS 5
`define DATA_BITS 1
`define SERIAL_BITS 8


// Choose top memory structure
// ===========================

//`define TOP_RTL_ARRAY       	// not valid when SERIAL_BITS != 1
//`define TOP_ARRAY           	// not valid when SERIAL_BITS != 1
`define TOP_RTL_SREG_ARRAY
//`define TOP_SREG_ARRAY      	// always clock gated dfxtp


// Choose memory element for TOP_RTL_SREG_ARRAY
// ============================================

`define ELEMENT_DFXTP       	// flip-flop with external mux for enable
//`define ELEMENT_EDFXTP      	// flip-flop with enable
//`define ELEMENT_DFXTP_CG    	// flip-flop with external clock gate
//`define ELEMENT_DLXTNP_CG   	// dlxtp latch with external clock gate, fed by dlxtn latch

// Confuses timing analysis, must keep address and data stable one cycle after write and address one before too (sets PRE_POST_WRITE_DELAY = 1):
//`define ELEMENT_DLXTP       	// dlxtp latch with write enable directly on the gate


// Misc options
// ============

// Add explicit clock buffer after clock gates? Seems to reduces the number of clock buffers, but still increase the utilization?
//`define BUFFER_CLOCK_GATE
