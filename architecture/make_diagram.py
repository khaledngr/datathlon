"""Builds the Datathlon architecture diagram.

Writes two files next to this script:
  datathlon-architecture.excalidraw  open it on excalidraw.com (menu > Open, or drag the file in) and edit it there
  datathlon-architecture.svg         quick preview, same layout
Logos: logos/*.svg from Simple Icons 13.21.0 (CC0 licence), coloured with each brand's colour.

Run:  python3 make_diagram.py
"""
import base64
import json
import random
from pathlib import Path

HERE = Path(__file__).parent
random.seed(8)  # group 8: stable ids, so re-running gives the same file

# Datathlon brand colors (brand/brand-sheet.html) + layer colors
BLUE, NIGHT = "#3946C0", "#101A4E"
FILL = {
    "source": "#E8ECFF", "ingest": "#D0EBFF", "bronze": "#FFD8A8", "silver": "#E9ECEF",
    "gold": "#FFEC99", "quarantine": "#FFC9C9", "output": "#B2F2BB", "tool": "#FFFFFF",
    "snowflake": "#F1F3FF", "cloud": "#EBFBEE", "tasks": "#FFF4E6",
}

boxes = []   # (id, x, y, w, h, text, kind, dashed, font_size)
arrows = []  # (id, points, label, dashed)


def box(key, x, y, w, h, text, kind, dashed=False, size=16):
    boxes.append((key, x, y, w, h, text, kind, dashed, size))


def arrow(key, points, label="", dashed=False):
    arrows.append((key, points, label, dashed))


# ---- layout ---------------------------------------------------------------
# No parentheses in labels (group request, 2 Nov). No TD numbers: the diagram shows Datathlon's architecture;
# where each part comes from is in docs/TD_INVENTORY.md (D-041).
box("title", 40, 0, 900, 40, "Data Pipeline of Datathlon", "tool", size=26)

# containers first, so they sit behind the boxes
box("snowflake", 680, 150, 700, 620, "", "snowflake", dashed=True)
box("cloud", 40, 810, 1640, 150, "", "cloud", dashed=True)
box("snowflake_label", 700, 158, 660, 30, "SNOWFLAKE", "snowflake", size=18)
box("cloud_label", 60, 818, 700, 30, "GOOGLE CLOUD · our one cloud provider · Frankfurt europe-west3, same region as Snowflake", "cloud", size=18)

box("tasks", 360, 60, 1020, 56,
    "Snowflake Tasks · every day 06:00: COPY INTO → MERGE → dbt build → gold\n"
    "2 automatic retries · a finalizer task logs every run", "tasks", size=15)

# 5 sources + the seed. 3 simulated OLTP systems, 2 real public APIs
box("s_orders", 40, 170, 260, 88, "Web orders · Postgres\nOLTP · web shop database\nsimulated in Docker\nUC1 · web channel", "source")
box("s_tills", 40, 274, 260, 88, "Store tills · Python feed\nOLTP · JSON files, live every 5 s\nUC1 · store channel\nsends bad rows on purpose", "source")
box("s_stock", 40, 378, 260, 88, "Warehouse stock · CSV\nOLTP · night inventory count\n+ control file · simulated · UC3", "source")
box("s_weather", 40, 482, 260, 88, "Weather · Open-Meteo API\nREAL · free, no key\nforecast + history per store city\nUC1 + UC3 context", "source")
box("s_holidays", 40, 586, 260, 88, "School + public holidays\nREAL · OpenHolidays API, free\nFR, BE, ES calendars\nUC1 + UC3 context", "source")
box("s_seed", 40, 690, 260, 64, "Catalogue · dbt seed\nproducts · stores · holidays", "source")

# ingestion: four methods
box("i_incr", 360, 170, 270, 88, "Incremental load\nPython · watermark + MERGE\npulls new rows once a day\nreconciled on every run", "ingest")
box("i_micro", 360, 274, 270, 88, "Micro-batch\nfiles → GCS bucket → COPY INTO\nevery few minutes", "ingest")
box("i_batch", 360, 378, 270, 88, "Daily batch\nCSV → GCS bucket → COPY INTO\nchecked against the control file", "ingest")
box("i_api", 360, 482, 270, 192, "API pull\n\nPython · JSON files\n→ GCS → COPY INTO\nonce a day\ntimeout, retry, fail loudly", "ingest")

