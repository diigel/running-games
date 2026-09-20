#!/usr/bin/env python3
"""Every obstacle must be beatable by at least one move.

Parses the real .tscn/.gd files so the check fails if anyone edits geometry
without re-checking clearance. Run: python tests/check_obstacle_clearance.py
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def const(source: str, name: str) -> float:
    m = re.search(rf"^const {name}: float = ([-\d.]+)", source, re.M)
    assert m, f"{name} not found"
    return float(m.group(1))


player = (ROOT / "player.gd").read_text(encoding="utf-8")
chunk_gd = (ROOT / "track_chunk.gd").read_text(encoding="utf-8")
main_gd = (ROOT / "main.gd").read_text(encoding="utf-8")

JUMP_FORCE = const(player, "JUMP_FORCE")
GRAVITY = const(player, "GRAVITY")
SLIDE_HEIGHT = const(player, "SLIDE_HEIGHT")
NORMAL_HEIGHT = const(player, "NORMAL_HEIGHT")
FLOOR_TOP_LOCAL = const(chunk_gd, "FLOOR_TOP_LOCAL")

# main.gd places the chunk root below the floor; the obstacle lift must cancel it.
chunk_y = float(
    re.search(r"chunk\.position = Vector3\(0\.0, ([-\d.]+),", main_gd).group(1)
)
assert abs(chunk_y + FLOOR_TOP_LOCAL) < 1e-6, (
    f"chunk root y={chunk_y} not cancelled by FLOOR_TOP_LOCAL={FLOOR_TOP_LOCAL}; "
    "obstacles would float or sink"
)

JUMP_APEX = JUMP_FORCE**2 / (2 * GRAVITY)
MARGIN = 0.15


def collision_box(path: Path) -> tuple[float, float]:
    """Return (y_bottom, y_top) of the obstacle's CollisionShape3D, in world space."""
    text = path.read_text(encoding="utf-8")
    height = float(
        re.search(
            r'\[sub_resource type="BoxShape3D".*?\nsize = Vector3\([-\d.]+, ([-\d.]+),',
            text,
            re.S,
        ).group(1)
    )
    node = text[text.index('[node name="CollisionShape3D"') :]
    node = node[: node.index("[node", 1)] if "[node" in node[1:] else node
    center_y = float(
        re.search(r"position = Vector3\([-\d.]+, ([-\d.]+),", node).group(1)
    )
    # chunk root offset + per-obstacle lift cancel out, so local == world here
    return center_y - height / 2, center_y + height / 2


failures = []
for path in sorted(ROOT.glob("obstacle_*.tscn")):
    bottom, top = collision_box(path)
    jumpable = JUMP_APEX >= top + MARGIN
    slideable = bottom >= SLIDE_HEIGHT + MARGIN
    verdict = "jump" if jumpable else ("slide" if slideable else "IMPOSSIBLE")
    print(f"{path.name:24} y {bottom:5.2f}..{top:5.2f}  -> {verdict}")

    if not (jumpable or slideable):
        failures.append(
            f"{path.name}: no move clears it (apex {JUMP_APEX:.2f}, slide top {SLIDE_HEIGHT})"
        )
    if jumpable and slideable:
        failures.append(
            f"{path.name}: ambiguous - both jump and slide work, obstacle reads as noise"
        )
    # A slide obstacle must actually punish standing, else sliding is pointless.
    if slideable and bottom >= NORMAL_HEIGHT:
        failures.append(
            f"{path.name}: standing player already clears it; not an obstacle"
        )

# Kampung scenery has no collider. If it visually crosses the track it reads as a
# fake obstacle and the player brakes for nothing.
ROAD_EDGE = const(chunk_gd, "ROAD_EDGE")

house_x = re.search(
    r'var clear_x: float = ROAD_EDGE \+ float\(house\.get_meta\("radius"\)\)'
    r" \+ randf_range\(([\d.]+),",
    chunk_gd,
)
assert house_x, "houses no longer offset by ROAD_EDGE + their own bounding radius"
if float(house_x.group(1)) <= 0:
    failures.append("houses can spawn flush against the track edge")

assert re.search(
    r"side \* \(ROAD_EDGE \+ Bounds\.radius\(prop\) \+ randf_range\(", chunk_gd
), "scattered props no longer offset by ROAD_EDGE + their own measured radius"

scatters = re.findall(r"_scatter\((\w+), \d+, ([-\d.]+),", chunk_gd)
assert scatters, "no _scatter() calls found"
for name, gap_min in scatters:
    if float(gap_min) < 0:
        failures.append(
            f"_scatter({name}, ...) gap_min={gap_min} lets props overhang the track"
        )
print(f"{len(scatters)} scatter bands, all clear of track edge {ROAD_EDGE}")

# Flat path stones sit on the running surface, so they must never cover a lane
# centre or they read as something to dodge.
PATH_JITTER = const(chunk_gd, "PATH_JITTER")
PATH_FIT_WIDTH = const(chunk_gd, "PATH_FIT_WIDTH")
PATH_LANE_CLEARANCE = const(chunk_gd, "PATH_LANE_CLEARANCE")
lanes = [
    float(v)
    for v in re.search(r"const LANE_POSITIONS: Array\[float\] = \[([^\]]+)\]", chunk_gd)
    .group(1)
    .split(",")
]
path_offsets = [
    float(v)
    for v in re.search(r"const PATH_OFFSETS: Array\[float\] = \[([^\]]+)\]", chunk_gd)
    .group(1)
    .split(",")
]
stone_half = PATH_FIT_WIDTH / 2 + PATH_JITTER
for offset in path_offsets:
    for sign in (-1.0, 1.0):
        near, far = sign * offset - stone_half, sign * offset + stone_half
        for lane in lanes:
            if near - PATH_LANE_CLEARANCE <= lane <= far + PATH_LANE_CLEARANCE:
                failures.append(
                    f"path stone at x={sign * offset:+.2f} (+/-{stone_half:.2f}) "
                    f"crowds lane centre {lane}"
                )
print(f"path stones at +/-{path_offsets}, half-span {stone_half:.2f}, lanes {lanes}")

# Laundry is decorative, but a hem dangling below the collider would promise
# clearance the physics doesn't give.
jemuran = (ROOT / "jemuran.gd").read_text(encoding="utf-8")
HEM_FLOOR = const(jemuran, "HEM_FLOOR")
slide_bottom, slide_top = collision_box(ROOT / "obstacle_slide.tscn")
if HEM_FLOOR < slide_bottom:
    failures.append(
        f"laundry hem {HEM_FLOOR} hangs below collider bottom {slide_bottom}"
    )
if const(jemuran, "ROPE_Y") > slide_top:
    failures.append("washing line sits above the collider; garments float free")
print(f"laundry hem {HEM_FLOOR} inside collider {slide_bottom}..{slide_top}")

listed = set(re.findall(r'"(res://obstacle_\w+\.tscn)"', chunk_gd))
on_disk = {f"res://{p.name}" for p in ROOT.glob("obstacle_*.tscn")}
if listed != on_disk:
    failures.append(f"spawn table {sorted(listed)} != files on disk {sorted(on_disk)}")

print(
    f"\njump apex {JUMP_APEX:.2f} | slide top {SLIDE_HEIGHT} | stand top {NORMAL_HEIGHT}"
)
if failures:
    print("\nFAIL:")
    for f in failures:
        print("  -", f)
    sys.exit(1)
print("OK: every obstacle has exactly one correct response")
