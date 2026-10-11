"""Builds the kampung-boy runner character (peci + baju koko + sarung + sandal jepit)
matching player.png, rigs it, authors Idle/Run/Jump/Slide, and exports models/player.glb.

Run:  blender --background --python blender/build_player.py
"""

# ruff: noqa: E402
# pyright: reportMissingImports=false
# bpy/mathutils only exist inside Blender's bundled interpreter.

import math
import os

import bpy
from mathutils import Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT_GLB = os.path.join(ROOT, "models", "player.glb")
# Kept out of res:// so Godot does not try to import the .blend and demand a
# configured Blender executable; models/player.glb is the committed artifact.
OUT_BLEND = os.path.join(HERE, ".out", "player.blend")
OUT_PREVIEW = os.path.join(HERE, "preview.png")

TAU = math.pi * 2.0
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))

# Blender is Z-up / -Y forward; glTF export flips it to Godot's Y-up / -Z forward,
# so a character facing -Y here ends up running away from the camera in Godot.

# --- Proportions, metres, soles at z=0 (traced off player.png) ----------------
H_TOTAL = 1.55
Z_ANKLE, Z_KNEE, Z_HIP = 0.09, 0.42, 0.78
Z_WAIST, Z_CHEST, Z_SHOULDER, Z_NECK = 0.80, 1.02, 1.07, 1.09
Z_HEAD, Z_HEAD_TOP, Z_PECI_TOP = 1.25, 1.40, 1.46
X_SHOULDER, X_ELBOW, X_WRIST, X_FINGER = 0.15, 0.40, 0.56, 0.69
X_LEG = 0.105
# In player.png the baju koko hem hangs over the sarung rather than tucking in,
# so the shirt bottom sits below the sarung's top edge.
Z_SARONG_TOP, Z_SARONG_HEM = 0.78, 0.165
Z_SHIRT_HEM = 0.60


# --- Materials ---------------------------------------------------------------
def mat(name, color, rough=0.65, image=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    if image is not None:
        tex = m.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = image
        tex.location = (-400, 200)
        m.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    m.diffuse_color = (*color, 1.0)  # viewport/workbench fallback
    return m


def make_plaid(size=256, repeats=4):
    """Green/blue/white sarung check, baked straight to pixels so the glTF carries
    a real texture instead of a procedural node tree the exporter would drop."""
    img = bpy.data.images.new("SarongPlaid", size, size, alpha=False)
    # player.png reads as a bright grass green with *thin* navy/white stripes.
    # The earlier mix had wide dark bands, which averaged out to near-black once
    # the mesh was shaded.
    base, dark, blue, white = (
        (0.185, 0.420, 0.105),
        (0.120, 0.300, 0.070),
        (0.045, 0.130, 0.420),
        (0.780, 0.840, 0.800),
    )
    cell = size / repeats
    px = [0.0] * (size * size * 4)
    for y in range(size):
        cy = (y % cell) / cell
        for x in range(size):
            cx = (x % cell) / cell
            c = base
            if cx < 0.06 or cy < 0.06:
                c = dark
            if abs(cx - 0.46) < 0.038 or abs(cy - 0.46) < 0.038:
                c = blue
            if abs(cx - 0.72) < 0.016 or abs(cy - 0.72) < 0.016:
                c = white
            i = (y * size + x) * 4
            px[i], px[i + 1], px[i + 2], px[i + 3] = c[0], c[1], c[2], 1.0
    img.pixels.foreach_set(px)
    img.pack()
    return img


# --- Primitive helpers -------------------------------------------------------
PARTS = []  # (object, weight_spec)


def _finish(obj, material, weights, scale=(1, 1, 1), rot=(0, 0, 0), smooth=True):
    obj.scale = scale
    obj.rotation_euler = rot
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.data.materials.append(material)
    if smooth:
        for p in obj.data.polygons:
            p.use_smooth = True
    PARTS.append((obj, weights))
    return obj


def sphere(name, loc, r, material, weights, scale=(1, 1, 1), segs=20, rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=segs, ring_count=rings, radius=r, location=loc
    )
    o = bpy.context.object
    o.name = name
    return _finish(o, material, weights, scale)


def cyl(
    name, loc, r, depth, material, weights, scale=(1, 1, 1), rot=(0, 0, 0), verts=20
):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=verts, radius=r, depth=depth, location=loc
    )
    o = bpy.context.object
    o.name = name
    return _finish(o, material, weights, scale, rot)


