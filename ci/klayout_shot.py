# klayout -zz -r klayout_shot.py -rd gds=... -rd outdir=... -rd lyp=...
import os
import pya

lv = pya.LayoutView()
lv.set_config("background-color", "#000000")
lv.set_config("grid-visible", "false")
lv.set_config("text-visible", "true")
idx = lv.load_layout(gds, True)
if os.path.exists(lyp):
    lv.load_layer_props(lyp)
    print("loaded layer properties", lyp)
else:
    print("no lyp found at", lyp)
lv.max_hier()

ly = lv.cellview(idx).layout()
top = lv.cellview(idx).cell
bb = top.dbbox()
print("top cell:", top.name, "bbox (um):", bb)

# whole die
lv.zoom_fit()
lv.save_image(os.path.join(outdir, "layout_full.png"), 1600, 1600)

# bounding box of placed standard cells (ignore fill / tap / decap for centring)
cells = pya.DBox()
for inst in top.each_inst():
    name = inst.cell.name
    if "fill" in name or "tap" in name or "decap" in name:
        continue
    cells += inst.dbbox()
print("logic cell bbox (um):", cells)
cx, cy = cells.center().x, cells.center().y

# zoomed view: 30 um x 30 um around the centre of the logic
lv.zoom_box(pya.DBox(cx - 15, cy - 15, cx + 15, cy + 15))
lv.save_image(os.path.join(outdir, "layout_zoom.png"), 1600, 1600)

# medium zoom on the whole core region of logic cells
lv.zoom_box(cells.enlarged(5, 5))
lv.save_image(os.path.join(outdir, "layout_core.png"), 1600, 1600)

# instance statistics of the final layout
from collections import Counter
cnt = Counter(inst.cell.name for inst in top.each_inst())
with open(os.path.join(outdir, "gds_cell_counts.txt"), "w") as f:
    for k, v in sorted(cnt.items(), key=lambda kv: -kv[1]):
        f.write(f"{v:6d} {k}\n")
print("done")
