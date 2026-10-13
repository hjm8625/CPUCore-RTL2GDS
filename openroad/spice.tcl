set sky130hd_cdl \
    /home/a0109/pdks/share/pdk/sky130A/libs.ref/sky130_fd_sc_hd/cdl/sky130_fd_sc_hd.cdl

read_liberty \
    /home/a0109/pdks/share/pdk/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

read_db build/CPUCore_final.odb

write_cdl \
    -masters [list $sky130hd_cdl] \
    -include_fillers \
    build/CPUCore_final.spice

write_cdl \
    -masters [list $sky130hd_cdl] \
    -include_fillers \
    build/CPUCore_final.cdl

#  include this!
# .include /home/a0109/pdks/share/pdk/sky130A/libs.ref/sky130_fd_sc_hd/spice/sky130_fd_sc_hd.spice
