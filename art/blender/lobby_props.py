"""
World 1 (Gray Plaza) lobby props for the Donation MMO, modeled procedurally so they can
be regenerated and tweaked from code.

Run headless:
    /Applications/Blender.app/Contents/MacOS/Blender --background --python art/blender/lobby_props.py -- [--render]

Outputs art/blender/out/lobby_props.glb (and a preview PNG with --render).

Layout contract with src/server/Dev/LobbyAssetImporter.luau:
  - every asset is an Empty named after the asset (e.g. "Fountain") placed at
    (index * GRID, 0, 0) in ASSET_ORDER, with child meshes named "<Asset>_<Role>"
  - the Empty's origin is the asset's pivot: ground contact point / footprint center
  - "front" of directional assets (booth, bench) faces Blender -Y, which the Studio
    importer maps to Roblox -Z (a CFrame's LookVector)
  - roles (Stone, Water, Wood, Canvas, ...) are given Roblox materials/colors by the
    importer script, so meshes carry geometry only
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

GRID = 45.0
ASSET_ORDER = [
    "PalmA",
    "PalmB",
    "RockA",
    "RockB",
    "RockC",
    "Fountain",
    "Lighthouse",
    "Rowboat",
    "Shipwreck",
    "BoothShell",
    "LampPost",
    "Bench",
    "Chest",
]

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(HERE, "out")
TAU = math.tau

# Flat preview colors per role (only used for the preview render; Roblox gets its look
# from the importer's material table).
PREVIEW = {
    "Trunk": (0.36, 0.27, 0.18),
    "Fronds": (0.22, 0.38, 0.16),
    "Nuts": (0.30, 0.20, 0.10),
    "Rock": (0.42, 0.40, 0.37),
    "Stone": (0.70, 0.69, 0.66),
    "Trim": (0.48, 0.47, 0.45),
    "Water": (0.25, 0.55, 0.65),
    "White": (0.90, 0.89, 0.86),
    "Red": (0.60, 0.22, 0.19),
    "Metal": (0.12, 0.12, 0.13),
    "Glass": (0.95, 0.85, 0.55),
    "Glow": (1.0, 0.75, 0.4),
    "Hull": (0.45, 0.33, 0.22),
    "Wood": (0.40, 0.29, 0.19),
    "WoodDark": (0.26, 0.19, 0.13),
    "Canvas": (0.88, 0.86, 0.82),
    "Stripe": (0.48, 0.50, 0.55),
    "Iron": (0.14, 0.14, 0.15),
}


# ----------------------------------------------------------------------------------------
# Scene + mesh helpers


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def make_root(name, index):
    root = bpy.data.objects.new(name, None)
    root.empty_display_type = "PLAIN_AXES"
    root.location = (index * GRID, 0, 0)
    bpy.context.collection.objects.link(root)
    return root


def finish(bm, asset, role, root, smooth_angle=None, uv_scale=4.0):
    """Turn a bmesh into a child mesh object '<asset>_<role>' with sane UVs."""
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(f"{asset}_{role}")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(f"{asset}_{role}", mesh)
    bpy.context.collection.objects.link(obj)
    obj.parent = root

    mat = bpy.data.materials.get(role) or bpy.data.materials.new(role)
    mat.diffuse_color = (*PREVIEW.get(role, (0.6, 0.6, 0.6)), 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*PREVIEW.get(role, (0.6, 0.6, 0.6)), 1.0)
        bsdf.inputs["Roughness"].default_value = 0.8
    mesh.materials.append(mat)

    bpy.context.view_layer.objects.active = obj
    for o in bpy.context.selected_objects:
        o.select_set(False)
    obj.select_set(True)

    # UVs scaled to world size so Roblox's tiling materials (Wood, Slate, Fabric...)
    # keep a consistent texel density instead of stretching one tile over a whole prop.
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.01, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    size = max(obj.dimensions) or 1.0
    uv = mesh.uv_layers.active
    if uv:
        factor = size / uv_scale
        for loop_uv in uv.data:
            loop_uv.uv = loop_uv.uv * factor

    if smooth_angle is not None:
        for poly in mesh.polygons:
            poly.use_smooth = True
        bpy.ops.object.shade_auto_smooth(angle=math.radians(smooth_angle))
    obj.select_set(False)
    return obj


def lathe(bm, profile, segments=32, center=(0, 0, 0), cap_bottom=False, cap_top=False, phase=0.0):
    """Revolve a list of (radius, z) points around Z. r == 0 points collapse to the axis."""
    cx, cy, cz = center
    rings = []
    for r, z in profile:
        if r <= 1e-6:
            rings.append([bm.verts.new((cx, cy, cz + z))])
        else:
            rings.append([
                bm.verts.new((cx + r * math.cos(TAU * k / segments + phase), cy + r * math.sin(TAU * k / segments + phase), cz + z))
                for k in range(segments)
            ])
    for a, b in zip(rings, rings[1:]):
        if len(a) == 1 and len(b) == 1:
            continue
        for k in range(segments):
            k2 = (k + 1) % segments
            if len(a) == 1:
                bm.faces.new((a[0], b[k], b[k2]))
            elif len(b) == 1:
                bm.faces.new((a[k], b[0], a[k2]))
            else:
                bm.faces.new((a[k], a[k2], b[k2], b[k]))
    if cap_bottom and len(rings[0]) > 2:
        bm.faces.new(list(reversed(rings[0])))
    if cap_top and len(rings[-1]) > 2:
        bm.faces.new(rings[-1])
    return rings


def box(bm, center, size, rotation=None):
    mat = Matrix.Translation(Vector(center))
    if rotation is not None:
        mat = mat @ rotation
    mat = mat @ Matrix.Diagonal((size[0], size[1], size[2], 1.0))
    bmesh.ops.create_cube(bm, size=1.0, matrix=mat)


def sphere(bm, center, radius, subdivisions=2):
    mat = Matrix.Translation(Vector(center))
    bmesh.ops.create_icosphere(bm, subdivisions=subdivisions, radius=radius, matrix=mat)


def tube_along(bm, points, radius, sides=8, taper=None):
    """A tube through a polyline (used for ribs, arms, oars)."""
    rings = []
    n = len(points)
    for i, p in enumerate(points):
        p = Vector(p)
        if i == 0:
            tangent = Vector(points[1]) - p
        elif i == n - 1:
            tangent = p - Vector(points[i - 1])
        else:
            tangent = Vector(points[i + 1]) - Vector(points[i - 1])
        tangent.normalize()
        helper = Vector((0, 0, 1)) if abs(tangent.z) < 0.9 else Vector((1, 0, 0))
        side = tangent.cross(helper).normalized()
        up = side.cross(tangent).normalized()
        r = radius * (taper(i / (n - 1)) if taper else 1.0)
        rings.append([bm.verts.new(p + (side * math.cos(TAU * k / sides) + up * math.sin(TAU * k / sides)) * r) for k in range(sides)])
    for a, b in zip(rings, rings[1:]):
        for k in range(sides):
            k2 = (k + 1) % sides
            bm.faces.new((a[k], a[k2], b[k2], b[k]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])


# ----------------------------------------------------------------------------------------
# Palms


def build_palm(name, index, height, lean, fronds, seed):
    root = make_root(name, index)

    def spine(t):
        # Curved trunk: leans along +X, bending more toward the top.
        return Vector((lean * t * t * height * 0.35, 0, height * t))

    bm = bmesh.new()
    steps = 22
    sides = 10
    rings = []
    for i in range(steps + 1):
        t = i / steps
        c = spine(t)
        base_r = 0.95 * (1 - 0.42 * t) + (0.35 if t < 0.06 else 0) * (1 - t / 0.06)
        # Ring bulges every segment give the stacked-frond-scar look of a palm trunk.
        bulge = 1 + 0.07 * (math.sin(t * steps * math.pi) ** 2)
        r = base_r * bulge
        rings.append([bm.verts.new(c + Vector((r * math.cos(TAU * k / sides), r * math.sin(TAU * k / sides), 0))) for k in range(sides)])
    for a, b in zip(rings, rings[1:]):
        for k in range(sides):
            k2 = (k + 1) % sides
            bm.faces.new((a[k], a[k2], b[k2], b[k]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    finish(bm, name, "Trunk", root, smooth_angle=60)

    crown = spine(1.0)

    # Fronds: drooping, serrated leaves with a raised midrib (V cross-section).
    bm = bmesh.new()
    for f in range(fronds):
        angle = TAU * f / fronds + seed * 0.37
        length = height * (0.42 + 0.08 * math.sin(f * 2.3 + seed))
        lift = 0.55 + 0.25 * math.sin(f * 1.7 + seed)
        direction = Vector((math.cos(angle), math.sin(angle), 0))
        side = Vector((-direction.y, direction.x, 0))
        samples = 14
        prev = None
        for s in range(samples + 1):
            u = s / samples
            # Rises a little, then arcs down past the crown.
            p = crown + direction * (length * u) + Vector((0, 0, length * (lift * u - 1.05 * u * u)))
            width = 1.5 * math.sin(math.pi * min(1.0, u * 1.08)) ** 0.7 + 0.05
            if s % 2 == 1:
                width *= 0.72  # serrated leaflet edge
            mid = p + Vector((0, 0, 0.18 * (1 - u)))
            left = p + side * width - Vector((0, 0, 0.25 * width))
            right = p - side * width - Vector((0, 0, 0.25 * width))
            row = (bm.verts.new(left), bm.verts.new(mid), bm.verts.new(right))
            if prev:
                bm.faces.new((prev[0], prev[1], row[1], row[0]))
                bm.faces.new((prev[1], prev[2], row[2], row[1]))
            prev = row
    finish(bm, name, "Fronds", root, smooth_angle=40)

    bm = bmesh.new()
    for k in range(4):
        a = TAU * k / 4 + seed
        sphere(bm, crown + Vector((math.cos(a) * 0.7, math.sin(a) * 0.7, -0.7)), 0.45, subdivisions=1)
    finish(bm, name, "Nuts", root, smooth_angle=80)


# ----------------------------------------------------------------------------------------
# Rocks


def build_rock(name, index, scale, seed):
    root = make_root(name, index)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=3, radius=4.0)
    offset = Vector((seed * 13.1, seed * 7.7, seed * 3.3))
    for v in bm.verts:
        n = v.co.normalized()
        # Three octaves: broad lumps, mid ridges, then sharp small facets.
        d = (
            noise.noise(v.co * 0.28 + offset) * 0.9
            + noise.noise(v.co * 0.8 + offset) * 0.45
            + abs(noise.noise(v.co * 1.9 + offset)) * 0.35
        )
        v.co = v.co * (1 + d * 0.3)
        v.co.x *= scale[0]
        v.co.y *= scale[1]
        v.co.z *= scale[2]
        # Flattened base so rocks sit on the ground instead of balancing on a point.
        if v.co.z < -1.0:
            v.co.z = -1.0 + (v.co.z + 1.0) * 0.15
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, 1.0))
    finish(bm, name, "Rock", root, smooth_angle=22)


# ----------------------------------------------------------------------------------------
# Fountain (base at z=0; the runtime spray emitter sits at z=14)


def build_fountain(index):
    name = "Fountain"
    root = make_root(name, index)
    seg = 48

    bm = bmesh.new()
    # Lower basin: solid revolve from the axis, outer wall with a rolled rim.
    lathe(bm, [
        (0.0, 0.0), (14.8, 0.0), (15.3, 0.35), (15.3, 1.9), (15.0, 2.2),
        (13.8, 2.2), (13.6, 1.9), (13.4, 0.9), (3.2, 0.9), (3.0, 1.0),
    ], segments=seg)
    # Column with moldings.
    lathe(bm, [
        (3.0, 1.0), (2.8, 1.5), (2.2, 1.8), (1.75, 2.3), (1.6, 3.5), (1.5, 6.4),
        (1.9, 6.8), (2.1, 7.3), (1.4, 7.6),
    ], segments=seg)
    # Upper bowl.
    lathe(bm, [
        (1.4, 7.6), (3.5, 7.75), (5.3, 8.25), (5.8, 8.75), (5.75, 9.05), (5.2, 9.05),
        (5.0, 8.9), (1.6, 8.6), (1.0, 8.6),
    ], segments=seg)
    # Spire and finial.
    lathe(bm, [
        (1.0, 8.6), (0.95, 9.4), (0.75, 11.6), (1.2, 11.9), (1.25, 12.25), (0.6, 12.5), (0.5, 12.6), (0.0, 12.6),
    ], segments=seg)
    sphere(bm, (0, 0, 13.4), 0.9, subdivisions=2)
    finish(bm, name, "Stone", root, smooth_angle=50)

    bm = bmesh.new()
    # Rim cap and a low plinth ring in a darker stone.
    lathe(bm, [(15.45, 1.85), (15.6, 2.05), (15.5, 2.35), (13.7, 2.35), (13.6, 2.15)], segments=seg)
    lathe(bm, [(17.2, 0.0), (17.2, 0.45), (16.6, 0.6), (15.0, 0.6)], segments=seg)
    for k in range(8):
        a = TAU * (k + 0.5) / 8
        box(bm, (math.cos(a) * 15.5, math.sin(a) * 15.5, 1.15), (1.0, 1.0, 2.3), Matrix.Rotation(a, 4, "Z"))
    finish(bm, name, "Trim", root, smooth_angle=40)

    bm = bmesh.new()
    lathe(bm, [(0.0, 2.05), (13.55, 2.05)], segments=seg)
    lathe(bm, [(0.0, 8.85), (5.05, 8.85)], segments=seg)
    finish(bm, name, "Water", root, smooth_angle=80)


# ----------------------------------------------------------------------------------------
# Lighthouse (base at z=0, tower top at z=46; the gallery floor/rails/ladder are built by
# IslandBuilder so collision stays simple and predictable)


def build_lighthouse(index):
    name = "Lighthouse"
    root = make_root(name, index)
    seg = 40
    height = 46.0

    def radius(z):
        return 7.0 - 2.5 * (z / height)

    bands = 6
    white, red = bmesh.new(), bmesh.new()
    for b in range(bands):
        z0, z1 = b * height / bands, (b + 1) * height / bands
        target = white if b % 2 == 0 else red
        prof = [(radius(z0), z0), (radius(z1), z1)]
        lathe(target, prof, segments=seg, cap_bottom=(b == 0), cap_top=(b == bands - 1))
    finish(white, name, "White", root, smooth_angle=50)
    finish(red, name, "Red", root, smooth_angle=50)

    bm = bmesh.new()
    # Plinth.
    lathe(bm, [(0.0, -1.0), (9.0, -1.0), (9.0, 0.4), (8.4, 1.0), (7.2, 1.1), (0.0, 1.1)], segments=8, phase=math.pi / 8)
    finish(bm, name, "Stone", root, smooth_angle=20)

    bm = bmesh.new()
    # Door facing -Y, and small dark windows spiralling up the tower.
    box(bm, (0, -radius(2.0) - 0.1, 2.6), (2.6, 0.6, 4.2))
    for i, z in enumerate((12.0, 21.0, 30.0, 38.0)):
        a = -math.pi / 2 + i * 1.9
        r = radius(z) + 0.05
        box(bm, (math.cos(a) * r, math.sin(a) * r, z), (1.2, 0.5, 2.0), Matrix.Rotation(a + math.pi / 2, 4, "Z"))
    # Lantern-room base ring, mullions, and the roof.
    lathe(bm, [(0.0, 46.0), (4.3, 46.0), (4.3, 47.0), (0.0, 47.0)], segments=seg)
    for k in range(8):
        a = TAU * k / 8
        box(bm, (math.cos(a) * 3.55, math.sin(a) * 3.55, 49.6), (0.3, 0.3, 5.3), Matrix.Rotation(a, 4, "Z"))
    lathe(bm, [(0.0, 52.1), (4.6, 52.1), (4.4, 52.7), (3.0, 54.0), (1.3, 55.3), (0.5, 56.4), (0.0, 56.9)], segments=seg)
    sphere(bm, (0, 0, 57.4), 0.55, subdivisions=2)
    finish(bm, name, "Metal", root, smooth_angle=45)

    bm = bmesh.new()
    lathe(bm, [(3.5, 47.0), (3.5, 52.1)], segments=seg)
    finish(bm, name, "Glass", root, smooth_angle=60)

    bm = bmesh.new()
    sphere(bm, (0, 0, 49.4), 1.3, subdivisions=2)
    finish(bm, name, "Glow", root, smooth_angle=80)


# ----------------------------------------------------------------------------------------
# Boats


def hull_shell(bm, length, beam, depth, keel_z, transom=0.35, stations=24, around=12, open_frac=1.0):
    """A boat hull surface: long along Y, bow at +Y. Returns nothing (writes into bm)."""
    rows = []
    for i in range(stations + 1):
        t = i / stations  # 0 = stern, 1 = bow
        y = -length / 2 + length * t
        # Full width amidships, pinched to a point at the bow, a cut transom at the stern.
        w = beam / 2 * (max(0.0, math.sin(math.pi * (transom + (1 - transom) * t))) ** 0.75)
        if t > 0.98:
            w = 0.02
        sheer = depth + 0.35 * (2 * t - 1) ** 2  # gunwale rises toward the ends
        row = []
        for j in range(around + 1):
            u = -1 + 2 * j / around
            x = w * u
            z = keel_z + sheer * (abs(u) ** 1.6)
            row.append(bm.verts.new((x, y, z)))
        rows.append(row)
    for a, b in zip(rows, rows[1:]):
        for j in range(around):
            bm.faces.new((a[j], a[j + 1], b[j + 1], b[j]))
    return rows


def build_rowboat(index):
    name = "Rowboat"
    root = make_root(name, index)
    bm = bmesh.new()
    hull_shell(bm, length=14.0, beam=5.0, depth=1.9, keel_z=-1.0)
    finish_obj = finish(bm, name, "Hull", root, smooth_angle=50)
    mod = finish_obj.modifiers.new("thick", "SOLIDIFY")
    mod.thickness = 0.18

    bm = bmesh.new()
    for y in (-3.0, 0.5, 3.6):
        box(bm, (0, y, 0.35), (3.8 - abs(y) * 0.25, 0.9, 0.18))
    # Gunwale rails.
    pts_l, pts_r = [], []
    for i in range(17):
        t = i / 16
        y = -7 + 14 * t
        w = 2.5 * (max(0.0, math.sin(math.pi * (0.35 + 0.65 * t))) ** 0.75)
        z = -1.0 + 1.9 + 0.35 * (2 * t - 1) ** 2 + 0.05
        pts_l.append((w, y, z))
        pts_r.append((-w, y, z))
    tube_along(bm, pts_l, 0.13, sides=6)
    tube_along(bm, pts_r, 0.13, sides=6)
    # Oars resting across the seats.
    tube_along(bm, [(-3.2, -1.2, 0.7), (3.4, 1.4, 0.75)], 0.1, sides=6)
    box(bm, (3.9, 1.6, 0.75), (1.2, 0.5, 0.08), Matrix.Rotation(0.37, 4, "Z"))
    finish(bm, name, "WoodDark", root, smooth_angle=40)


def build_shipwreck(index):
    name = "Shipwreck"
    root = make_root(name, index)
    length, beam, depth, keel = 28.0, 9.0, 5.0, -1.5

    def section(t, u):
        w = beam / 2 * (max(0.0, math.sin(math.pi * (0.3 + 0.7 * t))) ** 0.8)
        z = keel + (depth + 0.6 * (2 * t - 1) ** 2) * (abs(u) ** 1.5)
        return Vector((w * u, -length / 2 + length * t, z))

    bm = bmesh.new()
    # Ribs: most of the frame survives.
    for i in range(11):
        t = 0.06 + 0.86 * i / 10
        broken = 0.55 if i in (3, 7) else 1.0
        pts = [section(t, -1 + 2 * k / 12) for k in range(13) if abs(-1 + 2 * k / 12) <= broken]
        if len(pts) > 1:
            tube_along(bm, pts, 0.32, sides=6)
    # Keel.
    tube_along(bm, [section(t / 10, 0) - Vector((0, 0, 0.2)) for t in range(11)], 0.45, sides=6)
    finish(bm, name, "WoodDark", root, smooth_angle=35)

    bm = bmesh.new()
    # Planking survives on the low side only, with gaps where it rotted away.
    for row in range(5):
        u = -1 + row * 0.18
        start = 0.08 + 0.1 * (row % 2)
        end = 0.88 - 0.22 * (row % 3 == 1)
        seg = 14
        prev = None
        for s in range(seg + 1):
            t = start + (end - start) * s / seg
            a = section(t, u)
            b = section(t, u + 0.16)
            pair = (bm.verts.new(a), bm.verts.new(b))
            if prev:
                bm.faces.new((prev[0], prev[1], pair[1], pair[0]))
            prev = pair
    # Snapped mast lying across the deck line.
    tube_along(bm, [(0.5, 2.0, -0.5), (1.2, 4.0, 8.5), (1.6, 5.2, 13.0)], 0.5, sides=8, taper=lambda t: 1 - 0.3 * t)
    tube_along(bm, [(-2.5, 6.0, 1.5), (4.0, 6.6, 2.4)], 0.3, sides=6)
    wreck = finish(bm, name, "Wood", root, smooth_angle=35)
    mod = wreck.modifiers.new("thick", "SOLIDIFY")
    mod.thickness = 0.2


# ----------------------------------------------------------------------------------------
# Market booth shell (origin = booth center on the ground, front = -Y). Matches the
# DonationStand contract in IslandBuilder: the counter/Podium, sign and tier parts are
# runtime parts; this is the architecture around them.


def build_booth(index):
    name = "BoothShell"
    root = make_root(name, index)

    bm = bmesh.new()
    bevel = 0.6
    for x in (-5.0, 5.0):
        box(bm, (x, -3.0, 0.6 + 8.1 / 2), (bevel, bevel, 8.1))
        box(bm, (x, 4.0, 0.6 + 9.8 / 2), (bevel, bevel, 9.8))
        # Side rail and diagonal brace.
        box(bm, (x, 0.5, 3.2), (0.25, 7.0, 0.35))
        box(bm, (x, 0.5, 1.6), (0.25, 7.0, 0.35))
    # Top beams.
    box(bm, (0, -3.0, 8.75), (10.8, 0.5, 0.5))
    box(bm, (0, 4.0, 10.45), (10.8, 0.5, 0.5))
    for x in (-5.0, 5.0):
        rise = Vector((0, 7.0, 1.7))
        rot = Matrix.Rotation(math.atan2(rise.z, rise.y), 4, "X")
        box(bm, (x, 0.5, 9.6), (0.45, rise.length + 0.6, 0.45), rot)
    finish(bm, name, "Wood", root, smooth_angle=30)

    bm = bmesh.new()
    # Back wall: horizontal planks with small gaps.
    for i in range(6):
        z = 0.9 + i * 0.95
        box(bm, (0, 4.2, z + 0.42), (10.0, 0.3, 0.85))
    # A small shelf on the back wall.
    box(bm, (0, 3.75, 4.1), (8.0, 0.8, 0.18))
    finish(bm, name, "WoodDark", root, smooth_angle=30)

    # Striped awning: sags slightly, scalloped valance across the front.
    stripes = 8
    width = 12.2
    canvas, stripe = bmesh.new(), bmesh.new()
    back = Vector((0, 5.0, 10.75))
    front = Vector((0, -4.9, 9.0))
    rows = 10
    for s in range(stripes):
        target = canvas if s % 2 == 0 else stripe
        x0 = -width / 2 + width * s / stripes
        x1 = -width / 2 + width * (s + 1) / stripes
        grid = []
        for r in range(rows + 1):
            v = r / rows
            p = back.lerp(front, v)
            sag = 0.32 * math.sin(math.pi * v)
            grid.append((target.verts.new((x0, p.y, p.z - sag)), target.verts.new((x1, p.y, p.z - sag))))
        for a, b in zip(grid, grid[1:]):
            target.faces.new((a[0], a[1], b[1], b[0]))
        # Valance flap with a rounded scallop at the bottom of each stripe.
        top_l, top_r = grid[-1]
        drop = 1.15
        scallop = [
            target.verts.new((x0, front.y - 0.02, front.z - drop)),
            target.verts.new((x0 + (x1 - x0) * 0.25, front.y - 0.02, front.z - drop - 0.32)),
            target.verts.new((x0 + (x1 - x0) * 0.5, front.y - 0.02, front.z - drop - 0.42)),
            target.verts.new((x0 + (x1 - x0) * 0.75, front.y - 0.02, front.z - drop - 0.32)),
            target.verts.new((x1, front.y - 0.02, front.z - drop)),
        ]
        target.faces.new([top_l, top_r] + list(reversed(scallop)))
    finish(canvas, name, "Canvas", root, smooth_angle=50, uv_scale=3.0)
    finish(stripe, name, "Stripe", root, smooth_angle=50, uv_scale=3.0)

    bm = bmesh.new()
    # Two hanging lanterns at the front corners.
    for x in (-4.6, 4.6):
        tube_along(bm, [(x, -3.6, 8.5), (x, -3.6, 7.6)], 0.05, sides=4)
        box(bm, (x, -3.6, 7.1), (0.7, 0.7, 0.9))
    finish(bm, name, "Iron", root, smooth_angle=30)
    bm = bmesh.new()
    for x in (-4.6, 4.6):
        box(bm, (x, -3.6, 7.1), (0.5, 0.75, 0.62))
    finish(bm, name, "Glow", root, smooth_angle=30)


# ----------------------------------------------------------------------------------------
# Street furniture


def build_lamp(index):
    name = "LampPost"
    root = make_root(name, index)
    bm = bmesh.new()
    lathe(bm, [
        (0.0, 0.0), (0.95, 0.0), (0.95, 0.5), (0.7, 0.75), (0.45, 1.1), (0.32, 1.6), (0.24, 8.8),
        (0.38, 9.1), (0.38, 9.4), (0.22, 9.6), (0.2, 11.3), (0.0, 11.3),
    ], segments=16)
    # Lantern cage and cap.
    lathe(bm, [(0.0, 11.3), (0.85, 11.4), (0.85, 11.6), (0.0, 11.6)], segments=8, phase=math.pi / 8)
    for k in range(4):
        a = TAU * k / 4 + math.pi / 4
        box(bm, (math.cos(a) * 0.68, math.sin(a) * 0.68, 12.45), (0.12, 0.12, 1.7))
    lathe(bm, [(0.0, 13.25), (1.05, 13.25), (0.6, 13.75), (0.2, 14.1), (0.0, 14.2)], segments=8, phase=math.pi / 8)
    sphere(bm, (0, 0, 14.35), 0.18, subdivisions=1)
    finish(bm, name, "Iron", root, smooth_angle=45)

    bm = bmesh.new()
    lathe(bm, [(0.0, 11.6), (0.62, 11.6), (0.62, 13.25), (0.0, 13.25)], segments=8, phase=math.pi / 8)
    finish(bm, name, "Glass", root, smooth_angle=30)


def build_bench(index):
    name = "Bench"
    root = make_root(name, index)
    bm = bmesh.new()
    for i in range(4):
        box(bm, (0, -0.75 + i * 0.5, 1.6), (7.0, 0.4, 0.14))
    tilt = Matrix.Rotation(math.radians(-14), 4, "X")
    for i in range(3):
        box(bm, (0, 0.95 + i * 0.12, 2.25 + i * 0.5), (7.0, 0.14, 0.4), tilt)
    finish(bm, name, "Wood", root, smooth_angle=30)

    bm = bmesh.new()
    for x in (-3.0, 3.0):
        # Cast-iron side frame: front leg, back leg rising into the backrest, seat bar.
        tube_along(bm, [(x, -0.9, 0.0), (x, -0.85, 0.8), (x, -0.8, 1.5)], 0.12, sides=6)
        tube_along(bm, [(x, 0.9, 0.0), (x, 0.9, 1.5), (x, 1.15, 2.5), (x, 1.35, 3.4)], 0.12, sides=6)
        tube_along(bm, [(x, -0.95, 1.5), (x, 1.0, 1.5)], 0.1, sides=6)
        tube_along(bm, [(x, -0.9, 1.5), (x, -1.0, 2.2), (x, -0.6, 2.35)], 0.09, sides=6)
    finish(bm, name, "Iron", root, smooth_angle=45)


def build_chest(index):
    name = "Chest"
    root = make_root(name, index)
    bm = bmesh.new()
    box(bm, (0, 0, 0.9), (4.0, 2.6, 1.8))
    # Barrel lid: half-cylinder along X.
    lid = []
    for k in range(9):
        a = math.pi * k / 8
        lid.append((math.cos(a) * 1.3, 1.8 + math.sin(a) * 0.9))
    left = [bm.verts.new((-2.0, y, z)) for y, z in lid]
    right = [bm.verts.new((2.0, y, z)) for y, z in lid]
    for k in range(8):
        bm.faces.new((left[k], left[k + 1], right[k + 1], right[k]))
    bm.faces.new(left)
    bm.faces.new(list(reversed(right)))
    finish(bm, name, "Wood", root, smooth_angle=35)

    bm = bmesh.new()
    for x in (-1.4, 1.4):
        box(bm, (x, 0, 0.9), (0.25, 2.7, 1.85))
        pts = [(x, math.cos(math.pi * k / 8) * 1.36, 1.8 + math.sin(math.pi * k / 8) * 0.95) for k in range(9)]
        tube_along(bm, pts, 0.1, sides=4)
    box(bm, (0, -1.35, 1.7), (0.6, 0.2, 0.7))
    finish(bm, name, "Iron", root, smooth_angle=30)


# ----------------------------------------------------------------------------------------


def build_all():
    reset_scene()
    builders = {
        "PalmA": lambda i: build_palm("PalmA", i, height=22.0, lean=0.9, fronds=9, seed=1),
        "PalmB": lambda i: build_palm("PalmB", i, height=18.0, lean=-0.6, fronds=8, seed=4),
        "RockA": lambda i: build_rock("RockA", i, (1.25, 1.0, 0.75), 1),
        "RockB": lambda i: build_rock("RockB", i, (1.0, 0.85, 1.05), 2),
        "RockC": lambda i: build_rock("RockC", i, (1.5, 0.9, 0.55), 3),
        "Fountain": build_fountain,
        "Lighthouse": build_lighthouse,
        "Rowboat": build_rowboat,
        "Shipwreck": build_shipwreck,
        "BoothShell": build_booth,
        "LampPost": build_lamp,
        "Bench": build_bench,
        "Chest": build_chest,
    }
    for index, name in enumerate(ASSET_ORDER):
        builders[name](index)


def export_glb(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    for obj in bpy.context.scene.objects:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True, export_yup=True)


def render_preview(path):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x = 1800
    scene.render.resolution_y = 700
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.65, 0.78, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    scene.world = world

    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(35))
    scene.collection.objects.link(sun)

    ground = bpy.data.meshes.new("Ground")
    gbm = bmesh.new()
    box(gbm, ((len(ASSET_ORDER) - 1) * GRID / 2, 0, -0.5), (len(ASSET_ORDER) * GRID + 40, 120, 1))
    gbm.to_mesh(ground)
    gobj = bpy.data.objects.new("Ground", ground)
    scene.collection.objects.link(gobj)

    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = len(ASSET_ORDER) * GRID + 20
    cam.location = ((len(ASSET_ORDER) - 1) * GRID / 2, -200, 60)
    cam.rotation_euler = (math.radians(80), 0, 0)
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    build_all()
    export_glb(os.path.join(OUT_DIR, "lobby_props.glb"))
    if "--render" in argv:
        render_preview(os.path.join(OUT_DIR, "lobby_props_preview.png"))
    print("LOBBY_PROPS_DONE")


def render_closeups(out_dir):
    """One perspective render per asset, for reviewing the art without Studio."""
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x = 520
    scene.render.resolution_y = 520
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.62, 0.72, 0.85, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    scene.world = world
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.2
    sun.rotation_euler = (math.radians(48), math.radians(8), math.radians(-35))
    scene.collection.objects.link(sun)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.lens = 40
    scene.collection.objects.link(cam)
    scene.camera = cam
    for index, name in enumerate(ASSET_ORDER):
        root = bpy.data.objects[name]
        lo = Vector((1e9, 1e9, 1e9))
        hi = Vector((-1e9, -1e9, -1e9))
        for child in root.children:
            for corner in child.bound_box:
                w = child.matrix_world @ Vector(corner)
                lo = Vector(map(min, lo, w))
                hi = Vector(map(max, hi, w))
        center = (lo + hi) / 2
        radius = (hi - lo).length / 2
        # Three-quarter view from the front (-Y) side.
        direction = Vector((0.55, -1.0, 0.45)).normalized()
        cam.location = center + direction * radius * 2.3
        cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(out_dir, f"closeup_{index:02d}_{name}.png")
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__" and "--closeups" in sys.argv:
    render_closeups(OUT_DIR)
