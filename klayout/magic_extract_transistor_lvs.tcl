# Extract a transistor-level SPICE netlist from the final GDS
gds readonly true
gds read /home/a0109/architect/RTL2GDS/build/CPUCore_m3fix_v2.gds \

load CPUCore

extract do local
extract all

ext2spice lvs
ext2spice cthresh infinite // dont need parasitic
ext2spice rthresh infinite //
ext2spice -o /home/a0109/architect/RTL2GDS/build/CPUCore_magic_transistor.spice

quit -noprompt

# after this

# extract spice from GDS
#magic -dnull -noconsole \
#  -rcfile /home/a0109/pdks/share/pdk/sky130A/libs.tech/magic/sky130A.magicrc \
#  /home/a0109/architect/RTL2GDS/klayout/magic_extract_transistor_lvs.tcl

#netgen-lvs -batch lvs \
#  "/home/a0109/architect/RTL2GDS/build/CPUCore_magic_transistor.spice CPUCore" \
#  "/home/a0109/architect/RTL2GDS/build/CPUCore_final.spice CPUCore" \
#  /home/a0109/pdks/share/pdk/sky130A/libs.tech/netgen/sky130A_setup.tcl \
#  /home/a0109/architect/RTL2GDS/build/CPUCore_netgen_transistor_lvs.log