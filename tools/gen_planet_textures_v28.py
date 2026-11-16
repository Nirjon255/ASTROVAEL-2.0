"""
Procedural planet textures for ASTROVAEL 28.0: Venus, Jupiter, Saturn, Uranus, Neptune.

Sampled on the unit sphere, so patterns wrap seamlessly at the longitude seam and the poles.
Palettes follow spacecraft imagery of the real planets: Venus's yellow sulphuric cloud decks,
Jupiter's cream, tan and brown zones with the red oval, Saturn's pale gold bands, Uranus's
pale cyan haze and Neptune's deep blue with white high clouds.

Run from the project folder:  python3 tools/gen_planet_textures_v28.py
"""
import os
import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")


def sphere_grid(w, h):
    x = (np.arange(w) + 0.5) / w
    y = (np.arange(h) + 0.5) / h
    lon = x * 2.0 * np.pi - np.pi
    lat = np.pi / 2.0 - y * np.pi
    lon_g, lat_g = np.meshgrid(lon, lat)
    cl = np.cos(lat_g)
    pts = np.stack([cl * np.cos(lon_g), np.sin(lat_g), cl * np.sin(lon_g)], axis=-1)
    return pts.reshape(-1, 3), lat_g.reshape(-1), lon_g.reshape(-1)


def value_noise(pts, freq, seed, lattice=64):
    rng = np.random.default_rng(seed)
    grid = rng.random((lattice, lattice, lattice))
    q = pts * freq + 1000.0
    i = np.floor(q).astype(np.int64)
    f = q - i
    u = f * f * (3.0 - 2.0 * f)

    def corner(dx, dy, dz):
        return grid[(i[:, 0] + dx) % lattice, (i[:, 1] + dy) % lattice, (i[:, 2] + dz) % lattice]

    def mix(a, b, t):
        return a + (b - a) * t

    x00 = mix(corner(0, 0, 0), corner(1, 0, 0), u[:, 0])
    x10 = mix(corner(0, 1, 0), corner(1, 1, 0), u[:, 0])
    x01 = mix(corner(0, 0, 1), corner(1, 0, 1), u[:, 0])
    x11 = mix(corner(0, 1, 1), corner(1, 1, 1), u[:, 0])
    return mix(mix(x00, x10, u[:, 1]), mix(x01, x11, u[:, 1]), u[:, 2])


def fbm(pts, freq, seed, octaves=5):
    total = np.zeros(len(pts))
    amp, norm, f = 0.5, 0.0, freq
    for o in range(octaves):
        total += amp * value_noise(pts, f, seed + o * 17)
        norm += amp
        amp *= 0.5
        f *= 2.03
    return total / norm


def palette(t, stops):
    t = np.clip(t, 0.0, 1.0)
    pos = [s[0] for s in stops]
    out = np.zeros((len(t), 3))
    for c in range(3):
        out[:, c] = np.interp(t, pos, [s[1][c] for s in stops])
    return out


def save(colors, w, h, name):
    img = (np.clip(colors, 0.0, 1.0).reshape(h, w, 3) * 255).astype(np.uint8)
    Image.fromarray(img, "RGB").save(os.path.join(OUT, name), optimize=True)
    print("wrote", name)


def venus(w, h):
    pts, lat, _ = sphere_grid(w, h)
    wx = fbm(pts, 2.0, 301, 4) - 0.5
    wy = fbm(pts, 2.0, 311, 4) - 0.5
    wz = fbm(pts, 2.0, 321, 4) - 0.5
    warped = pts + 0.45 * np.stack([wx, wy, wz], axis=1)
    detail = fbm(warped, 3.0, 331, 5)
    bands = 0.5 + 0.5 * np.sin(lat * 9.0 + 2.2 * detail)
    t = 0.55 * detail + 0.45 * bands
    return palette(t, [(0.0, (0.62, 0.42, 0.18)), (0.35, (0.86, 0.66, 0.34)),
                       (0.7, (0.98, 0.90, 0.66)), (1.0, (1.0, 0.97, 0.85))])


def jupiter(w, h):
    pts, lat, lon = sphere_grid(w, h)
    turb = fbm(pts, 3.0, 401, 5)
    band = 0.5 + 0.5 * np.sin(lat * 15.0 + 1.6 * turb)
    t = 0.7 * band + 0.3 * turb
    colors = palette(t, [(0.0, (0.46, 0.30, 0.20)), (0.25, (0.74, 0.55, 0.38)),
                         (0.5, (0.92, 0.84, 0.70)), (0.75, (0.98, 0.96, 0.90)),
                         (1.0, (0.80, 0.62, 0.44))])
    # Great Red Spot: an oval south of the equator.
    d_lon = np.angle(np.exp(1j * (lon - 0.9)))
    oval = (d_lon / 0.28) ** 2 + ((lat + 0.38) / 0.09) ** 2
    spot = np.clip(1.0 - oval, 0.0, 1.0) ** 0.6
    red = np.array([0.72, 0.30, 0.20])
    return colors * (1.0 - 0.85 * spot[:, None]) + red * 0.85 * spot[:, None]


def saturn(w, h):
    pts, lat, _ = sphere_grid(w, h)
    turb = fbm(pts, 2.5, 501, 4)
    band = 0.5 + 0.5 * np.sin(lat * 11.0 + 1.2 * turb)
    t = 0.6 * band + 0.4 * turb
    return palette(t, [(0.0, (0.66, 0.55, 0.36)), (0.35, (0.90, 0.82, 0.60)),
                       (0.7, (0.98, 0.93, 0.78)), (1.0, (0.85, 0.76, 0.52))])


def uranus(w, h):
    pts, lat, _ = sphere_grid(w, h)
    turb = fbm(pts, 1.6, 601, 3)
    band = 0.5 + 0.5 * np.sin(lat * 4.0 + 0.8 * turb)
    t = 0.5 * turb + 0.5 * band
    return palette(t, [(0.0, (0.50, 0.82, 0.86)), (0.5, (0.66, 0.90, 0.93)),
                       (1.0, (0.80, 0.96, 0.98))])


def neptune(w, h):
    pts, _, _ = sphere_grid(w, h)
    t = fbm(pts, 2.2, 701, 4)
    base = palette(t, [(0.0, (0.08, 0.22, 0.62)), (0.5, (0.14, 0.36, 0.85)),
                       (1.0, (0.30, 0.55, 0.95))])
    streak = np.clip((fbm(pts, 6.0, 711, 3) - 0.55) * 4.0, 0.0, 1.0)
    white = np.array([0.85, 0.93, 1.0])
    return base * (1.0 - 0.6 * streak[:, None]) + white * 0.6 * streak[:, None]


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    save(venus(2048, 1024), 2048, 1024, "venus_surface.png")
    save(jupiter(2048, 1024), 2048, 1024, "jupiter_surface.png")
    save(saturn(2048, 1024), 2048, 1024, "saturn_surface.png")
    save(uranus(1024, 512), 1024, 512, "uranus_surface.png")
    save(neptune(1024, 512), 1024, 512, "neptune_surface.png")
