' ============================================================
' Pantree Scanner Enclosure — SolidWorks PARAMETRIC (feature-tree) Macro (VBA)
'
' Unlike scanner_case_sw.swp.bas (which imports boolean solids with no editable
' tree), this version builds each part from SKETCHES + BOSS/CUT EXTRUDE features.
' Every sketch gets driving dimensions, so you can double-click a dimension in
' the FeatureManager tree (or a feature's depth) and edit sizes directly.
'
' Usage:
'   1. Open SolidWorks (a default Part template must be set — see StartPart).
'   2. Tools -> Macro -> New..., save a .swp; paste this whole file into the module.
'   3. Run "main" (put the cursor in Sub main, press F5).
'   4. Four new part documents are created: Base / Lid / CameraTower / Tray.
'      Ctrl+S each to save as .SLDPRT.
'
' To change a size later: open the part, expand the feature, double-click the
' sketch dimension (width/length/diameter) or the extrude depth, type a new value.
' To regenerate from scratch with new defaults, edit the Const block and re-run.
'
' Coordinate convention: XY centered on origin, Z=0 is the box floor, units mm
'   (SolidWorks API is meters; M() converts mm->m).
'
' NOTE: Feature-based modeling depends on plane orientation and cut direction.
'   Planes are selected language-independently (by order, not by name). If the
'   button hole ends up on the wrong side in Z, flip the sign of BTN_Z inside
'   CutButtonHole (see the comment there).
' ============================================================
Option Explicit

' ---------- swEndConditions_e / swStartConditions_e ----------
Private Const swEndCondBlind As Long = 0
Private Const swStartSketchPlane As Long = 0
Private Const swStartOffset As Long = 3

' ---------- swUserPreferenceStringValue_e ----------
Private Const swDefaultTemplatePart As Long = 8

' ============================================================
' Parameters (change dimensions here, units mm)
' ============================================================
' --- Enclosure main body ---
Private Const OUT_X As Double = 220#
Private Const OUT_Y As Double = 120#
Private Const OUT_Z As Double = 40#
Private Const WALL As Double = 3#
Private Const FLOOR As Double = 3#
Private Const LID_T As Double = 3#

' --- Raspberry Pi standoffs ---
Private Const PI_CX As Double = -30#
Private Const PI_CY As Double = -27.5
Private Const PI_HX As Double = 58#
Private Const PI_HY As Double = 49#
Private Const STAND_OD As Double = 6#
Private Const STAND_HOLE As Double = 2.2
Private Const STAND_H As Double = 5#

' --- Button hole ---
Private Const BTN_D As Double = 12.3
Private Const BTN_X As Double = 70#
Private Const BTN_Z As Double = 20#

' --- Raspberry Pi port opening ---
Private Const PORT_W As Double = 60#
Private Const PORT_H As Double = 16#
Private Const PORT_Z0 As Double = 9#

' --- Paper feed bed rails ---
Private Const CHAN As Double = 84#
Private Const RAIL_W As Double = 3#
Private Const RAIL_H As Double = 6#

' --- Camera tower ---
Private Const CAM_X As Double = 20#
Private Const WORK_DIST As Double = 85#
Private Const POST_W As Double = 12#
Private Const POST_D As Double = 12#
Private Const Y_POST As Double = 52#
Private Const BAR_T As Double = 12#
Private Const PLATE_T As Double = 5#
Private Const CAM_BX As Double = 25.6
Private Const CAM_BY As Double = 24.3
Private Const CAM_RECESS As Double = 1.6
Private Const LENS_D As Double = 10#
Private Const CAM_SX As Double = 21#
Private Const CAM_SY As Double = 12.5
Private Const CAM_SCREW As Double = 1.8
Private Const LENS_OFFSET_Y As Double = 2.9

' --- Storage tray ---
Private Const TRAY_X As Double = 90#
Private Const TRAY_Y As Double = 88#
Private Const TRAY_Z As Double = 40#
Private Const TRAY_WALL As Double = 2#
Private Const TRAY_GAP As Double = 10#

' ============================================================
' Globals
' ============================================================
Private swApp As Object
Private swModel As Object
Private swSketchMgr As Object
Private swFeatMgr As Object

' ============================================================
' Entry point
' ============================================================
Sub main()
    Set swApp = Application.SldWorks
    If swApp Is Nothing Then MsgBox "Cannot connect to SolidWorks.": Exit Sub

    BuildBase
    BuildLid
    BuildCameraTower
    BuildTray

    MsgBox "Parametric parts generated: Base / Lid / CameraTower / Tray" & vbCrLf & _
           "Double-click a sketch dimension or extrude depth to edit sizes." & vbCrLf & _
           "Please Ctrl+S each part to save."
