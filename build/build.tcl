# =============================================================================
# build.tcl - Reproducible Vivado build for porcelain-clock
# From a Vivado command prompt:
#   vivado -mode batch -source build/build.tcl
# =============================================================================

set script_dir [file dirname [file normalize [info script]]]
set root      [file normalize [file join $script_dir ".."]]
set src_dir   [file join $root "src"]
set sim_dir   [file join $root "sim"]
set board_dir [file join $root "board"]
set work      [file join $script_dir "vivado_out"]
set reports   [file join $script_dir "reports"]
file mkdir $work
file mkdir $reports
file mkdir $board_dir

set xpr [file join $work "kiln_demo.xpr"]
if {[file exists $xpr]} {
    open_project $xpr
    reset_run synth_1
} else {
    create_project kiln_demo $work -part xc7a35tfgg484-2
    add_files -norecurse [list \
        [file join $src_dir "top_kiln.v"] \
        [file join $src_dir "kiln_core.v"] \
        [file join $src_dir "kiln_video.v"]]
    add_files -fileset constrs_1 -norecurse [file join $src_dir "board.xdc"]
    add_files -fileset sim_1 -norecurse [list \
        [file join $sim_dir "tb_kiln_core.sv"] \
        [file join $sim_dir "tb_kiln_board.sv"] \
        [file join $sim_dir "tb_kiln_preview.sv"]]
    set_property top top_kiln [current_fileset]
    update_compile_order -fileset sources_1
}

proc finish_step {run step} {
    wait_on_run $run
    set status [get_property STATUS [get_runs $run]]
    if {$status ne "$step Complete!"} {error "$run stopped: $status"}
}

launch_runs synth_1 -jobs 2
finish_step synth_1 synth_design
launch_runs impl_1 -to_step write_bitstream -jobs 2
finish_step impl_1 write_bitstream

open_run impl_1
report_utilization   -file [file join $reports "utilization.rpt"]
report_clocks        -file [file join $reports "clocks.rpt"]
report_io            -file [file join $reports "io.rpt"]
report_timing_summary -report_unconstrained -file [file join $reports "timing.rpt"]
report_drc           -file [file join $reports "drc.rpt"]

set violations [get_drc_violations -quiet -filter {SEVERITY == "Error" || SEVERITY == "Critical Warning"}]
if {[llength $violations]} {error "DRC failed: $violations"}
foreach type {max min} {
    set path [get_timing_paths -delay_type $type -max_paths 1]
    if {![llength $path] || [get_property SLACK $path] < 0} {error "Timing failed ($type)"}
}
close_design

set bit [file join [get_property DIRECTORY [get_runs impl_1]] "top_kiln.bit"]
set mcs [file join $work "porcelain_clock.mcs"]
write_cfgmem -force -format mcs -interface SPIx4 -size 16 \
    -loadbit [list up 0x00000000 $bit] -file $mcs

file copy -force $bit [file join $board_dir "porcelain_clock.bit"]
file copy -force $mcs [file join $board_dir "porcelain_clock.mcs"]
puts "Build done. Reports in $reports, images in $board_dir"
