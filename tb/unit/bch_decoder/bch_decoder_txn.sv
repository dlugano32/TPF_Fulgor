class bch_decoder_txn;

    cw_t  rx;
    cw_t  err;
    cw_t  cw;
    msg_t msg;
    bit   corrected;
    bit   uncorrectable;

    function void display(string tag = "");
        $display("[%s] rx=0x%032h err=0x%032h cw=0x%032h msg=0x%029h corrected=%0b uncorrectable=%0b",
            tag, rx, err, cw, msg, corrected, uncorrectable
        );
    endfunction

endclass
