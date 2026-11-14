`timescale 1ps/1ps

module gearbox_cdc #(
    parameter int PAR_IN  = 7,
    parameter int PAR_OUT = 8,
    parameter int DEPTH = 112, // Must be a multiple of LCM(PAR_IN, PAR_OUT)
    parameter type DATA_T = logic [126 : 0]
) (
    input  logic                    i_rd_clk,
    input  logic                    i_wr_clk,
    input  logic                    i_wr_rst_n,
    input  logic                    i_rd_rst_n,
    input  logic                    i_wr_en,
    input  DATA_T [PAR_IN  - 1 : 0] i_data,
    output DATA_T [PAR_OUT - 1 : 0] o_data,
    output logic                    o_valid
);
    localparam WR_DEPTH = DEPTH/PAR_IN;
    localparam RD_DEPTH = DEPTH/PAR_OUT;

    logic [$clog2(RD_DEPTH) - 1 : 0] rd_ptr_r;
    logic [$clog2(RD_DEPTH) - 1 : 0] rd_ptr_next;

    logic [$clog2(WR_DEPTH) - 1 : 0] wr_ptr_r;
    logic [$clog2(WR_DEPTH) - 1 : 0] wr_ptr_next;

    logic rd_start_r;
    logic rd_en;

    always_ff @(posedge i_wr_clk) begin
        if(!i_wr_rst_n) begin
            wr_ptr_r <= '0;
        end else if(i_wr_en) begin
            wr_ptr_r <= wr_ptr_next;
        end
    end

    assign wr_ptr_next = (wr_ptr_r < (WR_DEPTH-1)) ? (wr_ptr_r + 1'b1) : '0;

    always_ff @(posedge i_rd_clk) begin
        if(!i_rd_rst_n) begin
            rd_ptr_r <= '0;
        end else if(rd_en) begin
            rd_ptr_r <= rd_ptr_next;
        end
    end

    assign rd_ptr_next = (rd_ptr_r < (RD_DEPTH-1)) ? (rd_ptr_r + 1'b1) : '0;

    typedef DATA_T [PAR_IN  - 1 : 0] wr_t;
    typedef DATA_T [PAR_OUT - 1 : 0] rd_t;

    typedef wr_t [WR_DEPTH - 1 : 0] wr_mem_t;
    typedef rd_t [RD_DEPTH - 1 : 0] rd_mem_t;

    wr_mem_t wr_mem;
    rd_mem_t rd_mem;

    assign rd_mem = wr_mem;

    always_ff @(posedge i_wr_clk) begin
        if(i_wr_en) begin
            wr_mem[wr_ptr_r] <= i_data;
        end
    end

    always_ff @(posedge i_wr_clk) begin
        if(!i_wr_rst_n) begin
            rd_start_r <= '0;
        end else begin
            if(i_wr_en && (wr_ptr_r == ((WR_DEPTH/2) -1))) begin
                rd_start_r <= 1'b1;
            end
        end
    end

    sync_level #(
        .PIPE(2)
    ) u_sync_rd_start(
        .o_data(rd_en),
        .i_data(rd_start_r),
        .i_rst_n(i_rd_rst_n),
        .i_clk(i_rd_clk)
    );

    always_ff @(posedge i_rd_clk) begin
        if(rd_en) begin
            o_data <= rd_mem[rd_ptr_r];
        end
    end

    always_ff @(posedge i_rd_clk) begin
        if(!i_rd_rst_n) begin
            o_valid <= '0;
        end else if(rd_en) begin
            o_valid <= 1'b1;
        end
    end

endmodule