# inside Snowflake
box("dbt", 920, 200, 430, 50, "dbt · tests · seed · docs · lineage", "tool")
box("bronze", 710, 200, 180, 480, "BRONZE\nraw, as received\n\nweb_orders\nweb_order_lines\ntill_sales_raw\nstock_snapshots\nweather_raw\nholidays_raw", "bronze")
box("silver", 920, 270, 200, 250, "SILVER\ncleaned, typed,\ndeduplicated\n\norders · till sales\nstock · products\nweather · holidays", "silver")
box("quarantine", 920, 560, 200, 120, "QUARANTINE\nbad rows + reason:\nduplicate, unknown\nproduct, 2099 date…", "quarantine")
box("gold", 1150, 270, 200, 410, "GOLD\ncomplete days only\n\ngold_sales_daily\nUC1\n\ngold_stock_cover_daily\nUC3\n\ngold_data_quality_daily", "gold")

# outputs
box("dashboard", 1440, 270, 240, 130, "Streamlit dashboard\nreads GOLD only\nUC1 revenue · UC3 alerts\n% rows quarantined", "output")
box("html", 1440, 450, 240, 100, "HTML presentation\nshows the dashboard\nnot sure we keep it here", "output", dashed=True)

# platform on Google Cloud
box("terraform", 60, 860, 380, 84, "Terraform\nSnowflake database, warehouses, roles\nGCS bucket + access for Snowflake · state in GCS", "tool")
box("gha", 460, 860, 300, 84, "GitHub Actions\nterraform plan on every pull request", "tool")
box("gcs", 780, 860, 340, 84, "GCS bucket\nlanding zone for till, stock, API files\n+ Terraform state", "tool")
box("cost", 1140, 860, 520, 84, "Costs & security\nSnowflake resource monitor: alert 80 %, stop 100 %\nGCP budget alert · key-pair login · read-only role on GOLD", "tool")

FADED = {"html": 40}   # opacity in %: the group is not sure the HTML page stays on the diagram
HEIGHT = 980

# ---- arrows ----------------------------------------------------------------
for i, y in enumerate((214, 318, 422)):
    arrow(f"src{i}", [(300, y), (360, y)])
    arrow(f"ing{i}", [(630, y), (710, y)])
arrow("src3", [(300, 526), (360, 526)])
arrow("src4", [(300, 630), (360, 630)])
arrow("ing3", [(630, 578), (710, 578)])
arrow("seed", [(300, 722), (905, 722), (905, 450), (920, 450)], "dbt seed")
arrow("b2s", [(890, 330), (920, 330)])
arrow("s2q", [(1020, 520), (1020, 560)], "fails a check")
arrow("s2g", [(1120, 400), (1150, 400)])
arrow("g2d", [(1350, 335), (1440, 335)])
arrow("d2h", [(1560, 400), (1560, 450)], dashed=True)
arrow("t1", [(800, 116), (800, 200)], "COPY INTO", dashed=True)
arrow("t2", [(1135, 116), (1135, 200)], "dbt build", dashed=True)


# ---- logos ------------------------------------------------------------------
# Simple Icons 13.21.0 (CC0), downloaded into logos/; Excel from Simple Icons 10.0.0 (removed in later versions). Colour = the brand colour from Simple Icons.
LOGO_COLOR = {
    "postgresql": "#4169E1", "python": "#3776AB", "dbt": "#FF694B", "googlecloudstorage": "#4285F4",
    "docker": "#2496ED", "snowflake": "#29B5E8", "googlecloud": "#4285F4", "microsoftexcel": "#217346",
    "streamlit": "#FF4B4B", "html5": "#E34F26", "terraform": "#844FBA", "githubactions": "#2088FF",
}
ICONS = {  # box -> logos shown on its left side
    "s_orders": ["postgresql", "docker"], "s_tills": ["python"], "s_stock": ["microsoftexcel"], "s_seed": ["dbt"],
    "i_incr": ["python"], "i_micro": ["googlecloudstorage"], "i_batch": ["googlecloudstorage"],
    "i_api": ["python", "googlecloudstorage"],
    "tasks": ["snowflake"], "dbt": ["dbt"],
    "dashboard": ["streamlit"], "html": ["html5"],
    "terraform": ["terraform"], "gha": ["githubactions"], "gcs": ["googlecloudstorage"], "cost": ["googlecloud"],
    "snowflake_label": ["snowflake"], "cloud_label": ["googlecloud"],
}
ICON, GAP = 28, 6


