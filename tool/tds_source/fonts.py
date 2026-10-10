# /// script
# requires-python = ">=3.11"
# dependencies = ["fonttools[woff]==4.60.1"]
# ///
"""Rebuild the original Toss Product Sans faces from their official web subsets.

Run: uv run tool/tds_source/fonts.py
No glyphs are redrawn, rescaled or substituted. cmap coverage is checked after
merging. Downloaded CSS/subsets and SHA256 provenance make the input auditable.
"""
from concurrent.futures import ThreadPoolExecutor
from hashlib import sha256
from pathlib import Path
import json
import re
import time
from urllib.request import urlopen
from fontTools.ttLib import TTFont
from fontTools.merge import Merger, Options
from fontTools.pens.recordingPen import DecomposingRecordingPen

ROOT = Path(__file__).resolve().parents[2]
CACHE = ROOT / ".context/tds-fonts"
OUTPUT = ROOT / "packages/tds_mobile_flutter/assets/fonts"
CACHE.mkdir(parents=True, exist_ok=True)
OUTPUT.mkdir(parents=True, exist_ok=True)


def download(url, path):
    if not path.exists():
        for attempt in range(4):
            try:
                with urlopen(url, timeout=60) as response:
                    data = response.read()
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)
                break
            except Exception:
                if attempt == 3:
                    raise
                time.sleep(attempt + 1)
    return path


faces = {}
css_sources = []
for filename in ["main.css", "others.css"]:
    url = f"https://static.toss.im/tps/{filename}"
    css_path = download(url, CACHE / filename)
    css_sources.append({"url": url, "sha256": sha256(css_path.read_bytes()).hexdigest()})
    for face in re.findall(r"@font-face\s*\{([^}]+)\}", css_path.read_text()):
        weight = int(re.search(r"font-weight\s*:\s*(\d+)", face)[1])
        path = re.search(r'url\([\"\']?([^\)\"\']+\.woff2)', face)[1]
        faces.setdefault(weight, []).append(path)


def get_subset(path):
    return download("https://static.toss.im" + path, CACHE / path.lstrip("/"))


manifest = {"family": "Toss Product Sans", "css": css_sources, "faces": []}
for weight, paths in sorted(faces.items()):
    paths = sorted(set(paths))
    with ThreadPoolExecutor(max_workers=8) as pool:
        downloaded = list(pool.map(get_subset, paths))
    sources, ttfs, expected_cmap = [], [], set()
    for url_path, subset in zip(paths, downloaded):
        font = TTFont(subset, recalcTimestamp=False)
        expected_cmap.update(font.getBestCmap())
        font.flavor = None
        ttf = subset.with_suffix(".ttf")
        font.save(ttf)
        font.close()
        ttfs.append(str(ttf))
        sources.append({"url": "https://static.toss.im" + url_path, "sha256": sha256(subset.read_bytes()).hexdigest()})
    target = OUTPUT / f"TossProductSans-{weight}.ttf"
    merged = Merger(options=Options()).merge(ttfs)
    merged.flavor = None
    # Use source timestamps, not wall-clock build time, for reproducible hashes.
    merged.recalcTimestamp = False
    with TTFont(downloaded[0], recalcTimestamp=False) as first:
        merged["head"].created = first["head"].created
        merged["head"].modified = first["head"].modified
    merged.save(target)
    merged.close()
    result = TTFont(target)
    actual_cmap = set(result.getBestCmap())
    assert actual_cmap == expected_cmap, f"cmap mismatch for weight {weight}"
    result_glyphs = result.getGlyphSet()
    result_cmap = result.getBestCmap()
    checked = set()
    for subset in downloaded:
        original = TTFont(subset)
        original_glyphs = original.getGlyphSet()
        assert original["head"].unitsPerEm == result["head"].unitsPerEm
        for codepoint, name in original.getBestCmap().items():
            result_name = result_cmap[codepoint]
            assert original["hmtx"][name] == result["hmtx"][result_name], (weight, codepoint, "horizontal metrics")
            old_pen = DecomposingRecordingPen(original_glyphs)
            new_pen = DecomposingRecordingPen(result_glyphs)
            original_glyphs[name].draw(old_pen)
            result_glyphs[result_name].draw(new_pen)
            assert old_pen.value == new_pen.value, (weight, codepoint, "glyph outline")
            checked.add(codepoint)
        original.close()
    assert checked == actual_cmap
    manifest["faces"].append({"weight": weight, "asset": target.name, "sha256": sha256(target.read_bytes()).hexdigest(), "codepoints": len(actual_cmap), "verifiedGlyphOutlinesAndMetrics": len(checked), "unitsPerEm": result["head"].unitsPerEm, "sources": sources})
    result.close()
    print(f"{weight}: {len(paths)} subsets -> {target.name} ({len(actual_cmap)} codepoints)", flush=True)

(OUTPUT / "provenance.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
