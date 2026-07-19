/*
 * Copyright (c) 2026 Paul Campbell
 * SPDX-License-Identifier: Apache-2.0
 */


`default_nettype none

`timescale 1ns/1fs


/* verilator lint_off SYNCASYNCNET */
module cdrs(
`ifdef GL_TEST
            inout VPWR, inout VGND,
`endif
	input   CLKI, input CLKI_N, input CLKQ, input CLKQ_N,

	input RESET_N, input RESTART,

	// incoming data
	input DIN,
	input REV,

	input [9:0]DO,
	input      XMT_READY,
	input	   XMT_RD,

	output     RESET,
	output UP_N, output DOWN_N ,

	output	    CLK10,	// divide by 10 interface
	output [9:0]DI,
	output      SYNCED, 
	output      SYNCING,
	output      RESET_OUT_N,


	output	   DOUT
	);
endmodule

/* verilator lint_on */
/* For Emacs:
 * Local Variables: 
 * mode:c         
 * indent-tabs-mode:t
 * tab-width:4
 * c-basic-offset:4
 * End:     
 * For VIM: 
 * vim:set softtabstop=4 shiftwidth=4 tabstop=4:
 */ 

