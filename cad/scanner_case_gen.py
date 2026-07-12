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

# --- 进纸滚轮模组 (Stage 1: 主动轮 + 压紧惰轮 + 支架 + 电机座) ---
ROLLER_DIA = 20.0     # 主动滚轮直径(匹配固件周长62.8 -> 步进准确)
ROLLER_LEN = 90.0     # 滚轮长(>票宽80)
SHAFT_D = 5.0         # NEMA17 D 轴直径
SHAFT_FLAT = 2.1      # D 轴平面距中心(含公差)
ORING_POS = 30.0      # O 型圈槽位置(±Y，在纸道内)
ORING_W = 2.4         # 槽宽
ORING_DEPTH = 1.5     # 槽深
IDLER_DIA = 16.0      # 压紧惰轮外径(素管，轴孔Ø8)
BEARING_ID = 8.0      # 608 内径(惰轮/惰轴用 8mm)
BRACKET_T = 4.0       # 支架板厚
BRACKET_H = 45.0      # 支架高
DRIVE_AXIS_Z = 15.0   # 主动轮轴离支架底高
NEMA_HOLE = 31.0      # NEMA17 螺孔方阵
NEMA_BORE = 23.0      # 中心让位
NEMA_SCREW = 3.2      # M3 孔
FEED_EXPL_Y = -160.0  # 爆炸展示位置(远离主体，仅方便查看/导出)

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

# ---------- 5) 进纸滚轮模组 (Stage 1) ----------
# 装配假设：主动轮一端直接装在电机 5mm D 轴上，另一端 Ø5 轴段入支架孔；
# 惰轮为 Ø16 素管套在 8mm 轴上，轴端可套 608 轴承后落入支架竖槽(浮动下压)。
def _cylY(r, length, x, z, yc):
    """轴沿 +Y 的圆柱，轴线过 (x, *, z)，在 Y 上以 yc 居中。"""
    return Part.makeCylinder(r, length, Vector(x, yc - length / 2.0, z), Vector(0, 1, 0))

# 5a. 主动滚轮：Ø20×90，5mm D 轴孔，2 道 O 型圈槽
_rx, _rz = -90.0, 20.0
roller = _cylY(ROLLER_DIA / 2.0, ROLLER_LEN, _rx, _rz, FEED_EXPL_Y)
_bore = _cylY(SHAFT_D / 2.0 + 0.1, ROLLER_LEN + 2.0, _rx, _rz, FEED_EXPL_Y)
_slab = Part.makeBox(15, ROLLER_LEN + 4, 30,
                     Vector(_rx + SHAFT_FLAT, FEED_EXPL_Y - ROLLER_LEN / 2.0 - 2, _rz - 15))
roller = roller.cut(_bore.cut(_slab))          # D 形轴孔
for _gy in (FEED_EXPL_Y + ORING_POS, FEED_EXPL_Y - ORING_POS):
    _outer = _cylY(ROLLER_DIA / 2.0 + 2.0, ORING_W, _rx, _rz, _gy)
    _inner = _cylY(ROLLER_DIA / 2.0 - ORING_DEPTH, ORING_W + 2.0, _rx, _rz, _gy)
    roller = roller.cut(_outer.cut(_inner))    # O 型圈槽
add(doc, "DriveRoller", roller)

# 5b. 压紧惰轮：Ø16 素管 + Ø8 轴孔(套 8mm 轴/608)
_ix = -40.0
idler = _cylY(IDLER_DIA / 2.0, ROLLER_LEN, _ix, _rz, FEED_EXPL_Y)
idler = idler.cut(_cylY(BEARING_ID / 2.0 + 0.15, ROLLER_LEN + 2.0, _ix, _rz, FEED_EXPL_Y))
add(doc, "IdlerRoller", idler)

