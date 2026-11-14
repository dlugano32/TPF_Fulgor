`timescale 1ps/1ps

// RX rate test: constant DSP writes -> actual FWFT FIFO -> actual RX gearbox.
// Once started, every FEC edge must emit 889 bits. FIFO reads may have gaps.
// Constant data keeps this bank focused on startup, occupancy and line rate.

module fifo_start_level_rx_tb;
    localparam int FEC_PERIOD = 889;
    localparam int DSP_PERIOD = 1024;
    localparam int SUPERPERIOD = FEC_PERIOD * DSP_PERIOD;
    localparam int FIFO_DEPTH = 8;
    localparam int DSP_W = 1024;
    localparam int FEC_W = 889;

    bit fec_clk = 0, dsp_clk = 0, rst_n = 0, source_en = 0;
    bit started = 0;
    wire [DSP_W-1:0] fifo_data;
    wire [FEC_W-1:0] output_data;
    wire empty, full, rd_en, wr_en, gearbox_en, output_valid;
    wire [$clog2(FIFO_DEPTH):0] level;
    int start_level = 2;
    int startup_delay = 0;
    int phases = DSP_PERIOD;
    int phase, startup_count = 0;
    int writes = 0, reads = 0, outputs = 0;
    int block_reads = 0, block_outputs = 0;
    int tested_reads = 0, tested_outputs = 0;
    int maximum_occupancy = 0;
    int first_read_at = 0;
    int minimum_start_occupancy = FIFO_DEPTH+1;
    int maximum_start_occupancy = 0;

    assign wr_en = rst_n && source_en;
    // STARTUP_DELAY is measured in the reader's clock: FEC cycles in RX.
    assign gearbox_en = rst_n && (started || (level >= start_level && startup_count >= startup_delay));

    async_fifo #(
        .WIDTH(DSP_W),
        .DEPTH(FIFO_DEPTH)
    ) fifo (
        .i_wr_clk(dsp_clk),
        .i_rd_clk(fec_clk),
        .i_wr_rst_n(rst_n),
        .i_rd_rst_n(rst_n),
        .i_wr_en(wr_en),
        .i_rd_en(rd_en),
        .i_data({DSP_W{1'b0}}),
        .o_data(fifo_data),
        .o_empty(empty),
        .o_full(full),
        .o_rd_level(level)
    );

    gearbox_narrow #(
        .BITS_IN(DSP_W),
        .BITS_OUT(FEC_W)
    ) gearbox (
        .i_clk(fec_clk),
        .i_rst_n(rst_n),
        .i_en(gearbox_en),
        .i_data(fifo_data),
        .o_data(output_data),
        .o_valid(output_valid),
        .o_rd_en(rd_en)
    );

    always @(posedge dsp_clk) begin
        if (!rst_n) writes = 0;
        else if (wr_en) begin
            if (full)
                $fatal(1, "RX rejected write: phase=%0d level=%0d delay=%0d", phase, start_level, startup_delay);
            writes++;
        end
    end

    always @(posedge fec_clk) begin : check_reader
        bit expected_valid;
        expected_valid = rst_n && gearbox_en;
        if (!rst_n) begin
            started <= 0;
            startup_count <= 0;
            reads = 0;
            outputs = 0;
            block_reads = 0;
            block_outputs = 0;
        end else begin
            if (!started && level >= start_level) begin
                if (startup_count + 1 >= startup_delay) started <= 1;
                else startup_count <= startup_count + 1;
            end
            if (rd_en) begin
                if (empty)
                    $fatal(1, "RX underflow: phase=%0d level=%0d delay=%0d", phase, start_level, startup_delay);
                reads++;
                block_reads++;
                tested_reads++;
            end
            if (gearbox_en) begin
                outputs++;
                block_outputs++;
                tested_outputs++;
                if (block_outputs == DSP_W) begin
                    if (block_reads != FEC_W)
                        $fatal(1, "RX cadence mismatch: %0d reads per 1024 FEC outputs", block_reads);
                    block_reads = 0;
                    block_outputs = 0;
                end
            end
        end
        // Check the registered output after the nonblocking updates.
        #1;
        if (output_valid !== expected_valid)
            $fatal(1, "RX output gap or spurious valid: phase=%0d output=%0d", phase, outputs);
        if (rst_n) begin
            if (gearbox.count_r != DSP_W*reads - FEC_W*outputs)
                $fatal(1, "RX bit conservation mismatch");
            if (gearbox.count_r >= DSP_W)
                $fatal(1, "RX residue exceeds its buffer");
            if (output_valid && output_data !== {FEC_W{1'b0}})
                $fatal(1, "RX output contains unwritten or unexpected data");
        end
    end

    initial begin
        int now_tick, next_fec, next_dsp, next_tick, occupancy;
        bit fec_edge, dsp_edge;
        if ($value$plusargs("START_LEVEL=%d", start_level)) begin end
        if ($value$plusargs("STARTUP_DELAY=%d", startup_delay)) begin end
        if ($value$plusargs("PHASES=%d", phases)) begin end
        if (start_level < 1 || start_level > FIFO_DEPTH || startup_delay < 0 ||
            phases < 1 || phases > DSP_PERIOD)
            $fatal(1, "Invalid startup test configuration");

        for (phase = 0; phase < phases; phase++) begin
            rst_n = 0;
            source_en = 0;
            first_read_at = 0;
            now_tick = 0;
            next_fec = FEC_PERIOD;
            next_dsp = phase == 0 ? DSP_PERIOD : phase;
            while (now_tick < 2*SUPERPERIOD + 8192) begin
                next_tick = next_fec < next_dsp ? next_fec : next_dsp;
                #(next_tick - now_tick);
                if (next_tick >= 8192) begin rst_n = 1; source_en = 1; end
                fec_edge = next_fec == next_tick;
                dsp_edge = next_dsp == next_tick;
                fec_clk = fec_edge;
                dsp_clk = dsp_edge;
                if (fec_edge) next_fec += FEC_PERIOD;
                if (dsp_edge) next_dsp += DSP_PERIOD;
                // Account for both edges after simultaneous-clock updates.
                #1;
                occupancy = writes - reads;
                if (rst_n) begin
                    if (occupancy < 0 || occupancy > FIFO_DEPTH)
                        $fatal(1, "RX physical occupancy out of range");
                    if (occupancy > maximum_occupancy) maximum_occupancy = occupancy;
                    if (reads == 1 && first_read_at == 0) first_read_at = occupancy + 1;
                end
                fec_clk = 0;
                dsp_clk = 0;
                now_tick = next_tick + 1;
            end
            if (first_read_at < minimum_start_occupancy) minimum_start_occupancy = first_read_at;
            if (first_read_at > maximum_start_occupancy) maximum_start_occupancy = first_read_at;
            if (phase % 128 == 127) $display("RX PHASE PROGRESS %0d/%0d", phase+1, phases);
        end
        $display("PASS RX FIFO: %0d phases, START_LEVEL=%0d, extra FEC startup delay=%0d, reads=%0d, continuous outputs=%0d, maximum physical occupancy=%0d", phases, start_level, startup_delay, tested_reads, tested_outputs, maximum_occupancy);
        $display("Physical occupancy at first RX read: %0d..%0d words", minimum_start_occupancy, maximum_start_occupancy);
        $finish;
    end
endmodule
