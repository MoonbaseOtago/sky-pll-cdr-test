/*
 * Copyright (c) 2026 Paul Campbell
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none


`timescale 1ns/1ps

module pll2(input RESET_N,
`ifdef GL_TEST
            inout VPWR, inout VGND,
`endif
	output COUNT_OUT, output LOCKABLE,
	output RESET_OUT_N, input REFCLK, input COUNT_3, input COUNT_2, input COUNT_1, input COUNT_0, output CLK

	// don't use the following pins, they are for spice testing
`ifdef NOTDEF
	,output VCTRL, output UP, output UP_N, output DOWN, output DOWN_N, output BD, output BU
`endif
	);

endmodule
