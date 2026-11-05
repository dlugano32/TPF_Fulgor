`timescale 1ps/1ps

package tx_rx_cdc_tb_pkg;

    localparam int unsigned N_TESTS         = 100;
    localparam int unsigned MIN_CYCLES      = 1000;
    localparam int unsigned MAX_CYCLES      = 5000;
    localparam int unsigned LOCK_TIMEOUT    = 128;
    localparam int unsigned CHECKER_TIMEOUT = 8;
    localparam int unsigned RANDOM_SEED     = 32'h0FEC_2026;
    localparam int unsigned CNT_W           = $clog2(7 * 113 + 1);
    localparam int unsigned ORDER           = 31;

    typedef bit [ORDER - 1 : 0] seed_t;

    `include "tx_rx_cdc_txn.sv"
    `include "tx_rx_cdc_gen.sv"
    `include "tx_rx_cdc_drv.sv"
    `include "tx_rx_cdc_mon.sv"
    `include "tx_rx_cdc_scb.sv"
    `include "tx_rx_cdc_env.sv"

endpackage : tx_rx_cdc_tb_pkg
