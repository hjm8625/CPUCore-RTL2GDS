set pdk_root /home/a0109/pdks/share/pdk/sky130A
set stdcell_root $pdk_root/libs.ref/sky130_fd_sc_hd
set liberty_file $stdcell_root/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

#rcx rules: 
set rcx_rules_file \
    $pdk_root/libs.tech/openlane/rules.openrcx.sky130A.nom.spef_extractor

read_liberty $liberty_file
read_db build/CPUCore_routed.odb
read_sdc constraints/cpucore.sdc

set_propagated_clock [all_clocks]

# use model index 0, named process corner as X
define_process_corner -ext_model_index 0 X
# using rcx fules
set_extraction_rules_file $rcx_rules_file
extract_parasitics
# well, there are some unannotated drivers...
# Standard Parasitic Exchange Format
write_spef build/CPUCore_nom.spef

# check
report_worst_slack -max -digits 3
report_worst_slack -min -digits 3
report_tns -digits 3

report_checks \
    -path_delay max \
    -group_path_count 3 \
    -digits 3

report_checks \
    -path_delay min \
    -group_path_count 3 \
    -digits 3

# filler for physical only cell
filler_placement {
    sky130_fd_sc_hd__fill_2
    sky130_fd_sc_hd__fill_1
}
global_connect
check_placement
check_power_grid -net VDD -dont_require_terminals
check_power_grid -net VSS -dont_require_terminals
# Last check
check_antennas
report_worst_slack -max
report_worst_slack -min
report_tns
# make final files
write_def build/CPUCore_final.def
write_db build/CPUCore_final.odb
