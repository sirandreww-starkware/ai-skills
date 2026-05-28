"""Programmatic builder for Excalidraw (.excalidraw) files.

Public API:
    Diagram          - collect elements, save to a v2 .excalidraw file
    Palette          - named (fill, stroke) pairs with consistent semantics

The helper hides Excalidraw schema boilerplate, enforces reciprocal
arrow<->rect bindings, and creates label text elements with the right
`containerId` linkage. It also provides a few sugar paths for routing
arrows around obstacles (via_y, via_x, around).

A typical use:

    from excalidraw_builder import Diagram, Palette
    d = Diagram()
    d.title("My Pipeline", x=300, y=10)
    d.rect("a", 100, 80, 140, 50, label="Source",  palette=Palette.EXTERNAL)
    d.rect("b", 320, 80, 140, 50, label="Sink",    palette=Palette.STORAGE)
    d.arrow("a_b", "a", "b", label="writes")
    d.save("/tmp/demo.excalidraw")
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from typing import Iterable


# ---------------------------------------------------------------------------
# Palette
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class PaletteEntry:
    fill: str
    stroke: str


class Palette:
    EXTERNAL = PaletteEntry("#ffd8a8", "#c2410c")  # orange - sources, L1, FGW
    INGEST   = PaletteEntry("#a5d8ff", "#2563eb")  # blue   - IO / ingestion
    LOGIC    = PaletteEntry("#d0bfff", "#7c3aed")  # purple - orchestration
    EXEC     = PaletteEntry("#b2f2bb", "#15803d")  # green  - execution
    OUTPUT   = PaletteEntry("#eebefa", "#a21caf")  # pink   - finalization
    STORAGE  = PaletteEntry("#c3fae8", "#0d9488")  # teal   - storage / infra


_STROKE_STYLES = {"solid", "dashed", "dotted"}
_SIDES = {"top", "bottom", "left", "right"}


# ---------------------------------------------------------------------------
# Diagram
# ---------------------------------------------------------------------------


class Diagram:
    def __init__(self) -> None:
        self._elements: list[dict] = []
        self._by_id: dict[str, dict] = {}
        self._seed: int = 1000

    # ---- low-level ---------------------------------------------------------

    def _next_seed(self) -> int:
        self._seed += 1
        return self._seed

    def _base(self, eid: str, etype: str) -> dict:
        if eid in self._by_id:
            raise ValueError(f"duplicate id: {eid}")
        s = self._next_seed()
        return {
            "id": eid,
            "type": etype,
            "strokeColor": "#1e1e1e",
            "backgroundColor": "transparent",
            "fillStyle": "solid",
            "strokeWidth": 2,
            "strokeStyle": "solid",
            "roughness": 1,
            "opacity": 100,
            "seed": s,
            "version": 1,
            "versionNonce": s,
            "isDeleted": False,
            "groupIds": [],
            "frameId": None,
            "roundness": None,
            "boundElements": [],
            "updated": 1,
            "link": None,
            "locked": False,
        }

    def _add(self, el: dict) -> str:
        self._elements.append(el)
        self._by_id[el["id"]] = el
        return el["id"]

    # ---- primitives --------------------------------------------------------

    def text(
        self,
        eid: str,
        x: int,
        y: int,
        text: str,
        *,
        font: int = 14,
        color: str = "#1e1e1e",
        w: int | None = None,
        h: int | None = None,
        container: str | None = None,
        align: str = "left",
        valign: str = "top",
    ) -> str:
        if w is None:
            w = max(20, int(len(text) * font * 0.55))
        if h is None:
            h = int(font * 1.25)
        el = self._base(eid, "text")
        el.update({
            "x": x, "y": y, "width": w, "height": h,
            "text": text,
            "fontSize": font,
            "fontFamily": 1,
            "textAlign": align,
            "verticalAlign": valign,
            "containerId": container,
            "originalText": text,
            "autoResize": True,
            "lineHeight": 1.25,
            "strokeColor": color,
        })
        return self._add(el)

    def title(self, text: str, x: int, y: int, *, font: int = 28) -> str:
        return self.text(f"_title_{self._seed}", x, y, text, font=font)

    def note(
        self,
        text: str,
        x: int,
        y: int,
        *,
        font: int = 11,
        color: str = "#757575",
    ) -> str:
        return self.text(
            f"_note_{self._seed}", x, y, text, font=font, color=color
        )

    def rect(
        self,
        eid: str,
        x: int,
        y: int,
        w: int,
        h: int,
        *,
        label: str | None = None,
        fill: str | None = None,
        stroke: str | None = None,
        palette: PaletteEntry | None = None,
        font: int = 14,
    ) -> str:
        if palette is not None:
            fill = fill or palette.fill
            stroke = stroke or palette.stroke
        r = self._base(eid, "rectangle")
        r.update({
            "x": x, "y": y, "width": w, "height": h,
            "backgroundColor": fill or "transparent",
            "strokeColor": stroke or "#1e1e1e",
            "roundness": {"type": 3},
        })
        self._add(r)
        if label is not None:
            label_id = f"{eid}_t"
            t = self.text(
                label_id, x, y + (h - font) // 2, label,
                font=font, w=w, h=font + 4, container=eid,
                align="center", valign="middle",
            )
            r["boundElements"].append({"type": "text", "id": label_id})
        return eid

    # ---- arrows ------------------------------------------------------------

    def arrow(
        self,
        eid: str,
        start: str,
        end: str,
        *,
        points: list[tuple[int, int]] | list[list[int]] | None = None,
        via_y: int | None = None,
        via_x: int | None = None,
        around: tuple[str, str] | None = None,
        label: str | None = None,
        label_pos: tuple[int, int] | None = None,
        label_offset: tuple[int, int] = (0, 0),
        style: str = "solid",
        bidirectional: bool = False,
        gap: int = 12,
    ) -> str:
        """Add an arrow with reciprocal binding to start/end rectangles.

        Path selection (first match wins):
            points=...           - raw polyline of absolute (x, y) waypoints
            via_y=Y              - 4-point bend through horizontal channel y=Y
            via_x=X              - 4-point bend through vertical   channel x=X
            around=(rect_id, side) - detour around `rect_id` on its `side`
                                     (top | bottom | left | right)
            (default)            - straight edge-snapped line between rects

        `gap` is the clearance used when computing detours (around=, via_y, via_x).
        """
        if style not in _STROKE_STYLES:
            raise ValueError(f"style must be one of {_STROKE_STYLES}")

        start_rect = self._require_rect(start, "start")
        end_rect = self._require_rect(end, "end")

        if points is not None:
            poly = [tuple(p) for p in points]
        elif via_y is not None:
            poly = self._route_via_y(start_rect, end_rect, via_y)
        elif via_x is not None:
            poly = self._route_via_x(start_rect, end_rect, via_x)
        elif around is not None:
            other_id, side = around
            other = self._require_rect(other_id, "around")
            poly = self._route_around(start_rect, end_rect, other, side, gap)
        else:
            poly = self._edge_snap(start_rect, end_rect)

        sx, sy = poly[0]
        rel = [[p[0] - sx, p[1] - sy] for p in poly]
        # Width/height encode bounding box of the polyline; required by Excalidraw.
        xs = [p[0] for p in rel]
        ys = [p[1] for p in rel]
        bbox_w = max(xs) - min(xs) or 1
        bbox_h = max(ys) - min(ys) or 1

        a = self._base(eid, "arrow")
        a.update({
            "x": sx, "y": sy,
            "width": bbox_w, "height": bbox_h,
            "points": rel,
            "strokeStyle": style,
            "startBinding": {"elementId": start, "focus": 0, "gap": 1},
            "endBinding": {"elementId": end, "focus": 0, "gap": 1},
            "startArrowhead": "arrow" if bidirectional else None,
            "endArrowhead": "arrow",
            "lastCommittedPoint": None,
            "elbowed": False,
        })
        self._add(a)

        # Reciprocal binding on each endpoint rectangle.
        for rid in (start, end):
            self._by_id[rid]["boundElements"].append(
                {"type": "arrow", "id": eid}
            )

        if label is not None:
            self._attach_arrow_label(a, poly, label, label_pos, label_offset)

        return eid

    # ---- routing helpers ---------------------------------------------------

    @staticmethod
    def _center(rect: dict) -> tuple[int, int]:
        return (
            rect["x"] + rect["width"] // 2,
            rect["y"] + rect["height"] // 2,
        )

    @staticmethod
    def _edges(rect: dict) -> dict[str, tuple[int, int]]:
        x, y, w, h = rect["x"], rect["y"], rect["width"], rect["height"]
        return {
            "top":    (x + w // 2, y),
            "bottom": (x + w // 2, y + h),
            "left":   (x,           y + h // 2),
            "right":  (x + w,       y + h // 2),
        }

    def _edge_snap(self, a: dict, b: dict) -> list[tuple[int, int]]:
        """Straight line between the closest edge midpoints of two rects."""
        ac = self._center(a)
        bc = self._center(b)
        dx = bc[0] - ac[0]
        dy = bc[1] - ac[1]
        a_edges = self._edges(a)
        b_edges = self._edges(b)
        if abs(dx) >= abs(dy):
            a_side = "right" if dx >= 0 else "left"
            b_side = "left" if dx >= 0 else "right"
        else:
            a_side = "bottom" if dy >= 0 else "top"
            b_side = "top" if dy >= 0 else "bottom"
        return [a_edges[a_side], b_edges[b_side]]

    def _route_via_y(
        self, a: dict, b: dict, channel_y: int
    ) -> list[tuple[int, int]]:
        a_edges = self._edges(a)
        b_edges = self._edges(b)
        a_side = "bottom" if channel_y > self._center(a)[1] else "top"
        b_side = "bottom" if channel_y > self._center(b)[1] else "top"
        a_pt = a_edges[a_side]
        b_pt = b_edges[b_side]
        return [a_pt, (a_pt[0], channel_y), (b_pt[0], channel_y), b_pt]

    def _route_via_x(
        self, a: dict, b: dict, channel_x: int
    ) -> list[tuple[int, int]]:
        a_edges = self._edges(a)
        b_edges = self._edges(b)
        a_side = "right" if channel_x > self._center(a)[0] else "left"
        b_side = "right" if channel_x > self._center(b)[0] else "left"
        a_pt = a_edges[a_side]
        b_pt = b_edges[b_side]
        return [a_pt, (channel_x, a_pt[1]), (channel_x, b_pt[1]), b_pt]

    def _route_around(
        self,
        a: dict,
        b: dict,
        obstacle: dict,
        side: str,
        gap: int,
    ) -> list[tuple[int, int]]:
        if side not in _SIDES:
            raise ValueError(f"around side must be one of {_SIDES}")
        ox, oy = obstacle["x"], obstacle["y"]
        ow, oh = obstacle["width"], obstacle["height"]
        if side in ("top", "bottom"):
            channel_y = (oy - gap) if side == "top" else (oy + oh + gap)
            return self._route_via_y(a, b, channel_y)
        channel_x = (ox - gap) if side == "left" else (ox + ow + gap)
        return self._route_via_x(a, b, channel_x)

    # ---- labels ------------------------------------------------------------

    def _attach_arrow_label(
        self,
        arrow_el: dict,
        poly: list[tuple[int, int]],
        text: str,
        explicit_pos: tuple[int, int] | None,
        offset: tuple[int, int],
    ) -> None:
        if explicit_pos is not None:
            cx, cy = explicit_pos
        else:
            # Midpoint of the longest segment so labels on bent arrows land on
            # a real run rather than at a corner.
            best_len = -1.0
            cx, cy = poly[0]
            for i in range(len(poly) - 1):
                ax, ay = poly[i]
                bx, by = poly[i + 1]
                seg = ((bx - ax) ** 2 + (by - ay) ** 2) ** 0.5
                if seg > best_len:
                    best_len = seg
                    cx = (ax + bx) // 2
                    cy = (ay + by) // 2
        cx += offset[0]
        cy += offset[1]
        font = 12
        w = max(30, int(len(text) * font * 0.6))
        h = font + 4
        label_id = f"{arrow_el['id']}_l"
        self.text(
            label_id, cx - w // 2, cy - h // 2, text,
            font=font, w=w, h=h, container=arrow_el["id"],
            align="center", valign="middle",
        )
        arrow_el["boundElements"].append({"type": "text", "id": label_id})

    # ---- internal lookups --------------------------------------------------

    def _require_rect(self, rid: str, label: str) -> dict:
        el = self._by_id.get(rid)
        if el is None:
            raise KeyError(f"unknown {label} id: {rid}")
        if el["type"] != "rectangle":
            raise TypeError(
                f"{label} id {rid!r} refers to a {el['type']}, not a rectangle"
            )
        return el

    # ---- output ------------------------------------------------------------

    def save(self, path: str) -> None:
        doc = {
            "type": "excalidraw",
            "version": 2,
            "source": "https://excalidraw.com",
            "elements": self._elements,
            "appState": {
                "gridSize": None,
                "viewBackgroundColor": "#ffffff",
            },
            "files": {},
        }
        with open(path, "w") as f:
            json.dump(doc, f, indent=2)

    # ---- validation --------------------------------------------------------

    def validate(self) -> list[str]:
        """Return a list of problem strings; empty list means clean."""
        problems: list[str] = []
        ids = self._by_id

        for el in self._elements:
            eid = el["id"]
            if el["type"] == "arrow":
                for end_key in ("startBinding", "endBinding"):
                    b = el.get(end_key)
                    if not b:
                        continue
                    rid = b["elementId"]
                    rect = ids.get(rid)
                    if rect is None:
                        problems.append(
                            f"arrow {eid} {end_key} -> missing rect {rid}"
                        )
                        continue
                    if not any(
                        be.get("type") == "arrow" and be.get("id") == eid
                        for be in rect.get("boundElements", [])
                    ):
                        problems.append(
                            f"arrow {eid} not listed in {rid}.boundElements"
                        )
                for be in el.get("boundElements", []):
                    if be["type"] == "text":
                        t = ids.get(be["id"])
                        if t is None:
                            problems.append(
                                f"arrow {eid} label {be['id']} missing"
                            )
                        elif t.get("containerId") != eid:
                            problems.append(
                                f"label {be['id']} containerId != {eid}"
                            )
            elif el["type"] == "rectangle":
                for be in el.get("boundElements", []):
                    target = ids.get(be["id"])
                    if target is None:
                        problems.append(
                            f"rect {eid}.boundElements references missing "
                            f"{be['id']}"
                        )

        return problems

    # ---- introspection -----------------------------------------------------

    @property
    def elements(self) -> list[dict]:
        return list(self._elements)

    def __len__(self) -> int:
        return len(self._elements)


__all__ = ["Diagram", "Palette", "PaletteEntry"]
