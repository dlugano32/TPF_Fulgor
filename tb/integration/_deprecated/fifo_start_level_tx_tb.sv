`timescale 1ps/1ps

// TX rate test: actual TX gearbox -> actual FWFT FIFO -> constant DSP reads.
// Once started, every DSP edge must consume 1024 bits. FIFO writes may have gaps.
// Constant data keeps this bank focused on startup, occupancy and line rate.

module fifo_start_level_tx_tb;
    localparam int FIFO_DEPTH = 8;
    localparam int DSP_W = 1024;
    localparam int FEC_W = 889;
    localparam int FEC_PERIOD = FEC_W;
    localparam int DSP_PERIOD = DSP_W;
    localparam int SUPERPERIOD = FEC_PERIOD * DSP_PERIOD;
    localparam int RESET_TICKS = 8 * DSP_PERIOD;

    bit fec_clk = 0, dsp_clk = 0, rst_n = 0, source_en = 0, started = 0;
    wire [DSP_W-1:0] gearbox_data, fifo_data;
    wire gearbox_valid, empty, full, rd_en;
    wire [$clog2(FIFO_DEPTH):0] level;
    int start_level = 2;
    int startup_delay = 0;
    int phases = DSP_PERIOD;
    int phase;
    int writes = 0, reads = 0, tested_reads = 0;
    int first_read_at = 0;
    int minimum_start_occupancy = FIFO_DEPTH+1;
    int maximum_start_occupancy = 0;
    int maximum_occupancy = 0;
    int startup_count = 0;

    gearbox_widen #(
        .BITS_IN(FEC_W),
        .BITS_OUT(DSP_W)
    ) source (
        .i_clk(fec_clk),
        .i_rst_n(rst_n),
        .i_en(source_en),
        .i_data({FEC_W{1'b0}}),
        .o_data(gearbox_data),
        .o_valid(gearbox_valid)
    );

    async_fifo #(
        .WIDTH(DSP_W),
        .DEPTH(FIFO_DEPTH)
    ) fifo (
        .i_wr_clk(fec_clk),
        .i_rd_clk(dsp_clk),
        .i_wr_rst_n(rst_n),
        .i_rd_rst_n(rst_n),
        .i_wr_en(gearbox_valid),
        .i_rd_en(rd_en),
        .i_data(gearbox_data),
        .o_data(fifo_data),
        .o_empty(empty),
        .o_full(full),
        .o_rd_level(level)
    );

    // STARTUP_DELAY is measured in the reader's clock: DSP cycles in TX.
    assign rd_en = rst_n && (started || (level >= start_level && startup_count >= startup_delay));

    always @(posedge fec_clk) begin
        if (!rst_n)
            writes = 0;
        else if (gearbox_valid) begin
            if (full)
                $fatal(1, "TX rejected write: phase=%0d level=%0d delay=%0d", phase, start_level, startup_delay);

            writes++;
        end
    end

    always @(posedge dsp_clk) begin
        if (!rst_n) begin
            reads = 0;
            started <= 0;
            startup_count <= 0;
        end else begin
            if (!started && level >= start_level) begin
                if (startup_count + 1 >= startup_delay)
                    started <= 1;
                else
                    startup_count <= startup_count + 1;
            end
            if (rd_en) begin
                if (empty) $fatal(1, "TX underflow: phase=%0d level=%0d delay=%0d", phase, start_level, startup_delay);
                if (fifo_data !== {DSP_W{1'b0}})
                    $fatal(1, "TX read contains unwritten or unexpected data");
                reads++;
                tested_reads++;
            end
        end
    end

    initial begin
        int now_tick, next_fec, next_dsp, next_tick, occupancy;
        bit fec_edge, dsp_edge;

        if ($value$plusargs("START_LEVEL=%d", start_level)) begin end
        if ($value$plusargs("STARTUP_DELAY=%d", startup_delay)) begin end
        if ($value$plusargs("PHASES=%d", phases)) begin end
        if (FEC_W < 1 || DSP_W < FEC_W || FIFO_DEPTH < 4 ||
            (FIFO_DEPTH & (FIFO_DEPTH-1)) != 0 ||
            start_level < 1 || start_level > FIFO_DEPTH || startup_delay < 0 ||
            phases < 1 || phases > DSP_PERIOD)
            $fatal(1, "Invalid TX startup test configuration");

        for (phase = 0; phase < phases; phase++) begin
            rst_n = 0;
            source_en = 0;
            first_read_at = 0;
            now_tick = 0;
            next_fec = FEC_PERIOD;
            next_dsp = phase == 0 ? DSP_PERIOD : phase;

            // Two superperiods after reset cover every pointer wrap and cadence.
            while (now_tick < (2*SUPERPERIOD + RESET_TICKS)) begin
                next_tick = (next_fec < next_dsp) ? next_fec : next_dsp;
                #(next_tick - now_tick);
                if (next_tick >= RESET_TICKS) begin rst_n = 1; source_en = 1; end
                fec_edge = (next_fec == next_tick);
                dsp_edge = (next_dsp == next_tick);
                fec_clk = fec_edge;
                dsp_clk = dsp_edge;
                if (fec_edge) next_fec += FEC_PERIOD;
                if (dsp_edge) next_dsp += DSP_PERIOD;
                // Account for both clocks after simultaneous-edge updates.
                #1;
                occupancy = writes - reads;
                if (rst_n) begin
                    if (occupancy < 0 || occupancy > FIFO_DEPTH)
                        $fatal(1, "TX physical occupancy out of range");
                    if (occupancy > maximum_occupancy) maximum_occupancy = occupancy;
                    if (reads == 1 && first_read_at == 0) first_read_at = occupancy + 1;
                end
                fec_clk = 0;
                dsp_clk = 0;
                now_tick = next_tick + 1;
            end

            if (first_read_at < minimum_start_occupancy)
                minimum_start_occupancy = first_read_at;
            if (first_read_at > maximum_start_occupancy)
                maximum_start_occupancy = first_read_at;
            if (phase % 128 == 127)
                $display("TX PHASE PROGRESS %0d/%0d", phase+1, phases);
        end
        $display("PASS TX FIFO: %0d phases, START_LEVEL=%0d, extra DSP startup delay=%0d, reads=%0d, maximum physical occupancy=%0d", phases, start_level, startup_delay, tested_reads, maximum_occupancy);
        $display("Physical occupancy at first TX read: %0d..%0d words", minimum_start_occupancy, maximum_start_occupancy);
        $finish;
    end
endmodule
