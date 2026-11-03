`timescale 1ns/1ps
`default_nettype none

// A tick is one full second of accumulated FIRING time. The caller clears
// its second divider in READY/DONE and freezes it in PAUSED and on pause.
module kiln_core (
    input  wire        clk, reset, tick_second, cancel_hold,
    input  wire [3:0]  press,
    output reg  [1:0]  state, duration_sel,
    output reg  [10:0] remaining_s,
    output reg  [3:0]  pause_count, piece_id,
    output reg  [7:0]  fired_count,
    output reg  [15:0] collection,
    output reg  [1:0]  selected_piece,
    output reg         viewing
);
    localparam [1:0] READY=2'd0, FIRING=2'd1, PAUSED=2'd2, DONE=2'd3;

    function [10:0] seconds_for;
        input [1:0] selection;
        case (selection)
            0: seconds_for = 11'd30;
            1: seconds_for = 11'd300;
            2: seconds_for = 11'd900;
            3: seconds_for = 11'd1500;
        endcase
    endfunction

    wire [1:0] next_duration = duration_sel + 2'd1;
    wire [2:0] stored_pieces = fired_count >= 8'd4 ? 3'd4 : fired_count[2:0];
    wire [2:0] next_piece = {1'b0, selected_piece} + 3'd1;

    // Each mix is a permutation for any one varying input. Continue changing
    // the recipe after the visible total saturates at 255 finished pieces.
    reg [3:0] firing_serial;
    wire [3:0] new_piece = 4'h6 ^ firing_serial ^ {duration_sel, duration_sel}
                           ^ {pause_count[2:0], pause_count[3]};

    always @(posedge clk) begin
        if (reset) begin
            state <= READY;
            duration_sel <= 0;
            remaining_s <= seconds_for(0);
            pause_count <= 0;
            piece_id <= 0;
            firing_serial <= 0;
            fired_count <= 0;
            collection <= 0;
            selected_piece <= 0;
            viewing <= 0;
        end else case (state)
            READY: begin
                if (press[1]) begin
                    state <= FIRING;
                    remaining_s <= seconds_for(duration_sel);
                    pause_count <= 0;
                    selected_piece <= 0;
                    viewing <= 0;
                end else if (press[0]) begin
                    duration_sel <= next_duration;
                    remaining_s <= seconds_for(next_duration);
                    selected_piece <= 0;
                    viewing <= 0;
                end else if (press[3]) begin
                    selected_piece <= 0;
                    viewing <= 0;
                end else if (press[2] && stored_pieces != 0) begin
                    selected_piece <= (!viewing || next_piece >= stored_pieces)
                                      ? 2'd0 : next_piece[1:0];
                    viewing <= 1;
                end
            end
            FIRING: begin
                if (press[1]) begin
                    state <= PAUSED;
                    if (pause_count != 4'hf) pause_count <= pause_count + 1'b1;
                end else if (tick_second) begin
                    remaining_s <= remaining_s - 1'b1;
                    if (remaining_s == 1) state <= DONE;
                end
            end
            PAUSED: begin
                if (cancel_hold) begin
                    state <= READY;
                    remaining_s <= seconds_for(duration_sel);
                    pause_count <= 0;
                end else if (press[1]) begin
                    state <= FIRING;
                end
            end
            DONE: if (press[3]) begin
                piece_id <= new_piece;
                collection <= {collection[11:0], new_piece};
                firing_serial <= firing_serial + 1'b1;
                if (fired_count != 8'hff) fired_count <= fired_count + 1'b1;
                selected_piece <= 0;
                viewing <= 1;
                remaining_s <= seconds_for(duration_sel);
                state <= READY;
            end
        endcase
    end
endmodule

`default_nettype wire
