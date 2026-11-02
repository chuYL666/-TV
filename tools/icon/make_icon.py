# -*- coding: utf-8 -*-
"""生成番茄 App 图标（矢量风格，超采样抗锯齿）v2"""
from PIL import Image, ImageDraw, ImageFilter
import os, math

SS = 4


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def draw_tomato(canvas_px, tomato_ratio=0.62, bg=None, mono=False):
    S = canvas_px * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    if bg is not None:
        d.rounded_rectangle([0, 0, S - 1, S - 1], radius=int(S * 0.22), fill=bg)

    cx = S / 2
    rx = S * tomato_ratio / 2.0
    ry = rx * 0.90
    cy = S * 0.552

    # 果体：径向渐变（光源偏左上）
    if mono:
        edge = center = (255, 255, 255)
    else:
        edge = (183, 36, 26)
        center = (241, 84, 58)
    lx = cx - rx * 0.22
    ly = cy - ry * 0.28
    steps = 34
    for i in range(steps):
        t = i / (steps - 1.0)
        scale = 1.0 - t * 0.70
        ex, ey = rx * scale, ry * scale
        d.ellipse([lx - ex, ly - ey, lx + ex, ly + ey], fill=lerp(edge, center, t) + (255,))

    # 顶部叶蒂：扇形 5 片，只向斜上/上展开
    base_y = cy - ry * 0.74
    leaf_len = rx * 0.60
    angles = (-90, -126, -54, -162, -18)
    if mono:
        leaf_c, leaf_line = (255, 255, 255, 255), (255, 255, 255, 255)
    else:
        leaf_c = (74, 158, 76, 255)
        leaf_line = (56, 128, 60, 255)
    for ang in angles:
        a = math.radians(ang)
        tx = cx + math.cos(a) * leaf_len
        ty = base_y + math.sin(a) * leaf_len * 0.80
        nx, ny = -math.sin(a), math.cos(a)
        w = rx * 0.115
        d.polygon([(cx - nx * w, base_y - ny * w),
                   (cx + nx * w, base_y + ny * w),
                   (tx, ty)], fill=leaf_c, outline=leaf_line)

    # 叶芯 + 短茎
    if mono:
        stem_c = (255, 255, 255, 255)
    else:
        stem_c = (47, 110, 51, 255)
    d.ellipse([cx - rx * 0.155, base_y - rx * 0.135, cx + rx * 0.155, base_y + rx * 0.150],
              fill=(62, 146, 64, 255) if not mono else (255, 255, 255, 255))
    d.rounded_rectangle([cx - rx * 0.05, base_y - rx * 0.26, cx + rx * 0.05, base_y + rx * 0.02],
                        radius=int(rx * 0.045), fill=stem_c)

    # 高光
    if not mono:
        hi = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        hd = ImageDraw.Draw(hi)
        hx, hy = cx - rx * 0.40, cy - ry * 0.44
        hw, hh = rx * 0.40, ry * 0.26
        hd.ellipse([hx - hw, hy - hh, hx + hw, hy + hh], fill=(255, 255, 255, 100))
        hi = hi.filter(ImageFilter.GaussianBlur(radius=S * 0.024))
        img = Image.alpha_composite(img, hi)

    return img.resize((canvas_px, canvas_px), Image.LANCZOS)


def main():
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
    os.makedirs(out, exist_ok=True)
    draw_tomato(1024, tomato_ratio=0.66, bg=(255, 241, 230, 255)).save(os.path.join(out, "preview.png"))
    draw_tomato(432, tomato_ratio=0.56, bg=None).save(os.path.join(out, "foreground_432.png"))
    draw_tomato(432, tomato_ratio=0.56, bg=None, mono=True).save(os.path.join(out, "monochrome_432.png"))
    print("done")


if __name__ == "__main__":
    main()
