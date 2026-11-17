#-------------------------------------------------------------------------------
# 1. Parameters
#-------------------------------------------------------------------------------
# Tasa de linea: 800 Gb/s = 889*f_FEC = 1016*f_DSP.
set PERIOD_FEC 1.11125
set PERIOD_DSP 1.27

set IO_MARGIN   0.10    ;# 10% para el mundo externo
set UNCERT_SU   0.05    ;# 5%  jitter + skew (setup)
set UNCERT_HD   0.02    ;# 20 ps, absoluto (hold)
set TRAN_IN     0.03    ;# 3% del periodo para slew de entrada y reloj ideal
set MAX_TRAN    0.10    ;# slew maximo interno
set MAX_FANOUT  16
set MAX_CAP     0.050   ;# pF
set OUT_LOAD    0.020   ;# pF, carga que ve la salida

#-------------------------------------------------------------------------------
# 2. CLOCK
#-------------------------------------------------------------------------------
create_clock -period $PERIOD_FEC -name i_clk_fec [get_ports i_clk_fec]
create_clock -period $PERIOD_DSP -name i_clk_dsp [get_ports i_clk_dsp]
set_clock_groups -asynchronous -group [get_clocks i_clk_fec] -group [get_clocks i_clk_dsp]

# Jitter del PLL mas el skew que el arbol de reloj va a introducir.
set_clock_uncertainty -setup [expr {$UNCERT_SU * $PERIOD_FEC}] [get_clocks i_clk_fec]
set_clock_uncertainty -hold  $UNCERT_HD [get_clocks i_clk_fec]

set_clock_uncertainty -setup [expr {$UNCERT_SU * $PERIOD_DSP}] [get_clocks i_clk_dsp]
set_clock_uncertainty -hold  $UNCERT_HD [get_clocks i_clk_dsp]

# En sintesis el reloj es ideal, asi que le damos un slew representativo.
set_clock_transition [expr {$TRAN_IN * $PERIOD_FEC}] [get_clocks i_clk_fec]
set_clock_transition [expr {$TRAN_IN * $PERIOD_DSP}] [get_clocks i_clk_dsp]

set_ideal_network -no_propagate [get_ports {i_clk_fec i_clk_dsp}]

#-------------------------------------------------------------------------------
# 3. I/O separados por dominio
#-------------------------------------------------------------------------------

set FEC_INPUTS  [get_ports {i_en i_seed*}]
set DSP_INPUTS  [get_ports {i_dsp_line* i_dsp_valid}]
set FEC_OUTPUTS [get_ports {o_payload* o_locked o_error_count* o_valid}]
set DSP_OUTPUTS [get_ports {o_dsp_line* o_dsp_valid}]

foreach {clock period inputs outputs} [list \
        i_clk_fec $PERIOD_FEC $FEC_INPUTS $FEC_OUTPUTS \
        i_clk_dsp $PERIOD_DSP $DSP_INPUTS $DSP_OUTPUTS] {
    set delay [expr {$period * $IO_MARGIN}]
    if {[sizeof_collection $inputs] > 0} {
        set_input_delay -clock $clock -max $delay $inputs
        set_input_delay -clock $clock -min 0.0 $inputs
    }
    if {[sizeof_collection $outputs] > 0} {
        set_output_delay -clock $clock -max $delay $outputs
        set_output_delay -clock $clock -min 0.0 $outputs
    }
}

set_input_transition [expr {$TRAN_IN * $PERIOD_FEC}] $FEC_INPUTS
set_input_transition [expr {$TRAN_IN * $PERIOD_DSP}] $DSP_INPUTS

set_max_transition  $MAX_TRAN   [current_design]
set_max_fanout      $MAX_FANOUT [current_design]
set_max_capacitance $MAX_CAP    [current_design]

set_load $OUT_LOAD [all_outputs]

# Reset asincrono
set_false_path -from [get_ports i_arst_n]
set_ideal_network [get_ports i_arst_n]
set_max_fanout 32 [get_ports i_arst_n]