---
description: "Generate .excalidraw files programmatically. Use when the user asks to create, save, or update a .excalidraw file on disk (vs. just the inline MCP preview). A Python helper handles schema boilerplate, reciprocal arrow<->rect bindings, arrow labels, and bent-path routing around obstacles."
argument-hint: "[optional: what to draw, or a path to an existing .excalidraw to edit]"
---

# Excalidraw

Build hand-drawn-style architecture / flow / sequence diagrams as
`.excalidraw` files. Files open in the Excalidraw desktop app, the VS Code
Excalidraw extension, or by drag-and-drop onto https://excalidraw.com.

## When to use this skill (and when not to)

| Goal | Tool |
|---|---|
| **Save a `.excalidraw` file on disk** | This skill |
| **Inline animated preview during conversation** | `mcp__excalidraw__create_view` |
| **Upload to excalidraw.com and get a share URL** | `mcp__excalidraw__export_to_excalidraw` |

The MCP `create_view` format accepts shortcuts like `cameraUpdate`,
`label: { text: ... }` on shapes, and labeled arrows in one line - but those
shortcuts are NOT valid in saved `.excalidraw` files. Use the helper here
when you need a file; use the MCP when you need a transient preview.

## Workflow

1. **Plan the layout on paper first.** Decide rows (each at a fixed `y`),
   columns, which boxes go where, and where arrows might cross other boxes.
2. **Write a small Python script** that imports the helper and declares the
   diagram. Aim for one rectangle per line; group rows together with
   blank-line separation.
3. **Run the script** to write the `.excalidraw` file.
4. **Validate.** Call `Diagram.validate()` (expects `[]`) and parse the JSON
   to confirm element count.
5. **Spot-check visually** by uploading via the export MCP or opening
   excalidraw.com.

## Importing the helper

```python
import sys
sys.path.insert(0, "/home/andrew/.claude/skills/excalidraw/scripts")
from excalidraw_builder import Diagram, Palette
```

The helper has no external dependencies - stdlib only.

## API reference

```python
d = Diagram()

# Standalone text (titles, footer notes)
d.title("My Diagram", x=300, y=10, font=28)
d.note("Footnote text", x=10, y=600)
d.text("subtitle", x=320, y=50, "subtitle text", font=16, color="#757575")

# Rectangles with optional centered label
d.rect("a", x=100, y=80, w=140, h=50,
       label="Source", palette=Palette.EXTERNAL, font=14)
d.rect("b", x=320, y=80, w=140, h=50,
       label="Sink", fill="#a5d8ff", stroke="#2563eb")

# Arrows - pick ONE routing mode:
d.arrow("a_b", "a", "b")                           # edge-snap straight
d.arrow("a_b", "a", "b", label="writes")           # with label
d.arrow("a_b", "a", "b", via_y=200)                # one bend through y=200
d.arrow("a_b", "a", "b", via_x=400)                # one bend through x=400
d.arrow("a_b", "a", "b", around=("obstacle", "top"))   # detour over obstacle
d.arrow("a_b", "a", "b", points=[(100, 80), (200, 80), (200, 200)])  # raw
d.arrow("a_b", "a", "b", style="dashed")           # solid|dashed|dotted
d.arrow("a_b", "a", "b", bidirectional=True)       # arrowheads both ends
d.arrow("a_b", "a", "b", label="x", label_pos=(250, 180))  # explicit label

# Validate + save
problems = d.validate()   # [] when clean
d.save("/path/to/output.excalidraw")
```

All `eid` arguments must be unique strings; reuse triggers `ValueError`.

## `Palette` (semantic color pairs)

| Name | Fill | Stroke | Typical use |
|---|---|---|---|
| `Palette.EXTERNAL` | `#ffd8a8` | `#c2410c` | External sources, users, L1 |
| `Palette.INGEST`   | `#a5d8ff` | `#2563eb` | Gateways, IO, ingestion |
| `Palette.LOGIC`    | `#d0bfff` | `#7c3aed` | Orchestration, consensus, decision |
| `Palette.EXEC`     | `#b2f2bb` | `#15803d` | Execution, transformation |
| `Palette.OUTPUT`   | `#eebefa` | `#a21caf` | Sinks, finalization, output |
| `Palette.STORAGE`  | `#c3fae8` | `#0d9488` | Databases, infra, caches |

Stick to these for consistent semantics across diagrams. Pass `fill=` /
`stroke=` directly only when you need a one-off color.

## Stroke style conventions

| Style | Meaning |
|---|---|
| `solid` (default) | Main data flow |
| `dashed` | Auxiliary / control / RPC dependency |
| `dotted` | Storage I/O / persistence side-effect |

