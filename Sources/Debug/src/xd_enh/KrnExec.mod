
<* Storage+ *>
(* ����㧪�, �ᯮ������, ��⠭���, ०��� �ᯮ������, ��. *)
(* ����� ����� ���� ��騬 ��� ��� �஥�⮢ ��⥬�      *)
(* �ᯮ������ ������ �१ ����䥩� �ᯮ���⥫�        *)

IMPLEMENTATION MODULE KrnExec;

IMPORT sys := SYSTEM;
IMPORT fmt := FormStr;

IMPORT kt  := KrnTypes;
IMPORT kpr := Krn_Prog;
IMPORT dbg := Krn_Dbg;

IMPORT trd := Threads;

IMPORT mem := Exe_Mem;
IMPORT exe := ExeMain;
IMPORT erc := ExeReact;

IMPORT dri := DI_Read;
IMPORT dt  := DI_Types;
IMPORT tls := DI_Tools;
IMPORT bld := DI_Build;

IMPORT msg := MsgNo;
IMPORT opt := Options;
IMPORT xs  := xStr;
IMPORT fil := File;

IMPORT xi  := xdRTS;

<* IF TARGET_OS = "WINNT" THEN *>

IMPORT win := Windows;

TYPE
  MAPSTRUCT = RECORD
                lpFile  : win.PVOID;
                hMapFile: win.HANDLE;
                raw     : dt.RAW_DEBUG_INFO;
              END;
 <* END *>


CONST
  NoMainEntryPoint = MAX(CARDINAL);
  NoStartupEntryPoint = MAX(CARDINAL);


(* ����㧨�� �ணࠬ�� *)
PROCEDURE LoadProgram (name-: ARRAY OF CHAR; args-: ARRAY OF CHAR): CARDINAL;


 <* IF TARGET_x86 THEN *>

  CONST
    MAIN_ENTRY            = "main";
    MAIN_ENTRY_PREFIX     = "_main";
    MAIN_ENTRY_SUFFIX     = "main_";



  PROCEDURE find_program_main_entry (VAR entry: kt.ADDRESS): BOOLEAN;
  BEGIN
    RETURN tls.FindPublicByNameInCom (0, MAIN_ENTRY        , entry) OR
           tls.FindPublicByNameInCom (0, MAIN_ENTRY_PREFIX , entry) OR
           tls.FindPublicByNameInCom (0, MAIN_ENTRY_SUFFIX , entry);
  END find_program_main_entry;

 <* END *>


VAR
  rc: CARDINAL;

BEGIN
  Loaded := FALSE;
  ProgramContextOk := FALSE;

  rc := kpr.StartProgram (name, args);
  IF rc # 0 THEN
    RETURN rc;
  END;
  IF NOT kpr.GetProgramInfo (ProgInfo) THEN
    RETURN msg.ErrorGetProgramInfo;
  END;

  ProgramContextOk := TRUE;

  mem.GetCaches();

  xi.DestroyXDInterfaces ();

  exe.ProcessEvents ();
  exe.TurnStepModeOff;
  exe.WasBreakpoint := 0;

  dbg.StartSmartSelector;

 <* IF TARGET_x86 THEN *>
  IF NOT find_program_main_entry (ProgInfo.MainEntry) THEN
    ProgInfo.MainEntry := NoMainEntryPoint;
  END;
 <* END *>

  exe.JumpToMainEntry := xi.XDInterfacePresent () OR ProgramMainEntryFound ();
  exe.JumpToProgramEntry := ProgramMainEntryFound ();
  exe.SkipToMain;

  Loaded := TRUE;

 <* IF DEFINED (xd_debug) & xd_debug THEN *>
  IF opt.Debug(opt.Load) THEN
    bld.ShowDebugStat();
  END;
 <* END *>

  RETURN msg.Ok;
END LoadProgram;


PROCEDURE UnloadProgram;
BEGIN
  trd.ClearThreads;
END UnloadProgram;


(* �ਮ�⠭����� �믮������ �ணࠬ�� �� �ॡ������ ���짮��⥫� *)
PROCEDURE StopByUserBreak;
BEGIN
END StopByUserBreak;


(* �६� �ᯮ������ �ணࠬ�� � ॠ�쭮� �६���, ��襤襣� � ��᫥����� *)
(* �맮�� �  mode = RESET.                                                *)
PROCEDURE Timer (mode: TIMER_MODE): LONGCARD;
BEGIN
  RETURN 0;
END Timer;


VAR
  SleepTicksMode: BOOLEAN;
  SleepTicks    : CARDINAL;

PROCEDURE Ticks(mode: TIMER_MODE): LONGCARD;
VAR
  ticks: LONGCARD;
BEGIN
  ticks := 0;
  CASE mode OF
  | RESET : ticks := 0;
--            ���稪����� := 0;
            SleepTicksMode := FALSE;
  | SHOW  : IF SleepTicksMode THEN
              ticks := SleepTicks;
            ELSE
              ticks := 0; -- := ���稪�����;
            END;
  | SLEEP : IF SleepTicksMode THEN
--              ���稪����� := SleepTicks;
            ELSE
              SleepTicksMode := TRUE;
              SleepTicks := 0; -- := ���稪�����;
            END;
--            ticks := ���稪�����;
  | WAKE  : IF SleepTicksMode THEN
              SleepTicksMode := FALSE;
--              ���稪����� := SleepTicks;
            END;
--            ticks := ���稪�����;
  END;
  RETURN ticks;
END Ticks;


(* ��।����� �� �窠 �室� � ���짮��⥫�᪨� ���? *)
PROCEDURE ProgramMainEntryFound (): BOOLEAN;
BEGIN
  RETURN ProgInfo.MainEntry # NoMainEntryPoint;
END ProgramMainEntryFound;

(* ��।����� �� �窠 �室� � �ணࠬ��? *)
PROCEDURE ProgramStartupEntryFound (): BOOLEAN;
BEGIN
  RETURN ProgInfo.StartupEntry # NoStartupEntryPoint;
END ProgramStartupEntryFound;



BEGIN
  opt.KernelInRemoteMode := FALSE;
  SleepTicksMode         := FALSE;
  SleepTicks             := 0;
  Loaded                 := FALSE;
  ProgramContextOk       := FALSE;
END KrnExec.
