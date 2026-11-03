`timescale 1ns / 1ps
`default_nettype none

module top_kiln #(
    parameter integer TICKS_PER_SECOND = 25200000,
    parameter integer CANCEL_HOLD_FRAMES = 120
) (
    input  wire        sys_clk,
    input  wire [3:0]  buttons_raw,
    (* IOB = "TRUE" *) output reg [15:0] vga_d,
    (* IOB = "TRUE" *) output reg        vga_hs,
    (* IOB = "TRUE" *) output reg        vga_vs
);
    localparam [1:0] READY = 0, FIRING = 1, PAUSED = 2, DONE = 3;
    wire feedback_raw, feedback_clk, pixel_raw, pixel_clk, locked;
    MMCME2_BASE #(
        .CLKIN1_PERIOD(20.0), .DIVCLK_DIVIDE(4),
        .CLKFBOUT_MULT_F(63.0), .CLKOUT0_DIVIDE_F(31.25)
    ) pixel_mmcm (
        .CLKIN1(sys_clk), .CLKFBIN(feedback_clk), .CLKFBOUT(feedback_raw),
        .CLKOUT0(pixel_raw), .LOCKED(locked), .RST(1'b0), .PWRDWN(1'b0),
        .CLKFBOUTB(), .CLKOUT0B(), .CLKOUT1(), .CLKOUT1B(), .CLKOUT2(),
        .CLKOUT2B(), .CLKOUT3(), .CLKOUT3B(), .CLKOUT4(), .CLKOUT5(), .CLKOUT6()
    );
    BUFG feedback_buffer (.I(feedback_raw), .O(feedback_clk));
    BUFG pixel_buffer    (.I(pixel_raw),    .O(pixel_clk));
    (* ASYNC_REG = "TRUE" *) reg [2:0] reset_pipe = 3'b111;
    always @(posedge pixel_clk or negedge locked) begin
        if (!locked) reset_pipe <= 3'b111;
        else         reset_pipe <= {reset_pipe[1:0], 1'b0};
    end
    wire reset = reset_pipe[2];

    reg [9:0] x, y;
    always @(posedge pixel_clk) begin
        if (reset) begin
            x <= 0;
            y <= 0;
        end else if (x == 799) begin
            x <= 0;
            y <= (y == 524) ? 10'd0 : y + 1'b1;
        end else begin
            x <= x + 1'b1;
        end
    end
    wire frame_tick = (x == 0 && y == 480);

    // Each button must agree on two successive frame samples. The frame
    // strobe limits a press to exactly one pixel-clock pulse, even when held.
    (* ASYNC_REG = "TRUE" *) reg [3:0] sync1, sync2;
    reg [3:0] previous, held;
    wire [3:0] down = ~sync2;
    wire [3:0] press = {4{frame_tick}} & down & previous & ~held;
    always @(posedge pixel_clk) begin
        if (reset) begin
            sync1 <= 4'hf;
            sync2 <= 4'hf;
            previous <= 0;
            held <= 0;
        end else begin
            sync1 <= buttons_raw;
            sync2 <= sync1;
            if (frame_tick) begin
                previous <= down;
                held <= (down & previous) | (held & (down | previous));
            end
        end
    end

    wire [1:0] state, duration_sel, selected_piece;
    wire [10:0] remaining_s;
    wire [3:0] pause_count, piece_id;
    wire [7:0] fired_count;
    wire [15:0] collection;
    wire viewing;

    // Measure only active firing time, preserving partial seconds on pause.
    localparam PHASE_BITS = TICKS_PER_SECOND < 2 ? 1 : $clog2(TICKS_PER_SECOND);
    reg [PHASE_BITS-1:0] second_phase;
    wire running = (state == FIRING && !press[1]);
    wire tick_second = running && (second_phase == TICKS_PER_SECOND-1);
    always @(posedge pixel_clk) begin
        if (reset || state == READY || state == DONE || tick_second)
            second_phase <= 0;
        else if (running)
            second_phase <= second_phase + 1'b1;
    end

    // A long SW4 gesture must begin during PAUSED. A tap or a press carried
    // in from another state cannot discard the firing session.
    localparam HOLD_BITS = CANCEL_HOLD_FRAMES < 2 ? 1 : $clog2(CANCEL_HOLD_FRAMES);
    reg [HOLD_BITS-1:0] hold_frames;
    reg cancel_armed;
    wire cancel_hold = state == PAUSED && frame_tick && cancel_armed &&
                       down[3] && held[3] && hold_frames == CANCEL_HOLD_FRAMES-1;
    always @(posedge pixel_clk) begin
        if (reset || state != PAUSED) begin
            hold_frames <= 0;
            cancel_armed <= 0;
        end else if (frame_tick) begin
            if (press[3]) begin
                hold_frames <= 0;
                cancel_armed <= 1;
            end else if (!down[3] || cancel_hold) begin
                hold_frames <= 0;
                cancel_armed <= 0;
            end else if (cancel_armed)
                hold_frames <= hold_frames + 1'b1;
        end
    end

    reg [7:0] anim_frame;
    always @(posedge pixel_clk) begin
        if (reset) anim_frame <= 0;
        else if (frame_tick && ((state == READY && !viewing) || running))
            anim_frame <= anim_frame + 1'b1;
    end
    kiln_core core (
        .clk(pixel_clk), .reset(reset), .tick_second(tick_second),
        .press(press), .cancel_hold(cancel_hold), .state(state), .duration_sel(duration_sel),
        .remaining_s(remaining_s), .pause_count(pause_count), .piece_id(piece_id),
        .fired_count(fired_count), .collection(collection),
        .selected_piece(selected_piece), .viewing(viewing)
    );
    wire [15:0] rgb;
    kiln_video renderer (
        .pixel_clk(pixel_clk), .x(x), .y(y), .state(state), .duration_sel(duration_sel),
        .remaining_s(remaining_s), .pause_count(pause_count), .piece_id(piece_id),
        .fired_count(fired_count), .collection(collection), .selected_piece(selected_piece),
        .viewing(viewing), .anim_frame(anim_frame), .rgb(rgb)
    );
    always @(posedge pixel_clk) begin
        vga_d  <= (!reset && x < 640 && y < 480) ? rgb : 16'b0;
        vga_hs <= reset || !(x >= 656 && x < 752);
        vga_vs <= reset || !(y >= 490 && y < 492);
    end
endmodule

`default_nettype wire
