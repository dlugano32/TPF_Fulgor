package bch_encoder_tb_pkg;

    import bch_encoder_pkg::*;

    typedef bit [K - 1 : 0] msg_t;
    typedef bit [N - 1 : 0] cw_t;

    import "DPI-C" function void bch_encode_dpi(input msg_t message, output cw_t codeword);

    `include "bch_encoder_txn.sv"
    `include "bch_encoder_gen.sv"
    `include "bch_encoder_drv.sv"
    `include "bch_encoder_mon.sv"
    `include "bch_encoder_scb.sv"
    `include "bch_encoder_env.sv"

endpackage : bch_encoder_tb_pkg
