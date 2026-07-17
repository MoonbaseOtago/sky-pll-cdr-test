# Shared constants, copied from  base.sdc  
set input_delay_value [ expr $::env(CLOCK_PERIOD) * $::env(IO_PCT) ]
set output_delay_value [ expr $::env(CLOCK_PERIOD) * $::env(IO_PCT) ]
set_max_fanout $::env(MAX_FANOUT_CONSTRAINT) [ current_design ]
set cap_load [ expr $::env(OUTPUT_CAP_LOAD) / 1000.0 ] ;# fF -> pF

# Remove clock net from inputs
set idx [ lsearch [ all_inputs ] "CLK" ]
set all_inputs_wo_clk [ lreplace [ all_inputs ] $idx $idx ]


#create_clock [ get_ports "CLKI" ]    -name CLKI   -waveform {0       1.66667} -period 3.33333
#create_clock [ get_ports "CLKI_N" ]  -name CLKI_N -waveform {1.66667 3.33333} -period 3.33333
#create_clock [ get_ports "CLKQ" ]    -name CLKQ   -waveform {0.83325 2.49975} -period 3.33333
#create_clock [ get_ports "CLKQ_N" ]  -name CLKQ_N -waveform {2.49975 4.16641} -period 3.33333
create_clock [ get_ports "CLKI" ]    -name CLKI   -waveform {0 2} -period 4
create_clock [ get_ports "CLKI_N" ]  -name CLKI_N -waveform {2 4} -period 4
create_clock [ get_ports "CLKQ" ]    -name CLKQ   -waveform {1 3} -period 4
create_clock [ get_ports "CLKQ_N" ]  -name CLKQ_N -waveform {3 5} -period 4
#set_clock_uncertainty $::env(SYNTH_CLOCK_UNCERTAINTY) [ get_clocks CLKI ]
#set_clock_transition $::env(SYNTH_CLOCK_TRANSITION) [ get_clocks CLKI ]
#set_clock_uncertainty $::env(SYNTH_CLOCK_UNCERTAINTY) [ get_clocks CLKI_N ]
#set_clock_transition $::env(SYNTH_CLOCK_TRANSITION) [ get_clocks CLKI_N ]
#set_clock_uncertainty $::env(SYNTH_CLOCK_UNCERTAINTY) [ get_clocks CLKQ ]
#set_clock_transition $::env(SYNTH_CLOCK_TRANSITION) [ get_clocks CLKQ ]
#set_clock_uncertainty $::env(SYNTH_CLOCK_UNCERTAINTY) [ get_clocks CLKQ_N ]
#set_clock_transition $::env(SYNTH_CLOCK_TRANSITION) [ get_clocks CLKQ_N ]

set_multicycle_path 3 -from { "DO*" "XMT_READY" "XMT_RD"  } -to CLKI
set_multicycle_path 3 -from { "DO.*" "XMT_READY" "XMT_RD" } -to CLKI_N
set_multicycle_path 3 -from { "DO.*" "XMT_READY" "XMT_RD" } -to CLKQ
set_multicycle_path 3 -from { "DO.*" "XMT_READY" "XMT_RD" } -to CLKQ_N
set_multicycle_path 2 -from CLKI -to [ all_outputs ]
set_multicycle_path 2 -from CLKI_N -to [ all_outputs ]
set_multicycle_path 2 -from CLKQ -to [ all_outputs ]
set_multicycle_path 2 -from CLKQ_N -to [ all_outputs ]

# Miscellanea
set_driving_cell -lib_cell $::env(SYNTH_DRIVING_CELL) -pin $::env(SYNTH_DRIVING_CELL_PIN) $all_inputs_wo_clk
set_load  $cap_load [ all_outputs ]
set_timing_derate -early [ expr {1-$::env(SYNTH_TIMING_DERATE)} ]
set_timing_derate -late [ expr {1+$::env(SYNTH_TIMING_DERATE)} ]


# end


