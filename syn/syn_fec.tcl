###############################################################################
# Sintesis SAED14 con Fusion Compiler
###############################################################################

set TOP $::env(TOP)
if {[info exists ::env(TOP)]} {set TOP $::env(TOP)}
if {![info exists ::env(LIB_BASE)]} {
    error "Definir LIB_BASE con la ruta a las librerias SAED14"
}
set LIB_BASE [file normalize $::env(LIB_BASE)]
set PROJ_ROOT [file normalize [file join [file dirname [info script]] ../../]]

# PVT incluidos en los NDM frame_timing y en los archivos .db de SAED14.
set SLOW_PVT ss0p72v125c
set FAST_PVT ff0p88vm40c
set PVT_LIBRARY saed14rvt_base_frame_timing

set OUT_DIR [file join $PROJ_ROOT syn outputs]
set REPORT_DIR [file join $OUT_DIR reports]
file mkdir $REPORT_DIR

###############################################################################
# Librerias fisicas y de timing: HVT/RVT/LVT/SLVT, base + clock gating
###############################################################################
set REF_NDMS [list]
set SLOW_DBS [list]
set FAST_DBS [list]
foreach flavor {hvt rvt lvt slvt} {
    foreach family {base cg} {
        set name saed14${flavor}_${family}
        lappend REF_NDMS [file join $LIB_BASE ndm ${name}_frame_timing.ndm]
        lappend SLOW_DBS [file join $LIB_BASE db ${name}_${SLOW_PVT}.db]
        lappend FAST_DBS [file join $LIB_BASE db ${name}_${FAST_PVT}.db]
    }
}
set target_library [concat $SLOW_DBS $FAST_DBS]
set link_library [concat "*" $target_library]

set TECH_FILE [file join $LIB_BASE physical saed14nm_1p9m_mw.tf]
set LAYER_MAP [file join $LIB_BASE physical saed14nm_tf_itf_tluplus.map]
set CMAX_FILE [file join $LIB_BASE physical saed14nm_1p9m_Cmax.tlup]
set CMIN_FILE [file join $LIB_BASE physical saed14nm_1p9m_Cmin.tlup]

###############################################################################
# Fuentes RTL
###############################################################################
set RTL_FILES [list \
    ${PROJ_ROOT}/rtl/bch_decoder_pkg.sv \
    ${PROJ_ROOT}/rtl/bch_mult_m.sv \
    ${PROJ_ROOT}/rtl/bch_syndrome.sv \
    ${PROJ_ROOT}/rtl/gf127_op/gf127_log_lut.sv \
    ${PROJ_ROOT}/rtl/gf127_op/gf127_exp_lut.sv \
    ${PROJ_ROOT}/rtl/gf127_op/gf127_cube_lut.sv \
    ${PROJ_ROOT}/rtl/bch_mu_calculator.sv \
    ${PROJ_ROOT}/rtl/bch_omega_calculator.sv \
    ${PROJ_ROOT}/rtl/bch_root_calculator.sv \
    ${PROJ_ROOT}/rtl/bch_decoder.sv
]

set SDC_FILE $PROJ_ROOT/syn/inputs/$TOP.sdc

foreach path [concat $REF_NDMS $target_library $RTL_FILES \
        [list $TECH_FILE $LAYER_MAP $CMAX_FILE $CMIN_FILE $SDC_FILE]] {
    if {![file exists $path]} {
        error "No existe el archivo o libreria requerido: $path"
    }
}

###############################################################################
# Libreria de trabajo independiente por top. Se recrea en cada corrida.
###############################################################################
cd $OUT_DIR
if {[get_libs -quiet ${TOP}.nlib] ne ""} {close_lib ${TOP}.nlib}
if {[file exists ${TOP}.nlib]} {file delete -force ${TOP}.nlib}
create_lib ${TOP}.nlib -technology $TECH_FILE -ref_libs $REF_NDMS

analyze -format sverilog $RTL_FILES
elaborate $TOP
set_top_module $TOP

###############################################################################
# Dos corners y dos escenarios funcionales sobre la misma netlist
###############################################################################
read_parasitic_tech -tlup $CMAX_FILE -layermap $LAYER_MAP -name Cmax
read_parasitic_tech -tlup $CMIN_FILE -layermap $LAYER_MAP -name Cmin

create_mode functional
foreach {corner pvt rc} [list slow $SLOW_PVT Cmax fast $FAST_PVT Cmin] {
    create_corner $corner
    current_corner $corner
    set_parasitic_parameters -late_spec $rc -early_spec $rc -corner $corner
    set_operating_conditions -library $PVT_LIBRARY $pvt

    create_scenario -name func_$corner -mode functional -corner $corner
    current_scenario func_$corner
    source $SDC_FILE
    set_scenario_status func_$corner -active true -setup true -hold true -leakage_power true -dynamic_power true
}

###############################################################################
# Sintesis y reportes
###############################################################################
compile_fusion

current_scenario func_slow
report_units > $REPORT_DIR/units.rpt
report_scenarios > $REPORT_DIR/scenarios.rpt
report_area > $REPORT_DIR/area.rpt
report_clock_gating > $REPORT_DIR/clock_gating.rpt
report_threshold_voltage_groups > $REPORT_DIR/vt_groups.rpt
report_pvt > $REPORT_DIR/pvt.rpt
check_timing > $REPORT_DIR/check_timing.rpt
report_timing -delay_type max -max_paths 20 -significant_digits 6 > $REPORT_DIR/setup.rpt
report_timing -delay_type min -max_paths 20 -significant_digits 6 > $REPORT_DIR/hold.rpt
report_qor -significant_digits 6 > $REPORT_DIR/qor.rpt

# Potencia y exportaciones se generan en el escenario de cada corner.
foreach corner {slow fast} {
    current_scenario func_$corner
    report_power > $REPORT_DIR/power_${corner}.rpt
    write_sdf $OUT_DIR/${TOP}_${corner}.sdf
    write_sdc -output $OUT_DIR/${TOP}_${corner}.sdc
}

current_scenario func_slow
write_verilog $OUT_DIR/${TOP}_netlist.v
save_lib

set run_file [open $OUT_DIR/run_conditions.rpt w]
puts $run_file "TOP=$TOP"
puts $run_file "LIB_BASE=$LIB_BASE"
puts $run_file "SDC=$SDC_FILE"
puts $run_file "FEC_PERIOD=$PERIOD_FEC ns; clock=$CLK_NAME; puerto=$CLK_PORT"
puts $run_file "IO_MARGIN=$IO_MARGIN ns; UNCERT_SU=$UNCERT_SU ns; UNCERT_HD=$UNCERT_HD ns"
puts $run_file "TRAN_IN=$TRAN_IN ns; MAX_TRAN=$MAX_TRAN ns; MAX_FANOUT=$MAX_FANOUT"
puts $run_file "MAX_CAP=$MAX_CAP pF; OUT_LOAD=$OUT_LOAD pF"
puts $run_file "Reset sincrono $RST_PORT con timing de entrada; sin false paths."
puts $run_file "slow=$SLOW_PVT + Cmax; fast=$FAST_PVT + Cmin"
puts $run_file "Setup y hold en ambos escenarios; sin exclusiones de clock gating ni data gating."
close $run_file

echo "=== Sintesis $TOP SAED14 completa: $OUT_DIR ==="