/*
 * Copyright (c) 2026 Paul Campbell
 * SPDX-License-Identifier: Apache-2.0
 */

/* verilator lint_off TIMESCALEMOD */

`timescale 1ns/1fs
`default_nettype none
`ifdef SYS_TEST

module sky130_fd_sc_hd__buf_1(input A, output X);

	reg x;
	assign X=x;
	always @(*)
		x <= #0.04 A;

endmodule
module sky130_fd_sc_hd__a22oi_1(input A1, input A2, input B1, input B2, output Y);

	reg y;
	assign Y=y;
	always @(*)
		y <= #0.05 ~((A1&A2)|(B1&B2));

endmodule
`timescale 1ns/1ps
module del1(
`ifdef GL_TEST
            inout VPWR, inout VGND,
`endif
			input DIN, output DOUT, output OUT, input d);

	wire dd0, dd1, dd2, dd3, dd4, dd5, dd6 ;
	(* dont_touch = "yes" *) (* keep *) sky130_fd_sc_hd__buf_1 b00(
`ifdef GL_TEST
            .VPWR(VPWR), .VGND(VGND), .VPB(VPWR), .VNB(VGND),
`endif
				.A(DIN), .X(dd0));
	(* dont_touch = "yes" *) (* keep *) sky130_fd_sc_hd__buf_1 b01(
`ifdef GL_TEST
            .VPWR(VPWR), .VGND(VGND), .VPB(VPWR), .VNB(VGND),
`endif
				.A(dd0), .X(dd1));
	(* dont_touch = "yes" *) (* keep *) sky130_fd_sc_hd__buf_1 b10(
`ifdef GL_TEST
            .VPWR(VPWR), .VGND(VGND), .VPB(VPWR), .VNB(VGND),
`endif
				.A(dd1), .X(dd2));
	(* dont_touch = "yes" *) (* keep *) sky130_fd_sc_hd__buf_1 b11(
`ifdef GL_TEST
            .VPWR(VPWR), .VGND(VGND), .VPB(VPWR), .VNB(VGND),
`endif
				.A(dd2), .X(dd3));
	(* dont_touch = "yes" *) (* keep *) sky130_fd_sc_hd__buf_1 b20(
`ifdef GL_TEST
            .VPWR(VPWR), .VGND(VGND), .VPB(VPWR), .VNB(VGND),
`endif
				.A(dd3), .X(dd4));
	(* dont_touch = "yes" *) (* keep *) sky130_fd_sc_hd__buf_1 b21(
`ifdef GL_TEST
            .VPWR(VPWR), .VGND(VGND), .VPB(VPWR), .VNB(VGND),
`endif
				.A(dd4), .X(dd5));
	(* dont_touch = "yes" *) (* keep *) sky130_fd_sc_hd__buf_1 b30(
`ifdef GL_TEST
            .VPWR(VPWR), .VGND(VGND), .VPB(VPWR), .VNB(VGND),
`endif
				.A(dd5), .X(dd6));
	(* dont_touch = "yes" *) (* keep *) sky130_fd_sc_hd__buf_1 b31(
`ifdef GL_TEST
            .VPWR(VPWR), .VGND(VGND), .VPB(VPWR), .VNB(VGND),
`endif
				.A(dd6), .X(OUT));
	(* dont_touch = "yes" *) (* keep *) sky130_fd_sc_hd__a22oi_1 sw(
`ifdef GL_TEST
            .VPWR(VPWR), .VGND(VGND), .VPB(VPWR), .VNB(VGND),
`endif
				.A1(d), .A2(OUT), .B1(dd3), .B2(~d), .Y(DOUT));
endmodule
module del2(
`ifdef GL_TEST
            inout VPWR, inout VGND,
`endif
		input DIN, output DOUT, input[1:0]d, output OUT);

	wire dd0, dd1, o;
	del1 d0(
`ifdef GL_TEST
            .VPWR(VPWR), .VGND(VGND),
`endif
		.DIN(DIN), .DOUT(dd0), .d(d[0]), .OUT(o));
	del1 d1(
`ifdef GL_TEST
            .VPWR(VPWR), .VGND(VGND),
`endif
		.DIN(o), .DOUT(dd1), .d(d[0]),.OUT(OUT));
	(* dont_touch = "yes" *) (* keep *) sky130_fd_sc_hd__a22oi_1 sw(
`ifdef GL_TEST
            .VPWR(VPWR), .VGND(VGND), .VPB(VPWR), .VNB(VGND),
`endif
				.A1(d[1]), .A2(dd1), .B1(dd0), .B2(~d[1]), .Y(DOUT));
