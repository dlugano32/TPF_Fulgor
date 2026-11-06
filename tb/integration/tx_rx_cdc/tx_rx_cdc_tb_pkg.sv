`timescale 1ps/1ps

package tx_rx_cdc_tb_pkg;

    localparam int unsigned N_TESTS = 100;
    localparam int unsigned MIN_CYCLES = 1000;
    localparam int unsigned MAX_CYCLES = 5000;
    localparam int unsigned LOCK_TIMEOUT = 32;
    localparam int unsigned CHECKER_TIMEOUT = 5;
    localparam int unsigned RANDOM_SEED = 32'h0FEC_2026;
    localparam int unsigned CNT_W = $clog2(7 * 113 + 1);
    localparam int unsigned ORDER = 31;
    localparam int unsigned DSP_W = 1024;
    localparam int unsigned BURST_TEST_COUNT = 100;
    localparam int unsigned POST_BURST_CYCLES = 16;

    typedef enum int unsigned {CLEAN_TEST, BURST_TEST} test_mode_e;

    typedef bit [ORDER - 1 : 0] seed_t;

    `include "tx_rx_cdc_txn.sv"
    `include "tx_rx_cdc_gen.sv"
    `include "tx_rx_cdc_drv.sv"
    `include "tx_rx_cdc_mon.sv"
    `include "tx_rx_cdc_scb.sv"
    `include "tx_rx_cdc_env.sv"

endpackage : tx_rx_cdc_tb_pkg
