#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pdk_root="/home/a0109/pdks/share/pdk"
pdk_dir="${pdk_root}/sky130A"
stdcell_dir="${pdk_dir}/libs.ref/sky130_fd_sc_hd"
build_dir="${project_dir}/build"
work_dir="${build_dir}/magic_transistor_lvs"
top_cell="CPUCore"

mkdir -p "${work_dir}"

export PDK_ROOT="${pdk_root}"
export LVS_GDS="${build_dir}/CPUCore_m3fix_v2.gds"
export LVS_TOP="${top_cell}"
export LVS_OUTPUT="${build_dir}/CPUCore_magic_transistor.spice"

(
    cd "${work_dir}"
    magic -dnull -noconsole \
        -rcfile "${pdk_dir}/libs.tech/magic/sky130A.magicrc" \
        "${project_dir}/klayout/magic_extract_transistor_lvs.tcl"
) 2>&1 | tee "${build_dir}/CPUCore_magic_transistor_extract.log"

# Add the standard-cell transistor definitions before the OpenROAD top netlist.
sed -e 's| / | |g' \
    "${stdcell_dir}/spice/sky130_fd_sc_hd.spice" \
    "${build_dir}/CPUCore_final.cdl" \
    > "${build_dir}/CPUCore_transistor_reference.spice"

# Remove parasitic capacitors and join SPICE continuation lines.
for netlist in CPUCore_magic_transistor CPUCore_transistor_reference; do
    awk '
        /^C/ { next }
        /^\+/ {
            sub(/^\+[[:space:]]*/, " ")
            printf "%s", $0
            next
        }
        NR > 1 { printf "\n" }
        { printf "%s", $0 }
        END { printf "\n" }
    ' "${build_dir}/${netlist}.spice" \
        > "${build_dir}/${netlist}_compact.spice"
done

netgen-lvs -batch lvs \
    "${build_dir}/CPUCore_magic_transistor_compact.spice ${top_cell}" \
    "${build_dir}/CPUCore_transistor_reference_compact.spice ${top_cell}" \
    "${pdk_dir}/libs.tech/netgen/sky130A_setup.tcl" \
    "${build_dir}/CPUCore_netgen_transistor_lvs.log"
