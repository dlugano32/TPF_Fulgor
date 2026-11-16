# Tasa de linea: 800 Gb/s = 889*f_FEC = 1016*f_DSP.
set PERIOD_FEC 1.11125
set PERIOD_DSP 1.27

create_clock -period $PERIOD_FEC -name i_clk_fec [get_ports i_clk_fec]
create_clock -period $PERIOD_DSP -name i_clk_dsp [get_ports i_clk_dsp]
set_clock_groups -asynchronous -group [get_clocks i_clk_fec] -group [get_clocks i_clk_dsp]

set_clock_uncertainty -setup 0.01 [get_clocks i_clk_fec]
set_clock_uncertainty -setup 0.01 [get_clocks i_clk_dsp]

# I/O separados por dominio
set FEC_INPUTS  [get_ports {i_en i_seed*}]
set DSP_INPUTS  [get_ports {i_dsp_line* i_dsp_valid}]
set FEC_OUTPUTS [get_ports {o_payload* o_locked o_error_count* o_valid}]
set DSP_OUTPUTS [get_ports {o_dsp_line* o_dsp_valid}]

foreach {clock period inputs outputs} [list \
        i_clk_fec $PERIOD_FEC $FEC_INPUTS $FEC_OUTPUTS \
        i_clk_dsp $PERIOD_DSP $DSP_INPUTS $DSP_OUTPUTS] {
    set delay [expr {$period * 0.10}]
    if {[sizeof_collection $inputs] > 0} {
        set_input_delay -clock $clock -max $delay $inputs
        set_input_delay -clock $clock -min 0.0 $inputs
    }
    if {[sizeof_collection $outputs] > 0} {
        set_output_delay -clock $clock -max $delay $outputs
        set_output_delay -clock $clock -min 0.0 $outputs
    }
}

# Reset asincrono
set_false_path -from [get_ports i_arst_n]

set DATA_INPUTS [remove_from_collection [all_inputs] [get_ports {i_clk_fec i_clk_dsp}]]
set_input_transition 0.01 $DATA_INPUTS
set_clock_transition 0.01 [get_clocks {i_clk_fec i_clk_dsp}]
set_max_transition 0.15 [current_design]
set_max_fanout 16 [current_design]
set_load 0.02 [all_outputs]
