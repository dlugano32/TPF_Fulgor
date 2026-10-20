`timescale 1ps/1ps

module prbs31_checker
    import prbs31_pkg::*;
#(
    localparam int CNT_W = $clog2(P + 1)
) (
    input  logic                i_clk,
    input  logic                i_rst_n,
    input  logic                i_en,
    input  logic [P - 1 : 0]    i_data,

    output logic                o_locked,
    output logic [CNT_W - 1 : 0] o_error_count
);
    
    typedef enum logic {SEEDING, LOCKED} state_e;

    state_e state_r;
    state_e state_next;

    logic [ORDER - 1 : 0] seed_candidate;
    logic [ORDER - 1 : 0] lfsr_r;
    logic [ORDER - 1 : 0] lfsr_state;
    logic [ORDER - 1 : 0] lfsr_next;

    logic [P - 1 : 0] prbs_expected;
    logic [P - 1 : 0] error_pattern;
    logic [CNT_W - 1 : 0] error_weight;
    logic [CNT_W - 1 : 0] error_count_r;

    logic locked;
    logic match;

    // i_data[0] is the first bit in time and corresponds to state bit 30.
    genvar ix;
    generate
        for (ix = 0; ix < ORDER; ix++) begin : gen_seed
            assign seed_candidate[ORDER - 1 - ix] = i_data[ix];
        end
    endgenerate

    assign lfsr_state = (state_r == SEEDING) ? seed_candidate : lfsr_r;

    prbs31_mult_a
    u_prbs31_mult_a (
        .i_state      (lfsr_state),
        .o_state_next (lfsr_next)
    );

    prbs31_mult_b
    u_prbs31_mult_b (
        .i_state (lfsr_state),
        .o_prbs  (prbs_expected)
    );

    assign error_pattern = i_data ^ prbs_expected;

    assign match = ~(|error_pattern[P - 1 : ORDER]);   // Match between the payload received and the sequence generated

    assign locked = (state_r == SEEDING) && (seed_candidate != '0) && match;

    always_comb begin
        state_next = state_r;

        case (state_r)
            SEEDING: begin
                if (locked)
                    state_next = LOCKED;
            end

            LOCKED: state_next = LOCKED;

            default: state_next = SEEDING;
        endcase
    end

    always_ff @(posedge i_clk) begin
        if (!i_rst_n) begin
            state_r <= SEEDING;
        end else if (i_en) begin
            state_r <= state_next;
        end
    end

    // On the acquisition cycle lfsr_next points to the beginning of the next
    // 791-bit block. Once locked, the reference advances once per valid block.
    always_ff @(posedge i_clk) begin
        if (!i_rst_n) begin
            lfsr_r <= '0;
        end else if (i_en && ((state_r == LOCKED) || locked)) begin
            lfsr_r <= lfsr_next;
        end
    end

    popcount #(
        .WIDTH (P)
    ) u_popcount (
        .i_vec    (error_pattern),
        .o_weight (error_weight)
    );

    // The acquisition block is intentionally excluded from the BER. 
    // The count holds whenever no valid input block is presented.
    always_ff @(posedge i_clk) begin
        if (!i_rst_n) begin
            error_count_r <= '0;
        end else if (i_en) begin
            if (state_r == LOCKED)
                error_count_r <= error_weight;
            else
                error_count_r <= '0;
        end
    end

    assign o_locked      = (state_r == LOCKED);
    assign o_error_count = error_count_r;

endmodule
