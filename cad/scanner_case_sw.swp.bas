' ============================================================
' Pantree Scanner Enclosure — SolidWorks Parametric Generation Macro (VBA)
'
' Uses the SolidWorks modeling kernel (Modeler/Parasolid) temporary bodies with
' boolean operations to directly generate 4 solid parts. Geometry matches
' cad/scanner_case_gen.py (FreeCAD) exactly.
'
' Usage:
'   1. Open SolidWorks (no need to create a document first).
'   2. Menu Tools -> Macro -> New..., save with any .swp filename; the VBA editor opens.
'   3. Paste this entire file over the default module, or File -> Import File... to import this .bas.
'   4. Press F5 to run main.
'   5. Four new part documents appear in sequence: Base / Lid / CameraTower / Tray.
'      Ctrl+S each one to save as .SLDPRT.
'
' Coordinate convention: XY centered on origin, Z=0 is the box floor, units mm
'   (SolidWorks API is internally in meters; M() below handles mm->m conversion).
'   All dimensions come from the finalized values in CASE_MEASUREMENTS.md.
'
' Note: boolean operation codes SWBODYADD=15903 / SWBODYCUT=15902 (not 0/1/2).
' ============================================================
Option Explicit

' ---------- Boolean operation types (swBodyOperationType_e) ----------
Private Const SWBODYADD As Long = 15903
Private Const SWBODYCUT As Long = 15902

' ---------- Default part template preference (swUserPreferenceStringValue_e) ----------
Private Const swDefaultTemplatePart As Long = 8

' ============================================================
' Parameters (change dimensions here, units mm)
' ============================================================
' --- Enclosure main body ---
Private Const OUT_X As Double = 220#
Private Const OUT_Y As Double = 120#
Private Const OUT_Z As Double = 40#
Private Const WALL As Double = 3#          ' Side wall thickness
Private Const FLOOR As Double = 3#         ' Floor thickness
Private Const LID_T As Double = 3#         ' Lid thickness (= paper feed bed)

' --- Raspberry Pi standoffs (hole spacing 58x49, M2.5 self-tapping) ---
Private Const PI_CX As Double = -30#
Private Const PI_CY As Double = -27.5
Private Const PI_HX As Double = 58#
Private Const PI_HY As Double = 49#
Private Const STAND_OD As Double = 6#      ' Standoff outer diameter
Private Const STAND_HOLE As Double = 2.2   ' Standoff inner hole (self-tapping)
Private Const STAND_H As Double = 5#       ' Standoff height (raised to clear solder joints)

' --- Button hole (Ø12.3, front wall) ---
Private Const BTN_D As Double = 12.3
Private Const BTN_X As Double = 70#
Private Const BTN_Z As Double = 20#

' --- Raspberry Pi port opening (left wall X=-110) ---
Private Const PORT_W As Double = 60#       ' Opening width (along Y)
Private Const PORT_H As Double = 16#       ' Opening height (along Z)
Private Const PORT_Z0 As Double = 9#       ' Opening bottom height above floor

' --- Paper feed bed (lid top) rails ---
Private Const CHAN As Double = 84#         ' Spacing between the two rails (receipt width 80+4)
Private Const RAIL_W As Double = 3#        ' Rail thickness
Private Const RAIL_H As Double = 6#        ' Rail height

' --- Camera tower ---
Private Const CAM_X As Double = 20#        ' Camera aim point (along X)
Private Const WORK_DIST As Double = 85#    ' Working distance from lens to bed
Private Const POST_W As Double = 12#
Private Const POST_D As Double = 12#
Private Const Y_POST As Double = 52#       ' Post positions in Y (±)
Private Const BAR_T As Double = 12#        ' Top crossbar thickness
Private Const PLATE_T As Double = 5#       ' Camera mounting plate thickness
Private Const CAM_BX As Double = 25.6      ' Mounting recess
Private Const CAM_BY As Double = 24.3
Private Const CAM_RECESS As Double = 1.6   ' Recess depth
Private Const LENS_D As Double = 10#       ' Lens window
Private Const CAM_SX As Double = 21#       ' Screw hole spacing
Private Const CAM_SY As Double = 12.5
Private Const CAM_SCREW As Double = 1.8    ' Screw hole (M2 self-tapping)
Private Const LENS_OFFSET_Y As Double = 2.9 ' Lens offset relative to plate center in Y

