/*
 * Copyright (c) 2026 Paul Campbell
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none


`timescale 1ns/1ps

module pll(input RESET_N,
`ifdef GL_TEST
            inout VPWR, inout VGND,
`endif
	output COUNT_OUT, output LOCKABLE,
	output RESET_OUT_N, input REFCLK, input COUNT_3, input COUNT_2, input COUNT_1, input COUNT_0, output CLK

	// don't use the following pins, they are for spice testing
`ifdef NOTDEF
	,output VCTRL, output UP, output UP_N, output DOWN, output DOWN_N, output BD, output BU
`endif

`ifdef TEST
	reg r_RESET_OUT_N, r_CLK;
	assign CLK = r_CLK;
	assign RESET_OUT_N = r_RESET_OUT_N;

	reg [3:0]c;
	always @ (posedge r_CLK) begin
		c<= c+1;
		if (c== 15)
			r_RESET_OUT_N <= 1
	end

	always @(negedge RESET_N) begin
		r_RESET_OUT_N <= 0;
		count = 0;
	end

	wire c
	reg [3:0]count = {COUNT_3,COUNT_2,COUNT_1,COUNT_0};
	reg [31:0]freq;
	always @(*)
	case (count)
	0: freq = 25;
	1: freq = 50;
	2: freq = 75;
	3: freq = 100;
	4: freq = 125;
	5: freq = 150;
	6: freq = 175;
	7: freq = 200;
	8: freq = 225;
	9: freq = 250;
	10: freq = 275;
	11: freq = 300;
	12: freq = 325;
	13: freq = 350;
	14: freq = 375;
	15: freq = 400;
	endcase
	reg [31:0]delay = 1000000/freq/2;
	initial begin
		r_CLK <= 0;
		#10
		forever #(delay) r_CLK <= ~r_CLK;
	end
	
`endif

);
endmodule