End Sub

' ============================================================
' mm -> m
' ============================================================
Private Function M(ByVal mm As Double) As Double
    M = mm / 1000#
End Function

' ============================================================
' New part document + managers
' ============================================================
Private Sub StartPart()
    If swApp Is Nothing Then Set swApp = Application.SldWorks

    Dim templatePath As String
    templatePath = swApp.GetUserPreferenceStringValue(swDefaultTemplatePart)
    If templatePath = "" Or Dir(templatePath) = "" Then
        Err.Raise vbObjectError + 514, , _
            "No default part template is configured." & vbCrLf & _
            "Set one in Tools > Options > System Options > Default Templates, then re-run."
    End If

    Set swModel = swApp.NewDocument(templatePath, 0, 0#, 0#)
    If swModel Is Nothing Then Err.Raise vbObjectError + 515, , "Could not create a new part."
    Set swSketchMgr = swModel.SketchManager
    Set swFeatMgr = swModel.FeatureManager
End Sub

Private Sub FinishPart()
    swModel.ClearSelection2 True
    swModel.EditRebuild3
    swModel.ViewZoomtofit2
End Sub

' ============================================================
' Select a default reference plane by order (language independent).
'   idx: 0=Front, 1=Top, 2=Right
' ============================================================
Private Sub SelectPlane(ByVal idx As Long)
    Dim feat As Object, cnt As Long
    Set feat = swModel.FirstFeature
    cnt = 0
    Do While Not feat Is Nothing
        If feat.GetTypeName2 = "RefPlane" Then
            If cnt = idx Then
                swModel.ClearSelection2 True
                feat.Select2 False, 0
                Exit Sub
            End If
            cnt = cnt + 1
        End If
        Set feat = feat.GetNextFeature
    Loop
End Sub

Private Sub NewSketchOnFront()
    SelectPlane 0
    swSketchMgr.InsertSketch True
End Sub

' Select the sketch that was just closed (last feature in the tree)
Private Sub SelectLastSketch()
    Dim sk As Object
    Set sk = swModel.FeatureByPositionReverse(0)
    swModel.ClearSelection2 True
    sk.Select2 False, 0
End Sub

' ============================================================
' Sketch geometry + driving dimensions
' ============================================================
' Corner rectangle centered on (cx,cy), size lx x ly, with width+height dims
Private Sub DrawRectDims(ByVal cx As Double, ByVal cy As Double, _
                         ByVal lx As Double, ByVal ly As Double)
    Dim segs As Variant
    segs = swSketchMgr.CreateCornerRectangle(M(cx - lx / 2#), M(cy - ly / 2#), 0#, _
                                             M(cx + lx / 2#), M(cy + ly / 2#), 0#)
    On Error Resume Next
    swModel.ClearSelection2 True
    segs(0).Select4 False, Nothing                       ' a horizontal edge -> length dim
    swModel.AddDimension2 M(cx), M(cy - ly / 2# - 8#), 0#
    swModel.ClearSelection2 True
    segs(1).Select4 False, Nothing                       ' a vertical edge -> width dim
    swModel.AddDimension2 M(cx + lx / 2# + 8#), M(cy), 0#
    swModel.ClearSelection2 True
    On Error GoTo 0
End Sub

' Circle at (cx,cy) radius r, with a diameter/radius dim
Private Sub DrawCircleDim(ByVal cx As Double, ByVal cy As Double, ByVal r As Double)
    Dim seg As Object
    Set seg = swSketchMgr.CreateCircleByRadius(M(cx), M(cy), 0#, M(r))
    On Error Resume Next
    swModel.ClearSelection2 True
    seg.Select4 False, Nothing
    swModel.AddDimension2 M(cx + r + 5#), M(cy), 0#
    swModel.ClearSelection2 True
    On Error GoTo 0
End Sub

' ============================================================
' Feature builders (all on the Front plane, extruded/cut along Z)
' ============================================================
Private Function StartOffsetCond(ByVal z As Double) As Long
    If z = 0# Then StartOffsetCond = swStartSketchPlane Else StartOffsetCond = swStartOffset
End Function

' Boss box: XY-centered (cx,cy), bottom at z, size lx x ly x lz
Private Function BoxBoss(ByVal nm As String, ByVal cx As Double, ByVal cy As Double, ByVal z As Double, _
                         ByVal lx As Double, ByVal ly As Double, ByVal lz As Double, _
                         ByVal firstBody As Boolean) As Object
    NewSketchOnFront
    DrawRectDims cx, cy, lx, ly
    swSketchMgr.InsertSketch True
    SelectLastSketch
    Set BoxBoss = swFeatMgr.FeatureExtrusion3(True, False, False, _
        swEndCondBlind, 0, M(lz), 0#, False, False, False, False, 0#, 0#, _
        False, False, False, False, (Not firstBody), False, False, _
        StartOffsetCond(z), M(z), False)
    If nm <> "" And Not BoxBoss Is Nothing Then BoxBoss.Name = nm
End Function

' Boss cylinder: axis +Z, centered (cx,cy), bottom at z, radius r, height h
Private Function CylBoss(ByVal nm As String, ByVal cx As Double, ByVal cy As Double, ByVal z As Double, _
                         ByVal r As Double, ByVal h As Double, ByVal firstBody As Boolean) As Object
    NewSketchOnFront
    DrawCircleDim cx, cy, r
    swSketchMgr.InsertSketch True
    SelectLastSketch
    Set CylBoss = swFeatMgr.FeatureExtrusion3(True, False, False, _
        swEndCondBlind, 0, M(h), 0#, False, False, False, False, 0#, 0#, _
        False, False, False, False, (Not firstBody), False, False, _
        StartOffsetCond(z), M(z), False)
    If nm <> "" And Not CylBoss Is Nothing Then CylBoss.Name = nm
End Function

' Cut box (blind, along +Z): footprint centered (cx,cy), starts at z, depth lz
Private Function CutBox(ByVal nm As String, ByVal cx As Double, ByVal cy As Double, ByVal z As Double, _
                        ByVal lx As Double, ByVal ly As Double, ByVal lz As Double) As Object
    NewSketchOnFront
    DrawRectDims cx, cy, lx, ly
    swSketchMgr.InsertSketch True
    SelectLastSketch
    Set CutBox = swFeatMgr.FeatureCut4(True, False, True, _
        swEndCondBlind, 0, M(lz), 0#, False, False, False, False, 0#, 0#, _
        False, False, False, False, False, False, True, False, False, False, _
        StartOffsetCond(z), M(z), False, False)
    If nm <> "" And Not CutBox Is Nothing Then CutBox.Name = nm
End Function

' Cut cylinder (blind, along +Z): centered (cx,cy), starts at z, depth h
Private Function CutCyl(ByVal nm As String, ByVal cx As Double, ByVal cy As Double, ByVal z As Double, _
                        ByVal r As Double, ByVal h As Double) As Object
    NewSketchOnFront
    DrawCircleDim cx, cy, r
    swSketchMgr.InsertSketch True
    SelectLastSketch
    Set CutCyl = swFeatMgr.FeatureCut4(True, False, True, _
        swEndCondBlind, 0, M(h), 0#, False, False, False, False, 0#, 0#, _
        False, False, False, False, False, False, True, False, False, False, _
        StartOffsetCond(z), M(z), False, False)
    If nm <> "" And Not CutCyl Is Nothing Then CutCyl.Name = nm
End Function

' Button hole: round hole through the front wall, axis +Y (uses Top plane).
Private Function CutButtonHole() As Object
    SelectPlane 1                       ' Top plane (XZ), normal +Y
    swSketchMgr.InsertSketch True
    ' Top-plane sketch (x,y) maps to global (X, -Z); if it ends up mirrored in Z,
    ' change -BTN_Z below to +BTN_Z.
    DrawCircleDim BTN_X, -BTN_Z, BTN_D / 2#
    swSketchMgr.InsertSketch True
    SelectLastSketch
    ' Cut in the default (-Y) direction, from the sketch plane, through the wall.
    Set CutButtonHole = swFeatMgr.FeatureCut4(True, False, False, _
        swEndCondBlind, 0, M(OUT_Y / 2# + 1#), 0#, False, False, False, False, 0#, 0#, _
        False, False, False, False, False, False, True, False, False, False, _
        swStartSketchPlane, 0#, False, False)
    If Not CutButtonHole Is Nothing Then CutButtonHole.Name = "ButtonHole"
End Function

' ============================================================
' 1) Lower electronics chamber
' ============================================================
Private Sub BuildBase()
    StartPart

    BoxBoss "Enclosure", 0#, 0#, 0#, OUT_X, OUT_Y, OUT_Z, True
    CutBox "Cavity", 0#, 0#, FLOOR, OUT_X - 2 * WALL, OUT_Y - 2 * WALL, OUT_Z - FLOOR

    ' Pi standoffs (4): boss column from Z=0, blind self-tapping hole from FLOOR
    Dim sx As Variant, sy As Variant
    For Each sx In Array(PI_CX - PI_HX / 2#, PI_CX + PI_HX / 2#)
        For Each sy In Array(PI_CY - PI_HY / 2#, PI_CY + PI_HY / 2#)
            CylBoss "Standoff", CDbl(sx), CDbl(sy), 0#, STAND_OD / 2#, STAND_H + FLOOR, False
            CutCyl "StandoffHole", CDbl(sx), CDbl(sy), FLOOR, STAND_HOLE / 2#, STAND_H
        Next
    Next

    ' Button hole (front wall, along Y)
    CutButtonHole

    ' Raspberry Pi port opening (left wall) — an axis-aligned box, cut along Z
    Dim portCx As Double
    portCx = -OUT_X / 2# - 2# + (WALL + 4#) / 2#
    CutBox "Port", portCx, PI_CY, PORT_Z0, WALL + 4#, PORT_W, PORT_H

    FinishPart
End Sub

' ============================================================
' 2) Paper feed bed lid
' ============================================================
Private Sub BuildLid()
    StartPart

    BoxBoss "Lid", 0#, 0#, OUT_Z, OUT_X, OUT_Y, LID_T, True

    ' Two rails (span the lid thickness and rise RAIL_H so they merge cleanly)
    Dim ry As Variant
    For Each ry In Array(-CHAN / 2#, CHAN / 2#)
        BoxBoss "Rail", 0#, CDbl(ry), OUT_Z, OUT_X, RAIL_W, LID_T + RAIL_H, False
    Next

    ' Cable holes
    Dim cx As Variant
    For Each cx In Array(-80#, 80#)
        CutCyl "CableHole", CDbl(cx), 50#, OUT_Z - 1#, 5#, LID_T + 2#
    Next

    ' Tower mounting screw holes
    Dim py As Variant
    For Each py In Array(-Y_POST, Y_POST)
        CutCyl "TowerScrew", CAM_X, CDbl(py), OUT_Z - 1#, 1.7, LID_T + 2#
    Next

    FinishPart
End Sub

' ============================================================
' 3) Camera tower
' ============================================================
Private Sub BuildCameraTower()
    StartPart

    Dim bedTop As Double, camFace As Double, plateTop As Double
    Dim barZ0 As Double, barTop As Double, postH As Double
    bedTop = OUT_Z + LID_T
    camFace = bedTop + WORK_DIST
    plateTop = camFace + PLATE_T
    barZ0 = plateTop
    barTop = barZ0 + BAR_T
    postH = barTop - bedTop

    ' Crossbar first (spans both posts so everything merges connected)
    BoxBoss "Crossbar", CAM_X, 0#, barZ0, POST_W + 2#, 2 * Y_POST + POST_D, BAR_T, True

    ' Two posts
    Dim py As Variant
    For Each py In Array(-Y_POST, Y_POST)
        BoxBoss "Post", CAM_X, CDbl(py), bedTop, POST_W, POST_D, postH, False
    Next

    ' Camera mounting plate (top overlaps crossbar by 0.5 for a clean merge)
    BoxBoss "CameraPlate", CAM_X, 0#, camFace, 44#, 44#, PLATE_T + 0.5, False

    ' Camera recess (pocket carved upward from the bottom face)
    CutBox "CameraRecess", CAM_X, LENS_OFFSET_Y, camFace, CAM_BX, CAM_BY, CAM_RECESS
    ' Lens window
    CutCyl "LensWindow", CAM_X, 0#, camFace - 1#, LENS_D / 2#, PLATE_T + 2#
    ' Camera screw holes
    Dim dx As Variant, dy As Variant
    For Each dx In Array(-CAM_SX / 2#, CAM_SX / 2#)
        For Each dy In Array(-CAM_SY / 2#, CAM_SY / 2#)
            CutCyl "CamScrew", CAM_X + CDbl(dx), LENS_OFFSET_Y + CDbl(dy), camFace - 1#, _
                   CAM_SCREW / 2#, PLATE_T + 2#
        Next
    Next

    FinishPart
End Sub

' ============================================================
' 4) Storage tray
' ============================================================
Private Sub BuildTray()
    StartPart

    Dim tx As Double
    tx = OUT_X / 2# + TRAY_GAP + TRAY_X / 2#
    BoxBoss "Tray", tx, 0#, 0#, TRAY_X, TRAY_Y, TRAY_Z, True
    CutBox "TrayCavity", tx, 0#, FLOOR, TRAY_X - 2 * TRAY_WALL, TRAY_Y - 2 * TRAY_WALL, TRAY_Z - FLOOR

    FinishPart
End Sub
