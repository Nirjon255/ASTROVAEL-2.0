"""
Procedural planet textures for ASTROVAEL 26.0.

Everything is sampled on the unit sphere, so the noise is seamless at the
longitude wrap and at the poles. Colours are chosen from real-world reference
palettes (Mars: rust/ochre with dark basalt and white CO2 polar caps; Earth:
deep blue oceans, green/tan land, white ice caps and cloud layer; Moon: grey
regolith with dark maria).
"""
import os
import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")
W, H = 2048, 1024


def unit_sphere_grid(w, h):
    """Unit vectors and latitude for every pixel of an equirectangular map."""
    x = (np.arange(w) + 0.5) / w
    y = (np.arange(h) + 0.5) / h
    lon = x * 2.0 * np.pi - np.pi
    lat = np.pi / 2.0 - y * np.pi
    lon_g, lat_g = np.meshgrid(lon, lat)
    cl = np.cos(lat_g)
    pts = np.stack([cl * np.cos(lon_g), np.sin(lat_g), cl * np.sin(lon_g)], axis=-1)
    return pts.reshape(-1, 3), lat_g.reshape(-1)


def value_noise(pts, freq, seed, lattice=64):
    """Smooth, continuous 3D value noise over an integer lattice (0..1)."""
    rng = np.random.default_rng(seed)
    grid = rng.random((lattice, lattice, lattice))
    q = pts * freq + 1000.0
    i = np.floor(q).astype(np.int64)
    f = q - i
    u = f * f * (3.0 - 2.0 * f)
    ix = [i[:, 0] % lattice, (i[:, 0] + 1) % lattice]
    iy = [i[:, 1] % lattice, (i[:, 1] + 1) % lattice]
    iz = [i[:, 2] % lattice, (i[:, 2] + 1) % lattice]
    def c(a, b, d):
        return grid[ix[a], iy[b], iz[d]]
    x00 = c(0, 0, 0) * (1 - u[:, 0]) + c(1, 0, 0) * u[:, 0]
    x10 = c(0, 1, 0) * (1 - u[:, 0]) + c(1, 1, 0) * u[:, 0]
    x01 = c(0, 0, 1) * (1 - u[:, 0]) + c(1, 0, 1) * u[:, 0]
    x11 = c(0, 1, 1) * (1 - u[:, 0]) + c(1, 1, 1) * u[:, 0]
    y0 = x00 * (1 - u[:, 1]) + x10 * u[:, 1]
    y1 = x01 * (1 - u[:, 1]) + x11 * u[:, 1]
    return y0 * (1 - u[:, 2]) + y1 * u[:, 2]


def fbm(pts, base_freq, octaves, seed, gain=0.5):
    total = np.zeros(pts.shape[0])
    amp = 1.0
    norm = 0.0
    freq = base_freq
    for o in range(octaves):
        total += amp * value_noise(pts, freq, seed + o * 17)
        norm += amp
        amp *= gain
        freq *= 2.0
    return total / norm


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def mix(a, b, t):
    t = t[:, None] if t.ndim == 1 else t
    return a * (1.0 - t) + b * t


def add_craters(pts, albedo, count, seed, min_r, max_r, depth, rim_gain):
    rng = np.random.default_rng(seed)
    for _ in range(count):
        c = rng.normal(size=3)
        c /= np.linalg.norm(c)
        r = rng.uniform(min_r, max_r)
        r2 = 1.0 - np.cos(r)
        rr = 1.0 - pts @ c
        bowl = rr < r2 * 0.92
        rim = (rr >= r2 * 0.92) & (rr < r2 * 1.12)
        albedo[bowl] *= (1.0 - depth * rng.uniform(0.6, 1.0))
        albedo[rim] *= (1.0 + rim_gain * rng.uniform(0.4, 1.0))
    return albedo