' --- Storage tray ---
Private Const TRAY_X As Double = 90#
Private Const TRAY_Y As Double = 88#
Private Const TRAY_Z As Double = 40#
Private Const TRAY_WALL As Double = 2#
Private Const TRAY_GAP As Double = 10#     ' Gap from the main body's paper-exit end

' --- Paper-feed roller module (Stage 1) ---
Private Const ROLLER_DIA As Double = 20#   ' Drive roller diameter (matches firmware circumference 62.8)
Private Const ROLLER_LEN As Double = 90#   ' Roller length (> receipt width 80)
Private Const SHAFT_D As Double = 5#       ' NEMA17 D-shaft diameter
Private Const SHAFT_FLAT As Double = 2.1   ' D-shaft flat distance from center (with tolerance)
Private Const ORING_POS As Double = 30#    ' O-ring groove position (±Y, inside paper path)
Private Const ORING_W As Double = 2.4      ' Groove width
Private Const ORING_DEPTH As Double = 1.5  ' Groove depth
Private Const IDLER_DIA As Double = 16#    ' Idler roller outer diameter (plain tube, Ø8 bore)
Private Const BEARING_ID As Double = 8#    ' 608 inner diameter (idler / 8mm axle)
Private Const BRACKET_T As Double = 4#     ' Bracket plate thickness
Private Const BRACKET_H As Double = 45#    ' Bracket height
Private Const DRIVE_AXIS_Z As Double = 15# ' Drive roller axle height above bracket bottom

' ============================================================
' Globals
' ============================================================
Private swApp As Object
Private swModel As Object
Private swModeler As Object

' ============================================================
' Entry point
' ============================================================
Sub main()
    Set swApp = Application.SldWorks
    If swApp Is Nothing Then
        MsgBox "Cannot connect to SolidWorks.": Exit Sub
    End If

    BuildBase
    BuildLid
    BuildCameraTower
    BuildTray
    BuildDriveRoller
    BuildIdlerRoller
    BuildRollerBracket "RollerBracket_L"
    BuildRollerBracket "RollerBracket_R"

    MsgBox "Generation complete: Base / Lid / CameraTower / Tray" & vbCrLf & _
           "Paper feed: DriveRoller / IdlerRoller / RollerBracket_L,R" & vbCrLf & _
           "Please Ctrl+S each to save."
End Sub

' ============================================================
' Unit conversion: mm -> m
' ============================================================
Private Function M(ByVal mm As Double) As Double
    M = mm / 1000#
End Function

' ============================================================
' Temporary body factory
' ============================================================
' Box centered on (cx,cy) in XY, bottom face at z (extruded along +Z)
Private Function MakeBox(ByVal lx As Double, ByVal ly As Double, ByVal lz As Double, _
                         ByVal cx As Double, ByVal cy As Double, ByVal z As Double) As Object
    Dim d(8) As Double
    d(0) = M(cx): d(1) = M(cy): d(2) = M(z)   ' Bottom face center
    d(3) = 0#: d(4) = 0#: d(5) = 1#           ' Extrusion axis +Z
    d(6) = M(lx): d(7) = M(ly): d(8) = M(lz)  ' Width(X) Length(Y) Height(Z)
    ' Wrap in a Variant so late-bound marshaling passes a proper VT_R8 array
    ' (passing the typed array directly raises an Automation error).
    Dim vBox As Variant
    vBox = d
    Set MakeBox = swModeler.CreateBodyFromBox3((vBox))