def cone(
    name,
    loc,
    r1,
    r2,
    depth,
    material,
    weights,
    scale=(1, 1, 1),
    rot=(0, 0, 0),
    verts=24,
):
    bpy.ops.mesh.primitive_cone_add(
        vertices=verts, radius1=r1, radius2=r2, depth=depth, location=loc
    )
    o = bpy.context.object
    o.name = name
    return _finish(o, material, weights, scale, rot)


def box(name, loc, size, material, weights, rot=(0, 0, 0), smooth=False):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    o = bpy.context.object
    o.name = name
    return _finish(o, material, weights, size, rot, smooth)


def limb(name, p0, p1, r1, r2, material, weights, segs=16):
    """Capsule-ish tapered cylinder between two points, plus a sphere at the joint."""
    a, b = Vector(p0), Vector(p1)
    d = b - a
    bpy.ops.mesh.primitive_cone_add(
        vertices=segs, radius1=r1, radius2=r2, depth=d.length, location=(a + b) / 2.0
    )
    o = bpy.context.object
    o.name = name
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = Z.rotation_difference(d.normalized())
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    o.data.materials.append(material)
    for p in o.data.polygons:
        p.use_smooth = True
    PARTS.append((o, weights))
    return o


# --- Weight specs ------------------------------------------------------------
# A string = rigid bind to that bone. A callable = per-vertex weights, used for
# the two single-island garments that actually have to bend (shirt and sarung).
def clamp01(v):
    return 0.0 if v < 0.0 else (1.0 if v > 1.0 else v)


def smoothstep(a, b, v):
    t = clamp01((v - a) / (b - a))
    return t * t * (3.0 - 2.0 * t)


def shirt_weights(co):
    z = co[2]
    # Overlapping ramps rather than hard z cuts, so the shirt shears smoothly
    # across the spine instead of creasing at a single ring of vertices.
    chest = smoothstep(0.88, 1.00, z)
    hips = 1.0 - smoothstep(0.72, 0.88, z)
    spine = max(0.0, 1.0 - chest - hips)
    return {"Chest": chest, "Spine": spine, "Hips": hips}


# A sarung is a closed tube, not two trouser legs: it sways with the stride but
# never splits. Leg influence is therefore capped well below 1.0, otherwise a
# full-amplitude counter-swing rips the tube apart at the centre line.
SARONG_LEG_MAX = 0.46


def sarong_weights(co):
    x, z = co[0], co[2]
    sway = SARONG_LEG_MAX * (1.0 - smoothstep(0.22, 0.64, z))  # 0 at the waist
    # Smooth left/right blend instead of a hard x>=0 test, which would put a
    # weight discontinuity straight down the front of the cloth.
    fx = clamp01(0.5 + x / 0.34)
    return {
        "Hips": 1.0 - sway,
        "UpperLeg_L": sway * fx,
        "UpperLeg_R": sway * (1.0 - fx),
    }


def apply_weights(obj, spec):
    if isinstance(spec, str):
        g = obj.vertex_groups.new(name=spec)
        g.add(range(len(obj.data.vertices)), 1.0, "REPLACE")
        return
    groups = {}
    for v in obj.data.vertices:
        for bone, w in spec(v.co).items():
            if w <= 0.0:
                continue
            if bone not in groups:
                groups[bone] = obj.vertex_groups.new(name=bone)
            groups[bone].add([v.index], w, "REPLACE")


