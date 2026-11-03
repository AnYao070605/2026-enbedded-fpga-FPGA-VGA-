`timescale 1ns/1ps

// Exercise the physical low-active inputs and the timer through the board top.
// Shorten the second and the interval between debounce samples for simulation.
module tb_kiln_board;
    localparam integer SECOND = 256;
    reg sys_clk = 0, fast_frame = 0;
    reg [3:0] buttons = 4'hf;
    wire [15:0] rgb;
    wire hs, vs;
    top_kiln #(.TICKS_PER_SECOND(SECOND), .CANCEL_HOLD_FRAMES(12)) dut (
        .sys_clk(sys_clk), .buttons_raw(buttons),
        .vga_d(rgb), .vga_hs(hs), .vga_vs(vs)
    );
    always #10 sys_clk = !sys_clk;

    task automatic frame;
        repeat(8) @(negedge dut.pixel_clk);
        fast_frame = 1;
        @(negedge dut.pixel_clk);
        fast_frame = 0;
    endtask
    task automatic tap(input integer i);
        buttons[i] = 0; repeat(2) frame;
        buttons[i] = 1; repeat(2) frame;
    endtask

    integer ticks_left, hold_phase;
    reg [7:0] frozen_frame;
    reg [15:0] old_collection;
    initial begin
        force dut.frame_tick = fast_frame;
        wait(dut.reset === 1'b0); @(negedge dut.pixel_clk);
        if (dut.remaining_s !== 30 || dut.fired_count !== 0 || dut.viewing !== 0)
            $fatal(1,"Empty 30-second trial expected at cold start");
        buttons[1] = 0; frame; buttons[1] = 1; repeat(3) frame;
        if (dut.state !== 0) $fatal(1,"Contact bounce ignited the kiln");

        buttons[1] = 0; repeat(2) frame;
        buttons[1] = 1;
        if (dut.state !== 1 || dut.remaining_s !== 30)
            $fatal(1,"Physical SW2 ignition failed");
        repeat(SECOND-1) @(posedge dut.pixel_clk); #1;
        if (dut.remaining_s !== 30) $fatal(1,"First second expired too early");
        @(posedge dut.pixel_clk); #1;
        if (dut.remaining_s !== 29) $fatal(1,"First second expired too late");

        repeat(2) frame;
        tap(1);
        if (dut.state !== 2 || dut.pause_count !== 1) $fatal(1,"Pause failed");
        hold_phase=dut.second_phase; frozen_frame=dut.anim_frame;
        repeat(40) frame;
        if (dut.remaining_s !== 29 || dut.second_phase !== hold_phase ||
            dut.anim_frame !== frozen_frame) $fatal(1,"Pause leaked time or animation");
        buttons[1]=0; repeat(2) frame; buttons[1]=1;
        if (dut.state !== 1) $fatal(1,"Resume failed");
        ticks_left = SECOND-hold_phase;
        repeat(ticks_left-1) @(posedge dut.pixel_clk); #1;
        if(dut.remaining_s !== 29) $fatal(1,"Resume shortened the fractional second");
        @(posedge dut.pixel_clk); #1;
        if(dut.remaining_s !== 28) $fatal(1,"Resume lost the fractional second");
        repeat(28*SECOND) @(posedge dut.pixel_clk); #1;
        if(dut.state !== 3 || dut.remaining_s !== 0 || dut.fired_count !== 0)
            $fatal(1,"Completed firing must wait for manual unloading");
        tap(3);
        if(dut.state !== 0 || !dut.viewing || dut.fired_count !== 1 ||
           dut.collection[3:0] !== dut.piece_id) $fatal(1,"Unloading or gallery failed");
        old_collection=dut.collection;
        tap(3); tap(2);
        if(!dut.viewing || dut.selected_piece !== 0) $fatal(1,"SW3 gallery failed");
        tap(0);
        if(dut.viewing || dut.remaining_s !== 300) $fatal(1,"SW1 preset failed");
        tap(1); tap(1);
        if(dut.state !== 2) $fatal(1,"Second firing failed to pause");
        tap(3);
        if(dut.state !== 2) $fatal(1,"Brief SW4 tap discarded a firing");
        buttons[3]=0; repeat(18) frame; buttons[3]=1; repeat(2) frame;
        if(dut.state !== 0 || dut.remaining_s !== 300 ||
           dut.fired_count !== 1 || dut.collection !== old_collection)
            $fatal(1,"Long-press cancellation failed to preserve finished ceramics");
        $display("PASS: four debounced buttons, exact timer phase across ignition and pause, animation freeze, unloading, gallery and long-press cancellation");
        $finish;
    end
    initial begin #3000000; $fatal(1,"Board control simulation timed out"); end
endmodule
