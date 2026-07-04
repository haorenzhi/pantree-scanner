# -*- coding: utf-8 -*-
"""
Pantree 扫描仪外壳 — 参数化生成脚本 (FreeCAD)

用法：
1. 打开 FreeCAD → 菜单 View → Panels → 勾选 "Python console"。
2. 把本文件全部内容复制，粘贴进 Python console，回车。
   （或：Macro → Macros... → 新建，把内容贴进去 → Execute）
3. 会生成 4 个零件：Base(下层舱)、Lid(走纸台盖)、CameraTower(摄像头立柱)、Tray(收纳盒)。
4. 改顶部 PARAMS 里的数值即可重新生成（先关掉旧文档或新建）。

坐标约定：XY 居中于原点，Z=0 是盒子底面，单位 mm。
所有尺寸来自 CASE_MEASUREMENTS.md 的实测+公差定稿值。
"""

import FreeCAD as App
import Part
from FreeCAD import Vector

# ============================================================
# 参数（要改尺寸就改这里）
# ============================================================
# --- 外壳主体 ---
OUT_X, OUT_Y, OUT_Z = 220.0, 120.0, 40.0   # 外形 长×宽×高
WALL = 3.0                                   # 侧壁厚
FLOOR = 3.0                                  # 底厚
LID_T = 3.0                                  # 盖板厚（=走纸台面）

# --- 树莓派螺柱（孔距 58×49，M2.5 自攻）---
PI_CX, PI_CY = -30.0, -27.5   # 派中心在舱内的位置
PI_HX, PI_HY = 58.0, 49.0     # 螺柱孔距
STAND_OD = 6.0                # 螺柱外径
STAND_HOLE = 2.2              # 螺柱内孔（自攻）
STAND_H = 5.0                 # 螺柱高（抬高躲焊点）

# --- 按钮孔（Ø12.3，前墙）---
BTN_D = 12.3
BTN_X = 70.0      # 沿 X 位置
BTN_Z = 20.0      # 离底高度

# --- 树莓派接口开口（左墙 X=-110）---
PORT_W, PORT_H = 60.0, 16.0   # 开口 宽(沿Y)×高(沿Z)
PORT_Z0 = 9.0                 # 开口底部离地高

# --- 走纸台（盖顶）导轨 ---
CHAN = 84.0       # 两导轨间距（票宽80+4）
RAIL_W = 3.0      # 导轨厚
RAIL_H = 6.0      # 导轨高

# --- 摄像头立柱 ---
CAM_X = 20.0          # 摄像头对准点（沿X）
WORK_DIST = 85.0      # 镜头到台面工作距离
POST_W, POST_D = 12.0, 12.0   # 立柱截面
Y_POST = 52.0         # 两立柱在 Y 的位置(±)，在84通道之外
BAR_T = 12.0          # 顶横梁厚
PLATE_T = 5.0         # 摄像头安装板厚
# 摄像头实测：板 25.6×24.3，镜头窗Ø10，孔距21×12.5，镜头距一短边9.0(不居中)
CAM_BX, CAM_BY = 25.6, 24.3   # 安装凹槽
CAM_RECESS = 1.6              # 凹槽深
LENS_D = 10.0                # 镜头窗
CAM_SX, CAM_SY = 21.0, 12.5  # 螺丝孔距
CAM_SCREW = 1.8              # 螺丝孔(M2自攻)
LENS_OFFSET_Y = 2.9          # 镜头相对板中心的Y偏移(11.9-9.0)

# --- 收纳盒 ---
TRAY_X, TRAY_Y, TRAY_Z = 90.0, 88.0, 40.0
TRAY_WALL = 2.0
TRAY_GAP = 10.0   # 与主体出纸端的间距

# ============================================================
# 辅助函数
# ============================================================
def box(lx, ly, lz, cx=0.0, cy=0.0, z=0.0):
    """XY 居中于 (cx,cy)，底面在 z 的长方体。"""
    return Part.makeBox(lx, ly, lz, Vector(cx - lx / 2.0, cy - ly / 2.0, z))

def vcyl(r, h, x=0.0, y=0.0, z=0.0):
    """竖直(+Z)圆柱。"""
    return Part.makeCylinder(r, h, Vector(x, y, z))

def add(doc, name, shape):
    obj = doc.addObject("Part::Feature", name)
    obj.Shape = shape
    return obj

# ============================================================
# 建模
# ============================================================
doc = App.newDocument("ScannerCase")

# ---------- 1) 下层电子舱 ----------
base = box(OUT_X, OUT_Y, OUT_Z)                                   # 外壳
cavity = box(OUT_X - 2 * WALL, OUT_Y - 2 * WALL, OUT_Z - FLOOR,   # 内腔(顶开口)
             0, 0, FLOOR)
base = base.cut(cavity)

