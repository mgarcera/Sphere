"""Trace the airplane line art to a vector path, mirrored so the nose points right.

Supersamples before thresholding: potrace traces the staircase it is given, and the
source ink is only 255 px wide, so tracing it at native size bakes the pixel grid into
the curve. 4x LANCZOS then threshold puts the boundary between pixels instead of on them.
"""

import pathlib
import re
import subprocess
import sys

import numpy as np
from PIL import Image

SRC = str(pathlib.Path(__file__).parent / "plane-source.jpg")
UP = 4

g = Image.open(SRC).convert("L")
a = np.array(g)
ys, xs = np.nonzero(a < 128)
x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
crop = g.crop((x0, y0, x1 + 1, y1 + 1)).transpose(Image.FLIP_LEFT_RIGHT)
w, h = crop.size
big = crop.resize((w * UP, h * UP), Image.LANCZOS)
# Ink must stay DARK: PIL's "1" mode writes black as PBM foreground, which is what
# potrace traces. Inverting here traces the background and returns one subpath.
bw = big.point(lambda v: 0 if v < 128 else 255).convert("1")
bw.save("plane.pbm")
print(f"  source ink {w}x{h}  aspect {w/h:.3f}  ->  bitmap {w*UP}x{h*UP}")

subprocess.run(
    ["potrace", "-b", "svg", "-a", "1.0", "-O", "0.2", "-t", "8",
     "-o", "plane-potrace.svg", "plane.pbm"],
    check=True,
)

svg = open("plane-potrace.svg").read()
tr = re.search(r'transform="translate\(([-\d.]+),([-\d.]+)\) scale\(([-\d.]+),([-\d.]+)\)"', svg)
tx, ty, sx, sy = (float(v) for v in tr.groups())
# potrace emits one <path> per connected component, so the four window dots are
# their own elements. Taking only the first drops them silently.
d = " ".join(re.findall(r'<path d="(.*?)"', svg, re.S))

# potrace emits absolute M, then relative c/l, closed with z.
toks = re.findall(r"[MmLlCcVvHhZz]|-?[\d.]+", d)
subpaths, cur = [], None
i, cx, cy, sxp, syp = 0, 0.0, 0.0, 0.0, 0.0
cmd = None
while i < len(toks):
    t = toks[i]
    if t.isalpha():
        cmd = t
        i += 1
        if cmd in "Zz":
            if cur:
                subpaths.append(cur)
                cur = None
            cx, cy = sxp, syp
            continue
    n = lambda k: float(toks[i + k])
    if cmd in "Mm":
        px, py = (n(0), n(1)) if cmd == "M" else (cx + n(0), cy + n(1))
        if cur:
            subpaths.append(cur)
        cur = [("M", (px, py))]
        cx, cy = sxp, syp = px, py
        i += 2
        cmd = "L" if cmd == "M" else "l"
    elif cmd in "Ll":
        px, py = (n(0), n(1)) if cmd == "L" else (cx + n(0), cy + n(1))
        cur.append(("L", (px, py)))
        cx, cy = px, py
        i += 2
    elif cmd in "Hh":
        px = n(0) if cmd == "H" else cx + n(0)
        cur.append(("L", (px, cy)))
        cx = px
        i += 1
    elif cmd in "Vv":
        py = n(0) if cmd == "V" else cy + n(0)
        cur.append(("L", (cx, py)))
        cy = py
        i += 1
    elif cmd in "Cc":
        if cmd == "C":
            p = [(n(0), n(1)), (n(2), n(3)), (n(4), n(5))]
        else:
            p = [(cx + n(0), cy + n(1)), (cx + n(2), cy + n(3)), (cx + n(4), cy + n(5))]
        cur.append(("C", p))
        cx, cy = p[2]
        i += 6
    else:
        sys.exit(f"unhandled command {cmd!r}")
if cur:
    subpaths.append(cur)

# potrace's own transform, then normalise to a unit box on the ink's bounds.
def xf(p):
    return (p[0] * sx + tx, p[1] * sy + ty)

pts = [xf(q) for sp in subpaths for _, p in sp for q in ([p] if isinstance(p[0], float) else p)]
X = [p[0] for p in pts]
Y = [p[1] for p in pts]
bx, by, bw_, bh_ = min(X), min(Y), max(X) - min(X), max(Y) - min(Y)
print(f"  traced bbox {bw_:.1f}x{bh_:.1f}  aspect {bw_/bh_:.3f}")


def unit(p):
    q = xf(p)
    return ((q[0] - bx) / bw_, (q[1] - by) / bh_)


def area(sp):
    poly = []
    for k, p in sp:
        poly.extend([unit(q) for q in ([p] if isinstance(p[0], float) else p)])
    A = np.array(poly)
    return abs(np.dot(A[:, 0], np.roll(A[:, 1], -1)) - np.dot(A[:, 1], np.roll(A[:, 0], -1))) / 2


subpaths.sort(key=area, reverse=True)
print(f"  {len(subpaths)} subpaths, areas: " + " ".join(f"{area(s):.4f}" for s in subpaths))

lines = []
for sp in subpaths:
    for k, p in sp:
        if k == "M":
            lines.append(f"        p.move(to: at({unit(p)[0]:.4f}, {unit(p)[1]:.4f}))")
        elif k == "L":
            lines.append(f"        p.addLine(to: at({unit(p)[0]:.4f}, {unit(p)[1]:.4f}))")
        else:
            a1, a2, a3 = (unit(q) for q in p)
            lines.append(
                f"        p.addCurve(to: at({a3[0]:.4f}, {a3[1]:.4f}), "
                f"control1: at({a1[0]:.4f}, {a1[1]:.4f}), "
                f"control2: at({a2[0]:.4f}, {a2[1]:.4f}))"
            )
    lines.append("        p.closeSubpath()")
open("plane-swift.txt", "w").write("\n".join(lines) + "\n")
print(f"  wrote {len(lines)} Swift lines")

# An SVG at the real size, for a look before any of it reaches the project.
def dstr(sps):
    out = []
    for sp in sps:
        for k, p in sp:
            if k == "M":
                u = unit(p); out.append(f"M{u[0]:.4f} {u[1]:.4f}")
            elif k == "L":
                u = unit(p); out.append(f"L{u[0]:.4f} {u[1]:.4f}")
            else:
                a1, a2, a3 = (unit(q) for q in p)
                out.append(f"C{a1[0]:.4f} {a1[1]:.4f} {a2[0]:.4f} {a2[1]:.4f} {a3[0]:.4f} {a3[1]:.4f}")
        out.append("Z")
    return " ".join(out)

open("plane-unit-d.txt", "w").write(dstr(subpaths))
print("  wrote plane-unit-d.txt")
