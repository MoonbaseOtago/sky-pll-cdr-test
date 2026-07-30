/*
 * Copyright (c) 2026 Paul Campbell
 * SPDX-License-Identifier: Apache-2.0
 */


`timescale 1ns/1ps


`default_nettype none

module test;


	reg [7:0]ui_in, uio_in;
	wire [7:0]uio_out, uio_oe, uo_out;
	wire ena=1;
	reg clk, rst_n;

	tt_um_quick_bus qb(.clk(clk), .ena(ena), .rst_n(rst_n), 
			.ui_in(ui_in), .uio_in(uio_in), .uio_out(uio_out), .uio_oe(uio_oe), .uo_out(uo_out));

	initial begin
		$dumpvars;
		#30000000;
		$finish;
	end

	initial begin
		clk = 0;
		forever #20 clk = ~clk;
	end

	wire up_clk = uio_out[5];
	wire up_ready = uio_out[3];

	reg need_start=1;

	task write_reg(input [2:0]c, input[7:0]a, input[7:0]d);
	begin
		uio_in[7:6] <= 2'b11;
		if (need_start) begin
			need_start <=0;
			uio_in[0] <= 1;
			ui_in <= 8'hfb;
			 uio_in[3] <=  ~uio_in[3];
			@(posedge uio_out[5]);
		end
		uio_in[0] <= 0;
		ui_in <= {c, 1'b0, 3'b000, 1'b0};	// byte write to command reg
		uio_in[3] <=  ~uio_in[3];
		@(posedge uio_out[5]);
		uio_in[0] <= 0;
		ui_in <= a;						
		uio_in[3] <=  ~uio_in[3];
		@(posedge uio_out[5]);
		uio_in[0] <= 0;
		ui_in <= d;						
		uio_in[3] <=  ~uio_in[3];
		@(posedge uio_out[5]);
	end
	endtask

	task write_reg2(input [2:0]c, input[15:0]a, input[7:0]d);
	begin
		uio_in[7:6] <= 2'b11;
		if (need_start) begin
			need_start <=0;
			uio_in[0] <= 1;
			ui_in <= 8'hfb;
			 uio_in[3] <=  ~uio_in[3];
			@(posedge uio_out[5]);
		end
		uio_in[0] <= 0;
		ui_in <= {c, 1'b0, 3'b111, 1'b0};	// byte write to command reg
		uio_in[3] <=  ~uio_in[3];
		@(posedge uio_out[5]);
		uio_in[0] <= 0;
		ui_in <= {1'b1, 3'b1, 4'b0};						
		uio_in[3] <=  ~uio_in[3];
		@(posedge uio_out[5]);
		uio_in[0] <= 0;
		ui_in <= a[7:0];						
		uio_in[3] <=  ~uio_in[3];
		@(posedge uio_out[5]);
		uio_in[0] <= 0;
		ui_in <= a[15:8];						
		uio_in[3] <=  ~uio_in[3];
		@(posedge uio_out[5]);
		uio_in[0] <= 0;
		ui_in <= d;						
		uio_in[3] <=  ~uio_in[3];
		@(posedge uio_out[5]);
	end
	endtask

	task read_data(output [7:0]r);
	begin
		while (!uio_out[2])
			@(posedge uio_out[5]);
		while (uio_out[1]) begin	// skip begin/end symbols
			@(posedge uio_out[5]);
			while (!uio_out[2])
				@(posedge uio_out[5]);
		end
		// ignore tag
		@(posedge uio_out[5]);
		while (!uio_out[2])
			@(posedge uio_out[5]);
		if (uio_out[1]) begin
			$display("rcv err");
		end else begin
			r = uo_out;
		end
	end
	endtask

	task read_reg(input [2:0]c, input[7:0]a, output[7:0]r);
	begin
		uio_in[7:6] <= 2'b11;
		if (need_start) begin
			need_start <=0;
			uio_in[0] <= 1;
			ui_in <= 8'hfb;
			 uio_in[3] <=  ~uio_in[3];
			@(posedge uio_out[5]);
		end
		uio_in[0] <= 0;
		ui_in <= {c, 1'b0, 3'b000, 1'b1};	// byte read to command reg
		uio_in[3] <=  ~uio_in[3];
		@(posedge uio_out[5]);
		uio_in[0] <= 0;
		ui_in <= a;						
		uio_in[3] <=  ~uio_in[3];
		@(posedge uio_out[5]);
		read_data(r);
	end
	endtask

	task read_reg2(input [2:0]c, input[15:0]a, output[7:0]r);
	begin
		uio_in[7:6] <= 2'b11;
		if (need_start) begin
			need_start <=0;
			uio_in[0] <= 1;
			ui_in <= 8'hfb;
			 uio_in[3] <=  ~uio_in[3];
			@(posedge uio_out[5]);
		end
		uio_in[0] <= 0;
		ui_in <= {c, 1'b0, 3'b111, 1'b1};	// byte write to command reg
		uio_in[3] <=  ~uio_in[3];
		@(posedge uio_out[5]);
		uio_in[0] <= 0;
		ui_in <= {1'b1, 3'b1, 4'b0};						
		uio_in[3] <=  ~uio_in[3];
		@(posedge uio_out[5]);
		uio_in[0] <= 0;
		ui_in <= a[7:0];						
		uio_in[3] <=  ~uio_in[3];
		@(posedge uio_out[5]);
		uio_in[0] <= 0;
		ui_in <= a[15:8];						
		uio_in[3] <=  ~uio_in[3];
		@(posedge uio_out[5]);
		read_data(r);
	end
	endtask

	localparam REG_TEST =1;
	reg [7:0]r;
	initial begin
		if (!REG_TEST) begin
			// test for simple pll interface
			//		ui_in = {2'b00, 2'b0, 4'h3};
			//		uio_in = {2'b00, 2'b0, 4'h0};
			// speedbus
			
			//ui_in <= {2'b01, 2'b0, 1'b0, 3'h1};		// come up at 100MHz
			//ui_in <= {2'b01, 2'b0, 1'b0, 3'h2};		// come up at 100MHz, try 200MHz
			//ui_in <= {2'b01, 1'b1, 1'b0, 1'b0, 3'h3};	// come up at 100MHz, try 300MHz force prog failures
			//ui_in <= {2'b01, 1'b1, 1'b0, 1'b1, 3'h3};	// come up at 100MHz, try 300MHz force prog failures and speed failures
			//ui_in <= {2'b01, 1'b0, 1'b1, 1'b0, 3'h3};	// come up at 100MHz, try 300MHz force rev failures
			ui_in <= {2'b10, 1'b0, 1'b0, 1'b0, 3'h3};	// come up at 100MHz, try 300MHz send data from down to up
	
			uio_in <= {2'b01, 2'b0, 4'h0};
			
			rst_n <= 1;
			#1;
			rst_n <= 0;
			@(posedge clk);
			@(posedge clk);
			@(posedge clk);
			@(posedge clk);
			@(posedge clk);
			@(posedge clk);
			rst_n <= 1;
		end else begin
			ui_in <= {2'b11, 1'b0, 1'b0, 1'b0, 3'h3};	// come up at 100MHz, try 300MHz register mode
			uio_in <= {2'b00, 2'b0, 4'h0};
			
			rst_n <= 1;
			#1;
			rst_n <= 0;
			@(posedge clk);
			@(posedge clk);
			@(posedge clk);
			@(posedge clk);
			@(posedge clk);
			@(posedge clk);
			rst_n <= 1;
			@(posedge clk);
			@(posedge clk);
			@(posedge clk);
			@(posedge clk);
			@(posedge clk);
			@(posedge clk);
			@(posedge clk);
			@(posedge clk);
			@(posedge clk);
			@(posedge clk);
			@(posedge uio_out[2]);  // wait for upstream mangament to go up
			@(posedge uio_out[5]);	// wait a few clocks
			@(posedge uio_out[5]);
			@(posedge uio_out[5]);
			@(posedge uio_out[5]);
			write_reg(7, 8'h10, 0);	// set address to 0
			write_reg2(0, 16'h100, 8'h55);	// write 55 to per-device register
			read_reg(0, 0, r);
			$display("%c", r);
			read_reg(0, 1, r);
			$display("%c", r);
			read_reg(0, 2, r);
			$display("%c", r);
			read_reg(0, 3, r);
			$display("%c", r);
			read_reg2(0, 16'h100, r);
			$display("%h", r);
			@(posedge uio_out[5]);
			@(posedge uio_out[5]);
			@(posedge uio_out[5]);
			@(posedge uio_out[5]);
			@(posedge uio_out[5]);
			@(posedge uio_out[5]);
			@(posedge uio_out[5]);
			@(posedge uio_out[5]);
			@(posedge uio_out[5]);
			@(posedge uio_out[5]);
			@(posedge uio_out[5]);
			@(posedge uio_out[5]);
			@(posedge uio_out[5]);
			@(posedge uio_out[5]);
			@(posedge uio_out[5]);
			@(posedge uio_out[5]);
			@(posedge uio_out[5]);
			@(posedge uio_out[5]);
			@(posedge uio_out[5]);
			@(posedge uio_out[5]);
			@(posedge uio_out[5]);
			@(posedge uio_out[5]);
			@(posedge uio_out[5]);
			@(posedge uio_out[5]);
			@(posedge uio_out[5]);
			@(posedge uio_out[5]);
			$finish;
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

