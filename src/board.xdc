# Zhengzhan Core V3 U15B + Cam_Vga_V1 J1. Module pin 1 mates with U15B.100.
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property IOSTANDARD LVCMOS33 [get_ports *]
set_property PACKAGE_PIN Y18 [get_ports sys_clk]
create_clock -name sys_clk -period 20.000 [get_ports sys_clk]

# SW1 through SW4, active low. Each input feeds a two-register synchronizer.
set_property PACKAGE_PIN H5  [get_ports {buttons_raw[0]}]
set_property PACKAGE_PIN L13 [get_ports {buttons_raw[1]}]
set_property PACKAGE_PIN G17 [get_ports {buttons_raw[2]}]
set_property PACKAGE_PIN G18 [get_ports {buttons_raw[3]}]
set_false_path -from [get_ports {buttons_raw[*]}]

# Module J1.3 through J1.18 in descending color-bit order.
set_property PACKAGE_PIN P1 [get_ports {vga_d[15]}]
set_property PACKAGE_PIN R1 [get_ports {vga_d[14]}]
set_property PACKAGE_PIN N2 [get_ports {vga_d[13]}]
set_property PACKAGE_PIN P2 [get_ports {vga_d[12]}]
set_property PACKAGE_PIN L1 [get_ports {vga_d[11]}]
set_property PACKAGE_PIN M1 [get_ports {vga_d[10]}]
set_property PACKAGE_PIN J1 [get_ports {vga_d[9]}]
set_property PACKAGE_PIN K1 [get_ports {vga_d[8]}]
set_property PACKAGE_PIN G2 [get_ports {vga_d[7]}]
set_property PACKAGE_PIN H2 [get_ports {vga_d[6]}]
set_property PACKAGE_PIN F1 [get_ports {vga_d[5]}]
set_property PACKAGE_PIN G1 [get_ports {vga_d[4]}]
set_property PACKAGE_PIN D1 [get_ports {vga_d[3]}]
set_property PACKAGE_PIN E1 [get_ports {vga_d[2]}]
set_property PACKAGE_PIN B2 [get_ports {vga_d[1]}]
set_property PACKAGE_PIN C2 [get_ports {vga_d[0]}]
set_property PACKAGE_PIN A1 [get_ports vga_hs]
set_property PACKAGE_PIN B1 [get_ports vga_vs]
set_property DRIVE 8 [get_ports {vga_d[*] vga_hs vga_vs}]
set_property SLEW SLOW [get_ports {vga_d[*] vga_hs vga_vs}]

# The analog VGA interface does not forward a clock. Budget half a pixel for
# FPGA launch-to-pin settling, referenced to the actual MMCM-generated clock.
set_output_delay -clock [get_clocks -of_objects [get_pins pixel_mmcm/CLKOUT0]] -max 19.840 [get_ports {vga_d[*] vga_hs vga_vs}]
set_output_delay -clock [get_clocks -of_objects [get_pins pixel_mmcm/CLKOUT0]] -min 0.000 [get_ports {vga_d[*] vga_hs vga_vs}]
