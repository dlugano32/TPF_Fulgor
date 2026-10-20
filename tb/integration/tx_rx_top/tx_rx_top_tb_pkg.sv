package tx_rx_top_tb_pkg;

    import prbs31_pkg::*;

    localparam int unsigned N_TESTS       = 10;
    localparam int unsigned MIN_CYCLES    = 100;
    localparam int unsigned MAX_CYCLES    = 1000;
    localparam int unsigned LOCK_TIMEOUT  = 32;
    localparam int unsigned RESET_CYCLES  = 3;
    localparam int unsigned RANDOM_SEED   = 32'h0FEC_2026;
    localparam int unsigned CNT_W         = $clog2(P + 1);

    typedef bit [ORDER - 1 : 0] seed_t;

    `include "tx_rx_top_txn.sv"
    `include "tx_rx_top_gen.sv"
    `include "tx_rx_top_drv.sv"
    `include "tx_rx_top_mon.sv"
    `include "tx_rx_top_scb.sv"
    `include "tx_rx_top_env.sv"

endpackage : tx_rx_top_tb_pkg