# 派螺柱(4个)
for sx in (PI_CX - PI_HX / 2.0, PI_CX + PI_HX / 2.0):
    for sy in (PI_CY - PI_HY / 2.0, PI_CY + PI_HY / 2.0):
        post = vcyl(STAND_OD / 2.0, STAND_H, sx, sy, FLOOR)
        hole = vcyl(STAND_HOLE / 2.0, STAND_H + 0.1, sx, sy, FLOOR)
        base = base.fuse(post.cut(hole))

# 按钮孔(前墙 Y=-OUT_Y/2，沿+Y 穿透)
btn = Part.makeCylinder(BTN_D / 2.0, WALL + 2.0,
                        Vector(BTN_X, -OUT_Y / 2.0 - 1.0, BTN_Z), Vector(0, 1, 0))
base = base.cut(btn)

# 树莓派接口开口(左墙 X=-OUT_X/2)
port = Part.makeBox(WALL + 4.0, PORT_W, PORT_H,
                    Vector(-OUT_X / 2.0 - 2.0, PI_CY - PORT_W / 2.0, PORT_Z0))
base = base.cut(port)

add(doc, "Base", base)

# ---------- 2) 走纸台盖 ----------
bed_top = OUT_Z + LID_T          # 台面高度(=43)
lid = box(OUT_X, OUT_Y, LID_T, 0, 0, OUT_Z)

# 两条导轨
for ry in (-CHAN / 2.0, CHAN / 2.0):
    lid = lid.fuse(box(OUT_X, RAIL_W, RAIL_H, 0, ry, OUT_Z + LID_T))

# 走线孔(后侧两个 Ø10)
for cx in (-80.0, 80.0):
    lid = lid.cut(vcyl(5.0, LID_T + 2.0, cx, 50.0, OUT_Z - 1.0))

# 立柱固定螺丝孔
for py in (-Y_POST, Y_POST):
    lid = lid.cut(vcyl(1.7, LID_T + 2.0, CAM_X, py, OUT_Z - 1.0))

add(doc, "Lid", lid)

# ---------- 3) 摄像头立柱 ----------
cam_face = bed_top + WORK_DIST           # 镜头安装面 Z(=128)
plate_top = cam_face + PLATE_T
bar_z0 = plate_top
bar_top = bar_z0 + BAR_T
post_h = bar_top - bed_top               # 立柱高

tower = None
for py in (-Y_POST, Y_POST):             # 两立柱
    p = box(POST_W, POST_D, post_h, CAM_X, py, bed_top)
    tower = p if tower is None else tower.fuse(p)
# 顶横梁
tower = tower.fuse(box(POST_W + 2.0, 2 * Y_POST + POST_D, BAR_T, CAM_X, 0, bar_z0))
# 摄像头安装板
plate = box(44.0, 44.0, PLATE_T, CAM_X, 0, cam_face)
tower = tower.fuse(plate)

# 摄像头凹槽(从底面 cam_face 往上挖)
recess = box(CAM_BX, CAM_BY, CAM_RECESS, CAM_X, LENS_OFFSET_Y, cam_face)
tower = tower.cut(recess)
# 镜头窗(对准点 CAM_X,0 穿透)
tower = tower.cut(vcyl(LENS_D / 2.0, PLATE_T + 2.0, CAM_X, 0.0, cam_face - 1.0))
# 摄像头螺丝孔(板中心=凹槽中心)
for dx in (-CAM_SX / 2.0, CAM_SX / 2.0):
    for dy in (-CAM_SY / 2.0, CAM_SY / 2.0):
        tower = tower.cut(vcyl(CAM_SCREW / 2.0, PLATE_T + 2.0,
                               CAM_X + dx, LENS_OFFSET_Y + dy, cam_face - 1.0))

add(doc, "CameraTower", tower)

# ---------- 4) 收纳盒 ----------
tx = OUT_X / 2.0 + TRAY_GAP + TRAY_X / 2.0
tray = box(TRAY_X, TRAY_Y, TRAY_Z, tx, 0, 0)
tray = tray.cut(box(TRAY_X - 2 * TRAY_WALL, TRAY_Y - 2 * TRAY_WALL,
                    TRAY_Z - FLOOR, tx, 0, FLOOR))
add(doc, "Tray", tray)

# ============================================================
# 收尾
# ============================================================
doc.recompute()
try:
    import FreeCADGui as Gui
    Gui.activeDocument().activeView().viewAxonometric()
    Gui.SendMsgToActiveView("ViewFit")
except Exception:
    pass

print("生成完成：Base / Lid / CameraTower / Tray")
print("台面高 Z=%.1f，镜头工作距离=%.1f mm，立柱高=%.1f mm" %
      (bed_top, WORK_DIST, post_h))
print("导出STL：选中零件 → File → Export → STL")
