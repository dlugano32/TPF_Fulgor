class bch_codec_gen;

    import bch_codec_tb_pkg::*;

    mailbox #(bch_codec_txn) gen2drv;

    function new(mailbox #(bch_codec_txn) gen2drv);
        this.gen2drv = gen2drv;
    endfunction

    task send_random_message(cw_t error_mask);
        bch_codec_txn txn = new();

        if (!txn.randomize())
            $fatal(1, "Could not randomize BCH codec transaction");

        txn.error_mask = error_mask;
        gen2drv.put(txn);
    endtask

    task run();
        process current_process = process::self();
        cw_t error_mask;

        current_process.srandom(RANDOM_SEED);

        // All correctable patterns: no errors, one error and two errors

        // Random messages without errors
        repeat (RANDOM_MESSAGE_COUNT)
            send_random_message('0);

        // Random messages with single-errors
        for (int i = 0; i < N; i++) begin
            error_mask = '0;
            error_mask[i] = 1'b1;
            send_random_message(error_mask);
        end

        // Random messages with double-errors
        for (int i = 0; i < N; i++) begin
            for (int j = i + 1; j < N; j++) begin
                error_mask = '0;
                error_mask[i] = 1'b1;
                error_mask[j] = 1'b1;
                send_random_message(error_mask);
            end
        end
    endtask

endclass
