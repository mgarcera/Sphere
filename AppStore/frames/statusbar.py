#!/usr/bin/env python3
"""
One status bar across every capture: 9:41, full signal, full battery, nothing else.

The three device captures disagreed on more than the clock — 4:41 / 11:23 / 11:24, 57% and 66%
battery, different signal strength, plus a Location arrow on the night shot and a silent-mode bell
on the storm shot. None of that belongs in a listing.

Retaking on the phone cannot fix it; the phone has one real clock and one real battery. So the bar
is REPLACED instead. Two things make that exact rather than approximate:

  - Sphere's sky is uniform across any given row, so the old bar is erased by refilling each row
    with its own median colour. No cloning, no seam.
  - The new glyphs are Apple's own, lifted from a booted simulator of the same 1206x2622 metrics
    with `simctl status_bar override`. They are captured twice, over flat #F2F2F7 and over flat
    #000000, which recovers a clean coverage mask for dark ink and for light ink.

Each frame keeps the ink it already had — light on the day and night skies, dark on the storm sky.
That contrast decision is the app's, correctly made, and is not what was inconsistent.

    python3 AppStore/frames/statusbar.py
"""
import pathlib, re, subprocess, sys, time
from PIL import Image
import numpy as np

HERE = pathlib.Path(__file__).parent
CAP, OUT = HERE / "captures", HERE / "clean"
SIM = None         # resolved at run time; a hardcoded UDID rots the first time a runtime is removed
OVERRIDE = ["--time", "9:41", "--dataNetwork", "wifi", "--wifiMode", "active", "--wifiBars", "3",
            "--cellularMode", "active", "--cellularBars", "4",
            "--batteryState", "discharging", "--batteryLevel", "100"]
BAND = 14          # a row counts as bar content when it strays this far from its own median
WINDOW = (66, 136)  # the bar's rows. Fixed, not searched: both images are 1206x2622 with the same
                    # safe area, so the bar lands identically and no alignment step can drift.

def simulator():
    """Any simulator whose screen matches the captures. iPhone 16 Pro and 17 Pro are both
    1206x2622, so the bar geometry is identical and either will do."""
    out = subprocess.run(["xcrun", "simctl", "list", "devices", "available"],
                         capture_output=True, text=True).stdout
    boot = [l for l in out.splitlines() if "(Booted)" in l and re.search(r"iPhone 1[67] Pro\b", l)]
    row = boot or [l for l in out.splitlines() if re.search(r"iPhone 1[67] Pro\b", l)]
    if not row: sys.exit("  no iPhone 16/17 Pro simulator available")
    udid = re.search(r"\(([0-9A-F-]{36})\)", row[0]).group(1)
    if not boot:
        subprocess.run(["xcrun", "simctl", "boot", udid], capture_output=True)
        subprocess.run(["xcrun", "simctl", "bootstatus", udid], capture_output=True)
    return udid

def band_rows(a, limit=200):
    """Rows the status bar occupies: the first run of >=20 rows straying from a flat row colour.
    The minimum matters — a simulator screenshot has a 4px rounded-corner artifact at row 0 that
    a device screenshot does not, and without it that artifact is mistaken for the bar."""
    med = np.median(a[:limit], axis=1, keepdims=True)
    dirty = np.abs(a[:limit] - med).max(axis=(1, 2)) > BAND
    runs, s = [], None
    for i, v in enumerate(dirty):
        if v and s is None: s = i
        if not v and s is not None: runs.append((s, i - 1)); s = None
    if s is not None: runs.append((s, limit - 1))
    for lo, hi in runs:
        if hi - lo >= 20: return lo, hi
    sys.exit("  no status bar band found")

def sim_mask(appearance, path):
    """Capture the simulator's bar over a flat ground and return (alpha, ink, rows)."""
    subprocess.run(["xcrun", "simctl", "ui", SIM, "appearance", appearance], capture_output=True)
    subprocess.run(["xcrun", "simctl", "status_bar", SIM, "override", *OVERRIDE], capture_output=True)
    subprocess.run(["xcrun", "simctl", "terminate", SIM, "com.apple.Preferences"], capture_output=True)
    subprocess.run(["xcrun", "simctl", "launch", SIM, "com.apple.Preferences"], capture_output=True)
    for _ in range(12):                              # wait for Settings' flat chrome to land
        time.sleep(1.0)
        subprocess.run(["xcrun", "simctl", "io", SIM, "screenshot", str(path)], capture_output=True)
        a = np.array(Image.open(path).convert("RGB")).astype(float)
        top, bot = band_rows(a)
        bg = np.median(a[top:bot + 1].reshape(-1, 3), axis=0)
        if np.abs(a[top - 16:top] - bg).max() < 6: break
    else:
        sys.exit(f"  simulator background never settled flat for {appearance}")

    ink = np.array([0., 0., 0.]) if appearance == "light" else np.array([255., 255., 255.])
    band = a[WINDOW[0]:WINDOW[1]]
    alpha = np.clip(np.abs(band - bg) / np.abs(ink - bg), 0, 1).max(axis=2)

    # The simulator renders the Dynamic Island; a device screenshot does not. Drop the widest
    # run of fully-covered columns in the middle of the bar.
    solid = alpha.min(axis=0) > 0.97
    runs, s = [], None
    for i, v in enumerate(solid):
        if v and s is None: s = i
        if not v and s is not None: runs.append((s, i - 1)); s = None
    if s is not None: runs.append((s, len(solid) - 1))
    mid = [r for r in runs if r[1] - r[0] > 200]
    if mid:
        lo, hi = max(mid, key=lambda r: r[1] - r[0])
        alpha[:, lo:hi + 1] = 0
    return alpha, ink, (top, bot)

def main():
    global SIM
    SIM = simulator()
    OUT.mkdir(exist_ok=True)
    masks = {k: sim_mask(app, HERE / f".bar-{app}.png")
             for k, app in (("dark", "light"), ("light", "dark"))}   # key = the INK it paints

    for src in sorted(CAP.glob("*.png")):
        im = Image.open(src).convert("RGB")
        a = np.array(im).astype(float)
        top, bot = band_rows(a)
        if not (WINDOW[0] <= top and bot < WINDOW[1]):
            sys.exit(f"  {src.name}: bar at rows {top}-{bot} falls outside WINDOW {WINDOW}")

        lo, hi = WINDOW
        med = np.median(a[lo:hi], axis=1)                            # one flat colour per row

        glyphs = a[top:bot + 1]
        off = np.abs(glyphs - np.median(glyphs, axis=1)[:, None, :]).max(axis=2) > BAND
        ink_key = "dark" if glyphs[off].mean() < glyphs.mean() else "light"
        alpha, ink, simrows = masks[ink_key]

        a[lo:hi] = med[:, None, :]                                   # erase
        a[lo:hi] += alpha[..., None] * (ink - med[:, None, :])       # redraw
        Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).save(OUT / src.name)
        print(f"  {src.name:12} device bar {top}-{bot}  simulator bar {simrows[0]}-{simrows[1]}  "
              f"{ink_key} ink  -> clean/{src.name}")

    for p in HERE.glob(".bar-*.png"): p.unlink(missing_ok=True)

if __name__ == "__main__":
    main()
