/*
 * Copyright (c) 2026 Paul Campbell
 * SPDX-License-Identifier: Apache-2.0
 */

`timescale 1ns/1ps


module mgmt(input reset_n,
`ifdef GL_TEST
            inout VPWR, inout VGND,
`endif
			input  [6:0]default_speed,
			output [6:0]speed,
			output [7:0]xmt_prog,

			input	   clk10,
			input      reset_out_n,

			input [7:0]rcv_out,
			input      rcv_k,
			input	   rcv_ready,

			output [7:0]xmt_in,
			output      xmt_k,
			output      xmt_ready,

			output		rev,
			output		mgmt_ok,
			output		restart
			);

	parameter UPSTREAM=1;


	//
	//	startup protocol - for both ends, but upstream is in control because it
    //	    controls the clock. 
	//
	//	Startup needs to:
	//
	//		1) send a stream to get remote clock recovery to lock (this may take a while and
	//		   we may have to repeat many times)
	//		2) try a bunch of different transmit driver options (XMT PROG) to optimise the
	//		   link - this is done by sending N (implementation specific) values, the receiver
	//		   doesn't know what they mean, or how many of them there are, it just reports the
	//		   minimum and maximum values it's seen that contain 32 non-error symbols) - transmitters
    //		   send at least one complete sequence after it sees a max/min value - this is with the command
	//		   "START_UP"
	//		   Note: some tgransmit driver options (too weak, too string) may mean that the downstream
	//				 side does not get a reliable clock, upstream needs to repeat training data enough
	//				 times for the downstream CDR to lock, upstream does better by being fast
	//		3) after 2) above is done the transmnitter chooses an implementation specific
	//		   value based on max/min (might be an average might be something else) and starts transmitting
	//		   "XMT_RUNNING", we wait for the other side to also send XMT_RUNNING
    //		4) if we're searching down and we don't get a response after sending 8 sets of Nx32 we go down
	//		   to the next freq and back to 1)
	//		5) when UPSTREAM detects XMT_RUNNING in both directions upstream takes the AND of its speed
	//         capabilities and the downstream's works from the highest speed down until it finds one
    //		   that works (by changing the freq and switching to 1) ), if there's no higher freq or it's
	//		   searching down) otherwise we switch to 6) before switching it sends 8 "FREQ SWITCHING"
	//		   with the target freq as th only bit in the bit mask
	//		6) we've chosen a freq upstream starts sending "GO_ONLINE"
	//		7) when it sees "GO_ONLINE" downstream starts repeating "GO_ONLINE"
	//		8) when upstream sees "GO_ONLINE" it sends 8x "ONLINE" and marks itself "idle" and
	//		   quits sending packets
	//		9) when downstream receives "ONLINE" it marks itself "idle" and stops sending
	//
	//
	//		If when online if either side has an error it sends 4 "ERROR_RESTART" packets, the other side
	//		sends "ERROR_ACK" 4 times and then goes idle
	//
	//	packets look like:
	//
	//	0: COM	
	//  1: PAD
	//	2: 5D			     - we run with LFSR turned on, 5D->4A which has a symbol that is not the same when inverted
	//  3: XX	XMT PROG
	//  4: 00	RCV MIN PROG - min successfull prog received - 0 means none
	//  5: 00	RCV MAX PROG
	//  6: 00	speed available (only used upstream)
	//  7: 00	cmd
	//
	//	Commands bits 2:0 of the 7th byte, bits 7:3 are reserved and should be 0:
	//		0 - START_UP
	//		1 - XMT_RUNNING
	//		2 - FREQ_SWITCHING
	//		3 - GO_ONLINE
	//		4 - ONLINE
	//		5 - ERROR_RESTART
	//		6 - ERROR_ACK
	//
	localparam START_UP = 3'd0;
	localparam XMT_RUNNING = 3'd1;
	localparam FREQ_SWITCHING = 3'd2;
	localparam GO_ONLINE = 3'd3;
	localparam ONLINE = 3'd4;
	localparam ERROR_RESTART = 3'd5;
	localparam ERROR_ACK = 3'd6;
	//
	//  Speed mask in byte 6:
	//		bit			freq
	//		0			100MHz
	//		1			150MHz
	//		2			200MHz
	//		3			300MHz
	//		4			400MHz
	//		5			500MHz
	//		6			800MHz
	//		7			reserved set to 0
	//
	localparam SPEED_100 = 7'b000_0001;
	localparam SPEED_150 = 7'b000_0010;
	localparam SPEED_200 = 7'b000_0100;
	localparam SPEED_300 = 7'b000_1000;
	localparam SPEED_400 = 7'b001_0000;
	localparam SPEED_500 = 7'b010_0000;
	localparam SPEED_800 = 7'b100_0000;

	//
	//	Upstream algorithm for determining speed:
	//
	//		1) try to connect at 100MHz, drop back to 50MHz (if supported)
	//		2) get the downstream speed supported mask, and it with local mask
	//		3) if highest common bit is the same as this speed stop
	//		4) start at the highest common bit and work down until things work
	//		5) if nothing found	go back to 1)
	//

	//localparam MAX_COUNT = 5'h3;
	//localparam MAX_COUNT = 5'd7;
	//localparam MAX_COUNT = (UPSTREAM ? 5'd31: 5'd7);
	localparam MAX_COUNT = 5'd31;

	generate
	

	reg		 r_rev, c_rev;
	assign		rev = r_rev;
	reg		 r_restart, c_restart;
	assign		restart = r_restart;
	reg [7:0]r_xmt_d, c_xmt_d;
	assign		xmt_in = r_xmt_d;
	reg		 r_xmt_k, c_xmt_k;
	assign		xmt_k = r_xmt_k;
	reg		 r_xmt_ready, c_xmt_ready;
	assign		xmt_ready = r_xmt_ready;

	reg [1:0]r_rstate, c_rstate;
	reg [4:0]r_rcount, c_rcount;
	reg [4:0]r_xcount, c_xcount;
	reg [2:0]r_xphase, c_xphase;
	reg [2:0]r_rphase, c_rphase;
	reg [7:0]r_rcv_min, c_rcv_min;
	reg [7:0]r_rcv_max, c_rcv_max;
	reg [7:0]r_xmt_min, c_xmt_min;
	reg [7:0]r_xmt_max, c_xmt_max;
	reg [7:0]r_rcv_level, c_rcv_level;
	localparam MAX_CYCLES = (UPSTREAM?5'h1f:5'h5);
	reg	[4:0]r_xmt_cycles, c_xmt_cycles;
	reg      r_reset_count, c_reset_count;
	reg	     r_seen_prog, c_seen_prog;
	reg		 r_idle, c_idle;					// conected state
	reg		 r_almost_idle, c_almost_idle;		// disable sending messages as we get close
	assign mgmt_ok = r_idle;
	reg [2:0]r_cmd, c_cmd;

	reg	[2:0]r_last_cmd, c_last_cmd;
	reg [6:0]r_xmt_speed, c_xmt_speed;
	reg [6:0]c_upstream_speed;
	wire [6:0]prev_upstream_speed, prev_rcv_speed, prev_next_speed;;
	reg [6:0]c_rcv_speed;		
	reg [6:0]c_next_speed;
	reg	     c_searching_down;
	wire	 prev_searching_down;
	wire [6:0]next_upstream_speed, next_default_speed, first_upstream_speed;
	wire	last_speed, last_default_speed;
	wire last_recycle;
	reg		reset_recycle, next_recycle;
	if (UPSTREAM) begin : up		// this is where we hide the extra state/logic that's
						    // only required in the upstream management engine
		reg	     r_searching_down;
		reg [6:0]r_rcv_speed;	// the speeds that the downstream can support
		assign prev_rcv_speed = r_rcv_speed;
		reg [6:0]r_upstream_speed;					// actual speed to PLL (as a bit mask
		reg [6:0]r_next_speed;						// the speed we're going to shift to after announcing
		assign prev_next_speed = r_next_speed;
		wire [6:0]valid_speeds = r_rcv_speed&default_speed;	// intersection of speeds we support and speeds downstream supports
		

		reg [6:0]xnext_upstream_speed, xnext_default_speed, xfirst_upstream_speed;
		reg xlast_speed, xlast_default_speed;
		always @(*) begin
			casez(valid_speeds) // synthesis full_case parallel_case		// the first highest speed
			7'b1??_????: xfirst_upstream_speed = 7'b100_0000;
			7'b01?_????: xfirst_upstream_speed = 7'b010_0000;
			7'b001_????: xfirst_upstream_speed = 7'b001_0000;
			7'b000_1???: xfirst_upstream_speed = 7'b000_1000;
			7'b000_01??: xfirst_upstream_speed = 7'b000_0100;
			7'b000_001?: xfirst_upstream_speed = 7'b000_0010;
			7'b000_0001: xfirst_upstream_speed = 7'b000_0001;
			7'b000_0000: xfirst_upstream_speed = 7'b000_0010;
			endcase
		end

		/* verilator lint_off CASEOVERLAP */
		always @(*) begin
			xlast_speed = 0;
			casez({r_upstream_speed, valid_speeds}) // synthesis full_case parallel_case	// the next speed below the current one
			14'b1??_????__?1?_????: xnext_upstream_speed = 7'b010_0000;
			14'b1??_????__?01_????: xnext_upstream_speed = 7'b001_0000;
			14'b1??_????__?00_1???: xnext_upstream_speed = 7'b000_1000;
			14'b1??_????__?00_01??: xnext_upstream_speed = 7'b000_0100;
			14'b1??_????__?00_001?: xnext_upstream_speed = 7'b000_0010;
			14'b1??_????__?00_0001: xnext_upstream_speed = 7'b000_0001;
			14'b1??_????__?00_0000: begin xnext_upstream_speed = 7'b000_0010; xlast_speed = 1; end
			14'b?1?_????__??1_????: xnext_upstream_speed = 7'b001_0000;
			14'b?1?_????__??0_1???: xnext_upstream_speed = 7'b000_1000;
			14'b?1?_????__??0_01??: xnext_upstream_speed = 7'b000_0100;
			14'b?1?_????__??0_001?: xnext_upstream_speed = 7'b000_0010;
			14'b?1?_????__??0_0001: xnext_upstream_speed = 7'b000_0001;
			14'b?1?_????__??0_0000: begin xnext_upstream_speed = 7'b000_0010; xlast_speed = 1; end
			14'b??1_????__???_1???: xnext_upstream_speed = 7'b000_1000;
			14'b??1_????__???_01??: xnext_upstream_speed = 7'b000_0100;
			14'b??1_????__???_001?: xnext_upstream_speed = 7'b000_0010;
			14'b??1_????__???_0001: xnext_upstream_speed = 7'b000_0001;
			14'b??1_????__???_0000: begin xnext_upstream_speed = 7'b000_0010; xlast_speed = 1; end
			14'b???_1???__???_?1??: xnext_upstream_speed = 7'b000_0100;
			14'b???_1???__???_?01?: xnext_upstream_speed = 7'b000_0010;
			14'b???_1???__???_?001: xnext_upstream_speed = 7'b000_0001;
			14'b???_1???__???_?000: begin xnext_upstream_speed = 7'b000_0010; xlast_speed = 1; end
			14'b???_?1??__???_??1?: xnext_upstream_speed = 7'b000_0010;
			14'b???_?1??__???_??01: xnext_upstream_speed = 7'b000_0001;
			14'b???_?1??__???_??00: begin xnext_upstream_speed = 7'b000_0010; xlast_speed = 1; end
			14'b???_??1?__???_???1: xnext_upstream_speed = 7'b000_0001;
			14'b???_??1?__???_???0: begin xnext_upstream_speed = 7'b000_0010; xlast_speed = 1; end
			14'b???_???1__???_????: begin xnext_upstream_speed = 7'b000_0010; xlast_speed = 1; end
			default: xnext_upstream_speed = 7'bx;
			endcase
		end
		/* verilator lint_on CASEOVERLAP */

		always@(*) begin
			xlast_default_speed = 0;
			casez(r_upstream_speed) // synthesis full_case parallel_case	// the next speed when we haven't talked to the down stream yet
			7'b1??_????: xnext_default_speed = 7'b100_0000;
			7'b01?_????: xnext_default_speed = 7'b010_0000;
			7'b001_????: xnext_default_speed = 7'b001_0000;
			7'b000_1???: xnext_default_speed = 7'b000_1000;
			7'b000_01??: xnext_default_speed = 7'b000_0100;
			7'b000_001?: xnext_default_speed = 7'b000_0010;
			7'b000_0001: xnext_default_speed = 7'b000_0001;
			7'b000_0000: begin xnext_default_speed = 7'b000_0010; xlast_default_speed = 1; end
			endcase
		end

		assign speed = r_upstream_speed;
		always @(posedge clk10 or negedge reset_n) 
		if (!reset_n) begin
			r_upstream_speed <= 7'b000_0010;
			r_rcv_speed <= 7'bx;
			r_next_speed <= 7'bx;
			r_searching_down <= 0;
		end else begin
			r_upstream_speed <= c_upstream_speed;
			r_rcv_speed <= c_rcv_speed;
			r_next_speed <= c_next_speed;
			r_searching_down <= c_searching_down;
		end
		assign prev_upstream_speed = r_upstream_speed;

		assign next_upstream_speed = xnext_upstream_speed;
		assign next_default_speed = xnext_default_speed;
		assign prev_searching_down = r_searching_down;
		assign last_speed = xlast_speed;
		assign last_default_speed = xlast_default_speed;
		assign first_upstream_speed = xfirst_upstream_speed;

		//
		//	this logic is to discover and timeout frequencies that are too high (ie hear nothing from the downstream)
		//
		reg [1:0]r_recycle;
		always @(posedge clk10)
		if (reset_recycle) begin
			r_recycle <= 3;
		end else
		if (next_recycle) begin
			r_recycle <= r_recycle-1;
		end
		assign last_recycle = r_recycle==0;
	end else begin :down		// these stubs are for the downstream side
		assign speed = 7'bx;
		assign prev_next_speed = 0;
		assign prev_upstream_speed = 0;
		assign next_upstream_speed = 0;
		assign next_default_speed = 0;
		assign first_upstream_speed = 0;
		assign prev_searching_down = 0;
		assign prev_rcv_speed = 0;
		assign last_speed = 1;
		assign last_default_speed = 1;
		assign last_recycle=0;
	end

	//
	//	This section is implementation specific, it defines the 'prog' output that drives the output
	//		drivers and how to sequence it. What these bits mean are implementation specific
	//	
	//		outputs are the current prog value in xmt_prog, and a signal last_prog saying if this is
	//				 the last one
	//
	//		inputs are:
	//			reset_prog - sets the prog to the first one
	//			next_prog - steps the prog to the next one
	//			choose_prog - chooses the best prog based on the min/max values from the other end
	//		only one is asserted on any clock
	//
	//	a NULL implementation looks like:
	//
	//		reg reset_prog, next_prog, choose_prog;
	//		wire [7:0]r_xmt_prog = 1;
	//		assign xmt_prog = r_xmt_prog;
	//		wire last_prog = 1;
	//
	//
	//	here's a sample implementation that implements the values from 1-10 and chooses the average of
	//		the ones that work
	//

	reg	reset_prog;
	reg	choose_prog;
	reg	next_prog;

	reg [3:0]r_xmt_prog;
	assign xmt_prog = {4'b0, r_xmt_prog};
	wire last_prog = r_xmt_prog == 10;

	/* verilator lint_off UNUSEDSIGNAL */
	wire [4:0]average_prog = {1'b0, r_xmt_max[3:0]}+{1'b0, r_xmt_min[3:0]};
	/* verilator lint_on UNUSEDSIGNAL */

	/* verilator lint_off CASEOVERLAP */
	always @(posedge clk10) begin
		case ({choose_prog, next_prog, reset_prog}) // synthesis full_case parallel_case
		3'b100:	r_xmt_prog <= average_prog[4:1];
		3'b010:	r_xmt_prog <= r_xmt_prog+1;
		3'b001:	r_xmt_prog <= 1;
		3'b000:;
		default: r_xmt_prog <= 4'bx;
		endcase
	end
	/* verilator lint_on CASEOVERLAP */

	//
	//	transmit engine
	//
	always @(*) begin
			case(r_xphase)
			0: begin
				c_xmt_d = 8'hbc;	// COM
				c_xmt_k = 1;
			   end
			1: begin
				c_xmt_d = 8'hf7;	// PAD
				c_xmt_k = 1;
			   end
			2: begin
				c_xmt_d = 8'h5D;	// 5D
				c_xmt_k = 0;
			   end
			3: begin
				c_xmt_d = xmt_prog;	// 00
				c_xmt_k = 0;
			   end
			4: begin
				c_xmt_d = r_rcv_min;	// 00
				c_xmt_k = 0;
			   end
			5: begin
				c_xmt_d = r_rcv_max;	// 00
				c_xmt_k = 0;
			   end
			6: begin
				c_xmt_d = {1'b0, (UPSTREAM && r_cmd==FREQ_SWITCHING? prev_next_speed:default_speed)};	// speed
				c_xmt_k = 0;
			   end
			7: begin
				c_xmt_d = {5'b0, r_cmd};	// 00
				c_xmt_k = 0;
			   end
			endcase
			if (!reset_out_n) begin
				c_xphase = 0;
				c_xmt_ready = 0;
			end else begin
				c_xphase = r_xphase+1;
				c_xmt_ready = (!r_idle&!r_almost_idle) | (r_xmt_ready&&r_xphase != 7);
			end
	end


	//
	//	control state machine
	//
	//		r_rstate - receive state:
	//
	//		0: error recovery
	//		1: reading data
	//		2: XMT_RUNNING 
	//		3: going online	
	//
	always @(*)
	if (!reset_out_n) begin
		c_rev = 1'b0;
		c_rcount = 0;
		c_xcount = 0;
		c_rphase = 0;
		c_rstate = 0;
		c_rcv_min = 0;
		c_rcv_max = 0;
		c_xmt_min = 0;
		c_xmt_max = 0;
		c_rcv_level = 0;
		c_reset_count = 0;
		c_cmd = START_UP;
		c_seen_prog = 0;
		c_xmt_speed = default_speed;
		reset_prog = 1;
		next_prog = 0;
		choose_prog = 0;
		c_idle = 0;
		c_searching_down = prev_searching_down;
		c_rcv_speed = 7'bx;
		c_restart = 0;
		c_upstream_speed = prev_upstream_speed;
		c_next_speed = 7'bx;
		c_xmt_cycles = MAX_CYCLES;
		next_recycle = 0;
		reset_recycle = 1;
		c_last_cmd = START_UP;
		c_almost_idle = 0;
	end else  begin
		next_recycle = 0;
		reset_recycle = 0;
		reset_prog = 0;
		next_prog = 0;
		choose_prog = 0;
		c_rev = r_rev;
		c_rcount = r_rcount;
		c_xcount = r_xcount;
		c_rphase = r_rphase;
		c_rstate = r_rstate;
		c_rcv_min = r_rcv_min;
		c_rcv_max = r_rcv_max;
		c_xmt_min = r_xmt_min;
		c_xmt_max = r_xmt_max;
		c_cmd = r_cmd;
		c_rcv_level = r_rcv_level;
		c_reset_count = r_reset_count;
		c_seen_prog = r_seen_prog;
		c_idle = r_idle;
		c_xmt_speed = r_xmt_speed;
		c_searching_down = prev_searching_down;
		c_rcv_speed = prev_rcv_speed;
		c_restart = 0;
		c_upstream_speed = prev_upstream_speed;
		c_next_speed = prev_next_speed;
		c_xmt_cycles = r_xmt_cycles;
		c_last_cmd = r_last_cmd;
		c_almost_idle = r_almost_idle;
		//
		//	this is the receive side state machine
		//		we read 8 symbols - phase counts where we think we are in the message
		//
		case (r_rstate)	// synthesis full_case
		0:	begin
				c_reset_count = 0;
				c_rcount = 0;
				c_rphase = 1;
				if (rcv_ready && rcv_k && rcv_out == 8'hbc) begin // COM?
					c_rstate = 1;
				end	
			end
		1, 2, 3:	begin
				if (rcv_ready) begin 
					case (r_rphase)
					0:	if (!rcv_k || rcv_out != 8'hbc) c_rstate = 0;
					1:	if (!rcv_k || rcv_out != 8'hf7) c_rstate = 0;
					2:	if (rcv_k || rcv_out != 8'h5D) begin
							if (!rcv_k)	c_rev = ~r_rev;
							c_rstate = 0;
						end
					3:  if (rcv_k) begin
							c_rstate = 0;
						end else begin
							if (r_rcv_level != rcv_out) begin
								c_rcv_level = rcv_out;
								if (r_rcount != 0)
									c_reset_count = 1;
							end
						end
					4:  if (rcv_k) begin
							c_rstate = 0;
						end else begin
							if (r_rcount == MAX_COUNT)
								c_xmt_min = rcv_out;
						end
					5:	if (rcv_k) begin
							c_rstate = 0;
						end else begin
							if (r_rcount == MAX_COUNT)
								c_xmt_max = rcv_out;
						end
					6:  if (rcv_k) begin
							c_rstate = 0;
						end else begin
							if (!rcv_out[7])
								c_rcv_speed = rcv_out[6:0];
						end
					7:	if (rcv_k) begin
							c_rstate = 0;
						end else begin
							c_last_cmd = rcv_out[2:0];
							if (rcv_out[2:0] != r_last_cmd) begin
								c_rcount = 0;
							end else begin
								c_rcount = (r_reset_count || r_rcount==MAX_COUNT?0:r_rcount+1);
								if (r_rcount == MAX_COUNT) begin
									if (r_rcv_min == 0 || r_rcv_level < r_rcv_min) begin
										c_rcv_min = r_rcv_level;
									end
									if (r_rcv_max == 0 || r_rcv_level > r_rcv_max) begin
										c_rcv_max = r_rcv_level;
									end
								end
								case (rcv_out[2:0])	// synthesis full_case
								START_UP:;
	
								XMT_RUNNING:if (r_rcount > 1) begin
												c_rstate = 2;
											end
	
								FREQ_SWITCHING:
											begin
												if (!UPSTREAM && r_rcount >= 1)
													c_restart = 1;
											end
								ONLINE,	 
								GO_ONLINE:	 if( r_rcount >= 1) begin
												if (UPSTREAM)
													c_almost_idle = 1;
												c_rstate = 3;
											end
								default:;
								endcase
							end
							c_reset_count = 0;
						end
					
					endcase
					c_rphase = r_rphase+1;
				end	
			end
		default:;
		endcase
		//
		//	transmit controller, we only do stuff when active on the last beat of each message
		//
		if (!r_idle && r_xphase == 7) begin
			c_xcount = r_xcount+1;
			case (r_cmd)
			START_UP:	begin
								if (r_xcount == MAX_COUNT) begin
									c_xcount = 0;
									c_seen_prog = r_seen_prog||(r_xmt_cycles==0&&r_rcv_max!=0&& r_rcv_max!=0 && last_prog);
									if (r_xmt_cycles != 0) begin
										c_xmt_cycles = r_xmt_cycles-1;
									end else begin
										c_xmt_cycles = MAX_CYCLES;
										if (last_prog) begin
											if (r_seen_prog) begin
												//if (UPSTREAM) begin
													//if (prev_searching_down || prev_upstream_speed==first_upstream_speed) begin
												//		choose_prog = 1;
												//		c_cmd = XMT_RUNNING;
													//end else begin
													//	choose_prog = 1;
													//	c_cmd = FREQ_SWITCHING;
													//	c_freq_switch = 1;
													//	if (prev_rcv_speed == 0) begin
													//		c_next_speed =  next_default_speed;
													//	end else begin
													//		if (prev_searching_down) begin
													//			if (last_speed) begin
													//				c_next_speed =  7'b000_0010; 
													//				c_searching_down = 0;
													//			end else begin
													//				c_next_speed =  next_upstream_speed;
													//				c_rcv_speed = 0;
													//			end
													//		end else begin
													//			c_searching_down = 1;
													//			c_next_speed =  first_upstream_speed;
													//		end
													//	end
												//	end
												//end else begin
													choose_prog = 1;
													c_cmd = XMT_RUNNING;
												//end
											end else begin
												reset_prog = 1;
												if (UPSTREAM) begin
													if (last_recycle) begin
														c_cmd = FREQ_SWITCHING;
														if (prev_searching_down) begin
															if (last_speed) begin
																	c_next_speed =  7'b000_0010; 
																	c_searching_down = 0;
															end else begin
																	c_next_speed =  next_upstream_speed;
																	c_rcv_speed = 0;
															end
														end else begin
															c_searching_down = 1;
															c_next_speed =  first_upstream_speed;
														end
													end else begin
														next_recycle = 1;
													end
												end
											end
										end else begin
											next_prog = 1;
										end
									end
								end
						end	
			XMT_RUNNING:begin
								if (r_xcount == MAX_COUNT) begin
									c_xcount = 0;
									if (r_xmt_cycles == 0) begin
										c_xmt_cycles = MAX_CYCLES;
										if (UPSTREAM) begin
											if (last_recycle) begin
												if (prev_searching_down || prev_upstream_speed==first_upstream_speed) begin
													if (r_rstate >= 2)
														c_cmd = GO_ONLINE;
												end else begin
													c_cmd = FREQ_SWITCHING;
													if (prev_rcv_speed == 0) begin
														c_next_speed =  next_default_speed;
													end else begin
														if (prev_searching_down) begin
															if (last_speed) begin
																c_next_speed =  7'b000_0010; 
																c_searching_down = 0;
															end else begin
																c_next_speed =  next_upstream_speed;
																c_rcv_speed = 0;
															end
														end else begin
															c_searching_down = 1;
															c_next_speed =  first_upstream_speed;
														end
													end
												end
											end else begin
												next_recycle = 1;
											end
										end else begin
											if (r_rstate == 3) begin
												c_cmd = ONLINE;
											end
										end
									end else begin
										c_xmt_cycles = r_xmt_cycles-1;;
									end
								end
						end	
			GO_ONLINE:	begin
								if (r_xcount == 7 && r_rstate >= 2) begin
									c_xcount = 0;
									if (UPSTREAM) begin
										if (r_rstate == 3)
											c_cmd = ONLINE;
									end else begin
										if (r_cmd == ONLINE)
											c_idle = 1;
										c_cmd = ONLINE;
									end
								end
						end
			ONLINE:		begin
								if (r_xcount == 31 && (r_rstate >=2 || r_almost_idle)) begin
									c_xcount = 0;
									if (UPSTREAM) begin
										c_idle = 1;
									end else begin
										if (r_cmd == ONLINE)
											c_idle = 1;
										c_cmd = ONLINE;
									end
								end
						end
			FREQ_SWITCHING:begin
								if (UPSTREAM && r_xcount == 7) begin
									c_restart = 1;
									c_upstream_speed = prev_next_speed;
								end
						end
			default:;
			endcase
		end
		if (c_restart) begin
			c_cmd = START_UP;
			c_rcv_min = 0;
			c_rcv_max = 0;
			c_xmt_min = 0;
			c_xmt_max = 0;
			c_rcv_level = 0;
			c_xmt_cycles = MAX_CYCLES;
			c_xcount = 0;
			c_rstate = 0;
			c_seen_prog = 0;
			reset_prog = 1;
			reset_recycle = 1;
			c_last_cmd = START_UP;
			c_idle = 0;
			c_almost_idle = 0;
		end
	end

	always @(posedge clk10) begin
		r_rev <= c_rev;
		r_xmt_d <= c_xmt_d;
		r_xmt_k <= c_xmt_k;
		r_xmt_ready <= c_xmt_ready;
		r_rcount <= c_rcount;
		r_xcount <= c_xcount;
		r_rphase <= c_rphase;
		r_xphase <= c_xphase;
		r_rstate <= c_rstate;
		r_rcv_min <= c_rcv_min;
		r_rcv_max <= c_rcv_max;
		r_xmt_min <= c_xmt_min;
		r_xmt_max <= c_xmt_max;
		r_rcv_level <= c_rcv_level;
		r_reset_count <= c_reset_count;
		r_cmd <= c_cmd;
		r_seen_prog <= c_seen_prog;
		r_idle <= c_idle;
		r_almost_idle <= c_almost_idle;
		r_xmt_speed <= c_xmt_speed;
		r_xmt_cycles <= c_xmt_cycles;
		r_last_cmd <= c_last_cmd;
	end

	//
	//	stuff that has to live across PLL restarts
	//
	/* verilator lint_off SYNCASYNCNET */
	always @(posedge clk10 or negedge reset_n) 
	if (!reset_n) begin
		r_restart <= 0;
	end else begin
		r_restart <= c_restart;
	end
	/* verilator lint_on SYNCASYNCNET */

	endgenerate

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
