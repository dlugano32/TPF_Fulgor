class tx_rx_cdc_test_cfg;

    rand seed_t       seed;
    rand int unsigned cycles;
    int unsigned      test_index;

    constraint seed_c {
        seed != '0;
    }

    constraint cycles_c {
        cycles inside {[MIN_CYCLES:MAX_CYCLES]};
    }

    function void display(string tag = "");
        $display("[%s] mode=CLEAN test=%0d seed=0x%08h cycles=%0d",
            tag, test_index, seed, cycles);
    endfunction

endclass

class tx_rx_cdc_txn;

    logic                 locked;
    logic [CNT_W - 1 : 0] error_count;
    logic                 valid;

endclass