def save(arr, name, size=None):
    img = Image.fromarray((np.clip(arr, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8), mode="RGB" if arr.shape[-1] == 3 else "RGBA")
    if size is not None:
        img = img.resize(size, Image.LANCZOS)
    img.save(os.path.join(OUT, name), optimize=True)
    print("wrote", name, img.size)


def make_mars():
    pts, lat = unit_sphere_grid(W, H)
    lat_abs = np.abs(lat)
    # Large dark basalt plains (Syrtis / Acidalia-like) and bright dust highlands.
    plains = fbm(pts, 1.3, 5, seed=11)
    dust = fbm(pts, 3.0, 5, seed=23)
    fine = fbm(pts, 14.0, 3, seed=37)
    dark_mask = smoothstep(0.52, 0.66, plains)
    base = np.array([0.80, 0.47, 0.29])
    bright = np.array([0.90, 0.63, 0.42])
    basalt = np.array([0.36, 0.25, 0.21])
    albedo = mix(np.tile(base, (pts.shape[0], 1)), np.tile(bright, (pts.shape[0], 1)), smoothstep(0.42, 0.62, dust))
    albedo = mix(albedo, np.tile(basalt, (pts.shape[0], 1)), dark_mask * 0.82)
    albedo *= (0.88 + 0.24 * fine)[:, None]
    # Polar CO2/H2O caps: fuzzy-edged, seasonal-looking, strongest at the poles.
    sin_lat = np.abs(pts[:, 1])  # sine of latitude: 1.0 at the poles
    cap = smoothstep(0.945, 0.975, sin_lat + 0.06 * (fine - 0.5))
    albedo = mix(albedo, np.tile(np.array([0.93, 0.92, 0.90]), (pts.shape[0], 1)), cap)
    albedo = add_craters(pts, albedo, count=320, seed=101, min_r=0.006, max_r=0.05, depth=0.35, rim_gain=0.22)
    save(albedo.reshape(H, W, 3), "mars_surface.png")


def make_earth():
    pts, lat = unit_sphere_grid(W, H)
    lat_abs = np.abs(lat)
    continents = fbm(pts, 1.4, 6, seed=5)
    land = smoothstep(0.50, 0.53, continents)
    depth = np.clip((0.52 - continents) * 4.0, 0.0, 1.0)
    shallow = np.array([0.10, 0.36, 0.52])
    deep = np.array([0.02, 0.10, 0.28])
    ocean = mix(np.tile(shallow, (pts.shape[0], 1)), np.tile(deep, (pts.shape[0], 1)), depth)
    veg = np.array([0.17, 0.34, 0.12])
    desert = np.array([0.58, 0.46, 0.27])
    mountain = np.array([0.42, 0.40, 0.36])
    dryness = smoothstep(0.42, 0.60, fbm(pts, 2.2, 4, seed=8))
    rough = smoothstep(0.55, 0.72, fbm(pts, 6.0, 3, seed=9))
    ground = mix(np.tile(veg, (pts.shape[0], 1)), np.tile(desert, (pts.shape[0], 1)), dryness)
    ground = mix(ground, np.tile(mountain, (pts.shape[0], 1)), rough * 0.7)
    albedo = mix(ocean, ground, land)
    ice_noise = fbm(pts, 5.0, 3, seed=61)
    sin_lat = np.abs(pts[:, 1])
    ice = smoothstep(0.955, 0.98, sin_lat + 0.05 * (ice_noise - 0.5))
    albedo = mix(albedo, np.tile(np.array([0.92, 0.95, 0.98]), (pts.shape[0], 1)), ice)
    save(albedo.reshape(H, W, 3), "earth_surface.png")

    # Cloud layer as RGBA: white with alpha driven by a second noise field.
    cloud_field = fbm(pts, 2.6, 6, seed=77)
    alpha = smoothstep(0.50, 0.70, cloud_field) * 0.92
    rgba = np.zeros((H * W, 4))
    rgba[:, 0:3] = np.array([0.97, 0.98, 1.0])
    rgba[:, 3] = alpha
    save(rgba.reshape(H, W, 4), "earth_clouds.png")


def make_moon():
    w, h = 1024, 512
    pts, _ = unit_sphere_grid(w, h)
    regolith = fbm(pts, 4.0, 5, seed=301)
    maria = smoothstep(0.46, 0.40, fbm(pts, 1.6, 4, seed=311))
    albedo = np.tile(np.array([0.56, 0.55, 0.53]), (pts.shape[0], 1))
    albedo *= (0.82 + 0.30 * regolith)[:, None]
    albedo = mix(albedo, np.tile(np.array([0.22, 0.22, 0.23]), (pts.shape[0], 1)), maria * 0.75)
    albedo = add_craters(pts, albedo, count=260, seed=331, min_r=0.004, max_r=0.035, depth=0.30, rim_gain=0.25)
    save(albedo.reshape(h, w, 3), "moon_surface.png")


if __name__ == "__main__":
    make_mars()
    make_earth()
    make_moon()
