<*+NOREGVARS*>

MODULE LinkProc;

IMPORT ir,
       gr := ControlGraph,
       pc := pcK,
       Calc,
       Color,
       at := opAttrs,
       Emit,
       CodeDef,
       RD := RDefs,
       nts := BurgNT,

<* IF ~ nodebug THEN *>
       opIO,
<* END *>
       FormStr,
       SYSTEM,
       prc := opProcs;

IMPORT R := r386;
IMPORT D := desc386;

TYPE
    INT         = ir.INT;
    TriadePtr   = ir.TriadePtr;
    Node        = ir.Node;
    Local       = ir.Local;
    VarNum      = ir.VarNum;
    RegPlacement    = Emit.RegPlacement;

--------------------------------------------------------------------------------
CONST NTstm=      nts.NTstm;
CONST NTreg=      nts.NTreg;
CONST NTrc=       nts.NTrc;
CONST NTmrc=      nts.NTmrc;
CONST NTmem=      nts.NTmem;
CONST NTbased=    nts.NTbased;
CONST NTscaled=   nts.NTscaled;
CONST NTaddr=     nts.NTaddr;
CONST NTlocal=    nts.NTlocal;
CONST NTtos=      nts.NTtos;
CONST NTconst=    nts.NTconst;
CONST NTimem=     nts.NTimem;

CONST
    NOP = 90X;
    UNDEF_REG    = D.UNDEF_REG;
    CODE_ALIGN_A = 4; -- ��ࠢ������� � ��ᥬ����

PROCEDURE InitGenProc*;
VAR i: ir.TSNode;
    n: Node;
BEGIN
    FOR i:=ir.StartOrder TO SYSTEM.PRED(LEN(ir.Order^)) DO
        n := ir.Order^[i];
        RD.NodeInfo^[n].j := D.NoJ;
        RD.NodeInfo^[n].l := 0;
        IF at.GENASM IN at.COMP_MODE THEN
            RD.NodeInfo^[n].lb := Emit.UNDEF_LABEL;
            RD.NodeInfo^[n].ca := Emit.UNDEF_LABEL;
        END;
        CodeDef.new_segm (RD.NodeInfo^[n].sg);
    END;

    Emit.work.InitGenSkipTrap();

END InitGenProc;

--------------------------------------------------------------------------------

PROCEDURE ClearUltimateRegContents*;
VAR n: ir.Node;
    i: ir.TSNode;
    j : D.Reg;
BEGIN
    FOR i:=ir.StartOrder TO VAL(ir.TSNode,SYSTEM.PRED(ir.Nnodes)) DO
        n := ir.Order^[i];
        FOR j:=D.MINREG TO D.MAXREG DO
            RD.NodeInfo^[n].ultimateRegContents[j] := ir.UNDEFINED;
        END;
    END;
END ClearUltimateRegContents;

--------------------------------------------------------------------------------

PROCEDURE HasCode (n: Node): BOOLEAN;
BEGIN
    RETURN (ir.Nodes^[n].Last^.Op <> ir.o_goto) OR
           NOT Emit.work.EmptySegment (n, RD.NodeInfo^[n].sg);
END HasCode;

--------------------------------------------------------------------------------
(*
  ����冷��� ᥣ�����; ������஢���, �᫨ ����, �᫮���
*)

PROCEDURE SortSegments;
VAR
  t: Color.GenOrdNode;
  n: Node;
 <* IF DEFINED(OVERDYE) AND OVERDYE THEN *> -- FIXME
  i: INT;
  k: INT;
 <* END *>
