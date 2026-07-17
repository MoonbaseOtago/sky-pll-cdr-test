/*
 * Copyright (c) 2026 Paul Campbell
 * SPDX-License-Identifier: Apache-2.0
 */

`timescale 1ns/1ps


module upstream(input reset_n, input refclk,
`ifdef GL_TEST
            inout VPWR, inout VGND,
`endif
			input [3:0]pll_count,
			input      pll_test,

			input din, output dout,

			output	    clk10,
			output      reset_out_n,

			output [7:0]rcv_out,
			output      rcv_k,
			output		rcv_ready,
			output	    rcv_align,

			input  [7:0]xmt_in,
			input       xmt_k,
			input       xmt_ready
			);

    wire RESET_PLL_OUT_N;
    wire CLK;
	wire COUNT_OUT, LOCKABLE;

	pll2 pll(.RESET_N(reset_n),
`ifdef GL_TEST
            .VPWR(VPWR), .VGND(VGND),
`endif

        .RESET_OUT_N(RESET_PLL_OUT_N), .REFCLK(refclk),
		.COUNT_3(pll_count[3]), .COUNT_2(pll_count[2]), .COUNT_1(pll_count[1]), .COUNT_0(pll_count[0]),
		.COUNT_OUT(COUNT_OUT),
		.LOCKABLE(LOCKABLE),
		.CLK(CLK));

    wire [9:0]DI, DO;
    wire SYNCING;
    wire SYNCED;
    wire RESTART;
    wire REV;
	wire XMT_READY, XMT_RD;
	wire mgmt_ok;
	wire mgmt_k, mgmt_ready;
	wire [7:0]mgmt_in;
	wire local_rcv_ready;
	assign rcv_ready = local_rcv_ready&mgmt_ready;
	

    deskew deskew(.RESET_N(RESET_PLL_OUT_N), .RESTART(FRESTART), .DIN(din), .DOUT(dout), .REV(REV), .CLK(CLK),

                    .RESET_OUT_N(reset_out_n),
                    .CLK10(clk10),
                    .DI(DI),
                    .SYNCING(SYNCING),
                    .SYNCED(SYNCED),

                    .DO(DO),
                    .XMT_READY(XMT_READY),
                    .XMT_RD(XMT_RD));

    wire      scramble = 1;
    up_des8b10  des(.CLK10(CLK10), .RESET_OUT_N(reset_out_n), .DI(DI), .SYNCING(SYNCING),
                    .scramble(scramble),
                    .kout(rcv_k),
                    .out(rcv_out),
                    .ready(local_rcv_ready),
                    .align(rcv_align));

    up_ser8b10  ser(.CLK10(CLK10), .RESET_OUT_N(reset_out_n),
                    .DO(DO),
                    .XMT_READY(XMT_READY),
                    .XMT_RD(XMT_RD),

                    .scramble(scramble),
                    .k(mgmt_ready?xmt_k:mgmt_k),
                    .in(mgmt_ready?xmt_in:mgmt_in),
                    .ready(mgmt_ready?xmt_ready:mgmt_ready));


	//
	//	link management
	//
	wire [6:0]speed;
	reg [3:0]pll_clk;
	always @(*)
	case (speed) // synthesis full_case parallel_case
	7'b???_???1:	pll_clk = 1;	// 50MHzx
	7'b???_??1?:	pll_clk = 3;	// 100MHz
	7'b???_?1??:	pll_clk = 5;	// 150MHz
	7'b???_1???:	pll_clk = 7;	// 200MHz
	7'b??1_????:	pll_clk = 11;	// 200MHz
	endcase
	
	wire [7:0]output_prog;	// output drivers programming (unused here)
	mgmt #(.UPSTREAM(1))mgmt(
				.reset_n(reset_n),
				.clk10(CLK10), .RESET_OUT_N(reset_out_n),
				.speed(speed),
				.rcv_out(rcv_out),
				.rcv_k(rcv_k),
				.rcv_ready(local_rcv_ready),
				.xmt_in(mgmt_in),
				.xmt_k(mgmt_k),
				.xmt_ready(mgmt_ready),
				.rev(REV),
				.restart(RESTART),
				.mgmt_ok(mgmt_ok));

endmodule
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
