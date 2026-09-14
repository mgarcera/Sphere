#!/usr/bin/env python3
"""
App Store frames, built in code instead of in a design tool.

A frame is a background, a caption and a capture. That is an HTML page at exactly 1320x2868
rendered headlessly — which means the caption is versioned beside the listing copy it came from,
a wording change is one line and a re-render, and the pixel size cannot drift.

The surround is sampled from each capture's OWN top and bottom edge, so every frame extends its
own weather rather than sitting on one house colour. A night frame gets night around it.

    python3 AppStore/frames/build.py          # all frames that have a capture
    python3 AppStore/frames/build.py --open   # and reveal the output folder
"""
import base64, json, pathlib, subprocess, sys
from PIL import Image
import numpy as np

HERE = pathlib.Path(__file__).parent
CAP, OUT = HERE / "captures", HERE / "out"
W, H = 1320, 2868                     # 6.9", the only size App Store Connect now requires
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# Layout, in frame pixels. These are the knobs a design pass turns.
LAYOUT = dict(pad=96, caption_top=150, caption_size=78, caption_leading=1.12,
              device_top=520, device_width=1100, device_radius=54)

# Captions are the proofed ones from AppStore/screenshots.md. Keep them in step.
FRAMES = [
    ("01-day",   "See your schedule in the sky’s arc.", "light"),
    ("02-night", "Close to the sky at any time.",        "dark"),
    ("03-storm", "Your very own atmosphere.",            "light"),
    ("04-wheel", "Turn the wheel. Move the day.",        "light"),
    ("05-widget","Widgets on your Home Screen and Lock Screen.", "light"),
    ("06-menu",  "Tuned to where you are.",              "light"),
]

def edges(img):
    a = np.array(img.convert("RGB"))
    top = np.median(a[140:300].reshape(-1, 3), axis=0)
    bot = np.median(a[-240:].reshape(-1, 3), axis=0)
    hexs = lambda c: "#%02X%02X%02X" % tuple(int(round(x)) for x in c)
    return hexs(top), hexs(bot)

def page(caption, b64, top, bot, scheme):
    L = LAYOUT
    ink = "#F4F2EE" if scheme == "dark" else "#141317"
    return f"""<!doctype html><html><head><meta charset="utf-8">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Newsreader:opsz,wght@6..72,400;6..72,500&display=swap">
<style>
  *{{margin:0;box-sizing:border-box}}
  html,body{{width:{W}px;height:{H}px;overflow:hidden}}
  body{{background:linear-gradient(180deg,{top} 0%,{top} 34%,{bot} 100%);
        font-family:"Newsreader",Georgia,serif;color:{ink}}}
  .cap{{position:absolute;top:{L['caption_top']}px;left:{L['pad']}px;right:{L['pad']}px;
        font-size:{L['caption_size']}px;line-height:{L['caption_leading']};letter-spacing:-.015em;
        text-wrap:balance}}
  .dev{{position:absolute;top:{L['device_top']}px;left:50%;transform:translateX(-50%);
        width:{L['device_width']}px;border-radius:{L['device_radius']}px;overflow:hidden;
        box-shadow:0 40px 90px rgb(0 0 0 / .22), 0 0 0 1px rgb(0 0 0 / .06)}}
  .dev img{{width:100%;display:block}}
</style></head><body>
  <p class="cap">{caption}</p>
  <div class="dev"><img src="data:image/png;base64,{b64}"></div>
</body></html>"""

def main():
    OUT.mkdir(exist_ok=True)
    built, waiting = [], []
    for name, caption, scheme in FRAMES:
        src = CAP / f"{name}.png"
        if not src.exists():
            waiting.append(name); continue
        im = Image.open(src)
        top, bot = edges(im)
        html = HERE / f".{name}.html"
        html.write_text(page(caption, base64.b64encode(src.read_bytes()).decode(), top, bot, scheme))
        subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
                        f"--window-size={W},{H}", "--virtual-time-budget=8000",
                        f"--screenshot={OUT / (name + '.png')}", str(html)],
                       check=False, capture_output=True)
        html.unlink(missing_ok=True)
        got = Image.open(OUT / f"{name}.png").size
        built.append((name, got, top, bot))
    for name, got, top, bot in built:
        ok = "OK" if got == (W, H) else f"WRONG {got}"
        print(f"  {name:10} {got[0]}x{got[1]}  {ok:10} surround {top} → {bot}")
    if waiting:
        print(f"\n  waiting on a capture: {', '.join(waiting)}")
    if "--open" in sys.argv: subprocess.run(["open", str(OUT)])

if __name__ == "__main__":
    main()
