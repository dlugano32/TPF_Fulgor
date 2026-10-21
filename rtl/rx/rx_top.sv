`timescale 1ps/1ps

module rx_top #(
    localparam int ORDER = 31,
    localparam int LANES = 7,
    localparam int CW_W = 127,
    localparam int PAY_W = 113,
    localparam int LINE_W = LANES * CW_W,
    localparam int CNT_W = $clog2(LANES*PAY_W + 1)
) (
    input  logic                                i_clk,
    input  logic                                i_rst_n,
    input  logic                                i_en,
    input  logic [LINE_W -1 : 0]                i_line,
    output logic [LANES - 1 : 0][PAY_W - 1 : 0] o_payload,
    output logic                                o_locked,
    output logic [CNT_W - 1 : 0]                o_error_count
);

    logic [LINE_W - 1 : 0]                deinterleaved;
    logic [LANES - 1  : 0][CW_W  - 1 : 0] codewords;
    logic [LANES - 1  : 0][PAY_W - 1 : 0] payload;

    conv_deinterleaver #(
        .D(1),
        .B(8),
        .LINE_W(LINE_W)
    ) u_conv_deinterleaver(
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_en(i_en),
        .i_line(i_line),
        .o_line(deinterleaved)
    );

    lane_depermuter #(
        .LANES(LANES),
        .CW_W(CW_W)
    ) u_lane_depermuter (
        .i_line(deinterleaved),
        .o_codewords(codewords)
    );

    genvar i;
    generate
        for(i=0; i < LANES; i++) begin
            bch_decoder u_bch_decoder (
                .i_clk(i_clk),
                .i_rst_n(i_rst_n),
                .i_en(i_en),
                .i_rx(codewords[i]),
                .o_msg(payload[i])
            );
        end
    endgenerate

    prbs31_checker u_prbs31_checker (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_en(i_en),
        .i_data(payload),
        .o_locked(o_locked),
        .o_error_count(o_error_count)
    );

    assign o_payload = payload;
    
endmodule
