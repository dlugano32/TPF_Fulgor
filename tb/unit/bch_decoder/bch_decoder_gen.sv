class bch_decoder_gen;

    mailbox #(bch_decoder_txn) gen2drv;

    function new(mailbox #(bch_decoder_txn) gen2drv);
        this.gen2drv = gen2drv;
    endfunction

    task send_error(cw_t error_mask);
        bch_decoder_txn txn = new();

        txn.rx = BASE_CODEWORD ^ error_mask;
        gen2drv.put(txn);
    endtask

    task run();
        cw_t error_mask;

        // No errors
        send_error('0);

        // All 127 single-error patterns
        for (int i = 0; i < N; i++) begin
            error_mask = '0;
            error_mask[i] = 1'b1;
            send_error(error_mask);
        end

        // All 8001 double-error patterns
        for (int i = 0; i < N; i++) begin
            for (int j = i + 1; j < N; j++) begin
                error_mask = '0;
                error_mask[i]  = 1'b1;
                error_mask[j] = 1'b1;
                send_error(error_mask);
            end
        end
    endtask

endclass
