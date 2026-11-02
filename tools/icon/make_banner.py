# -*- coding: utf-8 -*-
"""生成 TV banner（640x360）：深色底 + 左番茄 + 右文字。"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from make_icon import draw_tomato

W, H = 640, 360
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RES = os.path.join(ROOT, "android", "app", "src", "main", "res", "drawable-xhdpi")

BG_TOP = (44, 30, 27)
BG_BOTTOM = (20, 14, 13)


def vgrad(w, h, top, bottom):
    img = Image.new("RGB", (1, h))
    px = img.load()
    for y in range(h):
        t = y / (h - 1)
        px[0, y] = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
    return img.resize((w, h), Image.BICUBIC)


def build(out_path):
    bg = vgrad(W, H, BG_TOP, BG_BOTTOM).convert("RGBA")

    # 番茄背后的暗红光晕，让主体从深底浮出来
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([-70, -30, 330, 370], fill=(170, 44, 28, 160))
    glow = glow.filter(ImageFilter.GaussianBlur(70))
    bg = Image.alpha_composite(bg, glow)

    tom = draw_tomato(280, tomato_ratio=0.82, bg=None)
    bg.alpha_composite(tom, (24, 40))

    d = ImageDraw.Draw(bg)
    f_big = ImageFont.truetype(r"C:/Windows/Fonts/msyhbd.ttc", 112)
    f_small = ImageFont.truetype(r"C:/Windows/Fonts/msyh.ttc", 46)

    d.text((348, 74), "番茄", font=f_big, fill=(255, 246, 242, 255))
    d.rounded_rectangle([352, 212, 588, 216], radius=2, fill=(150, 62, 48, 255))
    d.text((352, 232), "短 剧", font=f_small, fill=(216, 162, 146, 255))

    bg.convert("RGB").save(out_path, quality=100)
    print("saved", out_path)


if __name__ == "__main__":
    build(os.path.join(RES, "tv_banner.png"))
    build(os.path.join(RES, "tv_banner_all_sources.png"))