# --- Character ---------------------------------------------------------------
def build_mesh():
    plaid = make_plaid()
    SKIN = mat("Skin", (0.80, 0.34, 0.11), 0.70)
    SHIRT = mat("ShirtWhite", (0.88, 0.89, 0.92), 0.70)
    SHIRT_LINE = mat("ShirtSeam", (0.70, 0.71, 0.75), 0.70)
    BLACK = mat("Black", (0.012, 0.012, 0.016), 0.55)
    SARONG = mat("Sarong", (0.20, 0.45, 0.13), 0.80, image=plaid)
    EYE_W = mat("EyeWhite", (0.90, 0.90, 0.90), 0.35)
    EYE_IRIS = mat("EyeIris", (0.10, 0.045, 0.018), 0.30)
    MOUTH = mat("Mouth", (0.28, 0.07, 0.06), 0.55)
    BLUE = mat("SandalBlue", (0.025, 0.110, 0.480), 0.50)
    TAN = mat("SandalSole", (0.52, 0.19, 0.045), 0.65)

    # Head ---------------------------------------------------------------
    sphere(
        "Head",
        (0, 0, Z_HEAD),
        0.145,
        SKIN,
        "Head",
        scale=(1.0, 0.97, 1.04),
        segs=24,
        rings=16,
    )
    sphere(
        "Ear_L",
        (0.142, 0.005, Z_HEAD - 0.005),
        0.040,
        SKIN,
        "Head",
        scale=(0.45, 0.85, 1.15),
    )
    sphere(
        "Ear_R",
        (-0.142, 0.005, Z_HEAD - 0.005),
        0.040,
        SKIN,
        "Head",
        scale=(0.45, 0.85, 1.15),
    )
    sphere(
        "Nose",
        (0, -0.132, Z_HEAD - 0.015),
        0.033,
        SKIN,
        "Head",
        scale=(0.95, 0.9, 0.75),
    )
    cyl(
        "Neck",
        (0, 0, Z_NECK - 0.045),
        0.058,
        0.11,
        SKIN,
        "Neck",
        scale=(1.0, 0.92, 1.0),
    )

    for sx, tag in ((1, "L"), (-1, "R")):
        ex = 0.062 * sx
        sphere(
            "EyeWhite_" + tag,
            (ex, -0.110, Z_HEAD + 0.030),
            0.052,
            EYE_W,
            "Head",
            scale=(1.0, 0.55, 0.86),
        )
        sphere(
            "EyeIris_" + tag,
            (ex, -0.136, Z_HEAD + 0.026),
            0.034,
            EYE_IRIS,
            "Head",
            scale=(1.0, 0.42, 1.0),
        )
        sphere(
            "Pupil_" + tag,
            (ex, -0.149, Z_HEAD + 0.026),
            0.017,
            BLACK,
            "Head",
            scale=(1.0, 0.40, 1.0),
        )
        box(
            "Brow_" + tag,
            (ex + 0.004 * sx, -0.126, Z_HEAD + 0.092),
            (0.092, 0.030, 0.023),
            BLACK,
            "Head",
            rot=(0, math.radians(-8 * sx), 0),
        )
    box("Mouth", (0, -0.126, Z_HEAD - 0.082), (0.062, 0.028, 0.013), MOUTH, "Head")

    # Peci (songkok) ------------------------------------------------------
    cyl(
        "HairFringe",
        (0, 0, 1.330),
        0.150,
        0.055,
        BLACK,
        "Head",
        scale=(1.0, 0.98, 1.0),
        verts=24,
    )
    # A songkok is a slightly *flared* truncated cone with an almost flat top,
    # not a dome: wider at the crown than at the brow.
    cone(
        "Peci",
        (0, 0, Z_PECI_TOP - 0.070),
        0.150,
        0.159,
        0.140,
        BLACK,
        "Head",
        scale=(1.0, 0.97, 1.0),
        verts=32,
    )
    sphere(
        "PeciTop",
        (0, 0, Z_PECI_TOP - 0.018),
        0.159,
        BLACK,
        "Head",
        scale=(1.0, 0.97, 0.26),
        segs=32,
    )

    # Baju koko -----------------------------------------------------------
    # The hem hangs *over* the sarung in player.png, so the shirt runs lower
    # than the waist line rather than stopping at it.
    # The hem has to stay clearly narrower than the sarung it overlaps; at equal
    # radii the two surfaces interpenetrate and the shirt pokes through.
    cone(
        "Shirt",
        (0, 0, (Z_SHIRT_HEM + 1.10) / 2.0),
        0.184,
        0.176,
        1.10 - Z_SHIRT_HEM,
        SHIRT,
        shirt_weights,
        scale=(1.0, 0.76, 1.0),
        verts=28,
    )
    cyl(
        "Collar",
        (0, 0, Z_NECK + 0.028),
        0.086,
        0.062,
        SHIRT,
        "Neck",
        scale=(1.0, 0.92, 1.0),
    )
    # Stops at the shirt hem; running it lower pokes the seam through the sarung.
    box(
        "Placket",
        (0, -0.132, (Z_SHIRT_HEM + 1.10) / 2.0 + 0.02),
        (0.015, 0.030, 1.10 - Z_SHIRT_HEM - 0.06),
        SHIRT_LINE,
        shirt_weights,
    )

    # Arms (T-pose) -------------------------------------------------------
    for sx, tag in ((1, "L"), (-1, "R")):
        sphere(
            "Shoulder_" + tag,
            (X_SHOULDER * sx, 0, Z_SHOULDER),
            0.075,
            SHIRT,
            "Chest",
            scale=(1.0, 0.92, 1.0),
        )
        limb(
            "UpperArm_" + tag,
            (X_SHOULDER * sx, 0, Z_SHOULDER),
            (X_ELBOW * sx, 0, Z_SHOULDER),
            0.070,
            0.058,
            SHIRT,
            "UpperArm_" + tag,
        )
        sphere(
            "Elbow_" + tag,
            (X_ELBOW * sx, 0, Z_SHOULDER),
            0.058,
            SHIRT,
            "LowerArm_" + tag,
        )
        # Baju koko is long-sleeved: white runs all the way to the wrist and
        # only the hand is skin.
        limb(
            "LowerArm_" + tag,
            (X_ELBOW * sx, 0, Z_SHOULDER),
            (X_WRIST * sx, 0, Z_SHOULDER),
            0.057,
            0.046,
            SHIRT,
            "LowerArm_" + tag,
        )
        cyl(
            "Cuff_" + tag,
            ((X_WRIST - 0.012) * sx, 0, Z_SHOULDER),
            0.049,
            0.030,
            SHIRT,
            "LowerArm_" + tag,
            rot=(0, math.radians(90), 0),
        )
        limb(
            "Hand_" + tag,
            (X_WRIST * sx, 0, Z_SHOULDER),
            (X_FINGER * sx, 0, Z_SHOULDER - 0.012),
            0.046,
            0.026,
            SKIN,
            "Hand_" + tag,
        )

    # Sarung --------------------------------------------------------------
    # player.png wraps a near-straight tube, not an A-line skirt: the hem is
    # barely wider than the waist. Keep it just clear of a swinging thigh
    # (x=±0.105, r=0.088) and hem it above the ankle so the sandals read.
    cone(
        "Sarong",
        (0, 0, (Z_SARONG_HEM + Z_SARONG_TOP) / 2.0),
        0.224,
        0.208,
        Z_SARONG_TOP - Z_SARONG_HEM,
        SARONG,
        sarong_weights,
        # Round rather than flattened: Y is the stride axis, so squashing it is
        # exactly what let a swinging thigh punch through the front of the cloth.
        scale=(1.0, 1.0, 1.0),
        verts=32,
    )

    # Legs + sandals ------------------------------------------------------
    for sx, tag in ((1, "L"), (-1, "R")):
        limb(
            "Thigh_" + tag,
            (X_LEG * sx, 0, Z_HIP),
            (X_LEG * sx, 0, Z_KNEE),
            0.078,
            0.064,
            SKIN,
            "UpperLeg_" + tag,
        )
        sphere("Knee_" + tag, (X_LEG * sx, 0, Z_KNEE), 0.063, SKIN, "LowerLeg_" + tag)
        limb(
            "Shin_" + tag,
            (X_LEG * sx, 0, Z_KNEE),
            (X_LEG * sx, 0, Z_ANKLE),
            0.062,
            0.048,
            SKIN,
            "LowerLeg_" + tag,
        )
        box(
            "Foot_" + tag,
            (X_LEG * sx, -0.045, Z_ANKLE - 0.030),
            (0.092, 0.195, 0.062),
            SKIN,
            "Foot_" + tag,
        )
        box(
            "SandalSole_" + tag,
            (X_LEG * sx, -0.050, 0.016),
            (0.122, 0.265, 0.032),
            BLUE,
            "Foot_" + tag,
        )
        box(
            "SandalBed_" + tag,
            (X_LEG * sx, -0.050, 0.034),
            (0.104, 0.245, 0.012),
            TAN,
            "Foot_" + tag,
        )
        for stx in (1, -1):
            box(
                f"Strap_{tag}{stx}",
                (X_LEG * sx + 0.030 * stx, -0.108, 0.062),
                (0.022, 0.100, 0.052),
                BLUE,
                "Foot_" + tag,
                rot=(math.radians(28), 0, math.radians(26 * stx)),
            )
        cyl(
            "Toepost_" + tag,
            (X_LEG * sx, -0.150, 0.052),
            0.012,
            0.045,
            BLUE,
            "Foot_" + tag,
        )

    # Bake weights, then fuse into one skinned mesh.
    for obj, spec in PARTS:
        apply_weights(obj, spec)

    bpy.ops.object.select_all(action="DESELECT")
    for obj, _ in PARTS:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = PARTS[0][0]
    bpy.ops.object.join()
    body = bpy.context.object
    body.name = "PlayerBody"
    try:
        bpy.ops.object.shade_auto_smooth(angle=math.radians(38))
    except Exception:
        bpy.ops.object.shade_smooth()
    return body


