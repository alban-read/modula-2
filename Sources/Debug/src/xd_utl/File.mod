IMPLEMENTATION MODULE File;

IMPORT FileSys;
IMPORT SYSTEM;
IMPORT TimeConv;
IMPORT Strings;

IMPORT xStr;

VAR
  filesep: CHAR;


PROCEDURE ExtensionPos (s-: ARRAY OF CHAR ) : CARDINAL ;
VAR
  c : CHAR ;
  l,i : CARDINAL ;
BEGIN
  l := LENGTH(s) ;
  IF l=0 THEN RETURN MAX(CARDINAL); END ;
  i := l ;
  REPEAT
    DEC(i) ;
    c := s[i] ;
  UNTIL (i=0) OR (c=filesep) OR (c='/') OR (c=':') OR (c='.') ;
  IF (c='.') THEN
    RETURN i;
  ELSE
    RETURN MAX(CARDINAL) ;
  END ;
END ExtensionPos ;


PROCEDURE AddExtension ( VAR s : ARRAY OF CHAR ; ext- : ARRAY OF CHAR ) ;
BEGIN
  IF ExtensionPos(s) = MAX(CARDINAL) THEN
    xStr.Append('.',s) ;
    IF (ext[0]>' ') THEN xStr.Append(ext,s); END;
  END;
END AddExtension ;


PROCEDURE RemoveExtension ( VAR s : ARRAY OF CHAR ) ;
VAR
  p : CARDINAL ;
BEGIN
  p := ExtensionPos(s) ;
  IF p<>MAX(CARDINAL) THEN s[p] := 0C END ;
END RemoveExtension ;


PROCEDURE ChangeExtension ( VAR s : ARRAY OF CHAR ; ext- : ARRAY OF CHAR ) ;
BEGIN
  RemoveExtension(s) ;
  (* Do not use AddExtension(s,ext) here because in case s=="q.q.txt"   *)
  (* RemoveExtension() removes ".txt" to "q.q" and AddExtension() fails *)
  xStr.Append('.',s) ;
  IF (ext[0]>' ') THEN xStr.Append(ext,s); END;
END ChangeExtension ;

(* �����頥� ���७�� ����� 䠩�� *)
PROCEDURE GetExtension (file-: ARRAY OF CHAR; VAR ext: ARRAY OF CHAR);
VAR
  p : CARDINAL ;
BEGIN
  p := ExtensionPos(file);
  IF p <> MAX(CARDINAL) THEN
    xStr.Extract(file, p+1, LENGTH(file), ext);
  ELSE
    ext[0] := '';
  END;
END GetExtension;

(* �஢���� ���७�� ����� 䠩��, �᫨ ᮢ���� - TRUE *)
PROCEDURE CompareExtension (file-, ext-: ARRAY OF CHAR) : BOOLEAN;
VAR
  ext1: ARRAY [0..2] OF CHAR;
BEGIN
  GetExtension(file, ext1);
  IF ext1 = ext THEN RETURN TRUE; ELSE RETURN FALSE; END;
END CompareExtension;

(* �뤥��� �� ������� ��� ��� ��᪠,���� �� ��⠫����,��� 䠩�� *)
PROCEDURE SplitPath (st-:ARRAY OF CHAR; VAR drive,head,tail:ARRAY OF CHAR);
VAR
  i, k, len: CARDINAL;
  findpath : BOOLEAN;
  st2      : xStr.String;
