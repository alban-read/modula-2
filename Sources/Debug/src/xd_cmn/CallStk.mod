<* +storage *>

IMPLEMENTATION MODULE CallStk;

IMPORT sys := SYSTEM;
IMPORT fmt := FormStr;

IMPORT kt  := KrnTypes;
IMPORT dt  := DI_Types;
IMPORT tls := DI_Tools;

IMPORT xs  := xStr;
IMPORT opt := Options;

IMPORT nm  := Names;

<* IF DEST_XDS THEN *>
IMPORT stk := ScanStk;
<* END *>


TYPE
  PPROC_NAME = POINTER TO ARRAY OF CALL;

  PROC_CALL = RECORD
                top: CARDINAL;
                call: PPROC_NAME;
              END;
VAR
  ProcCall: PROC_CALL;


PROCEDURE GetCall (num: CARDINAL; VAR call: CALL);
BEGIN
  ASSERT(num < ProcCall.top);
  call := ProcCall.call^[num];
END GetCall;


PROCEDURE _PushCall(Addr: kt.ADDRESS; reverse: BOOLEAN; frame: CARDINAL);
CONST
  Q_CALL = 128;
VAR
  pos, i: CARDINAL;
  tmp : PPROC_NAME;
  name, com_name: xs.txt_ptr;
  pub_addr: kt.ADDRESS;
