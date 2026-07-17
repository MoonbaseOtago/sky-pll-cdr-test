/*
 * Copyright (c) 2026 Paul Campbell
 * SPDX-License-Identifier: Apache-2.0
 */


`timescale 1ns/1fs


`default_nettype none

module tt_um_speed_bus (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  	// All output pins must be assigned. If not used, assign to 0.
	assign uo_out  = ui_in + uio_in;  // Example: ou_out is the sum of ui_in and uio_in
	assign uio_out = 0;
	assign uio_oe  = 0;

	// List all unused inputs to prevent warnings
	wire _unused = &{ena, clk, rst_n, 1'b0};

	wire [2:0]mode = uio_in[7:5];


	wire [3:0]pll_count=7;
	wire	  pll_test=1;

	wire	  d_up_to_down;		// the 'LVS' up/down connection
	wire	  d_down_to_up;

	wire [7:0]up_rcv_out;
	wire	  up_rcv_k;
    wire      up_rcv_ready;
    wire	  up_rcv_align;

	wire [7:0]up_xmt_in=0;
	wire	  up_xmt_k=0;
    wire      up_xmt_ready=0;

	wire	  up_reset_n;
	wire	  clk_up;

	upstream up(.reset_n(rst_n), .refclk(clk),
`ifdef GL_TEST
            .VPWR(.VPWR), .VGND(VGND),
`endif
            .pll_count(pll_count),
			.pll_test(pll_test),

            .din(d_down_to_up), 
			.dout(d_up_to_down),

            .clk10(clk_up),
            .reset_out_n(up_reset_n),

            .rcv_out(up_rcv_out),
            .rcv_k(up_rcv_k),
            .rcv_ready(up_rcv_ready),
            .rcv_align(up_rcv_align),

            .xmt_in(up_xmt_in),
            .xmt_k(up_xmt_k),
            .xmt_ready(up_xmt_ready)
            );

	wire [7:0]down_rcv_out;
	wire	  down_rcv_k;
    wire      down_rcv_ready;
    wire	  down_rcv_align;

	wire [7:0]down_xmt_in=0;
	wire	  down_xmt_k=0;
    wire      down_xmt_ready=0;

	wire	  down_reset_n;
	wire	  clk_down;

	downstream down(.reset_n(down_reset_n), 
`ifdef GL_TEST
            .VPWR(.VPWR), .VGND(VGND),
`endif
            .din(d_up_to_down), 
			.dout(d_down_to_up),

            .clk10(clk_down),
            .reset_out_n(down_reset_n),

            .rcv_out(down_rcv_out),
            .rcv_k(down_rcv_k),
            .rcv_ready(down_rcv_ready),
            .rcv_align(down_rcv_align),

            .xmt_in(down_xmt_in),
            .xmt_k(down_xmt_k),
            .xmt_ready(down_xmt_ready)
            );


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

