IMPLEMENTATION MODULE Options;
(* ����� ��६�����, ��।������ ०�� ࠡ��� �⫠�稪� *)

<* IF DEST_XDS THEN *>

IMPORT Translit;

<* END *>



<* IF DEFINED (xd_debug) & xd_debug THEN *>

VAR
  Debug_Info : DEBUG_INFO;   (* �뤠���� �⫠����� ���ଠ�� *)


PROCEDURE DebugOn (d: DEBUG_MODE); (* ������� ०�� *)
BEGIN
  INCL(Debug_Info, d);
END DebugOn;


PROCEDURE Debug (d: DEBUG_MODE) : BOOLEAN; (* ����祭 �� ०��? *)
BEGIN
  RETURN d IN Debug_Info;
END Debug;

<* END *>

PROCEDURE SetXY (x, y: CARDINAL);
BEGIN
  X := x;
  Y := y;
END SetXY;


BEGIN
  DialogMode  := FALSE; (* �� 㬮�砭�� ������ ०�� *)
  tst_name    := '';
  prog_name   := '';
  prog_args   := '';
  Stop_Pack   := FALSE;
  in_dialog   := FALSE;
  name_only   := FALSE;
  Code        := FALSE;
  WarningBell := TRUE;
  SaveOpt     := FALSE;
  CodeHilight := TRUE;
  CallHilight := FALSE;
  WholeHex    := FALSE;
  KbdFile     := '';

  ShowAllModules := FALSE;
  InitDumpType   := 0;

  SetXY (0, 0);

(*
  JumpToMainEntry := TRUE;
  JumpToProgramEntry  := FALSE;
*)
  StopImmediately:= FALSE;
  SkipDisasm       := TRUE;

  ShowModuleWithoutSource  := TRUE; (* �����뢠�� ���㫨 ��� ��室���� ⥪�� *)
  DisplayDerefencePointer  := FALSE;
  CatchExceptInternalError := TRUE;
  UseSingleStructureWindow := TRUE;
  MergeEqualTypes          := FALSE;

<* IF DEST_K26 THEN *>

  DisasmMode           := FALSE;
  ConvertVar2Ref       := FALSE;   (* �।�⠢����� ��६����� ��� ��뫪� (�. Expr.def) *)
  TableModel           := FALSE;
  TraceRegisters       := TRUE;
  IgnoreWriteProtected := FALSE;

<* ELSIF DEST_XDS THEN *>

  DisasmMode     := TRUE;
  ConvertVar2Ref := FALSE;

  ExceptionOnFirstChance := TRUE;
  ShowSoftwareException  := TRUE;
  SSS_Delay              := 500;
  CorrectObjectName      := TRUE;

  StripPathFromFullName    := FALSE;
  StripPathFromPartialName := FALSE;
  TranslirateTextFromTo    := Translit.nn; -- no transliterate

  RemoteMode      := FALSE;
  RemoteHost      := '';
  RemotePort      := 0;
  RemoteTransport := '';

  IgnoreWriteProtected := TRUE;
  KernelInRemoteMode   := FALSE;
  AutoDetectActualType := TRUE; (* ��।����� �����騩 ⨯ ��쥪⮢      *)

<* END *>


<* IF DEFINED (xd_debug) & xd_debug THEN *>
  Debug_Info := DEBUG_INFO {};
<* END *>

END Options.
