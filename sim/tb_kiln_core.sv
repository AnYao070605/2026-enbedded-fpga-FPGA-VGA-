`timescale 1ns/1ps

module tb_kiln_core;
    localparam READY=0, FIRING=1, PAUSED=2, DONE=3;
    reg clk=0, reset=1, tick_second=0, cancel_hold=0;
    reg [3:0] press=0;
    wire [1:0] state, duration_sel, selected_piece;
    wire [10:0] remaining_s;
    wire [3:0] pause_count, piece_id;
    wire [7:0] fired_count;
    wire [15:0] collection;
    wire viewing;
    always #5 clk=~clk;
    kiln_core dut(.*);

    task cycle(input [3:0] keys, input bit second, input bit cancel);
        @(negedge clk);
        press=keys; tick_second=second; cancel_hold=cancel;
        @(posedge clk); #1;
    endtask

    task key(input int num);
        cycle(1 << (num-1), 0, 0);
        cycle(0, 0, 0);
    endtask

    task restart_core;
        @(negedge clk);
        reset=1; press=0; tick_second=0; cancel_hold=0;
        @(posedge clk); #1; reset=0;
        if (state!==READY || remaining_s!==30 || duration_sel!==0 ||
            pause_count!==0 || viewing!==0 || fired_count!==0 ||
            selected_piece!==0 || collection!==0)
            $fatal(1,"Reset did not produce an empty 30 s kiln");
    endtask

    task fire_to_done(input int duration, input int pauses);
        // Coincident SW2/tick transitions never charge an unearned second.
        cycle(4'b0010,1,0);
        if (state!==FIRING || remaining_s!==duration || pause_count!==0 || viewing)
            $fatal(1,"Bad ignition");
        for (int i=0; i<pauses; i++) begin
            cycle(4'b0010,1,0);
            if (state!==PAUSED || remaining_s!==duration || pause_count!==(i<15 ? i+1 : 15))
                $fatal(1,"Bad pause state, count or boundary");
            cycle(4'b1101,1,0);
            if (state!==PAUSED || remaining_s!==duration)
                $fatal(1,"Paused timer moved or unrelated keys changed its state");
            cycle(4'b0010,1,0);
            if (state!==FIRING || remaining_s!==duration)
                $fatal(1,"Resume charged a second too early");
        end
        for (int left=duration-1; left>=0; left--) begin
            cycle(4'b1101,1,0); // selection, gallery and open are ignored while firing
            if (remaining_s!==left || state!==(left==0 ? DONE : FIRING))
                $fatal(1,"Countdown error at %0d",left);
        end
        cycle(4'b0111,1,1);
        if (remaining_s!==0 || state!==DONE)
            $fatal(1,"Finished kiln should await SW4");
    endtask

    integer durations[0:3];
    integer expected_selected;
    reg [3:0] expected_style;
    reg [15:0] expected_shelf;
    initial begin
        durations[0]=30; durations[1]=300; durations[2]=900; durations[3]=1500;
        for (int sel=0; sel<4; sel++) begin
            restart_core;
            key(3); key(4);
            if (viewing || fired_count!==0) $fatal(1,"An empty shelf was displayed");
            repeat (sel) key(1);
            if (duration_sel!==sel || remaining_s!==durations[sel])
                $fatal(1,"Incorrect preset");
            fire_to_done(durations[sel],0);
            if (fired_count!==0) $fatal(1,"Unopened kiln counted as completed");
            key(4);
            expected_style=4'h6 ^ (sel*5);
            if (piece_id!==expected_style || collection!==expected_style || !viewing ||
                fired_count!==1 || selected_piece!==0 || state!==READY)
                $fatal(1,"Preset did not produce expected piece");
            key(1);
            if (viewing || duration_sel!==((sel+1)%4)) $fatal(1,"Selection did not wrap");
        end
        $display("PASS: all four time presets, exact second boundaries, distinct duration glazes");

        restart_core;
        fire_to_done(30,1); key(4);
        if (piece_id!==4'h4 || fired_count!==1) $fatal(1,"Pause did not affect glaze");
        key(2); repeat (9) cycle(0,1,0);
        key(2);
        if (remaining_s!==21 || state!==PAUSED) $fatal(1,"Unexpected pause before cancellation");
        key(4);
        if (state!==PAUSED) $fatal(1,"A short SW4 discarded a batch");
        cycle(4'b0010,1,1);
        if (state!==READY || remaining_s!==30 || fired_count!==1 || collection!==16'h0004 ||
            viewing || pause_count!==0)
            $fatal(1,"Cancellation should spare the shelf, discard current batch, reset timer");
        fire_to_done(30,18);
        if (pause_count!==15) $fatal(1,"Pause count wrapped");
        key(4);
        $display("PASS: paused time is frozen, short SW4 preserved batch, cancel preserved gallery, pause count saturates");

        restart_core;
        expected_shelf=0;
        for (int i=0; i<258; i++) begin
            fire_to_done(30,0); key(4);
            expected_style=(i%16)^6;
            expected_shelf={expected_shelf[11:0],expected_style};
            if (piece_id!==expected_style || collection!==expected_shelf ||
                fired_count!==(i>=254 ? 255 : i+1) || selected_piece!==0 || !viewing)
                $fatal(1,"Serial, shelf or total off at batch %0d",i);
            if (i<6) begin
                for (int j=1; j<7; j++) begin
                    key(3);
                    expected_selected=j%(i>=3 ? 4 : i+1);
                    if (selected_piece!==expected_selected) $fatal(1,"Gallery index out of range");
                end
                key(4);
                if (viewing) $fatal(1,"SW4 should leave the gallery");
                key(3);
                if (!viewing || selected_piece!==0) $fatal(1,"Gallery should reopen on newest");
            end
        end
        $display("PASS: newest-four gallery, wrap, unit total saturation and firing serial continuity through 258 openings");
        $finish;
    end
    initial begin #1000000; $fatal(1,"Timer test timeout"); end
endmodule
