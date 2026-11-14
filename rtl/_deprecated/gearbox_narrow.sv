`timescale 1ps/1ps

// Repackages a continuous bit stream into narrower words (e.g. RX 1024 -> 889).
// Supported widths: 1 <= BITS_OUT <= BITS_IN. Equal widths are also supported.
// Connect i_data to a FWFT FIFO head and o_rd_en to its read enable.
// Each enabled edge emits BITS_OUT bits, bit [0] first. If the residue is
// insufficient, the head is incorporated and consumed at that same edge.
// External startup control must guarantee a valid head whenever needed.
// With i_en low, pending bits are preserved, o_rd_en is low and o_valid is
// cleared. Reset both blocks together. Startup threshold control is external.
// The downstream must always accept outputs. Uses a single clock.

module gearbox_narrow #(
    parameter int BITS_IN  = 1024,
    parameter int BITS_OUT = 889
) (
    input  logic                    i_clk,
    input  logic                    i_rst_n,
    input  logic                    i_en,
    input  logic [BITS_IN  - 1 : 0] i_data,

    output logic [BITS_OUT - 1 : 0] o_data,
    output logic                    o_valid,
    output logic                    o_rd_en
);
    
    localparam int BITS_TOT = BITS_IN + BITS_OUT;
    localparam int CNT_W    = $clog2(BITS_TOT);

    logic [BITS_IN  - 1 : 0] buffer_r;
    logic [BITS_TOT - 1 : 0] buffer_next;

    logic [CNT_W     - 1 : 0] count_next;
    logic [CNT_W     - 1 : 0] count_r;
    logic [CNT_W     - 1 : 0] count_available;

    logic need_input;      // Indica que los bits almacenados no alcanzan para una salida

    always_ff @(posedge i_clk) begin
        if(!i_rst_n) begin
            buffer_r  <= '0;
            count_r   <= '0;
            o_valid   <= '0;
            o_data    <= '0;
        end else if(i_en) begin
            o_valid  <= 1'b1;
            o_data   <= buffer_next[BITS_OUT - 1 : 0];
            buffer_r <= buffer_next >> BITS_OUT;
            count_r  <= count_next;
        end else
            o_valid <= 1'b0;
    end

    assign need_input = (count_r < CNT_W'(BITS_OUT));

    assign buffer_next = need_input ?
        ({{BITS_OUT{1'b0}}, i_data} << count_r)| {{BITS_OUT{1'b0}}, buffer_r} :
        {{BITS_OUT{1'b0}}, buffer_r};

    assign count_available = need_input ?
        count_r + CNT_W'(BITS_IN) :
        count_r;

    assign count_next = count_available - CNT_W'(BITS_OUT);

    // Consume the current FWFT head only when this output needs new bits.
    assign o_rd_en = i_rst_n && i_en && need_input;

endmodule
