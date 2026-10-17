class bch_codec_scb;

    mailbox #(bch_codec_txn) drv2scb;
    mailbox #(bch_codec_txn) mon2scb;

    int unsigned checked_count = 0;
    int unsigned error_count   = 0;
    bit          done          = 0;

    function new(
        mailbox #(bch_codec_txn) drv2scb,
        mailbox #(bch_codec_txn) mon2scb
    );
        this.drv2scb = drv2scb;
        this.mon2scb = mon2scb;
    endfunction

    task run(int unsigned transaction_count);
        repeat (transaction_count) begin
            bch_codec_txn expected;
            bch_codec_txn actual;
            cw_t expected_cw;
            cw_t expected_rx;
            bit  expected_corrected;

            drv2scb.get(expected);
            mon2scb.get(actual);

            bch_encode_dpi(expected.msg, expected_cw);
            expected_rx        = expected_cw ^ expected.error_mask;
            expected_corrected = (expected.error_mask != '0);
            actual.msg         = expected.msg;
            actual.error_mask  = expected.error_mask;

            if ((actual.encoded_cw    !== expected_cw) ||
                (actual.rx            !== expected_rx) ||
                (actual.err           !== expected.error_mask) ||
                (actual.decoded_cw    !== expected_cw) ||
                (actual.decoded_msg   !== expected.msg) ||
                (actual.corrected     !== expected_corrected) ||
                (actual.uncorrectable !== 1'b0)) begin

                $error("BCH codec mismatch sample=%0d", checked_count);
                $display(
                    "[expected] msg=0x%029h mask=0x%032h encoded_cw=0x%032h rx=0x%032h corrected=%0b uncorrectable=0",
                    expected.msg, expected.error_mask, expected_cw, expected_rx, expected_corrected
                );

                error_count++;
            end

            checked_count++;
            actual.display("actual");
        end

        done = 1'b1;
    endtask

endclass
