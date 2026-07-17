# Shared constants, copied from  base.sdc  
set input_delay_value [ expr $::env(CLOCK_PERIOD) * $::env(IO_PCT) ]
set output_delay_value [ expr $::env(CLOCK_PERIOD) * $::env(IO_PCT) ]
set_max_fanout $::env(MAX_FANOUT_CONSTRAINT) [ current_design ]
set cap_load [ expr $::env(OUTPUT_CAP_LOAD) / 1000.0 ] ;# fF -> pF

# Remove clock net from inputs
set idx [ lsearch [ all_inputs ] "CLK" ]
set all_inputs_wo_clk [ lreplace [ all_inputs ] $idx $idx ]

create_clock [ get_ports "CLK" ]  -name CLK -period 3.333



create_clock [ get_ports "CLK10" ]    -name CLK10   -waveform {0 10} -period 20

set_multicycle_path 3 -from { "DO*" "XMT_READY" "XMT_RD"  } -to CLK
set_multicycle_path 2 -from CLK -to [ all_outputs ]

# Miscellanea
set_driving_cell -lib_cell $::env(SYNTH_DRIVING_CELL) -pin $::env(SYNTH_DRIVING_CELL_PIN) $all_inputs_wo_clk
set_load  $cap_load [ all_outputs ]
set_timing_derate -early [ expr {1-$::env(SYNTH_TIMING_DERATE)} ]
set_timing_derate -late [ expr {1+$::env(SYNTH_TIMING_DERATE)} ]

set_false_path -from [ get_ports "DIN" ]
set_false_path -from [ get_ports "REV" ]


# end


