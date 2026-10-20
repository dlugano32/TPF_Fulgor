package prbs31_checker_tb_pkg;

    import prbs31_pkg::*;

    localparam int CNT_W = $clog2(P + 1);
    localparam int unsigned RANDOM_SEED = 32'h31C0_FEC0;    // Makes test configuration and error masks reproducible.
    localparam int unsigned SCENARIO_COUNT = 3;             // Must match the number and order of checker_scenario_e values.
    localparam int unsigned MIN_FRAMES = 10;                // Random frame-count limits applied independently to every test.
    localparam int unsigned MAX_FRAMES = 100;

    typedef bit [ORDER - 1 : 0] seed_t;
    typedef bit [P - 1 : 0]     prbs_t;

    // Test-level intent. 
    // The driver translates each scenario into one error_mode_e per frame in get_error_mode().
    typedef enum int unsigned {
        CLEAN,         // Every frame is clean; lock is expected on frame 0.
        SEED_FAILURE,  // Frame 0 has seed errors; frame 1 must acquire lock.
        FRAME_ERRORS   // Frame 0 acquires lock; later frames contain 1-10 errors.
    } checker_scenario_e;

    // Frame-level stimulus used to constrain error_mask generation.
    typedef enum int unsigned {
        NO_ERRORS,
        SEED_ERRORS,   // Errors are restricted to temporal bits [0:30].
        RANDOM_ERRORS  // Errors may occur anywhere in the 791-bit frame.
    } error_mode_e;

    import "DPI-C" function void prbs31_checker_reset_dpi();
    import "DPI-C" function void prbs31_checker_dpi(input  prbs_t data, output bit locked, output int unsigned error_count);

    `include "prbs31_checker_txn.sv"
    `include "prbs31_checker_gen.sv"
    `include "prbs31_checker_drv.sv"
    `include "prbs31_checker_mon.sv"
    `include "prbs31_checker_scb.sv"
    `include "prbs31_checker_env.sv"

endpackage : prbs31_checker_tb_pkg
