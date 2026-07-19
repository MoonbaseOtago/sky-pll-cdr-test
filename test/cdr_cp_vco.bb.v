/*                  
 * Copyright (c) 2026 Paul Campbell
 * SPDX-License-Identifier: Apache-2.0
 */                 
         
module cdr_cp_vco(input RESET,
`ifdef GL_TEST
		  inout VPWR, inout VGND,
`endif
                  input UP_N, input DOWN_N,
                  output CLKI, output CLKI_N,
                  output CLKQ, output CLKQ_N);

`ifdef SYS_TEST
    parameter LARGE_UPD = 1;
    parameter LARGE_DOWND = 1;
    parameter MID_UPD   = 1;
    parameter MID_DOWND = 1;
    parameter SMALL_DOWND = 1;
    parameter SMALL_UPD = 1;
    parameter INITD = 100000000;    // 100 nS/ 10 MHz
    parameter TC=500;
    reg[31:0]rdelay=INITD;
    wire[31:0]delay=INITD-rdelay;
    wire [63:0]freq = 1000000000/(2*rdelay);

    reg clkq, clki;
    assign CLKI = clki;
    assign CLKQ = clkq;
    assign CLKI_N = ~clki;
    assign CLKQ_N = ~clkq;
    // CP
    initial begin
        forever begin
            if (RESET) begin
                rdelay = INITD;
            end else begin
                if (!DOWN_N)
                    if (rdelay < INITD) rdelay = rdelay + LARGE_DOWND;
                if (!UP_N)
                    if (rdelay > LARGE_UPD) rdelay = rdelay - LARGE_UPD;
            end
            #TC;
        end
    end

    // VCO
    initial begin
        clki = 0;
        clkq = 0;
        #1;
        forever begin
            #(rdelay/2);
            clki = ~clki;
            #(rdelay/2);
            clkq = ~clkq;

        end
    end
`endif
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
         

