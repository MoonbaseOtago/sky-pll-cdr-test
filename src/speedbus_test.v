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


	wire	  up_mgmt_ok, down_mgmt_ok;
	wire	  clk_up, clk_down;

	wire [7:0]down_rcv_out;
	wire	  down_rcv_k;
    wire      down_rcv_ready;
	/* verilator lint_off UNUSEDSIGNAL */
    wire	  down_rcv_align;
    wire	  up_rcv_align;
	/* verilator lint_on UNUSEDSIGNAL */
	wire	  down_reset_n;

	wire [7:0]up_rcv_out;
	wire	  up_rcv_k;
    wire      up_rcv_ready;
	wire	  up_reset_n;

	reg		  r_force_rev;


	wire tmp = (|uio_in[4:1]) | ena;	// to keep lint happy



	//
	//	test modes:
	//		0 - just PLL
	//		1 - speed_bus 100MHz
	//		2 - speed_bus 100-200MHz
	//		3 - speed_bus 100-300MHz
	//
	reg	[1:0]r_test;
	reg [3:0]r_pll_count;
	always @(posedge clk)
	if (!rst_n) begin
		r_test <= ui_in[7:6];
		r_force_rev <= ui_in[4];
		r_pll_count <= ui_in[3:0];
	end

	reg [6:0]default_speed;
	always @(*)
	case (r_test)
	0, 1:	default_speed = 7'b000_0010;
	2:		default_speed = 7'b000_1010;
	3:		default_speed = 7'b001_1010;
	endcase
		

	wire [1:0]mode = uio_in[7:6];

	wire	 pll_clk;
	reg [3:0]r_pll_counter;

	reg[7:0]ruo_out;
	assign uo_out = ruo_out;
	reg[7:0]ruio_out;
	assign uio_out = ruio_out;
	reg[7:0]ruio_oe;
	assign uio_oe = ruio_oe;
	always @(*)
	case (mode)	// synthesis full_case parallel_case
	0:	begin		// mostly PLL test
			ruo_out = {pll_clk, clk_up, clk_down, 1'b0, r_pll_counter};
			ruio_oe = 8'b0001_1111;
			ruio_out = {tmp, 3'b0,  down_mgmt_ok, up_mgmt_ok, down_reset_n, up_reset_n};
		end
	1:	begin
			ruo_out = up_rcv_out;
			ruio_oe = 8'b0001_1110;
			ruio_out = {tmp, 2'b0,  clk_up, clk_down, up_rcv_ready, up_rcv_k, 1'b0};
		end
	2:	begin
			ruo_out = down_rcv_out;
			ruio_oe = 8'b0001_1110;
			ruio_out = {tmp, 2'b0,  clk_up, clk_down, down_rcv_ready, down_rcv_k, 1'b0};
		end
	default:
		begin
			ruo_out = 8'bx;
			ruio_oe = 8'bx;
			ruio_out = 8'bx;
		end
	endcase

	reg r_up_last, r_up_xmt_ready;
	reg r_down_last, r_down_xmt_ready;
	always @(posedge clk_up) 
	if (!rst_n) begin
		r_up_last <= 0;
		r_up_xmt_ready <= 0;
	end else 
	if (mode == 2 && r_up_last != uio_in[5]) begin
		r_up_xmt_ready <= 1;
		r_up_last <= uio_in[5];
	end else begin
		r_up_xmt_ready <= 0;
	end
	
	always @(posedge clk_down) 
	if (!rst_n) begin
		r_down_last <= 0;
		r_down_xmt_ready <= 0;
	end else 
	if (mode == 1 && r_down_last != uio_in[5]) begin
		r_down_xmt_ready <= 1;
		r_down_last <= uio_in[5];
	end else begin
		r_down_xmt_ready <= 0;
	end
	
	
	always @(posedge pll_clk) 
	if (!rst_n) begin
		r_pll_counter <= 0;
	end else begin
		r_pll_counter <= r_pll_counter+1;
	end


	wire	  d_up_to_down;		// the 'LVS' up/down connection
	wire	  d_down_to_up;

	upstream up(.reset_n(rst_n), .refclk(clk), 
`ifdef GL_TEST
            .VPWR(.VPWR), .VGND(VGND),
`endif
			.default_speed(default_speed),
			.pll_clk(pll_clk),
            .pll_count(r_pll_count),
			.pll_test(r_test==0),

            .din(d_down_to_up), 
			.dout(d_up_to_down),

            .clk10(clk_up),
            .reset_out_n(up_reset_n),

			.mgmt_ok(up_mgmt_ok),

            .rcv_out(up_rcv_out),
            .rcv_k(up_rcv_k),
            .rcv_ready(up_rcv_ready),
            .rcv_align(up_rcv_align),

            .xmt_in(ui_in),
            .xmt_k(uio_in[0]),
            .xmt_ready(r_up_xmt_ready)
            );

	downstream down(.reset_n(rst_n), 
`ifdef GL_TEST
            .VPWR(.VPWR), .VGND(VGND),
`endif
            .din(d_up_to_down^r_force_rev), 
			.dout(d_down_to_up),

            .clk10(clk_down),
            .reset_out_n(down_reset_n),

			.mgmt_ok(down_mgmt_ok),

            .rcv_out(down_rcv_out),
            .rcv_k(down_rcv_k),
            .rcv_ready(down_rcv_ready),
            .rcv_align(down_rcv_align),

            .xmt_in(ui_in),
            .xmt_k(uio_in[0]),
            .xmt_ready(r_down_xmt_ready)
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

