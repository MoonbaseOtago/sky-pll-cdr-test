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
			output	   pll_clk,
			input [6:0]default_speed,

			input din, output dout,

			output	    clk10,
			output      reset_out_n,

			output [7:0]rcv_out,
			output      rcv_k,
			output		rcv_ready,
			output	    rcv_align,

			input  [7:0]xmt_in,
			input       xmt_k,
			input       xmt_ready,

			output	    mgmt_ok
			);

    wire RESET_PLL_OUT_N;
    wire CLK;
	/* verilator lint_off UNUSEDSIGNAL */
	wire COUNT_OUT, LOCKABLE;
	/* verilator lint_on UNUSEDSIGNAL */
	reg [3:0]pll_clk_speed;
	assign pll_clk = CLK;

	pll2 pll2(.RESET_N(reset_n),
`ifdef GL_TEST
            .VPWR(VPWR), .VGND(VGND),
`endif

        .RESET_OUT_N(RESET_PLL_OUT_N), .REFCLK(refclk),
		.COUNT_3(pll_clk_speed[3]), .COUNT_2(pll_clk_speed[2]), .COUNT_1(pll_clk_speed[1]), .COUNT_0(pll_clk_speed[0]),
		.COUNT_OUT(COUNT_OUT),
		.LOCKABLE(LOCKABLE),
		.CLK(CLK));

    wire [9:0]DI, DO;
    wire SYNCING;
	/* verilator lint_off UNUSEDSIGNAL */
    wire SYNCED;
	/* verilator lint_on UNUSEDSIGNAL */
    wire RESTART;
    wire REV;
	wire XMT_READY, XMT_RD;
	wire mgmt_k, mgmt_ready;
	wire [7:0]mgmt_in;
	wire local_rcv_ready;
	assign rcv_ready = local_rcv_ready&mgmt_ok;
	

    deskew deskew(.RESET_N(RESET_PLL_OUT_N), .RESTART(RESTART), .DIN(din), .DOUT(dout), .REV(REV), .CLK(CLK),

                    .RESET_OUT_N(reset_out_n),
                    .CLK10(clk10),
                    .DI(DI),
                    .SYNCING(SYNCING),
                    .SYNCED(SYNCED),

                    .DO(DO),
                    .XMT_READY(XMT_READY),
                    .XMT_RD(XMT_RD));

    wire      scramble = 1;
    up_des8b10  des(.CLK10(clk10), .RESET_OUT_N(reset_out_n), .DI(DI), .SYNCING(SYNCING),
                    .scramble(scramble),
                    .kout(rcv_k),
                    .out(rcv_out),
                    .ready(local_rcv_ready),
                    .align(rcv_align));

    up_ser8b10  ser(.CLK10(clk10), .RESET_OUT_N(reset_out_n),
                    .DO(DO),
                    .XMT_READY(XMT_READY),
                    .XMT_RD(XMT_RD),

                    .scramble(scramble),
                    .k(mgmt_ok?xmt_k:mgmt_k),
                    .in(mgmt_ok?xmt_in:mgmt_in),
                    .ready(mgmt_ok?xmt_ready:mgmt_ready));


	//
	//	link management
	//
	/* verilator lint_off CASEOVERLAP */
	wire [6:0]speed;
	always @(*)
	if (pll_test) begin
		pll_clk_speed = pll_count;
	end else
	casez (speed) // synthesis full_case parallel_case
	7'b???_???1:	pll_clk_speed = 1;	// 50MHzx
	7'b???_??1?:	pll_clk_speed = 3;	// 100MHz
	7'b???_?1??:	pll_clk_speed = 5;	// 150MHz
	7'b???_1???:	pll_clk_speed = 7;	// 200MHz
	7'b??1_????:	pll_clk_speed = 11;	// 200MHz
	default:		pll_clk_speed = 4'bx;
	endcase
	/* verilator lint_on CASEOVERLAP */
	
	/* verilator lint_off UNUSEDSIGNAL */
	wire [7:0]output_prog;	// output drivers programming (unused here)
	/* verilator lint_on UNUSEDSIGNAL */
	mgmt #(.UPSTREAM(1))mgmt(
				.reset_n(reset_n),
				.clk10(clk10), .reset_out_n(reset_out_n),
				.speed(speed),
				.xmt_prog(output_prog),
				.default_speed(default_speed),
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