def logo_svg(slug):
    raw = (HERE / "logos" / f"{slug}.svg").read_text()
    return raw.replace("<svg ", f'<svg fill="{LOGO_COLOR[slug]}" ', 1)


# ---- spacing: widen columns so the logos fit next to the text ---------------------
def sx(x):
    return x + (80 if x >= 630 else 40 if x >= 300 else 0)


boxes = [(k, sx(x), y, sx(x + w) - sx(x), h, t, kind, d, size) for k, x, y, w, h, t, kind, d, size in boxes]
arrows = [(k, [(sx(px), py) for px, py in pts], label, d) for k, pts, label, d in arrows]
WIDTH = 1800


def icon_slots(key, x, y, h, free_text):
    """Where each logo goes: left of the box, centred vertically (or before a free label)."""
    slugs = ICONS.get(key, [])
    top = y + (2 if free_text else (h - ICON) / 2)
    left = x if free_text else x + 10
    return [(slug, left + i * (ICON + GAP), top) for i, slug in enumerate(slugs)]


def text_offset(key, free_text):
    n = len(ICONS.get(key, []))
    if n == 0:
        return 0
    return n * (ICON + GAP) if free_text else 10 + n * (ICON + GAP)


def label_at(pts):
    """Baseline position of an arrow label: beside a vertical arrow, above a horizontal one."""
    (x0, y0), (x1, y1) = pts[0], pts[1]
    if len(pts) > 2:
        return x0 + 48, y0 - 8
    if x0 == x1:
        return x0 + 8, y0 + 22
    return x0 + 8, y0 - 8


# ---- Excalidraw -----------------------------------------------------------
def base(el_id, kind, x, y, w, h, stroke=BLUE, bg="transparent", dashed=False, opacity=100):
    return {
        "id": el_id, "type": kind, "x": x, "y": y, "width": w, "height": h, "angle": 0,
        "strokeColor": stroke, "backgroundColor": bg, "fillStyle": "solid", "strokeWidth": 2,
        "strokeStyle": "dashed" if dashed else "solid", "roughness": 1, "opacity": opacity,
        "groupIds": [], "frameId": None, "roundness": {"type": 3} if kind == "rectangle" else {"type": 2},
        "seed": random.randint(1, 2**31), "version": 1, "versionNonce": random.randint(1, 2**31),
        "isDeleted": False, "boundElements": [], "updated": 1, "link": None, "locked": False,
    }


def text_el(el_id, x, y, w, h, text, size, container=None, align="center"):
    el = base(el_id, "text", x, y, w, h, stroke=NIGHT)
    el.update({
        "text": text, "originalText": text, "fontSize": size, "fontFamily": 2,
        "textAlign": align, "verticalAlign": "middle", "containerId": container,
        "lineHeight": 1.25, "autoResize": True, "roundness": None,
    })
    return el


files = {}
for slug in LOGO_COLOR:
    data = base64.b64encode(logo_svg(slug).encode()).decode()
    files[slug] = {"mimeType": "image/svg+xml", "id": slug, "dataURL": f"data:image/svg+xml;base64,{data}",
                   "created": 1, "lastRetrieved": 1}

elements = []
for key, x, y, w, h, text, kind, dashed, size in boxes:
    free = key in ("title", "snowflake_label", "cloud_label")  # free text, no box
    lines = text.count("\n") + 1
    th = lines * size * 1.25
    if free:
        elements.append(text_el(key, x + text_offset(key, free), y + 4, w, th, text, size, align="left"))
    else:
        fade = FADED.get(key, 100)
        rect = base(key, "rectangle", x, y, w, h, bg=FILL[kind], dashed=dashed, opacity=fade)
        elements.append(rect)
        off = text_offset(key, free)
        if text and off:   # text next to logos stays free, so Excalidraw does not re-centre it over them
            elements.append(text_el(key + "_t", x + off, y + (h - th) / 2, w - off - 8, th, text, size))
        elif text:
            t = text_el(key + "_t", x + 6, y + (h - th) / 2, w - 12, th, text, size, container=key)
            t["opacity"] = fade
            rect["boundElements"].append({"id": t["id"], "type": "text"})
            elements.append(t)
    for slug, ix, iy in icon_slots(key, x, y, h, free):
        img = base(f"{key}_{slug}", "image", ix, iy, ICON, ICON, stroke="transparent")
        img.update({"fileId": slug, "status": "saved", "scale": [1, 1], "roundness": None, "crop": None})
        elements.append(img)