# 5c. 滚轮支架(左右各一)：主动轮圆孔 + 惰轮浮动竖槽 + 弹簧挂孔 + 底脚螺孔
def _make_bracket():
    plate = Part.makeBox(34, BRACKET_T, BRACKET_H, Vector(-17, -BRACKET_T / 2.0, 0))
    foot = Part.makeBox(34, 18, BRACKET_T, Vector(-17, BRACKET_T / 2.0, 0))
    b = plate.fuse(foot)
    # 主动轮轴孔 Ø8
    b = b.cut(Part.makeCylinder(4.0, BRACKET_T + 2,
              Vector(0, -BRACKET_T / 2.0 - 1, DRIVE_AXIS_Z), Vector(0, 1, 0)))
    # 惰轮浮动竖槽(Ø8 宽，可上下浮动施压)
    b = b.cut(Part.makeBox(8, BRACKET_T + 2, 14,
              Vector(-4, -BRACKET_T / 2.0 - 1, DRIVE_AXIS_Z + 6)))
    b = b.cut(Part.makeCylinder(4.0, BRACKET_T + 2,
              Vector(0, -BRACKET_T / 2.0 - 1, DRIVE_AXIS_Z + 20), Vector(0, 1, 0)))
    # 弹簧挂柱孔
    b = b.cut(Part.makeCylinder(1.5, BRACKET_T + 2,
              Vector(0, -BRACKET_T / 2.0 - 1, BRACKET_H - 4), Vector(0, 1, 0)))
    # 底脚螺孔 Ø3.2(竖向穿脚，螺上盖板)
    for fx in (-12, 12):
        b = b.cut(Part.makeCylinder(1.6, BRACKET_T + 4, Vector(fx, 10, -1), Vector(0, 0, 1)))
    return b

_brk = _make_bracket()
_bL = _brk.copy(); _bL.translate(Vector(20, FEED_EXPL_Y - 60, 0))
_bR = _brk.copy(); _bR.translate(Vector(20, FEED_EXPL_Y + 60, 0))
add(doc, "RollerBracket_L", _bL)
add(doc, "RollerBracket_R", _bR)

# 5d. 电机座：NEMA17 面板(中心让位Ø23 + 4×M3) + 底脚(可换独立件)
MM_T = 4.0
_mp = Part.makeBox(50, MM_T, 50, Vector(-25, -MM_T / 2.0, 0))
_mf = Part.makeBox(50, 18, MM_T, Vector(-25, MM_T / 2.0, 0))
motor_mount = _mp.fuse(_mf)
motor_mount = motor_mount.cut(Part.makeCylinder(NEMA_BORE / 2.0, MM_T + 2,
                             Vector(0, -MM_T / 2.0 - 1, 25), Vector(0, 1, 0)))
for _dx in (-NEMA_HOLE / 2.0, NEMA_HOLE / 2.0):
    for _dz in (25 - NEMA_HOLE / 2.0, 25 + NEMA_HOLE / 2.0):
        motor_mount = motor_mount.cut(Part.makeCylinder(NEMA_SCREW / 2.0, MM_T + 2,
                                     Vector(_dx, -MM_T / 2.0 - 1, _dz), Vector(0, 1, 0)))
for _fx in (-18, 18):
    motor_mount = motor_mount.cut(Part.makeCylinder(1.6, MM_T + 4, Vector(_fx, 10, -1), Vector(0, 0, 1)))
motor_mount.translate(Vector(95, FEED_EXPL_Y, 0))
add(doc, "MotorMount", motor_mount)

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
print("       + 进纸模组：DriveRoller / IdlerRoller / RollerBracket_L,R / MotorMount")
print("台面高 Z=%.1f，镜头工作距离=%.1f mm，立柱高=%.1f mm" %
      (bed_top, WORK_DIST, post_h))
print("主动轮 Ø%.0f×%.0f(匹配固件周长62.8)，5mm D轴孔 + 2道O型圈槽" %
      (ROLLER_DIA, ROLLER_LEN))
print("导出STL：选中零件 → File → Export → STL")