End Function

' Box defined by min corner (x0,y0,z0) + dimensions (dx,dy,dz)
Private Function MakeBoxCorner(ByVal x0 As Double, ByVal y0 As Double, ByVal z0 As Double, _
                               ByVal dx As Double, ByVal dy As Double, ByVal dz As Double) As Object
    Set MakeBoxCorner = MakeBox(dx, dy, dz, x0 + dx / 2#, y0 + dy / 2#, z0)
End Function

' Vertical (+Z) cylinder, bottom face center (x,y,z)
Private Function MakeCyl(ByVal r As Double, ByVal h As Double, _
                         ByVal x As Double, ByVal y As Double, ByVal z As Double) As Object
    Set MakeCyl = MakeCylAxis(r, h, x, y, z, 0#, 0#, 1#)
End Function

' Arbitrary-axis cylinder, start face center (x,y,z), along unit vector (ax,ay,az)
Private Function MakeCylAxis(ByVal r As Double, ByVal h As Double, _
                             ByVal x As Double, ByVal y As Double, ByVal z As Double, _
                             ByVal ax As Double, ByVal ay As Double, ByVal az As Double) As Object
    Dim c(7) As Double
    c(0) = M(x): c(1) = M(y): c(2) = M(z)
    c(3) = ax: c(4) = ay: c(5) = az
    c(6) = M(r): c(7) = M(h)
    ' Wrap in a Variant so late-bound marshaling passes a proper VT_R8 array.
    Dim vCyl As Variant
    vCyl = c
    Set MakeCylAxis = swModeler.CreateBodyFromCyl((vCyl))
End Function

' ============================================================
' Boolean operations (two temporary bodies, returns result body;
' input bodies become invalid after the operation)
' ============================================================
Private Function BoolOp(ByRef a As Object, ByRef b As Object, ByVal opType As Long) As Object
    Dim errCode As Long, v As Variant
    v = a.Operations2(opType, b, errCode)
    If errCode <> 0 Then
        Err.Raise vbObjectError + 512, , "Boolean operation failed, error code=" & errCode
    End If
    If IsEmpty(v) Then
        Err.Raise vbObjectError + 513, , "Boolean operation returned no body (bodies may not overlap)."
    End If
    Set BoolOp = v(0)
End Function

Private Function Fuse(ByRef a As Object, ByRef b As Object) As Object
    Set Fuse = BoolOp(a, b, SWBODYADD)
End Function

Private Function Cut(ByRef a As Object, ByRef b As Object) As Object
    Set Cut = BoolOp(a, b, SWBODYCUT)
End Function

' ============================================================
' Create a new part document and acquire the modeler within its context.
' The modeler must be obtained while a document is active, otherwise
' GetModeler returns Nothing and CreateBodyFromBox3 raises error 91.
'
' Uses NewDocument with the configured default part template (NewPart is
' obsolete and can fail on newer SolidWorks releases).
' ============================================================
Private Sub StartPart()
    ' Lazy-init so the macro also works if a Build* sub is run directly (F5 with
    ' the cursor inside it), when main() has not run and swApp is still Nothing.
    If swApp Is Nothing Then Set swApp = Application.SldWorks
    If swApp Is Nothing Then
        Err.Raise vbObjectError + 513, , "Cannot connect to SolidWorks."
    End If

    Dim templatePath As String
    templatePath = swApp.GetUserPreferenceStringValue(swDefaultTemplatePart)
    If templatePath = "" Or Dir(templatePath) = "" Then
        Err.Raise vbObjectError + 514, , _
            "No default part template is configured." & vbCrLf & _
            "Set one in Tools > Options > System Options > Default Templates, then re-run."
    End If

    Set swModel = swApp.NewDocument(templatePath, 0, 0#, 0#)
    If swModel Is Nothing Then
        Err.Raise vbObjectError + 515, , "Could not create a new part document from: " & templatePath
    End If

    Set swModeler = swApp.GetModeler
    If swModeler Is Nothing Then
        Err.Raise vbObjectError + 516, , "Could not obtain the SolidWorks modeler."
    End If
End Sub

' ============================================================
' Insert the temporary body as a standalone solid feature into the current part document
' ============================================================
Private Sub CommitAsPart(ByRef body As Object, ByVal partName As String)
    Dim swPart As Object
    Set swPart = swModel
    Dim feat As Object
    Set feat = swPart.CreateFeatureFromBody3(body, False, 0)   ' 0 = no extra simplification
    If Not feat Is Nothing Then feat.Name = partName
    swModel.ClearSelection2 True
    swModel.EditRebuild3
    swModel.ViewZoomtofit2
End Sub

' ============================================================
' 1) Lower electronics chamber
' ============================================================
Private Sub BuildBase()
    StartPart
    Dim b As Object
    Set b = MakeBox(OUT_X, OUT_Y, OUT_Z, 0#, 0#, 0#)                       ' Enclosure
    Set b = Cut(b, MakeBox(OUT_X - 2 * WALL, OUT_Y - 2 * WALL, _
                           OUT_Z - FLOOR, 0#, 0#, FLOOR))                  ' Inner cavity (open top)

    ' Pi standoffs (4): start from Z=0 to ensure reliable fusion with the floor, self-tapping hole from FLOOR
    Dim sx As Variant, sy As Variant, post As Object
    For Each sx In Array(PI_CX - PI_HX / 2#, PI_CX + PI_HX / 2#)
        For Each sy In Array(PI_CY - PI_HY / 2#, PI_CY + PI_HY / 2#)
            Set post = MakeCyl(STAND_OD / 2#, STAND_H + FLOOR, CDbl(sx), CDbl(sy), 0#)
            Set post = Cut(post, MakeCyl(STAND_HOLE / 2#, STAND_H + 0.1, CDbl(sx), CDbl(sy), FLOOR))
            Set b = Fuse(b, post)
        Next
    Next

    ' Button hole (front wall Y=-OUT_Y/2, through along +Y)
    Set b = Cut(b, MakeCylAxis(BTN_D / 2#, WALL + 2#, BTN_X, -OUT_Y / 2# - 1#, BTN_Z, 0#, 1#, 0#))

    ' Raspberry Pi port opening (left wall X=-OUT_X/2)
    Set b = Cut(b, MakeBoxCorner(-OUT_X / 2# - 2#, PI_CY - PORT_W / 2#, PORT_Z0, _
                                 WALL + 4#, PORT_W, PORT_H))

    CommitAsPart b, "Base"
End Sub

' ============================================================
' 2) Paper feed bed lid
' ============================================================
Private Sub BuildLid()
    StartPart
    Dim b As Object
    Set b = MakeBox(OUT_X, OUT_Y, LID_T, 0#, 0#, OUT_Z)

    ' Two rails (start from lid bottom OUT_Z, spanning the lid thickness and rising RAIL_H, ensuring reliable fusion)
    Dim ry As Variant
    For Each ry In Array(-CHAN / 2#, CHAN / 2#)
        Set b = Fuse(b, MakeBox(OUT_X, RAIL_W, LID_T + RAIL_H, 0#, CDbl(ry), OUT_Z))
    Next

    ' Cable holes (two Ø10 on the rear side)
    Dim cx As Variant
    For Each cx In Array(-80#, 80#)
        Set b = Cut(b, MakeCyl(5#, LID_T + 2#, CDbl(cx), 50#, OUT_Z - 1#))
    Next

    ' Tower mounting screw holes
    Dim py As Variant
    For Each py In Array(-Y_POST, Y_POST)
        Set b = Cut(b, MakeCyl(1.7, LID_T + 2#, CAM_X, CDbl(py), OUT_Z - 1#))
    Next

    CommitAsPart b, "Lid"
End Sub

' ============================================================
' 3) Camera tower
' ============================================================
Private Sub BuildCameraTower()
    StartPart
    Dim bedTop As Double, camFace As Double, plateTop As Double
    Dim barZ0 As Double, barTop As Double, postH As Double
    bedTop = OUT_Z + LID_T           ' Bed height (=43)
    camFace = bedTop + WORK_DIST      ' Lens mounting face Z (=128)
    plateTop = camFace + PLATE_T
    barZ0 = plateTop
    barTop = barZ0 + BAR_T
    postH = barTop - bedTop           ' Post height

    Dim t As Object
    ' Build the top crossbar first (spans both post positions, ensuring subsequent fusion stays connected)
    Set t = MakeBox(POST_W + 2#, 2 * Y_POST + POST_D, BAR_T, CAM_X, 0#, barZ0)
    ' Two posts (their tops overlap the crossbar solidly over the BAR_T height)
    Dim py As Variant
    For Each py In Array(-Y_POST, Y_POST)
        Set t = Fuse(t, MakeBox(POST_W, POST_D, postH, CAM_X, CDbl(py), bedTop))
    Next
    ' Camera mounting plate (top extends 0.5 into the crossbar to ensure solid overlap for fusion)
    Set t = Fuse(t, MakeBox(44#, 44#, PLATE_T + 0.5, CAM_X, 0#, camFace))

    ' Camera recess (carved upward from the bottom face camFace)
    Set t = Cut(t, MakeBox(CAM_BX, CAM_BY, CAM_RECESS, CAM_X, LENS_OFFSET_Y, camFace))
    ' Lens window (through at aim point CAM_X,0)
    Set t = Cut(t, MakeCyl(LENS_D / 2#, PLATE_T + 2#, CAM_X, 0#, camFace - 1#))
    ' Camera screw holes (recess center)
    Dim dx As Variant, dy As Variant
    For Each dx In Array(-CAM_SX / 2#, CAM_SX / 2#)
        For Each dy In Array(-CAM_SY / 2#, CAM_SY / 2#)
            Set t = Cut(t, MakeCyl(CAM_SCREW / 2#, PLATE_T + 2#, _
                                   CAM_X + CDbl(dx), LENS_OFFSET_Y + CDbl(dy), camFace - 1#))
        Next
    Next

    CommitAsPart t, "CameraTower"
End Sub

' ============================================================
' 4) Storage tray
' ============================================================
Private Sub BuildTray()
    StartPart
    Dim tx As Double
    tx = OUT_X / 2# + TRAY_GAP + TRAY_X / 2#
    Dim b As Object
    Set b = MakeBox(TRAY_X, TRAY_Y, TRAY_Z, tx, 0#, 0#)
    Set b = Cut(b, MakeBox(TRAY_X - 2 * TRAY_WALL, TRAY_Y - 2 * TRAY_WALL, _
                           TRAY_Z - FLOOR, tx, 0#, FLOOR))
    CommitAsPart b, "Tray"
End Sub

' ============================================================
' 5) Drive roller (Ø20x90, axis +Y, 5mm D-bore + 2 O-ring grooves)
' ============================================================
Private Sub BuildDriveRoller()
    StartPart
    Dim r As Object
    ' Main roller cylinder, centered on origin, axis +Y
    Set r = MakeCylAxis(ROLLER_DIA / 2#, ROLLER_LEN, 0#, -ROLLER_LEN / 2#, 0#, 0#, 1#, 0#)

    ' D-shaped shaft bore (Ø5.2 cylinder with a flat cut at SHAFT_FLAT)
    Dim bore As Object
    Set bore = MakeCylAxis(SHAFT_D / 2# + 0.1, ROLLER_LEN + 2#, 0#, -ROLLER_LEN / 2# - 1#, 0#, 0#, 1#, 0#)
    Set bore = Cut(bore, MakeBoxCorner(SHAFT_FLAT, -ROLLER_LEN / 2# - 2#, -15#, 15#, ROLLER_LEN + 4#, 30#))
    Set r = Cut(r, bore)

    ' Two O-ring grooves at ±ORING_POS
    Dim gy As Variant, groove As Object
    For Each gy In Array(ORING_POS, -ORING_POS)
        Set groove = MakeCylAxis(ROLLER_DIA / 2# + 2#, ORING_W, 0#, CDbl(gy) - ORING_W / 2#, 0#, 0#, 1#, 0#)
        Set groove = Cut(groove, MakeCylAxis(ROLLER_DIA / 2# - ORING_DEPTH, ORING_W + 2#, _
                                             0#, CDbl(gy) - (ORING_W + 2#) / 2#, 0#, 0#, 1#, 0#))
        Set r = Cut(r, groove)
    Next

    CommitAsPart r, "DriveRoller"
End Sub

' ============================================================
' 6) Idler roller (Ø16x90 plain tube, Ø8 bore for 608 / 8mm axle)
' ============================================================
Private Sub BuildIdlerRoller()
    StartPart
    Dim r As Object
    Set r = MakeCylAxis(IDLER_DIA / 2#, ROLLER_LEN, 0#, -ROLLER_LEN / 2#, 0#, 0#, 1#, 0#)
    Set r = Cut(r, MakeCylAxis(BEARING_ID / 2# + 0.15, ROLLER_LEN + 2#, 0#, -ROLLER_LEN / 2# - 1#, 0#, 0#, 1#, 0#))
    CommitAsPart r, "IdlerRoller"
End Sub

' ============================================================
' 7) Roller bracket (drive axle hole + floating idler slot + spring post + feet)
'    L and R are geometrically identical.
' ============================================================
Private Sub BuildRollerBracket(ByVal nm As String)
    StartPart
    Dim b As Object
    ' Upright plate: X[-17,17], Y[-T/2,+T/2], Z[0,BRACKET_H]
    Set b = MakeBoxCorner(-17#, -BRACKET_T / 2#, 0#, 34#, BRACKET_T, BRACKET_H)
    ' Foot: X[-17,17], Y[T/2, T/2+18], Z[0,T]
    Set b = Fuse(b, MakeBoxCorner(-17#, BRACKET_T / 2#, 0#, 34#, 18#, BRACKET_T))

    ' Drive roller axle hole Ø8 (axis +Y) at Z=DRIVE_AXIS_Z
    Set b = Cut(b, MakeCylAxis(4#, BRACKET_T + 2#, 0#, -BRACKET_T / 2# - 1#, DRIVE_AXIS_Z, 0#, 1#, 0#))

    ' Idler floating slot (Ø8 wide vertical slot with rounded top, lets idler press down)
    Set b = Cut(b, MakeBoxCorner(-4#, -BRACKET_T / 2# - 1#, DRIVE_AXIS_Z + 6#, 8#, BRACKET_T + 2#, 14#))
    Set b = Cut(b, MakeCylAxis(4#, BRACKET_T + 2#, 0#, -BRACKET_T / 2# - 1#, DRIVE_AXIS_Z + 20#, 0#, 1#, 0#))

    ' Spring post hole Ø3
    Set b = Cut(b, MakeCylAxis(1.5, BRACKET_T + 2#, 0#, -BRACKET_T / 2# - 1#, BRACKET_H - 4#, 0#, 1#, 0#))

    ' Foot screw holes Ø3.2 (vertical, through the foot)
    Dim fx As Variant
    For Each fx In Array(-12#, 12#)
        Set b = Cut(b, MakeCylAxis(1.6, BRACKET_T + 4#, CDbl(fx), 10#, -1#, 0#, 0#, 1#))
    Next

    CommitAsPart b, nm
End Sub
