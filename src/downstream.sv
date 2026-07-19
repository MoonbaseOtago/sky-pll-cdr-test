/*
 * Copyright (c) 2026 Paul Campbell
 * SPDX-License-Identifier: Apache-2.0
 */


`default_nettype none

`timescale 1ns/1fs

module downstream(input reset_n,
`ifdef GL_TEST
            inout VPWR, inout VGND,
`endif

            input din, output dout,

            output      clk10,
            output      reset_out_n,

            output      mgmt_ok,

            output [7:0]rcv_out,
            output      rcv_k,
            output      rcv_ready,
            output      rcv_align,

            input  [7:0]xmt_in,
            input       xmt_k,
            input       xmt_ready


		);



	wire RESTART;
	wire REV;


    wire CLKI;
    wire CLKQ;
    wire CLKI_N;
    wire CLKQ_N;

	wire UP_N, DOWN_N;  // CP inputs
	wire RESET;
	/* verilator lint_off UNUSEDSIGNAL */
	wire SYNCED;
	/* verilator lint_on UNUSEDSIGNAL */
	wire SYNCING;
	wire [9:0]DI, DO;
	wire XMT_READY, XMT_RD;

	cdrs cdrs(
`ifdef GL_TEST
            .VPWR(VPWR), .VGND(VGND),
`endif
        .RESET_N(reset_n),
		.RESTART(RESTART),
        .RESET_OUT_N(reset_out_n),
        .SYNCED(SYNCED),
        .SYNCING(SYNCING),
        .DIN(din),
        .REV(REV),
        .CLK10(clk10),
        .DI(DI),
        .DO(DO),
        .DOUT(dout),
        .XMT_READY(XMT_READY),
        .XMT_RD(XMT_RD),

    // CP/VCO interface
        .CLKI(CLKI), .CLKI_N(CLKI_N), .CLKQ(CLKQ), .CLKQ_N(CLKQ_N),
        .RESET(RESET), .UP_N(UP_N), .DOWN_N(DOWN_N));


    cdr_cp_vco cp_vco(
`ifdef GL_TEST
            .VPWR(VPWR), .VGND(VGND),
`endif
		.CLKI(CLKI), .CLKI_N(CLKI_N), .CLKQ(CLKQ), .CLKQ_N(CLKQ_N),
        .RESET(RESET), .UP_N(UP_N), .DOWN_N(DOWN_N));



    wire      scramble = 1;
	wire	  mgmt_ready;
	wire	  local_rcv_ready;
	assign	  rcv_ready = mgmt_ready&local_rcv_ready;
    down_des8b10    des(.CLK10(clk10), .RESET_OUT_N(reset_out_n), .DI(DI), .SYNCING(SYNCING),
                    .scramble(scramble),
                    .kout(rcv_k),
                    .out(rcv_out),
                    .ready(local_rcv_ready),
                    .align(rcv_align));

    wire        mgmt_k;
    wire   [7:0]mgmt_in;
    down_ser8b10    ser(.CLK10(clk10), .RESET_OUT_N(reset_out_n),
                    .DO(DO),
                    .XMT_READY(XMT_READY),
                    .XMT_RD(XMT_RD),

                    .scramble(scramble),
                    .k(mgmt_ok?xmt_k:mgmt_k),
                    .in(mgmt_ok?xmt_in:mgmt_in),
                    .ready(mgmt_ok?xmt_ready:mgmt_ready));

	/* verilator lint_off UNUSEDSIGNAL */
	wire [7:0]output_prog;	// output drivers programming (unused here)
	wire [6:0]speed; // not used for downstream
	wire [6:0]default_speed=7'bx; // not used for downstream
	/* verilator lint_on UNUSEDSIGNAL */
	/* verilator lint_off PINMISSING */
	mgmt #(.UPSTREAM(0))mgmt(
				.reset_n(reset_n),
				.clk10(clk10), .reset_out_n(reset_out_n),
				.xmt_prog(output_prog),
				.speed(speed),
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
	/* verilator lint_on PINMISSING */


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