# --- Armature ----------------------------------------------------------------
BONES = [
    # name, head, tail, parent
    ("Hips", (0, 0, Z_HIP), (0, 0, 0.90), None),
    ("Spine", (0, 0, 0.90), (0, 0, Z_CHEST), "Hips"),
    ("Chest", (0, 0, Z_CHEST), (0, 0, Z_NECK), "Spine"),
    ("Neck", (0, 0, Z_NECK), (0, 0, 1.16), "Chest"),
    ("Head", (0, 0, 1.16), (0, 0, Z_HEAD_TOP + 0.04), "Neck"),
]
for _sx, _t in ((1, "L"), (-1, "R")):
    BONES += [
        (
            "UpperArm_" + _t,
            (X_SHOULDER * _sx, 0, Z_SHOULDER),
            (X_ELBOW * _sx, 0, Z_SHOULDER),
            "Chest",
        ),
        (
            "LowerArm_" + _t,
            (X_ELBOW * _sx, 0, Z_SHOULDER),
            (X_WRIST * _sx, 0, Z_SHOULDER),
            "UpperArm_" + _t,
        ),
        (
            "Hand_" + _t,
            (X_WRIST * _sx, 0, Z_SHOULDER),
            (X_FINGER * _sx, 0, Z_SHOULDER),
            "LowerArm_" + _t,
        ),
        ("UpperLeg_" + _t, (X_LEG * _sx, 0, Z_HIP), (X_LEG * _sx, 0, Z_KNEE), "Hips"),
        (
            "LowerLeg_" + _t,
            (X_LEG * _sx, 0, Z_KNEE),
            (X_LEG * _sx, 0, Z_ANKLE),
            "UpperLeg_" + _t,
        ),
        (
            "Foot_" + _t,
            (X_LEG * _sx, 0, Z_ANKLE),
            (X_LEG * _sx, -0.16, 0.012),
            "LowerLeg_" + _t,
        ),
    ]
