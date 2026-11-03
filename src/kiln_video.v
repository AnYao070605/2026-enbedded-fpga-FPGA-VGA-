`timescale 1ns/1ps
`default_nettype none

// The scene is drawn on a 96 x 66 logical canvas. All quantities are in
// logical pixels unless they refer to the 640 x 480 text / frame overlay.
module kiln_video (
    input wire pixel_clk,
    input wire [9:0] x,y,
    input wire [1:0] state,duration_sel,
    input wire [10:0] remaining_s,
    input wire [3:0] pause_count,piece_id,
    input wire [7:0] fired_count,
    input wire [15:0] collection,
    input wire [1:0] selected_piece,
    input wire viewing,
    input wire [7:0] anim_frame,
    output reg [15:0] rgb
);
    localparam READY=2'd0, FIRING=2'd1, PAUSED=2'd2, DONE=2'd3;
    localparam [15:0] INK=16'h2126, CARD=16'h2926, RULE=16'h52ad,
        CREAM=16'hff58, STRAW=16'hf570, SAGE=16'h9df5, SOFT=16'hbd31;
    wire gallery=(state==READY && viewing);
    wire [3:0] pot=(selected_piece==0) ? piece_id :
        collection[{selected_piece,2'b0}+:4];
    wire [2:0] occupied=(fired_count>=4) ? 3'd4 : fired_count[2:0];

    // The timer changes once per second. Convert to minutes and seconds by
    // repeated subtraction on spare pixel clocks, never on the raster path.
    reg [10:0] captured=11'h7ff, time_work=0;
    reg [4:0] minute_work=0;
    reg updating=0;
    reg [3:0] m10=0,m1=0,s10=0,s1=0;
    wire [3:0] sec_tens=time_work>=50?5:time_work>=40?4:time_work>=30?3:
                         time_work>=20?2:time_work>=10?1:0;
    always @(posedge pixel_clk) begin
        if(captured!=remaining_s) begin
            captured<=remaining_s;
            time_work<=remaining_s;
            minute_work<=0;
            updating<=1;
        end else if(updating) begin
            if(time_work>=60) begin
                time_work<=time_work-60;
                minute_work<=minute_work+1'b1;
            end else begin
                m10<=minute_work>=20 ? 2 : minute_work>=10 ? 1 : 0;
                m1<=minute_work>=20 ? minute_work-20 : minute_work>=10 ? minute_work-10 : minute_work;
                s10<=sec_tens;
                s1<=time_work[3:0]-{sec_tens[0],3'b000}-{sec_tens[2:0],1'b0};
                updating<=0;
            end
        end
    end
    reg [10:0] q1,q2,q3;
    always @* case(duration_sel)
        0: begin q1=7; q2=15; q3=22; end
        1: begin q1=75; q2=150; q3=225; end
        2: begin q1=225; q2=450; q3=675; end
        default: begin q1=375; q2=750; q3=1125; end
    endcase
    wire [1:0] heat=(remaining_s>q3)?0:(remaining_s>q2)?1:(remaining_s>q1)?2:3;
    wire [9:0] scene_x=x-10'd16,scene_y=y-10'd84;
    wire [6:0] sx=scene_x[8:2],sy=scene_y[8:2];
    wire in_scene=x>=16 && x<400 && y>=84 && y<348;
    wire [6:0] dx=sx>=48 ? sx-7'd48 : 7'd48-sx;
    wire leftside=sx<48;
    reg [5:0] outer_w,inner_w;
    always @* begin
        if(sy<17 || sy>=57) outer_w=0;
        else if(sy<19) outer_w=13;
        else if(sy<21) outer_w=20;
        else if(sy<23) outer_w=25;
        else if(sy<26) outer_w=29;
        else if(sy<30) outer_w=31;
        else outer_w=33;
        if(sy<29 || sy>=52) inner_w=0;
        else if(sy<31) inner_w=6;
        else if(sy<33) inner_w=10;
        else if(sy<36) inner_w=14;
        else if(sy<39) inner_w=16;
        else inner_w=17;
    end
    wire [3:0] brick_x=sx[3:0]+(sy[2]?4'd5:4'd0);
    wire [3:0] flame_phase=sx[3:0]+anim_frame[5:3];
    reg [4:0] flame_h;
    always @* case(flame_phase)
        0,1: flame_h=13;
        2: flame_h=16;
        3,4: flame_h=11;
        5,6: flame_h=7;
        7: flame_h=10;
        8,9: flame_h=14;
        10: flame_h=17;
        11,12: flame_h=12;
        13: flame_h=9;
        default: flame_h=6;
    endcase
    wire [5:0] flame_depth=6'd51-sy[5:0];
    wire [5:0] flame_limit=flame_h+{heat,1'b0};
    wire [15:0] coal=(heat<2)?16'ha963:16'hdb44;
    wire [15:0] flame=(heat==0)?16'hd268:(heat==1)?16'hf368:(heat==2)?16'hf46a:16'hf586;
    wire [15:0] heart=(heat<2)?16'hfc8a:16'hff2f;

    // Four hand-cut silhouettes: round jar, long-neck vase, bowl, amphora.
    wire [5:0] pot_h=sy-7'd12;
    reg [4:0] radius;
    always @* begin
        case(pot[1:0])
            0: begin
                if(pot_h<3) radius=12; else if(pot_h<6) radius=9;
                else if(pot_h<9) radius=14; else if(pot_h<13) radius=19;
                else if(pot_h<19) radius=22; else if(pot_h<29) radius=23;
                else if(pot_h<34) radius=21; else if(pot_h<38) radius=17;
                else radius=12;
            end
            1: begin
                if(pot_h<3) radius=8; else if(pot_h<12) radius=5;
                else if(pot_h<16) radius=8; else if(pot_h<20) radius=14;
                else if(pot_h<24) radius=19; else if(pot_h<29) radius=21;
                else if(pot_h<33) radius=19; else if(pot_h<37) radius=15;
                else radius=10;
            end
            2: begin
                if(pot_h<18) radius=0; else if(pot_h<21) radius=29;
                else if(pot_h<24) radius=27; else if(pot_h<27) radius=26;
                else if(pot_h<30) radius=24; else if(pot_h<33) radius=21;
                else if(pot_h<36) radius=17; else if(pot_h<38) radius=12;
                else radius=9;
            end
            default: begin
                if(pot_h<3) radius=10; else if(pot_h<9) radius=7;
                else if(pot_h<14) radius=13; else if(pot_h<18) radius=17;
                else if(pot_h<23) radius=19; else if(pot_h<28) radius=18;
                else if(pot_h<32) radius=16; else if(pot_h<37) radius=12;
                else radius=8;
            end
        endcase
    end
    // Both the first short trial and the first full focus session feature
    // blue-and-white porcelain. Other recipes retain their own glaze family.
    wire [1:0] glaze_family=(pot==4'h9) ? 2'd1 : pot[3:2];
    reg [15:0] glaze,shadow,light,motif;
    always @* case(glaze_family)
        0: begin glaze=16'h4d59; shadow=16'h2410; light=16'h9ebb; motif=16'hff58; end
        1: begin glaze=16'hf79b; shadow=16'h9db9; light=16'hfffe; motif=16'h1a53; end
        2: begin glaze=16'heca9; shadow=16'hb309; light=16'hf68e; motif=16'h6931; end
        default: begin glaze=16'ha3f4; shadow=16'h6230; light=16'hd596; motif=16'hff58; end
    endcase
    wire [2:0] chevron=sx[3] ? ~sx[2:0] : sx[2:0];
    wire [6:0] zig_y=7'd33+{5'b0,chevron[2:1]};
    // Glaze, silhouette and painted motif respond independently to the firing
    // recipe. Even pieces with the same glaze can wear very different bands.
    reg painted;
    always @* case(pot[3:2]^pot[1:0])
        0: painted=(sy==32 || sy==40 || sy==zig_y || sy==7'd72-zig_y);
        1: painted=(sy==31 || sy==40 || sy==zig_y || sy==zig_y+1);
        2: painted=(sy==31 || sy==40 ||
                   (sy>=33 && sy<=38 && ((sx[2:0]<3) ^ sy[2])));
        default: painted=(sy==32 || sy==33 || sy==37 || sy==38);
    endcase
    reg [15:0] scene_rgb;
    always @* begin
        // A plaster wall, cool window panes and an oak workbench.
        scene_rgb=(sy<45)?16'hb50e:16'h9c6d;
        if(!gallery && sx>=4 && sx<30 && sy>=5 && sy<26) begin
            scene_rgb=16'h4928;
            if(sx>5 && sx<28 && sy>6 && sy<24)
                scene_rgb=(sy<15)?16'h7cf4:16'hae18;
            if(sx==16 || sy==15) scene_rgb=16'h694a;
            if(sx>=7 && sx<=13 && sy>=8 && sy<=13) scene_rgb=16'hf6d3;
        end
        if(!gallery && sx>=76 && sx<92 && sy==27) scene_rgb=16'h596a;
        if(!gallery && sx>=80 && sx<86 && sy>=21 && sy<27) scene_rgb=16'h5370;
        if(!gallery && sx>=81 && sx<85 && sy>=19 && sy<21) scene_rgb=16'h5370;
        if(sy>=54) scene_rgb=(sy<57)?16'h976e:16'hac6f;
        if(sy==57 || sy==63) scene_rgb=16'h8b4b;
        if(!gallery) begin
            // Smoke duct, domed brick body and a masonry arch around the fire.
            if(sx>=57 && sx<68 && sy>=8 && sy<28) scene_rgb=(sx<60)?16'h4928:16'h7349;
            if(sx>=55 && sx<70 && sy>=7 && sy<10) scene_rgb=16'h41a8;
            if(outer_w!=0 && dx<=outer_w)
                scene_rgb = dx==outer_w || sy[1:0]==0 || brick_x==0 || brick_x==8
                    ? 16'h8147 : ((sx[3]^sy[3]) ? 16'hc308 : 16'hba88);
            if(inner_w!=0 && dx<=inner_w+3)
                scene_rgb=(dx==inner_w+3)?16'h8947:16'he48d;
            if(inner_w!=0 && dx<=inner_w) begin
                scene_rgb=16'h3907;
                if(state!=READY) begin
                    scene_rgb=(heat<2) ? 16'h6906 : 16'h91e4;
                    if(flame_depth<flame_limit) scene_rgb=coal;
                    if(flame_depth+3<flame_limit) scene_rgb=flame;
                    if(flame_depth+9<flame_limit) scene_rgb=heart;
                    if(sy>=49 && (sx[2:0]==0 || sx[2:0]==1)) scene_rgb=16'hb267;
                end
            end
            if(dx<36 && sy>=53 && sy<57) scene_rgb=(sy==53)?16'hf4d0:16'h8a07;
            if(dx<38 && sy>=57 && sy<59) scene_rgb=16'h6949;
        end else begin
            // A two-tier pottery plinth with a horizon-line shadow.
            if(dx<35 && sy>=52 && sy<54) scene_rgb=16'hf714;
            if(dx<33 && sy>=54 && sy<56) scene_rgb=16'hc58f;
            if(dx<27 && sy>=56 && sy<60) scene_rgb=16'h8bcd;
            if(sy>=12 && sy<52 && radius!=0 && dx<=radius) begin
                scene_rgb=glaze;
                if(!leftside && dx+6>=radius) scene_rgb=shadow;
                if(leftside && dx+5==radius && pot_h>8 && pot_h<31) scene_rgb=light;
                if(painted) scene_rgb=motif;
                if((sy==26 || sy==43) && sx[2:0]==2) scene_rgb=light;
                if(dx==radius || sy==51) scene_rgb=shadow;
                if((pot[1:0]==2 ? sy==30 : sy==12)) scene_rgb=motif;
                if(glaze_family==1 && (sy==49 || sy==(pot[1:0]==2 ? 31 : 13)))
                    scene_rgb=motif;
            end
        end
    end

    // Header, timer, glaze card and the four context-sensitive key captions.
    localparam NONE=0,TITLE=1,EDITION=2,STATUS=3,SCENE=4,PANEL_ID=5,
        BIG=6,SMALL=7,MID=8,MIDVAL=9,LOW=10,LOWVAL=11,CAPTION=12,
        NUM=13,ACTION=14,HINT=15;
    wire [1:0] key=x<160?0:x<320?1:x<480?2:3;
    wire [9:0] key_l={key,7'b0}+{key,5'b0}+10'd12;
    wire key_on=(key==1 && state!=DONE) || (key==0 && state==READY)
                || (key==2 && state==READY && fired_count!=0)
                || (key==3 && (state==PAUSED || state==DONE || gallery));
    reg [3:0] label;
    reg [9:0] ox,oy;
    reg [1:0] zoom;
    reg [15:0] text_color;
    always @* begin
        label=NONE;ox=0;oy=0;zoom=0;text_color=CREAM;
        if(y>=12 && y<40 && x>=18 && x<338) begin label=TITLE;ox=18;oy=12;zoom=2; end
        else if(y>=24 && y<31 && x>=352 && x<518) begin label=EDITION;ox=352;oy=24;text_color=STRAW; end
        else if(y>=20 && y<27 && x>=533 && x<630) begin label=STATUS;ox=533;oy=20;text_color=SAGE; end
        else if(y>=65 && y<72 && x>=16 && x<407) begin label=SCENE;ox=16;oy=65;text_color=SOFT; end
        else if(y>=65 && y<72 && x>=423 && x<629) begin label=PANEL_ID;ox=423;oy=65;text_color=SOFT; end
        else if(y>=94 && y<101 && x>=423 && x<629) begin label=SMALL;ox=423;oy=94;text_color=SOFT; end
        else if(y>=111 && y<143 && x>=423 && x<631) begin label=BIG;ox=423;oy=111;zoom=gallery?1:2;text_color=STRAW; end
        else if(y>=173 && y<180 && x>=423 && x<629) begin label=MID;ox=423;oy=173;text_color=SOFT; end
        else if(y>=195 && y<213 && x>=423 && x<629) begin label=MIDVAL;ox=423;oy=195;zoom=1; end
        else if(y>=257 && y<264 && x>=423 && x<629) begin label=LOW;ox=423;oy=257;text_color=SOFT; end
        else if(y>=275 && y<291 && x>=423 && x<629) begin label=LOWVAL;ox=423;oy=275;zoom=1; end
        else if(y>=363 && y<370 && x>=16 && x<630) begin label=CAPTION;ox=16;oy=363;text_color=SAGE; end
        else if(y>=424 && y<438 && x>=key_l+28 && x<key_l+142) begin label=ACTION;ox=key_l+28;oy=424;zoom=1;text_color=key_on?CREAM:RULE; end
        else if(y>=424 && y<438 && x>=key_l+6 && x<key_l+20) begin label=NUM;ox=key_l+6;oy=424;zoom=1;text_color=INK; end
        else if(y>=447 && y<454 && x>=key_l+8 && x<key_l+145) begin label=HINT;ox=key_l+8;oy=447;text_color=key_on?SOFT:RULE; end
    end
    wire [9:0] tx=(x-ox)>>zoom,ty=(y-oy)>>zoom;
    wire [6:0] char_index=tx[9:3];
    wire [2:0] glyph_x=tx[2:0],glyph_y=ty[2:0];
    function [7:0] letter;
        input [8*40-1:0] string_value;
        input [6:0] length,index;
        begin
            letter=(index<length)?string_value[(length-1-index)*8+:8]:" ";
        end
    endfunction
    reg [7:0] character;
    always @* begin
        character=" ";
        case(label)
            TITLE: character=letter("FOCUS KILN",10,char_index);
            EDITION: character=letter("POTTERY STUDIO  /  01",21,char_index);
            STATUS: case(state)
                READY: character=gallery?letter("COLLECTION",10,char_index):letter("READY",5,char_index);
                FIRING:character=letter("FIRING",6,char_index);
                PAUSED:character=letter("PAUSED",6,char_index);
                DONE:character=letter("OPEN KILN",9,char_index);
            endcase
            SCENE: character=gallery?letter("01  /  THE GALLERY",18,char_index):letter("01  /  THE KILN ROOM",20,char_index);
            PANEL_ID: character=gallery?letter("02  /  WARE CARD",16,char_index):letter("02  /  FOCUS TIMER",18,char_index);
            SMALL: character=gallery?letter("GLAZE FAMILY",12,char_index):letter("TIME REMAINING",14,char_index);
            BIG: if(gallery) case(glaze_family)
                0:character=letter("COBALT",6,char_index);
                1:character=letter("QINGHUA",7,char_index);
                2:character=letter("AMBER",5,char_index);
                3:character=letter("PLUM",4,char_index);
            endcase else case(char_index)
                0:character="0"+m10;1:character="0"+m1;
                2:character=":";3:character="0"+s10;4:character="0"+s1;
                default:character=" ";
            endcase
            MID: character=gallery?letter("VESSEL FORM",11,char_index):letter("FIRING STAGE",12,char_index);
            MIDVAL: if(gallery) case(pot[1:0])
                0:character=letter("ROUND JAR",9,char_index);1:character=letter("BUD VASE",8,char_index);
                2:character=letter("BOWL",4,char_index);3:character=letter("AMPHORA",7,char_index);
            endcase else if(state==READY) character=letter("COLD",4,char_index);
            else if(state==PAUSED) character=letter("ON HOLD",7,char_index);
            else case(heat)
                0:character=letter("EMBERS",6,char_index);1:character=letter("LOW FIRE",8,char_index);
                2:character=letter("HIGH FIRE",9,char_index);3:character=state==DONE?letter("FIRED",5,char_index):letter("WHITE HEAT",10,char_index);
            endcase
            LOW: character=gallery?letter("SHELF POSITION",14,char_index):letter("PAUSES",6,char_index);
            LOWVAL: if(gallery) case(char_index)
                0:character="1"+selected_piece;1:character=" ";
                2:character="/";3:character=" ";4:character="0"+occupied;
                default:character=" ";
            endcase else case(char_index)
                0:character="0"+(pause_count>=10);
                1:character="0"+((pause_count>=10)?(pause_count-4'd10):pause_count);
                default:character=" ";
            endcase
            CAPTION: if(gallery) character=letter("FIRED WARE  /  THIS POWER SESSION",33,char_index);
                else case(state)
                    READY:character=letter("COLD KILN  /  SELECT TIME AND FIRE",34,char_index);
                    FIRING:character=letter("STOKING  /  KEEP YOUR FOCUS",27,char_index);
                    PAUSED:character=letter("ON HOLD  /  RESUME WHEN READY",29,char_index);
                    DONE:character=letter("READY TO UNLOAD  /  PRESS SW4",29,char_index);
                endcase
            NUM: if(char_index==0) character="1"+key;
            ACTION: case(key)
                0:character=letter("TIME",4,char_index);
                1:character=state==PAUSED?letter("RESUME",6,char_index):state==FIRING?letter("PAUSE",5,char_index):letter("FIRE",4,char_index);
                2:character=letter("SHELF",5,char_index);
                3:character=gallery?letter("CLOSE",5,char_index):state==PAUSED?letter("EXIT",4,char_index):letter("OPEN",4,char_index);
            endcase
            HINT: case(key)
                0:character=letter("NEXT PRESET",11,char_index);
                1:character=state==PAUSED?letter("CONTINUE",8,char_index):state==FIRING?letter("HOLD SESSION",12,char_index):letter("START SESSION",13,char_index);
                2:character=letter("BROWSE PIECES",13,char_index);
                3:character=gallery?letter("BACK TO TIMER",13,char_index):state==PAUSED?letter("HOLD 2S TO EXIT",15,char_index):letter("UNLOAD KILN",11,char_index);
            endcase
            default:character=" ";
        endcase
    end
    function [34:0] font;
        input [7:0] ch;
        begin
            case(ch)
                "0":font={5'h0e,5'h11,5'h13,5'h15,5'h19,5'h11,5'h0e};
                "1":font={5'h04,5'h0c,5'h04,5'h04,5'h04,5'h04,5'h0e};
                "2":font={5'h0e,5'h11,5'h01,5'h02,5'h04,5'h08,5'h1f};
                "3":font={5'h1e,5'h01,5'h01,5'h0e,5'h01,5'h01,5'h1e};
                "4":font={5'h02,5'h06,5'h0a,5'h12,5'h1f,5'h02,5'h02};
                "5":font={5'h1f,5'h10,5'h10,5'h1e,5'h01,5'h01,5'h1e};
                "6":font={5'h06,5'h08,5'h10,5'h1e,5'h11,5'h11,5'h0e};
                "7":font={5'h1f,5'h01,5'h02,5'h04,5'h08,5'h08,5'h08};
                "8":font={5'h0e,5'h11,5'h11,5'h0e,5'h11,5'h11,5'h0e};
                "9":font={5'h0e,5'h11,5'h11,5'h0f,5'h01,5'h02,5'h0c};
                "A":font={5'h0e,5'h11,5'h11,5'h1f,5'h11,5'h11,5'h11};
                "B":font={5'h1e,5'h11,5'h11,5'h1e,5'h11,5'h11,5'h1e};
                "C":font={5'h0f,5'h10,5'h10,5'h10,5'h10,5'h10,5'h0f};
                "D":font={5'h1e,5'h11,5'h11,5'h11,5'h11,5'h11,5'h1e};
                "E":font={5'h1f,5'h10,5'h10,5'h1e,5'h10,5'h10,5'h1f};
                "F":font={5'h1f,5'h10,5'h10,5'h1e,5'h10,5'h10,5'h10};
                "G":font={5'h0f,5'h10,5'h10,5'h17,5'h11,5'h11,5'h0f};
                "H":font={5'h11,5'h11,5'h11,5'h1f,5'h11,5'h11,5'h11};
                "I":font={5'h0e,5'h04,5'h04,5'h04,5'h04,5'h04,5'h0e};
                "L":font={5'h10,5'h10,5'h10,5'h10,5'h10,5'h10,5'h1f};
                "M":font={5'h11,5'h1b,5'h15,5'h15,5'h11,5'h11,5'h11};
                "N":font={5'h11,5'h19,5'h19,5'h15,5'h13,5'h13,5'h11};
                "O":font={5'h0e,5'h11,5'h11,5'h11,5'h11,5'h11,5'h0e};
                "P":font={5'h1e,5'h11,5'h11,5'h1e,5'h10,5'h10,5'h10};
                "R":font={5'h1e,5'h11,5'h11,5'h1e,5'h14,5'h12,5'h11};
                "S":font={5'h0f,5'h10,5'h10,5'h0e,5'h01,5'h01,5'h1e};
                "T":font={5'h1f,5'h04,5'h04,5'h04,5'h04,5'h04,5'h04};
                "U":font={5'h11,5'h11,5'h11,5'h11,5'h11,5'h11,5'h0e};
                "V":font={5'h11,5'h11,5'h11,5'h11,5'h11,5'h0a,5'h04};
                "W":font={5'h11,5'h11,5'h11,5'h15,5'h15,5'h1b,5'h11};
                "X":font={5'h11,5'h11,5'h0a,5'h04,5'h0a,5'h11,5'h11};
                "Y":font={5'h11,5'h11,5'h0a,5'h04,5'h04,5'h04,5'h04};
                "/":font={5'h01,5'h01,5'h02,5'h04,5'h08,5'h10,5'h10};
                "+":font={5'h00,5'h04,5'h04,5'h1f,5'h04,5'h04,5'h00};
                "J":font={5'h07,5'h02,5'h02,5'h02,5'h12,5'h12,5'h0c};
                "K":font={5'h11,5'h12,5'h14,5'h18,5'h14,5'h12,5'h11};
                "Q":font={5'h0e,5'h11,5'h11,5'h11,5'h15,5'h12,5'h0d};
                "Z":font={5'h1f,5'h01,5'h02,5'h04,5'h08,5'h10,5'h1f};
                ":":font={5'h00,5'h04,5'h04,5'h00,5'h04,5'h04,5'h00};
                "-":font={5'h00,5'h00,5'h00,5'h1f,5'h00,5'h00,5'h00};
                default: font=0;
            endcase
        end
    endfunction
    wire [34:0] glyph=font(character);
    wire text_pixel=(ty<7 && glyph_x<5) && glyph[34-glyph_y*5-glyph_x];
    always @* begin
        rgb=INK;
        if(y<51) rgb=CARD;
        if(y==50 || (y==385 && x>=16 && x<624) || (x==410 && y>=64 && y<348)) rgb=RULE;
        if(x>=523 && x<627 && y>=12 && y<37) rgb=16'h3930;
        if(in_scene) rgb=scene_rgb;
        if(x>=423 && x<621 && (y==155 || y==237 || y==319)) rgb=RULE;
        if(!gallery && x>=423 && x<611 && y>=220 && y<226) begin
            if(x<467 || (x>=471&&x<515) || (x>=519&&x<563) || x>=567)
                rgb=(state==READY || (x>=471 && heat<1) || (x>=519 && heat<2) || (x>=567 && heat<3))
                    ? RULE : STRAW;
        end
        if(gallery && x>=423 && x<521 && y>=222 && y<228) rgb=glaze;
        if(x>=key_l && x<key_l+146 && y>=410 && y<465) rgb=CARD;
        if(x>=key_l+3 && x<key_l+23 && y>=420 && y<442) rgb=key_on?STRAW:RULE;
        if(text_pixel) rgb=text_color;
    end
endmodule
`default_nettype wire

