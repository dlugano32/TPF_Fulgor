package bch_decoder_tb_pkg;

    import bch_decoder_pkg::*;

    typedef bit [K - 1 : 0] msg_t;
    typedef bit [N - 1 : 0] cw_t;

    localparam msg_t BASE_MESSAGE = 113'h172B4D65C6E047DB1ABAB1B51C34C;
    localparam cw_t  BASE_CODEWORD = 127'h5CAD35971B811F6C6AEAC6D470D31D02;

    import "DPI-C" function void bch_decode_dpi(
        input  cw_t  received,
        output cw_t  error,
        output cw_t  codeword,
        output msg_t message,
        output bit   corrected,
        output bit   uncorrectable
    );

    `include "bch_decoder_txn.sv"
    `include "bch_decoder_gen.sv"
    `include "bch_decoder_drv.sv"
    `include "bch_decoder_mon.sv"
    `include "bch_decoder_scb.sv"
    `include "bch_decoder_env.sv"

endpackage : bch_decoder_tb_pkg
