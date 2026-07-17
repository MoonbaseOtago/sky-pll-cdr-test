
/*
 * Copyright (c) 2026 Paul Campbell
 * SPDX-License-Identifier: Apache-2.0
 */

`timescale 1ns/1ps


module mgmt(
`ifdef GL_TEST
            inout VPWR, inout VGND,
`endif
			output [6:0]speed,
			output [7:0]xmt_prog,

			input	   clk10,
			input      reset_out_n,

			input [7:0]rcv_out,
			input      rcv_k,
			input	   rcv_ready,
			input	   rcv_align,

			output [7:0]xmt_in,
			output      xmt_k,
			output      xmt_ready,

			output		rev,
			output		mgmt_ok,
			output		restart
			);

	parameter UPSTREAM=1;


	//
	//	startup protocol - for both ends, but upstream is in controlbecause it
    //	    controls the clock
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
	//		3) after 2) above is done the transmnitter chooses an implementation specific
	//		   value based on max/min (might be an average might be something else) and starts transmitting
	//		   "XMT_RUNNING"
    //		4) if we're searching down and we don't get a response after sending 4 sets of Nx32 we go down
	//		   to the next freq and back to 1)
	//		5) when UPSTREAM detects XMT_RUNNING in both directions upstream takes the AND of its speed
	//         capabilities and the downstream's works from the highest speed down until it finds one
    //		   that works (by changing the freq and switching to 1) ), if there's no higher freq or it's
	//		   searching down) otherwise we switch to 6) before switching it sends 4 "FREQ SWITCHING"
	//		   with the target freq as th only bit in the bit mask
	//		6) we've chosen a freq upstream starts sending "GO_ONLINE"
	//		7) when it sees "GO_ONLINE" downstream starts repeating "GO_ONLINE"
	//		8) when upstream sees "GO_ONLINE" it sends 4x "ONLINE" and marks itself "idle" and
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
	//	2: 4A
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
	parameter START_UP = 0;
	parameter XMT_RUNNING = 1;
	parameter FREQ_SWITCHING = 2;
	parameter GO_ONLINE = 3;
	parameter ONLINE = 4;
	parameter ERROR_RESTART = 5;
	parameter ERROR_ACK = 6;
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
	parameter SPEED_100 = 8'b0000_0001;
	parameter SPEED_150 = 8'b0000_0010;
	parameter SPEED_200 = 8'b0000_0100;
	parameter SPEED_300 = 8'b0000_1000;
	parameter SPEED_400 = 8'b0001_0000;
	parameter SPEED_500 = 8'b0010_0000;
	parameter SPEED_800 = 8'b0100_0000;
	
	parameter SPEED = SPEED_100|SPEED_200;	// 100/200 MHz
	

	reg		 r_rev, c_rev;
	assign		rev = r_rev;
	reg		 r_ok, c_ok;
	assign		mgmt_ok = r_ok;
	reg		 r_restart, c_restart;
	assign		restart = r_restart;
	reg [7:0]r_xmt_d, c_xmt_d;
	assign		xmt_in = r_xmt_d;
	reg		 r_xmt_k, c_xmt_k;
	assign		xmt_k = r_xmt_k;
	reg		 r_xmt_ready, c_xmt_ready;
	assign		xmt_ready = r_xmt_ready;

	reg [3:0]r_state, c_state;
	reg [4:0]r_rcount, c_rcount;
	reg [4:0]r_xcount, c_xcount;
	reg [2:0]r_xphase, c_xphase;
	reg [2:0]r_rphase, c_rphase;
	reg [7:0]r_rcv_min, c_rcv_min;
	reg [7:0]r_rcv_max, c_rcv_max;
	reg [7:0]r_xmt_min, c_xmt_min;
	reg [7:0]r_xmt_max, c_xmt_max;
	reg [7:0]r_rcv_level, c_rcv_level;
	reg [6:0]r_rcv_speed, c_rcv_speed;
	reg      r_reset_count, c_reset_count;
	reg	     r_seen_prog, c_seen_prog;
	reg		 r_idle, c_idle;
	assign mgmt_ok = r_idle;
	generate
		if (UPSTREAM) begin
			assign speed = r_upstream_speed;
		end
	end generate
	reg [2:0]r_cmd, c_cmd;

	reg [7:0]next_speed;
	always @(*)
	case(r_next_speed)
	PLL_100: next_speed = SPEED_100;
	PLL_150: next_speed = SPEED_150;
	PLL_200: next_speed = SPEED_200;
	PLL_300: next_speed = SPEED_300;
	default: next_speed = 8'bx;
	endcase


	//
	//	This section is implementation specific, it defines the 'prog' output that drives the output
	//		drivers and how to sequence it. What these bits mean are implementation specific
	//	
	//		outputs are the current prog value in r_xmt_prog, and a signal saying if this is the last one
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

	reg [7:0]r_xmt_prog;
	reg [3:0]r_xmt_prog;
	assign xmt_prog = {4'b0, r_xmt_prog};
	wire last_prog = r_xmt_prog == 10;
	wire [4:0]average_prog = {1'b0, r_rcv_max}+{1'b0, r_rcv_min};

	always @(posedge clk10) begin
		casez ({choose_prog, next_prog, reset_prog}) // synthesis full_case parallel_case
		3'b1??:	r_xmt_prog <= average_prog[4:1];
		3'b?1?:	r_xmt_prog <= r_xmt_prog+1;
		3'b??1:	r_xmt_prog <= 1;
		3'b000:;
		endcase
	end

	//
	//

	always @(*) begin
			case(r_xphase)
			0: begin
				c_xmt_d = 8'hbc	// COM
				c_xmt_k = 1;
			   end
			1: begin
				c_xmt_d = 8'hf7;	// PAD
				c_xmt_k = 1;
			   end
			2: begin
				c_xmt_d = 8'h4A;	// 4A
				c_xmt_k = 0;
			   end
			3: begin
				c_xmt_d = xmt_prog;	// 00
				c_xmt_k = 0;
			   end
			4: begin
				c_xmt_d = r_xmt_min;	// 00
				c_xmt_k = 0;
			   end
			5: begin
				c_xmt_d = r_xmt_max;	// 00
				c_xmt_k = 0;
			   end
			6: begin
				c_xmt_d = (r_cnd==FREQ_SWITCHING? next_speed:SPEED);	// speed
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
				c_xmt_ready = !r_idle;
			end
	end

	always @(*)
	if (!reset_out_n) begin
		c_ok = 1'b0;
		c_rev = 1'b0;
		c_xmt_d = 1'bx;
		c_xmt_k = 1'bx;
		c_xmt_ready = 0;
		c_rcount = 5'bx;
		c_rphase = 0;
		c_state = 0;
		c_rcv_min = 0;
		c_rcv_max = 0;
		c_xmt_min = 0;
		c_xmt_max = 0;
		c_rcv_level = 0;
		c_reset_count = 0;
		c_cmd = START_UP;
		c_seen_prog = 0;
		if (UPSTREAM) begin
			c_xmt_speed = SPEED_100;
		end
		reset_prog = 1;
		next_prog = 0;
		choose_prog = 0;
		c_idle = 0;
	end else  begin
		reset_prog = 0;
		next_prog = 0;
		choose_prog = 0;
		c_ok = r_ok;
		c_rev = r_rev;
		c_rcount = r_rcount;
		c_rphase = r_rphase;
		c_state = r_state;
		c_rcv_min = r_rcv_min;
		c_rcv_max = r_rcv_max;
		c_xmt_min = r_rcv_min;
		c_xmt_max = r_rcv_max;
		c_cmd = r_cmd;
		c_rcv_level = r_rcv_level;
		c_reset_count = r_reset_count;
		c_seen_prog = r_seen_prog;
		c_idle = 0;
		if (UPSTREAM) begin
			c_xmt_speed = r_xmt_speed;
		end
		case (r_state)	// synthesis full_case
	
		0:	begin
				if (rcv_ready && rcv_k && rcv_out == 8'hbc) begin // COM?
					c_state = 1;
					c_rcv_count = 0;
					c_rphase = 1;
	
				end	
			end
		1:	begin
				if (rcv_ready) begin 
					case (r_rphase)
					0:	if (!rcv_k || rcv_out != 8'hbc) c_state = 0;
					1:	if (!rcv_k || rcv_out != 8'hf7) c_state = 0;
					2:	if (rcv_k || rcv_out != 8'h4A) begin
							if (!rcv_k)	c_rev = ~r_rev;
							c_state = 0;
					3:  if (rcv_k) begin
							c_state = 0;
						end else begin
							if (r_rcv_level != rcv_out) begin
								c_rcv_level = rcv_out;
								c_reset_count = 1;
							end
						end
					4:  if (rcv_k) begin
							c_state = 0;
						end else begin
						end
					5:	if (rcv_k) begin
							c_state = 0;
						end else begin
						end
					6:  if (rcv_k) begin
							c_state = 0;
						end else begin
							c_remote_speed = rcv_out;
						end
					7:	if (rcv_k) begin
							c_state = 0;
						end else begin
							if (r_count == 3'h3f) begin
								if (r_rcv_min == 0 || r_rcv_level < r_rcv_min) begin
									c_rcv_min = r_rcv_level;
								end
								if (r_rcv_max == 0 || r_rcv_level > r_rcv_max) begin
									c_rcv_max = r_rcv_level;
								end
							end
							c_rcv_count = (r_reset_count?0:r_rcv_count+1);
							c_reset_count = 0;
							if (rcv_out[2:0] == 
						end 
					end
					c_rphase = r_rphase+1;
				end	
			end
		endcase
		c_xcount = r_xcount+1;
		case (r_xphase)
		7:	begin
				case (r_cmd)
				START_UP:	begin
								if (r_xcount == 31) begin
									if (last_prog) begin
										reset_prog = 1;
										if (r_seen_prog) begin
											c_cmd = XMT_RUNNING;
											c_seen_prog = 0;
										end else 
										if (r_rcv_min != 0) begin
											c_seen_prog = 1;
										end
									end else begin
										next_prog = 1;
									end
								end
							end
				endcase
			end
		endcase
	end

	always @(posedge clk10) begin
		r_ok <= c_ok;
		r_rev <= c_rev;
		r_xmt_d <= c_xmt_d;
		r_xmt_k <= c_xmt_k;
		r_xmt_ready <= c_xmt_ready;
		r_rcount <= c_xcount;
		r_xcount <= c_xcount;
		r_rphase <= c_rphase;
		r_xphase <= c_xphase;
		r_state <= c_state;
		r_rcv_min <= c_rcv_min;
		r_rcv_max <= c_rcv_max;
		r_xmt_min <= c_xmt_min;
		r_xmt_max <= c_xmt_max;
		r_rcv_level <= c_rcv_level;
		r_reset_count <= c_reset_count;
		r_cmd <= c_cmd;
		r_seen_prog <= c_seen_prog;
		r_idle <= c_idle;
		if (UPSTREAM) begin
			r_xmt_speed <= c_xmt_speed;
		end
	end


	

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
