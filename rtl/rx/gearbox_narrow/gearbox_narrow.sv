`timescale 1ps/1ps

// Repackages a continuous bit stream into narrower words (e.g. RX 1024 -> 889).
// Supported widths: 1 <= BITS_OUT <= BITS_IN. Equal widths are also supported.
// Each rising edge with i_en emits one registered output word, bit [0] first,
// and asserts o_valid. An input word is incorporated only when the pending
// bit count is below BITS_OUT; otherwise the output uses pending bits alone.
// The upstream must provide a new valid word whenever an input is needed;
// With i_en low, pending bits are preserved and o_valid is cleared.
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
    output logic                    o_valid
);
    
    localparam int BITS_TOT = BITS_IN + BITS_OUT;
    localparam int CNT_W    = $clog2(BITS_TOT);

    logic [BITS_IN  - 1 : 0] buffer_r;
    logic [BITS_TOT - 1 : 0] buffer_next;

    logic [CNT_W     - 1 : 0] count_next;
    logic [CNT_W     - 1 : 0] count_r;

    always_ff @(posedge i_clk) begin
        if(!i_rst_n) begin
            buffer_r  <= '0;
            count_r   <= '0;
            o_valid   <= '0;
            o_data    <= '0;
        end else if(i_en) begin
            o_data   <= buffer_next[BITS_OUT - 1 : 0];
            buffer_r <= buffer_next >> BITS_OUT;
            o_valid <= 1'b1; 
            count_r <= count_next - CNT_W'(BITS_OUT);
        end else
            o_valid <= 1'b0;
    end

    assign buffer_next = (count_r < CNT_W'(BITS_OUT)) ?
        ({{BITS_OUT{1'b0}}, i_data} << count_r)| {{BITS_OUT{1'b0}}, buffer_r} :
        {{BITS_OUT{1'b0}}, buffer_r};

    assign count_next = (count_r < CNT_W'(BITS_OUT)) ? 
        count_r + CNT_W'(BITS_IN) :
        count_r;

endmodule
