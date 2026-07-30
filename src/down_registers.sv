/*
 * Copyright (c) 2026 Paul Campbell
 * SPDX-License-Identifier: Apache-2.0
 */

`timescale 1ns/1ps


module down_registers(input reset_n, input clk10,
`ifdef GL_TEST
            inout VPWR, inout VGND,
`endif
			input [7:0]rcv_out,
			input      rcv_k,
			input	   rcv_ready,
	/* verilator lint_off UNUSEDSIGNAL */
			input	   rcv_align,
	/* verilator lint_on UNUSEDSIGNAL */

			output [7:0]xmt_in,
			output      xmt_k,
			output      xmt_ready,

			input	    mgmt_ok
			);


			//
			// 8b10 special symbols (sent/received with k bit sent)
			//
			//	K28.5 0xbc	- COM Comma 
			//	K27.7 0xfb	- STP Start TLP		START
			//	K28.2 0x5c	- SDP Start DLLP	STARTA
			//	K29.7 0xfd	- END End			END
			//	K30.7 0xfe	- EDB EnD Bad 
			//	K23.7 0xfc	- PAD 
			//	K28.0 0x28	- SKP 
			//	K28.1 0x5c	- FTS 
			//	K28.3 0x7c	- IDL Idle 
			//	K28.4 0x9c  - Reserved
			//	K28.6 0xdc	- Reserved
			//	K28.7 0xfc	- EIE 
			//
			// Lower layers signal:
			//	K0.0 0x00	- error
			//

			localparam START =	8'hfb;
			localparam STARTA =	8'h5c;
			localparam END =	8'hfd;
			localparam ERROR =	8'h00;
	
			//
			//	Some of these symbols are used at lower layers, others
			//		may have undefined results, only send START/STARTA/END.
			//		any k symbol received other than these 3 is an error
			//
			//
			//		Downstream messages
			//
			//		commands:
			//
			//		byte 0
			//			7-5	device address
			//			4   async
			//			3-1 length
			//			0:	1=read/0=write
			//
			//		lengths:
			//				0: addr 1 byte  data 1 byte   cmd
			//				1: addr N bytes data 1 bytes  data
			//				2: addr N bytes data 2 bytes  data
			//				3: addr N bytes data 4 bytes  data
			//				4: addr N bytes data 8 bytes  data
			//				4: addr N bytes data 16 bytes  data
			//				6: addr N bytes data terminated by symbol data
			//				7: next byte gives lengths
			//
			//			N is programmed in control registers, defaults to 4
			//
			//		byte 1 (if length==3)
			//
			//		7		cmd=1/data=0
			//		6:4		address length
			//		3:0		data length
			//					0: 1 byte	
			//					1: 2 bytes
			//					2: 4 bytes
			//					3: 6 bytes
			//					4: 8 bytes
			//					5: 10 bytes
			//					6: 12 bytes
			//					7: 16 bytes
			//					14: next 2 bytes give data length
			//					15: N bytes (teminated by end symbol) - N/A for addresses
			//					other values undefined
			//
			//		The async tag is a byte used to identify an out of order response, it's included 
			//		to identify the response - a tag of 0 is undefined
			//
			//		messages look like:
			//
			//		[START] byte0 [byte1] [data length] [async] address0-N data0-N [END]
			//
			//		start and end symbols are optional unless you are using 'terminated by end symbol'
			//		or you have an error condition'
			//
			//		Upstream messages:
			//
			//		Upstream messages come in two types: data responses, out of band (OOB) messages
			//
			//		Data responses look like:
			//		
			//			[START] async data0-N END
			//			
			//			async is the async byte from an async request, it is 0 for a synchronous request.
			//
			//		OOB messages:
			//
			//			STARTA code data0-N END
			//
			//			code is a code indicating what sort of message it is:
			//
			//			0: error CRC
			//			1: error link
			//			2: error invalid address
			//			3: interrupt, followed by a 2 byte mask, LSB first indicating the interrupt type
			//			4: data - data of arbitrary length follows
			//			other values are undefined
			//
			//
			//		A device has 2 address spaces - Command and Data
			//
			//			Data is of arbitrary size and device specific
			//
			//			Command referes to a register block the first 256 bytes are standardkised
			//				any remaining addressess are device specific
			//
			//	Standard command register layout:
			//	
			//	Note - registers in command space can be up to 32-bits wide (initial 256 bytes are only
			//		8-bits wide for simplicity) if you write to an address all the data goes to that
			//		one address - writing 32-bits to address 0x06 only writes 
			//		
			//	     - undefined registers should not be written to
			//
			//	0x00-03		VID - vendor id	byte 0 determines type:
			//				0: bytes 1-3 are a MAC-48 OUI
			//				1: byte 1 0 bytes 2-3 USB VID 
			//				2: byte 1 0 bytes 2-3 PCI VID 
			//				3-7f: - bytes 1-3 Quickbus registry
			//				0x80-ff: unregistered you choose something you hope is unique
			//	0x04-05		PID - product ID
			//	0x06		QuickBus version - this version '1'
			//	0x07		address sizes supported - bit mask
			//	0x08		data sizes supported - bit mask
			//	0x09		capabilities
			//				0: supports async reads (if not set upstream must wait for previous read
			//				   to complete, or an error before issuing a new one)
			//	0x10		Address
			//					7:	address not defined (set at reset)
			//					6:3 reserved 0
			//					2:0	address
			//
			//				all devices with address not defined set only respond to
			//				address 7 if the adress resolution daisy chain is asserted, if it's
			//				not set they respond to their programmed address
			//
			//	0x11		command
			//				7:	reset						asserted resets the chip
			//				6:	bus reset					asserted cause a quick_bus reset
			//				3:0	default address length		defaults to 4 on reset
			//	0x12		status		writing 1 to a bit here clears the bit, writing a 0 is ignored
			//				0:	error seen					
			//


			reg		 r_k, c_k;
			reg [7:0]r_d, c_d;
			reg		 r_req, c_req;
			assign xmt_k = r_k;
			assign xmt_in = r_d;
			assign xmt_ready = r_req;
			reg		 r_need_start, c_need_start;
			reg		 abort_read, start_read;

			//
			//	command space
			//

			reg [8:0]r_xaddr, c_xaddr;
			reg [7:0]r_xdata, c_xdata;
			reg		 r_write_back, c_write_back;
		

			reg	[2:0]r_addr, c_addr;
			reg		 r_addr_not_enabled, c_addr_not_enabled;
			always @(posedge clk10) begin
				r_addr <= c_addr;
				r_addr_not_enabled <= c_addr_not_enabled;
			end

			always @(*) begin
				c_addr = r_addr;
				c_addr_not_enabled = r_addr_not_enabled;
				if (!reset_n) begin
					c_addr_not_enabled = 1;
					c_addr = 3'bx;
				end else
				if (r_write_back && r_xaddr == 9'h10) begin
					c_addr_not_enabled = r_xaddr[7];
					c_addr = r_xaddr[2:0];
				end
			end

			
			reg  [7:0]r_ddd;
			always @(posedge clk10)
			if (r_write_back && r_xaddr == 9'h100) begin
				r_ddd <= r_xdata;
			end

			reg		 r_reset;
			always @(posedge clk10)
			if (!reset_n) begin
				r_reset <= 0;
			end else
			if (r_write_back && r_xaddr == 9'h10 && r_xdata[0]) begin
				r_reset <= 1;
			end else begin
				r_reset <= 0;
			end

			reg send_start, send_starta, send_end, send_zero;
			always @(*) begin
				c_k = send_start|send_starta|send_end;
/* verilator lint_off CASEOVERLAP */
				casez ({send_zero, send_start, send_starta, send_end}) // synthesis full_case parallel_case
				4'b1???:	c_d = 0;
				4'b?1??:	c_d = START;
				4'b??1?:	c_d = STARTA;
				4'b???1:	c_d = END;
				4'b0000:
					case(r_xaddr)
					9'h00:		c_d = 8'h50;
					9'h01:		c_d = 8'h61;
					9'h02:		c_d = 8'h75;
					9'h03:		c_d = 8'h6c;
					9'h04:		c_d = 8'h01;
					9'h05:		c_d = 8'h00;
					9'h06:		c_d = 8'h01;
					9'h07:		c_d = 8'h03;
					9'h08:		c_d = 8'h01;
					9'h10:		c_d = 0;
					9'h10:		c_d = {r_addr_not_enabled, 4'b0, r_addr};
					9'h100:		c_d = r_ddd;
					default:	c_d = 0;
					endcase
				endcase
/* verilator lint_on CASEOVERLAP */
			end

			reg [1:0]r_rstate, c_rstate;
			reg	     r_abort_read, c_abort_read;

			always @(*)
			if (!reset_n | r_reset) begin
				c_rstate = 0;
				c_need_start = 1;
				send_start = 0;
				send_starta = 0;
				send_end = 0;
				send_zero = 0;
				c_req = 0;
				c_abort_read = 0;
			end else begin
				send_start = 0;
				send_starta = 0;
				send_end = 0;
				send_zero = 0;
				c_req = 0;
				c_need_start = r_need_start;
				c_rstate = r_rstate;
				c_abort_read = r_abort_read|abort_read;
				case (r_rstate)
				0:	if (r_need_start) begin
							c_need_start = 0;
							send_start = 1;
							c_req = 1;
					end else
					if(start_read) begin
						c_req = 1;
						send_zero = 1;
						c_rstate = 1;
					end else
					if (r_abort_read) begin
						c_req = 1;
						send_starta = 1;
						c_rstate = 2;
						c_abort_read = 0;
					end
				1:  begin
						c_req = 1;
						c_rstate = 0;
					end
				2:  begin
						c_req = 1;
						send_zero = 1;
						c_rstate = 3;
					end
				3:  begin
						c_req = 1;
						send_end = 1;
						c_rstate = 0;
					end
				endcase
			end

			always @(posedge clk10) begin
				r_rstate <= c_rstate;
				r_need_start <= c_need_start;
				r_req <= c_req;
				r_k <= c_k;
				r_d <= c_d;
				r_abort_read <= c_abort_read;
			end

			//
			// this dumb device only supports byte accesses to command space

			reg [2:0]r_state, c_state;	
			reg		 r_addressed, c_addressed;
			reg		 r_read, c_read;
			reg		 r_addr_size, c_addr_size;
			localparam SEARCHING = 0;
			localparam BYTE_0 = 1;
			localparam BYTE_1 = 2;
			localparam ADDR_0 = 3;
			localparam ADDR_1 = 4;
			localparam DATA_0 = 5;
			localparam ERR    = 6;


			wire daisy_chain = 1;	// lone device at head of daisychain

			always @(*)
			if (!reset_n | r_reset) begin
				c_state = SEARCHING; 
				c_addressed = 0;
				start_read = 0;
				abort_read = 0;
				c_xaddr = 9'bx;
				c_xdata = 8'bx;
				c_write_back = 0;
				c_addr_size = 1'bx;
				c_read = 0;
			end else begin
				abort_read = 0;
				start_read = 0;
				c_state = r_state;
				c_read = r_read;
				c_addressed = r_addressed;
				c_xaddr = r_xaddr;
				c_xdata = r_xdata;
				c_write_back = 0;
				c_addr_size = r_addr_size;
				if (rcv_ready)
				case (r_state) 
				SEARCHING:	if (mgmt_ok && rcv_k && (rcv_out == START || rcv_out == END))
								c_state = BYTE_0;
				BYTE_0:		begin
								c_addressed = c_addr_not_enabled?(rcv_out[7:5] == 7 && daisy_chain):
															     (rcv_out[7:5] == c_addr);
								if (rcv_k) begin
									if (rcv_out == START || rcv_out == END) begin
										c_state = BYTE_0;
									end else begin
										c_state = ERR;
									end
								end else
								if (rcv_out[4]) begin
									c_state = ERR;
								end else
								case (rcv_out[3:1])
								0: c_state = ADDR_0;
								7: c_state = BYTE_1;
								default c_state = ERR;
								endcase
								c_addr_size = 0;
								c_read = rcv_out[0];
							end
				BYTE_1:		if (rcv_k) begin
								c_state = ERR;
							end else begin
								if (rcv_out == 8'b1_000_0000 || rcv_out == 8'b1_001_0000) begin
									c_addr_size = rcv_out[4];
									c_state = ADDR_0;
								end else begin
									c_state = ERR;
								end
							end
				ADDR_0:		if (rcv_k) begin
								c_state = ERR;
							end else begin
								c_xaddr = {1'b0, rcv_out};
								if (r_read&!r_addr_size) begin
									start_read = r_addressed;
									c_state = BYTE_0;
								end else begin
									c_state = (r_addr_size? ADDR_1:DATA_0);
								end
							end
				ADDR_1:		if (rcv_k) begin
								c_state = ERR;
							end else begin
								c_xaddr[8] = rcv_out[0];
								if (r_read) begin
									start_read = r_addressed;
									c_state = BYTE_0;
								end else begin
									c_state = DATA_0;
								end
							end
				DATA_0:		if (rcv_k) begin
								c_state = ERR;
							end else begin
								c_xdata = rcv_out;
								c_write_back = r_addressed;
								c_state = BYTE_0;
							end
				
				ERR:		begin
								abort_read = r_addressed;
								c_state = BYTE_0;
							end
								
				default:;
				endcase
			end

			always @(posedge clk10) begin
				r_state <= c_state;
				r_addressed <= c_addressed;
				r_read <= c_read;
				r_xaddr <= c_xaddr;
				r_xdata <= c_xdata;
				r_write_back <= c_write_back;
				r_addr_size <= c_addr_size;
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
