read_liberty /home/a0109/pdks/share/pdk/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
read_db build/CPUCore_final.odb
read_sdc /home/a0109/architect/RTL2GDS/constraints/cpucore.sdc

# Performance
report_worst_slack -max
report_worst_slack -min
report_tns

# Area
report_design_area

# Power: activity 파일이 없을 때의 추정
set_power_activity -input -activity 0.1
set_power_activity -global -activity 0.1
report_power

