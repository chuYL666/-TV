# 图标与 TV banner 生成

用 Pillow 矢量绘制，不依赖设计稿，改色 / 改形状都在脚本里。

| 脚本 | 产出 |
|---|---|
| `make_icon.py` | `mipmap-{m,h,x,xx,xxx}dpi/` 下的 `ic_launcher.png`（48–192px）、`ic_launcher_foreground.png`、`ic_launcher_monochrome.png`（108dp 画板，供自适应图标用），以及 `out/` 里的预览图 |
| `make_banner.py` | `drawable-xhdpi/tv_banner.png` 与 `tv_banner_all_sources.png`（640×360） |

## 为什么需要 banner

Android TV 桌面渲染的是 `android:banner` 而不是 `android:icon`。只改图标、不改 banner，桌面上看到的仍是旧横幅——这正是本项目 1.0.3 之前「图标显示成上游名字」的原因。

## 用法

```bash
pip install pillow
python make_icon.py      # 图标 + out/preview.png
python make_banner.py    # TV banner
```

脚本按自身位置推导 `res/` 路径，需在仓库内的目录结构下执行。字体用 Windows 自带的 `msyhbd.ttc`（微软雅黑粗体），非 Windows 环境请改成系统内可用的中文字体路径。

配色：底色 `#241917`（深棕黑），果实由 `#B7241A` 渐变到 `#F1583C`，叶蒂 `#4A9E4C`。改 `BG` / `edge` / `center` 几个常量即可整体换色。