## Layout playbook

- **Rows**: assign each layer a fixed `y` value, with ~30 px gap between
  rows for arrows to route through. Typical sizes: 50–55 px tall, gaps
  20–30 px.
- **Columns**: 50–70 px gap between boxes lets arrow labels fit cleanly.
- **Box width**: 120–200 px typical. Don't shrink below 110 px or labels
  wrap.
- **Fonts**: 28 pt title, 16 pt subtitle, 14 pt box labels, 12 pt arrow
  labels, 11 pt footer notes. Don't go below 11.
- **Canvas size**: aim for 800–1100 px wide. Saved files aren't bound to
  the 4:3 camera ratios that constrain the MCP `create_view` tool.
- **Section labels**: a small standalone `note(...)` text at the far-left
  of each row reads better than a wrapping zone background.

## Avoiding arrow crossings

Long diagonals are the #1 source of ugly diagrams. Before drawing an
arrow, check whether its straight path crosses any other rect. The four
routing modes in priority order:

1. **Straight (default)** - only when the path is clear.
2. **`via_y=Y`** - when the channel between two rows is clear at height Y.
   Builds a 4-point path: `start_edge → (start_x, Y) → (end_x, Y) → end_edge`.
3. **`via_x=X`** - same idea, vertical channel at column X.
4. **`around=(rect_id, side)`** - when one specific box blocks the path.
   `side` ∈ {`top`, `bottom`, `left`, `right`} picks which way to detour.
5. **`points=[...]`** - raw polyline. Use only when none of the above fit.

Detour gaps default to 12 px past the obstacle edge - adjust with `gap=`.

## Worked example

```python
import sys
sys.path.insert(0, "/home/andrew/.claude/skills/excalidraw/scripts")
from excalidraw_builder import Diagram, Palette

d = Diagram()
d.title("Producer / Consumer", x=280, y=10)

# Row 1
d.rect("user",  100, 80, 140, 50, label="User",     palette=Palette.EXTERNAL)
d.rect("queue", 320, 80, 140, 50, label="Queue",    palette=Palette.INGEST)
d.rect("worker",540, 80, 160, 50, label="Worker",   palette=Palette.EXEC)

# Row 2 (storage)
d.rect("db",    320, 230, 220, 55, label="Database", palette=Palette.STORAGE)

# Main flow
d.arrow("u_q", "user",   "queue",  label="enqueue")
d.arrow("q_w", "queue",  "worker", label="dequeue")
d.arrow("w_d", "worker", "db",     label="write", style="dotted")
# Long return arrow - detour around the queue instead of crossing it
d.arrow("w_u", "worker", "user",
        around=("queue", "top"),
        label="ack", style="dashed")

assert d.validate() == []
d.save("/tmp/producer_consumer.excalidraw")
```

## Verification

After running your script:

```bash
python3 - <<'PY'
import json
d = json.load(open("/tmp/your.excalidraw"))
print("elements:", len(d["elements"]))
print("rects:   ", sum(1 for e in d["elements"] if e["type"] == "rectangle"))
print("arrows:  ", sum(1 for e in d["elements"] if e["type"] == "arrow"))
PY
```

Then open the file in Excalidraw and confirm:

- Arrows visibly attach to rectangle edges (no floating endpoints).
- Dragging a rectangle drags every connected arrow with it.
- Arrow labels stay centered on the arrow when the arrow is dragged.

## Lessons / gotchas

- **Bindings are reciprocal.** The helper does this automatically: every
  arrow it creates appears in both endpoint rectangles' `boundElements`.
  Hand-rolling JSON without this silently breaks "drag-the-box-the-arrow-
  follows" behaviour.
- **Arrow labels are separate `text` elements** with `containerId` set to
  the arrow's id (and the arrow's `boundElements` lists the text). The
  helper does this when you pass `label=`.
- **Don't put `cameraUpdate` in saved files** - it's an MCP-only pseudo-
  element. The helper would never emit one.
- **Don't put `label: {...}` on rectangles in saved files** - same. Use
  `d.rect(..., label="...")`, which creates a real bound `text` element.
- **`points` is relative to the arrow's `(x, y)`** in the schema. The
  helper converts absolute waypoints for you; don't pass relative offsets.
- **Long diagonals across many rows almost always cross something.** Prefer
  `via_y`/`via_x` over `points=...` so the routing intent is in the code.
- **Reusing an id raises `ValueError`** at build time, not at save time -
  fix it where you reuse, not by post-processing.