endmodule
module del3(
`ifdef GL_TEST
            inout VPWR, inout VGND,
`endif
		input DIN, output DOUT, input[2:0]d, output OUT);

	wire dd0, dd1, o;
	del2 d0(
`ifdef GL_TEST
            .VPWR(VPWR), .VGND(VGND),
`endif
		.DIN(DIN), .DOUT(dd0), .d(d[1:0]), .OUT(o));
	del2 d1(
`ifdef GL_TEST
            .VPWR(VPWR), .VGND(VGND),
`endif
		.DIN(o), .DOUT(dd1), .d(d[1:0]),.OUT(OUT));
	(* dont_touch = "yes" *) (* keep *) sky130_fd_sc_hd__a22oi_1 sw(
`ifdef GL_TEST
            .VPWR(VPWR), .VGND(VGND), .VPB(VPWR), .VNB(VGND),
`endif
				.A1(d[2]), .A2(dd1), .B1(dd0), .B2(~d[2]), .Y(DOUT));
endmodule
module del4(
`ifdef GL_TEST
            inout VPWR, inout VGND,
`endif
		input DIN, output DOUT, input[3:0]d, output OUT);

	wire dd0, dd1, o;
	del3 d0(
`ifdef GL_TEST
            .VPWR(VPWR), .VGND(VGND),
`endif
		.DIN(DIN), .DOUT(dd0), .d(d[2:0]), .OUT(o));
	del3 d1(
`ifdef GL_TEST
            .VPWR(VPWR), .VGND(VGND),
`endif
		.DIN(o), .DOUT(dd1), .d(d[2:0]),.OUT(OUT));
	(* dont_touch = "yes" *) (* keep *) sky130_fd_sc_hd__a22oi_1 sw(
`ifdef GL_TEST
            .VPWR(VPWR), .VGND(VGND), .VPB(VPWR), .VNB(VGND),
`endif
				.A1(d[3]), .A2(dd1), .B1(dd0), .B2(~d[3]), .Y(DOUT));
endmodule
module variable_delay(
`ifdef GL_TEST
            inout VPWR, inout VGND,
`endif
		input DIN, input REV, output DOUT, input[4:0]d);

	wire din = DIN^REV;
	wire dd0, dd1, dd2, o;
	wire o2;
	del4 d0(
`ifdef GL_TEST
            .VPWR(VPWR), .VGND(VGND),
`endif
		.DIN(din), .DOUT(dd0), .d(d[3:0]), .OUT(o));
	del4 d1(
`ifdef GL_TEST
            .VPWR(VPWR), .VGND(VGND),
`endif
		.DIN(o), .DOUT(dd1), .d(d[3:0]), .OUT(o2));
	(* dont_touch = "yes" *) (* keep *) sky130_fd_sc_hd__a22oi_1 sw(
`ifdef GL_TEST
            .VPWR(VPWR), .VGND(VGND), .VPB(VPWR), .VNB(VGND),
`endif
				.A1(d[4]), .A2(dd1), .B1(dd0), .B2(~d[4]), .Y(dd2));
	assign DOUT = ~dd2;
