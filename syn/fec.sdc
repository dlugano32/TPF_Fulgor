set PERIOD_FEC 1.11125  ;# 800 Gb/s = 889*f_FEC
set CLK_NAME    i_clk_fec
set CLK_PORT    i_clk
set RST_PORT    i_rst_n  ;# Reset sincrono del encoder; incluido en FEC_INPUTS

# Los porcentajes se convierten a ns aqui; los comandos usan esos valores directamente.
set IO_MARGIN   [expr {$PERIOD_FEC * 0.10}]          ;# 10% para el mundo externo
set UNCERT_SU   [expr {$PERIOD_FEC * 0.05}]          ;# 5%  jitter + skew (setup)
set UNCERT_HD   0.020                            ;# 20 ps, absoluto (hold)
set TRAN_IN     [expr {$PERIOD_FEC * 0.03}]          ;# slew de entrada
set MAX_TRAN    [expr {$PERIOD_FEC * 0.10}]          ;# slew maximo interno
set MAX_FANOUT  16
set MAX_CAP     0.050                            ;# pF
set OUT_LOAD    0.020                            ;# pF, carga que ve la salida

create_clock -period $PERIOD_FEC -name $CLK_NAME [get_ports $CLK_PORT]
set_clock_uncertainty -setup $UNCERT_SU [get_clocks $CLK_NAME]
set_clock_uncertainty -hold $UNCERT_HD [get_clocks $CLK_NAME]
set_clock_transition $TRAN_IN [get_clocks $CLK_NAME]
set_ideal_network -no_propagate [get_ports $CLK_PORT]

set FEC_INPUTS  [remove_from_collection [all_inputs] [get_ports $CLK_PORT]]
set FEC_OUTPUTS [all_outputs]

set_input_delay -clock $CLK_NAME -max $IO_MARGIN $FEC_INPUTS
set_input_delay -clock $CLK_NAME -min 0.0 $FEC_INPUTS
set_output_delay -clock $CLK_NAME -max $IO_MARGIN $FEC_OUTPUTS
set_output_delay -clock $CLK_NAME -min 0.0 $FEC_OUTPUTS
set_input_transition $TRAN_IN $FEC_INPUTS

set_max_transition $MAX_TRAN [current_design]
set_max_fanout $MAX_FANOUT [current_design]
set_max_capacitance $MAX_CAP [current_design]
set_load $OUT_LOAD $FEC_OUTPUTS
