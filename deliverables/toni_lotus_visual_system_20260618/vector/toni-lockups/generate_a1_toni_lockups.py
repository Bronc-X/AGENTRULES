from __future__ import annotations

import base64
import html
import re
import subprocess
from pathlib import Path

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.ttLib import TTFont


ROOT = Path(__file__).resolve().parents[1]
OUT = Path(__file__).resolve().parent
FONT = ROOT.parent / "assets" / "fonts" / "InstrumentSerif-Regular.ttf"
EDGE = Path(r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe")

SYMBOL = ROOT / "a1-lotus-symbol.vector.svg"
WORDMARK = ROOT / "a1-lotus-wordmark.vector.svg"

CANVAS_W = 1080
CANVAS_H = 330


SCENARIOS = [
    {
        "slug": "deep-ink",
        "label": "Deep ink",
        "bg": "#0D0F12",
        "fg": "#F6F4EF",
        "card": None,
        "icon_bg": None,
    },
    {
        "slug": "charcoal",
        "label": "Charcoal",
        "bg": "#1A1C21",
        "fg": "#F6F4EF",
        "card": None,
        "icon_bg": None,
    },
    {
        "slug": "paper-light",
        "label": "Paper light",
        "bg": "#E6E7EB",
        "fg": "#0D0F12",
        "card": None,
        "icon_bg": None,
    },
    {
        "slug": "warm-white",
        "label": "Warm white",
        "bg": "#F6F6F4",
        "fg": "#0D0F12",
        "card": None,
        "icon_bg": None,
    },
    {
        "slug": "petal-pink",
        "label": "Petal pink",
        "bg": "#DFA7B0",
        "fg": "#0D0F12",
        "card": None,
        "icon_bg": None,
    },
    {
        "slug": "sync-green",
        "label": "Sync green",
        "bg": "#76C86F",
        "fg": "#0D0F12",
        "card": None,
        "icon_bg": None,
    },
    {
        "slug": "transparent",
        "label": "Transparent",
        "bg": "none",
        "fg": "#0D0F12",
        "card": "#F6F6F4",
        "icon_bg": None,
    },
]


def inner_svg(path: Path) -> str:
    text = path.read_text(encoding="utf-8")
    match = re.search(r"(<g fill-rule=\"evenodd\">.*?</g>)", text, re.S)
    if not match:
        raise RuntimeError(f"Could not find vector group in {path}")
    return match.group(1)


def recolor_group(group: str, fg: str) -> str:
    group = group.replace('fill="#F6F4EF"', f'fill="{fg}"')
    group = group.replace('fill="#0D0F12"', f'fill="{fg}"')
    return group


def text_to_paths(text: str, font_path: Path, size: float, x: float, baseline: float) -> str:
    paths, _ = text_to_paths_and_width(text, font_path, size, x, baseline)
    return paths


def text_to_paths_and_width(
    text: str,
    font_path: Path,
    size: float,
    x: float,
    baseline: float,
) -> tuple[str, float]:
    font = TTFont(font_path)
    glyph_set = font.getGlyphSet()
    cmap = font.getBestCmap()
    hmtx = font["hmtx"]
    units = font["head"].unitsPerEm
    scale = size / units

    parts: list[str] = []
    cursor = x
    for char in text:
        if char == " ":
            glyph_name = cmap[ord(" ")]
            advance, _ = hmtx[glyph_name]
            cursor += advance * scale
            continue
        glyph_name = cmap[ord(char)]
        pen = SVGPathPen(glyph_set)
        glyph_set[glyph_name].draw(pen)
        d = pen.getCommands()
        if d:
            parts.append(
                f'<path d="{d}" transform="translate({cursor:.2f} {baseline:.2f}) '
                f'scale({scale:.6f} {-scale:.6f})"/>'
            )
        advance, _ = hmtx[glyph_name]
        cursor += advance * scale
    return "\n      ".join(parts), cursor - x


def lotus_x_toni_wordmark_paths(
    fg: str,
    size: float,
    x: float,
    baseline: float,
    dot: str = "#DFA7B0",
) -> str:
    text = "Lotus × Tonı"
    paths, width = text_to_paths_and_width(text, FONT, size, x, baseline)
    _, before_i_width = text_to_paths_and_width("Lotus × Ton", FONT, size, x, baseline)
    dot_x = x + before_i_width + size * 0.075
    dot_y = baseline - size * 0.72
    dot_rx = size * 0.048
    dot_ry = size * 0.075
    return f"""<g fill="{fg}" fill-rule="nonzero">
      {paths}
    </g>
    <g fill="{dot}">
      <ellipse cx="{dot_x:.2f}" cy="{dot_y:.2f}" rx="{dot_rx:.2f}" ry="{dot_ry:.2f}" transform="rotate(28 {dot_x:.2f} {dot_y:.2f})"/>
      <circle cx="{dot_x + dot_rx * 0.56:.2f}" cy="{dot_y - dot_ry * 0.58:.2f}" r="{dot_rx * 0.32:.2f}" opacity="0.72"/>
    </g>"""


def checker_pattern() -> str:
    return """
  <defs>
    <pattern id="checker" width="24" height="24" patternUnits="userSpaceOnUse">
      <rect width="24" height="24" fill="#ffffff"/>
      <rect width="12" height="12" fill="#e4e4e4"/>
      <rect x="12" y="12" width="12" height="12" fill="#e4e4e4"/>
    </pattern>
  </defs>
"""


def lockup_svg(scenario: dict[str, str | None]) -> str:
    fg = str(scenario["fg"])
    symbol = recolor_group(inner_svg(SYMBOL), fg)
    wordmark = lotus_x_toni_wordmark_paths(fg, 102, 322, 218)

    bg = str(scenario["bg"])
    if bg == "none":
        bg_rect = '<rect width="1080" height="330" rx="32" fill="url(#checker)"/>'
    else:
        bg_rect = f'<rect width="1080" height="330" rx="32" fill="{bg}"/>'

    icon_bg = scenario["icon_bg"]
    if icon_bg:
        icon_plate = f'<rect x="72" y="84" width="170" height="82" rx="17" fill="{icon_bg}"/>'
        icon_transform = 'translate(84 93) scale(0.40)'
    else:
        icon_plate = ""
        icon_transform = 'translate(82 78) scale(0.49)'

    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{CANVAS_W}" height="{CANVAS_H}" viewBox="0 0 {CANVAS_W} {CANVAS_H}" role="img" aria-label="A1 Lotus Toni lockup on {html.escape(str(scenario['label']))} background">
  <title>A1 Lotus × Toni lockup / {html.escape(str(scenario['label']))}</title>
{checker_pattern() if bg == "none" else ""}
  {bg_rect}
  {icon_plate}
  <g transform="{icon_transform}">
    {symbol}
  </g>
  {wordmark}
</svg>
"""


def production_lockup_svg(fg: str = "#0D0F12") -> str:
    symbol = recolor_group(inner_svg(SYMBOL), fg)
    wordmark = lotus_x_toni_wordmark_paths(fg, 74, 230, 143)

    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="880" height="220" viewBox="0 0 880 220" role="img" aria-label="A1 Lotus times Toni lockup">
  <title>A1 Lotus × Toni lockup</title>
  <g transform="translate(48 44) scale(0.43)">
    {symbol}
  </g>
  {wordmark}
</svg>
"""


def overview_svg(scenarios: list[dict[str, str | None]]) -> str:
    tiles = []
    tile_w, tile_h = 500, 153
    x0, y0 = 44, 112
    gap_x, gap_y = 36, 58
    for index, scenario in enumerate(scenarios):
        col = index % 2
        row = index // 2
        x = x0 + col * (tile_w + gap_x)
        y = y0 + row * (tile_h + gap_y)
        label = html.escape(str(scenario["label"]))
        svg = lockup_svg(scenario)
        encoded = base64.b64encode(svg.encode("utf-8")).decode("ascii")
        tiles.append(f'<text x="{x}" y="{y - 18}" fill="#B7B8BC" font-family="JetBrains Mono, Consolas, monospace" font-size="16" font-weight="700">{label}</text>')
        tiles.append(f'<image x="{x}" y="{y}" width="{tile_w}" height="{tile_h}" href="data:image/svg+xml;base64,{encoded}"/>')

    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="1080" height="960" viewBox="0 0 1080 960" role="img" aria-label="A1 Lotus Toni background scenarios">
  <rect width="1080" height="960" fill="#111418"/>
  <text x="44" y="42" fill="#F2F2F0" font-family="Arial, sans-serif" font-size="24" font-weight="700">A1 Lotus × Toni / background scenarios</text>
  <text x="44" y="68" fill="#9C9DA3" font-family="JetBrains Mono, Consolas, monospace" font-size="14">Lotus and Toni use the same Instrument Serif size; the connector is a multiplication sign.</text>
  {''.join(tiles)}
</svg>
"""


def render_png(svg_path: Path, png_path: Path) -> None:
    subprocess.run(
        [
            str(EDGE),
            "--headless=new",
            "--disable-gpu",
            f"--screenshot={png_path}",
            f"--window-size={CANVAS_W},{CANVAS_H}",
            svg_path.resolve().as_uri(),
        ],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def render_overview(svg_path: Path, png_path: Path) -> None:
    subprocess.run(
        [
            str(EDGE),
            "--headless=new",
            "--disable-gpu",
            f"--screenshot={png_path}",
            "--window-size=1080,960",
            svg_path.resolve().as_uri(),
        ],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def main() -> None:
    for scenario in SCENARIOS:
        svg = lockup_svg(scenario)
        for suffix in ("", "-v2"):
            svg_path = OUT / f"a1-lotus-toni-lockup-{scenario['slug']}{suffix}.svg"
            png_path = svg_path.with_suffix(".png")
            svg_path.write_text(svg, encoding="utf-8")
            render_png(svg_path, png_path)

    svg = overview_svg(SCENARIOS)
    for suffix in ("", "-clean", "-v2"):
        overview = OUT / f"a1-lotus-toni-lockup-background-scenarios{suffix}.svg"
        overview_png = overview.with_suffix(".png")
        overview.write_text(svg, encoding="utf-8")
        render_overview(overview, overview_png)

    (OUT / "a1-lotus-toni-lockup-transparent-production.svg").write_text(
        production_lockup_svg("#0D0F12"),
        encoding="utf-8",
    )
    (OUT / "a1-lotus-toni-lockup-transparent-production-on-dark.svg").write_text(
        production_lockup_svg("#F6F4EF"),
        encoding="utf-8",
    )


def lotus_x_toni_wordmark_paths(
    fg: str,
    size: float,
    x: float,
    baseline: float,
    dot: str = "#DFA7B0",
) -> str:
    lotus_paths, lotus_width = text_to_paths_and_width("Lotus", FONT, size, x, baseline)
    times_size = size * 0.24
    times_gap = size * 0.28
    times_x = x + lotus_width + times_gap
    times_y = baseline - size * 0.36
    toni_x = times_x + size * 0.34 + times_gap
    toni_paths, _ = text_to_paths_and_width("Toni", FONT, size, toni_x, baseline)
    _, before_i_width = text_to_paths_and_width("Ton", FONT, size, toni_x, baseline)
    dot_x = toni_x + before_i_width + size * 0.075
    dot_y = baseline - size * 0.72
    dot_rx = size * 0.048
    dot_ry = size * 0.075
    return f"""<g fill="{fg}" fill-rule="nonzero">
      {lotus_paths}
      <g stroke="{fg}" stroke-width="{max(size * 0.034, 2):.2f}" stroke-linecap="round">
        <line x1="{times_x - times_size:.2f}" y1="{times_y - times_size:.2f}" x2="{times_x + times_size:.2f}" y2="{times_y + times_size:.2f}"/>
        <line x1="{times_x + times_size:.2f}" y1="{times_y - times_size:.2f}" x2="{times_x - times_size:.2f}" y2="{times_y + times_size:.2f}"/>
      </g>
      {toni_paths}
    </g>
    <g fill="{dot}">
      <ellipse cx="{dot_x:.2f}" cy="{dot_y:.2f}" rx="{dot_rx:.2f}" ry="{dot_ry:.2f}" transform="rotate(28 {dot_x:.2f} {dot_y:.2f})"/>
      <circle cx="{dot_x + dot_rx * 0.56:.2f}" cy="{dot_y - dot_ry * 0.58:.2f}" r="{dot_rx * 0.32:.2f}" opacity="0.72"/>
    </g>"""


if __name__ == "__main__":
    main()
