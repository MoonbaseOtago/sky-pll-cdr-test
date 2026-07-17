//
//	(C) Paul Campbell 2026
//	All Rights Reserved
//


//
//	standard LFSR for input and output scrambling
//

module lfsr8b10b(input clk, input rst, input shift, output [7:0]out);

	reg [15:0]r_lfsr;
	assign out = {r_lfsr[8],r_lfsr[9],r_lfsr[10],r_lfsr[11],r_lfsr[12],r_lfsr[13],r_lfsr[14],r_lfsr[15]};

	wire [15:0]lfsr0 = {r_lfsr[14:0], r_lfsr[15]} ^ {10'h0,r_lfsr[15],r_lfsr[15],r_lfsr[15],3'h0};
	wire [15:0]lfsr1 = {lfsr0[14:0], lfsr0[15]} ^ {10'h0,lfsr0[15],lfsr0[15],lfsr0[15],3'h0};
	wire [15:0]lfsr2 = {lfsr1[14:0], lfsr1[15]} ^ {10'h0,lfsr1[15],lfsr1[15],lfsr1[15],3'h0};
	wire [15:0]lfsr3 = {lfsr2[14:0], lfsr2[15]} ^ {10'h0,lfsr2[15],lfsr2[15],lfsr2[15],3'h0};
	wire [15:0]lfsr4 = {lfsr3[14:0], lfsr3[15]} ^ {10'h0,lfsr3[15],lfsr3[15],lfsr3[15],3'h0};
	wire [15:0]lfsr5 = {lfsr4[14:0], lfsr4[15]} ^ {10'h0,lfsr4[15],lfsr4[15],lfsr4[15],3'h0};
	wire [15:0]lfsr6 = {lfsr5[14:0], lfsr5[15]} ^ {10'h0,lfsr5[15],lfsr5[15],lfsr5[15],3'h0};
	wire [15:0]lfsr7 = {lfsr6[14:0], lfsr6[15]} ^ {10'h0,lfsr6[15],lfsr6[15],lfsr6[15],3'h0};

	always @(posedge clk)
	if (rst) begin
		r_lfsr <= 16'hffff;
	end else
	if (shift) begin
		r_lfsr <=  lfsr7;
`ifdef TESTLFSR
		$displayh("lfsr=",lfsr7);
`endif
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