BEGIN
  WITH ProcCall DO
    IF call = NIL THEN
      NEW(call, Q_CALL);
      top := 0;
    ELSIF top >= HIGH(call^)+1 THEN
      NEW(tmp,HIGH(call^)+1+Q_CALL);
      ASSERT(tmp # NIL);
      sys.MOVE(sys.ADR(call^), sys.ADR(tmp^), SIZE(call^));
      DISPOSE(call);
      call := tmp;
    END;
    IF reverse THEN
      pos := 0;
      IF top >0 THEN
        FOR i := top-1 TO 0 BY -1 DO
          call^[i+1] := call^[i];
        END;
      END;
    ELSE
      pos := top;
    END;
    WITH call^[pos] DO
      call_addr := Addr;
      Frame := frame;
      Name := "";
      IF tls.FindModByAddr(Addr, com, mod) THEN
(* AVY: ᮢ��襭�� �� ����, ��祬 �� ����?
        �� �� �� ��뢠���� ��楤�� � ��᪮�, � ���� �맮��!
        <* IF TARGET_VAX THEN *>
        INC(Addr, 2);
        INC(call_addr, 2);
        <* END *>
*)
        IF -- NOT opt.CallHilight OR
           -- ���������७� AVY: �᫨ �⮣� �� ᤥ����, � �� ����祭��
           -- ��樨 CallHilight �� ���� �⮡ࠦ����� ��ப� � �맮���,
           -- ��᪮��� �⥪ �맮��� �� ���樠����஢�� �ࠢ��쭮
           -- (�� �� ������� �ᯮ������)
          NOT tls.SourceByAddrInMod (com, mod, Addr, line)
        THEN
          line := dt.Invalid_Line;
        END;
        Object := tls.FindProcByAddr (com, mod, Addr);
        IF tls.IsObjectValid(Object) THEN
          nm.ObjectNameGetAndCorrect (Object, Name);
        ELSE
          com := dt.Invalid_Component;
          mod := dt.Invalid_Module;
          IF tls.FindPublicByAddr(Addr, FALSE, com, name) THEN
            COPY (name^, Name);
          ELSE
            Name := "";
          END;
        END;
      ELSE
        Object := dt.Invalid_Object;
        line := dt.Invalid_Line;
        IF tls.FindPublicByAddr(Addr, FALSE, com, name) THEN
          ASSERT (tls.ComName (com, com_name));
          ASSERT (tls.FindPublicByNameInCom(com, name^, pub_addr));
          IF Addr > pub_addr THEN
            fmt.print (Name, '%s.%s+0%XH', com_name^, name^, Addr-pub_addr);
          ELSE
            fmt.print (Name, '%s.%s', com_name^, name^);
          END;
        ELSE
          Name := "";
        END;
      END;
    END;
    INC(top);
  END;
END _PushCall;

(* �������� �� ���� �஢��� �� �, �� �� ����᪥ �ணࠬ�� *)
(* �� �������, ��� ������ �ᯮ������� � ��蠣���� ०���        *)
PROCEDURE AddCall (Addr, frame: kt.ADDRESS);
BEGIN
  _PushCall(Addr, FALSE, frame);
END AddCall;


PROCEDURE GetFrame (level: CARDINAL; VAR frame: kt.ADDRESS): BOOLEAN;
BEGIN
  frame := INVALID_FRAME;
  WITH ProcCall DO
    IF level < top THEN
     <* IF DEST_XDS THEN *>
      frame := call^[level].Frame;
     <* ELSIF DEST_K26 THEN *>
      IF top-level > 0 THEN
        frame := call^[top-level-1].Frame;
      END;
     <* END *>
    END;
  END;
  RETURN frame # INVALID_FRAME;
END GetFrame;


PROCEDURE PopCall ();
BEGIN
  WITH ProcCall DO
    IF top > 0 THEN
      DEC(top);
    END;
  END;
END PopCall;


-- ��㡨�� �⥪� �맮���
PROCEDURE CallTop(): CARDINAL;
BEGIN
  RETURN ProcCall.top;
END CallTop;


VAR
  CallStackScanned: BOOLEAN;

(* ������ �������� �⥪� �맮��� *)
PROCEDURE ResetCallStack;
BEGIN
  ProcCall.top := 0;
  CallStackScanned := FALSE;
END ResetCallStack;


(* �஢����, �᫨ � �⥪� �맮��� ⠪�� �맮�, ����� *)
(* ᮮ⢥����� 㪠������ ��ப� ����� � ���������   *)
PROCEDURE IsLineInCallStack (c: dt.ComNo; m: dt.ModNo; l: dt.LineNo): BOOLEAN;
VAR
  i: CARDINAL;
BEGIN
  WITH ProcCall DO
    IF top # 0 THEN
      FOR i := 0 TO top-1 DO
        WITH call^[i] DO
          IF (com = c) AND (mod = m) AND (l = line) THEN
            RETURN TRUE;
          END;
        END;
      END;
    END;
  END;
  RETURN FALSE;
END IsLineInCallStack;

(* �஢����, �᫨ � �⥪� �맮��� ⠪�� �맮�, ����� *)
(* ᮮ⢥����� 㪠������� �����                      *)
PROCEDURE IsAddrInCallStack (addr: kt.ADDRESS): BOOLEAN;
VAR
  i: CARDINAL;
BEGIN
  WITH ProcCall DO
    IF top # 0 THEN
      FOR i := 0 TO top-1 DO
        IF call^[i].call_addr = addr THEN
          RETURN TRUE;
        END;
      END;
    END;
  END;
  RETURN FALSE;
END IsAddrInCallStack;


(* �஢����, �᫨ � �⥪� �맮��� ⠪�� �맮�, *)
(* ����� ᮮ⢥����� 㪠������� ��쥪��     *)
PROCEDURE GetObjectLevelInCallStack (first: CARDINAL; object: dt.OBJECT; VAR level: CARDINAL): BOOLEAN;
VAR
  i: CARDINAL;
BEGIN
  WITH ProcCall DO
    IF top # 0 THEN
      FOR i := first TO top-1 DO
       <* IF DEST_XDS THEN *>
        -- 1 - �⥪ �������� ᭨�� �����
        -- 2 - �� �����誥 �ᯮ����� ⥪�騩 ���⥪��
        IF tls.EqualObjects (call^[i].Object, object) THEN
       <* ELSIF DEST_K26 THEN *>
        -- 1 - �⥪ �������� ᢥ��� ����
        -- 2 - �� �����誥 �� 墠⠥� ⥪�饣� ���⥪��
        IF tls.EqualObjects (call^[top-i].Object, object) THEN
       <* END *>
          level := i;
          RETURN TRUE;
        END;
      END;
    END;
  END;
  RETURN FALSE;
END GetObjectLevelInCallStack;


<* IF DEST_XDS THEN *>

(* ���樠����஢��� �⥪ �맮��� *)
PROCEDURE ScanCallStack;
BEGIN
  IF NOT CallStackScanned THEN
    stk.ScanCallStack;
    CallStackScanned := TRUE;
  END;
END ScanCallStack;


PROCEDURE UnrollStack (num: CARDINAL; VAR addr: kt.ADDRESS; VAR obj: dt.OBJECT): BOOLEAN;
BEGIN
  WITH ProcCall DO
    IF top > num THEN
      WITH call^[num] DO
        addr := call_addr;
        obj := Object;
        RETURN TRUE;
      END;
    END;
  END;
  RETURN FALSE;
END UnrollStack;


PROCEDURE SkipProcWithoutDebugInfo (VAR addr: kt.ADDRESS; VAR obj: dt.OBJECT): BOOLEAN;
VAR
  p: CARDINAL;
BEGIN
  WITH ProcCall DO
    IF top > 0 THEN
     <* IF TARGET_VAX THEN *>
      FOR p := top-1 TO 0 DO
        WITH ProcCall.call^[p] DO
          IF tls.CheckDebugInfoForModule (com, mod) AND tls.ModHaveDebugInfo (com, mod) THEN
            addr := call_addr;
            obj := Object;
            RETURN TRUE;
          END;
        END;
      END;
     <* ELSIF TARGET_X86 THEN *>
      FOR p := 0 TO top-1 DO
        WITH ProcCall.call^[p] DO
          IF tls.CheckDebugInfoForModule (com, mod) AND tls.ModHaveDebugInfo (com, mod) THEN
            addr := call_addr;
            obj := Object;
            RETURN TRUE;
          END;
        END;
      END;
     <* END *>
    END;
  END;
  RETURN FALSE;
END SkipProcWithoutDebugInfo;


PROCEDURE GetFirstProc (VAR num: CARDINAL): BOOLEAN;
VAR
  p: CARDINAL;
BEGIN
  WITH ProcCall DO
    IF top > 0 THEN
     <* IF TARGET_VAX THEN *>
      FOR p := top-1 TO 0 DO
        WITH ProcCall.call^[p] DO
          IF tls.CheckDebugInfoForModule (com, mod) AND tls.ModHaveDebugInfo (com, mod) THEN
            num := p;
            RETURN TRUE;
          END;
        END;
      END;
     <* ELSIF TARGET_X86 THEN *>
      FOR p := 0 TO top-1 DO
        WITH ProcCall.call^[p] DO
          IF tls.CheckDebugInfoForModule (com, mod) AND tls.ModHaveDebugInfo (com, mod) THEN
            num := p;
            RETURN TRUE;
          END;
        END;
      END;
     <* END *>
    END;
  END;
  RETURN FALSE;
END GetFirstProc;


<* END *>


<* IF DEST_K26 THEN *>

PROCEDURE PushCall(call_point, frame: kt.ADDRESS);
BEGIN
  _PushCall(call_point, FALSE, frame);
END PushCall;


PROCEDURE SkipMM(): kt.ADDRESS;
VAR
  p: CARDINAL;
  str : xs.txt_ptr;
BEGIN
  p    := ProcCall.top-1;
  LOOP
    WITH ProcCall.call^[p] DO
      IF mod = dt.Invalid_Module THEN
        EXIT
      ELSE
        ASSERT(tls.ModName(com, mod, str));
        IF str^ # 'STORAGE' THEN
          EXIT
        END;
      END;
      IF p = 0 THEN EXIT END;
      DEC(p);
    END;
  END;
  RETURN ProcCall.call^[p].call_addr;
END SkipMM;

<* END *>

BEGIN
  ProcCall := PROC_CALL{0, NIL};
  CallStackScanned := FALSE;
END CallStk.
