# CPUCore RTL-to-GDS Project

A complete RTL-to-GDS implementation of a 32-bit, 5-stage pipelined MIPS CPU using the SKY130 open-source PDK.

> **Final status:** DRC clean, LVS matched, and setup/hold timing met at 50 MHz

---

## Overview

This project takes a synthesizable CPU core from Verilog RTL through synthesis, floorplanning, placement, clock-tree synthesis, routing, physical verification.

The CPU RTL was originally developed as a MIPS processor project. This repository focuses on the physical-design flow and the verification of the resulting SKY130 layout.

---

## Tools

- Yosys — RTL synthesis and SKY130 standard-cell mapping
- OpenROAD — floorplanning, placement, CTS, routing, RC extraction, and STA
- KLayout — GDS generation, DRC, and layout inspection
- Magic — transistor-level SPICE extraction from the final GDS
- Netgen — transistor-level LVS
- SKY130A PDK
- `sky130_fd_sc_hd` standard-cell library

---

## CPU Features

- 32-bit MIPS integer ISA subset
- Classic 5-stage pipeline (IF, ID, EX, MEM, WB)
- Data forwarding and load use hazard handling
- Pipeline flush on control flow redirection
- GShare branch predictor
- 2bit saturating counter Pattern History Table (PHT)
- Branch Target Buffer (BTB)
- Separate instruction and data memory interfaces

---

## RTL-to-GDS Flow

1. Synthesize and map the RTL to `sky130_fd_sc_hd` cells with Yosys
2. Initialize the floorplan and place I/O pins with OpenROAD
3. Generate the power distribution network and insert tap cells
4. Perform global placement and pre CTS timing repair.
5. Build the clock tree and repair setup/hold timing
6. Perform global and detailed routing
7. Repair antenna violations and extract post-route parasitics
8. Generate the final DEF/ODB and stream the layout to GDS
9. Run the SKY130 full DRC in KLayout
10. Extract the final GDS with Magic and compare it against the OpenROAD reference netlist using Netgen

The target clock constraint is 50 MHz with a 20 ns period. Timing and power use the SKY130 HD typical library corner at 1.8 V and 25 °C.

---

## Final Results

### Timing and Area

| Metric | Result |
|---|---:|
| Target clock | 50 MHz (20 ns) |
| Setup worst slack | +4.71 ns |
| Hold worst slack | +0.32 ns |
| Setup TNS | 0.00 ns |
| Standard-cell area | 301,824 µm² |
| Core utilization | 58% |

The reported timing is based on the final routed OpenROAD database and extracted parasitics.

### Estimated Power

| Component | Power | Share |
|---|---:|---:|
| Sequential | 14.1 mW | 65.3% |
| Combinational | 2.03 mW | 9.4% |
| Clock | 5.50 mW | 25.4% |
| **Total** | **21.7 mW** | **100%** |

Power was estimated with a switching activity assumption of `0.1`; it is not based on workload-derived VCD/SAIF activity.

### Physical Verification

| Check | Result |
|---|---|
| KLayout Full DRC | PASS — 0 violations |
| Magic + Netgen LVS | PASS — circuits match uniquely |
| LVS devices | 21,122 / 21,122 |
| LVS nets | 21,156 / 21,156 |
| Antenna | PASS — 0 net and pin violations |
| VDD/VSS connectivity | PASS |

KLayout LVS was also evaluated, but the SKY130 KLayout extraction deck did not extract the `conb_1` and `diode_2` special cells correctly. Final transistor-level LVS was therefore performed with the SKY130-supported Magic and Netgen flow.

---

## DRC Repair

The initial streamed layout contained local `m1.1`, `m3.2`, and `m3.6` violations. The Metal 1 issue was corrected in the DEF/layout, and the Metal 3 minimum-spacing and minimum-area violations were repaired with [`klayout/fix_m3_min_area.py`](klayout/fix_m3_min_area.py). The repaired layout then passed the full SKY130 DRC with zero violations.

The final verified layout is:

```text
build/CPUCore_m3fix_v2.gds
```

---

## Repository Structure

```text
RTL/          Verilog RTL and module-level testbenches
constraints/  SDC timing constraints
synth/        Yosys synthesis script
openroad/     Physical-design, post-route, netlist, and PPA scripts
klayout/      DRC repair and Magic/Netgen LVS scripts
build/        Selected final netlist, DEF, GDS, DRC, and LVS results
```

Large reproducible files such as ODB, SPEF, Magic `.ext`, and routing databases are excluded from Git.

---

## Running the Flow

Run commands from the repository root. The scripts currently reference a local SKY130A installation under `/home/a0109/pdks/share/pdk`; update those paths for a different installation.

### Synthesis

```bash
yosys -s synth/cpucore_sky130.ys
```

### Physical Design
- recommend do it with gui (it is fun to watch it)
```bash
openroad -gui openroad/init.tcl
openroad -gui openroad/post.tcl
```

### PPA Report

```bash
openroad openroad/ppa.tcl
```

### Magic Extraction and Netgen LVS

```bash
magic -dnull -noconsole \
  -rcfile /home/a0109/pdks/share/pdk/sky130A/libs.tech/magic/sky130A.magicrc \
  klayout/magic_extract_transistor_lvs.tcl

netgen-lvs -batch lvs \
  "build/CPUCore_magic_transistor.spice CPUCore" \
  "build/CPUCore_final.spice CPUCore" \
  /home/a0109/pdks/share/pdk/sky130A/libs.tech/netgen/sky130A_setup.tcl \
  build/CPUCore_netgen_transistor_lvs.log
```

---

## Limitations and Future Work

- Power is estimated with assumed activity rather than workload-generated VCD/SAIF data.
- Sign-off across additional PVT corners has not yet been performed.
- IR-drop and electromigration analysis are not included.
- The CPU does not include caches, an MMU, an FPU, interrupts, or exception handling.
- This project is under active development
---

## Reference

- Hanyang University ITE2031 Computer Architecture
- Hanyang Universicy ELE3081 VLSI
- Hanyang University ELE3074 Electronic circuit 1
- SKY130 Open Source PDK
- OpenROAD documentation and SKY130 flow examples