BEGIN
    Color.GenSort (HasCode);
   <* IF DEFINED(OVERDYE) AND OVERDYE THEN *> -- FIXME
    IF at.DbgRefine IN at.COMP_MODE THEN
      od.AccurateNodePosOrder;
      -- AVY: epilogue must be last node in all cases
      Color.GenOrder^[Color.EndGenOrder] := CodeDef.ret_node;
      -- AVY: prologue must be first node in all cases
      Color.GenOrder^[Color.StartGenOrder] := 0;
      k := 0;
      FOR i := 0 TO LEN(od.NodePosOrder^)-1 DO
        n := od.NodePosOrder[i];
        -- first and last node is already added
        IF (n # 0) AND (n # CodeDef.ret_node) THEN
          INC(k);
          Color.GenOrder^[Color.StartGenOrder+k] := n;
        END;
      END;
    END;
   <* END *>
    FOR t:=Color.StartGenOrder TO Color.EndGenOrder DO
        n := Color.GenOrder^[t];        RD.NodeInfo^[n].l := 0;
        IF RD.NodeInfo^[n].j <> D.NoJ THEN
            RD.NodeInfo^[n].l1 := FALSE;
            RD.NodeInfo^[n].l2 := FALSE;
            RD.NodeInfo^[n].j2 := FALSE;
            RD.NodeInfo^[n].a  := 0;
            IF RD.NodeInfo^[n].j = D.UnJ THEN
                IF (t <> Color.EndGenOrder) &
                   (Color.To (ir.Nodes^[n].OutArcs^[0], HasCode) =
                    Color.GenOrder^[SYSTEM.SUCC(t)])
                THEN
                    RD.NodeInfo^[n].j := D.NoJ;
                END;
            ELSIF (t <> Color.EndGenOrder) &
                  (Color.To (ir.Nodes^[n].OutArcs^[0], HasCode) =
                   Color.GenOrder^[SYSTEM.SUCC(t)])
            THEN
                RD.NodeInfo^[n].j := Emit.InverseCond (RD.NodeInfo^[n].j);
                RD.NodeInfo^[n].a := 1;
            ELSIF (t = Color.EndGenOrder) OR
                  (Color.To (ir.Nodes^[n].OutArcs^[1], HasCode) <>
                   Color.GenOrder^[SYSTEM.SUCC(t)])
            THEN
                RD.NodeInfo^[n].j2 := TRUE;
                IF (ir.Nodes^[n].LoopNo <> ir.UndefLoop) &
                   gr.NodeInLoop (Color.To (ir.Nodes^[n].OutArcs^[1],
                                            HasCode),
                                  ir.Nodes^[n].LoopNo)
                THEN
                    RD.NodeInfo^[n].j := Emit.InverseCond (RD.NodeInfo^[n].j);
                    RD.NodeInfo^[n].a := 1;
                END;
            END;
        END;
    END;
END SortSegments;

--------------------------------------------------------------------------------
(*

changed to call of CodeDef.EqualSegments

PROCEDURE EqSegments (s1, s2: CodeDef.CODE_SEGM): BOOLEAN;
VAR i: INT;
BEGIN
    IF (s1^.code_len <> s2^.code_len) OR (s1^.fxup_len <> s2^.fxup_len) THEN
        RETURN FALSE;
    END;
    IF at.GENASM IN at.COMP_MODE THEN
        FOR i:=0 TO s1^.code_len-1 DO
            IF s1^.acode^[i] <> s2^.acode^[i] THEN
                RETURN FALSE;
            END;
        END;
    ELSE
        FOR i:=0 TO s1^.code_len-1 DO
            IF s1^.bcode^[i] <> s2^.bcode^[i] THEN
                RETURN FALSE;
            END;
        END;
    END;
    FOR i:=0 TO s1^.fxup_len-1 DO
        IF (s1^.fxup^[i].obj     <> s2^.fxup^[i].obj)    OR
           (s1^.fxup^[i].fx_offs <> s2^.fxup^[i].fx_offs) OR
           (s1^.fxup^[i].offs    <> s2^.fxup^[i].offs)   OR
           (s1^.fxup^[i].kind    <> s2^.fxup^[i].kind)
        THEN
            RETURN FALSE;
        END;
    END;
    RETURN TRUE;
END EqSegments;
*)
--------------------------------------------------------------------------------

(*
  ��ꥤ����� ⥪��㠫쭮 ᮢ�����騥 ᥣ�����
*)

PROCEDURE UniteSegments;
VAR i:      Color.GenOrdNode;
    n1, n2: Node;
BEGIN
    i := Color.StartGenOrder;
    WHILE i < Color.EndGenOrder DO
        n1 := Color.GenOrder^[i];
        n2 := Color.GenOrder^[SYSTEM.SUCC(i)];
        IF (ir.Nodes^[n1].Last <> NIL) & (ir.Nodes^[n2].Last <> NIL) &
           (ir.Nodes^[n1].NOut = 0) & (ir.Nodes^[n2].NOut = 0) &
           ((at.COMP_MODE * at.CompModeSet{at.debug, at.lineno, at.history} = at.CompModeSet{}) OR
            (ir.Nodes^[n1].Last^.Op <> ir.o_error) &
            (ir.Nodes^[n1].Last^.Op <> ir.o_stop)) &
           CodeDef.EqualSegments (RD.NodeInfo^[n1].sg, RD.NodeInfo^[n2].sg)
        THEN
            CodeDef.new_segm (RD.NodeInfo^[n1].sg);
        END;
        INC (i);
    END;
END UniteSegments;

--------------------------------------------------------------------------------

(*
  �㦭� �� ��ࠢ������ ������� ���⮪ �� ��-�� �室� � 横�,
  � ⮫쪮 ��⮬�, �� �।��騩 �� "�஢���������" �� ����?
*)

PROCEDURE IsJmpNode (n: Node): BOOLEAN;
BEGIN
    RETURN (RD.NodeInfo^[n].j = D.UnJ) OR
           (ir.Nodes^[n].Last = NIL) OR
           (ir.Nodes^[n].Last^.Op = ir.o_case)   OR
           (ir.Nodes^[n].Last^.Op = ir.o_ret)    OR
           (ir.Nodes^[n].Last^.Op = ir.o_retfun) OR
           (ir.Nodes^[n].Last^.Op = ir.o_error)  OR
           (ir.Nodes^[n].Last^.Op = ir.o_stop);
END IsJmpNode;

-------------------------------------------------------------------------------
(*
  �㦭� �� ��ࠢ������ ������� ���⮪?
*)

PROCEDURE NeedAlignment (i: Color.GenOrdNode): BOOLEAN;
VAR n1, n2: Node;
BEGIN
    IF (at.SPACE IN at.COMP_MODE) OR (i = Color.EndGenOrder) THEN
        RETURN FALSE;
    END;
    n1 := Color.GenOrder^[i];
(*
    IF IsJmpNode (n1) THEN
        RETURN TRUE;
    END;
*)
    n2 := Color.GenOrder^[SYSTEM.SUCC(i)];
    RETURN ir.Nodes^[n2].Nesting > ir.Nodes^[n1].Nesting;
END NeedAlignment;

--------------------------------------------------------------------------------

(*
  ���᫨�� ����� ���室��; ���⨢�� �����
*)

PROCEDURE CalcJumpsB;
VAR j, l, ll: INT;
    i: Color.GenOrdNode;
    n:       Node;
    Changed, cc: BOOLEAN;
BEGIN
    ASSERT(~(at.GENASM IN at.COMP_MODE));
    REPEAT
        l := 0;
        FOR i:=Color.StartGenOrder TO Color.EndGenOrder DO
            n := Color.GenOrder^[i];
            RD.NodeInfo^[n].o := l;
            INC (l, RD.NodeInfo^[n].sg.code_len);
            IF RD.NodeInfo^[n].j <> D.NoJ THEN
                IF RD.NodeInfo^[n].l1 THEN
                    IF RD.NodeInfo^[n].j = D.UnJ THEN
                        INC (l, 5);
                    ELSE
                        INC (l, 6);
                    END;
                ELSE
                    INC (l, 2);
                END;
                IF RD.NodeInfo^[n].j2 THEN
                    IF RD.NodeInfo^[n].l2 THEN
                        INC (l, 5);
                    ELSE
                        INC (l, 2);
                    END;
                END;
            END;
            IF NeedAlignment (i) THEN
                l := ((l + 3) DIV 4) * 4;
            END;
        END;

        Changed := FALSE;
        FOR i:=Color.StartGenOrder TO Color.EndGenOrder DO
            n := Color.GenOrder^[i];

            -- *shell
            IF at.OptimizeTraps IN at.COMP_MODE THEN
              Changed := Emit.work.CalcSkipTrapJumps(i) OR Changed;
            END;

            IF RD.NodeInfo^[n].j <> D.NoJ THEN
                l := RD.NodeInfo^[n].o + RD.NodeInfo^[n].sg.code_len;
                IF RD.NodeInfo^[n].l1 THEN
                    IF RD.NodeInfo^[n].j = D.UnJ THEN
                        INC (l, 5);
                    ELSE
                        INC (l, 6);
                    END;
                ELSE
                    j := RD.NodeInfo^[
                             Color.To (ir.Nodes^[n].OutArcs^[RD.NodeInfo^[n].a],
                                       HasCode)].o - l - 2;
                    IF (j < -128) OR (j > 127) THEN
                        RD.NodeInfo^[n].l1 := TRUE;
                        Changed := TRUE;
                    END;
                    INC (l, 2);
                END;
                IF RD.NodeInfo^[n].j2 & NOT RD.NodeInfo^[n].l2 THEN
                    j := RD.NodeInfo^[
                            Color.To (ir.Nodes^[n].OutArcs^[1-RD.NodeInfo^[n].a],
                                      HasCode)].o - l - 2;
                    IF (j < -128) OR (j > 127) THEN
                        RD.NodeInfo^[n].l2 := TRUE;
                        Changed := TRUE;
                    END;
                END;
            END;
        END;
    UNTIL NOT Changed;
END CalcJumpsB;

--------------------------------------------------------------------------------

(*
  AVY: ����⢥��� ᣥ���஢��� ���室�
  ��� ��� ���室� �� ����஢���� ���� ����� ᮧ������
  ����প�, ��砫� �������� ���⪮� ��ࠢ�������� �� �࠭���
  ᫮��. ��-�� �⮣� ����� �।��饣� ��������� ���⪠ ����������
  NOP, �᫨ �ࠢ����� �㤠 ������� �� ��������, ���� ��
  ����� "����������" �������� ���室�饩 �����.
*)

PROCEDURE GenJumpsB(): INT;
VAR j, l: INT;
    i: Color.GenOrdNode;
    n:       Node;
BEGIN
    FOR i:=Color.StartGenOrder TO Color.EndGenOrder DO
        n := Color.GenOrder^[i];
        l := RD.NodeInfo^[n].o + RD.NodeInfo^[n].sg.code_len;
        Emit.work.SetSegment (n, RD.NodeInfo^[n].sg);
        IF RD.NodeInfo^[n].j <> D.NoJ THEN
            IF RD.NodeInfo^[n].l1 THEN
                IF RD.NodeInfo^[n].j = D.UnJ THEN
                    INC (l, 5);
                ELSE
                    INC (l, 6);
                END;
            ELSE
                INC (l, 2);
            END;
            j := RD.NodeInfo^[Color.To (ir.Nodes^[n].OutArcs^[RD.NodeInfo^[n].a],
                                     HasCode)].o - l;
            IF (ir.Nodes^[n].Last <> NIL) AND (RD.NodeInfo^[n].j = D.UnJ) AND
               NOT ir.Nodes^[n].Last.Position.IsNull()
            THEN
              -- AVY: ����᫮��� ���室 � ���� �ਢ離� � ⥪���
              Emit.work.AddPosition (ir.Nodes^[n].Last.Position);
            END;
            Emit.work.GenBinJ (RD.NodeInfo^[n].j, j, RD.NodeInfo^[n].l1);
            IF RD.NodeInfo^[n].j2 THEN
                IF RD.NodeInfo^[n].l2 THEN
                    INC (l, 5);
                ELSE
                    INC (l, 2);
                END;
                j := RD.NodeInfo^[Color.To(ir.Nodes^[n].OutArcs^[1-RD.NodeInfo^[n].a],
                                        HasCode)].o - l;
                IF (ir.Nodes^[n].Last <> NIL) AND NOT ir.Nodes^[n].Last.Position.IsNull() THEN
                  -- AVY: ���� �ਢ離� � ⥪���
                  Emit.work.AddPosition (ir.Nodes^[n].Last.Position);
                END;
                Emit.work.GenBinJ (D.UnJ, j, RD.NodeInfo^[n].l2);
            END;
        END;
        IF NeedAlignment (i) THEN
            CASE l MOD 4 OF
            | 0:
            | 1:    IF IsJmpNode (n) THEN
                        CodeDef.GenByte (NOP);
                        CodeDef.GenByte (NOP);
                        CodeDef.GenByte (NOP);
                    ELSE
                        CodeDef.GenByte (83X);
                        CodeDef.GenByte (0FCX);
                        CodeDef.GenByte (0);
                    END;
            | 2:    IF IsJmpNode (n) THEN
                        CodeDef.GenByte (NOP);
                        CodeDef.GenByte (NOP);
                    ELSE
                        CodeDef.GenByte (85X);
                        CodeDef.GenByte (0E4X);
                    END;
            | 3:    CodeDef.GenByte (NOP);
            END;
            RD.NodeInfo^[n].l := ((l + 3) DIV 4) * 4 - l;
            l := ((l + 3) DIV 4) * 4;
        END;
    END;
(*
  ������� ����� ��楤��� ��⭮� 4 - � �ਭ樯� ��祬 �� �⫨砥��� �� ⮣�,
  �� �������� ࠭��, �� ����筥� ��������� ������ NOP���
*)
    IF NOT (at.SPACE IN at.COMP_MODE) THEN
        n := Color.GenOrder^[Color.EndGenOrder];
        RD.NodeInfo^[n].l := ((l + 3) DIV 4) * 4 - l;
        CodeDef.set_segm (RD.NodeInfo^[n].sg);
        WHILE l MOD 4 <> 0 DO
            CodeDef.GenByte (NOP);
            INC (l);
        END;
    END;
    RETURN l;
END GenJumpsB;

--------------------------------------------------------------------------------


PROCEDURE GenVarsInfo;
VAR l, m:  Local;
    v:     VarNum;
    c:     Color.ClusterNum;
    table: POINTER TO ARRAY OF Local;

    (*
      �஢����, �� ����� �뤠�� �⫠����� ���ଠ�� �� ��६�����
    *)

    PROCEDURE CheckVar (v: VarNum);
    VAR u: VarNum;
    BEGIN
        l := ir.Vars^[v].LocalNo;
        IF (l <> ir.UNDEFINED) & NOT (ir.o_Debug IN ir.Locals^[l].Options) THEN
            u := table^[l];
            IF u = ir.UNDEFINED THEN
                table^[l] := v;
            ELSIF (RD.Loc^[v].tag = RD.Loc^[u].tag) &
                  ((RD.Loc^[v].tag = NTreg)   & (RD.Loc^[v].reg = RD.Loc^[u].reg) OR
                   (RD.Loc^[v].tag = NTlocal) & (RD.Loc^[v].mem = RD.Loc^[u].mem) &
                                              (RD.Loc^[v].offs = RD.Loc^[u].offs))
            THEN
                ;
            ELSE
                INCL (ir.Locals^[l].Options, ir.o_Debug);
            END;
        END;
    END CheckVar;

VAR
  LocalsOffset: INT;

BEGIN
    IF NOT (at.debug IN at.COMP_MODE) OR
       (ir.NLocals = ir.ZEROVarNum)
    THEN
        RETURN;
    END;
    NEW (table, ir.NLocals);
    FOR l:=ir.ZEROVarNum TO SYSTEM.PRED(ir.NLocals) DO
        table^[l] := ir.UNDEFINED;
    END;
    IF Emit.baseReg = D.EBP THEN
      LocalsOffset := Emit.LocalsOffset;
    ELSE
      LocalsOffset := 0;
    END;
(*
  ���砫� �뤠�� ���ଠ�� �� ᨤ�騥 � ����� ��ॣ���
*)
--    IF Emit.baseReg <> D.ESP THEN
        FOR l:=ir.ZEROVarNum TO SYSTEM.PRED(ir.NLocals) DO
            IF (* NOT (ir.Locals^[l].VarType IN { ir.t_int, ir.t_unsign,
                                               ir.t_float, ir.t_ref }) & *)
               (ir.Locals^[l].Offset <> ir.UNKNOWN_OFFSET) &
               NOT ir.IsExternal (l)
            THEN
                INCL (ir.Locals^[l].Options, ir.o_Debug);
                ir.Locals^[l].Debug.Location := ir.LocInFrame;
                ir.Locals^[l].Debug.Value    := ir.Locals^[l].Offset+LocalsOffset;
            END;
        END;
--    END;
(*
  ������ ��ᬮ����, ����� vars �⮡ࠦ��� � ������
*)
    FOR c:=0 TO Color.NClusters-1 DO
        CheckVar (Color.Clusters^[c].v^[0]);
    END;
    FOR v:=Color.NNonTempVars TO SYSTEM.PRED(ir.NVars) DO
        IF (RD.Loc^[v].tag = NTlocal) OR (RD.Loc^[v].tag = NTreg) THEN
            CheckVar (v);
        END;
    END;
(*
  ������ �뤠�� ���ଠ�� � �� locals, � ������ ᨤ�� �� ����� ������
  ������/var
*)
    FOR l:=ir.ZEROVarNum TO SYSTEM.PRED(ir.NLocals) DO
        IF NOT (ir.o_Debug IN ir.Locals^[l].Options) &
           NOT ir.IsExternal (l) & (ir.Locals^[l].Obj <> NIL)
        THEN
            v := table^[l];
            IF v = ir.UNDEFINED THEN
                IF (ir.Locals^[l].Offset <> ir.UNKNOWN_OFFSET)
--                & (Emit.baseReg <> D.ESP)
                THEN
                    ir.Locals^[l].Debug.Location := ir.LocInFrame;
                    ir.Locals^[l].Debug.Value    := ir.Locals^[l].Offset+LocalsOffset;
                END;
            ELSE
                CASE RD.Loc^[v].tag OF
                | NTreg:
                    IF RD.Loc^[v].reg <> UNDEF_REG THEN
                        ir.Locals^[l].Debug.Location := ir.LocInReg;
                        ir.Locals^[l].Debug.Value    := ORD(RD.Loc^[v].reg);
                    END;
                | NTlocal:
                    m := RD.Loc^[v].mem;
                    IF --(Emit.baseReg <> D.ESP) &
                        NOT ir.IsExternal (m)
                    THEN
                        ir.Locals^[l].Debug.Location := ir.LocInFrame;
                        ir.Locals^[l].Debug.Value    := ir.Locals^[m].Offset +
                                                        RD.Loc^[v].offs+LocalsOffset;
                    END;
                ELSE
                END;
            END;
        END;
    END;
END GenVarsInfo;

--------------------------------------------------------------------------------

PROCEDURE GenFinalizer(): pc.OBJECT;
VAR nm: pc.STRING;
    o: pc.OBJECT;
    sg, old: CodeDef.CODE_SEGM;
BEGIN
  CodeDef.get_segm(old);
  CodeDef.new_segm(sg);
  Emit.work.EnterNode(-1,sg);
  R.Epilogue(TRUE);
  WHILE sg.code_len MOD 4 <> 0 DO
    CodeDef.GenByte(NOP);
  END;
  CodeDef.set_segm(old);

  nm := at.make_name("%s'finalizer", at.curr_proc.name^);
  o := at.new_work_object(nm, NIL, at.curr_mod.type, pc.ob_proc, FALSE);
  CodeDef.set_ready(o, sg);
  RETURN o;
END GenFinalizer;

PROCEDURE EndGenProcB;
VAR e, k, j, m, o: INT;
    h, min, max, proc_len: LONGINT;
    hc, minc, maxc:      SYSTEM.CARD32;
    sg, ca:              CodeDef.CODE_SEGM;
    p:                   TriadePtr;
    i: Color.GenOrdNode;
    n:                   Node;
    b:                   BOOLEAN;

BEGIN
    Emit.work.Flush;
    SortSegments;
    UniteSegments;

    -- *shell
    IF at.OptimizeTraps IN at.COMP_MODE THEN
      Emit.work.EndGenSkipTrap();
    END;
    CalcJumpsB;

    -- *shell
    IF at.OptimizeTraps IN at.COMP_MODE THEN
      Emit.work.GenSkipTrapJumps();
    END;
    j := GenJumpsB();
(*
  ������஢��� ⠡���� CASE'��
*)
    b := FALSE;
    ca := NIL;
    e  := 0;
    FOR i:=Color.StartGenOrder TO Color.EndGenOrder DO
        n := Color.GenOrder^[i];
        IF RD.NodeInfo^[n].j = D.NoJ THEN
            p := ir.Nodes^[n].Last;
            IF (p <> NIL) AND (p^.Op = ir.o_case) THEN
                sg := RD.NodeInfo^[n].sg;
                CodeDef.set_segm (sg);
                CodeDef.add_fixup (at.curr_proc, j,
                                   sg.code_len - RD.NodeInfo^[n].l - 4,
                                   CodeDef.fx_obj32);
                IF NOT b THEN
                    CodeDef.new_segm (ca);
                    b := TRUE;
                END;
                CodeDef.set_segm (ca);
                m := LEN (p.Params^) - 1;
                k := ir.Nodes^[n].NOut;
                IF k <> m DIV 2 THEN
                    e := RD.NodeInfo^[Color.To (ir.Nodes^[n].OutArcs^[k-1],
                                             HasCode)].o;
                END;
                IF p^.OpType = ir.t_int THEN
                    h := Calc.ToInteger (p^.Params^[1].value, p^.OpSize);
                    FOR k:=1 TO m BY 2 DO
                        min := Calc.ToInteger (p^.Params^[k].value,
                                               p^.OpSize);
                        max := Calc.ToInteger (p^.Params^[k+1].value,
                                               p^.OpSize);
                        WHILE h < min DO
                            CodeDef.gen_fixup (at.curr_proc, e,
                                               CodeDef.fx_obj32);
                            INC (h);
                            INC (j, 4);
                        END;
                        o := RD.NodeInfo^[
                                Color.To (ir.Nodes^[n].OutArcs^[(k-1) DIV 2],
                                          HasCode)].o;
                        LOOP
                            CodeDef.gen_fixup (at.curr_proc, o,
                                               CodeDef.fx_obj32);
                            INC (j, 4);
                            IF h = MAX (LONGINT) THEN
                                EXIT;
                            END;
                            INC (h);
                            IF h > max THEN
                                EXIT;
                            END;
                        END;
                    END;
                ELSE
                    hc := Calc.ToCardinal (p^.Params^[1].value, p^.OpSize);
                    FOR k:=1 TO m BY 2 DO
                        minc := Calc.ToCardinal (p^.Params^[k].value,
                                                 p^.OpSize);
                        maxc := Calc.ToCardinal (p^.Params^[k+1].value,
                                                 p^.OpSize);
                        WHILE hc < minc DO
                            CodeDef.gen_fixup (at.curr_proc, e,
                                               CodeDef.fx_obj32);
                            hc := hc + 1;
                            INC (j, 4);
                        END;
                        o := RD.NodeInfo^[
                                Color.To (ir.Nodes^[n].OutArcs^[(k-1) DIV 2],
                                          HasCode)].o;
                        LOOP
                            CodeDef.gen_fixup (at.curr_proc, o,
                                               CodeDef.fx_obj32);
                            INC (j, 4);
                            IF hc = Calc.MaxCard32 THEN
                                EXIT;
                            END;
                            hc := hc + 1;
                            IF hc > maxc THEN
                                EXIT;
                            END;
                        END;
                    END;
                END;
            END;
        END;
    END;


(*
  ������ ᮡ��� ���� ����让 ᥣ���� �� ��� �����쪨�
*)
    CodeDef.new_segm (sg);
    CodeDef.set_segm (sg);

    FOR i:=Color.StartGenOrder TO Color.EndGenOrder DO
        CodeDef.AddSegment (RD.NodeInfo^[Color.GenOrder^[i]].sg);
    END;
    IF b THEN
        CodeDef.AddSegment (ca);
    END;

(*
  ������� ����� ��楤��� ��⭮� 16, �᫨ ����
  ���࠭�� �।���⥫쭮 ����� ��楤���, �⮡� ���⠢��� ����
*)
    proc_len := sg^.code_len;
    IF NOT (at.SPACE IN at.COMP_MODE) THEN
        WHILE sg^.code_len MOD 16 <> 0 DO
            CodeDef.GenByte (NOP);
        END;
    END;
(*
  �뤠�� �⫠����� ���ଠ�� � ��६�����
*)
    GenVarsInfo;

    -- ��।����� ��砫� �஫��� � ����� ��楤���
    sg.start := R.CODE_START;
    IF CodeDef.ret_node = ir.UndefNode THEN
      sg.fin := proc_len;
    ELSE
      sg.fin := RD.NodeInfo^[CodeDef.ret_node].o + CodeDef.ret_offs;
    END;
    -- ��।����� ࠧ��� ��砫쭮�� ���� ��楤���
    sg.frame_size := R.InitialFrameOffset;
    sg.has_frame := R.ProcHasFrame;

(*
  � ⥯��� �ਢ易�� ��⮢� ᥣ���� � ��楤��
*)
    CodeDef.set_ready (prc.ProcObj (at.curr_procno), sg);

(*
  Finalizer for procs with "except" attr; EXCEPTTABLE entry
*)
    IF pc.ttag_except IN at.curr_proc.type.tags THEN
        CodeDef.set_segm(CodeDef.excepttable_segm);
        CodeDef.gen_fixup (at.curr_proc, 0, CodeDef.fx_obj32);
        CodeDef.GenLWord (CodeDef.get_ready(at.curr_proc).code_len);
        CodeDef.gen_fixup (GenFinalizer(), 0, CodeDef.fx_obj32); 
    END;
END EndGenProcB;


(*
  ���᫨�� ����� ���室��; ���⨢�� �����
*)
PROCEDURE GenJumpsA;
VAR
    n, m:  Node;
    i: Color.GenOrdNode;

BEGIN
    FOR i:=Color.StartGenOrder TO Color.EndGenOrder DO
        n := Color.GenOrder^[i];
        IF RD.NodeInfo^[n].j <> D.NoJ THEN
            m := Color.To (ir.Nodes^[n].OutArcs^[RD.NodeInfo^[n].a], HasCode);
            IF RD.NodeInfo^[m].lb = Emit.UNDEF_LABEL THEN
                Emit.work.SetSegment (m, RD.NodeInfo^[m].sg);
                -- AVY: ��⠢��� ���� � ��砫� ���⪠
                Emit.work.InsertLabel (RD.NodeInfo^[m].lb);
                -- AVY: �᫨ ���⮪ ������ ��।���� � ࠢ�� ⥪�饬�
                -- �������� ᬥ饭�� �����
                INC(CodeDef.ret_offs, ORD((CodeDef.ret_node#ir.UndefNode) AND (CodeDef.ret_node=m) AND (CodeDef.ret_offs>0)));
            END;
            Emit.work.SetSegment (n, RD.NodeInfo^[n].sg);

            Emit.work.GenTxtJ (RD.NodeInfo^[n].j, RD.NodeInfo^[m].lb);

            IF RD.NodeInfo^[n].j2 THEN
                m := Color.To (ir.Nodes^[n].OutArcs^[1-RD.NodeInfo^[n].a],HasCode);
                IF RD.NodeInfo^[m].lb = Emit.UNDEF_LABEL THEN
                    Emit.work.SetSegment (m, RD.NodeInfo^[m].sg);
                    Emit.work.InsertLabel (RD.NodeInfo^[m].lb);
                    INC(CodeDef.ret_offs, ORD((CodeDef.ret_node#ir.UndefNode) AND (CodeDef.ret_node=m) AND (CodeDef.ret_offs>0)));
                    Emit.work.SetSegment (n, RD.NodeInfo^[n].sg);
                END;
                Emit.work.GenTxtJ (D.UnJ, RD.NodeInfo^[m].lb);
            END;
        END;
        IF NeedAlignment (i) THEN
            CodeDef.set_segm (RD.NodeInfo^[n].sg);
            CodeDef.GenAlign (CODE_ALIGN_A);
        END;
    END;
END GenJumpsA;


PROCEDURE CalcJumpsA;
VAR
  l: INT;
  i: Color.GenOrdNode;
  n: Node;
BEGIN
    ASSERT(at.GENASM IN at.COMP_MODE);
    l := 0;
    FOR i:=Color.StartGenOrder TO Color.EndGenOrder DO
      n := Color.GenOrder^[i];
      RD.NodeInfo^[n].o := l;
      INC (l, RD.NodeInfo^[n].sg.code_len);
    END;
END CalcJumpsA;


PROCEDURE EndGenProcA;
VAR instr, k, j, m : INT;
    e, o: ir.Node;
    h, min, max: LONGINT;
    hc, minc, maxc:      SYSTEM.CARD32;
    sg, ca:              CodeDef.CODE_SEGM;
    p:                   TriadePtr;
    i: Color.GenOrdNode;
    n:                   Node;
    b:                   BOOLEAN;
BEGIN
    Emit.work.Flush;
    SortSegments;
    GenJumpsA;

(*
  ������஢��� ⠡���� CASE'��
*)
    b := FALSE;
    ca := NIL;
    e  := ir.ZERONode;
    FOR i:=Color.StartGenOrder TO Color.EndGenOrder DO
        n := Color.GenOrder^[i];
        IF RD.NodeInfo^[n].j = D.NoJ THEN
            p := ir.Nodes^[n].Last;
            IF p^.Op = ir.o_case THEN
                sg := RD.NodeInfo^[n].sg;
                IF NOT b THEN
                    CodeDef.new_segm (ca);
                    CodeDef.set_segm (ca);
                    CodeDef.GenAlign (4);
                    b := TRUE;
                END;
                CodeDef.set_segm (ca);
                Emit.work.SetLabel (RD.NodeInfo^[n].ca);
                m := LEN (p.Params^) - 1;
                k := ir.Nodes^[n].NOut;
                IF k <> m DIV 2 THEN
                    e := Color.To (ir.Nodes^[n].OutArcs^[k-1], HasCode);
                    IF RD.NodeInfo^[e].lb = Emit.UNDEF_LABEL THEN
                        CodeDef.set_segm (RD.NodeInfo^[e].sg);
                        Emit.work.InsertLabel (RD.NodeInfo^[e].lb);
                        INC(CodeDef.ret_offs, ORD((CodeDef.ret_node#ir.UndefNode) AND (CodeDef.ret_node=e) AND (CodeDef.ret_offs>0)));
                        CodeDef.set_segm (ca);
                    END;
                END;
                IF p^.OpType = ir.t_int THEN
                    h := Calc.ToInteger (p^.Params^[1].value, p^.OpSize);
                    FOR k:=1 TO m BY 2 DO
                        min := Calc.ToInteger (p^.Params^[k].value,
                                               p^.OpSize);
                        max := Calc.ToInteger (p^.Params^[k+1].value,
                                               p^.OpSize);
                        WHILE h < min DO
                            Emit.work.DwLabel (RD.NodeInfo^[e].lb);
                            INC (h);
                        END;
                        o := Color.To (ir.Nodes^[n].OutArcs^[(k-1) DIV 2],
                                       HasCode);
                        IF RD.NodeInfo^[o].lb = Emit.UNDEF_LABEL THEN
                            CodeDef.set_segm (RD.NodeInfo^[o].sg);
                            Emit.work.InsertLabel (RD.NodeInfo^[o].lb);
                            INC(CodeDef.ret_offs, ORD((CodeDef.ret_node#ir.UndefNode) AND (CodeDef.ret_node=o) AND (CodeDef.ret_offs>0)));
                            CodeDef.set_segm (ca);
                        END;
                        LOOP
                            Emit.work.DwLabel (RD.NodeInfo^[o].lb);
                            IF h = MAX (LONGINT) THEN
                                EXIT;
                            END;
                            INC (h);
                            IF h > max THEN
                                EXIT;
                            END;
                        END;
                    END;
                ELSE
                    hc := Calc.ToCardinal (p^.Params^[1].value, p^.OpSize);
                    FOR k:=1 TO m BY 2 DO
                        minc := Calc.ToCardinal (p^.Params^[k].value,
                                                 p^.OpSize);
                        maxc := Calc.ToCardinal (p^.Params^[k+1].value,
                                                 p^.OpSize);
                        WHILE hc < minc DO
                            Emit.work.DwLabel (RD.NodeInfo^[e].lb);
                            hc := hc + 1;
                        END;
                        o := Color.To (ir.Nodes^[n].OutArcs^[(k-1) DIV 2],
                                       HasCode);
                        IF RD.NodeInfo^[o].lb = Emit.UNDEF_LABEL THEN
                            CodeDef.set_segm (RD.NodeInfo^[o].sg);
                            Emit.work.InsertLabel (RD.NodeInfo^[o].lb);
                            INC(CodeDef.ret_offs, ORD((CodeDef.ret_node#ir.UndefNode) AND (CodeDef.ret_node=o) AND (CodeDef.ret_offs>0)));
                            CodeDef.set_segm (ca);
                        END;
                        LOOP
                            Emit.work.DwLabel (RD.NodeInfo^[o].lb);
                            IF hc = Calc.MaxCard32 THEN
                                EXIT;
                            END;
                            hc := hc + 1;
                            IF hc > maxc THEN
                                EXIT;
                            END;
                        END;
                    END;
                END;
            END;
        END;
    END;
(*
  ������ ᮡ��� ���� ����让 ᥣ���� �� ��� �����쪨�
*)
    CodeDef.new_segm (sg);
    CodeDef.set_segm (sg);

    -- �������� ᬥ饭�� ���⪮� �⭮�⥫쭮 ��砫� ��楤���
    CalcJumpsA;

    FOR i:=Color.StartGenOrder TO Color.EndGenOrder DO
        CodeDef.AddSegment (RD.NodeInfo^[Color.GenOrder^[i]].sg);
    END;
    IF b THEN
        CodeDef.AddSegment (ca);
    END;
(*
  �뤠�� �⫠����� ���ଠ�� � ��६�����
*)
    GenVarsInfo;

    -- ��।����� ��砫� �஫��� � ����� ��楤���
    sg.start := R.CODE_START;
    IF CodeDef.ret_node = ir.UndefNode THEN
      sg.fin := sg^.code_len;
    ELSE
      sg.fin := RD.NodeInfo^[CodeDef.ret_node].o + CodeDef.ret_offs;
    END;
(*
  � ⥯��� �ਢ易�� ��⮢� ᥣ���� � ��楤��
*)
<* IF NOT nodebug THEN *>
    IF opIO.needed THEN
        opIO.print ("\n\n-----------------------------------------------\n\n");
        FOR instr:=0 TO sg.code_len-1 DO
            opIO.print ("\t\t\t\t\t%s\n", sg.acode^[instr]^);
        END;
    END;
<* END *>
    CodeDef.set_ready (prc.ProcObj (at.curr_procno), sg);
END EndGenProcA;

PROCEDURE EndGenProc*();
BEGIN
  IF at.GENASM IN at.COMP_MODE THEN
    EndGenProcA;
    -- *shell
    IF at.OptimizeTraps IN at.COMP_MODE THEN
      Emit.work.EndGenSkipTrap();
    END;
  ELSE
    EndGenProcB;
  END;
END EndGenProc;

END LinkProc.