endmodule
`endif


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
`ifdef SYS_TEST

	// first fixed symbol - this or its inverse
	wire[9:0]hdr = 10'b0011111010;

	//
	//	This is the high speed part of the upstream side of a link,
	//	we have an extern PLL that generates the link speed CLK and a
	//	RESET_N synchronous signal
	//
	//	The clock is sent downstream and recovered by a CDR, the upstream 
	//	signal is essentially clocked by the same clock but with added jitter
	//	and delay - we assume the jitter is small enough (less that 1/2 a symbol time)
	//	the following section deals with the delay:
	//
	//	First we deal with bit time delays with a variable delay line and a digital bang-bang 
	//	phase detector - it's goal is to align the incoming signal changes (after the
	//	delay line) with the falling edge of the sampling clock. Because the delay
	//	index is discrete (a 5 bit counter) it's never perfect. we expect it to
	//	bounce up and down - this effectively adds more jitter.
	//

	//
	//	digital delay line - a chain of minimum sized buffers
	//  sampled by a mux - built recursively above
	//
	wire DIN_DELAY;			// output signal
	reg [4:0]r_dd;			// mux selector

	variable_delay delay(
`ifdef GL_TEST
            .VPWR(VPWR), .VGND(VGND),
`endif
			.DIN(DIN), .REV(REV), .DOUT(DIN_DELAY), .d(r_dd));



	reg [9:0]r_in_p;	// symbol on pos edges
	reg      r_in_n;	// symbol on neg edges
	reg      r_in_x;	// posedge copy if negedge symbol for PD

	always @(posedge CLK) begin
		r_in_x <= r_in_n;
		r_in_p <= {r_in_p[8:0], DIN_DELAY};
	end
	always @(negedge CLK) 
		r_in_n <= DIN_DELAY;

	//
	// Phase detector - bang-bang stationkeeping
	//		stolen from the CDR
	//

	reg		r_slow, r_last;
	reg [2:0]r_cnt;

	wire X1 = r_in_p[0]^r_in_x;
	wire X2 = r_in_p[1]^r_in_x;

	wire mod = ((r_cnt[2:0]==0) | !r_slow);

	wire DOWN   = X2&mod;
	wire UP     = X1&mod;


	always @(posedge CLK) begin
		
        if (X1) begin
            r_slow <= r_last;
        end else
        if (X2) begin
            r_slow <= ~r_last;
        end

        if (X1) begin
            r_last <= 1;
        end else
        if (X2) begin
            r_last <= 0;
        end

		if (!RESET_N) begin
			r_cnt <= 0;
		end else begin
			r_cnt <= r_cnt-1;
		end

		if (!RESET_N|RESTART) begin
			r_dd <= 5'h10;
		end else
		if (DOWN && r_dd != 5'h1f) begin
			r_dd <= r_dd+1;
		end else
		if (UP && r_dd != 0) begin
			r_dd <= r_dd-1;
		end 
    end

	//
	// from here on down are the high speed (CLK) domain parts of the 8b10 enc/dec
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
	//
	//	as this is the upstream side we can create and arbitrary clk10 phase when the PLL
	//	starts - the receive side has to synchronise to the (arbitrary) transmit clk10
	//
	//

(* gclk *) (* dont_touch = "yes" *) (* keep *) 	reg		 r_clk10;
	assign CLK10 = r_clk10;
	reg		r_reset_out_n;
	assign RESET_OUT_N = r_reset_out_n;
	reg [3:0]r_xmt_count;


	reg [9:0]r_d;
	reg		 r_start_sync, r_syncing, r_synced;
	assign	SYNCED = r_synced;
	assign	SYNCING = r_syncing;
	reg [3:0]r_rcv_phase;
	assign DI = r_d;
	wire match = r_in_p == hdr || r_in_p == ~hdr;
	reg [9:0]r_ff;

	reg next_bit;
	always @(*)
	case (r_rcv_phase)
	0: next_bit = r_in_p[9];
	1: next_bit = r_in_p[0];
	2: next_bit = r_in_p[1];
	3: next_bit = r_in_p[2];
	4: next_bit = r_in_p[3];
	5: next_bit = r_in_p[4];
	6: next_bit = r_in_p[5];
	7: next_bit = r_in_p[6];
	8: next_bit = r_in_p[7];
	9: next_bit = r_in_p[8];
	default: next_bit = 'bx;
	endcase

	always @(posedge CLK) begin
		r_start_sync <= (!RESET_N|RESTART)&!r_syncing&!r_synced;
		if (!RESET_N|RESTART) begin
			r_syncing <= 1;
			r_synced <= 0; 
			r_rcv_phase <= 0;
		end else 
		if (match && (!r_synced || r_rcv_phase != r_xmt_count)) begin
			r_rcv_phase <= r_xmt_count;      
			r_syncing <= 0;
			r_synced <= 1; 
		end else begin
			if (r_syncing || r_start_sync) begin
				r_synced <= 0;
				r_syncing <= 1;
			end 
			if (r_xmt_count == 0) 
			     r_d <= r_ff;
		end
		r_ff <= {next_bit, r_ff[9:1]};
	end

	//
	// upstream link - uses derived clock and framed clock
	//

	reg [9:0]r_dout;
	assign DOUT = r_dout[9];
	always @(posedge CLK)
	if (!RESET_N) begin
		r_dout <= 10'b110000_1011; // only here to pass gatesim
		r_xmt_count <= 9;
		r_clk10 <= 0;
		r_reset_out_n <= 0; 
	end else begin
		if (r_xmt_count == 0) begin
			r_clk10 <= 0;
			r_xmt_count <= 9;
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
			if (r_xmt_count == 1)
				r_reset_out_n <= 1;
			if (r_xmt_count == 5)
				r_clk10 <= 1;
			r_xmt_count <= r_xmt_count-1;
			r_dout <= { r_dout[8:0], 1'bx};
		end
	end
`endif
endmodule


`ifdef XTEST

module test;

	reg DIN;
	reg RESET_N;
	reg CLK;
	initial begin
		CLK <= 0;
		forever #2.5 CLK <= ~CLK;
	end

	wire DOUT;
	deskew deskew(.CLK(CLK), .RESET_N(RESET_N), .RESTART(1'b0),
				.DIN(DIN),
				.DO(10'b0),
				.REV(1'b0),
				.XMT_READY(1'b0),
				.XMT_RD(1'b0),

				.DOUT(DOUT)
	);

    initial $dumpvars(0);
    initial begin
        RESET_N <= 0;
        #2000;   
        RESET_N <= 1;
    end
	initial    #100000 $finish;
 

    reg [9:0]data;
    
    integer i, j;
    initial begin
		#3
        forever begin

            for (i = 0; i < 8; i=i+1) begin
                case(i)
                0: data = 10'b0011_1110_10; // 17c   283
                1: data = 10'b0001_0101_11; // 3a8
                2: data = 10'b0100_1101_01; // 2b2
                3: data = 10'b0110_0001_10; // 186
                4: data = 10'b0010_1110_11;
                5: data = 10'b0100_1110_10;
                6: data = 10'b0001_1100_01;
                7: data = 10'b1011_0101_00;
                endcase
                for (j = 0; j < 10; j=j+1) begin
                    DIN <= #5 data[9-j];
                    #5;     // #5 is 200MHz
                    //#3.333;   // #3.33 is 300MHz
                    //#2.5  ;   // #2,5 is 400MHz
                end
            end
        end
    end
endmodule
`endif

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

