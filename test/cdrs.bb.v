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
`ifdef SYS_TEST
	// CP/VCO
	wire din = DIN^REV;
	assign RESET = ~RESET_N|RESTART;	// VCO analog reset

	//
	//	This is the high speed part of the downstream side of a link,
	//		we do CDR to get the high speed clock (all the logic driven by the
	//		high speed clock lives here and gets built using the HS library to
	//		live in a macro with the VCO and CP
	//
	//	There's a lot of logic (flops/etc) in common between the CDR and the DES
	//	
	//	The derived clock and the divideby10 clock framed by the downstream link
	//		are also used for the upstream link
	//

	// first fixed symbol - this or its inverse
	wire[9:0]hdr = 10'b0011111010;


	// state - basic guide - we are fed a startup stream of 8 10-bit symbols including the hdr
	//		         symbol or it's inverse, no symbol has 6 or more bits in a row
	//
	//	1) search up in freq until we see 6 1s or 0s - r_searching_up
	//	2) search down slowly until we see a hdr symbol     - r_searching_down
	//	3) turn on freq detector to zero in on freq  - r_searching_mid
	//	4) turn on station keeping using bang-bang phase detector
	//
	//	we detect "too_high" and "too low" and break back into 1/2 when we see them, this avoids aliasing issues
	//
	reg		 r_searching_up;
	reg		 r_searching_down;
	reg		 r_searching_mid;
	reg [2:0]r_cnt;
	wire locked = !(r_searching_up|r_searching_mid|r_searching_down);

	// input symbols

	reg [9:0]r_in_p;	// symbol on pos edges
	reg [5:0]r_in_n;	// symbol on neg edges
	reg      r_in_x;	// posedge copy if negedge symbol for PD

	always @(posedge CLKI) begin
		r_in_x <= r_in_n[0];
		r_in_p <= {r_in_p[8:0], din};
	end
	always @(posedge CLKI_N) 
		r_in_n <= {r_in_n[4:0], din};

	// Phase detector - bang-bang stationkeeping

	wire X1 = r_in_p[0]^r_in_x;
	wire X2 = r_in_p[1]^r_in_x;

	reg r_slow, r_last;
	wire sup  =X2&locked;
	wire sdown=X1&locked;
	wire mod = CLKI&((r_cnt[2:0]==0) | !r_slow);
	
	wire SMALL_UP  =sup&mod;
	wire SMALL_DOWN=sdown&mod;

	always @(posedge CLKI) begin
		if (!locked) begin
			r_slow <= 1;
		end else
		if (sup) begin
			r_slow <= r_last;
		end else
		if (sdown) begin
			r_slow <= ~r_last;
		end
		if (!locked) begin
			r_last <= 0;
		end else
		if (sup) begin
			r_last <= 1;
		end else
		if (sdown) begin
			r_last <= 0;
		end
	end

	// 
	// ROTATOR frequency detector - deffs are double edged flops
	//

	wire io0, io1, qo0, qo1;
	deff i0(.c(din), .d(CLKI), .q(io0));	
	deff i1(.c(din), .d(io0), .q(io1));
	deff q0(.c(din), .d(CLKQ), .q(qo0));
	deff q1(.c(din), .d(qo0), .q(qo1));
	wire MID_UP     = qo0&!io0&!io1&!qo1&~(r_searching_down|r_searching_up);
	wire MID_DOWN   = io0&!qo0&!io1&!qo1&~(r_searching_down|r_searching_up);

	//
	//  high level state machine
	//

	reg 	 r_qdp;
	reg [1:0]r_qdn;
	always @(posedge CLKQ)
		r_qdp <= din;
	always @(posedge CLKQ_N)
		r_qdn <= {r_qdn[0],din};

	wire too_low =	( r_qdn[1] &!r_in_p[0]& r_qdp ) ||		// too slow?
					(!r_qdn[1] & r_in_p[0]&!r_qdp ) ||
					(!r_in_p[0]& r_qdp    &!r_in_n[0]) ||
					( r_in_p[0]&!r_qdp    & r_in_n[0]) ||
					(!r_in_p[0]& r_qdp    &!r_in_n[0]) ||
					( r_qdp    &!r_in_n[0]& r_qdn[0]) ||
					(!r_qdp    & r_in_n[0]&!r_qdn[0]) ||
					( r_in_n[0]&!r_qdn[0] & din) ||
					(!r_in_n[0]& r_qdn[0] &!din);
	
	wire too_high =	( &r_in_p[5:0] && &r_in_n[5:1]) ||
					(~|r_in_p[5:0]&& ~|r_in_n[5:1]); // 6 1s/0s in a row -  too fast

	wire match = r_in_p == hdr || r_in_p == ~hdr;
	
	always @(posedge CLKI or negedge RESET_N) begin
		if (!RESET_N) begin
			r_searching_down <= 0;
			r_searching_up <= 1;
			r_searching_mid <= 0;
			r_cnt <=  0;
		end else 
		if (RESTART) begin
			r_searching_down <= 0;
			r_searching_up <= 1;
			r_searching_mid <= 0;
			r_cnt <=  ~0;
		end else begin
			r_cnt <=  r_cnt-1;
/* verilator lint_off CASEOVERLAP */
			casez ({too_low, too_high, ~r_searching_up&match, locked&(MID_UP|MID_DOWN), r_searching_mid}) // synthesis full_case parallel_case */
			5'b1?_???:begin	// too_low
						r_searching_down <= 0;
						r_searching_mid <= 0;
						r_searching_up <= 1;
					  end
			5'b?1_???:begin	// too_high
						r_searching_down <= 1;
						r_searching_mid <= 0;
						r_searching_up <= 0;
					  end
			5'b00_1??:begin	// searching down matched a symbol
						r_searching_down <= 0;
						r_searching_mid <= r_searching_up|r_searching_down|r_searching_mid;
						r_searching_up <= 0;
						r_cnt <= ~0;
					  end
			5'b00_01?:begin	// jumped back into freq search
						r_searching_mid <= 1;
						r_cnt <= ~0;
					  end
			5'b00_001:begin	// freq search - wait for 8 clocks with no movement
						if (MID_UP|MID_DOWN) begin
							r_cnt <= ~0;
						end else
						if (r_cnt == 0) begin
							r_searching_mid <= 0;
						end
					   end
			5'b00_000:;	// station keeping
			endcase
/* verilator lint_on CASEOVERLAP */
		end
	end

	wire LARGE_UP = r_searching_up;	// search up fast
	wire LARGE_DOWN = CLKI&r_searching_down&(r_cnt == 0);	// search down slowly

	assign UP_N = ~(LARGE_UP|MID_UP|SMALL_UP);
	assign DOWN_N = ~(LARGE_DOWN|MID_DOWN|SMALL_DOWN);

	// If all you want is a CDR output clki and r_in_p[1] and ignore everything below here

	//
	// from here on down are the high speed (CLKI) domain parts of the 8b10 dec/enc
	//
	//	decoder:
	//
	//  we're assembling a 10-bit output sequence and use a 1/10 local clock
    //      for most of the logic - note this means that for some paths we have 5/10 (less clk tree and 
    //      skew) of a 1/10 clock setup and for others going the other way 5/10 
    //
    //  Care must be taken - we save lots of gates having to run at full speed at the expense of
    //      more care being taken around timing 
    //  
    //  the rising edge of slow clk10 is skewed 2 clks from the start of every outgoing packet
    //
    //      ....|0123456789|0123456789|0123456789|....
    //
    //               ______     ______     ______ 
    //               |    |     |    |     |    | 
    //               |    |     |    |     |    | 
    //            ----    -------    -------    --------
    //
    //  when we see a synchronising symbol in the stream we stretch clock10 carefully so that
    //      there are no runt clocks (as a side effect we miss the next symbol in the stream)
    //
	//

	reg [9:0]r_d;
	reg		 r_start_sync, r_syncing, r_synced, r_reset_out_n;
	assign	SYNCED = r_synced;
	assign	SYNCING = r_syncing;
(* gclk *) (* keep *) 	reg		 r_clk10;
	assign CLK10 = r_clk10;
	reg [4:0]r_rcv_count;
	assign DI = r_d;
	assign RESET_OUT_N = r_reset_out_n;

	always @(posedge CLKI) begin
		r_start_sync <= (!RESET_N|RESTART)&!r_syncing&!r_synced;
		if (!RESET_N) begin
			r_rcv_count <= 9;
			r_clk10 <= 0; 
			r_reset_out_n <= 0; 
			r_syncing <= 1;
			r_synced <= 0; 
		end else 
		if (match && locked && (!r_synced || r_rcv_count != 0)) begin
			r_rcv_count <= 19;      // wait a clock so we can stretch clk10 cleanly, we'll miss the next symbol
			r_syncing <= 0;
			r_synced <= 1; 
		end else begin
			if (!locked || r_syncing || r_start_sync) begin
				r_synced <= 0;
				r_syncing <= 1;
			end 
			r_rcv_count <= r_rcv_count-1;
			case (r_rcv_count) 
			0:   	begin 
					r_d <= {r_in_p[0], r_in_p[1], r_in_p[2], r_in_p[3], r_in_p[4], r_in_p[5], r_in_p[6], r_in_p[7], r_in_p[8], r_in_p[9]};
					r_clk10 <= 0;
					r_rcv_count <= 9;
				end
			1:	r_reset_out_n <= 1;
			5:	r_clk10 <= 1;
			14:	r_clk10 <= 0;
			default:;
			endcase
		end
	end

	//
	// upstream link - uses derived clock and framed clock
	//

	reg [9:0]r_dout;
	assign DOUT = r_dout[9];
	always @(posedge CLKI)
	if (!RESET_N) begin
		r_dout <= 10'b110000_1011; // only here to pass gatesim
	end else begin
		if (r_rcv_count == 0) begin
			if (XMT_READY) begin
				r_dout <= DO;
			end else begin
				if (XMT_RD) begin // insert SKP
					r_dout <= 10'b110000_1011;
				end else begin
					r_dout <= 10'b001111_0100;
				end
			end
		end else begin
			r_dout <= { r_dout[8:0], 1'bx};
		end
	end
endmodule

module deff(input c, input d, output q);

	reg p, n;

	always @(posedge c)
		p <= d;
	always @(negedge c)
		n <= d;
	assign q = (c?p:n);
`endif
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