for key, pts, label, dashed in arrows:
    x0, y0 = pts[0]
    rel = [[px - x0, py - y0] for px, py in pts]
    xs, ys = [p[0] for p in rel], [p[1] for p in rel]
    a = base(key, "arrow", x0, y0, max(xs) - min(xs), max(ys) - min(ys), stroke=NIGHT, dashed=dashed)
    a.update({"points": rel, "lastCommittedPoint": None, "startBinding": None, "endBinding": None,
              "startArrowhead": None, "endArrowhead": "arrow", "elbowed": False})
    elements.append(a)
    if label:
        mx, my = label_at(pts)
        elements.append(text_el(key + "_l", mx, my - 14, 120, 18, label, 14, align="left"))

doc = {"type": "excalidraw", "version": 2, "source": "https://excalidraw.com",
       "elements": elements, "appState": {"viewBackgroundColor": "#ffffff", "gridSize": None}, "files": files}
(HERE / "datathlon-architecture.excalidraw").write_text(json.dumps(doc, indent=1, ensure_ascii=False))


# ---- SVG preview ------------------------------------------------------------
def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


svg = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 -10 {WIDTH} {HEIGHT}" font-family="Helvetica, Arial, sans-serif">',
       '<defs><marker id="h" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto">'
       f'<path d="M0 0 L10 5 L0 10 z" fill="{NIGHT}"/></marker></defs>',
       f'<rect x="0" y="-10" width="{WIDTH}" height="{HEIGHT}" fill="#fff"/>']
for key, x, y, w, h, text, kind, dashed, size in boxes:
    lines = text.split("\n")
    free = key in ("title", "snowflake_label", "cloud_label")
    if free:
        svg.append(f'<text x="{x + text_offset(key, free)}" y="{y + size + 4}" font-size="{size}" font-weight="700" fill="{NIGHT}">{esc(text)}</text>')
    else:
        dash = ' stroke-dasharray="8 6"' if dashed else ""
        svg.append(f'<g opacity="{FADED.get(key, 100) / 100}">')
        svg.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="10" fill="{FILL[kind]}" stroke="{BLUE}" stroke-width="2"{dash}/>')
        off = text_offset(key, free)
        cx = x + off + (w - off - 8) / 2 if off else x + w / 2
        lh = size * 1.25
        top = y + (h - lh * len(lines)) / 2 + size
        for i, line in enumerate(lines):
            weight = ' font-weight="700"' if i == 0 else ""
            svg.append(f'<text x="{cx}" y="{top + i * lh:.1f}" font-size="{size}" text-anchor="middle" fill="{NIGHT}"{weight}>{esc(line)}</text>')
        svg.append("</g>")
    for slug, ix, iy in icon_slots(key, x, y, h, free):
        inner = logo_svg(slug).replace("<svg ", f'<svg x="{ix}" y="{iy}" width="{ICON}" height="{ICON}" ', 1)
        svg.append(inner)
for key, pts, label, dashed in arrows:
    dash = ' stroke-dasharray="6 5"' if dashed else ""
    d = " ".join(f"{px},{py}" for px, py in pts)
    svg.append(f'<polyline points="{d}" fill="none" stroke="{NIGHT}" stroke-width="2" marker-end="url(#h)"{dash}/>')
    if label:
        mx, my = label_at(pts)
        svg.append(f'<text x="{mx}" y="{my}" font-size="14" fill="{NIGHT}" font-style="italic">{esc(label)}</text>')
svg.append("</svg>")
(HERE / "datathlon-architecture.svg").write_text("\n".join(svg))
print("wrote", len(elements), "Excalidraw elements,", len(files), "logos + SVG preview")
