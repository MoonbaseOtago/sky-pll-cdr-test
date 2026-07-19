/*
 * Copyright (c) 2026 Paul Campbell
 * SPDX-License-Identifier: Apache-2.0
 */

/* verilator lint_off TIMESCALEMOD */

`timescale 1ns/1fs
`default_nettype none

/* verilator lint_off SYNCASYNCNET */
module deskew(
`ifdef GL_TEST
            inout VPWR, inout VGND,
`endif
	input   CLK, 
	input RESET_N, input RESTART,

	// incoming data
	input DIN,
	input REV,

	input [9:0]DO,
	input      XMT_READY,
	input	   XMT_RD,

	output	    CLK10,	// divide by 10 interface
	output [9:0]DI,
	output      SYNCED, 
	output      SYNCING,
	output      RESET_OUT_N,

	output	   DOUT
	);
endmodule


/* verilator lint_on SYNCASYNCNET */
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