PARENT = {b[0]: b[3] for b in BONES}


def build_armature():
    bpy.ops.object.armature_add(location=(0, 0, 0))
    arm = bpy.context.object
    arm.name = "PlayerRig"
    arm.data.name = "PlayerRig"
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones
    for b in list(eb):
        eb.remove(b)
    for name, head, tail, _ in BONES:
        b = eb.new(name)
        b.head, b.tail, b.roll = Vector(head), Vector(tail), 0.0
    for name, _, _, parent in BONES:
        if parent:
            eb[name].parent = eb[parent]
            eb[name].use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    return arm


# --- Posing ------------------------------------------------------------------
# Poses are written as absolute world-space deltas from rest, so no bone-roll or
# local-axis guessing is needed. basis = M^-1 . (Dparent^-1 . Dbone) . M
def qx(a):
    return Quaternion(X, a)


def qy(a):
    return Quaternion(Y, a)


def qz(a):
    return Quaternion(Z, a)


IDENT = Quaternion()


def apply_pose(arm, D, hips_offset=Vector((0, 0, 0))):
    for name in PARENT:
        pb = arm.pose.bones[name]
        d = D.get(name, IDENT)
        dp = D.get(PARENT[name], IDENT) if PARENT[name] else IDENT
        M = pb.bone.matrix_local.to_3x3().to_quaternion()
        pb.rotation_quaternion = M.inverted() @ (dp.inverted() @ d) @ M
    hb = arm.pose.bones["Hips"]
    hb.location = hb.bone.matrix_local.to_3x3().inverted() @ hips_offset


