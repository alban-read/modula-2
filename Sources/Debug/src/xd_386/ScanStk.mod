IMPLEMENTATION MODULE ScanStk;

IMPORT sys := SYSTEM;

IMPORT stk := CallStk;

IMPORT xs  := xStr;
IMPORT opt := Options;
IMPORT dsm := Krn_Dasm;
IMPORT kt  := KrnTypes;

IMPORT dt  := DI_Types;
IMPORT tls := DI_Tools;

IMPORT mem := Exe_Mem;


<* NEW dbg_print_stk- *>

<* IF DEFINED (dbg_print_stk) AND dbg_print_stk THEN *>
FROM Printf IMPORT printf;
<* END *>

CONST
  MAX_SCANNABLE_FRAMES = 1000;


PROCEDURE ScanCallStack;


  MODULE AutoSaveRestore;

  IMPORT opt;

  VAR
    tmp: BOOLEAN;
  
  BEGIN
    tmp := opt.DisasmMode;
    opt.DisasmMode := FALSE;
  FINALLY
    opt.DisasmMode := tmp;
  END AutoSaveRestore;



<* IF TARGET_OS = "WINNT" THEN *>
CONST
  KERNEL_ADDR_SPACE = 0FFFFH;
<* END *>

VAR
  top        : kt.ADDRESS; -- �����誠 �⥪�
  bottom     : kt.ADDRESS; -- ��� �⥪�

  -- �஢����, ���� �� ������� ���� ret ���ᮬ ������ �� �������,
  -- �����।�⢥��� ᫥������ �� �����-���� �������� call. �᫨ ⠪, �
  -- �����頥� ���� ������� call � �� ��㬥��, �᫨ �� ��������.
  -- � ��砥, ����� ��㬥�� ���᫨�� �����, ��୥� NIL_ADDRESS.
  PROCEDURE IsCall (ret_addr: kt.ADDRESS; VAR call_point: kt.ADDRESS; VAR len: CARDINAL): BOOLEAN;
  TYPE
    RAW = ARRAY [0..6] OF sys.CARD8;
    BYTES = SET OF sys.CARD8;
  VAR
    raw: RAW;
    prel: POINTER TO CARDINAL;
  BEGIN
    call_point := kt.NIL_ADDRESS;
    len := 0;

   <* IF TARGET_OS = "WINNT" THEN *>
    -- ��� �� ��� ���� �ࠢ����, ������ � �� ����樨����� ��⥬�?
    IF ret_addr < KERNEL_ADDR_SPACE THEN
      RETURN FALSE;
    END;
   <* END *>
    -- �।��������� ���� ������ �� �⥪�?!
    IF (top <= ret_addr) AND (ret_addr <= bottom) THEN
      RETURN FALSE;
    END;
    -- �஢�ਬ, 㪠�뢠�� �� ���� � ᥣ���� ���� �ணࠬ��
    IF NOT mem.IsAddrFromExecutableSeg (ret_addr) THEN
      RETURN FALSE;
    END;

    len := 7;
    raw := RAW {0 BY 7};
    LOOP
      IF mem.Get_Special (ret_addr-len, sys.ADR (raw[7-len]), len, FALSE, TRUE) THEN
        EXIT;
      END;
      IF len = 2 THEN
        -- ����� �� ࠧ���� ������ call �� �뢠��
        RETURN FALSE;
      END;
      DEC (len);
    END;

    IF (raw[5] = 0FFH) AND
      NOT (raw[6] IN BYTES {14H, 15H, 0D4H}) AND
      ((raw[6] DIV 8) IN BYTES {02H, 1AH})
    THEN
      len := 2;
      RETURN TRUE;
    END;

    IF raw[4] = 0FFH THEN
      IF raw[5] # 54H THEN
        IF (raw[5] DIV 8) = 0AH THEN
          len := 3;
          RETURN TRUE;
        END;
        IF (raw[5] = 14H) AND ((raw[6] MOD 8) # 5) THEN
          len := 3;
          RETURN TRUE;
        END;
      END;
    END;

    IF (raw[3] = 0FFH) AND (raw[4] = 54H) THEN
      len := 4;
      RETURN TRUE;
    END;

    IF raw[2] = 0E8H THEN
      prel := sys.ADR (raw[3]);
      <* PUSH *>
      <* COVERFLOW- *>
      call_point := ret_addr + prel^;
      <* POP *>
      len := 5;
      RETURN mem.IsAddrFromExecutableSeg (call_point);
    END;

    IF raw[1] = 0FFH THEN
      IF raw[2] = 15H THEN
        prel := sys.ADR (raw[3]);
        len := 6;
        -- ��� � �⮬ ��砥 ���� ���室� 㦥 ��� ᬥ������!
        IF NOT mem.Get (prel^, sys.ADR (call_point), SIZE (call_point)) THEN
          call_point := kt.NIL_ADDRESS;
        END;
        RETURN TRUE;
      ELSIF raw[2] # 94H THEN
        IF sys.SET8(raw[2]) * sys.SET8(0F8H) = sys.SET8(090H) THEN
          len := 6;
          RETURN TRUE;
        END;
      END;
    END;

    IF (raw[0] = 0FFH) AND (raw[1] = 94H) THEN
      len := 7;
      RETURN TRUE;
    END;

    RETURN FALSE;
  END IsCall;



  PROCEDURE FindProc (addr: kt.ADDRESS): dt.OBJECT;
  VAR
    com, mod: CARDINAL;
  BEGIN
    IF tls.FindModByAddr (addr, com, mod) THEN
      RETURN tls.FindProcByAddr (com, mod, addr);
    END;
    RETURN dt.Invalid_Object;
  END FindProc;


  PROCEDURE FindProcBegin (proc: dt.OBJECT): kt.ADDRESS;
  VAR
    procBegin: kt.ADDRESS;
  BEGIN
    IF tls.IsObjectValid (proc) THEN
      ASSERT (tls.ObjectAddr (proc, procBegin));
      RETURN procBegin;
    END;
    RETURN kt.NIL_ADDRESS;
  END FindProcBegin;



  CONST
    -- push ebp
    -- move ebp, esp
    InitFrameCode = 0EC8B55H;


  PROCEDURE HasFrame (proc: dt.OBJECT; procBegin: kt.ADDRESS): BOOLEAN;
  VAR
    tmp: CARDINAL;
  BEGIN
    IF tls.IsObjectValid (proc) AND tls.ProcHasFrame (proc) THEN
      RETURN TRUE;
    ELSIF procBegin = kt.NIL_ADDRESS THEN
      RETURN FALSE;
    END;
    tmp := 0;
    RETURN mem.Get (procBegin, sys.ADR(tmp), 3) AND (tmp = InitFrameCode);
  END HasFrame;


  PROCEDURE FrameInitialized (procBegin, ip: kt.ADDRESS): BOOLEAN;
  BEGIN
    RETURN procBegin+3 <= ip;
  END FrameInitialized;


  PROCEDURE FindProcBeginByFrameCode (code: kt.ADDRESS): kt.ADDRESS;
  CONST
    N_code = 128;
  VAR
   <* PUSH *>
   <* ALIGNMENT = "4" *>
    code_seg: ARRAY [0..N_code-1] OF sys.CARD8;
   <* POP *>
    disasm_pos : kt.ADDRESS;
    error      : BOOLEAN;
    asm, info  : xs.String;
    len        : CARDINAL;
    frame_found: BOOLEAN;
    frame_addr : kt.ADDRESS;
  BEGIN
-- ������ �� �஢�ઠ ��⪮ �ମ���, ⠪ �� ������⭮, ����� ���� �� �⮨�
-- �몫���� �� 䨣? �����筮 ��� �⮣� �᪮�������� ��ப� ����.
--    RETURN kt.NIL_ADDRESS;
   <* IF DEFINED (dbg_print_stk) AND dbg_print_stk THEN *>
    printf (">>> FindProcBeginByFrameCode (0x%$8X)\n", code);
   <* END *>
    -- �஢�ਬ, �� �⮨� �� 㦥 �� ��砫� ��楤���
    frame_found := HasFrame (dt.Invalid_Object, code);
    IF frame_found OR (code < N_code) THEN
      RETURN code;
    END;
    -- �ਤ���� �᪠�� ��� �� ����
    disasm_pos := code-N_code;
    IF NOT mem.Get (disasm_pos, sys.ADR(code_seg), N_code) THEN
      RETURN kt.NIL_ADDRESS;
    END;
    frame_addr := kt.NIL_ADDRESS;
    WHILE disasm_pos < code DO
      error := NOT dsm.Disasm (disasm_pos, FALSE, asm, info, len);
      IF error THEN
       <* IF DEFINED (dbg_print_stk) AND dbg_print_stk THEN *>
        printf ("0x%$8X ???\n", disasm_pos);
       <* END *>
        len := 1;
        frame_found := FALSE;
      ELSE
       <* IF DEFINED (dbg_print_stk) AND dbg_print_stk THEN *>
        printf ("0x%$8X %-40s %s\n", disasm_pos, asm, info);
       <* END *>
        IF frame_found THEN
          IF dsm.IsRet (disasm_pos) THEN
            frame_found := FALSE;
          END;
        ELSIF HasFrame (dt.Invalid_Object, disasm_pos) THEN
          frame_found := TRUE;
          frame_addr := disasm_pos;
        END;
      END;
      INC (disasm_pos, len);
    END;
    IF (disasm_pos = code) AND frame_found THEN
      RETURN frame_addr;
    END;
    RETURN kt.NIL_ADDRESS;
  END FindProcBeginByFrameCode;



  PROCEDURE GetFrameSize (proc: dt.OBJECT): CARDINAL;
  VAR
    i        : CARDINAL;
    max_size : CARDINAL;
    offs     : CARDINAL;
    local    : dt.OBJECT;
    local_tag: dt.SYM_TAG;
    reg_no   : CARDINAL;
    ref      : BOOLEAN;
    addr     : kt.ADDRESS;
   <* IF DEFINED (dbg_print_stk) AND dbg_print_stk THEN *>
    name     : xs.String;
   <* END *>
  BEGIN
    IF NOT tls.IsObjectValid (proc) THEN
      RETURN 0;
    END;
    max_size := tls.ProcFrameSize (proc);
    IF max_size > 0 THEN
      RETURN max_size;
    END;
    FOR i := 1 TO tls.LocalVarsNo (proc) DO
      local := tls.GetLocalVar (proc, i-1);
      ASSERT (tls.ObjectTag (local, local_tag));
      IF local_tag = dt.Sy_Relative THEN
        ASSERT (tls.GetLocalObject_Reg (local, reg_no, ref));
        IF reg_no = kt.FRAME_REG THEN
          ASSERT (tls.GetLocalObject_Addr (local, MAX (CARDINAL), addr));
          -- ��᪮��� �� ������ ����� ��� �� �⥪�, 祬 ���� ������
          -- �� ᬥ饭�� � ������� ������ ���� ����⥫�묨
          offs := MAX (CARDINAL) - CARDINAL (addr);
         <* IF DEFINED (dbg_print_stk) AND dbg_print_stk THEN *>
          tls.ObjectName (local, name);
          printf ("offs=%d name=%s\n", offs, name);
         <* END *>
          IF (max_size < offs) AND (offs < MAX(INTEGER)) THEN
            max_size := offs;
          END;
        END;
      END;
    END;
    RETURN (max_size DIV 4) * 4;
  END GetFrameSize;


 <* IF DEFINED (dbg_print_stk) AND dbg_print_stk THEN *>
  PROCEDURE PrintCurrProc (proc: dt.OBJECT; code, frame: kt.ADDRESS);
  VAR
    name: xs.String;
  BEGIN
    printf ("code=0x%$8X frame=0x%$8X", code, frame);
    IF tls.IsObjectValid (proc) THEN
      tls.ObjectName (proc, name);
      printf (" -> 0x%$8X %s", FindProcBegin (proc), name);
    END;
    printf ("\n");
  END PrintCurrProc;
 <* END *>


VAR
  scan_pos   : kt.ADDRESS; -- ⥪�饥 ��������� � �⥪� �� ᪠��஢����
  code       : kt.ADDRESS; -- ���� ����� ⥪�饩 ��楤���
  proc       : dt.OBJECT;  -- ⥪��� ��楤��
  procBegin  : kt.ADDRESS; -- ���� ��砫� ⥪�饩 ��楤���
  frame      : kt.ADDRESS; -- ���祭�� ���� ⥪�饩 ��楤���
  hasFrame   : BOOLEAN;    -- �ନ��� �� ⥪��� ��楤�� ����?
  saved_frame: kt.ADDRESS; -- ��࠭����� ���祭�� ���� ��뢠�饩 ��楤���
  ret        : kt.ADDRESS; -- �।��������� ���� ������
  call       : kt.ADDRESS; -- ���� ���� �맮�� ⥪�饩 ��楤���
  likely_call: BOOLEAN;    -- ���室�饥 ���� �맮��
  undef_call : BOOLEAN;    -- �� �� �맮� �������� call � ����।��塞� ��㬥�⮬?
  top_call   : BOOLEAN;    -- ⥪��� ��楤�� �� �����誥 �⥪� �맮���
  len        : CARDINAL;
  access     : kt.ATTRIBS;

  tmp_code      : kt.ADDRESS;
  tmp_proc      : dt.OBJECT;
  tmp_procBegin : kt.ADDRESS;
  tmp_frame     : kt.ADDRESS;
  tmp_hasFrame  : BOOLEAN;
  tmp_undef_call: BOOLEAN;

  numberOfFrames :CARDINAL;
BEGIN
 <* IF DEFINED (dbg_print_stk) AND dbg_print_stk THEN *>
  printf (">>> ScanCallStack\n");
 <* END *>



  -- ��।���� ��ࠬ���� �⥪� ������
  top := mem.GetSP ();
  IF NOT mem.GetSegmentInfo (top, bottom, len, access) THEN
    RETURN;
  END;
  INC (bottom, len);
  -- �᫨ �⥪ �� �맮����, �� �����-� �᪫��⥫쭠� �����
  -- ���� ��஢�塞 �⥪ ����, �⮡� ��᫥���訥 ������ ��� ࠡ����
  top := top - (top MOD 4);

  -- ��।���� ⥪���� ��楤���, � ���ன ��室���� �ᯮ��塞� ����
  frame := top;
  code := mem.GetIP ();
  proc := FindProc (code);
  IF tls.IsObjectValid (proc) THEN
    procBegin := FindProcBegin (proc);
  ELSE
    procBegin := FindProcBeginByFrameCode (code);
  END;
  hasFrame := HasFrame (proc, procBegin);
  IF hasFrame THEN
    IF tls.IsObjectValid (proc) AND tls.AddrInProcBody (proc, code) THEN
      -- ����� �筮 ��।����� ������ ����
      frame := mem.GetFrame ();
      -- ᪠��஢���� ����� ����� ���� ���� �� �⥪�, ⠪ ��� �� �����誥 ebp
      scan_pos := frame+4;
    ELSE
      scan_pos := frame;
    END;
  ELSIF tls.IsObjectValid (proc) AND tls.AddrInProcBody (proc, code) THEN
    -- �� �㦭� ᪠��஢��� ������ ��楤���
    INC (frame, GetFrameSize (proc));
    scan_pos := frame;
  ELSE
    scan_pos := frame;
  END;
  -- �⥪ �� x86 ��஢��� �� 4
  ASSERT (scan_pos MOD 4 = 0);

  undef_call := FALSE;
  top_call := TRUE;

  numberOfFrames := 0;

  LOOP
    IF (scan_pos >= bottom) OR (numberOfFrames >= MAX_SCANNABLE_FRAMES) THEN
      EXIT;
    END;
    -- ����� � �⥪� ����, ����� �� ������ ���� �訡��,
    -- ⠪ ��� �⥪ �ᥣ�� ������ ���� ����㯥� �� �⥭��
    ret := kt.NIL_ADDRESS;
    ASSERT (mem.Get_Special (scan_pos, sys.ADR (ret), 4, TRUE, FALSE));
    IF IsCall (ret, call, len) THEN
      -- �맮� �������� call � ����।��塞� ��㬥�⮬?
      tmp_undef_call := undef_call OR (call = kt.NIL_ADDRESS);
      -- �� �᫮���, �� �� �� �뫮 �� ������ �맮�� � ����।��塞�
      -- ��㬥�⮬, �஢�ਬ, �� ���� �맮�� ᮢ������ � ⥪�饩 (�맢�����)
      -- ��楤�ன, ���� ��� �맮� - � ���� �� �⥪�.
      IF tmp_undef_call OR (procBegin = kt.NIL_ADDRESS)
        OR (procBegin = call) OR (procBegin = dsm.IsJmpForDll (call))
      THEN
        -- ���� ���⠪�!
        likely_call := TRUE;

        -- ���室�騩 �������� �� �맢����� ��楤���
        tmp_code := ret-len;
        tmp_proc := FindProc (tmp_code);
        IF tls.IsObjectValid (tmp_proc) THEN
          tmp_procBegin := FindProcBegin (tmp_proc);
        ELSE
          tmp_procBegin := FindProcBeginByFrameCode (tmp_code);
        END;
        tmp_hasFrame := HasFrame (tmp_proc, tmp_procBegin);
        tmp_frame := scan_pos;

        saved_frame := kt.NIL_ADDRESS;

        -- �᫨ ⥪��� ��楤�� ����� ����...
        IF hasFrame THEN
          -- ...� �� �⮬ �ன���� ���樠������ ���� ��� ⥪�饩 ��楤���
          IF NOT top_call
            OR FrameInitialized (procBegin, code)
          THEN
            -- ...� ���� ���� - �� ������� ret, �.�. ����室��� "�������"
            -- �⥪ �� ����, ��� ������ ret, ����� �� ���� ����� �⥪�.
            DEC (tmp_frame, 4);
            -- �஢�ਬ, �� �������� ���� ������ �� ⥪�饩 ��楤���
            -- ��室���� ��� �� �⥪� ��࠭������ ��᫥ ���樠����樨 ����
            -- ��뢠�饩 ��楤���, � ��⨢��� ��砥 �� ����, � �� ��������
            IF tmp_hasFrame THEN
              ASSERT (mem.Get_Special (tmp_frame, sys.ADR (saved_frame), 4, TRUE, FALSE));
              -- ��࠭���� ���� ���� ��뢠���� ��楤��� ������
              -- 㪠�뢠�� � �⥪
              IF (top <= saved_frame) AND (saved_frame <= bottom) THEN
                -- � ��砫� ᠬ��� ���� ��뢠���� ��楤��� ������ ���� ����
                -- �� �⥪�, 祬 ��࠭���� � �⥪� ���� ������
                likely_call := scan_pos < saved_frame;
              ELSE
                saved_frame := kt.NIL_ADDRESS;
              END;
            END;
          END;
        END;

        IF likely_call THEN
          -- �����: ����� �ᯮ������ ⮫쪮 �� ���᫥��� tmp_frame
          frame := tmp_frame;
          stk.AddCall (code, frame);
         <* IF DEFINED (dbg_print_stk) AND dbg_print_stk THEN *>
          PrintCurrProc (proc, code, frame);
         <* END *>

          frame := saved_frame;
          IF frame # kt.NIL_ADDRESS THEN
            -- �����஢���� ����� ����� � ��࠭������ ���� ��楤���.
            -- �� �०�� �஢�ਬ, �� �ᯮ��塞� ���� ����� ⥫� ⥪�饩
            -- ��楤��� �� �����誥 �⥪� �맮��� - �� ��࠭����, �� ��
            -- �� �뫠 �ᯮ����� ������� pop ebp �����।�⢥��� ��। ret.
            IF top_call THEN
              IF tls.IsObjectValid (proc) AND tls.AddrInProcBody (proc, code) THEN
                -- scan_pos �ࠧ� �த�������� �� ret �맢��饩 ��楤���!
                scan_pos := frame;
              ELSE
              -- � ��⨢��� ��砥 ����� ��࠭�஢���, �� pop ebp
              -- �� �� �ᯮ�������. ����� �㦭� ����� ᪠��஢����
              -- � �����饣� �����. � ��� ����� ���� ����, �� ��
              -- �१��砩�� ��������⭮.
                scan_pos := frame-4;
              END;
            ELSE
              -- ��� 㦥 �ந��樠����஢��
              scan_pos := frame;
            END;
          ELSIF NOT top_call
            OR tls.IsObjectValid (tmp_proc) AND tls.AddrInProcBody (tmp_proc, tmp_code)
            OR NOT tls.IsObjectValid (tmp_proc) AND FrameInitialized (tmp_procBegin, tmp_code)
          THEN
            -- ��� ������, �� �㦭� ᪠��஢��� ������ ��楤���
            len := GetFrameSize (tmp_proc);
            INC (scan_pos, len);
          END;

          -- ��८�।���� ⥪���� ��楤���
          code := tmp_code;
          proc := tmp_proc;
          procBegin := tmp_procBegin;
          top_call := FALSE;
          hasFrame := tmp_hasFrame;
          undef_call := tmp_undef_call;
        END;
      END;
    END;
    -- �த����� ᪠��஢����
    INC (scan_pos, 4);
    INC (numberOfFrames);
  END;
  stk.AddCall (code, frame);
 <* IF DEFINED (dbg_print_stk) AND dbg_print_stk THEN *>
  PrintCurrProc (proc, code, frame);
 <* END *>
END ScanCallStack;



END ScanStk.
