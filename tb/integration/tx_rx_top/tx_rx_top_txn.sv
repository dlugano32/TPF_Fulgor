class tx_rx_top_test_cfg;

    import tx_rx_top_tb_pkg::*;

    rand seed_t       seed;
    rand int unsigned cycles;

    test_mode_e       mode;
    int unsigned      test_index;
    int unsigned      burst_length;
    int unsigned      burst_offset;
    bit               expect_post_fec_errors;

    constraint seed_c {
        seed != '0;
    }

    constraint cycles_c {
        cycles inside {[MIN_CYCLES:MAX_CYCLES]};
    }

    function void display(string tag = "");
        if (mode == CLEAN_TEST) begin
            $display("[%s] mode=CLEAN test=%0d seed=0x%08h cycles=%0d",
                tag, test_index, seed, cycles
            );
        end else begin
            $display("[%s] mode=BURST test=%0d seed=0x%08h length=%0d offset=%0d expect_errors=%0b window=%0d",
                tag, test_index, seed, burst_length, burst_offset,
                expect_post_fec_errors, cycles
            );
        end
    endfunction

endclass

class tx_rx_top_txn;

    import tx_rx_top_tb_pkg::*;

    logic                 locked;
    logic [CNT_W - 1 : 0] error_count;
    line_t                error_mask;
    logic                 input_valid;
    logic                 output_valid;

endclass
