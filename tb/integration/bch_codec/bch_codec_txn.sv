class bch_codec_txn;

    rand msg_t msg;
    cw_t       error_mask;

    cw_t  encoded_cw;
    cw_t  rx;
    cw_t  err;
    cw_t  decoded_cw;
    msg_t decoded_msg;
    bit   corrected;
    bit   uncorrectable;

    function void display(string tag = "");
        $display("[%s] msg=0x%029h mask=0x%032h encoded_cw=0x%032h rx=0x%032h err=0x%032h decoded_cw=0x%032h decoded_msg=0x%029h corrected=%0b uncorrectable=%0b",
            tag, msg, error_mask, encoded_cw, rx, err, decoded_cw, decoded_msg, corrected, uncorrectable
        );
    endfunction

endclass
