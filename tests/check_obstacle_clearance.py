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
chunk_y = float(re.search(r"chunk\.position = Vector3\(0\.0, ([-\d.]+),", main_gd).group(1))
assert abs(chunk_y + FLOOR_TOP_LOCAL) < 1e-6, (
    f"chunk root y={chunk_y} not cancelled by FLOOR_TOP_LOCAL={FLOOR_TOP_LOCAL}; "
    "obstacles would float or sink"
)

JUMP_APEX = JUMP_FORCE ** 2 / (2 * GRAVITY)
MARGIN = 0.15


def collision_box(path: Path) -> tuple[float, float]:
    """Return (y_bottom, y_top) of the obstacle's CollisionShape3D, in world space."""
    text = path.read_text(encoding="utf-8")
    height = float(
        re.search(r'\[sub_resource type="BoxShape3D".*?\nsize = Vector3\([-\d.]+, ([-\d.]+),',
                  text, re.S).group(1)
    )
    node = text[text.index('[node name="CollisionShape3D"'):]
    node = node[:node.index("[node", 1)] if "[node" in node[1:] else node
    center_y = float(re.search(r"position = Vector3\([-\d.]+, ([-\d.]+),", node).group(1))
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
        failures.append(f"{path.name}: no move clears it (apex {JUMP_APEX:.2f}, slide top {SLIDE_HEIGHT})")
    if jumpable and slideable:
        failures.append(f"{path.name}: ambiguous - both jump and slide work, obstacle reads as noise")
    # A slide obstacle must actually punish standing, else sliding is pointless.
    if slideable and bottom >= NORMAL_HEIGHT:
        failures.append(f"{path.name}: standing player already clears it; not an obstacle")

listed = set(re.findall(r'"(res://obstacle_\w+\.tscn)"', chunk_gd))
on_disk = {f"res://{p.name}" for p in ROOT.glob("obstacle_*.tscn")}
if listed != on_disk:
    failures.append(f"spawn table {sorted(listed)} != files on disk {sorted(on_disk)}")

print(f"\njump apex {JUMP_APEX:.2f} | slide top {SLIDE_HEIGHT} | stand top {NORMAL_HEIGHT}")
if failures:
    print("\nFAIL:")
    for f in failures:
        print("  -", f)
    sys.exit(1)
print("OK: every obstacle has exactly one correct response")
