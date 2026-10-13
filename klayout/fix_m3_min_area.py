import math
import re
import xml.etree.ElementTree as ET

import pya


# Run like this
'''
klayout -b \
  -r /home/a0109/architect/RTL2GDS/klayout/fix_m3_min_area.py \
  -rd input=/home/a0109/architect/RTL2GDS/build/CPUCore_final_drcfix_p.gds \
  -rd report=/home/a0109/architect/RTL2GDS/sky130_drc.txt \
  -rd spacing_report=/home/a0109/architect/RTL2GDS/build/sky130_drc.txt \
  -rd output=/home/a0109/architect/RTL2GDS/build/CPUCore_m3fix_v2.gds
'''
# in this project
# two m1.1 problems -> change layout directly
# Also, using python scripts to solve 385 m3.6 problems,
# but it makes 13 m3.2 problems
# so this scripts solve m3.6 and m3.2 without conflict



layout = pya.Layout()
layout.read(input)

top = layout.cell("CPUCore")
met3 = layout.layer(70, 20)
dbu = layout.dbu
grid = 0.005
target_area = 0.245  # m3.6 minimum area: 0.240 um^2


def snap_down(value):
    return math.floor(value / grid) * grid


def snap_up(value):
    return math.ceil(value / grid) * grid


count = 0
spacing_edges = []

for item in ET.parse(spacing_report).findall(".//item"):
    if item.findtext("category", "") != "'m3.2'":
        continue

    value = item.findtext("./values/value", "")
    points = [
        (float(x), float(y))
        for x, y in re.findall(r"([0-9.]+),([0-9.]+)", value)
    ]
    spacing_edges.append(
        ({x for x, _ in points}, min(y for _, y in points), max(y for _, y in points))
    )

for item in ET.parse(report).findall(".//item"):
    if item.findtext("category", "") != "'m3.6'":
        continue

    value = item.findtext("./values/value", "")
    points = [
        (float(x), float(y))
        for x, y in re.findall(r"([0-9.]+),([0-9.]+)", value)
    ]

    x1 = min(x for x, _ in points)
    x2 = max(x for x, _ in points)
    y1 = min(y for _, y in points)
    y2 = max(y for _, y in points)

    target_width = target_area / (y2 - y1)
    extension = max(0.0, (target_width - (x2 - x1)) / 2)
    patch_x1 = snap_down(x1 - extension)
    patch_x2 = snap_up(x2 + extension)

    left_conflict = any(
        any(abs(patch_x1 - edge_x) < 0.001 for edge_x in edge_xs)
        and y1 < edge_y2
        and y2 > edge_y1
        for edge_xs, edge_y1, edge_y2 in spacing_edges
    )
    right_conflict = any(
        any(abs(patch_x2 - edge_x) < 0.001 for edge_x in edge_xs)
        and y1 < edge_y2
        and y2 > edge_y1
        for edge_xs, edge_y1, edge_y2 in spacing_edges
    )

    full_extension = target_width - (x2 - x1)
    if left_conflict and not right_conflict:
        patch_x1 = x1
        patch_x2 = snap_up(x2 + full_extension)
    elif right_conflict and not left_conflict:
        patch_x1 = snap_down(x1 - full_extension)
        patch_x2 = x2

    top.shapes(met3).insert(
        pya.Box(
            round(patch_x1 / dbu),
            round(y1 / dbu),
            round(patch_x2 / dbu),
            round(y2 / dbu),
        )
    )
    count += 1

layout.write(output)
print("Added {} met3 minimum-area patches while avoiding m3.2 markers.".format(count))
