/*
 * Copyright (c) 2024 Toivo Henningsson
 * SPDX-License-Identifier: Apache-2.0
 */

`define ADDR_BITS 5
`define DATA_BITS 8
`define SERIAL_BITS 1


// Choose top memory structure
// ===========================

//`define TOP_RTL_ARRAY  // not valid when SERIAL_BITS != 1
`define TOP_ARRAY        // not valid when SERIAL_BITS != 1
//`define TOP_RTL_SREG_ARRAY


// Choose memory element for non-RTL array
// =======================================

//`define ELEMENT_DFXTP     // flip-flop with external mux for enable
//`define ELEMENT_EDFXTP  // flip-flop with enable
//`define ELEMENT_DFXTP_CG  // flip-flop with external clock gate
`define ELEMENT_DLXTNP_CG  // dlxtp latch with external clock gate, fed by dlxtn latch

// Misc options
// ============

// Add explicit clock buffer after clock gates? Seems to reduces the number of clock buffers, but still increase the utilization?
//`define BUFFER_CLOCK_GATE
