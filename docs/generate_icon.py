"""
OpenCode Mobile - 应用图标生成脚本

设计特性：
1. 几何构型：由 4 个纯代码角标 `<` (左 <, 右 >, 上 ^, 下 v) 构成的严格上下左右对称菱形代码环。
2. 空间占比：主体跨度 ~93%，线宽 92px，大幅降低边缘留白，保证在手机桌面小尺寸下的辨识度。
3. 色彩渲染：左上至右下冰川蔚蓝渐变 (#00D2FF -> #0078FF)，背景纯透明 (1024x1024 RGBA)。
"""

import os
import math
import numpy as np
from PIL import Image, ImageDraw


def generate_app_icon(output_dir: str):
    # 4x 超采样抗锯齿渲染
    scale = 4
    canvas_size = 1024 * scale
    cx, cy = canvas_size // 2, canvas_size // 2

    # 几何参数配置
    corner_dist = int(430 * scale)  # 尖角顶点距中心距离
    arm_len = int(245 * scale)      # 角标臂长
    line_width = int(92 * scale)    # 线宽（带圆角端点）

    def draw_rounded_polyline(draw, points, width, color):
        draw.line(points, fill=color, width=width, joint="round")
        r = width // 2
        for p in points:
            draw.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=color)

    # 计算 4 个方向的角标顶点与两臂坐标
    # 0°: 右 (>), 90°: 下 (v), 180°: 左 (<), 270°: 上 (^)
    chevrons = []
    for angle_deg in [0, 90, 180, 270]:
        rad = math.radians(angle_deg)
        tip_x = cx + corner_dist * math.cos(rad)
        tip_y = cy + corner_dist * math.sin(rad)
        arm1_rad = rad + math.radians(135)
        arm2_rad = rad - math.radians(135)
        p1 = (tip_x + arm_len * math.cos(arm1_rad), tip_y + arm_len * math.sin(arm1_rad))
        p2 = (tip_x, tip_y)
        p3 = (tip_x + arm_len * math.cos(arm2_rad), tip_y + arm_len * math.sin(arm2_rad))
        chevrons.append([p1, p2, p3])

    # 绘制高分辨率单通道蒙版
    mask_img = Image.new("L", (canvas_size, canvas_size), 0)
    mask_draw = ImageDraw.Draw(mask_img)
    for pts in chevrons:
        draw_rounded_polyline(mask_draw, pts, line_width, 255)

    # 冰川蔚蓝渐变（对角线：左上 -> 右下）
    y_coords, x_coords = np.mgrid[0:canvas_size, 0:canvas_size]
    t = (x_coords + y_coords) / (2.0 * canvas_size)
    t = np.clip(t * 1.4 - 0.2, 0.0, 1.0)

    c_start = (0, 210, 255)  # 电光青蓝 (#00D2FF)
    c_end = (0, 120, 255)    # 蔚蓝 (#0078FF)

    r = (c_start[0] * (1 - t) + c_end[0] * t).astype(np.uint8)
    g = (c_start[1] * (1 - t) + c_end[1] * t).astype(np.uint8)
    b = (c_start[2] * (1 - t) + c_end[2] * t).astype(np.uint8)
    a = np.array(mask_img, dtype=np.uint8)

    rgba = np.dstack((r, g, b, a))
    final_icon = Image.fromarray(rgba, "RGBA").resize((1024, 1024), Image.Resampling.LANCZOS)

    os.makedirs(output_dir, exist_ok=True)
    out_app_icon = os.path.join(output_dir, "app_icon.png")
    out_color4 = os.path.join(output_dir, "color4_ice_sky_blue.png")

    final_icon.save(out_app_icon)
    final_icon.save(out_color4)
    print(f"Icon exported successfully to:")
    print(f" - {out_app_icon}")
    print(f" - {out_color4}")


if __name__ == "__main__":
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    assets_dir = os.path.join(project_root, "assets")
    generate_app_icon(assets_dir)
