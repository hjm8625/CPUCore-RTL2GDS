# set pdk_root, stdcell_root
# some paramters are referenced by OpenROAD flow script sky130HD
set pdk_root /home/a0109/pdks/share/pdk/sky130A
set stdcell_root $pdk_root/libs.ref/sky130_fd_sc_hd

###step1: informations
# Routing layers and physical design rules
read_lef $stdcell_root/techlef/sky130_fd_sc_hd__nom.tlef

# Standard-cell
read_lef $stdcell_root/lef/sky130_fd_sc_hd.lef

# Typical timing and power model: 1.80 V, 25 C.
read_liberty $stdcell_root/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

# SKY130 CPUCore netlist
read_verilog build/CPUCore_sky130.v
link_design CPUCore

# using sdc
read_sdc constraints/cpucore.sdc

#############################################
#I recommend to write down these tcl in openroad GUI
#It is easy to watch it directly

### step2: initialize floorplan
# this is first attempt, so I use parameters easily.
# hd lef-> site unithd 
initialize_floorplan \
    -utilization 50 \
    -aspect_ratio 1.0 \
    -core_space 20 \
    -site unithd

make_tracks

# result save
report_design_area
write_def build/CPUCore_2_floorplan.def
#############################################

### step3: Pin placement
# module CPUCore(
#   input       clk,
#   input       rst,
#   input         imem_ready,
#   input  [31:0] imem_rdata,
#   input         dmem_ready,
#   input  [31:0] dmem_rdata
#   output        imem_req,
#   output [31:0] imem_addr,
#   output        dmem_req,
#   output        dmem_read,
#   output        dmem_write,
#   output [31:0] dmem_addr,
#   output [31:0] dmem_wdata,
#   );

# set i/o pins
# for now, the direction is placed simply 
set_io_pin_constraint \
    -pin_names {clk rst} \
    -region left:*

set_io_pin_constraint \
    -pin_names {imem_req imem_ready imem_addr* imem_rdata*} \
    -region top:* \
    -group \
    -order

set_io_pin_constraint \
    -pin_names {dmem_req dmem_ready dmem_read dmem_write dmem_addr* dmem_wdata* dmem_rdata*} \
    -region right:* \
    -group \
    -order

# in SKY130 hd tlef, it shows that met2: vertical, met3: horizontal
place_pins \
    -hor_layers met3 \
    -ver_layers met2 \
    -corner_avoidance 5

write_def build/CPUCore_3_iopins.def

### step4: global connection and tapcell
# Connect SKY130 power(VPWR-VGND) and body(VPB-VNB)
add_global_connection \
    -net VDD \
    -pin_pattern {^VPWR$} \
    -power

add_global_connection \
    -net VDD \
    -pin_pattern {^VPB$}

add_global_connection \
    -net VSS \
    -pin_pattern {^VGND$} \
    -ground

add_global_connection \
    -net VSS \
    -pin_pattern {^VNB$}

# tapcell is used to maintain well/substrate voltage
tapcell \
    -distance 14 \
    -tapcell_master sky130_fd_sc_hd__tapvpwrvgnd_1

global_connect
report_global_connect
write_def build/CPUCore_4_tapcell.def
#############################################

### step5: PDN Generation
# OpenROAD is based on the PDNGEN tool
set_voltage_domain \
    -name CORE \
    -power VDD \
    -ground VSS

define_pdn_grid \
    -name core_grid \
    -voltage_domains CORE

# met 1: standard cell rail
add_pdn_stripe \
    -grid core_grid \
    -layer met1 \
    -width 0.48 \
    -pitch 5.44 \
    -offset 0 \
    -followpins
# met 4: vertical power grid
add_pdn_stripe \
    -grid core_grid \
    -layer met4 \
    -width 1.60 \
    -pitch 27.14 \
    -offset 13.57
# met 5: horizontal power grid
add_pdn_stripe \
    -grid core_grid \
    -layer met5 \
    -width 1.60 \
    -pitch 27.20 \
    -offset 13.60

# make vias
add_pdn_connect \
    -grid core_grid \
    -layers {met1 met4}
add_pdn_connect \
    -grid core_grid \
    -layers {met4 met5}

pdngen

write_def build/CPUCore_5_pdn.def
#############################################

### step6: global placement

# allow up to 55% target placement density
# more details, check OpenROAD
global_placement -density 0.55

# make total violation zero
detailed_placement
check_placement

report_design_area
write_def build/CPUCore_6_global.def
#############################################

### step7: pre-cts optimization
# Pre-CTS timing with placement-estimated interconnect parasitics
# using OpenROAD flow script sky130HD setRC
source openroad/sky130hd.rc
# signal-met2, clock-met5 (estimation)
set_wire_rc -signal -layer met2
set_wire_rc -clock -layer met5
estimate_parasitics -placement

# for the timing repair, setting prohibits
set_dont_use {sky130_fd_sc_hd__probe_p_* sky130_fd_sc_hd__probec_p_*}