def key(arm, frame):
    for pb in arm.pose.bones:
        pb.keyframe_insert("rotation_quaternion", frame=frame)
    arm.pose.bones["Hips"].keyframe_insert("location", frame=frame)


def arm_pose(D, swing_l, swing_r, elbow_l, elbow_r):
    D["UpperArm_L"] = qx(swing_l) @ qy(math.pi / 2)
    D["UpperArm_R"] = qx(swing_r) @ qy(-math.pi / 2)
    D["LowerArm_L"] = qx(swing_l + elbow_l) @ qy(math.pi / 2)
    D["LowerArm_R"] = qx(swing_r + elbow_r) @ qy(-math.pi / 2)
    D["Hand_L"] = D["LowerArm_L"]
    D["Hand_R"] = D["LowerArm_R"]


def pose_run(p):
    """p in [0,1). +X rotation = backwards for a down-pointing bone, forwards for an
    up-pointing one, so legs/arms use the opposite sign convention to the spine."""
    s, c = math.sin(TAU * p), math.cos(TAU * p)
    D = {
        "Hips": qz(0.10 * s) @ qx(0.03),
        "Spine": qx(0.09),
        "Chest": qx(0.05) @ qz(-0.07 * s),
        "Neck": qx(-0.05),
        "Head": qx(-0.09),
    }
    # Stride is deliberately short: a sarung is a closed tube, so a full sprint
    # swing would push the thigh straight through the cloth.
    thigh_l, thigh_r = -0.46 * s, 0.46 * s
    flex_l = 0.22 + 1.05 * max(0.0, c)
    flex_r = 0.22 + 1.05 * max(0.0, -c)
    D["UpperLeg_L"], D["UpperLeg_R"] = qx(thigh_l), qx(thigh_r)
    D["LowerLeg_L"], D["LowerLeg_R"] = qx(thigh_l + flex_l), qx(thigh_r + flex_r)
    D["Foot_L"] = qx(0.45 * max(0.0, -s) - 0.18 * max(0.0, s))
    D["Foot_R"] = qx(0.45 * max(0.0, s) - 0.18 * max(0.0, -s))
    arm_pose(
        D, 0.85 * s, -0.85 * s, -1.25 - 0.35 * max(0.0, -s), -1.25 - 0.35 * max(0.0, s)
    )
    bob = Vector((0, 0, abs(s) * 0.055 - 0.025))
    return D, bob


def pose_idle(p):
    b = math.sin(TAU * p)
    D = {
        "Hips": qx(0.02),
        "Spine": qx(0.04 + 0.015 * b),
        "Chest": qx(0.03),
        "Neck": qx(-0.03),
        "Head": qx(-0.05 + 0.02 * b),
        "UpperLeg_L": qx(-0.04),
        "UpperLeg_R": qx(0.04),
        "LowerLeg_L": qx(0.10),
        "LowerLeg_R": qx(0.10),
        "Foot_L": qx(0.0),
        "Foot_R": qx(0.0),
    }
    arm_pose(D, 0.0, 0.0, -0.22, -0.22)
    D["UpperArm_L"] = qx(0.03 * b) @ qz(-0.10) @ qy(math.pi / 2)
    D["UpperArm_R"] = qx(0.03 * b) @ qz(0.10) @ qy(-math.pi / 2)
    D["LowerArm_L"] = qx(0.03 * b - 0.25) @ qz(-0.10) @ qy(math.pi / 2)
    D["LowerArm_R"] = qx(0.03 * b - 0.25) @ qz(0.10) @ qy(-math.pi / 2)
    D["Hand_L"], D["Hand_R"] = D["LowerArm_L"], D["LowerArm_R"]
    return D, Vector((0, 0, 0.012 * b))


