`timescale 1ps/1ps

// Repackages a continuous bit stream into wider words (e.g. TX 889 -> 1024).
// Supported widths: 1 <= BITS_IN <= BITS_OUT. Equal widths are also supported.
// Each rising edge with i_en accepts one input word, with bit [0] first.
// Pending bits are retained until a complete output word can be emitted;
// o_valid marks each new registered output. With i_en low, pending bits are
// preserved and o_valid is cleared. The downstream must always accept outputs.

module gearbox_widen #(
    parameter int BITS_IN  = 889,
    parameter int BITS_OUT = 1024
) (
    input  logic                    i_clk,
    input  logic                    i_rst_n,
    input  logic                    i_en,
    input  logic [BITS_IN  - 1 : 0] i_data,

    output logic [BITS_OUT - 1 : 0] o_data,
    output logic                    o_valid
);
    localparam int CNT_W = $clog2(BITS_OUT + 1);
    localparam int BITS_TOT = BITS_IN + BITS_OUT;

    logic [BITS_OUT - 1 : 0] buffer_r;
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
            if (count_next >= CNT_W'(BITS_OUT)) begin
                o_data   <= buffer_next[BITS_OUT - 1 : 0];
                buffer_r <= buffer_next >> BITS_OUT;
                o_valid <= 1'b1; 
                count_r <= count_next - CNT_W'(BITS_OUT);
            end else begin
                buffer_r <= buffer_next[BITS_OUT - 1 : 0];
                o_valid <= 1'b0;
                count_r  <= count_next;
            end
        end else
            o_valid <= 1'b0;
    end

    assign buffer_next = ({{BITS_OUT{1'b0}}, i_data} << count_r) | {{BITS_IN{1'b0}}, buffer_r};
    assign count_next = count_r + CNT_W'(BITS_IN);

endmodule
