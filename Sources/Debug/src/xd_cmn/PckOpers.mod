<* Storage+ *>

IMPLEMENTATION MODULE PckOpers;

IMPORT sys := SYSTEM;
IMPORT fmt := FormStr;
IMPORT str := Strings;
IMPORT tcn := TimeConv;
IMPORT com := COMPILER;
IMPORT pe  := ProgExec;

FROM Printf IMPORT printf;

IMPORT xs  := xStr;
IMPORT crt := CRT;
IMPORT opt := Options;
IMPORT pro := Protocol;
IMPORT msg := MsgNo;
IMPORT fil := File;
IMPORT err := Errors;
IMPORT key := Keys;
IMPORT txt := Texts;
IMPORT r2s := Real2Str;

IMPORT kex := KrnExec;
IMPORT kt  := KrnTypes;
IMPORT kpr := Krn_Prog;
IMPORT kda := Krn_Dasm;

IMPORT trd := Threads;

IMPORT brk := Breaks;
IMPORT stk := CallStk;

IMPORT exp := Expr;
IMPORT eve := Events;

IMPORT mem := Exe_Mem;
IMPORT exe := ExeMain;
IMPORT erc := ExeReact;

IMPORT dt  := DI_Types;
IMPORT tls := DI_Tools;

IMPORT lst := Lists;

IMPORT pt  := PckTypes;
IMPORT bas := PckBase;
IMPORT prc := PckReact;

IMPORT dm  := Dlg_Main;
IMPORT dw  := DlgWatch;
IMPORT dv  := Dlg_Vars;
IMPORT dmm := Dlg_Mem;
IMPORT dmd := DlgMods;
IMPORT dex := Dlg_Exec;

IMPORT xdt := XD_Title;
IMPORT xi  := xdRTS;

<* IF SCHERN_K26 THEN *>
IMPORT lpr := Lineprof,                                               (* CHERN *)
       asp := Asmprof,
              OctLog,
              LogIO,
       dit:=DI_Types,
              IntV_Mem,
       con:=  Convert,
       act := Dlg_Acts,
       ncr := Npo_Cri,
       iad := IntV_Adr,
       tpc := Time_prc,
       prv := Prf_Var;
IMPORT wsp := Windsave;                                               (* CHERN *)
<* END *>


<* IF DEST_K26 THEN *>

IMPORT mdl := Model;
IMPORT int := IntVMain;
IMPORT ime := IntV_Mem;

<* ELSIF DEST_XDS THEN *>

IMPORT thr := Threads;

<* END *>


CONST
  OperatorLength = 16;                                  (* ����� ������    *)


TYPE
  OPERATOR_NAME = ARRAY [0..OperatorLength] OF CHAR;  (* ��� ������      *)

  OPERATOR_NAMES = RECORD                              (* ������           *)
                     First : OPERATOR_NAME;
                     Second: OPERATOR_NAME;
                   END;

  OPERATOR = RECORD
               Hndl : OPERATOR_PROC;
               Names: OPERATOR_NAMES;
             END;

  PAOPERATOR = POINTER TO ARRAY OF OPERATOR;

  OPERATORS = RECORD
                Operators: PAOPERATOR;
                Count    : CARDINAL;
              END;


VAR
  Operators: OPERATORS;

  TestName : xs.String; (* ��� �������� *)

  Line  : xs.txt_ptr; (* ������� ������                 *)
  PosStr: CARDINAL;     (* ����� ������� ������� � ������ *)
  Param : xs.String;  (* ������� ��������               *)



(* ��।���� ����� ������ *)
PROCEDURE OperatorNumber (name-: ARRAY OF CHAR; VAR n: CARDINAL): BOOLEAN;
VAR
  i: CARDINAL;
BEGIN
  WITH Operators DO
    IF Count > 0 THEN
      FOR i := 0 TO Count-1 DO
        WITH Operators^[i].Names DO
          IF (name = First) OR (name = Second) THEN
            n := i+1;
            RETURN TRUE;
          END;
        END;
      END;
    END;
  END;
  RETURN FALSE;
END OperatorNumber;


PROCEDURE IsOperator (name-: ARRAY OF CHAR): BOOLEAN;
VAR
  n: CARDINAL;
BEGIN
  RETURN OperatorNumber(name, n);
END IsOperator;


(* ��२�������� ������ *)
PROCEDURE RenameOperator (old_name,new_name:ARRAY OF CHAR): BOOLEAN;
VAR
  i: CARDINAL;
BEGIN
  IF old_name = new_name THEN RETURN TRUE; END;
  IF NOT OperatorNumber(old_name, i) THEN RETURN FALSE; END;
  IF OperatorNumber(new_name, i) THEN RETURN FALSE; END;
  WITH Operators.Operators^[i-1].Names DO
    IF First = old_name THEN COPY(new_name, First); END;
    IF Second = old_name THEN COPY(new_name, Second); END;
  END;
  RETURN TRUE;
END RenameOperator;


PROCEDURE AddOperator (first-, second-: ARRAY OF CHAR; hndl: OPERATOR_PROC);
CONST
  HN_Operators = 32;
VAR
  tmp: PAOPERATOR;
