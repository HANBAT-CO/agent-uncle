# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow==11.3.0"]
# ///
"""Compare unscaled React/Flutter captures over an explicit common viewport.

No threshold is called a parity pass. Store the measurements and difference image
so a reviewer can distinguish geometry differences from text rasterization.
"""
import argparse
import json
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw

p = argparse.ArgumentParser()
p.add_argument("react", type=Path)
p.add_argument("flutter", type=Path)
p.add_argument("--height", type=int, required=True)
p.add_argument("--output", type=Path, required=True)
args = p.parse_args()
a, b = Image.open(args.react).convert("RGB"), Image.open(args.flutter).convert("RGB")
assert a.width == b.width, "Viewport widths must match; never rescale references"
assert min(a.height, b.height) >= args.height
a, b = a.crop((0,0,a.width,args.height)), b.crop((0,0,b.width,args.height))
diff = ImageChops.difference(a,b)
errors = [max(rgb) for rgb in diff.getdata()]
report = {"viewport": [a.width,a.height], "pixels": len(errors),
          "differentPixels": sum(v>0 for v in errors), "pixelsDeltaAbove16": sum(v>16 for v in errors),
          "meanMaxChannelDelta": sum(errors)/len(errors), "maxChannelDelta": max(errors)}
args.output.parent.mkdir(parents=True,exist_ok=True)
args.output.with_suffix(".json").write_text(json.dumps(report,indent=2)+"\n")
canvas = Image.new("RGB",(a.width*3,a.height+28),"white")
canvas.paste(a,(0,28));canvas.paste(b,(a.width,28));canvas.paste(diff,(a.width*2,28))
draw=ImageDraw.Draw(canvas)
for i,title in enumerate(["React 2.5.1","Flutter native","Absolute pixel difference"]):
    draw.text((i*a.width+8,7),title,fill="black")
canvas.save(args.output)
print(json.dumps(report,indent=2))