# repair_design to fix electrical violations, such as slew, capacitance
repair_design -slew_margin 10 -cap_margin 10

# again... because there are some changes like buffer 
detailed_placement
check_placement
global_connect
estimate_parasitics -placement

#repair tie fanout 
repair_tie_fanout \
    -separation 5 \
    sky130_fd_sc_hd__conb_1/LO
repair_tie_fanout \
    -separation 5 \
    sky130_fd_sc_hd__conb_1/HI

#again...
detailed_placement
check_placement
global_connect
estimate_parasitics -placement

# pre-cts STA
report_worst_slack -max -digits 3
report_worst_slack -min -digits 3
report_tns -digits 3

write_def build/CPUCore_7_repaired.def
write_db build/CPUCore_7_pre_cts.odb

# well, there could be a little negative clock, but check after CTS done.
#############################################

### step 8: CTS

# check invertor (recommend before CTS)
repair_clock_inverters

# CTS 4-> middle drive strength
clock_tree_synthesis \
    -root_buf sky130_fd_sc_hd__clkbuf_4 \
    -buf_list {sky130_fd_sc_hd__clkbuf_4} \
    -sink_clustering_enable \
    -sink_clustering_size 20 \
    -sink_clustering_max_diameter 50

# it repairs long wire
repair_clock_nets
#again..
detailed_placement
check_placement
global_connect

# set all clocks
set_propagated_clock [all_clocks]
estimate_parasitics -placement

#STA
report_worst_slack -max -digits 3
report_worst_slack -min -digits 3
report_tns -digits 3
write_db build/CPUCore_8_cts.odb

# Also, negative slack appears...
#############################################

### step 9: Post CTS
# Actually, I can fix RTL to solve it, but this is more focused on physical design
# So, I will fix just timing in physical design level
# I will try more challenging clock frequency later....

# Repair setup and hold timing violations (because both are negative...)
# After a few attempts, I set margins as follow
repair_timing \
    -setup_margin 0.50 \
    -hold_margin 0.10 \
    -max_utilization 70

detailed_placement
check_placement
global_connect
estimate_parasitics -placement

report_worst_slack -max -digits 3
report_worst_slack -min -digits 3
report_tns -digits 3
write_db build/CPUCore_9_post_cts.odb
#############################################

### step 9: global routing
# signal for met1 ~ met5, clk for met ~ met5
set_routing_layers \
    -signal met1-met5 \
    -clock met3-met5

# for the detailed router access
pin_access

# global_route
global_route \
    -guide_file build/CPUCore.route_guide

# estimate RC after global routing
estimate_parasitics -global_routing

report_worst_slack -max -digits 3
report_worst_slack -min -digits 3
report_tns -digits 3
# to watch setup(max) or hold(min) critical path
report_checks -path_delay max -group_path_count 3 -digits 3
report_checks -path_delay min -group_path_count 3 -digits 3

# negative slacks......
repair_timing \
    -setup \
    -hold \
    -setup_margin 0.25 \
    -hold_margin 0.05 \
    -skip_gate_cloning \
    -max_utilization 70

# 
global_route -start_incremental
detailed_placement
global_connect
global_route -end_incremental

estimate_parasitics -global_routing

# check again
report_worst_slack -max -digits 3
report_worst_slack -min -digits 3
report_tns -digits 3
write_db build/CPUCore_11_global.odb
#############################################

### step 10: antenna check and details
# Repair antenna violations by diode insertion, because we dont need to chang whole route
repair_antennas \
    sky130_fd_sc_hd__diode_2 \
    -iterations 5 \
    -diode_only

global_connect
write_guides build/CPUCore.route_guide

#for speeeeeed
set_thread_count 8
# for the detail debugs, save some files.
# later, I can solve small violations with random seed
detailed_route \
    -or_seed 27 \
    -clean_patches \
    -output_drc build/CPUCore_droute_drc.rpt \
    -output_maze build/CPUCore_droute_maze.log \
    -output_guide_coverage build/CPUCore_guide_coverage.csv \
    -save_guide_updates \
    -verbose 1

# Check antenna violations after detail route
check_antennas

# net,pin violations
# again repair
repair_antennas \
    sky130_fd_sc_hd__diode_2 \
    -diode_only
global_connect
detailed_route \
    -output_drc build/CPUCore_antenna_fix_drc.rpt \
    -output_maze build/CPUCore_antenna_fix_maze.log
check_antennas

#well... again...
repair_antennas \
    sky130_fd_sc_hd__diode_2 \
    -diode_only
global_connect
detailed_route \
    -output_drc build/CPUCore_antenna_fix_drc.rpt \
    -output_maze build/CPUCore_antenna_fix_maze.log
check_antennas


# some checks before finishing
check_placement
# I dont have top level power terminal yet
check_power_grid -net VDD -dont_require_terminals
check_power_grid -net VSS -dont_require_terminals
write_def build/CPUCore_routed.def
write_db build/CPUCore_routed.odb
#############################################
# see you at the post.tcl
