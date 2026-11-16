"""
Procedural metal panel textures for ASTROVAEL 28.13: a hull (ships) and a station (lighter, larger panels).
Each set has an albedo map, a normal map and a roughness map (in the red channel, as Godot reads it).
Seams, rivets, wear and scratches are all generated here, so no image files come from outside the project.

Run from the project folder:  python3 tools/gen_metal_textures_v28_13.py
"""
import os
import numpy as np
from PIL import Image, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")
SIZE = 512


def smooth_noise(seed, sigma):
    rng = np.random.default_rng(seed)
    img = Image.fromarray((rng.random((SIZE, SIZE)) * 255).astype(np.uint8))
    img = img.filter(ImageFilter.GaussianBlur(sigma))
    a = np.asarray(img).astype(np.float32) / 255.0
    return (a - a.mean()) / (a.std() + 1e-6)


def make_metal(name, base_rgb, grid, seam_w, rough_base, seed):
    yy, xx = np.mgrid[0:SIZE, 0:SIZE]
    seam = np.zeros((SIZE, SIZE), np.float32)
    for k in range(0, SIZE, grid):
        seam[k:k + seam_w, :] = 1.0
        seam[:, k:k + seam_w] = 1.0
    # Rivets, four to each panel, slightly raised.
    rivets = np.zeros((SIZE, SIZE), np.float32)
    for ky in range(0, SIZE, grid):
        for kx in range(0, SIZE, grid):
            for dy, dx in [(grid // 4, grid // 4), (grid // 4, 3 * grid // 4),
                           (3 * grid // 4, grid // 4), (3 * grid // 4, 3 * grid // 4)]:
                cy, cx = ky + dy, kx + dx
                if cy < SIZE and cx < SIZE:
                    rivets += np.exp(-((yy - cy) ** 2 + (xx - cx) ** 2) / (2 * 2.0 ** 2))
    rivets = np.clip(rivets, 0.0, 1.0)
    n_low = smooth_noise(seed, 8)
    n_fine = smooth_noise(seed + 1, 1.2)

    # Albedo: the base metal, varied gently, with darker seams, brighter rivets and a few scratches.
    tone = 1.0 + 0.06 * n_low + 0.03 * n_fine
    albedo = np.array(base_rgb, np.float32)[None, None, :] * tone[..., None]
    albedo *= (1.0 - 0.45 * seam)[..., None]
    albedo += 0.12 * rivets[..., None]
    rng = np.random.default_rng(seed + 2)
    for _ in range(70):
        x = int(rng.integers(0, SIZE - 60))
        y = int(rng.integers(0, SIZE))
        length = int(rng.integers(10, 50))
        albedo[y:y + 1, x:x + length] *= 0.82
    albedo = np.clip(albedo, 0.0, 1.0)

    # Normal map from the height: seams sink, rivets rise, and the surface has a fine grain.
    height = -0.6 * seam + 0.5 * rivets + 0.08 * n_fine + 0.05 * n_low
    gy, gx = np.gradient(height)
    strength = 4.0
    nx = -gx * strength
    ny = gy * strength
    nz = np.ones_like(nx)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    normal = np.stack([0.5 + 0.5 * nx / length, 0.5 + 0.5 * ny / length, 0.5 + 0.5 * nz / length], axis=-1)

    # Roughness: the panels are smooth, the seams and the wear are rougher.
    rough = np.clip(rough_base + 0.10 * n_low + 0.30 * seam + 0.10 * rivets, 0.0, 1.0)

    Image.fromarray((albedo * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, name + "_albedo.png"), optimize=True)
    Image.fromarray((normal * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, name + "_normal.png"), optimize=True)
    Image.fromarray((rough * 255).astype(np.uint8), "L").save(os.path.join(OUT, name + "_roughness.png"), optimize=True)
    print("wrote", name)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    # The ship: a dark graphite hull with fine panels.
    make_metal("metal_hull", base_rgb=(0.55, 0.58, 0.62), grid=128, seam_w=2, rough_base=0.38, seed=901)
    # The station: a lighter silver-white hull with larger panels.
    make_metal("metal_station", base_rgb=(0.72, 0.75, 0.79), grid=256, seam_w=3, rough_base=0.30, seed=911)