def pose_jump(t):
    """t: 0 = crouch launch, 0.5 = apex tuck, 1 = reach for landing."""
    tuck = math.sin(math.pi * min(1.0, t * 1.15))
    D = {
        "Hips": qx(0.10 * tuck),
        "Spine": qx(0.22 - 0.10 * t),
        "Chest": qx(0.10),
        "Neck": qx(-0.12),
        "Head": qx(-0.22),
    }
    # Shallow tuck: the sarung is a closed tube, so a deep knees-to-chest pose
    # drives the thighs straight out through the front of the cloth.
    thigh = -0.30 - 0.34 * tuck
    knee = 0.45 + 0.85 * tuck
    D["UpperLeg_L"] = qx(thigh - 0.08)
    D["UpperLeg_R"] = qx(thigh + 0.08)
    D["LowerLeg_L"] = qx(thigh - 0.08 + knee)
    D["LowerLeg_R"] = qx(thigh + 0.08 + knee + 0.20)
    D["Foot_L"] = qx(0.45 * tuck)
    D["Foot_R"] = qx(0.45 * tuck)
    arm_pose(D, -1.55 - 0.55 * tuck, -1.55 - 0.55 * tuck, -0.55, -0.55)
    return D, Vector((0, 0, -0.04 * tuck))


def pose_slide(t):
    """t: 0 = still upright, 1 = fully tucked under the obstacle."""
    k = min(1.0, t)
    D = {
        "Hips": qx(-0.22 * k),
        "Spine": qx(0.58 * k),
        "Chest": qx(0.26 * k),
        "Neck": qx(-0.36 * k),
        "Head": qx(-0.46 * k),
    }
    D["UpperLeg_L"] = qx(-1.05 * k)
    D["UpperLeg_R"] = qx(-0.28 * k)
    D["LowerLeg_L"] = qx(-1.05 * k + 0.18 * k)
    D["LowerLeg_R"] = qx(-0.28 * k + 1.70 * k)
    D["Foot_L"] = qx(-0.35 * k)
    D["Foot_R"] = qx(0.55 * k)
    arm_pose(D, 0.95 * k, 0.95 * k, -0.45 * k, -0.45 * k)
    return D, Vector((0, 0, -0.46 * k))


def action_fcurves(action):
    """Blender 4.4+ moved fcurves under layers/strips/channelbags; 4.3 and older
    keep them flat on the action."""
    if hasattr(action, "fcurves"):
        return list(action.fcurves)
    out = []
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                out.extend(bag.fcurves)
    return out


def bake(arm, name, sampler, frames, step=2):
    arm.animation_data_create()
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    arm.animation_data.action = action
    # Blender 4.4+ slotted actions: assigning an action normally auto-picks a slot,
    # but a freshly created empty action has none to pick.
    if (
        hasattr(arm.animation_data, "action_slot")
        and arm.animation_data.action_slot is None
    ):
        arm.animation_data.action_slot = (
            action.slots[0]
            if len(action.slots)
            else action.slots.new(id_type="OBJECT", name=name)
        )
    for f in range(1, frames + 1, step):
        D, off = sampler((f - 1) / float(frames - 1))
        apply_pose(arm, D, off)
        key(arm, f)
    if (frames - 1) % step:
        D, off = sampler(1.0)
        apply_pose(arm, D, off)
        key(arm, frames)
    for fc in action_fcurves(action):
        for kp in fc.keyframe_points:
            kp.interpolation = "BEZIER"
    arm.animation_data.action = None
    return action


def loop_sampler(fn, frames):
    """Phase 0..1 exclusive of the endpoint so the cycle closes seamlessly."""
    return lambda t: fn(t * (frames - 1) / float(frames))