BEGIN
  WITH Operators DO
    IF Operators = NIL THEN
      NEW(Operators, HN_Operators);
      ASSERT(Operators # NIL);
    ELSIF Count > HIGH(Operators^) THEN
      NEW(tmp, HIGH(Operators^)+1 + HN_Operators);
      ASSERT(tmp # NIL);
      sys.MOVE(sys.ADR(Operators^[0]), sys.ADR(tmp^[0]), (HIGH(Operators^)+1)*SIZE(OPERATOR));
      DISPOSE(Operators);
      Operators := tmp;
    END;
    WITH Operators^[Count] DO
      Hndl := hndl;
      WITH Names DO
        COPY(first, First);
        COPY(second, Second);
      END;
    END;
    INC(Count);
  END;
END AddOperator;




PROCEDURE GetCurrentPos(): CARDINAL;
BEGIN
  RETURN PosStr;
END GetCurrentPos;


PROCEDURE SkipBlanks (): BOOLEAN;
BEGIN
  RETURN bas.SkipBlanks(Line^, PosStr);
END SkipBlanks;


PROCEDURE GetParam (): BOOLEAN;
VAR
  res: exp.ExprRes;
  line: xs.txt_ptr;
BEGIN
  IF bas.GetParam (Line^, PosStr, Param) THEN
    IF Param[0] = '@' THEN
      exp.CalcExpr (pt.ActiveComponent, pt.ActiveModule, Param, res);
      IF (exp.error = 0) AND (res.sort = exp.STRINGval) THEN
        COPY(res.string, Param);
      END;
    ELSIF Param[0] = '"' THEN
      line := sys.ADR (Line^[PosStr-LENGTH(Param)]);
      exp.CalcExpr (pt.ActiveComponent, pt.ActiveModule, line^, res);
      IF (exp.error = 0) AND (res.sort = exp.STRINGval) THEN
        COPY ('"', Param);
        xs.Append (res.string, Param);
        xs.Append ('"', Param);
      END;
    END;
    RETURN TRUE;
  END;
  RETURN FALSE;
END GetParam;


PROCEDURE GetLastParam (): BOOLEAN;
VAR
  s: xs.String;
BEGIN
  COPY("", s);
  WHILE GetParam() DO
    xs.Append(' ', s);
    xs.Append(Param, s);
  END;
  COPY(s, Param);
  RETURN Param # "";
END GetLastParam;


PROCEDURE GetCurrentChar (VAR ch: CHAR): BOOLEAN;
BEGIN
  IF SkipBlanks() THEN
    RETURN FALSE;
  ELSE
    ch := Line^[PosStr];
    INC(PosStr);
    RETURN TRUE;
  END;
END GetCurrentChar;


PROCEDURE CheckCurrentChar (ch: CHAR): BOOLEAN;
VAR
  c: CHAR;
BEGIN
  IF GetCurrentChar(c) THEN
    RETURN c = ch;
  ELSE
    RETURN FALSE;
  END;
END CheckCurrentChar;


PROCEDURE SepParam (): BOOLEAN;
BEGIN
  RETURN CheckCurrentChar(pt.SepParam);
END SepParam;




(* �ᯮ����� ��ப�, �� ������ ᮤ�ঠ�� Line; RC - ��� ������ ������       *)
(* ��୥� TRUE - �᫨ ��ப� �ᯮ��﫠��, warning - �� ����稨 ��譨� ��ࠬ�஢ *)
PROCEDURE Execute (line-: ARRAY OF CHAR; VAR RC: CARDINAL; VAR warning: BOOLEAN): BOOLEAN;
VAR
  DoLine: BOOLEAN;
  before: CARDINAL;
  OperNo: CARDINAL;
BEGIN
  Line := sys.ADR(line);
  PosStr := 0;
  RC := 0;
  warning := FALSE;
  IF NOT bas.SkipBlanks(Line^,PosStr) THEN
    DoLine := TRUE;
    IF (PosStr = 0) THEN
      IF (Line^[0] = '#') THEN
        DoLine := FALSE;
      ELSE
        ASSERT(GetParam());
      END;
    END;
    DoLine := DoLine AND GetParam();
    IF DoLine THEN
      before := PosStr;
      IF OperatorNumber (Param, OperNo) THEN
        RC := Operators.Operators^[OperNo-1].Hndl();
        warning := (RC=0) AND (before#PosStr) AND SepParam();
      ELSE
        RETURN FALSE;
      END;
    END;
  END;
  RETURN TRUE;
END Execute;


PROCEDURE Assert () : CARDINAL;
VAR
  res  : BOOLEAN;
  paket: CARDINAL;
  line : CARDINAL;
BEGIN
  IF NOT GetParam() THEN RETURN msg.Expected_parameter; END;
  IF NOT exp.GetRelation (pt.ActiveComponent, pt.ActiveModule, Param, res) THEN RETURN msg.Incorrect_Expression; END;
  IF res THEN
    RETURN 0;
  ELSE
    IF bas.CheckMode (pt.GoSuccess) AND NOT lst.IsEmptyCall() THEN
      bas.ModeOff(pt.GoSuccess);
      WHILE lst.IsGOSUBCall() DO lst.PopCall(paket, line); END;
      lst.PopCall(paket, line);
      pt.CurrPaket := paket;
      pt.Pakets[pt.CurrPaket].LineNum := line;
      erc.CancelReact;
      eve.ClearQueue;
    ELSE
      err.FatalError;
    END;
    RETURN msg.Assert;
  END;
END Assert;


PROCEDURE Calls (): CARDINAL;
VAR
  str : xs.txt_ptr;
  call: stk.CALL;
  num : CARDINAL;
  N   : CARDINAL;
  buf : xs.String;
 <* IF DEST_K26 THEN *>
  name: xs.String;
  top : dt.OBJECT;
  IP  : kt.ADDRESS;
 <* END *>
BEGIN
  IF NOT kex.Loaded THEN RETURN msg.Load_must_be_first; END;
 <* IF DEST_XDS THEN *>
  stk.ScanCallStack;
 <* END *>
  N := stk.CallTop();
 <* IF DEST_K26 THEN *>
  INC(N);
 <* END *>
  IF N = 0 THEN
    pro.WriteMsg ("Empty calls stack", pro.to_screen, pro.to_file);
  ELSE
    FOR num := 0 TO N-1 DO
     <* IF DEST_XDS THEN *>
      stk.GetCall (num, call);
      WITH call DO
     <* ELSIF DEST_K26 THEN *>
      IF num = 0 THEN
        IP := mem.GetIP();
        top := tls.FindProcByAddr (pt.ActiveComponent, pt.ActiveModule, IP);
        IF tls.EqualObjects (top, dt.Invalid_Object) THEN
          fmt.print (buf, "%2d. A:%$8X", num+1, top);
        ELSE
          ASSERT(tls.ModName(pt.ActiveComponent, pt.ActiveModule, str));
          tls.ObjectName (top, name);
          fmt.print (buf, '%2d. %s.%s', num+1, str^, name);
        END;
      ELSE
      stk.GetCall (N-num-1, call);
      WITH call DO
     <* END *>
        IF Name # "" THEN
          IF (com # dt.Invalid_Component) AND (mod # dt.Invalid_Module) THEN
            ASSERT(tls.ModName(com, mod, str));
            fmt.print (buf, '%2d. %s.%s', num+1, str^, Name);
          ELSE
            fmt.print (buf, "%2d. %s", num+1, Name);
          END;
        ELSE
          fmt.print (buf, "%2d. A:%$8X", num+1, call_addr);
        END;
      END; -- WITH call ...
     <* IF DEST_K26 THEN *>
      END; -- IF num = 0 ...
     <* END *>
      pro.WriteMsg (buf, pro.to_screen, pro.to_file);
    END;
  END;
  RETURN 0;
END Calls;


PROCEDURE CallsForAllThreads (): CARDINAL;
VAR
  nThreads, t: CARDINAL;
  buf: xs.String;
  rc: CARDINAL;
BEGIN
  IF NOT kex.Loaded THEN RETURN msg.Load_must_be_first; END;
  nThreads := trd.NThreads ();
  FOR t := 0 TO nThreads-1 DO
    trd.GetThreadDescription (t, buf);
    pro.WriteMsg (buf, pro.to_screen, pro.to_file);
    IF thr.SwitchToThread (t) THEN
      mem.GetCaches;
      dmm.RefreshRegs;
      dex.ResetCallStack;
      rc := Calls ();
      pro.WriteMsg ("", pro.to_screen, pro.to_file);
      IF rc # 0 THEN
        err.Error (rc);
      END;                       
    ELSE
      pro.WriteMsg ("Cannot switch to the thread.\n", pro.to_screen, pro.to_file);
    END;
  END;
  RETURN 0; -- Ok
END CallsForAllThreads;

(* ����㧨�� �ணࠬ�� *)
PROCEDURE LoadProgram () : CARDINAL;
VAR
  ext: BOOLEAN;
  pos: CARDINAL;
  IP : kt.ADDRESS;
  com: dt.ComNo;
  mod: dt.ModNo;
BEGIN
  IF NOT GetParam() THEN RETURN msg.Expected_program_name; END;
  IF NOT exp.CheckFileName(Param, ext) THEN RETURN msg.Incorrect_prog_name; END;
  fil.AddExtension (Param, kt.prg_file_ext);
  COPY(Param, opt.prog_name);
  IF GetLastParam() THEN
    COPY(Param, opt.prog_args);
  ELSE
    opt.prog_args := '';
  END;

  IF kex.Loaded THEN
    dmm.ClearRegisters;
    brk.ClearBreaks;
    exe.UnloadProgram;
    tls.ClearComponents(TRUE);
    dmd.ClearModules;
    stk.ResetCallStack;
    dv.N_Call := 0;
  END;

  pos := kex.LoadProgram(opt.prog_name, opt.prog_args);
  IF pos = 0 THEN
    -- ��⠭����� ⥪�騥 ���������� � �����
    IP := mem.GetIP();
    IF tls.FindComponentByAddr (IP, com) THEN
      pt.ActiveComponent := com;
      IF tls.FindModInCompByAddr (com, IP, mod) THEN
        pt.ActiveModule := mod;
      END;
    END;
  ELSE
    err.FatalError;
  END;

  bas.ModeOff (pt.RestartDone);

  RETURN pos;
END LoadProgram;



(* ���室 �� ��⪥ � ����� *)
PROCEDURE Go_To_Label (VAR ok:BOOLEAN) : CARDINAL;
VAR
  paket, line : CARDINAL;
BEGIN
  IF NOT GetParam() THEN RETURN msg.Expected_label; END;
  IF NOT exp.CheckName(Param, TRUE) THEN RETURN msg.Incorrect_label; END;
  IF NOT lst.GetLabel(Param, paket, line) THEN
    err.Warning(msg.Label_not_found, Param);
    ok := FALSE;
  ELSE
    pt.CurrPaket := paket;
    pt.Pakets[pt.CurrPaket].LineNum := line;
    ok := TRUE;
  END;
  RETURN 0;
END Go_To_Label;


(* ���室 �� ��⪥ � ����� *)
PROCEDURE Goto () : CARDINAL;
VAR
  ok : BOOLEAN;
BEGIN
  RETURN Go_To_Label(ok);
END Goto;


(* �맮� ����ணࠬ� *)
PROCEDURE Gosub () : CARDINAL;
VAR
  ErrCode,
  paket  ,
  line   : CARDINAL;
  ok     : BOOLEAN;
BEGIN
  paket := pt.CurrPaket;
  line  := pt.Pakets[pt.CurrPaket].LineNum;
  ErrCode := Go_To_Label(ok);
  IF (ErrCode = 0) AND ok THEN lst.PushCall(paket,line,TRUE); END;
  RETURN ErrCode;
END Gosub;


(* ������ �� ����ணࠬ� *)
PROCEDURE Return () : CARDINAL;
VAR
  paket,
  line : CARDINAL;
BEGIN
  IF lst.IsEmptyCall() OR NOT lst.IsGOSUBCall() THEN
    RETURN msg.Return_without_Gosub;
  ELSE
    lst.PopCall(paket, line);
    pt.CurrPaket := paket;
    pt.Pakets[pt.CurrPaket].LineNum := line;
  END;
  RETURN 0;
END Return;


(* ���ࠢ����� �뢮�� ��⮪��� *)
PROCEDURE Dir () : CARDINAL;

  PROCEDURE ToScreen (s-:ARRAY OF CHAR) : BOOLEAN;
  VAR
    ch: CHAR;
  BEGIN
    ch := xs.UpChar(s[0]);
    IF ((ch='�') OR (ch='S')) AND (s[1] = 0C) THEN
      RETURN TRUE;
    ELSE
      RETURN FALSE;
    END;
  END ToScreen;

VAR
  ext  : BOOLEAN;
  pname: xs.txt_ptr;
  name : xs.String;
BEGIN
  IF NOT GetParam() THEN
    fil.ExtractFileName(opt.tst_name, Param);
    fil.RemoveExtension(Param);
  END;
  IF ToScreen(Param) THEN
    pro.to_screen := TRUE;
    pro.to_file   := FALSE
  ELSE
    IF NOT exp.CheckFileName(Param, ext) THEN RETURN msg.Incorrect_prot_name; END;
    IF NOT ext THEN fil.ChangeExtension(Param, kt.res_file_ext); END;
    pro.to_file := TRUE;
    pro.to_screen := FALSE;
    IF pro.Create(Param) THEN
      txt.GetName(pt.Pakets[pt.CurrPaket].Paket, pname);
      bas.FileName(pname^, name);
      pro.WriteMsgNo(msg.Paket, FALSE, TRUE, name);
    ELSE
      err.Warning(msg.Cant_open_protocol, Param);
    END;
  END;
  RETURN 0;
END Dir;


(* �����襭�� ࠡ��� �⫠�稪� *)
PROCEDURE End () : CARDINAL;
BEGIN
  opt.Stop_Pack := TRUE;
  IF kex.Loaded THEN
    dmm.ClearRegisters;
    brk.ClearBreaks;
    exe.UnloadProgram;
    tls.ClearComponents(TRUE);
    dmd.ClearModules;
    stk.ResetCallStack;
    dv.N_Call := 0;
  END;
  RETURN 0
END End;


(* ��㧠, �� ������ ������ ���� �� �६��� *)
PROCEDURE Pause () : CARDINAL;
VAR
  value: LONGCARD;
  msgno: CARDINAL;
BEGIN
  IF GetParam() THEN
    IF exp.GetCardValue (pt.ActiveComponent, pt.ActiveModule, Param, value) THEN
      IF value > MAX(CARDINAL) DIV 100 THEN RETURN msg.Incorrect_parameter; END;
    ELSE
      RETURN exp.error;
    END;
    msgno := msg.Pause;
  ELSE
    value := 60000;
    msgno := msg.Press_any_key;
  END;
  pro.WriteMsgNo(msgno, TRUE, FALSE, value);
  key.DelayUntilKeyPressed(VAL(CARDINAL,value) * 100);
  RETURN 0;
END Pause;


(* ������� ���������� ����: �����஢, ��ࠦ����, ��ப ���㫥� *)
PROCEDURE Equiv (): CARDINAL;
CONST
  MODE = exp.CHARSET { 'S', 'L', 'O' };

VAR
  Name : xs.String;
  ch   : CHAR;
  Addr : kt.ADDRESS;
  com  : CARDINAL;
  no   : CARDINAL;
  value: LONGCARD;

BEGIN
  IF NOT GetParam() THEN RETURN msg.Expected_equnamel; END;
  COPY(Param, Name); (* ������� ��� *)
  IF NOT (exp.CheckName(Name,TRUE) OR exp.CheckName(Name,FALSE)) THEN RETURN msg.Incorrect_equiv_name; END;
  IF SkipBlanks() THEN
    IF lst.IsEquName(Name) THEN
      lst.DelEquName(Name);
    ELSE
      err.Warning(msg.EquName_not_found,Name);
    END;
  ELSIF SepParam() THEN
    IF GetCurrentChar(ch) THEN
      IF (ch IN MODE) THEN
        IF NOT SepParam() THEN RETURN msg.Expected_separator; END;
        IF NOT GetParam() THEN RETURN msg.Expected_def_equnamel; END;
      END;
    ELSE
      RETURN msg.Expected_equ_type;
    END;
    Addr := 0;
    CASE ch OF
    | 'S': lst.PutEquName(Name, Param);
    | 'O': IF NOT RenameOperator(Name, Param) THEN RETURN msg.EquOperatorError; END;
    | 'L': IF NOT kex.Loaded THEN RETURN msg.Load_must_be_first; END;
           IF NOT tls.FindMod (Param, com, no) THEN RETURN msg.Module_not_found; END;
           IF NOT SepParam() THEN RETURN msg.Expected_separator; END;
           IF NOT GetParam() THEN RETURN msg.Expected_line; END;
           IF NOT exp.GetCardValue (pt.ActiveComponent, no, Param, value) THEN RETURN exp.error; END;
           IF NOT tls.AddrBySource (pt.ActiveComponent, no, value, Addr) THEN RETURN msg.Incorrect_address; END;
           fmt.print (Param, "0x%$8X", Addr);
           lst.PutEquName(Name, Param);
    END;
  END;
  RETURN 0;
END Equiv;


(* ���室 �� �訡�� *)
PROCEDURE JumpByError (): CARDINAL;
VAR
  Add   : BOOLEAN;
  number: LONGCARD;
  paket ,
  line  : CARDINAL;
  action: CHAR;
BEGIN
  IF NOT GetCurrentChar(action) THEN RETURN msg.Incorrect_error_act; END;
  CASE action OF
  | '-' : Add := FALSE;
  | '+' : Add := TRUE;
  ELSE
    RETURN msg.Incorrect_error_act;
  END;
  IF NOT GetParam() THEN RETURN msg.Expected_error_number; END;
  IF NOT exp.GetCardValue(pt.ActiveComponent, pt.ActiveModule, Param,number) THEN RETURN exp.error; END;
  IF Add THEN
    IF lst.GetJumpByError(number, paket, line) THEN err.Warning(msg.JumpErrAlreadyPresent, number); END;
    IF NOT SepParam() THEN RETURN msg.Expected_separator; END;
    IF NOT GetParam() THEN RETURN msg.Expected_label; END;
    IF NOT exp.CheckName(Param, TRUE) THEN RETURN msg.Incorrect_label; END;
    IF NOT lst.GetLabel(Param, paket, line) THEN RETURN msg.Label_not_found; END;
    lst.PutJumpByError(number, paket, line);
  ELSE
    IF NOT lst.GetJumpByError(VAL(CARDINAL,number), paket, line) THEN
      err.Warning(msg.JumpByErrorNotPresent, number);
    ELSE
      lst.DelJumpByError(number);
    END;
  END;
  RETURN 0;
END JumpByError;

(* �����襭�� �ᯮ������ �ணࠬ��, ������ �� �த������� ��ਠ�� *)
PROCEDURE GoBack (): CARDINAL;
VAR
  paket,
  line : CARDINAL;
BEGIN
  IF lst.IsEmptyCall() OR NOT bas.CheckMode(pt.GoSuccess) THEN
    RETURN msg.GOBackOn_without_GO;
  ELSE
    WHILE lst.IsGOSUBCall() DO lst.PopCall(paket,line); END;
    lst.PopCall(paket, line);
    pt.CurrPaket := paket;
    pt.Pakets[pt.CurrPaket].LineNum := line;
    bas.ModeOff(pt.GoSuccess);
    erc.CancelReact;
    eve.ClearQueue;
  END;
  RETURN 0;
END GoBack;


(* �맮� ����������� �⫠�稪� *)
PROCEDURE Dialog (): CARDINAL;

  MODULE SaveRestore;
  IMPORT pro, txt, opt;
  VAR
    file      ,
    screen    : BOOLEAN;
    FileEmpty ,
    NotFound  ,
    ReadError : txt.ErrorProc;
  BEGIN
    file          := pro.to_file;
    screen        := pro.to_screen;
    FileEmpty     := txt.FileEmpty;
    NotFound      := txt.NotFound;
    ReadError     := txt.ReadError;
    opt.in_dialog := TRUE;
  FINALLY
    pro.to_file   := file;
    pro.to_screen := screen;
    txt.FileEmpty := FileEmpty;
    txt.NotFound  := NotFound;
    txt.ReadError := ReadError;
    opt.in_dialog := FALSE;
  END SaveRestore;

BEGIN
  IF NOT kex.Loaded THEN RETURN msg.Load_must_be_first END;
  IF GetLastParam() THEN
    dm.StartFromPack (Param);
  ELSE
    dm.StartFromPack ("");
  END;
  RETURN 0;
END Dialog;



(* ������� ०���� ࠡ��� �⫠�稪� *)
PROCEDURE List () : CARDINAL;

VAR
  p    : CARDINAL;
  st1  : xs.String;
  found: BOOLEAN;

<* IF DEST_K26 THEN *>

  PROCEDURE Io (b: BOOLEAN) : BOOLEAN;
  VAR
    device,
    reg   : CARDINAL;
    i     : CARDINAL;
    ok    : BOOLEAN;
    N     : CARDINAL;
    DeviceName: xs.String;
    RegName   : xs.String;
  BEGIN
    IF found THEN
      IF (Param[p] # '(') THEN RETURN FALSE; END;
      INC(p);
      IF p = LENGTH(Param) THEN RETURN FALSE; END;
      xs.Extract(Param, p, LENGTH(Param)-p, st1);
      COPY(st1,Param);
      LOOP
        IF Param[LENGTH(Param)-1] =')' THEN
          xs.Extract(Param,0,LENGTH(Param)-1,st1);
        ELSE
          xs.Extract(Param,0,LENGTH(Param),st1);
        END;
        i := xs.CharPos(st1, '.', ok);
        IF ok THEN
          xs.Extract(st1, 0, i, DeviceName);
          IF NOT mdl.FindDeviceByName(DeviceName, device) THEN RETURN FALSE; END;
          xs.Extract(st1, i+1, LENGTH(st1), RegName);
          IF NOT mdl.FindByNameAddress(device, RegName, reg) THEN RETURN FALSE; END;
          IF b THEN mdl.EnablePortNotify(device, reg);
          ELSE      mdl.DisablePortNotify(device, reg);
          END;
        ELSE
          IF NOT mdl.FindDeviceByName(st1, device) THEN RETURN FALSE; END;
          N := mdl.QuantityRegs(device)-1;
          IF b THEN
            FOR i := 0 TO N DO mdl.EnablePortNotify(device, i); END;
          ELSE
            FOR i := 0 TO N DO mdl.DisablePortNotify(device, i); END;
          END;
        END;
        IF Param[LENGTH(Param)-1] =')' THEN EXIT; END;
        IF NOT SepParam() THEN RETURN FALSE; END;
        IF SkipBlanks() THEN RETURN FALSE; END;
        IF NOT GetParam() THEN RETURN FALSE; END;
      END;
    ELSE
      IF b THEN mdl.EnableAllPortNotify;
      ELSE      mdl.DisableAllPortNotify;
      END;
    END;
    RETURN TRUE;
  END Io;

<* END *>


VAR
  Mode  : pt.MODE_FLAGS;
  Ident : pt.IDENT;
  active: BOOLEAN;
  value : LONGCARD;

BEGIN
  LOOP
    IF NOT GetParam() THEN RETURN msg.Expected_mode; END;
    p := xs.CharPos(Param, '=', found);
    IF found THEN
      xs.Extract(Param, 0, p, st1);
    ELSE
      COPY(Param, st1);
    END;
    INC(p);
    IF bas.GetMode(st1, Mode, active) THEN
      CASE Mode OF
      | pt.Dump:
        bas.ShiftMode(Mode, active);
        opt.Code := active;

<* IF DEST_K26 THEN *>
      | pt.System:
        bas.ShiftMode(Mode, active);
        IF active THEN INCL(int.Mode, int.system); ELSE EXCL(int.Mode, int.system); END;

      | pt.Test:
        bas.ShiftMode(Mode, active);
        IF active THEN INCL(int.Mode, int.tests); ELSE EXCL(int.Mode, int.tests); END;

      | pt.Storage:
        IF NOT mdl.SetMemoryManager (active) THEN RETURN msg.CantSupportMemoryManager; END;

      | pt.IO:
        IF NOT bas.CheckMode(pt.KodSuccess) THEN RETURN msg.DeviceTableNotLoaded; END;
        IF NOT Io(active) THEN RETURN msg.Incorrect_parameter; END;

      | pt.DirectStart:
        bas.ShiftMode(Mode, active);
        IF active THEN INCL(int.Mode, int.start); ELSE EXCL(int.Mode, int.start); END;

<* END *>

      ELSE
        bas.ShiftMode(Mode, active);
      END;

    ELSIF bas.GetIdent(st1, Ident) THEN
      CASE Ident OF
      | pt.TraceCode:
        pt.TraceMode := pt.Code;
        bas.ShiftMode(pt.Trace, TRUE);
      | pt.TraceSource:
        pt.TraceMode := pt.Source;
        bas.ShiftMode(pt.Trace, TRUE);
      | pt.TraceMix:
        pt.TraceMode := pt.Mix;
        bas.ShiftMode(pt.Trace, TRUE);
      | pt.Error:
        IF NOT found THEN RETURN msg.Mode_incorrect; END;
        xs.Extract(Param, p, LENGTH(Param)-p, st1);
        IF NOT exp.GetCardValue(pt.ActiveComponent, pt.ActiveModule, st1, value) THEN RETURN msg.Incorrect_parameter; END;
        IF (value <= err.Max_Errors_limit) THEN
          err.Errors_limit := value;
        ELSE
          err.Warning(msg.ErrorsSetToMaxLimits, err.Max_Errors_limit);
          err.Errors_limit := err.Max_Errors_limit;
        END;
      | pt.Disasm:
        IF NOT found THEN RETURN msg.Mode_incorrect; END;
        xs.Extract(Param, p, LENGTH(Param)-p, st1);
        IF st1 = 'SMALL' THEN
          opt.DisasmMode := FALSE;
        ELSIF st1 = 'FULL' THEN
          opt.DisasmMode := TRUE;
        ELSE
          RETURN msg.Incorrect_parameter;
        END;
      END;
    ELSE
      RETURN msg.Incorrect_parameter;
    END;
    IF SkipBlanks() THEN EXIT; END;
    IF NOT SepParam() THEN RETURN msg.Expected_separator; END;
  END;
  RETURN 0;
END List;


VAR
  CurrentBreakNumber: CARDINAL;


(* ������� ��⠭���� *)
PROCEDURE Break (): CARDINAL;
CONST
  Exceptions = pt.SET_MODE_FLAGS { pt.OutMem, pt.WrProt, pt.ProgInt, pt.User };
  CallRet    = pt.SET_MODE_FLAGS { pt.Call, pt.Ret };
  CompBreaks = pt.SET_MODE_FLAGS { pt.CompCreated, pt.CompDestroyed };
  EmptyParam = Exceptions + CallRet + CompBreaks;


VAR
  BreakName   : xs.String;
  Event       : eve.EVENT_TYPE;
  event       : pt.MODE_FLAGS;
  BreakDesc   : pt.BREAK_DESCRIPTION;
  BP          : brk.BREAKPOINT;
  COND        : brk.CONDITION_BREAK;
  ACCESS      : brk.ACCESS_BREAK;
  PException  : prc.PEXCEPTION;
  PComp       : prc.PCOMP;
  preact      : erc.PREACTION;
  i           : CARDINAL;
  com         : CARDINAL;
  Module_No   : CARDINAL;
  ModuleLine  : CARDINAL;
  store_str   : xs.String;
  res         : exp.ExprRes;
 <* IF DEST_K26 THEN *>
  Call        : prc.CALL;
  PCall       : prc.PCALL;
  PReturn     : prc.PRETURN;
  Return      : prc.DRETURN;
  ok          : BOOLEAN;
  RegisterNo  : CARDINAL;
  DeviceName  : xs.String;
  RegName     : xs.String;
 <* END *>
 <* IF DEST_XDS THEN *>
  address     : kt.ADDRESS;
  start, end  : kt.ADDRESS;
  object      : dt.OBJECT;
  asm, info   : xs.String;
 <* END *>

BEGIN
  IF NOT kex.Loaded THEN RETURN msg.Load_must_be_first END;
  IF NOT GetParam() THEN RETURN msg.Expected_break_ident; END;
  IF NOT exp.CheckName (Param, TRUE) AND
     NOT exp.GetCardValue (0, 0, Param, BreakDesc.Number)
  THEN
    RETURN msg.Expected_break_ident;
  END;
  IF lst.GetBreakNumber (Param, BreakDesc.Number) THEN
    IF prc.FindBreak(BreakDesc.Number, Event, preact, i) THEN
      RETURN msg.Duplicate_ident_break;
    ELSE
      lst.DelBreak (Param);
    END;
  END;
  COPY(Param, BreakName);
  IF NOT SepParam() THEN
    RETURN msg.Expected_separator;
  END;
  IF NOT GetParam() THEN
    RETURN msg.Expected_break_type;
  END;
  IF NOT bas.GetBreakMode(Param, event) THEN
    RETURN msg.Incorrect_event;
  END;
  IF NOT SepParam() THEN
    RETURN msg.Expected_separator;
  END;
  IF NOT (event IN EmptyParam) THEN
    IF NOT GetParam() THEN
      RETURN msg.Expected_break_attr;
    END;
  END;
  BreakDesc.Number := CurrentBreakNumber;
  CASE event OF
  | pt.OutMem:
    IF prc.FindException(eve.OutOfMemory) THEN err.Warning(msg.Dublicate_reaction); END;

  | pt.WrProt:
    IF prc.FindException(eve.WriteProtected) THEN err.Warning(msg.Dublicate_reaction); END;

  | pt.ProgInt:
    IF prc.FindException(eve.ProgramException) THEN err.Warning(msg.Dublicate_reaction); END;

  | pt.User:
    IF prc.FindException(eve.UserException) THEN err.Warning(msg.Dublicate_reaction); END;

  | pt.Address:
    BP := brk.EmptyBREAKPOINT;
    IF NOT exp.GetAddress(pt.ActiveComponent, pt.ActiveModule, Param, BP.Addr) THEN RETURN msg.Incorrect_address; END;
    WITH brk.Breakpoints DO
      IF free # 0 THEN
        i := 0;
        LOOP
          WITH Breakpoints^[i] DO
            IF (Break.Owner=brk.Paket) AND (Addr=BP.Addr) THEN
              err.Warning(msg.Dublicate_reaction);
              EXIT;
            END;
          END;
          INC(i);
          IF i = free THEN EXIT; END;
        END;
      END;
    END;

  | pt.Line:
    IF pt.ActiveComponent = dt.Invalid_Component THEN
      IF NOT tls.FindMod (Param, com, Module_No) THEN RETURN msg.Module_not_found; END;
    ELSE
      IF NOT tls.FindModInComp (pt.ActiveComponent, Param, Module_No) THEN RETURN msg.Module_not_found; END;
      com := pt.ActiveComponent;
    END;
    IF NOT SepParam() THEN RETURN msg.Expected_separator; END;
    IF NOT GetParam() THEN RETURN msg.Expected_line; END;
    IF NOT exp.GetCardValue(com, Module_No, Param, ModuleLine) THEN RETURN msg.Incorrect_line; END;
    BP := brk.EmptyBREAKPOINT;
    IF NOT tls.AddrBySource(com, Module_No, ModuleLine, BP.Addr) THEN
      i := tls.LastLineHasCode (com, Module_No);
      LOOP
        INC(ModuleLine);
        IF ModuleLine > i THEN RETURN msg.Incorrect_line; END;
        IF tls.AddrBySource(com, Module_No, ModuleLine, BP.Addr) THEN
          err.Warning (msg.Incorrect_line_down, ModuleLine);
          EXIT;
        END;
      END;
    END;
    event := pt.Address;
    WITH brk.Breakpoints DO
      IF free # 0 THEN
        i := 0;
        LOOP
          WITH Breakpoints^[i] DO
            IF (Break.Owner=brk.Paket) AND (Addr=BP.Addr) THEN
              err.Warning(msg.Dublicate_reaction);
              EXIT;
            END;
          END;
          INC(i);
          IF i = free THEN EXIT; END;
        END;
      END;
    END;

  | pt.If:
    exp.CalcExpr(pt.ActiveComponent, pt.ActiveModule, Param, res);
    IF exp.error = 0 THEN
      IF res.sort # exp.BOOLval THEN
        RETURN msg.ExpectedBooleanValue;
      END;
    ELSIF NOT exp.dfn THEN
      pro.GetMsg(exp.error, store_str);
      err.Warning (msg.WrongExprInCurrentContext, store_str);
    ELSE
      RETURN exp.error;
    END;
    COPY(Param, store_str);

  | pt.Write, pt.Read:
    ACCESS := brk.EmptyACCESS_BREAK;
    WITH ACCESS DO
      CASE event OF
      | pt.Write : Access_Type := eve.Write;
      | pt.Read  : Access_Type := eve.Read;
      END;
     <* IF DEST_K26 THEN *>
      WITH Access_Data DO
        IF NOT exp.GetAddrOrReg(pt.ActiveComponent, pt.ActiveModule, Param, Location, RegisterNo) THEN RETURN exp.error; END;
        IF RegisterNo = MAX(CARDINAL) THEN
          Access_ID := brk.Memory;
          IF NOT SepParam() THEN RETURN msg.Expected_separator; END;
          IF GetParam() THEN
            IF NOT exp.GetCardValue(pt.ActiveComponent, pt.ActiveModule, Param, Len) OR (Len = 0)THEN RETURN msg.Incorrect_length; END;
          ELSE
            Len := 1;
          END;
        ELSE
          Access_ID := brk.Register;
          Reg_No    := RegisterNo;
        END;
      END;
     <* ELSE *>
      WITH Access_Data DO
        IF NOT exp.GetAddress(pt.ActiveComponent, pt.ActiveModule, Param, Location) THEN RETURN exp.error; END;
        Access_ID := brk.Memory;
        IF NOT SepParam() THEN RETURN msg.Expected_separator; END;
        IF GetParam() THEN
          IF NOT exp.GetCardValue (pt.ActiveComponent, pt.ActiveModule, Param, Len) THEN RETURN msg.Incorrect_length; END;
          IF (Len = 0) OR (Len > 4) THEN RETURN msg.Incorrect_length; END;
        ELSE
          Len := 1;
        END;
        IF (Location MOD Len) # 0 THEN
          IF Len = 2 THEN
            err.WarningStr("Watchpoint address must be aligned on word boundary.");
          ELSE
            err.WarningStr("Watchpoint address must be aligned on dword boundary.");
          END;
          RETURN msg.Impossible_Break;
        END;
      END;
     <* END *>
    END;
    IF prc.FindAccess(ACCESS) THEN err.Warning(msg.Dublicate_reaction); END;

  | pt.CompCreated, pt.CompDestroyed:
    IF GetParam() THEN
      COPY (Param, store_str);
    ELSE
      store_str := "";
    END;
    IF NOT SepParam() THEN
      RETURN msg.Expected_separator;
    END;

 <* IF DEST_XDS THEN *>
  | pt.Call:
    IF NOT GetParam() THEN RETURN msg.Expected_address; END;
    IF NOT exp.GetAddress  (pt.ActiveComponent, pt.ActiveModule, Param, address) THEN RETURN exp.error; END;
    IF NOT tls.FindModByAddr (address, com, Module_No) THEN RETURN msg.ObjectNotFound; END;
    object := tls.FindProcByAddr (com, Module_No, address);
    IF NOT tls.IsObjectValid (object) THEN RETURN msg.ObjectNotFound; END;
    IF NOT SepParam() THEN RETURN msg.Expected_separator; END;
    IF NOT GetParam() THEN
      COPY(pt.ProcedureParts[pt.Body], Param);
    END;
    ASSERT(tls.ObjectAddr(object, address));
    ASSERT(tls.ObjectSize(object, i));
    tls.ProcAttr(object, start, end);
    IF    Param = pt.ProcedureParts[pt.Prologue] THEN
      BP.Addr := address;
    ELSIF Param = pt.ProcedureParts[pt.Body] THEN
      BP.Addr := start;
    ELSIF Param = pt.ProcedureParts[pt.Epilogue] THEN
      BP.Addr := end;
    ELSIF Param = pt.ProcedureParts[pt.Return] THEN
       BP.Addr := end;
       INC(address, i);
       LOOP
         IF kda.IsRet (BP.Addr) THEN EXIT; END;
         IF NOT kda.Disasm (BP.Addr, FALSE, asm, info, i) THEN
           RETURN msg.Impossible_Break;
         END;
         INC(BP.Addr, i);
         IF BP.Addr >= address THEN
           RETURN msg.Impossible_Break;
         END;
       END;
    ELSE
      RETURN msg.Incorrect_parameter;
    END;
    event := pt.Address;
    WITH brk.Breakpoints DO
      IF free # 0 THEN
        i := 0;
        LOOP
          WITH Breakpoints^[i] DO
            IF (Break.Owner=brk.Paket) AND (Addr=BP.Addr) THEN
              err.Warning(msg.Dublicate_reaction);
              EXIT;
            END;
          END;
          INC(i);
          IF i = free THEN EXIT; END;
        END;
      END;
    END;

 <* END *>

 <* IF DEST_K26 THEN *>
  | pt.Call:
    IF GetParam() THEN
      IF NOT exp.GetAddress(pt.ActiveComponent, pt.ActiveModule, Param, Call.Address) THEN RETURN msg.Incorrect_address; END;
      Call.Exactly := TRUE;
    ELSE
      Call.Exactly := FALSE;
    END;
    IF NOT SepParam() THEN RETURN msg.Expected_separator; END;
    preact := erc.FirstReaction(eve.Call);
    LOOP
      preact := erc.FindReaction(preact, prc.Call);
      IF preact = NIL THEN EXIT; END;
      PCall := prc.PCALL(preact^.data);
      IF (PCall^.Exactly AND Call.Exactly AND (PCall^.Address = Call.Address))
         OR (NOT PCall^.Exactly AND NOT Call.Exactly) THEN
        err.Warning(msg.Dublicate_reaction);
        EXIT;
      END;
      preact := preact^.next;
    END;

  | pt.Ret:
    Return.Count := 0;

  | pt.IO:
    IF NOT bas.CheckMode(pt.KodSuccess) THEN RETURN msg.DeviceTableNotLoaded; END;
    WITH ACCESS DO
      Access_Type := eve.ReadWrite;
      WITH Access_Data DO
        Access_ID := brk.Port;
        i := xs.CharPos(Param, '.', ok);
        IF ok THEN
          xs.Extract(Param, 0, i, DeviceName);
          IF NOT mdl.FindDeviceByName(DeviceName, Dev_No) THEN
            RETURN msg.DeviceNotFound;
          END;
          xs.Extract(Param, i+1, LENGTH(Param), RegName);
          IF NOT mdl.FindByNameAddress(Dev_No, RegName, Port_No) THEN
            RETURN msg.AddressNotFound;
          END;
        ELSE
          IF NOT mdl.FindDeviceByName(Param, Dev_No) THEN
            RETURN msg.DeviceNotFound;
          END;
          Port_No := MAX(CARDINAL);
        END;
      END;
    END;
    IF prc.FindAccess(ACCESS) THEN err.Warning(msg.Dublicate_reaction); END;
 <* END *>

  END;
  IF NOT (event IN EmptyParam) THEN
    IF NOT SepParam() THEN RETURN msg.Expected_separator; END;
  END;
  IF NOT GetParam() THEN RETURN msg.Expected_label; END;
  IF event = pt.Address THEN
    IF Param = pt.Watchpoint THEN
      BP.Kind := brk.watchpoint;
    ELSIF Param = pt.Counter THEN
      BP.Kind := brk.counter;
    ELSE
      BP.Kind := brk.normal;
    END;
  END;
  IF (event # pt.Address) OR (BP.Kind = brk.normal) THEN
    IF NOT exp.CheckName(Param, TRUE) THEN RETURN msg.Incorrect_label; END;
    IF NOT lst.GetLabel(Param, BreakDesc.Paket_No, BreakDesc.Line_No) THEN RETURN msg.Label_not_found; END;
  ELSE
    -- watchpoints and counters do not need a label
    BreakDesc.Paket_No := MAX(CARDINAL);
    BreakDesc.Line_No  := MAX(CARDINAL);
  END;
  CASE event OF
  | pt.OutMem:
    NEW(PException);
    ASSERT(PException#NIL);
    PException^.Description  := BreakDesc;
    PException^.Exception_ID := eve.OutOfMemory;
    prc.SetExceptionReaction (erc.DATA(PException));

  | pt.WrProt :
    NEW(PException);
    ASSERT(PException#NIL);
    PException^.Description  := BreakDesc;
    PException^.Exception_ID := eve.WriteProtected;
    prc.SetExceptionReaction (erc.DATA(PException));

  | pt.ProgInt :
    NEW(PException);
    ASSERT(PException#NIL);
    PException^.Description  := BreakDesc;
    PException^.Exception_ID := eve.ProgramException;
    prc.SetExceptionReaction (erc.DATA(PException));

  | pt.User :
    NEW(PException);
    ASSERT(PException#NIL);
    PException^.Description  := BreakDesc;
    PException^.Exception_ID := eve.UserException;
    prc.SetExceptionReaction (erc.DATA(PException));

  | pt.Address:
    BP.Break.Pass := 0;
    BP.Break.Sticky := TRUE;
    BP.Condition := NIL;
    IF BP.Kind = brk.normal THEN
      LOOP
        IF SepParam() THEN
          IF NOT GetParam() THEN RETURN msg.Expected_break_attr; END;
          IF Param = pt.Condition THEN
            IF NOT SepParam() THEN RETURN msg.Expected_separator; END;
            IF NOT GetParam() THEN RETURN msg.Expected_break_attr; END;
            exp.CalcExpr(pt.ActiveComponent, pt.ActiveModule, Param, res);
            IF exp.error = 0 THEN
              IF res.sort # exp.BOOLval THEN
                RETURN msg.ExpectedBooleanValue;
              END;
            ELSIF NOT exp.dfn THEN
              pro.GetMsg(exp.error, store_str);
              err.Warning (msg.WrongExprInCurrentContext, store_str, Param);
            ELSE
              err.Warning (exp.error, Param);
            END;
            xs.alloc_from (BP.Condition, Param);
          ELSIF Param = pt.Delayed THEN
            BP.Break.Sticky := FALSE;
          ELSE
            IF NOT exp.GetCardValue (pt.ActiveComponent, pt.ActiveModule, Param, BP.Break.Pass) THEN
              err.Warning (exp.error);
            END;
          END;
        ELSE
          EXIT;
        END;
      END;
    END;
    WITH BP DO
      WITH Break DO
        Active := TRUE;
        Owner  := brk.Paket;
      END;
      Break.BreakDesc := BreakDesc;
      init_value := Break.Pass;
      IF NOT tls.SourceByAddr (Addr, Pos.ComN, Pos.ModN, Line) THEN
        Pos.ComN := 0;
        Pos.ModN := 0;
        Line  := 0;
      END;
    END;
    IF NOT brk.Add_Breakpoint(BP, FALSE, i) THEN RETURN msg.Impossible_Break; END;

 <* IF DEST_K26 THEN *>
  | pt.Call :
    NEW(PCall);
    ASSERT(PCall#NIL);
    Call.Description := BreakDesc;
    PCall^ := Call;
    erc.AddAction(eve.Call, erc.DATA(PCall), prc.Call);

  | pt.Ret :
    NEW(PReturn);
    ASSERT(PReturn#NIL);
    Return.Description := BreakDesc;
    PReturn^ := Return;
    erc.AddAction(eve.Call,   erc.DATA(PReturn), prc.Return);
    erc.AddAction(eve.Return, erc.DATA(PReturn), prc.Return);
 <* END *>

  | pt.If:
    COND := brk.EmptyCONDITION_BREAK;
    WITH COND DO
      WITH Break DO
        Active := TRUE;
        Sticky := TRUE;
        Pass   := 0;
        Owner  := brk.Paket;
      END;
      Break.BreakDesc := BreakDesc;
      xs.alloc_from(Expr, store_str);
    END;
    IF NOT brk.Add_ConditionBreak(COND) THEN RETURN msg.Impossible_Break; END;

  | pt.CompCreated, pt.CompDestroyed:
    NEW(PComp);
    ASSERT(PComp#NIL);
    PComp^.Description := BreakDesc;
    PComp^.Action := event;
    xs.Uppercase(store_str);
    COPY(store_str, PComp^.CompName);
    CASE event OF
    | pt.CompCreated:
      erc.AddAction (eve.CompCreated, erc.DATA(PComp), prc.CompProcessing);
    | pt.CompDestroyed:
      erc.InsActionFirst (eve.CompDestroyed, erc.DATA(PComp), prc.CompProcessing);
    END;

  | pt.IO, pt.Write, pt.Read:
    WITH ACCESS DO
      WITH Break DO
        Active := TRUE;
        Sticky := TRUE;
        Pass   := 0;
        Owner  := brk.Paket;
      END;
      Break.BreakDesc := BreakDesc;
      IF event = pt.Write THEN
       <* IF DEST_K26 THEN *>
        WITH Access_Data DO
          CASE Access_ID OF
          | brk.Memory:
            Prev_value_long := NIL;
            IF Len <= brk.PREV_VALUE_LENGTH THEN
              FOR i := 0 TO Len-1 DO
                IF NOT mem.Get(Location+i, sys.ADR(Prev_value[i]), 1) THEN
                  Prev_value[i] := 0;
                END;
              END;
            ELSE
              xs.alloc_str(Prev_value_long, Len);
              FOR i := 0 TO Len-1 DO
                IF NOT mem.Get(Location+i, sys.ADR(Prev_value_long^[i]), 1) THEN
                  Prev_value_long^[i] := 0C;
                END;
              END;
            END;
          | brk.Register:
            ASSERT(mem.GetReg(Reg_No, Prev_Reg_value));
          END;
        END;
       <* ELSE *>
        WITH Access_Data DO
          Prev_value_long := NIL;
          ASSERT( Access_ID = brk.Memory );
          IF NOT mem.Get(Location, sys.ADR(Prev_value[0]), Len) THEN
            Prev_value := brk.PREV_VALUE(VAL(CARDINAL, 0));
          END;
        END;
       <* END *>
      END;
    END;

   <* IF DEST_K26 THEN *>
    IF NOT brk.Add_AccessBreak(ACCESS) THEN
      IF event = pt.Write THEN
        WITH ACCESS.Access_Data DO
          IF (Access_ID = brk.Memory) AND (Len > brk.PREV_VALUE_LENGTH) THEN
            xs.dealloc_str(Prev_value_long);
          END;
        END;
      END;
      RETURN msg.Impossible_Break;
    END;
   <* ELSE *>
    IF NOT brk.Add_AccessBreak(ACCESS) THEN
      RETURN msg.Impossible_Break;
    ELSIF NOT ACCESS.Break.Active THEN
      err.Warning(msg.HardwareAccessBreakLimit);
    END;
   <* END *>
  END;
  lst.PutBreak (BreakName, BreakDesc.Number);
  INC(CurrentBreakNumber);
  RETURN 0;
END Break;


(* ������� ��⠭�� �� ������ *)
PROCEDURE Del(): CARDINAL;
VAR
  number: LONGCARD;
BEGIN
  LOOP
    IF NOT GetParam() THEN RETURN msg.Expected_break_ident; END;
    IF lst.GetBreakNumber (Param, number) THEN
      IF NOT prc.DelBreak(number) THEN
        lst.DelBreak (Param);
        err.Warning(msg.Cant_found_break, Param);
      END;
    ELSE
      err.Warning(msg.Cant_found_break, Param);
    END;
    IF SkipBlanks() THEN EXIT; END;
    IF NOT SepParam() THEN RETURN msg.Expected_separator; END;
  END;
  RETURN 0;
END Del;


(* ������ �᫮����� ���室� *)
PROCEDURE If (): CARDINAL;
VAR
  jump: BOOLEAN;
BEGIN
  IF NOT GetParam() THEN RETURN msg.Expected_expression; END;
  IF NOT exp.GetRelation(pt.ActiveComponent, pt.ActiveModule, Param, jump) THEN RETURN msg.Incorrect_Expression; END;

<* IF DEST_K26 THEN *>
  IF NOT SepParam() THEN RETURN(msg.Expected_separator); END;
<* ELSE *>

  IF NOT GetParam() THEN RETURN(msg.THEN_expected); END;
  IF Param # 'THEN' THEN RETURN(msg.THEN_expected); END;
  IF SkipBlanks() THEN RETURN msg.Expected_label; END;
<* END *>

  IF jump THEN RETURN Goto(); END;
  IF NOT GetParam() THEN RETURN msg.Expected_label; END;
  RETURN 0;
END If;



(* �������� ��ࠦ���� � ���� ᫥����� ��� ��ᬮ�� � ������� *)
PROCEDURE Watch (): CARDINAL;
VAR
  res : exp.ExprRes;
BEGIN
  LOOP
    IF NOT kex.Loaded THEN
      RETURN msg.Load_must_be_first;
    END;
    IF NOT GetParam() THEN
      RETURN msg.Expected_expression;
    END;
    exp.CalcExpr (pt.ActiveComponent, pt.ActiveModule, Param, res);
    IF (exp.error # 0) OR NOT exp.dfn THEN
      err.Warning (msg.WrongExprInCurrentContext, Param);
    END;
    dw.WatchFromPack (Param);
    IF SkipBlanks() THEN
      EXIT;
    END;
    IF NOT SepParam() THEN
      RETURN msg.Expected_separator;
    END;
  END;
  RETURN 0;
END Watch;


(* ��।������ ��⨢���� ����� *)
PROCEDURE SetActiveModule (): CARDINAL;
VAR
  com: dt.ComNo;
  mod: dt.ModNo;
  IP : kt.ADDRESS;
BEGIN
  IF NOT kex.Loaded THEN RETURN msg.Load_must_be_first; END;
  IF GetParam() THEN;
    IF tls.FindComponentByName (Param, com) THEN
      pt.ActiveComponent := com;
      IF SepParam() THEN
        IF NOT GetParam() THEN RETURN msg.ExpectedModuleName; END;
        IF NOT tls.FindModInComp (com, Param, mod) THEN RETURN msg.Module_not_found; END;
        pt.ActiveModule := mod;
      END;
    ELSIF tls.FindMod (Param, com, mod) THEN
      pt.ActiveComponent := com;
      pt.ActiveModule := mod;
    ELSE
      RETURN msg.Incorrect_parameter;
    END;
  ELSE
    -- ��⠭����� ⥪�騥 ���������� � �����
    IP := mem.GetIP();
    IF tls.FindComponentByAddr (IP, com) THEN
      pt.ActiveComponent := com;
      IF tls.FindModInCompByAddr (com, IP, mod) THEN
        pt.ActiveModule := mod;
      ELSE
        pt.ActiveModule := 1;
      END;
    ELSE
      pt.ActiveComponent := 0;
      pt.ActiveModule := 1;
    END;
  END;
  RETURN 0;
END SetActiveModule;



CONST
  FREE_FORMAT = 'n';

(* ������ �뢮�� ������ *)
PROCEDURE Put (): CARDINAL;

TYPE
  EMODIFICATOR = ( sp, alignment, left, sg, bs, center, asterisk, wdth, prc);

  SMODIFICATOR = SET OF EMODIFICATOR;

  CMODIFICATOR = ARRAY EMODIFICATOR OF CHAR;


CONST
  MODIFICATOR = CMODIFICATOR{" ","$","-","+","#","|","*","","."};

  BASE = exp.CHARSET{'m','i','d','u','x','o','b','f','e','g','c','s','w', FREE_FORMAT
                    ,'M'            ,'X'        ,'F','E','G'            , CAP(FREE_FORMAT) };



  PROCEDURE IsMemoryRegion (ch: CHAR): BOOLEAN;
  BEGIN
    RETURN CAP(ch) = 'M';
  END IsMemoryRegion;

CONST
  MaxLen = 72;

VAR
  stroka  : xs.String;  (* ��室��� ��ப� *)
  st, st1 : xs.String;
  st2, st3: xs.String;
  text    : xs.String;  (* ⥪�� ��� �뢮�� *)
  format  : xs.String;  (* �ଠ� *)
  len     : CARDINAL;   (* ����� stroka *)
  base    : CHAR;       (* ���� *)
  smodif  : SMODIFICATOR;
  width   : CARDINAL;
  precis  : CARDINAL;
  Addr    : kt.ADDRESS; (* ���� ��砫� ���� ��� ��६����� *)
  CurrAddr: kt.ADDRESS; (* ���� ��砫� ⥪�饣� ����� ���� *)
  LnPole  : CARDINAL;   (* ����� ���� �� 㪠����� L����⠭� *)
  LnElem  : CARDINAL;   (*����� ����� ����, ��������, ��������, K����⠭� *)


  PROCEDURE check_print;
  BEGIN
    IF LENGTH(text) > MaxLen THEN
      pro.WriteMsg(text,pro.to_screen,pro.to_file);
      text := '';
    END;
  END check_print;


  PROCEDURE get_max_length (ch:CHAR; l:CARDINAL) : CARDINAL;
  TYPE
    Len = ARRAY [1..4] OF CARDINAL;
  CONST
    d_len = Len{3,5,8,10};
    o_len = Len{3,6,8,11};
    b_len = Len{8,16,24,32};
  BEGIN
    CASE ch OF
    |'i','I','d','D' : RETURN d_len[l];
    |'h','H','x','X' : RETURN l*2;
    |'o','O'         : RETURN o_len[l];
    |'b','B'         : RETURN b_len[l];
    ELSE
    END;
    RETURN 0;
  END get_max_length;


  PROCEDURE do_align (len: CARDINAL; VAR s: ARRAY OF CHAR);
  VAR
    i, maxlen, strlen: CARDINAL;
  BEGIN
--    IF NOT (left IN smodif) THEN
      IF alignment IN smodif THEN
        strlen := LENGTH(s);
        maxlen := get_max_length (base, len);
        IF strlen < maxlen THEN
          FOR i := 1 TO maxlen-strlen DO
            xs.Insert ('0', 0, s);
          END;
        ELSE
          FOR i := 1 TO strlen-maxlen DO
            IF s[i-1] = '0' THEN
              s[i-1] := ' ';
            END;
          END;
        END;
      END;
--    END;
  END do_align;


  PROCEDURE expand_width (VAR s: ARRAY OF CHAR);
  VAR
    i, strlen: CARDINAL;
  BEGIN
    strlen := LENGTH(s);
    IF width > strlen THEN
      IF left IN smodif THEN
        FOR i := 1 TO width-strlen DO
          xs.Insert (' ', LENGTH(s), s);
        END;
      ELSE
        FOR i := 1 TO width-strlen DO
          xs.Insert (' ', 0, s);
        END;
      END;
    END;
  END expand_width;



  PROCEDURE get_format (stroka-:ARRAY OF CHAR; VAR i,i1:CARDINAL);
  VAR
    p, p1: CARDINAL;
    st : xs.String;
    ok : BOOLEAN;
    value : LONGCARD;

    PROCEDURE is_modif (ch: CHAR): BOOLEAN;
    VAR
      emodif: EMODIFICATOR;
    BEGIN
      FOR emodif := MIN(EMODIFICATOR) TO MAX(EMODIFICATOR) DO
        IF ch = MODIFICATOR[emodif] THEN
          INCL (smodif, emodif);
          RETURN TRUE;
        END;
      END;
      RETURN FALSE;
    END is_modif;

  BEGIN
    LOOP
      smodif := SMODIFICATOR {};
      width := 0;
      precis := 0;
      str.FindNext('%',stroka,i,ok,p);
      IF ok THEN
        INC(i,p-i);
      ELSE
        i := len;
      END;
      i1 := i;
      IF i = len THEN RETURN; END;
      IF stroka[i+1] = '%' THEN
        INC(i,2);
      ELSE
        INC(i);
        LOOP
          IF is_modif (stroka[i]) THEN
            INC(i);
          ELSIF stroka[i] IN exp.Digits THEN
            IF prc IN smodif THEN
              precis := precis * 10 + ORD(stroka[i]) - ORD('0');
            ELSE
              width := width * 10 + ORD(stroka[i]) - ORD('0');
              INCL (smodif, wdth);
            END;
            INC(i);
          ELSE
            EXIT;
          END;
        END;
        IF stroka[i] IN BASE THEN
          base := stroka[i];
          INC(i);
          IF NOT IsMemoryRegion(base) THEN
            xs.Extract(stroka,i1,i-i1,format);
            RETURN;
          ELSE
            IF (i=i1+2) AND (stroka[i] = "(") THEN
              INC(i);
              IF stroka[i] = "'" THEN
                INC(i);
                p := i;
                str.FindNext("'",stroka,i,ok,p1);
                IF ok THEN
                  INC(i,p1-i);
                  xs.Extract(stroka,p,i-p,format);
                  INC(i);
                  IF stroka[i] = ',' THEN
                    IF CAP(stroka[i+1]) = 'K' THEN
                      INC(i,2);
                      p1 := i;
                      WHILE stroka[i] IN exp.CHARSET{"0".."9"} DO INC(i) END;
                      IF p1 <> i THEN
                        xs.Extract(stroka,p1,i-p1,st);
                        IF exp.GetCardValue(pt.ActiveComponent, pt.ActiveModule, st, value) THEN
                          LnElem := VAL(CARDINAL,value);
                        ELSE
                          i:=p1-1; (* ��୥��� ����� - � ����⠭� �訡�� *)
                        END;
                      ELSE
                        i:=p1-1; (* ��୥��� ����� - 'K' ��砫� ᫥�. ⥪�� *)
                      END;
                    END;
                  END;
                  IF stroka[i] = ',' THEN
                    IF CAP(stroka[i+1]) = 'L' THEN
                      INC(i,2);
                      p1 := i;
                      WHILE stroka[i] IN exp.CHARSET{"0".."9"} DO INC(i) END;
                      IF p1 <> i THEN
                        xs.Extract(stroka,p1,i-p1,st);
                        IF exp.GetCardValue(pt.ActiveComponent, pt.ActiveModule, st, value) THEN
                          LnPole := VAL(CARDINAL,value);
                        ELSE
                          i:=p1-1; (* ��୥��� ����� - � ����⠭� �訡�� *)
                        END;
                      ELSE
                        i:=p1-1; (* ��୥��� ����� - 'K' ��砫� ᫥�. ⥪�� *)
                      END;
                    END;
                  END;
                  IF stroka[i] # ')' THEN
                    i := p;
                  ELSE
                    INC(i);
                    RETURN;
                  END;
                END;
              END;
            END;
          END;
        END;
      END;
    END;
  END get_format;

  PROCEDURE float_sig (VAR s: ARRAY OF CHAR);
  BEGIN
    IF s[0] # '-' THEN
      IF sg IN smodif THEN
        xs.Insert ('+', 0, s);
      ELSIF sp IN smodif THEN
        xs.Insert (' ', 0, s);
      END;
    END;
  END float_sig;


VAR
  i,i0,i1 : CARDINAL;
  flag : BOOLEAN;
  p1, p2, p3, p4, p5, p6: CARDINAL;
  ExprRes, ValueRes: exp.ExprRes;
  l, k : CARDINAL;
  idxobc : LONGCARD;
  prev_text: xs.String;
  real_val: LONGLONGREAL;
  max_dig: CARDINAL;


  PROCEDURE get_max_digits (VAR max_dig: CARDINAL): BOOLEAN;
  BEGIN
    IF exp.ConvertReal2Host (ValueRes, real_val) THEN
     <* IF DEST_K26 THEN *>
      CASE ValueRes.r_type OF
      | exp.PC_const: max_dig := 17;
      | exp.f       : max_dig := 7;
      | exp.g       : max_dig := 15;
      | exp.d       : max_dig := 16;
      END;
     <* ELSE *>
      max_dig := 17;
     <* END *>
      RETURN TRUE;
    ELSE
      RETURN FALSE;
    END;
  END get_max_digits;


BEGIN
  IF NOT bas.CheckMode(pt.Put) THEN RETURN 0; END;
  IF bas.SkipBlanks(Line^, PosStr) THEN RETURN msg.Quota_expected; END;
  IF NOT CheckCurrentChar('"') THEN RETURN msg.Quota_expected; END;
  p2 := PosStr;
  str.FindNext('"',Line^,p2,flag,p3);
  IF NOT flag THEN RETURN msg.String_not_terminated; END;
  len := p3-p2;
  xs.Extract(Line^,p2,len,stroka);
  PosStr := p3+1;
  text := ''; (* ⥪�� ��� �뢮�� *)
  i := 0; (* ����� ⥪�饣� �ଠ� *)
  i1 := 0;
  LOOP
    LnPole := 0;
    LnElem := 0;
    i0 := i; (* ��砫� ⥪�� �� ⥪�饣� �ଠ� *)
    get_format (stroka, i, i1);
    (* i1 - �� ��砫� �ଠ�, i - ��᫥, �.�. �� ��砫� ᫥�. ⥪�� *)
    xs.Extract(stroka,i0,i1-i0,st);
    fmt.print (st1, st);
    xs.Append (st1, text);
    check_print;
    IF (i = i1) THEN
      IF text # '' THEN
        pro.WriteMsg (text, pro.to_screen, pro.to_file);
      END;
      EXIT;
    END;
    IF NOT SepParam() THEN RETURN msg.Expected_separator; END;
    IF NOT GetParam() THEN RETURN msg.Expected_expression; END;
    exp.GetLeftValue(pt.ActiveComponent, pt.ActiveModule, Param, ExprRes);
    IF (exp.error#0) OR NOT exp.dfn THEN RETURN exp.error; END;
    IF IsMemoryRegion(base) THEN (* ���� ���� *)
      flag := FALSE;
      WITH ExprRes DO
        CASE sort OF
        | exp.INTval
        , exp.CARDval
        , exp.WHOLEval   : Addr := kt.ADDRESS(value);
                           IF LnPole = 0 THEN LnPole := 1; END;
                           IF LnElem = 0 THEN LnElem := 1; END;
                           flag := TRUE;
        | exp.Address    : Addr := address;
                           IF LnPole = 0 THEN LnPole := 1; END;
                           IF LnElem = 0 THEN LnElem := 1; END;
                           flag := TRUE;
        | exp.Variable   : Addr := location;
                           l    := tls.TypeSize(var_type);
                           IF LnElem = 0 THEN LnElem := l; END;
                           IF LnPole = 0 THEN LnPole := l; END;
                           flag := TRUE;
        | exp.Reference  : Addr := reference;
                           l    := tls.TypeSize(ref_type);
                           IF LnElem = 0 THEN LnElem := l; END;
                           IF LnPole = 0 THEN LnPole := l; END;
                           flag := TRUE;
        | exp.Register   :
        | exp.REALval    :
        | exp.BOOLval    :
        END;
      END;
      IF LnElem > LnPole THEN
        LnElem := LnPole;
      END;
      IF flag THEN
        p1 := 0;
        p2 := 0; -- ��������, ����� �㤥� LOOP �� �ଠ⠬ ����� �����ଠ⭮� ��ப�
        p3 := p1;
        COPY (format, st1); -- st1 �����ଠ⭠� ��ப�
        get_format (st1, p1, p2);
        xs.Extract (st1, 0, p2, st2);
        fmt.print (prev_text, st2);
        p4 := 0; (* ����� ⥪�饣� ����� *)
        IF text # '' THEN (* ����� �।���⥫쭮�� ⥪�� *)
          pro.WriteMsg (text, pro.to_screen, pro.to_file);
          COPY ("", text);
        END;
        LOOP
          check_print;
         <* PUSH*>
         <* WOFF304+ *>
          CurrAddr := Addr+p4*LnElem;
          CASE base OF
          | 'i','d','x','X','o','b','c':
             IF LnElem > 4 THEN
               IF base IN xs.CHARSET{'x','X'} THEN
                 COPY ("", st2);
                 fmt.print (st3, '%$2%c', base);
                 idxobc := 0;
                 IF (p4+1)*LnElem <= LnPole THEN
                   p6 := LnElem;
                 ELSE
                   p6 := LnPole-p4*LnElem;
                 END;
                 p5 := p6-1;
                 LOOP
                   IF mem.Get(CurrAddr+p5, sys.ADR(idxobc), 1) THEN
                     fmt.append (st2, st3, idxobc);
                   ELSE
                     err.Warning (msg.ReadErrorAddress, CurrAddr+p5, 1);
                     EXIT;
                   END;
                   IF p5 = 0 THEN EXIT; END;
                   DEC (p5);
                 END;
                 WHILE st2[0] = '0' DO
                   str.Delete (st2, 0, 1);
                 END;
                 do_align (p6, st2);
                 expand_width (st2);
               ELSE
                 COPY (format, st2);
               END;
             ELSE
               idxobc := 0;
               IF (p4+1)*LnElem <= LnPole THEN
                 IF mem.Get(CurrAddr, sys.ADR(idxobc), LnElem) THEN
                   fmt.print (st2, format, idxobc);
                   do_align (LnElem, st2);
                 ELSE
                   err.Warning(msg.ReadErrorAddress, CurrAddr, LnElem);
                   COPY (format, st2);
                 END;
               ELSE
                 IF mem.Get(CurrAddr, sys.ADR(idxobc), LnPole-p4*LnElem) THEN
                   fmt.print (st2, format, idxobc);
                   do_align (LnPole-p4*LnElem, st2);
                 ELSE
                   err.Warning(msg.ReadErrorAddress, CurrAddr, LnPole-p4*LnElem);
                   COPY (format, st2);
                 END;
               END;
             END;
          | 's' :
            FOR k := 0 TO LnElem DO st2[k] := 0C; END;
            IF (p4+1)*LnElem <= LnPole THEN
              IF HIGH(st2) < LnElem THEN
                IF NOT mem.Get(CurrAddr,sys.ADR(st2),HIGH(st2)) THEN
                  err.Warning(msg.ReadErrorAddress, CurrAddr, HIGH(st2));
                  st2 := '';
                END;
              ELSE
                IF NOT mem.Get(CurrAddr,sys.ADR(st2),LnElem) THEN
                  err.Warning(msg.ReadErrorAddress, CurrAddr, LnElem);
                  st2 := '';
                END;
              END;
            ELSE
              IF HIGH(st2) < LnPole-p4*LnElem THEN
                IF NOT mem.Get(CurrAddr,sys.ADR(st2),HIGH(st2)) THEN
                  err.Warning(msg.ReadErrorAddress, CurrAddr, HIGH(st2));
                  st2 := '';
                END;
              ELSE
                IF NOT mem.Get(CurrAddr,sys.ADR(st2),LnPole-p4*LnElem) THEN
                  err.Warning(msg.ReadErrorAddress, CurrAddr, LnPole-p4*LnElem);
                  st2 := '';
                END;
              END;
            END;
         <* POP *>
          ELSE
            COPY (format, st2);
          END;
          IF (text = '') AND bas.CheckMode(pt.Put_Addr) THEN
            fmt.print(text, exp.Fmt_ADDRval, CurrAddr);
            xs.Append("   ", text);
          END;
          xs.Append (prev_text, text);
          xs.Append (st2, text);
          IF (p4+1)*LnElem >= LnPole THEN
            EXIT;
          END;
          INC(p4);
        END;
      ELSE
        xs.Append (format, text);
      END;
    ELSE
      IF NOT exp.Var2Value (ExprRes, ValueRes) THEN
        RETURN exp.error;
      END;
      CASE CAP(base) OF
      | 'N':
        exp.Res2Str (ValueRes, st);
      | 'E':
        IF get_max_digits (max_dig) THEN
          IF prc IN smodif THEN
            INC (precis);
          END;
          r2s.to_float (real_val, precis, 1, max_dig, base, bs IN smodif, TRUE, st);
          float_sig (st);
          expand_width (st);
        ELSE
          COPY (format, st);
        END;
      | 'F':
        IF get_max_digits (max_dig) THEN
          IF NOT (prc IN smodif) THEN
            precis := 6;
          END;
          r2s.to_fixed (real_val, precis, max_dig, st);
          float_sig (st);
          expand_width (st);
        ELSE
          COPY (format, st);
        END;
      | 'G':
        IF get_max_digits (max_dig) THEN
          IF NOT (prc IN smodif) THEN
            precis := 6;
          END;
          IF NOT (wdth IN smodif) THEN
            width := 2+precis;
          END;
          r2s.to_any (real_val, width, max_dig, st);
          float_sig (st);
          expand_width (st);
        ELSE
          COPY (format, st);
        END;
      ELSE
        WITH ValueRes DO
          CASE sort OF
          | exp.CARDval, exp.INTval, exp.WHOLEval:
            IF base = 'w' THEN
              sort := exp.BOOLval;
              IF value # 0 THEN b_val := TRUE; ELSE b_val := FALSE; END;
            ELSE
              COPY(format, exp.Fmt_Special);
            END;
          | exp.CHARval:
            COPY(format, exp.Fmt_CHARval);
          | exp.REALval:
            COPY(format, exp.Fmt_REALval);
          | exp.Address:
            COPY(format, exp.Fmt_ADDRval);
          | exp.Reference:
            COPY(format, exp.Fmt_ADDRval);
          | exp.STRINGval:
            COPY(format, exp.Fmt_STRINGval);
          | exp.Register:
            RETURN msg.Point_reg_not_here;
          | exp.Variable:
            RETURN msg.Struct_var_not_here;
          ELSE
          END;
        END;
        exp.Res2Str (ValueRes, st);
      END;  
      xs.Append (st, text);
    END;
  END;
  exp.SetDefaultFormat;
  RETURN 0;
END Put;


PROCEDURE Examine (): CARDINAL;
VAR
  res: exp.ExprRes;
  tmp: xs.String;
  txt: xs.String;
BEGIN
  LOOP
    IF NOT GetParam() THEN
      RETURN msg.Expected_parameter;
    END;
    exp.CalcExpr (pt.ActiveComponent, pt.ActiveModule, Param, res);
    IF (exp.error#0) THEN
      RETURN exp.error;
    END;
    exp.Res2Str (res, tmp);
    IF LENGTH (Param) < 8 THEN
      fmt.print (txt, "%s\t = %s", Param, tmp);
    ELSE
      fmt.print (txt, "%s = %s", Param, tmp);
    END;
    pro.WriteMsg (txt, pro.to_screen, pro.to_file);
    IF SkipBlanks() THEN
      EXIT;
    END;
    IF NOT SepParam() THEN
      RETURN msg.Expected_separator;
    END;
  END;
  RETURN 0;
END Examine;



(* ������� ���祭�� ��६����*)
PROCEDURE Set () : CARDINAL;
VAR
  ExprResL: exp.ExprRes;
  ExprResR: exp.ExprRes;

BEGIN
  IF NOT kex.Loaded THEN RETURN msg.Load_must_be_first END;
  IF NOT GetParam() THEN RETURN msg.Expected_VarOrReg; END;
  exp.GetLeftValue(pt.ActiveComponent, pt.ActiveModule, Param, ExprResL);
  IF (exp.error#0) OR NOT exp.dfn THEN RETURN exp.error; END;
  IF NOT SepParam() THEN RETURN msg.Expected_separator; END;
  IF NOT GetParam() THEN RETURN msg.Expected_expression; END;
  exp.CalcExpr(pt.ActiveComponent, pt.ActiveModule, Param, ExprResR);
  IF (exp.error#0) OR NOT exp.dfn THEN RETURN exp.error; END;
  IF NOT exp.Assign(ExprResL, ExprResR) THEN RETURN exp.error; END;
  RETURN 0;
END Set;



TYPE
  REGISTERS = ARRAY [0..kt.UserRegs-1] OF kt.REG_VALUE;

VAR
  Registers: REGISTERS;


(* ������ ���������� 䮭�� *)
PROCEDURE Fon (): CARDINAL;
VAR
  Addr : kt.ADDRESS;
  RegNo: CARDINAL;
  Ln   ,
  value: LONGCARD;
  pbyte: POINTER TO sys.CARD8;
  k,i,N: CARDINAL;

BEGIN
  IF NOT kex.Loaded THEN RETURN msg.Load_must_be_first END;
  IF NOT GetParam() THEN RETURN msg.Expected_address; END;
  IF NOT exp.GetAddrOrReg(pt.ActiveComponent, pt.ActiveModule, Param, Addr, RegNo) THEN RETURN msg.Incorrect_address; END;
  IF NOT SepParam() THEN RETURN msg.Expected_separator; END;
  IF GetParam() THEN
    IF NOT exp.GetCardValue(pt.ActiveComponent, pt.ActiveModule, Param, Ln) OR (Ln=0) THEN RETURN msg.Incorrect_parameter; END;
  ELSE
    IF RegNo = MAX(CARDINAL) THEN Ln := 1; ELSE Ln := 4; END;
  END;
  IF NOT SepParam() THEN RETURN msg.Expected_separator; END;
  IF NOT GetParam() THEN RETURN msg.Expected_parameter; END;
  IF NOT exp.GetCardValue(pt.ActiveComponent, pt.ActiveModule, Param, value) THEN RETURN msg.Incorrect_parameter; END;
  pbyte := sys.ADR(value);
  IF RegNo # MAX(CARDINAL) THEN
    k := 0;
    LOOP
      IF kt.Registers[k].reg_no = RegNo THEN EXIT; END;
      INC(k);
      IF k = kt.UserRegs THEN RETURN msg.Incorrect_parameter; END;
    END;
    FOR i := 0 TO HIGH(Registers) DO
      ASSERT( mem.GetReg(kt.Registers[i].reg_no, Registers[i]) );
    END;
    N := (HIGH(Registers)-k+1) * 4; (* ����. ���-�� ����뫠���� ���� *)
    IF N > Ln THEN N := Ln; END;
    FOR i := 0 TO N-1 DO
      sys.MOVE( pbyte, sys.ADDADR(sys.ADR(Registers[k]),i), 1);
    END;
    FOR k := 0 TO HIGH(Registers) DO
      ASSERT( mem.SetReg(kt.Registers[k].reg_no, Registers[k]) );
    END;
  ELSE
    FOR k := 0 TO Ln-1 DO
      IF NOT mem.Put(Addr+k, pbyte, 1) THEN
        err.Warning(msg.WriteErrorAddress, Addr+k, 1);
        RETURN 0;
      END;
    END;
  END;
  RETURN 0;
END Fon;


(* ����뫪� � ���� �� ���� ᪮�쪮-� ���� *)
PROCEDURE Move (): CARDINAL;

<* IF DEST_K26 THEN *>

VAR
  Dest       : kt.ADDRESS;
  Source     : exp.ExprRes;
  LC         : exp.LONGCONST;
  RegNoDest  : CARDINAL;
  Ln, k,i,n,N: LONGCARD;
  byte       : sys.CARD8;
  Registers2 : REGISTERS;

<* ELSIF DEST_XDS THEN *>

VAR
  Source: kt.ADDRESS;
  Dest  : kt.ADDRESS;
  Ln, k : CARDINAL;
  byte  : sys.CARD8;

<* END *>

BEGIN
  IF NOT kex.Loaded THEN RETURN msg.Load_must_be_first END;
  IF NOT GetParam() THEN RETURN msg.Expected_address; END;

<* IF DEST_K26 THEN *>

  IF NOT exp.GetAddrOrReg(pt.ActiveComponent, pt.ActiveModule, Param, Dest, RegNoDest) THEN
    RETURN msg.Incorrect_parameter;
  END;
  IF NOT SepParam() THEN RETURN msg.Expected_separator; END;
  IF NOT GetParam() THEN RETURN msg.Expected_parameter; END;
  IF NOT exp.GetCardValue(pt.ActiveComponent, pt.ActiveModule, Param, Ln) OR (Ln=0) THEN RETURN msg.Incorrect_length; END;
  IF NOT SepParam() THEN RETURN msg.Expected_separator; END;
  IF NOT GetParam() THEN RETURN msg.Expected_address; END;
  IF NOT exp.GetSource(pt.ActiveComponent, pt.ActiveModule, Param, LC, Source) THEN RETURN msg.Incorrect_parameter; END;
  IF LC.len = 0 THEN (* ��ࠢ� ���� *)
    IF Source.sort = exp.Address THEN
      IF RegNoDest = MAX(CARDINAL) THEN
        IF ((Source.address<Dest) AND (Source.address+Ln>Dest)) OR
           ((Dest<Source.address) AND (Dest+Ln>Source.address)) THEN
          err.Warning(msg.Overlapping_blocks,Source.address,Dest);
        END;
        FOR k := 0 TO Ln-1 DO
          byte := 0;
          IF NOT mem.Get(Source.address+k, sys.ADR(byte), 1) THEN
            err.Warning(msg.ReadErrorAddress, Source.address+k, 1);
            RETURN 0;
          END;
          IF NOT mem.Put(Dest+k, sys.ADR(byte), 1) THEN
            err.Warning(msg.WriteErrorAddress, Dest+k, 1);
            RETURN 0;
          END;
        END;
      ELSE
        k := 0;
        LOOP
          IF kt.Registers[k].reg_no = RegNoDest THEN EXIT; END;
          INC(k);
          IF k = kt.UserRegs THEN RETURN msg.Incorrect_parameter; END;
        END;
        FOR i := 0 TO HIGH(Registers) DO
          ASSERT( mem.GetReg(kt.Registers[i].reg_no, Registers[i]) );
        END;
        N := (HIGH(Registers)-k+1) * 4; (* ����. ���-�� ����뫠���� ���� *)
        IF N > Ln THEN N := Ln; END;
        FOR i := 0 TO N-1 DO
          IF NOT mem.Get(Source.address+i, sys.ADDADR(sys.ADR(Registers[k]),i), 1) THEN
            err.Warning(msg.ReadErrorAddress, Source.address+i, 1);
            RETURN 0;
          END;
        END;
        FOR k := 0 TO HIGH(Registers) DO
          ASSERT( mem.SetReg(kt.Registers[k].reg_no, Registers[k]) );
        END;
      END;
    ELSIF Source.sort = exp.Register THEN
      IF RegNoDest = MAX(CARDINAL) THEN
        RETURN msg.Incorrect_parameter;
      ELSE
        k := 0;
        LOOP
          IF kt.Registers[k].reg_no = RegNoDest THEN EXIT; END;
          INC(k);
          IF k = kt.UserRegs THEN RETURN msg.Incorrect_parameter; END;
        END;
        n := 0;
        LOOP
          IF kt.Registers[n].reg_no = Source.reg_no THEN EXIT; END;
          INC(n);
          IF n = kt.UserRegs THEN RETURN msg.Incorrect_parameter; END;
        END;
        FOR i := 0 TO HIGH(Registers) DO
          ASSERT( mem.GetReg(kt.Registers[i].reg_no, Registers[i]) );
        END;
        Registers2 := Registers;
        N := (HIGH(Registers)-n+1) * 4; (* ����. ���-�� ����뫠���� ���� *)
        i := (HIGH(Registers)-k+1) * 4;
        IF N > i THEN N := i; END;
        IF N > Ln THEN N := Ln; END;
        FOR i := 0 TO N-1 DO
          sys.MOVE( sys.ADDADR(sys.ADR(Registers2[n]),i),
                    sys.ADDADR(sys.ADR(Registers[k]),i), 1);
        END;
        FOR k := 0 TO HIGH(Registers) DO
          ASSERT( mem.SetReg(kt.Registers[k].reg_no, Registers[k]) );
        END;
      END;
    ELSE
      RETURN msg.Incorrect_parameter;
    END;
  ELSE (* ��ࠢ� ����⠭� *)
    IF Ln > LC.len THEN
      err.Warning(msg.Length_GR_const, Ln, LC.len);
      Ln := LC.len;
    END;
    IF RegNoDest = MAX(CARDINAL) THEN
      FOR k := 0 TO Ln-1 DO
        IF NOT mem.Put(Dest+k, sys.ADR(LC.ptr^[k]), 1) THEN
          err.Warning(msg.WriteErrorAddress, Dest+k, 1);
          RETURN 0;
        END;
      END;
    ELSE
      k := 0;
      LOOP
        IF kt.Registers[k].reg_no = RegNoDest THEN EXIT; END;
        INC(k);
        IF k = kt.UserRegs THEN RETURN msg.Incorrect_parameter; END;
      END;
      FOR i := 0 TO HIGH(Registers) DO
        ASSERT( mem.GetReg(kt.Registers[i].reg_no, Registers[i]) );
      END;
      N := (HIGH(Registers)-k+1) * 4; (* ����. ���-�� ����뫠���� ���� *)
      IF N > Ln THEN N := Ln; END;
      FOR i := 0 TO N-1 DO
        sys.MOVE( sys.ADR(LC.ptr^[i]), sys.ADDADR(sys.ADR(Registers[k]),i), 1);
      END;
      FOR k := 0 TO HIGH(Registers) DO
        ASSERT( mem.SetReg(kt.Registers[k].reg_no, Registers[k]) );
      END;
    END;
  END;

<* ELSIF DEST_XDS THEN *>

  IF NOT exp.GetAddress(pt.ActiveComponent, pt.ActiveModule, Param, Source) THEN RETURN msg.Incorrect_address; END;
  IF NOT SepParam() THEN RETURN msg.Expected_separator; END;
  IF NOT GetParam() THEN RETURN msg.Expected_address; END;
  IF NOT exp.GetAddress(pt.ActiveComponent, pt.ActiveModule, Param, Dest)  THEN RETURN msg.Incorrect_address; END;
  IF NOT SepParam() THEN RETURN msg.Expected_separator; END;
  IF NOT GetParam() THEN RETURN msg.Expected_parameter; END;
  IF NOT exp.GetCardValue(pt.ActiveComponent, pt.ActiveModule, Param, Ln) OR (Ln = 0) THEN RETURN msg.Incorrect_length; END;
  IF ((Source < Dest) AND (Source+Ln > Dest)) OR
     ((Dest < Source) AND (Dest+Ln > Source)) THEN err.Warning(msg.Overlapping_blocks, Source, Dest);
  END;
  FOR k := 0 TO Ln-1 DO
    IF NOT mem.Get(Source+k, sys.ADR(byte), 1) THEN
      err.Warning(msg.ReadErrorAddress, Source+k, 1);
      RETURN 0;
    END;
    IF NOT mem.Put(Dest+k, sys.ADR(byte), 1) THEN
      err.Warning(msg.WriteErrorAddress, Dest+k, 1);
      RETURN 0;
    END;
  END;

<* END *>

  RETURN 0;
END Move;


(* ��砫� ��ਠ�� �ᯮ������ �ࠣ���� �ணࠬ�� *)
PROCEDURE TestBegin () : CARDINAL;
BEGIN
  IF TestName <> '' THEN RETURN msg.Test_begin_duplicate; END;
  IF NOT GetParam() THEN RETURN msg.Expected_test_name; END;
  pro.WriteMsgNo(msg.Test_Begin,TRUE,pro.to_file, Param);
  COPY(Param, TestName);
  ASSERT( kex.Ticks(kex.RESET) = kex.Timer(kex.RESET) );
  RETURN 0;
END TestBegin;


PROCEDURE Beep (): CARDINAL;
BEGIN
  crt.Beep;
  RETURN 0;
END Beep;


PROCEDURE About (): CARDINAL;
VAR
  d  : tcn.DateTime;
  str: xs.String;
BEGIN
  tcn.unpack (d, com.TIMESTAMP);
  fmt.print (str, "\n\t%s", xdt.PRODUCT);
  pro.WriteMsg (str, pro.to_screen, pro.to_file);
  fmt.print (str, "\tVersion %s [build %$2d.%$2d.%4d]", xdt.VERSION, d.day, d.month, d.year);
  pro.WriteMsg (str, pro.to_screen, pro.to_file);
  fmt.print (str, "\t(c) %s\n", xdt.COPYRIGHT);
  pro.WriteMsg (str, pro.to_screen, pro.to_file);
  RETURN 0;
END About;


<* IF DEST_K26 THEN *>

PROCEDURE Restart (): CARDINAL;
VAR
  entry: kt.ADDRESS;
BEGIN
  IF NOT kex.Loaded THEN RETURN msg.Load_must_be_first END;
  IF bas.CheckMode(pt.GoSuccess) THEN RETURN msg.RestartNotAllowed; END;
  stk.ResetCallStack;
  IF GetParam() THEN
    IF NOT exp.GetAddress(pt.ActiveComponent, pt.ActiveModule, Param, entry) THEN
      RETURN msg.IncorrectEntryPoint;
    END;
    IF NOT int.ChangeProgramEntryPoint (entry) THEN
      RETURN msg.IncorrectEntryPoint;
    END;
  ELSE
    IF NOT kpr.RestartProgram() THEN   -- ��뢠�� �ࠧ� ������ �ᯮ���⥫�
      RETURN msg.ProgramCantRestarted; -- �� �� �� KrnExec, ���� �ணࠬ��
    END;                               -- �㤥� ���㦥�� � ����㦥�� �����
    -- � ⥯��� �㦭� �믮����� �ணࠬ��, ����
    -- �� �� 㩤�� � �窨 �室� ��᫥ ��᪠���
    exe.JumpToMainEntry := TRUE;    -- ��⠭�������, �᫨ ���� �⫠��筠� ���ଠ��
    exe.JumpToProgramEntry := TRUE; -- ��⠭�������, �᫨ ���� �窠 �室�
    exe.SkipToMain;
  END;
  kex.ProgramContextOk := TRUE;
  RETURN 0;
END Restart;


(* ����� �ணࠬ�� *)
PROCEDURE Go (): CARDINAL;
VAR
  paket: CARDINAL;
  line : CARDINAL;
  rc   : CARDINAL;
BEGIN
  IF bas.CheckMode(pt.GoSuccess) THEN RETURN msg.Dublicate_GO; END;
 <* IF SCHERN_K26 THEN *>
  ncr.Contr_ID;
 <* END *>
  lst.PushCall (pt.CurrPaket, pt.Pakets[pt.CurrPaket].LineNum, FALSE);
  rc := Restart();
  IF rc # 0 THEN
    lst.PopCall (paket, line);
    RETURN rc;
  END;
  bas.ModeOn(pt.GoSuccess);
  IF prc.NeedToStepMode() THEN
    exe.TurnStepModeOn;
  ELSE
    exe.TurnStepModeOff;
  END;
  exe.Go;
  RETURN 0;
END Go;


(* �த������� �ᯮ������ �ணࠬ�� *)
PROCEDURE Goon (): CARDINAL;
VAR
  entry: kt.ADDRESS;
BEGIN
  IF NOT kex.Loaded THEN RETURN msg.Load_must_be_first END;
  IF NOT bas.CheckMode(pt.GoSuccess) THEN RETURN msg.GOBackOn_without_GO; END;
  IF GetParam() THEN
    IF NOT exp.GetAddress(pt.ActiveComponent, pt.ActiveModule, Param, entry) THEN RETURN msg.Incorrect_address; END;
    IF NOT mem.SetReg (kt.EIP, entry) THEN RETURN msg.IncorrectEntryPoint; END;
  END;
  IF prc.NeedToStepMode() THEN
    exe.TurnStepModeOn;
  ELSE
    exe.TurnStepModeOff;
  END;
  exe.Go;
  RETURN 0;
END Goon;


(* ������ � �뤠� ⠪⮢ �ᯮ������ *)
PROCEDURE Ticks () : CARDINAL;
BEGIN
  IF bas.CheckMode(pt.Time_Count) THEN
    pro.WriteMsgNo(msg.Time,TRUE,pro.to_file,kex.Ticks(kex.SHOW));
    ASSERT(kex.Ticks(kex.RESET)=0);
  END;
  RETURN 0;
END Ticks;


(* ����砭�� ��ਠ�� �ᯮ������ *)
PROCEDURE TestEnd () : CARDINAL;
BEGIN
  IF TestName = '' THEN RETURN msg.Expected_test_begin; END;
  IF NOT GetParam() THEN RETURN msg.Expected_test_name; END;
  pro.WriteMsgNo(msg.Test_End,TRUE,pro.to_file,Param);
  TestName := '';
  ASSERT( Ticks() = 0 );;
  RETURN 0;
END TestEnd;


(* ������� ������ ��� ⠡��筮� ������ *)
PROCEDURE Data (): CARDINAL;
VAR
  device: CARDINAL;
  reg   : CARDINAL;
  value : LONGCARD;
  Addr  : kt.ADDRESS;
BEGIN
  IF NOT bas.CheckMode(pt.KodSuccess) THEN RETURN msg.DeviceTableNotLoaded; END;
  IF NOT GetParam() THEN RETURN msg.Expected_parameter; END;
  IF NOT exp.GetAddress(pt.ActiveComponent, pt.ActiveModule, Param, Addr) THEN RETURN exp.error; END;
  IF NOT mdl.FindByAddress(Addr, device, reg) THEN RETURN msg.DeviceNotFound; END;
  IF SepParam() THEN
    LOOP
      IF NOT GetParam() THEN RETURN msg.Expected_parameter; END;
      IF NOT exp.GetCardValue(pt.ActiveComponent, pt.ActiveModule, Param, value) THEN RETURN msg.Incorrect_Data; END;
      mdl.SetDataRegs(device, reg, value);
      IF SkipBlanks() THEN EXIT; END;
      IF NOT SepParam() THEN RETURN msg.Expected_separator END;
    END;
  ELSE
    IF mdl.IsDataRegs (device, reg) THEN
      mdl.DelDataRegs(device, reg);
    ELSE
      err.Warning(msg.DataNotDefine, Param);
    END;
  END;
  RETURN 0;
END Data;


(* ��।������ ������ ��� ���ன�⢠ *)
PROCEDURE Model (): CARDINAL;
VAR
  ext   : BOOLEAN;
  device: CARDINAL;
BEGIN
  IF NOT bas.CheckMode(pt.KodSuccess) THEN RETURN msg.DeviceTableNotLoaded; END;
  IF NOT GetParam() THEN RETURN msg.ExpectedModuleName; END;
  IF NOT mdl.FindDeviceByName(Param, device) THEN RETURN msg.DeviceNotFound; END;
  IF SepParam() THEN
    IF NOT GetParam() THEN RETURN msg.ExpectedModelName; END;
    IF NOT exp.CheckFileName(Param, ext) THEN RETURN msg.Incorrect_file_name; END;
    mdl.SetPktModel(device, Param);
  ELSE
    IF mdl.IsPktModel(device) THEN
      mdl.DelPktModel(device);
    ELSE
      err.Warning(msg.PktModelNotInstall, Param);
    END;
  END;
  RETURN 0;
END Model;



(* ��।������ ⠡���� ���ᠭ�� ���ன�� *)
PROCEDURE Kod () : CARDINAL;
VAR
  ext: BOOLEAN;
BEGIN
  IF bas.CheckMode(pt.KodSuccess) THEN RETURN msg.Dublicate_kod END;
  IF NOT GetParam() THEN RETURN msg.Expected_table_name; END;
  IF NOT exp.CheckFileName(Param, ext) THEN RETURN msg.Incorrect_file_name; END;
  IF NOT ext THEN fil.ChangeExtension(Param, kt.tbl_file_ext); END;
  IF NOT mdl.Init_ModelIO(Param) THEN RETURN msg.Incorrect_Model_Table; END;
  bas.ModeOn(pt.KodSuccess);
  RETURN 0;
END Kod;


(* ���������� ॣ���஢ 䮭��� ���祭��� *)
PROCEDURE Regfon (): CARDINAL;
VAR
  Reg : ARRAY [0..SIZE(kt.REG_VALUE)-1] OF sys.CARD8;
  i, k: CARDINAL;
BEGIN
  IF NOT kex.Loaded THEN RETURN msg.Load_must_be_first END;
  FOR i := 0 TO kt.UserRegs-1 DO
    FOR k := 0 TO SIZE(kt.REG_VALUE)-1 DO Reg[k] := sys.CARD8(0F0H+i) END;
    ASSERT( mem.SetReg(kt.Registers[i].reg_no, kt.REG_VALUE(Reg)) );
  END;
  RETURN 0;
END Regfon;


PROCEDURE SetInterrupt (): CARDINAL;
VAR
  vector: CARDINAL;
BEGIN
  LOOP
    IF NOT GetParam() THEN RETURN msg.Expected_interrupt_vector; END;
    IF NOT exp.GetCardValue (pt.ActiveComponent, pt.ActiveModule, Param, vector) THEN RETURN exp.error; END;
    int.SetInterrupt (vector);
    IF int.ok # 0 THEN RETURN msg.Incorrect_interrupt_vector; END;
    IF SkipBlanks() THEN EXIT; END;
    IF NOT SepParam() THEN RETURN msg.Expected_separator; END;
  END;
  RETURN 0;
END SetInterrupt;


PROCEDURE ProcModel (): CARDINAL;
VAR
  proc : dt.OBJECT;
  Addr : kt.ADDRESS;
  index: CARDINAL;
  break: pt.BREAK_DESCRIPTION;
  com  : dt.ComNo;
  mod  : dt.ModNo;
BEGIN
  IF NOT kex.Loaded THEN RETURN msg.Load_must_be_first END;
  IF NOT GetParam() THEN RETURN msg.Expected_parameter; END;
  IF NOT exp.GetAddress (pt.ActiveComponent, pt.ActiveModule, Param, Addr) THEN RETURN msg.ObjectNotFound; END;
  IF NOT tls.FindModByAddr (Addr, com, mod) THEN RETURN msg.ObjectNotFound; END;
  proc := tls.FindLabelByAddr (com, mod, Addr);
  IF NOT tls.IsObjectValid (proc) THEN RETURN msg.ObjectNotFound; END;
  IF SepParam() THEN
    IF NOT mdl.Add_Proc (proc, index) THEN RETURN msg.ModelProcCantInstall; END;
    LOOP
      IF NOT GetParam() THEN RETURN msg.Expected_parameter; END;
      IF NOT exp.CheckName (Param, TRUE) THEN RETURN msg.Incorrect_label; END;
      IF lst.GetLabel (Param, break.Paket_No, break.Line_No) THEN
        break.Number := index;
        mdl.Add_DescProc (break);
      ELSE
        err.Warning(msg.Label_not_found, Param);
      END;
      IF SkipBlanks() THEN EXIT; END;
      IF NOT SepParam() THEN RETURN msg.Expected_separator; END;
    END;
  ELSE
    IF mdl.Find_Proc (proc, index) THEN
      mdl.Delete_Proc (index);
    ELSE
      err.Warning (msg.ModelProcNotDefine, Param);
    END;
  END;
  RETURN 0;
END ProcModel;


PROCEDURE Allocate (): CARDINAL;
VAR
  size: CARDINAL;
  dest: exp.ExprRes;
  addr: exp.ExprRes;
BEGIN
  IF NOT kex.Loaded THEN RETURN msg.Load_must_be_first END;
  IF NOT GetParam() THEN RETURN msg.Expected_parameter; END;
  IF NOT exp.GetCardValue (pt.ActiveComponent, pt.ActiveModule, Param, size) THEN RETURN msg.Incorrect_parameter; END;
  ime.GetMem (size, dest.value);
  IF int.ok # 0 THEN RETURN msg.Not_enough_memory; END;
  dest.sort := exp.Address;
  IF NOT SepParam() THEN RETURN msg.Expected_separator; END;
  IF NOT GetParam() THEN RETURN msg.Expected_parameter; END;
  exp.GetLeftValue (pt.ActiveComponent, pt.ActiveModule, Param, addr);
  IF exp.error # 0 THEN RETURN exp.error; END;
  IF NOT exp.Assign (addr, dest) THEN RETURN exp.error; END;
  RETURN 0;
END Allocate;


PROCEDURE Deallocate (): CARDINAL;
VAR
  addr: exp.ExprRes;
  dest: kt.ADDRESS;
  res : exp.ExprRes;
BEGIN
  IF NOT GetParam() THEN RETURN msg.Expected_parameter; END;
  IF NOT exp.GetAddress (pt.ActiveComponent, pt.ActiveModule, Param, dest) THEN RETURN msg.Incorrect_address; END;
  exp.GetLeftValue (pt.ActiveComponent, pt.ActiveModule, Param, addr);
  ASSERT(exp.error = 0);
  ime.FreeMem (dest);
  IF int.ok # 0 THEN RETURN msg.Incorrect_parameter; END;
  res.sort := exp.Address;
  res.address := 0;
  IF NOT exp.Assign (addr, res) THEN RETURN exp.error; END;
  RETURN 0;
END Deallocate;


(* ���뫪� ����⠭�� � ������ *)
PROCEDURE Transfer (): CARDINAL;
VAR
  Source: exp.ExprRes;
  Dest  : kt.ADDRESS;
  LC    : exp.LONGCONST;
  Ln, k : CARDINAL;
  sum   : CARDINAL;
BEGIN
  IF NOT kex.Loaded THEN
    RETURN msg.Load_must_be_first;
  END;
  -- ������� ���� �ਥ�����
  IF NOT GetParam() THEN
    RETURN msg.Expected_address;
  END;
  IF NOT exp.GetAddress (pt.ActiveComponent, pt.ActiveModule, Param, Dest) THEN
    RETURN msg.Incorrect_parameter;
  END;
  -- ������� ����� ������塞��� �����
  IF NOT SepParam() THEN
    RETURN msg.Expected_separator;
  END;
  IF NOT GetParam() THEN
    RETURN msg.Expected_parameter;
  END;
  IF NOT exp.GetCardValue (pt.ActiveComponent, pt.ActiveModule, Param, Ln) OR (Ln=0) THEN
    RETURN msg.Incorrect_length;
  END;
  -- ������� ����⠭�� ��� ����������
  sum := 0;
  LOOP
    IF NOT SepParam() THEN
      RETURN msg.Expected_separator;
    END;
    IF NOT GetParam() THEN
      RETURN msg.Expected_address;
    END;
    IF NOT exp.GetSource (pt.ActiveComponent, pt.ActiveModule, Param, LC, Source) THEN
      RETURN msg.Incorrect_parameter;
    END;
    IF LC.len = 0 THEN
      RETURN msg.ExpectedIntConstant;
    END;
    FOR k := LC.len-1 TO 0 BY -1 DO
      IF sum >= Ln THEN
        err.Warning (msg.Length_LS_const, Ln, sum+k+1);
        EXIT;
      END;
      IF NOT mem.Put (Dest+sum, sys.ADR(LC.ptr^[k]), 1) THEN
        err.Warning(msg.WriteErrorAddress, Dest+sum, 1);
        RETURN 0;
      END;
      INC (sum);
    END;
    IF SkipBlanks() THEN
      EXIT;
    END;
  END;
  IF Ln > sum THEN
    err.Warning (msg.Length_GR_const, Ln, sum);
  END;
  RETURN 0;
END Transfer;

<* END *>


<* IF DEST_XDS THEN *>

(* Execute external program *)
PROCEDURE ExecuteProgram (): CARDINAL;
VAR
  progName: xs.String;
  exit: CARDINAL;
BEGIN
  IF NOT GetParam() THEN RETURN msg.Expected_program_name; END;
  progName := Param;
  IF NOT GetLastParam() THEN RETURN msg.Expected_parameter; END;
  IF pe.Execute(progName, Param, exit) THEN
    RETURN exit;
  ELSE
    RETURN msg.CannotCreateProcess;
  END;
END ExecuteProgram;


PROCEDURE CmdShell (): CARDINAL;
VAR
  exit: CARDINAL;
BEGIN
  IF NOT GetLastParam() THEN RETURN msg.Expected_parameter; END;
  IF pe.Command(Param, exit) THEN
    RETURN exit;
  ELSE
    RETURN msg.CannotCreateProcess;
  END;
END CmdShell;


(* Restart program *)
PROCEDURE Restart (): CARDINAL;
BEGIN
  IF NOT kex.Loaded THEN
    RETURN msg.Load_must_be_first;
  END;
  IF bas.CheckMode(pt.GoSuccess) THEN
    RETURN msg.RestartNotAllowed;
  END;
  stk.ResetCallStack;
  dv.SetMainMode(dv.source);
  thr.ClearThreads;
  brk.Clear_AccessBreak;
  exe.JumpToMainEntry := xi.XDInterfacePresent () OR kex.ProgramMainEntryFound ();
  exe.JumpToProgramEntry := kex.ProgramMainEntryFound ();
  IF NOT exe.Restart() THEN
    RETURN msg.ProgramCantRestarted;
  END;
  brk.Refresh_AccessBreak;
  brk.Refresh_Breakpoints;
  bas.ModeOn (pt.RestartDone);
  RETURN 0;
END Restart;

(* ����� �ணࠬ�� *)
PROCEDURE Start (): CARDINAL;
(*
VAR
  rc: CARDINAL;
*)
BEGIN
  IF NOT kex.Loaded THEN
    RETURN msg.Load_must_be_first;
  END;
  IF NOT kex.ProgramContextOk THEN
    RETURN msg.ProgramFinished;
  END;
  IF bas.CheckMode(pt.GoSuccess) THEN
    RETURN msg.Dublicate_GO;
  END;
(*
  rc := Restart();
  IF rc # 0 THEN RETURN rc; END;
*)
  bas.ModeOff (pt.RestartDone);
  bas.ModeOn(pt.GoSuccess);
  lst.PushCall(pt.CurrPaket, pt.Pakets[pt.CurrPaket].LineNum, FALSE);
  IF prc.NeedToStepMode() THEN
    exe.TurnStepModeOn;
  ELSE
    exe.TurnStepModeOff;
  END;
  exe.Go;
  RETURN 0;
END Start;


(* �த������� �ᯮ������ �ணࠬ�� *)
PROCEDURE Resume (): CARDINAL;
BEGIN
  IF NOT kex.Loaded THEN
    RETURN msg.Load_must_be_first;
  END;
  IF NOT bas.CheckMode(pt.GoSuccess) AND NOT bas.CheckMode(pt.RestartDone) THEN
    RETURN msg.GOBackOn_without_GO;
  END;
  IF prc.NeedToStepMode() THEN
    exe.TurnStepModeOn;
  ELSE
    exe.TurnStepModeOff;
  END;
  exe.Go;
  RETURN 0;
END Resume;

<* END *>



<* IF SCHERN_K26 THEN *>
(*                                             CHERN      *)

(*  ����� �६��� �ᯮ������ ��楤�� *)
PROCEDURE Init_PrcTime():CARDINAL;
BEGIN
     IF tpc.Init_Time_proc(act.prf_4,FALSE) THEN
       RETURN 0;
     END;
END Init_PrcTime;


(*    ____________________________________________________________________ CHERN *)
(*                       ����஫� ���஢������ �ணࠬ��                   *)


(*                       ���਩ ��� �� �� �����             *)

PROCEDURE Init_ID():CARDINAL; (* ����㦠�� 䠩�� �ᯮ��㥬� ��� ����஫� *)
VAR
BEGIN
  IF NOT kex.Loaded THEN RETURN msg.Load_must_be_first END;
  IF NOT GetParam() THEN RETURN msg.Expected_parameter;
  ELSE       RETURN ncr.Read_Idata(Param);
  END;
END Init_ID;

PROCEDURE End_ID():CARDINAL; (* �����뢠�� 䠩�� �ᯮ��㥬� ��� ����஫� *)
VAR
BEGIN
    RETURN ncr.Write_Idata();
      RETURN 0;
END End_ID;


VAR A_all_logs : OctLog.ALL_LOGS;


PROCEDURE Init_Cov():CARDINAL; (* ��頥� 䠩�� �ᯮ��㥬� ��� ����஫� *)
VAR
      recl,recr: exp.ExprRes;
      mod : dt.ModNo;
      com: dt.ComNo;
      l : CARDINAL;
      Vax_all_logs : kt.ADDRESS;
--      pt : exe.PType;
--      pv : exe.PVar;
BEGIN
      l :=SIZE(OctLog.ALL_LOGS_REC);  (* ࠧ��� ����� ��� *)
      ime.GetMem(l,Vax_all_logs);
      IF int.ok#0 THEN RETURN 6;END;
-- �஢�ઠ ��
      A_all_logs := iad.ADPC(Vax_all_logs);
      LogIO.read_logs(A_all_logs,TRUE); (*  ����� �������� ��� ��࠭���� *)
                  (* ���ଠ樨 � ���஢������ �ணࠬ�� *)

     IF tls.FindMod('OctLog',com,mod) THEN
      exp.GetLeftValue(com,mod, 'all_logs', recl);
--      pv := exe.FindVar(mod,'all_logs');
--      pt := exe.VarType(pv);
--      pt := exe.TypeByName(mod,'all_logs');
--      recl.sort :=def.Variable;
--      recl.type := pt;
      recr.sort := exp.Address;
      recr.address:=Vax_all_logs;
      IF exp.Assign(recl,recr) THEN
            RETURN 0
      ELSE RETURN 7;
      END;
     ELSE RETURN msg.ObjectNotFound;
     END;
END Init_Cov;

PROCEDURE Read_Cov():CARDINAL; (* ����砥��� ०��  ����஫� ���஢������*)
         (* ���뢠���� �㦭� ��� �⮣� 䠩�� � ���� �⮩ ���ଠ樨 *)
         (* ��।����� �ᯮ��塞�� �ணࠬ��                           *)
VAR
      recl,recr: exp.ExprRes;
      mod : dt.ModNo;
      com : dt.ComNo;
      l  : CARDINAL;
      Vax_all_logs : kt.ADDRESS;

BEGIN
      l :=SIZE(OctLog.ALL_LOGS_REC);  (* ࠧ��� ����� ��� *)
      ime.GetMem(l,Vax_all_logs);
      IF int.ok#0 THEN RETURN 6;END;
-- �஢�ઠ ��
      A_all_logs := iad.ADPC(Vax_all_logs);

      LogIO.read_logs(A_all_logs,FALSE); (* ���뢠���� �������� ��� ��࠭���� *)
(* ���ଠ樨 � ���஢������ �ணࠬ�� � ����饩�� � ��� ���ଠ樥� *)
    IF tls.FindMod('OctLog',com,mod) THEN
      exp.GetLeftValue(com,mod, 'all_logs', recl);
      recr.sort := exp.Address;
      recr.address:=Vax_all_logs;
      IF exp.Assign(recl,recr) THEN
            RETURN 0
      ELSE RETURN 7;
      END;
     ELSE  RETURN msg.ObjectNotFound;
     END;

END Read_Cov;

PROCEDURE Save_Cov():CARDINAL; (* �⪫�砥��� ०��  ����஫� ���஢������*)
                        (* ���࠭����� ᮡ࠭�� ���ᨢ� ���ଠ樨 � 䠩��� *)
BEGIN

     LogIO.write_logs(A_all_logs); RETURN 0;
END Save_Cov;


(*��������� ��䨫�஢���� �ணࠬ�� �������������������������������*)


(* ������� ��ࠬ��� �� ��ப� st, ��稭�� � ����樨 p     *)
PROCEDURE GetParamSt(st-:ARRAY OF CHAR; rp : CHAR; VAR p:CARDINAL; VAR dest:ARRAY OF CHAR);
VAR
  p0 : CARDINAL;
BEGIN
  p0 := 0;
  WHILE (st[p]>' ') & (st[p]#rp) & (st[p]#0C) DO
    dest[p0] := st[p];
    INC(p);
    INC(p0);
  END;
  dest[p0] := 0C;
END GetParamSt;

PROCEDURE GetPSt(st-:ARRAY OF CHAR; rp: CHAR;
               VAR p:CARDINAL;VAR dest:ARRAY OF CHAR): BOOLEAN;
VAR
  p0 : CARDINAL;
BEGIN
  p0 := 0;
  WHILE (st[p]>' ') & (st[p]#'.')&(st[p]#rp) & (st[p]#0C) DO
    dest[p0] := st[p];
    INC(p);
    INC(p0);
  END;
  dest[p0] := 0C;
  IF st[p]=rp THEN RETURN TRUE; ELSE RETURN FALSE; END;
END GetPSt;

PROCEDURE GetPat(st-:ARRAY OF CHAR;
               VAR p:CARDINAL;VAR dest:ARRAY OF CHAR);
VAR
  p0 : CARDINAL;
BEGIN
  p0 := 0;
  WHILE (st[p]>' ') & (st[p]#'.')&(st[p]#'[') & (st[p]#0C) DO
    dest[p0] := st[p];
    INC(p);
    INC(p0);
  END;
  dest[p0] := 0C;
END GetPat;

PROCEDURE IndVar(p: dt.OBJECT;mod : dt.ModNo): CARDINAL;
VAR i : CARDINAL;
    pv : dt.OBJECT;
BEGIN
     FOR i :=0 TO tls.VarsNo(pt.ActiveComponent,mod) DO
        pv := tls.GetVar(pt.ActiveComponent,mod,i);
        IF (p.mod=pv.mod) AND (p.rec=pv.rec) THEN RETURN i;END;
     END;
     ASSERT(FALSE);
END IndVar;

PROCEDURE VarName(s: xs.String;u: dt.ModNo): BOOLEAN;
                      (*  ��ࠡ�⪠ ��ࠬ��� ���=(��� ���1|��� ���2|...   )*)
                      (*                      VAR=(  |   |     |          ) *)

VAR  st,st1,st2: xs.String;
     pos,p,depth,offs,i : CARDINAL;
     pv : dt.OBJECT;
     f,fvar:BOOLEAN;
     base: dit.PTYPE;
     ai : prv.AR_EL;   --;
     ind, res,res1 : exp.ExprRes;
BEGIN    fvar:=FALSE;
      prv.Init;
--      k := exe.VarQuantity(u);    (* �᫮ ��६����� *)
      s[LENGTH(s)-1]:=0C;
      IF (((s[0]='�')AND(s[1]='�')AND(s[2]='�'))
                 OR ((s[0]='V')AND(s[1]='A')AND(s[2]='R')))AND(s[3]='=')
      THEN
         pos := 5;
         WHILE s[pos]#0C DO
           GetParamSt(s,'|',pos,st); (* ��� �뤥���� �� ����� ���� �������*)
           p:=0;depth :=0;
--          WHILE st[p]#0C DO
            GetPat(st,p,st1);
            CASE st[p] OF
            |0C:pv := tls.FindVar(pt.ActiveComponent,u,st);
                IF tls.IsObjectValid(pv) THEN
                 f:= prv.AddVar(pt.ActiveComponent,u,IndVar(pv,u));
                ELSE RETURN FALSE;
                END;
                fvar:=TRUE;
            |'.': INC(p); fvar:=FALSE;
                  exp.GetLeftValue(pt.ActiveComponent,pt.ActiveModule, st1, res);
                  ai[depth].type:=res.var_type;
                  ASSERT(tls.TypeTag(res.var_type,ai[depth].tag));
                  GetPat(st,p,st2);
                  tls.Field_no(res.var_type,ai[depth].ind,sys.ADR(st2),base,offs);
                  INC(res.location,offs);
                  res.var_type:= base;
                --  INC(p);
                  CASE st[p] OF
                  |0C :
                  |'.': INC(depth); INC(p);  (* st2 - ���� 1-����� p -�� ����� ��� *)
                         FOR i:=0 TO p-1 DO
                           st2[i]:=st[i];
                         END; st2[p]:=0C;
                     exp.GetLeftValue(pt.ActiveComponent,pt.ActiveModule,st2,res1);
                     ai[depth].type:=res.var_type;
                     ASSERT(tls.TypeTag(res.var_type,ai[depth].tag));
                     GetPat(st,p,st2);
                     tls.Field_no(res.var_type,ai[depth].ind,sys.ADR(st2),base,offs);
                     INC(res.location,offs);
                     res.var_type:=base;
                     IF st[p]#0C THEN RETURN FALSE; END;

                  |'[': INC(p);INC(depth);
                       IF GetPSt(st,']',p,st2) THEN
                        ai[depth].ind:=con.StrToCard(st2,10,f);
                        ASSERT(tls.TypeTag(res.var_type,ai[depth].tag));
                        ind.sort  := exp.INTval;
                        ind.value := ai[depth].ind;
                        exp.Index(res,ind, res1);res:=res1;
                       ELSE RETURN FALSE;
                       END;
                       IF st[p+1]#0C THEN RETURN FALSE;END;
                  ELSE RETURN FALSE;
                  END;
            |'[': fvar:=FALSE;
                 INC(p);
                 exp.GetLeftValue(pt.ActiveComponent,pt.ActiveModule, st1, res);
                IF GetPSt(st,']',p,st2) THEN
                  ai[depth].ind:=con.StrToCard(st2,10,f);
                  ASSERT(tls.TypeTag(res.var_type,ai[depth].tag));
                  ind.sort  := exp.INTval;
                  ind.value := ai[depth].ind;
                  exp.Index(res,ind, res1);res:=res1;
                  INC(depth); INC(p);
                 ELSE RETURN FALSE;END;
                  CASE st[p] OF
                  |0C:  DEC(depth);
                  |'.':   FOR i:=0 TO p-1 DO
                           st2[i]:=st[i];
                         END; st2[p]:=0C;
                        exp.GetLeftValue(pt.ActiveComponent,pt.ActiveModule,st2,res1);
                        ai[depth].type:=res.var_type;
                        ASSERT(tls.TypeTag(res.var_type,ai[depth].tag));
                        INC(p);
                        GetPat(st,p,st2);
                        IF st[p]#0C THEN RETURN FALSE;END;
                       -- exp.GetLeftValue(pt.ActiveComponent,pt.ActiveModule, st, res);
                        tls.Field_no(res.var_type,ai[depth].ind,sys.ADR(st2),base,offs);
                        INC(res.location,offs);
                        res.var_type:=base;
--                         exp.GetLeftValue(pt.ActiveComponent,pt.ActiveModule, st, res);

                  |'[': INC(p);
                     IF GetPSt(st,']',p,st2) THEN
                       ai[depth].ind:=con.StrToCard(st2,10,f);
                       ASSERT(tls.TypeTag(res.var_type,ai[depth].tag));
                       ind.sort  := exp.INTval;
                       ind.value := ai[depth].ind;
                       exp.Index(res,ind, res1);
                       res:=res1;
                     ELSE RETURN FALSE;
                     END;
                     IF st[p+1]#0C THEN RETURN FALSE;END;
                ELSE RETURN FALSE;
                END;
            ELSE     RETURN FALSE;
            END;
             IF NOT fvar THEN
--              DEC(depth);
              pv := tls.FindVar(pt.ActiveComponent,u,st1);
              IF tls.IsObjectValid(pv) THEN
                 f:= prv.AddIndVar(pt.ActiveComponent,u,IndVar(pv,u),depth,ai,res);
              ELSE RETURN FALSE;
              END;
             END;
--          END;
           INC(pos);
         END;
      ELSE RETURN FALSE;
      END;

  RETURN TRUE;
END VarName;
PROCEDURE Profil(): CARDINAL;
VAR                 (* ���� ��ࠡ��뢠�� ������� ������� MD=<��� 䠩��>,VAR=(;) *)
  mod,com  : CARDINAL;
  st1     :xs.String;        (*     PJ= <��� 䠩��> *)
BEGIN
  IF NOT kex.Loaded THEN RETURN msg.Load_must_be_first END;
  IF NOT GetParam() THEN
       IF pt.ActiveModule # 0 THEN
            lpr.MarkMod(pt.ActiveComponent,pt.ActiveModule); RETURN 0;
       ELSE
        RETURN msg.ExpectedModuleName;
       END;
  ELSE
(* ��ࠡ�⪠ ०��� - ��� ��� ALL - ��䨫�஢���� ��� �����஢
        ��� ��� ��楤�� ��� ���㫥�*)
(* PROFIL ALL[,PROC] *)
    IF (((Param[0]='A')AND(Param[1]='L')AND(Param[2]='L'))
           OR ((Param[0]='�')AND(Param[1]='�')AND(Param[2]='�')))
    THEN
    IF SepParam() THEN
     IF GetParam() THEN
       IF (((Param[0]='P')AND(Param[1]='R')AND(Param[2]='C'))
           OR ((Param[0]='�')AND(Param[1]='�')AND(Param[2]='�')))
       THEN
            lpr.MarkAllProcAllMod(pt.ActiveComponent); RETURN 0;
       ELSE
          RETURN msg.Incorrect_parameter;
       END
     ELSE
          lpr.MarkAllMod(pt.ActiveComponent); RETURN 0;
     END;
    END;
    END;
    IF (((Param[0]='P')AND(Param[1]='R')AND(Param[2]='C'))
           OR ((Param[0]='�')AND(Param[1]='�')AND(Param[2]='�')))
    THEN
       IF pt.ActiveModule # 0 THEN
            lpr.MAllProcMod(pt.ActiveComponent,pt.ActiveModule); RETURN 0;
       ELSE
        RETURN msg.ExpectedModuleName;
       END;
    END;
    IF (((Param[0]='M')AND(Param[1]='D')) OR ((Param[0]='�')AND(Param[1]='�')))
     AND(Param[2]='=') THEN
     str.Extract(Param,3,250,st1);  (* ��� ����� *)
     IF NOT tls.FindMod(st1,com,mod) THEN
     (* �� ������ *) RETURN msg.Module_not_found;
     ELSE pt.ActiveModule := mod; pt.ActiveComponent:=com;
      IF SepParam() THEN
       IF GetParam() THEN
        IF (((Param[0]='P')AND(Param[1]='R')AND(Param[2]='C'))
           OR ((Param[0]='�')AND(Param[1]='�')AND(Param[2]='�')))
        THEN
          lpr.MAllProcMod(pt.ActiveComponent,pt.ActiveModule); RETURN 0;
        END;
       END;
      END;
          lpr.MarkMod(com,mod);
     IF SepParam() THEN
      IF GetParam() THEN
       IF NOT VarName(Param,mod) THEN  RETURN msg.Incorrect_parameter;
        ELSE RETURN 0;
       END;
      END;
      RETURN 0;
     ELSE RETURN 0;
     END;
--     IF EndParam() THEN RETURN 0
     END;
    END;
    IF (((Param[0]='�')AND(Param[1]='�')) OR ((Param[0]='P')AND(Param[1]='J')))
     AND(Param[2]='=') THEN
     str.Extract(Param,3,250,st1);  (* ��� ����� *)
                                 (* st1 - ��� 䠩�� � ०���� ��䨫�஢���� *)
     asp.CheckCond_pack;
     RETURN  wsp.ExtReadFile(st1);
    END;
    IF (((Param[0]='�')AND(Param[1]='�')AND(Param[2]='�'))
        OR ((Param[0]='V')AND(Param[1]='A')AND(Param[2]='R')))AND(Param[3]='=')
    THEN
         IF pt.ActiveModule # 0 THEN
            lpr.MarkMod(pt.ActiveComponent,pt.ActiveModule);
         ELSE
           RETURN msg.ExpectedModuleName;
         END;
         IF NOT VarName(Param,pt.ActiveModule) THEN  RETURN msg.Incorrect_parameter;
          ELSE RETURN 0;
         END;
    ELSE RETURN msg.Incorrect_parameter;
    END;
  END;
 RETURN msg.Incorrect_parameter;
END Profil;

PROCEDURE SavProf(): CARDINAL;   (* ���࠭��� ��䨫� � 䠩�� *)
VAR f : BOOLEAN;
BEGIN
 IF GetParam() THEN  RETURN msg.Expected_end_param  END;

--  FromSaveCheck();
  f := wsp.ActSaveProf(act.prf_5,FALSE);
  RETURN 0;
END SavProf;

(*                                          end CHERN       *)

(* ____________________________________________________________________________END CHERN *)

<* END *>

BEGIN
  Operators := OPERATORS { NIL, 0 };
  TestName := '';
  CurrentBreakNumber := 0;
 <* IF DEST_K26 THEN *>
  AddOperator( '��������',        'SET',        Set);
  AddOperator( '������',          'PUT',        Put);
  AddOperator( '���������',       'GO',         Go);
  AddOperator( '�������',         'BREAK',      Break);
  AddOperator( '�������',         'DEL',        Del);
  AddOperator( '�����',           'GOSUB',      Gosub);
  AddOperator( '�������',         'RETURN',     Return);
  AddOperator( '�������',         'GOTO',       Goto);
  AddOperator( '�����',           'DIR',        Dir);
  AddOperator( '�����',           'LIST',       List);
  AddOperator( '�����',           'TIME',       Ticks);
  AddOperator( '������_��������', 'TEST_BEGIN', TestBegin);
  AddOperator( '�����_��������',  'TEST_END',   TestEnd);
  AddOperator( '������',          'DIAL',       Dialog);
  AddOperator( '���',             'FON',        Fon);
  AddOperator( '������',          'REGFON',     Regfon);
  AddOperator( '�����',           'PAUSE',      Pause);
  AddOperator( '���������',       'LOAD',       LoadProgram);
  AddOperator( '����',            'KOD',        Kod);
  AddOperator( '�����',           'END',        End);
  AddOperator( '����������',      'GOON',       Goon);
  AddOperator( '�_�����',         'GOBACK',     GoBack);
  AddOperator( '����',            'IF',         If);
  AddOperator( '���',             'EQU',        Equiv);
  AddOperator( '������',          'DATA',       Data);
  AddOperator( '������',          'MODEL',      Model);
  AddOperator( '���������',       'MOVE',       Move);
  AddOperator( '���������',       'TRANSFER',   Transfer);
  AddOperator( '��_������',       'ON_ERROR',   JumpByError);
  AddOperator( '�������',         'WATCH',      Watch);
  AddOperator( '������',          'MODULE',     SetActiveModule);
  AddOperator( '������',          'BEEP',       Beep);
  AddOperator( '����������',      'INTER',      SetInterrupt);
  AddOperator( '��������',        'ASSERT',     Assert);
  AddOperator( '�������',         'RESTART',    Restart);
  AddOperator( '����',            'PROC',       ProcModel);
  AddOperator( '��������',        'ALLOCATE',   Allocate);
  AddOperator( '����������',      'DEALLOCATE', Deallocate);
  AddOperator( '���������',       'EXAMINE',    Examine);
  AddOperator( '���������',       'ABOUT',      About);
  AddOperator( '����',            'CALLS',      Calls);
 <* IF SCHERN_K26 THEN *>
  AddOperator( '�������',         'PROFIL',     Profil);
  AddOperator( '���_����',        'SAV_PRF',    SavProf);
  AddOperator( '������_��������', 'INIT_COV',   Init_Cov);
  AddOperator( '��������_������', 'READ_COV',   Read_Cov);
  AddOperator( '�����_��������',  'SAVE_COV',   Save_Cov);
  AddOperator( '����_��',         'TEST_ID',    Init_ID);
  AddOperator( '���_��',          'SAV_ID',     End_ID);
  AddOperator( '�����_���',       'TIME_PRC',   Init_PrcTime);
 <* END *>
 <* ELSIF DEST_XDS THEN *>
  AddOperator( 'SET',             'set',        Set);
  AddOperator( 'PRINT',           'print',      Put);
  AddOperator( 'START',           'start',      Start);
  AddOperator( 'BREAK',           'break',      Break);
  AddOperator( 'DEL',             'del',        Del);
  AddOperator( 'CALL',            'call',       Gosub);
  AddOperator( 'RETURN',          'return',     Return);
  AddOperator( 'GOTO',            'goto',       Goto);
  AddOperator( 'LOG',             'log',        Dir);
  AddOperator( 'MODE',            'mode',       List);
  AddOperator( 'BEGIN',           'begin',      TestBegin);
  AddOperator( 'DIALOG',          'dialog',     Dialog);
  AddOperator( 'FILL',            'fill',       Fon);
  AddOperator( 'PAUSE',           'pause',      Pause);
  AddOperator( 'LOAD',            'load',       LoadProgram);
  AddOperator( 'QUIT',            'quit',       End);
  AddOperator( 'RESUME',          'resume',     Resume);
  AddOperator( 'STOP',            'stop',       GoBack);
  AddOperator( 'IF',              'if',         If);
  AddOperator( 'ALIAS',           'alias',      Equiv);
  AddOperator( 'MOVE',            'move',       Move);
  AddOperator( 'SIGNAL',          'signal',     JumpByError);
  AddOperator( 'WATCH',           'watch',      Watch);
  AddOperator( 'MODULE',          'module',     SetActiveModule);
  AddOperator( 'RESTART',         'restart',    Restart);
  AddOperator( 'BEEP',            'beep',       Beep);
  AddOperator( 'ASSERT',          'assert',     Assert);
  AddOperator( 'ABOUT',           'about',      About);
  AddOperator( 'EXAMINE',         'examine',    Examine);
  AddOperator( 'CALLS',           'calls',      Calls);
  AddOperator( 'DUMPSTACKS',      'dumpstacks', CallsForAllThreads);
  AddOperator( 'EXEC',            'exec',       ExecuteProgram);
  AddOperator( 'CMD',             'cmd',        CmdShell);
 <* END *>
END PckOpers.
