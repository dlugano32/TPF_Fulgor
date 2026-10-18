package prbs31_tb_pkg;

    import prbs31_pkg::*;

    typedef bit [ORDER - 1 : 0] seed_t;
    typedef bit [P - 1 : 0]     prbs_t;

    import "DPI-C" function void prbs31_reset_dpi(input seed_t seed);
    import "DPI-C" function void prbs31_gen_dpi(output prbs_t output_bits);

    `include "prbs31_txn.sv"
    `include "prbs31_gen.sv"
    `include "prbs31_drv.sv"
    `include "prbs31_mon.sv"
    `include "prbs31_scb.sv"
    `include "prbs31_env.sv"

endpackage : prbs31_tb_pkg
