`timescale 1ns/1ps
// Preview the real core and its RGB565 renderer. Accelerate time by injecting
// logical seconds, then enumerate the 640x480 active raster for each still.
module tb_kiln_preview;
    reg clk=0,reset=1,tick_second=0;
    reg [3:0] press=0;
    reg [7:0] anim_frame=0;
    reg [9:0] x=0,y=0;
    wire [1:0] state,duration_sel,selected_piece;
    wire [10:0] remaining_s;
    wire [3:0] pause_count,piece_id;
    wire [7:0] fired_count;
    wire [15:0] collection,rgb;
    wire viewing;
    kiln_core core(.clk(clk),.reset(reset),.tick_second(tick_second),
        .cancel_hold(1'b0),.press(press),.state(state),.duration_sel(duration_sel),
        .remaining_s(remaining_s),.pause_count(pause_count),.piece_id(piece_id),
        .fired_count(fired_count),.collection(collection),
        .selected_piece(selected_piece),.viewing(viewing));
    kiln_video screen(.pixel_clk(clk),.x(x),.y(y),.state(state),.duration_sel(duration_sel),
        .remaining_s(remaining_s),.pause_count(pause_count),.piece_id(piece_id),
        .fired_count(fired_count),.collection(collection),.selected_piece(selected_piece),
        .viewing(viewing),.anim_frame(anim_frame),.rgb(rgb));
    task tick;
        begin #5;clk=1;#5;clk=0;end
    endtask
    task button(input integer index);
        begin press[index]=1;tick;press=0;tick;end
    endtask
    task seconds(input integer n);
        integer i;
        begin
            for(i=0;i<n;i=i+1)begin
                tick_second=1;tick;tick_second=0;tick;
                if(state==1) anim_frame=anim_frame+8'd60;
            end
        end
    endtask
    task snap(input integer id);
        reg [8*40-1:0] name;
        integer fd,ix,iy;
        reg [7:0] r,g,b;
        begin
            repeat(40)tick;
            if ({screen.m10,screen.m1,screen.s10,screen.s1} !==
                ((remaining_s/600)*4096+((remaining_s/60)%10)*256+
                 ((remaining_s%60)/10)*16+(remaining_s%10)))
                $fatal(1,"Timer digits differ from seconds");
            $sformat(name,"kiln%02d.ppm",id);
            fd=$fopen(name,"wb");if(!fd)$fatal(1,"Cannot open preview");
            $fwrite(fd,"P6\n640 480\n255\n");
            for(iy=0;iy<480;iy=iy+1)for(ix=0;ix<640;ix=ix+1)begin
                x=ix;y=iy;#1;
                if(^rgb===1'bx)$fatal(1,"Unknown pixel");
                r={rgb[15:11],rgb[15:13]};g={rgb[10:5],rgb[10:9]};b={rgb[4:0],rgb[4:2]};
                $fwrite(fd,"%c%c%c",r,g,b);
            end
            $fclose(fd);
            $display("FRAME %0d STATE=%0d SEC=%0d PAUSES=%0d GALLERY=%0d RECIPE=%0d",
                     id,state,remaining_s,pause_count,viewing,piece_id);
        end
    endtask
    initial begin
        tick;tick;reset=0;tick;snap(0);
        button(1);snap(1);
        seconds(8);snap(2);
        button(1);seconds(5);
        if(remaining_s!=22 || state!=2)$fatal(1,"Pause failed");
        snap(3);
        button(1);seconds(9);snap(4);
        seconds(8);snap(5);
        seconds(4);snap(6);
        seconds(1);snap(7);
        if(state!=3)$fatal(1,"No unload prompt");
        button(3);snap(8);
        if(!viewing || piece_id!=4 || fired_count!=1)$fatal(1,"Unexpected finished vessel");
        if(screen.glaze_family!=1 || screen.glaze!=16'hf79b || screen.motif!=16'h1a53)
            $fatal(1,"Trial did not render the blue-and-white glaze");
        $display("PASS: 30-second trial, one pause, finished Qinghua round jar");

        reset=1;tick;reset=0;tick;
        button(0);button(0);button(0);
        if(remaining_s!=1500 || duration_sel!=3)$fatal(1,"25-minute preset failed");
        snap(9);
        button(1);seconds(630);snap(10);
        seconds(870);button(3);snap(11);
        if(piece_id!=9 || screen.glaze_family!=1 || !viewing)
            $fatal(1,"25-minute first uninterrupted firing did not give a Qinghua vase");
        reset=1;tick;reset=0;tick;button(1);seconds(30);button(3);snap(12);
        if(piece_id!=6 || screen.glaze_family!=1 || !viewing)
            $fatal(1,"Uninterrupted trial did not give a Qinghua bowl");
        $display("PASS: 25-minute focus vase and short trial bowl in Qinghua family");$finish;
    end
endmodule