BEGIN
  drive[0] := '';
  head[0] := '';
  tail[0] := '';
  len := LENGTH(st);
  IF (len # 0) THEN
    COPY(st,st2);
    IF filesep # '/' THEN
      FOR i := 0 TO len-1 DO
        IF st2[i] = '\' THEN
          st2[i] := '/'
        END
      END;
    END;
    IF ('A' <= CAP(st[0])) AND (CAP(st[0]) <= 'Z') AND (st[1] = ':') THEN
      xStr.Extract(st, 0, 2, drive);
      k := 2;
    ELSE
      k := 0;
    END;
    Strings.FindPrev('/',st2,(len-1),findpath,i);
    IF findpath AND (i <= len-k+1) THEN INC(i) ELSE i := k; END;
    xStr.Extract(st,i,len-i,tail);
    xStr.Extract(st,k,i-k,head);
  END;
END SplitPath;


(* �뤥��� �� ��� ⮫쪮 ��� 䠩�� *)
PROCEDURE ExtractFileName (path-: ARRAY OF CHAR; VAR fname: ARRAY OF CHAR);
VAR
  to_skip: ARRAY [0..1] OF CHAR; --xStr.String;
BEGIN
  SplitPath(path, to_skip, to_skip, fname);
END ExtractFileName;


(* �६� ����䨪�樨 䠩�� � ᥪ㭤�� *)
PROCEDURE ModifyTime (fname-: ARRAY OF CHAR): CARDINAL;
VAR
  time : CARDINAL;
  exist: BOOLEAN;
BEGIN
  FileSys.ModifyTime (fname, time, exist);
  IF NOT exist THEN time := 0; END;
  RETURN time;
END ModifyTime;


(* �ࠢ����� �६�� ����䨪�樨 䠩���: �᫨ f1 "����" f2 - TRUE *)
PROCEDURE FileOlderThan(fname1-, fname2-: ARRAY OF CHAR) : BOOLEAN;
VAR
  time1, time2: CARDINAL;
  exist: BOOLEAN;
BEGIN
  FileSys.ModifyTime (fname1, time1, exist);
  IF NOT exist THEN RETURN FALSE; END;
  FileSys.ModifyTime (fname2, time2, exist);
  IF NOT exist THEN RETURN FALSE; END;
  IF time1 > time2 THEN RETURN FALSE; END;
  RETURN TRUE;
END FileOlderThan;


(* �८�ࠧ������ �� �।�⠢����� �६��� ����䨪�樨 䠩��,
   �ਭ�⮣� DOS (4 ����, ���祭�� "㯠������") � ᥪ㭤�    *)
PROCEDURE DOS2SEC (t: CARDINAL): CARDINAL;

TYPE
  TimeDOS = RECORD
              CASE :BOOLEAN OF
              | TRUE : tm, dt : SYSTEM.CARD16;
              | FALSE: tm_dt  : CARDINAL;
              END;
            END;
VAR
  T  : TimeDOS;
  DT : TimeConv.DateTime;
  Sec: CARDINAL;

BEGIN
  WITH T DO
    tm_dt := t;
    WITH DT DO
      second := (tm MOD 32)*2; tm:=tm DIV 32;
      minute := tm MOD 64;
      hour   := tm DIV 64;
      day    := dt MOD 32;     dt:=dt DIV 32;
      month  := dt MOD 16;
      year   := dt DIV 16 + 1980;
    END;
  END;
  TimeConv.pack (DT, Sec);
  RETURN Sec;
END DOS2SEC;



(* �८�ࠧ�� ��� 䠩�� �� ᫥���騬 �ࠢ����:                  *)
(* �����            -> �����४���'\'�����           *)
(* �������_�����  -> �����४���'\'�������_����� *)
(* \����멏���         -> ��᪠_����멏���                    *) -- by Shev
(* ��᪠:�������  -> ��᪠_����멏���                    *) -- by Shev
(* ��᪠_����멏��� -> ��᪠_����멏���                    *)
PROCEDURE ModifyFileName (fname-: ARRAY OF CHAR; VAR fullname: ARRAY OF CHAR);
BEGIN
  FileSys.FullName (fullname, fname);
END ModifyFileName;


(* �����頥� ⥪�騩 ࠧ���⥫� ��४�਩ � ����� 䠩�� *)
PROCEDURE GetFileSepChar (): CHAR;
BEGIN
  RETURN filesep;
END GetFileSepChar;


BEGIN
<* IF (env_target = 'linux') OR (env_target = 'x86linux') THEN *>
  filesep := '/';
<* ELSE *>
  filesep := '\';
<* END *>
END File.