# --- Preview render ----------------------------------------------------------
# Contact sheet of rest + one frame per clip, so a bad bind or a broken pose is
# visible without opening Blender.
# Action poses are judged from the side; a front view foreshortens every
# forward-swinging limb into a blob and tells you nothing about the cycle.
SHOTS = [
    ("rest", None, 0.0, "front"),
    ("rest_side", None, 0.0, "side"),
    ("run", pose_run, 0.12, "side"),
    ("run_b", pose_run, 0.38, "side"),
    ("jump", pose_jump, 0.5, "side"),
    ("slide", pose_slide, 1.0, "side"),
]


def render_preview(arm):
    scene = bpy.context.scene
    for engine in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "BLENDER_WORKBENCH"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            continue
    # The NLA tracks that carry the clips would otherwise evaluate over any pose
    # set here and render whatever the last strip happens to hold.
    for tr in arm.animation_data.nla_tracks:
        tr.mute = True
    bpy.ops.object.camera_add(location=(0, -4.2, 0.78), rotation=(math.pi / 2, 0, 0))
    cam = bpy.context.object
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 1.85
    scene.camera = cam
    bpy.ops.object.light_add(type="SUN", location=(2, -3, 4))
    bpy.context.object.data.energy = 4.0
    bpy.context.object.rotation_euler = (math.radians(50), 0, math.radians(35))
    bpy.ops.object.light_add(type="SUN", location=(-3, -2, 2))
    bpy.context.object.data.energy = 1.5
    bpy.context.object.rotation_euler = (math.radians(70), 0, math.radians(-120))
    scene.render.resolution_x, scene.render.resolution_y = 460, 620
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new("W")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (
        0.82,
        0.84,
        0.86,
        1,
    )
    for tag, fn, t, view in SHOTS:
        if fn is None:
            apply_pose(arm, {})
        else:
            D, off = fn(t)
            apply_pose(arm, D, off)
        if view == "side":
            # Wider and lower than the front shot: the slide pose drops the hips
            # and throws a leg well outside the standing silhouette.
            cam.location = (4.2, 0, 0.72)
            cam.rotation_euler = (math.pi / 2, 0, math.pi / 2)
            cam.data.ortho_scale = 2.4
        else:
            cam.location = (0, -4.2, 0.78)
            cam.rotation_euler = (math.pi / 2, 0, 0)
            cam.data.ortho_scale = 1.85
        scene.render.filepath = OUT_PREVIEW.replace(".png", f"_{tag}.png")
        bpy.ops.render.render(write_still=True)
    for tr in arm.animation_data.nla_tracks:
        tr.mute = False


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    body = build_mesh()
    arm = build_armature()

    body.parent = arm
    m = body.modifiers.new("Armature", "ARMATURE")
    m.object = arm

    # The body is modelled facing -Y, which glTF's Y-up conversion turns into
    # +Z; Godot's forward is -Z, so without this the character runs backwards,
    # facing the chase camera. Rotating the rig object (not the bones) keeps
    # every baked pose delta valid.
    arm.rotation_euler = (0.0, 0.0, math.pi)

    bpy.context.view_layer.objects.active = arm
    actions = [
        bake(arm, "Idle", loop_sampler(pose_idle, 48), 48, step=4),
        bake(arm, "Run", loop_sampler(pose_run, 24), 24, step=2),
        bake(arm, "Jump", pose_jump, 16, step=2),
        bake(arm, "Slide", pose_slide, 10, step=2),
    ]
    # One NLA track per action: the only arrangement every recent glTF exporter
    # agrees on for emitting separately-named animation clips.
    for a in actions:
        track = arm.animation_data.nla_tracks.new()
        track.name = a.name
        strip = track.strips.new(a.name, 1, a)
        strip.name = a.name

    os.makedirs(os.path.dirname(OUT_GLB), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=OUT_GLB,
        export_format="GLB",
        export_apply=True,
        export_animations=True,
        export_animation_mode="NLA_TRACKS",
        export_bake_animation=True,
        export_optimize_animation_size=False,
        export_yup=True,
    )
    render_preview(arm)
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    names = [a.name for a in actions]
    print(f"OK verts={len(body.data.vertices)} actions={names} -> {OUT_GLB}")


main()
