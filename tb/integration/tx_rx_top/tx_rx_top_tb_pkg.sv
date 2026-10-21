package tx_rx_top_tb_pkg;

    import prbs31_pkg::*;

    localparam int unsigned LINE_W                  = 889;
    localparam int unsigned N_TESTS                 = 10;
    localparam int unsigned MIN_CYCLES              = 100;
    localparam int unsigned MAX_CYCLES              = 1000;
    localparam int unsigned BURST_TEST_COUNT        = 10;
    localparam int unsigned PRE_BURST_CYCLES        = 2;
    localparam int unsigned POST_BURST_CYCLES       = 20;
    localparam int unsigned LOCK_TIMEOUT            = 32;
    localparam int unsigned RESET_CYCLES            = 3;
    localparam int unsigned RANDOM_SEED             = 32'h0FEC_2026;
    localparam int unsigned CNT_W                   = $clog2(P + 1);

    typedef bit   [ORDER  - 1 : 0] seed_t;
    typedef logic [LINE_W - 1 : 0] line_t;

    typedef enum int unsigned {
        CLEAN_TEST,
        BURST_TEST
    } test_mode_e;

    `include "tx_rx_top_txn.sv"
    `include "tx_rx_top_gen.sv"
    `include "tx_rx_top_drv.sv"
    `include "tx_rx_top_mon.sv"
    `include "tx_rx_top_scb.sv"
    `include "tx_rx_top_env.sv"

endpackage : tx_rx_top_tb_pkg
