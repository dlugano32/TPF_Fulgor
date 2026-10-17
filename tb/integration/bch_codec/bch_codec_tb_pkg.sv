package bch_codec_tb_pkg;

    import bch_decoder_pkg::*;

    typedef bit [K - 1 : 0] msg_t;
    typedef bit [N - 1 : 0] cw_t;

    localparam int unsigned RANDOM_MESSAGE_COUNT       = 1872;
    localparam int unsigned RANDOM_SEED                = 32'hB127_0113;
    localparam int unsigned CORRECTABLE_PATTERN_COUNT  = N + (N * (N - 1)) / 2;
    localparam int unsigned TRANSACTION_COUNT          = RANDOM_MESSAGE_COUNT + CORRECTABLE_PATTERN_COUNT;

    import "DPI-C" function void bch_encode_dpi(input msg_t message, output cw_t codeword);

    `include "bch_codec_txn.sv"
    `include "bch_codec_gen.sv"
    `include "bch_codec_drv.sv"
    `include "bch_codec_mon.sv"
    `include "bch_codec_scb.sv"
    `include "bch_codec_env.sv"

endpackage : bch_codec_tb_pkg
