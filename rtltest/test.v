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
		#100000000;
		$finish;
	end

	initial begin
		clk = 0;
		forever #20 clk = ~clk;
	end

	initial begin
		// test for simple pll interface
		//		ui_in = {2'b00, 2'b0, 4'h3};
		//		uio_in = {2'b00, 2'b0, 4'h0};
		// speedbus
				//ui_in <= {2'b01, 2'b0, 1'b0, 3'h1};		// come up at 100MHz
				//ui_in <= {2'b01, 2'b0, 1'b0, 3'h2};		// come up at 100MHz, try 200MHz
				ui_in <= {2'b01, 2'b0, 1'b0, 3'h3};		// come up at 100MHz, try 300MHz
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

