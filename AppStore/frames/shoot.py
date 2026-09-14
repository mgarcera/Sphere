#!/usr/bin/env python3
"""
Take one App Store capture off the phone, with the status bar already unified.

The device, not a simulator: Sphere's whole subject is a real day — a real calendar, real weather,
a real place — and a simulator shows an empty one. The cost is that posing the screen is Mason's
job; this script is only the shutter.

    python3 AppStore/frames/shoot.py 04-wheel

The phone must be UNLOCKED. Reshooting the same name overwrites it, so a bad take costs nothing.
"""
import pathlib, re, subprocess, sys

HERE = pathlib.Path(__file__).parent
SHOTS = {                      # from AppStore/screenshots.md, section 3
    "04-wheel":  "Menu -> WHEEL section: the wheel diagram with a position selected, and the "
                 "PRIMARY / SECONDARY column panel beside it.",
    "05-widget": "Home Screen with the small AND medium Day widgets placed. Shoot in daylight — "
                 "the widget palette does not follow Natural Sky, so a night shot shows a light "
                 "widget beside a dark app.",
    "06-menu":   "Menu, scrolled to show the place name and field, the TODAY block with moon and "
                 "temperature, the MiniArc with its sunrise / solar-noon / sunset labels, and the "
                 "CALENDARS switches.",
}

def device():
    out = subprocess.run(["xcrun", "devicectl", "list", "devices"],
                         capture_output=True, text=True).stdout
    rows = [l for l in out.splitlines() if "physical" in l and "iPhone" in l
            and ("connected" in l or "available (paired)" in l)]
    if not rows:
        sys.exit("  no reachable iPhone. Wake it, and check it is on the same network.")
    if len(rows) > 1:
        sys.exit("  more than one iPhone reachable; name the one to use in this script.")
    return re.search(r"([0-9A-F]{8}-(?:[0-9A-F]{4}-){3}[0-9A-F]{12})", rows[0]).group(1)

def main():
    if len(sys.argv) != 2 or sys.argv[1] not in SHOTS:
        print(__doc__)
        for k, v in SHOTS.items(): print(f"  {k:10} {v}\n")
        sys.exit(1)
    name = sys.argv[1]
    print(f"  {name}: {SHOTS[name]}\n")

    dest = HERE / "captures" / f"{name}.png"
    r = subprocess.run(["xcrun", "devicectl", "device", "capture", "screenshot",
                        "--device", device(), "--destination", str(dest)],
                       capture_output=True, text=True)
    if r.returncode or not dest.exists():
        sys.exit(f"  capture failed — is the phone unlocked?\n{r.stderr.strip() or r.stdout.strip()}")

    subprocess.run([sys.executable, str(HERE / "statusbar.py"), name], check=True)
    subprocess.run([sys.executable, str(HERE / "build.py")], check=True)

if __name__ == "__main__":
    main()
