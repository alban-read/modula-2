MODULE FLoops;

IMPORT
     ir,
     gr := ControlGraph,
     BitVect,
     Color,
     def := OcirDef,
     env := xiEnv,
     Emit,
     ocir,
     (* ocirtxt,*)
     Rrd2Bin;
IMPORT D := desc386;
IMPORT SYSTEM;

TYPE
     Loop = ir.Loop;
     AddrList = POINTER TO AddrRec;
     AddrDesc = RECORD
                    addr    : def.AddrMode;
                    used_in : BitVect.BitVector;
                    count   : LONGINT;
                    in_int_op,
                    read,
                    write,
                    unknown : BOOLEAN;
                    sz      : Emit.SizeType;
                    ST_offs : SHORTINT; -- ����� �� �⥪� � ᬥ饭���
                                        -- ST_SIZE - ST_offs
                END;

     AddrRec  = RECORD
                    ad      : AddrDesc;
                    next    : AddrList;
                END;

(* ������ ᯨ᮪ �� count *)
PROCEDURE SortList(l : AddrList) : AddrList;
VAR tmp      : AddrList;
    changed  : BOOLEAN;
    buf_ad   : AddrDesc;
BEGIN
    IF (l = NIL) OR (l^.next = NIL) THEN RETURN l; END;
    REPEAT
        changed := FALSE;
        tmp := l;
        LOOP
            IF tmp^.ad.count < tmp^.next^.ad.count THEN
                changed := TRUE;
                buf_ad := tmp^.ad;
                tmp^.ad := tmp^.next^.ad;
                tmp^.next^.ad := buf_ad;
            END;
            tmp := tmp^.next;
            IF tmp^.next = NIL THEN EXIT END;
        END;
    UNTIL NOT changed;
    RETURN l;
END SortList;

(* ��ॢ��稢��� ᯨ᮪ *)
PROCEDURE ReverseList(l : AddrList) : AddrList;
VAR res, tmp : AddrList;
BEGIN
    res := NIL;
    WHILE l <> NIL DO
        tmp := l;
        l := l^.next;
        tmp^.next := res;
        res := tmp;
    END;
    RETURN res;
END ReverseList;

PROCEDURE ClearScales(l : AddrList);
BEGIN
    WHILE l <> NIL DO BitVect.Free(l^.ad.used_in); l := l^.next; END;
END ClearScales;

VAR LoopDescs : POINTER TO ARRAY OF
                    RECORD
                        max_FS       : SHORTINT;
                                     -- ����. �ᯮ�짮����� �⥪� � 横��
                        with_call    : BOOLEAN;
                                     -- ᮤ�ন� �맮�
                        res_regs     : def.Regs;
                                     -- ����� ॣ�����
                        candidates   : AddrList;
                                     -- �� ����� �������� ᠤ��� �� ॣ����
                        fmem,
                        mem          : AddrList;
                                     -- (����⢥����)
                                     -- �ᯮ��㥬��/�����塞�� ������ � 横��
                    END;


(* �ࠢ����� ᯨ᪮� ᬥ饭�� �� ���ᮢ *)
PROCEDURE CompareOffsLists(l1,l2  : Emit.OffsRecPtr) : BOOLEAN;
BEGIN
    LOOP
       IF l1 = NIL THEN RETURN l2 = NIL;
       ELSIF l2 = NIL THEN RETURN FALSE;
       ELSIF l1^.name <> l2^.name THEN RETURN FALSE;
       ELSE l1 := l1^.next; l2 := l2^.next;
       END;
    END;
END CompareOffsLists;

(* �ࠢ����� ᯨ᪮� ��楤�� �� ���ᮢ *)
PROCEDURE CompareProcLists(l1,l2  : Emit.ProcRecPtr) : BOOLEAN;
BEGIN
    LOOP
       IF l1 = NIL THEN RETURN l2 = NIL;
       ELSIF l2 = NIL THEN RETURN FALSE;
       ELSIF l1^.name <> l2^.name THEN RETURN FALSE;
       ELSE l1 := l1^.next; l2 := l2^.next;
       END;
    END;
END CompareProcLists;

(* �ࠢ����� ���ᮢ *)
PROCEDURE CompareAddrs(a1,a2 : def.AddrMode) : BOOLEAN;
BEGIN
    RETURN (a1.place1.r  = a2.place1.r)  &  (a1.place1.v  = a2.place1.v)  &
           (a1.place2.r  = a2.place2.r)  &  (a1.place2.v  = a2.place2.v)  &
           (a1.scale = a2.scale) &  (a1.offs  = a2.offs)  &
           (a1.local = a2.local) &  (a1.proc = a2.proc)   &
           CompareOffsLists(a1.offslist,a2.offslist) & CompareProcLists(a1.proclist,a2.proclist);
END CompareAddrs;

(* �����頥� 墮�� ᯨ᪠ l, ��稭�� � �����, ᮤ�ঠ饣� a,
   ��� NIL
*)
PROCEDURE Member(l : AddrList; a :  def.AddrMode) : AddrList;
BEGIN
    LOOP
        IF (l = NIL) OR CompareAddrs(l^.ad.addr,a) THEN RETURN l;
        ELSE l := l^.next;
        END;
    END;
END Member;


(*
   �������� ���� a, �ᯮ��㥬� � 㧫� n �� �⥭�� (�᫨ read)
   ��� �� ������ � ᯨ�� l,
   �᫨ � l ⠪�� ���� 㦥 ����, � �������� n � used_in
*)
PROCEDURE AddAddr(VAR   l : AddrList;
                        a : def.AddrMode;
                        n : ir.Node;
                 in_int_op: BOOLEAN;
                  unknown : BOOLEAN;
                     read : BOOLEAN;
                       sz : Emit.SizeType);

VAR tmp : AddrList;
BEGIN
    tmp := Member(l,a);
    IF tmp = NIL THEN
       NEW(tmp);
       tmp^.ad.addr    := a;
       tmp^.ad.count   := 0;
       tmp^.ad.used_in := BitVect.New(ORD(ir.Nnodes),FALSE);
       tmp^.next       := l;
       tmp^.ad.sz      := sz;
       tmp^.ad.unknown := unknown;
       tmp^.ad.read    := FALSE;
       tmp^.ad.write   := FALSE;
       tmp^.ad.in_int_op := FALSE;
       l := tmp;
    END;
    BitVect.Incl(tmp^.ad.used_in,ORD(n));
    INC(tmp^.ad.count);
    IF read THEN tmp^.ad.read := TRUE; ELSE tmp^.ad.write := TRUE; END;
    IF in_int_op THEN tmp^.ad.in_int_op := TRUE; END;
END AddAddr;

(* ��।���� '��ண��' �����⭮��� ���� *)
PROCEDURE IsUnknownAddr(addr : def.AddrMode; loop: Loop) : BOOLEAN;
VAR local : ir.Local;
BEGIN
    local := def.GetLocal(addr);
    IF local = ir.UNDEFINED THEN RETURN TRUE; END;
    IF local >= Color.NLocals THEN RETURN FALSE; END;
    IF ir.IsExternal(local) OR gr.IsAddressedInLoop(local, loop)THEN
        RETURN TRUE;
    END;
    RETURN FALSE;
END IsUnknownAddr;

(* ������ ��砫�� ���祭�� ���ਯ�஢ 横��� �� 㧫� n � 横�� l,
   �����頥� �ਧ���, �� ��� 横� �� ����� ��� �������
   ��⨬���஢���
*)
PROCEDURE EvalLoopDesc(n : ir.Node; l : Loop) : BOOLEAN;
VAR current,max : SHORTINT;
    i           : INTEGER;
    op          : def.Operation;
    bin         : def.BinRecipe;
    a           : def.AddrMode;
    unknown     : BOOLEAN;
    tmp         : ocir.Segment;
BEGIN
    current := 0;
    max     := 0;
    tmp     := ocir.ProcSegms[n];
    WHILE tmp <> NIL DO
        FOR i := 0 TO tmp.code_len-1 DO
            op := tmp.code[i];
            LoopDescs^[l].res_regs :=
                LoopDescs^[l].res_regs + op.attrs.res.r - def.Regs{def.ESP};
            bin := op.bin;
            WITH
              bin : def.BinRecipeFloatR DO
                bin.ReadMem(a);
                unknown := IsUnknownAddr(a,l);
                AddAddr(LoopDescs^[l].fmem,a,n,FALSE,unknown,TRUE,bin.GetReadSz());
                AddAddr(LoopDescs^[l].mem, a,n,FALSE,unknown,TRUE,bin.GetReadSz());
            | bin : def.BinRecipeFloatW DO
                bin.WriteMem(a);
                unknown := IsUnknownAddr(a,l);
                AddAddr(LoopDescs^[l].fmem,a,n,FALSE,unknown,FALSE,bin.GetWriteSz());
                AddAddr(LoopDescs^[l].mem, a,n,FALSE,unknown,FALSE,bin.GetWriteSz());
            | bin : def.BinRecipeR DO
                bin.ReadMem(a);
                AddAddr(LoopDescs^[l].mem,a,n,TRUE,IsUnknownAddr(a,l),TRUE,bin.GetReadSz());
            | bin : def.BinRecipeW DO
                bin.WriteMem(a);
                AddAddr(LoopDescs^[l].mem,a,n,TRUE,IsUnknownAddr(a,l),FALSE,bin.GetWriteSz());
            | bin : def.BinRecipeRW DO
                bin.ReadMem(a);
                AddAddr(LoopDescs^[l].mem,a,n,TRUE,IsUnknownAddr(a,l),TRUE,bin.GetReadSz());
                bin.WriteMem(a);
                AddAddr(LoopDescs^[l].mem,a,n,TRUE,IsUnknownAddr(a,l),FALSE,bin.GetWriteSz());
            ELSE
            END;
            INC(current,def.GetFLOAT_SIZE_delta(op.code));
            IF max < current THEN max := current; END;
            IF op.code = def.CALL THEN
                LoopDescs^[l].with_call := TRUE;
                RETURN FALSE;
            END;
        END;
        tmp := tmp^.next;
    END;
    IF LoopDescs^[l].max_FS < max THEN LoopDescs^[l].max_FS := max; END;
    RETURN LoopDescs^[l].max_FS < 8;
END EvalLoopDesc;

(* 誠�� � ���ࠪ�����묨 横���� *)
VAR discarded : BitVect.BitVector;

(* ���樠������ �ᥣ� ���嫠 ��� FL-��⨬���樨 *)
PROCEDURE InitLoopDescs*;
VAR s        : ir.TSNode;
    l        : Loop;
    continue : BOOLEAN;
    n        : ir.Node;
BEGIN
    NEW(LoopDescs,gr.NLoops);
    discarded := BitVect.New(ORD(gr.NLoops),FALSE);
    FOR l := ir.ZEROLoop TO SYSTEM.PRED(gr.NLoops) DO
        LoopDescs^[l].max_FS       := 0;
        LoopDescs^[l].with_call   := FALSE;
        LoopDescs^[l].res_regs    := def.Regs{};
        LoopDescs^[l].candidates  := NIL;
        LoopDescs^[l].fmem        := NIL;
        LoopDescs^[l].mem         := NIL;
    END;
    FOR l := ir.ZEROLoop TO SYSTEM.PRED(gr.NLoops) DO
        s :=SYSTEM.SUCC(ir.Nodes^[gr.LoopList^[l].Preheader].TopNumber);
        continue := TRUE;
        WHILE continue & (s < LEN(ir.Order^)) DO
            n := ir.Order^[s];
            IF BitVect.In (gr.LoopList^[l].Body, ORD(n)) THEN
                continue := EvalLoopDesc(n,l);
            END;
            INC(s);
        END;
        IF (NOT continue) OR (LoopDescs^[l].fmem = NIL) THEN
            BitVect.Incl(discarded,ORD(l));
        END;
    END;
END InitLoopDescs;

(* ����� �� �������� ������ al1 � ������� al2
   � ��ࢮ� ॣ����� - ��࠭�஢��� ����ਠ��� 横��
   ��ࢠ� - ����⢥���� ������, ������ ����� ������� �� �⥪
*)
PROCEDURE AreLocationsIntersect(al1,al2 : AddrList) : BOOLEAN;
VAR l1,l2 : ir.Local;
BEGIN
    IF (NOT al1^.ad.unknown) OR (NOT al2^.ad.unknown) THEN RETURN FALSE END;
    l1 := def.GetLocal(al1^.ad.addr);
    l2 := def.GetLocal(al2^.ad.addr);
    IF (l1 <> ir.UNDEFINED) & (l2 <> ir.UNDEFINED) & (l1 <> l2) THEN
        RETURN FALSE;
    END;
    RETURN al1^.ad.write OR al2^.ad.write;
END AreLocationsIntersect;

PROCEDURE AreLocationsIntersectStrict(al1,al2 : AddrList; dif_regs : def.Regs)
          : BOOLEAN;
VAR a1, a2 : def.AddrMode;
BEGIN
    a1 := al1^.ad.addr;
    a2 := al2^.ad.addr;
    IF (a1.offs <> a2.offs) &
       NOT (VAL(def.Register,a1.place1.r) IN dif_regs) & NOT (VAL(def.Register,a1.place2.r) IN dif_regs)
    THEN
        a2.offs := a1.offs;
        IF CompareAddrs(a1,a2) THEN
            RETURN FALSE;
        ELSE
            RETURN AreLocationsIntersect(al1,al2);
        END;
    END;
    RETURN CompareAddrs(a1,a2) OR AreLocationsIntersect(al1,al2);
END AreLocationsIntersectStrict;

(* ����� �� �������� ������ al1 � �����-����� ���ᮬ �� al2
   ������ al1 - 㦥 �� �祭� ��訩 ����,
   �� ��� ॣ����� - ����ਠ��� � 横��
*)
PROCEDURE CanIntersect(al1, al2 : AddrList) : BOOLEAN;
BEGIN
    (* ᯨ᪨ �� ����� ���� ����묨, ��᪮��� �ᥣ�� ��।�����
       LoopDescs^[l].mem, ��� l �� �室�� � discarded, � ����� �
       l ���� ��� �� ���� ����⢥���� ������
    *)
    REPEAT
        IF AreLocationsIntersect(al1,al2) THEN RETURN TRUE; END;
        al2 := al2^.next;
    UNTIL al2 = NIL;
    RETURN FALSE;
END CanIntersect;

(* � �� �� ��� �ᥣ� ᯨ᪠ al1 *)
PROCEDURE ListsCanIntersect(al1,al2 : AddrList; dif_regs : def.Regs) : BOOLEAN;
VAR tmp : AddrList;
BEGIN
    WHILE al1 <> NIL DO
        tmp := al2;
        WHILE tmp <> NIL DO
            IF AreLocationsIntersectStrict(al1,tmp,dif_regs) THEN RETURN TRUE;
            ELSE tmp := tmp^.next;
            END;
        END;
        al1 := al1^.next;
    END;
    RETURN FALSE;
END ListsCanIntersect;


(* ��ࢮ� ���饭�� � addr � link node ��� l - �� ������ *)
PROCEDURE FirstWrite(addr : def.AddrMode; l : Loop) : BOOLEAN;
VAR s   : ocir.Segment;
    i   : INTEGER;
    bin : def.BinRecipe;
    a   : def.AddrMode;
BEGIN
    s := ocir.ProcSegms[ir.Order^[SYSTEM.SUCC(ir.Nodes^[gr.LoopList^[l].Preheader].TopNumber)]];
    FOR i := 0 TO s.code_len-1 DO
        bin := s.code^[i].bin;
        WITH
          bin : def.BinRecipeFloatR DO
            bin.ReadMem(a);
            IF CompareAddrs(a,addr) THEN RETURN FALSE END;
        | bin : def.BinRecipeFloatW DO
            bin.WriteMem(a);
            IF CompareAddrs(a,addr) THEN RETURN TRUE; END;
        ELSE
        END;
    END;
    RETURN FALSE;
END FirstWrite;

(* n - ����騩 ���⮪ 横�� l *)
PROCEDURE IsLinkNode(l : Loop; n : ir.Node) : BOOLEAN;
BEGIN
    RETURN n = ir.Order^[SYSTEM.SUCC(ir.Nodes^[gr.LoopList^[l].Preheader].TopNumber)];
END IsLinkNode;

(* � nodes ���� ����騩 ���⮪ 横�� l *)
PROCEDURE IncludeLinkNode(nodes : BitVect.BitVector; l : Loop) : BOOLEAN;
VAR i : ir.TSNode;
BEGIN
    FOR i:=SYSTEM.SUCC(ir.Nodes^[gr.LoopList^[l].Preheader].TopNumber)
        TO SYSTEM.PRED(LEN(ir.Order^))
    DO
        IF BitVect.In(nodes,ORD(ir.Order^[i])) & IsLinkNode(l,ir.Order^[i]) THEN
            RETURN TRUE;
        END;
    END;
    RETURN FALSE;
END IncludeLinkNode;

PROCEDURE EvalLoopCandidates(l : Loop);
VAR tmp, tmp1 : AddrList;
BEGIN
    (* ᭠砫� ��७�ᥬ �� fmem � candidates
       ⮫쪮 � ����,
       1) ॣ����� ������ �� �������� � 横�� ��� = ESP
       2) ���� ⮫쪮 �� �⥭�� ��� �� �����쭠� ������
       3) ���� ���饭�� � ��뢠�饬 ���⪥ 横��
       ���ࠪ��뢠� �� ��⠫��
    *)
    tmp := LoopDescs^[l].fmem;
    (* ���ࠪ����� � ����, ����� �ᯮ������� � 楫�� �������� � � ��� ����� *)
    REPEAT
        tmp1 := Member(LoopDescs^[l].mem,tmp^.ad.addr);
        IF tmp1^.ad.in_int_op THEN
            BitVect.Free(tmp^.ad.used_in);
            tmp := tmp^.next;
        ELSE
           tmp1 := tmp;
           tmp := tmp^.next;
           tmp1^.next := LoopDescs^[l].candidates;
           LoopDescs^[l].candidates := tmp1;
       END;
    UNTIL tmp = NIL;
    IF LoopDescs^[l].candidates = NIL THEN
        BitVect.Incl(discarded,ORD(l));
        RETURN;
    END;
    LoopDescs^[l].fmem := LoopDescs^[l].candidates;
    LoopDescs^[l].candidates := NIL;
    tmp := LoopDescs^[l].fmem;
    REPEAT
       IF ((tmp^.ad.addr.place1.r <> def.UNDEF_REG) AND
           (VAL(def.Register,tmp^.ad.addr.place1.r) IN LoopDescs^[l].res_regs))
          OR
          ((tmp^.ad.addr.place2.r <> def.UNDEF_REG) AND
           (VAL(def.Register,tmp^.ad.addr.place2.r) IN LoopDescs^[l].res_regs))
          OR
          (tmp^.ad.write &
           ((tmp^.ad.addr.local = ir.UNDEFINED) OR
            (tmp^.ad.addr.local = def.BAD_MEM)  OR
            ir.IsExternal(tmp^.ad.addr.local)))
          OR
          (NOT IncludeLinkNode(tmp^.ad.used_in,l))
       THEN
           BitVect.Free(tmp^.ad.used_in);
           tmp := tmp^.next;
       ELSE
           tmp1 := tmp;
           tmp := tmp^.next;
           tmp1^.next := LoopDescs^[l].candidates;
           LoopDescs^[l].candidates := tmp1;
       END;
    UNTIL tmp = NIL;
    IF LoopDescs^[l].candidates = NIL THEN
        BitVect.Incl(discarded,ORD(l));
        RETURN;
    END;
    LoopDescs^[l].fmem := LoopDescs^[l].candidates;
    LoopDescs^[l].candidates := NIL;
    (* ⥯��� ࠧ��६�� � ����祭�ﬨ �� ����� *)
    tmp := LoopDescs^[l].fmem;
    REPEAT
        IF IsUnknownAddr(tmp^.ad.addr,l) & CanIntersect(tmp,LoopDescs^[l].mem)
        THEN
            BitVect.Free(tmp^.ad.used_in);
            tmp := tmp^.next;
        ELSE
            tmp1 := tmp;
            tmp := tmp^.next;
            tmp1^.next := LoopDescs^[l].candidates;
            LoopDescs^[l].candidates := tmp1;
        END;
    UNTIL tmp = NIL;
    IF LoopDescs^[l].candidates = NIL THEN BitVect.Incl(discarded,ORD(l)); END;
END EvalLoopCandidates;


(* ��室�� ����-��������� �� ��⠫������� � ����⢥��� �⥪ *)
PROCEDURE EvalCandidates();
VAR l         : Loop;
BEGIN
    FOR l := ir.ZEROLoop TO SYSTEM.PRED(gr.NLoops) DO
        IF NOT BitVect.In(discarded,ORD(l)) THEN
            EvalLoopCandidates(l);
        END;
    END;
END EvalCandidates;

(*
 ������ ��� ������� ���� ���ᨬ���� 横��, � ������ �㦭�
 ������ ��� ��७�� �� �⥪
*)
PROCEDURE CalcMaxLoop();
VAR l, out   : Loop;
    tmp,
    tmp1     : AddrList;
    transfer : BOOLEAN;
BEGIN
    (* �� � ���� �� ��������� 横���, ����� ����� ������� ��
       ����⢥��� �⥪ � �墠�뢠�饬 横��, �모�뢠���� �� ��������� 横���,
    *)
    FOR l := ir.ZEROLoop TO SYSTEM.PRED(gr.NLoops,2) DO
        IF NOT BitVect.In(discarded,ORD(l)) THEN
            tmp := LoopDescs^[l].candidates;
            LoopDescs^[l].candidates := NIL;
            REPEAT
                transfer := FALSE;
                out := SYSTEM.SUCC(l);
                WHILE NOT transfer & (out < gr.NLoops) DO
                    transfer :=
                        NOT BitVect.In(discarded,ORD(out)) &
                        gr.LoopInLoop(l,out) &
                        (Member(LoopDescs^[out].candidates,tmp^.ad.addr) <> NIL);
                    INC(out);
                END;
                IF NOT transfer THEN
                    (* �㦭� ��⠢��� � �⮬ 横�� *)
                    tmp1       := tmp;
                    tmp        := tmp^.next;
                    tmp1^.next := LoopDescs^[l].candidates;
                    LoopDescs^[l].candidates := tmp1;
                ELSE
                    (* �㤥�, �᫨ ����, �뭮����� � �墠�뢠�饬 横�� *)
                    BitVect.Free(tmp^.ad.used_in);
                    tmp := tmp^.next;
                END;
            UNTIL tmp = NIL;
            IF LoopDescs^[l].candidates = NIL THEN
                BitVect.Incl(discarded,ORD(l));
            END;
        END;
    END;
END CalcMaxLoop;

VAR buff_segm : ocir.Segment; -- �ᯮ������ ��� ⮣�,
                              -- �⮡� ��� �㬠 � �뫨 ���짮������ ��楤�ࠬ�
                              -- �� ocir � EmitRrd ��� ������ ����
                              -- �� ॣ���� ����⢥����� �⥪�

(* �������� ������ �� al � op �� ST_(al^.ad.ST_offs+op.FLOAT_SIZE *)
PROCEDURE Addr2STInOp(al : AddrList; op :def.Operation; VAR res : def.Operation);
VAR bin  : def.BinRecipe;
    st_i : SHORTINT;
    old  : ocir.Segment;
    tags : def.OpTagAttrs;
BEGIN
    buff_segm.code_len := 0;
    old                := ocir.c_seg;
    ocir.c_seg         := buff_segm;
    (*
      ��堥� � �㫥��� ������� ��騬� ��楤�ࠬ�, � ��⮬ ��९�娢��� � op
    *)
    bin := op.bin;
    st_i := VAL(SHORTINT,op.FLOAT_SIZE) + al^.ad.ST_offs;
    WITH
      bin : Rrd2Bin.MoveTOS_M DO
        Emit.work.GenMoveTOS_STi(st_i);
    | bin : Rrd2Bin.MoveM_TOS DO
        Emit.work.GenMoveSTi_TOS(st_i);
    | bin : Rrd2Bin.FOpST0_M  DO
        Emit.work.GenFOpST0_STi(bin^.op,st_i);
    | bin : Rrd2Bin.FComTOS_M DO
        Emit.work.GenFComTOS_STi(st_i);
    END;
    ocir.c_seg.code^[0].tpos           := op.tpos;
    ocir.c_seg.code^[0].PUSH_SIZE      := op.PUSH_SIZE;
    ocir.c_seg.code^[0].NEXT_PUSH_SIZE := op.NEXT_PUSH_SIZE;
    ocir.c_seg.code^[0].FLOAT_SIZE     := op.FLOAT_SIZE;
    tags := def.OpTagAttrs{def.NOT_MOVABLE, def.NOT_TRANSFER_LOCAL_MOVE} * op.attrs.tag_attrs;
    IF tags # def.OpTagAttrs{} THEN
        ocir.c_seg.code^[0].attrs.tag_attrs := 
            ocir.c_seg.code^[0].attrs.tag_attrs + tags;
    END;
    res := ocir.c_seg.code^[0];
    ocir.c_seg := old;
END Addr2STInOp;

(*
  1) �� �宦����� addr �� al �������� ��
     ST_(FLOAT_SIZE + tmp^.ad.ST_offs),
     ᮮ⢥�����騬 ��ࠧ�� ������� �������
  2) FLOAT_SIZE ������ ������� 㢥����� �� alloc,
*)
PROCEDURE Addr2STInNode(al : AddrList; n : ir.Node; alloc : SHORTINT);
VAR segm : ocir.Segment;
    i    : INTEGER;
    bin  : def.BinRecipe;
    a    : def.AddrMode;
    tmp  : AddrList;
    res  : def.Operation;
BEGIN
    segm := ocir.ProcSegms^[n];
    FOR i := 0 TO segm.code_len-1 DO
        bin := segm.code^[i].bin;
        WITH
          bin : def.BinRecipeFloatR DO
            bin.ReadMem(a);
            tmp := Member(al,a);
            IF tmp <> NIL THEN
                Addr2STInOp(tmp,segm.code^[i],res);
                segm.code^[i] := res;
            END;
        | bin : def.BinRecipeFloatW DO
            bin.WriteMem(a);
            tmp := Member(al,a);
            IF tmp <> NIL THEN
                Addr2STInOp(tmp,segm.code^[i],res);
                segm.code^[i] := res;
            END;
        ELSE
        END;
        INC(segm.code^[i].FLOAT_SIZE,alloc);
    END;
END Addr2STInNode;

PROCEDURE AddFSTSeq2Node(al : AddrList; n : ir.Node; alloc : SHORTINT);
VAR old        : ocir.Segment;
    FLOAT_SIZE : ir.INT;

    PROCEDURE AddHead(al : AddrList);
    BEGIN
        IF al^.ad.write THEN
            Emit.work.GenMoveM_TOS(al^.ad.addr,al^.ad.sz);
        ELSE
            Emit.work.GenMoveSTi_TOS(0);
        END;
        ocir.c_seg.code[ocir.c_seg.code_len-1].FLOAT_SIZE := FLOAT_SIZE+alloc;
        DEC(alloc);
    END AddHead;

    PROCEDURE Pass(al : AddrList);
    BEGIN
        IF al <> NIL THEN Pass(al^.next); AddHead(al); END;
    END Pass;

BEGIN
    IF ocir.ProcSegms^[n].code_len = 0 THEN
        FLOAT_SIZE := 0
    ELSE
        FLOAT_SIZE := ocir.ProcSegms^[n].code^[0].FLOAT_SIZE;
    END;
    old                := ocir.c_seg;
    buff_segm.code_len := 0;
    ocir.c_seg         := buff_segm;
    Pass(al);
    ocir.AddToStart(ocir.ProcSegms^[n], ocir.c_seg);
    ocir.c_seg := old;
END AddFSTSeq2Node;

PROCEDURE IsFLD_STi(op : def.Operation; i : LONGINT) : BOOLEAN;
VAR bin : def.BinRecipe;
BEGIN
    bin := op.bin;
    WITH bin : Rrd2Bin.MoveTOS_STi DO
        RETURN bin.i = i;
    ELSE
        RETURN FALSE;
    END;
END IsFLD_STi;

PROCEDURE IsFSTP_STi(op : def.Operation; i : LONGINT) : BOOLEAN;
VAR bin : def.BinRecipe;
BEGIN
    bin := op.bin;
    WITH bin : Rrd2Bin.MoveSTi_TOS DO
        RETURN bin.i = i;
    ELSE
        RETURN FALSE;
    END;
END IsFSTP_STi;

PROCEDURE IsFOp_ST0_STi(op : def.Operation; i : LONGINT) : BOOLEAN;
VAR bin : def.BinRecipe;
BEGIN
    bin := op.bin;
    WITH bin : Rrd2Bin.FOpST0_STi DO
        RETURN bin.r = i;
    ELSE
        RETURN FALSE;
    END;
END IsFOp_ST0_STi;

PROCEDURE IsFLD_mem(op : def.Operation) : BOOLEAN;
VAR bin : def.BinRecipe;
BEGIN
    bin := op.bin;
    WITH bin : Rrd2Bin.MoveTOS_M DO RETURN TRUE;
    ELSE RETURN FALSE;
    END;
END IsFLD_mem;

(* �모���� �� ᥣ���� ������� FLD ST0 (������ � s - from)
   � FSTP ST1 (������ � s - to)
   � �⮬ ���ࢠ�� �������� FLOAT_SIZE � �ᯮ�짮����� STi
*)
PROCEDURE RemoveFLD_FSTP(s     : ocir.Segment;
                         from,
                         to    : INTEGER);
VAR i       : INTEGER;
    bin     : def.BinRecipe;
    cur_STi : LONGINT;
BEGIN
    cur_STi := 0;
    FOR i := from TO to-2 DO
        s.code^[i] := s.code^[i+1];
        DEC(s.code^[i].FLOAT_SIZE);
        (* �������� �宦����� STi �� STi-1, �᫨ STi > cur_STi *)
        bin := s.code^[i].bin;
        WITH
          bin : Rrd2Bin.MoveTOS_STi DO
            IF cur_STi < bin^.i THEN DEC(bin^.i); END;
        | bin : Rrd2Bin.MoveSTi_TOS DO
            IF cur_STi < bin^.i THEN DEC(bin^.i); END;
        | bin : Rrd2Bin.MoveSTi_ST0 DO
            IF cur_STi < bin^.i THEN DEC(bin^.i); END;
        | bin : Rrd2Bin.FOpSTi_TOS DO
            IF VAL(SHORTINT,cur_STi) < bin^.r THEN DEC(bin^.r); END;
        | bin : Rrd2Bin.FOpST0_STi DO
            IF VAL(SHORTINT,cur_STi) < bin^.r THEN DEC(bin^.r); END;
        | bin : Rrd2Bin.FComTOS_STi DO
            IF VAL(SHORTINT,cur_STi) < bin^.r THEN DEC(bin^.r); END;
        ELSE
        END;
        (* ��ॢ��᫨�� cur_STi *)
        cur_STi := cur_STi + def.GetFLOAT_SIZE_delta(s.code^[i].code);
    END;
    FOR i := to+1 TO s.code_len-1 DO
        s.code^[i-2] := s.code^[i];
    END;
    DEC(s.code_len,2);
END RemoveFLD_FSTP;

(* fop ST1 -> fopr mem *)
PROCEDURE FOp_ST1_To_FOpR_mem(VAR res : def.Operation;
                                  mem : def.AddrMode;
                                  sz  : Emit.SizeType);
VAR old : ocir.Segment;
    op  : D.FloatOp;
    bin : def.BinRecipe;
    src : def.Operation;
BEGIN
    src := res;
    old := ocir.c_seg;
    buff_segm.code_len := 0;
    ocir.c_seg := buff_segm;
    bin := src.bin;
    WITH bin : Rrd2Bin.FOpST0_STi DO
        CASE bin.op OF
        | D.FADD,
          D.FMUL : op := bin.op;
        | D.FSUB : op := D.FSUBR;
        | D.FSUBR: op := D.FSUB;
        | D.FDIV : op := D.FDIVR;
        | D.FDIVR: op := D.FDIV;
        END;
        Emit.work.GenFOpST0_M(op,mem,sz);
    END;
    res := buff_segm.code^[0];
    res.tpos := src.tpos;
    res.PUSH_SIZE := src.PUSH_SIZE;
    res.NEXT_PUSH_SIZE := src.NEXT_PUSH_SIZE;
    res.FLOAT_SIZE := src.FLOAT_SIZE;
    ocir.c_seg := old;
END FOp_ST1_To_FOpR_mem;

PROCEDURE FOp_ST1_ToFOpSTi_ST0(VAR res : def.Operation; STi : SHORTINT);
VAR old : ocir.Segment;
    bin : def.BinRecipe;
    src : def.Operation;
BEGIN
    src := res;
    old := ocir.c_seg;
    buff_segm.code_len := 0;
    ocir.c_seg := buff_segm;
    bin := src.bin;
    WITH bin : Rrd2Bin.FOpST0_STi DO
        Emit.work.GenFOpSTi_ST0(bin.op,STi);
    END;
    res := buff_segm.code^[0];
    res.tpos := src.tpos;
    res.PUSH_SIZE := src.PUSH_SIZE;
    res.NEXT_PUSH_SIZE := src.NEXT_PUSH_SIZE;
    res.FLOAT_SIZE := src.FLOAT_SIZE;
    ocir.c_seg := old;
END FOp_ST1_ToFOpSTi_ST0;

(* fop ST0,ST1 -> foprp ST1, ST0 *)
PROCEDURE FOp2FOpRP(VAR res : def.Operation);
VAR old : ocir.Segment;
    op  : D.FloatOp;
    bin : def.BinRecipe;
    src : def.Operation;
BEGIN
    src := res;
    old := ocir.c_seg;
    buff_segm.code_len := 0;
    ocir.c_seg := buff_segm;
    bin := src.bin;
    WITH bin : Rrd2Bin.FOpST0_STi DO
        CASE bin.op OF
        | D.FADD,
          D.FMUL : op := bin.op;
        | D.FSUB : op := D.FSUBR;
        | D.FSUBR: op := D.FSUB;
        | D.FDIV : op := D.FDIVR;
        | D.FDIVR: op := D.FDIV;
        END;
        Emit.work.GenFOpSTi_TOS(op,bin.r);
    END;
    res := buff_segm.code^[0];
    res.tpos := src.tpos;
    res.PUSH_SIZE := src.PUSH_SIZE;
    res.NEXT_PUSH_SIZE := src.NEXT_PUSH_SIZE;
    res.FLOAT_SIZE := src.FLOAT_SIZE;
    ocir.c_seg := old;
END FOp2FOpRP;

PROCEDURE RemoveOp(s : ocir.Segment; pos : INTEGER);
VAR i : INTEGER;
BEGIN
    FOR i := pos TO s.code_len-2 DO
        s.code^[i] := s.code^[i+1];
    END;
    DEC(s.code_len);
END RemoveOp;

(* �ᯮ���� �� op STi *)
PROCEDURE UseSTi(op : def.Operation; STi : LONGINT) : BOOLEAN;
VAR bin : def.BinRecipe;
BEGIN
    bin := op.bin;
    WITH
      bin : Rrd2Bin.MoveTOS_STi DO
          RETURN bin^.i = STi;
      | bin : Rrd2Bin.MoveSTi_TOS DO
          RETURN bin^.i = STi;
      | bin : Rrd2Bin.MoveSTi_ST0 DO
          RETURN bin^.i = STi;
      | bin : Rrd2Bin.FOpSTi_TOS DO
          RETURN bin^.r = VAL(SHORTINT,STi);
      | bin : Rrd2Bin.FOpST0_STi DO
          RETURN bin^.r = VAL(SHORTINT,STi);
      | bin : Rrd2Bin.FComTOS_STi DO
          RETURN bin^.r = VAL(SHORTINT,STi);
      ELSE
          RETURN FALSE;
      END;
END UseSTi;

(*  �� �ᯮ�짮����� ST(i),i>=from, ������� �� ST(i+1) *)
PROCEDURE IncUseSTi(VAR op : def.Operation; from : SHORTINT);
VAR bin : def.BinRecipe;
BEGIN
    bin := op.bin;
    WITH
      bin : Rrd2Bin.MoveTOS_STi DO
          IF bin^.i >= from THEN
              INC(bin^.i);
              op.dest.r := VAL(def.Register, ORD(op.dest.r)+1);
          END;
      | bin : Rrd2Bin.MoveSTi_TOS DO
          IF bin^.i >= from THEN
              INC(bin^.i);
              op.dest.r := VAL(def.Register, ORD(op.dest.r)+1);
          END;
      | bin : Rrd2Bin.MoveSTi_ST0 DO
          IF bin^.i >= from THEN
              INC(bin^.i);
              op.dest.r := VAL(def.Register, ORD(op.dest.r)+1);
              op.attrs.res.r := def.Regs{op.dest.r};
          END;
      | bin : Rrd2Bin.FOpSTi_TOS DO
          IF bin^.r >= from THEN
              INC(bin^.r);
              op.dest.r := VAL(def.Register, ORD(op.dest.r)+1);
          END;
      | bin : Rrd2Bin.FOpST0_STi DO
          IF bin^.r >= from THEN
              INC(bin^.r);
              op.dest.r := VAL(def.Register, ORD(op.dest.r)+1);
              op.attrs.arg.r := def.Regs{def.ST0,op.src.r};
          END;
      | bin : Rrd2Bin.FOpSTi_ST0 DO
          IF bin^.r >= from THEN
              INC(bin^.r);
              op.dest.r := VAL(def.Register, ORD(op.dest.r)+1);
              op.attrs.arg.r := def.Regs{def.ST0,op.dest.r};
              op.attrs.res.r := def.Regs{op.dest.r};
          END;
      | bin : Rrd2Bin.FComTOS_STi DO
          IF bin^.r >= from THEN
              INC(bin^.r);
              op.dest.r := VAL(def.Register, ORD(op.dest.r)+1);
          END;
          INC(bin^.r);
              op.dest.r := VAL(def.Register, ORD(op.dest.r)+1);
      ELSE
      END;
END IncUseSTi;

(* � ��ࢮ� ��室� ������� ��᫥����⥫쭮��
        FLD ST0
        seq - ��᫥����⥫쭮��� ������, �� �ᯮ������ ST1
        FSTP ST1
        ��
        seq,

        FLD mem
        fop ST1
        seq - ��᫥����⥫쭮��� ������, �� �ᯮ������ ST1
        FSTP ST1
        ��
        fopr mem
        seq

        FLD STi
        fop ST1
        FSTP ST(i+1)
        ��
        fop STi, ST0
   �� ��஬ ��室� ������� ��᫥����⥫쭮���
        fop ST1
        FSTP ST1
        ��
        foprp ST1
*)
PROCEDURE PeepAfterFL(n : ir.Node);
VAR s          : ocir.Segment;
    i, j       : INTEGER;
    from_op,
    to_op      : def.Operation;
    cur_STi    : LONGINT;
    FLOAT_SIZE : ir.INT;
    bin        : def.BinRecipe;
    a          : def.AddrMode;
BEGIN
    s := ocir.ProcSegms^[n];
    i := 0;
    LOOP
        IF i = s.code_len THEN EXIT END;
        from_op := s.code^[i];
        IF IsFLD_STi(from_op,0) & (i < s.code_len-1) THEN
            FLOAT_SIZE := from_op.FLOAT_SIZE;
            j := i+1;
            cur_STi := 1;
            LOOP
                IF j = s.code_len THEN INC(i); EXIT END;
                to_op := s.code^[j];
                IF (to_op.code = def.FSTP) &
                   (to_op.FLOAT_SIZE = FLOAT_SIZE+1) THEN
                   IF IsFSTP_STi(to_op,1) THEN
                       RemoveFLD_FSTP(s,i,j);
                       i := 0;
                   ELSE
                       INC(i);
                   END;
                   EXIT;
                ELSIF UseSTi(to_op,cur_STi) THEN
                    INC(i);
                    EXIT
                END;
                cur_STi := cur_STi + def.GetFLOAT_SIZE_delta(to_op.code);
                INC(j);
            END;
        ELSIF IsFLD_mem(from_op) & (i < s.code_len-2) &
              IsFOp_ST0_STi(s.code^[i+1],1)
        THEN
            FLOAT_SIZE := from_op.FLOAT_SIZE;
            j := i+2;
            cur_STi := 1;
            LOOP
                IF j = s.code_len THEN INC(i); EXIT END;
                to_op := s.code^[j];
                IF (to_op.code = def.FSTP) &
                   (to_op.FLOAT_SIZE = FLOAT_SIZE+1) THEN
                   IF IsFSTP_STi(to_op,1) THEN
                       bin := from_op.bin;
                       WITH bin : Rrd2Bin.MoveTOS_M DO
                           bin.ReadMem(a);
                           FOp_ST1_To_FOpR_mem(s.code^[i+1],
                                               a,
                                               bin.GetReadSz());
                       END;
                       RemoveFLD_FSTP(s,i,j);
                       i := 0;
                   ELSE
                       INC(i);
                   END;
                   EXIT;
                ELSIF UseSTi(to_op,cur_STi) THEN
                    INC(i);
                    EXIT
                END;
                cur_STi := cur_STi + def.GetFLOAT_SIZE_delta(to_op.code);
                INC(j);
            END;
        ELSIF (from_op.code = def.FLD) &
              (def.GetOpOpndKind(from_op.dest.r) = def.REG) &
              (i < s.code_len-2) &
              IsFOp_ST0_STi(s.code^[i+1],1) &
              (s.code^[i+2].code = def.FSTP) &
              (def.GetOpOpndKind(s.code^[i+2].dest.r) = def.REG) &
              (from_op.dest.r = VAL(def.Register,ORD(s.code^[i+2].dest.r)+1))
        THEN
            FOp_ST1_ToFOpSTi_ST0(s.code^[i+1],VAL(SHORTINT,from_op.dest.r)-VAL(SHORTINT,def.ST0));
            RemoveFLD_FSTP(s,i,i+2);
            i := 0;
        ELSE
            INC(i);
        END;
    END;
    i := 0;
    LOOP
        IF i = s.code_len THEN EXIT END;
        IF IsFOp_ST0_STi(s.code^[i],1) & (i <> s.code_len-1) &
           IsFSTP_STi(s.code^[i+1],1)
        THEN
            FOp2FOpRP(s.code^[i]);
            INC(i);
            RemoveOp(s,i);
        ELSE
            INC(i);
        END;
    END;
END PeepAfterFL;

PROCEDURE OptimizeLoop(l : Loop);
VAR tmp,
    tmp1  : AddrList;
    alloc,
    offs  : SHORTINT; -- ᪮�쪮 㤠���� �������� �� �⥪;
    out   : Loop;
    n     : ir.Node;
    old   : ocir.Segment;
    Exits : BitVect.BitVector;
    j  : ir.INT;
    i:  ir.TSNode;
    old_tpos : ir.TPOS;
BEGIN
    IF LoopDescs^[l].max_FS = 7 THEN
        BitVect.Incl(discarded,ORD(l));
        RETURN;
    END;
    LoopDescs^[l].candidates := SortList(LoopDescs^[l].candidates);
    tmp := LoopDescs^[l].candidates;
    alloc := 0;
    (* ᭠砫� ��।���� �� max_FS, ᪮�쪮 ����� �뤢����� �� �⥪*)
    LOOP
        INC(LoopDescs^[l].max_FS);
        INC(alloc);
        IF LoopDescs^[l].max_FS >=7 THEN
            tmp1 := tmp^.next;
            WHILE tmp1 <> NIL DO
                BitVect.Free(tmp1^.ad.used_in);
                tmp1 := tmp1^.next;
            END;
            tmp^.next := NIL;
        END;
        tmp := tmp^.next;
        IF (tmp = NIL) THEN EXIT END;
    END;
    (* ⥯��� � candidates ⮫쪮 �, �� �㤥� ��类 ������ �� �⥪ *)
    (* ⥯��� �� ��ॢ�୥�, ���� �������� ��� �ᯮ��㥬� �������� ��
       �⥪ ��᫥�����
    *)
    LoopDescs^[l].candidates := ReverseList(LoopDescs^[l].candidates);
    (* 㢥����� �� alloc max_FS � ��� �墠�뢠��� 横��� *)
    FOR out := SYSTEM.SUCC(l) TO SYSTEM.PRED(gr.NLoops) DO
        IF gr.LoopInLoop(l,out) THEN
            INC(LoopDescs^[out].max_FS,alloc);
            IF LoopDescs^[out].max_FS >= 8 THEN
                BitVect.Incl(discarded,ORD(out));
            END;
        END;
    END;
    tmp := LoopDescs^[l].candidates;
    (* ��⠥� ST_offs � � PreHeader ��ᮢ뢠�� FLD *)
    old := ocir.c_seg;
    ocir.c_seg := ocir.ProcSegms[gr.LoopList^[l].Preheader];
    offs := alloc-1;
    old_tpos := def.CURRENT_TPOS;
    def.CURRENT_TPOS := env.null_pos;
    REPEAT
        IF tmp^.ad.write & FirstWrite(tmp^.ad.addr,l) THEN
            Emit.work.GenFOp(D.FLDZ);
        ELSE
            Emit.work.GenMoveTOS_M(tmp^.ad.addr, tmp^.ad.sz);
        END;
        (* ��ॢ��᫨�� ��ਡ��� ����������� FLD -
           PUSH_SIZE, FLOAT_SIZE � �ਧ���� NOT_MOVABLE-��
        *)
        ocir.EvalLastAttrs;
        tmp^.ad.ST_offs := offs;
        DEC(offs);
        tmp :=tmp^.next;
    UNTIL offs < 0;
    def.CURRENT_TPOS := old_tpos;
    (* �����塞 ���� �� ST_i *)
    FOR i := SYSTEM.SUCC(ir.Nodes^[gr.LoopList^[l].Preheader].TopNumber)
        TO SYSTEM.PRED(LEN(ir.Order^))
    DO
        IF BitVect.In(gr.LoopList^[l].Body,ORD(ir.Order^[i])) THEN
            Addr2STInNode(LoopDescs^[l].candidates,ir.Order^[i],alloc);
            PeepAfterFL(ir.Order^[i]);
        END;
    END;
    (* ⥯��� �� ��� ���⪠� ��᫥ 横�� ��⠢��� ��᫥����⥫쭮���
       FSTP ST0 �᫨ � ���� �� ��ᠫ�,
       FST addr ����
    *)
    Exits := gr.LoopList^[l].Exits;
    FOR i := SYSTEM.SUCC(ir.Nodes^[gr.LoopList^[l].Preheader].TopNumber)
        TO SYSTEM.PRED(LEN(ir.Order^))
    DO
        n := ir.Order^ [i];
        IF BitVect.In(Exits,ORD(n)) THEN
            FOR j := 0 TO ir.Nodes^[n].NOut-1 DO
                IF NOT gr.NodeInLoop (ir.Nodes^[n].Out^[j], l) THEN
                    ASSERT(ir.Nodes[ir.Nodes^[n].Out^[j]].NIn=1);
                    AddFSTSeq2Node(LoopDescs^[l].candidates,
                                   ir.Nodes^[n].Out^[j],
                                   alloc);
                END;
            END;
        END;
    END;
    ocir.c_seg := old;
END OptimizeLoop;


PROCEDURE FLClear();
VAR l : Loop;
BEGIN
    FOR l := ir.ZEROLoop TO SYSTEM.PRED(gr.NLoops) DO
        ClearScales(LoopDescs^[l].candidates);
        LoopDescs^[l].candidates := NIL;
        LoopDescs^[l].fmem       := NIL;
        ClearScales(LoopDescs^[l].mem);
        LoopDescs^[l].mem    := NIL;
    END;
    BitVect.Free(discarded);
    LoopDescs := NIL;
END FLClear;

PROCEDURE FLOptimizeMain*;
VAR l : Loop;
BEGIN
    ocir.new_segm(buff_segm);
    InitLoopDescs;
    EvalCandidates;
    CalcMaxLoop;
    FOR l := ir.ZEROLoop TO SYSTEM.PRED(gr.NLoops) DO
        IF NOT BitVect.In(discarded,ORD(l)) THEN OptimizeLoop(l); END;
    END;
    FLClear;
END FLOptimizeMain;

(* ��⠥��� ����, ��稭�� � start, ��᫥����⥫�� ��᮪,
   ��稭��騩�� � ����㧪� 祣�-� �� �⥪, ࠡ���騩 ⮫쪮 � ���設��
   �⥪�, � �����騩�� ���㧪�� � 㬥��襭��� �⥪�
   �����頥� �ਧ��� 㤠筮�� ���᪠
*)
PROCEDURE FindTrace(sg             : ocir.Segment;
                    start          : INTEGER;
                    VAR from,
                        to,
                        next_start : INTEGER;
                    float_allowed  : BOOLEAN) : BOOLEAN;
VAR i     : INTEGER;
BEGIN
    i := start;
    from := def.UNDEF_POS;
    to   := def.UNDEF_POS;
    next_start := sg.code_len;
    WHILE (i < sg.code_len) & (from = def.UNDEF_POS) DO
        IF (sg.code[i].FLOAT_SIZE >=8) THEN
            next_start := i+1;
            RETURN FALSE;
        ELSIF sg.code[i].code = def.FLD THEN
            from := i;
        ELSIF (sg.code[i].attrs.pair IN def.PairTags{def.FP,def.FNP}) &
              (NOT float_allowed)
        THEN
            next_start := i + 1;
            RETURN FALSE;
        ELSIF def.GetFLOAT_SIZE_delta(sg.code[i].code) <> 0 THEN
            next_start := i+1;
            RETURN FALSE;
        ELSE
            INC(i);
        END;
    END;
    IF from = def.UNDEF_POS THEN
        RETURN FALSE;
    END;
    i := from+1;
    WHILE (i < sg.code_len) & (to = def.UNDEF_POS) DO
        CASE def.GetFLOAT_SIZE_delta(sg.code[i].code) OF
        | 1 :
            next_start := i;
            RETURN FALSE;
        | -1:
            next_start := i+1;
            to := i;
        ELSE
            INC(i);
        END;
    END;
    RETURN (to<>def.UNDEF_POS) & (to>from+1);
END FindTrace;

TYPE ArgResDesc = RECORD
                      r:  def.Regs;
                      f : def.Flags;
                      m    : AddrList;
                  END;
(* ���ᥪ����� �� ��㬥���    sg.code[from..to]
                 � १���⠬� sg.code[from1..to1]
    � �������
*)
PROCEDURE IntersectArgRes(sg        : ocir.Segment;
                          from,to,
                          from1,to1 : INTEGER; loop: Loop) : BOOLEAN;

VAR arg1, arg2,
    res1, res2 : ArgResDesc;
    b          : BOOLEAN;

    PROCEDURE ScanInterval(from,to     : INTEGER;
                           dif         : LONGINT;
                           VAR arg,res : ArgResDesc);
    VAR i   : INTEGER;
        bin : def.BinRecipe;
        a   : def.AddrMode;
    BEGIN
        arg := ArgResDesc{{},{},NIL};
        res := ArgResDesc{{},{},NIL};
        FOR i := from TO to DO
            arg.r := arg.r + sg.code[i].attrs.arg.r*def.Regs{def.EAX..def.EDI};
            arg.f := arg.f + sg.code[i].attrs.arg.f;
            res.r := res.r + sg.code[i].attrs.res.r*def.Regs{def.EAX..def.EDI};
            res.f := res.f + sg.code[i].attrs.res.f;
            bin   := sg.code[i].bin;
            (* ���_�_��� � ������� *)
            WITH
              bin : def.BinRecipeR DO
                bin.ReadMem(a);
                AddAddr(arg.m,a,ir.ZERONode,TRUE,IsUnknownAddr(a,loop),TRUE,bin.GetReadSz());
            | bin : def.BinRecipeW DO
                bin.WriteMem(a);
                AddAddr(res.m,a,ir.ZERONode,TRUE,IsUnknownAddr(a,loop),FALSE,bin.GetWriteSz());
            | bin : def.BinRecipeRW DO
                bin.ReadMem(a);
                AddAddr(arg.m,a,ir.ZERONode,TRUE,IsUnknownAddr(a,loop),TRUE,bin.GetReadSz());
                bin.WriteMem(a);
                AddAddr(res.m,a,ir.ZERONode,TRUE,IsUnknownAddr(a,loop),FALSE,bin.GetWriteSz());
            ELSE
            END;
            (* ���_�_��� �R ��_�R� *)
            WITH
              bin : Rrd2Bin.MoveTOS_STi DO
                ASSERT(i=from);
                INCL(arg.r,VAL(def.Register, ORD(sg.code[i].dest.r)+dif+1));
            | bin : Rrd2Bin.MoveSTi_TOS DO
                ASSERT(i=to);
                --IF sg.code[i].dest.r <> def.ST0 THEN
                    INCL(res.r, VAL(def.Register,ORD(sg.code[i].dest.r)+dif));
                --END;
            | bin : Rrd2Bin.FOpSTi_TOS  DO
                ASSERT(i=to);
                --IF sg.code[i].dest.r <> def.ST0 THEN
                    INCL(res.r, VAL(def.Register,ORD(sg.code[i].dest.r)+dif));
                --END;
            | bin : Rrd2Bin.MoveSTi_ST0  DO
                INCL(res.r,VAL(def.Register, ORD(sg.code[i].dest.r)+dif));
            | bin : Rrd2Bin.FOpSTi_ST0  DO
                INCL(res.r,VAL(def.Register, ORD(sg.code[i].dest.r)+dif));
            | bin : Rrd2Bin.FOpST0_STi  DO
                INCL(arg.r,VAL(def.Register, ORD(sg.code[i].src.r)+dif));
            ELSE
            END;
        END;
        arg.r := arg.r - def.Regs{def.ST0};
        res.r := res.r - def.Regs{def.ST0};
    END ScanInterval;
BEGIN
    IF (from>to) OR (from1>to1) THEN RETURN FALSE; END;
    ScanInterval(from,to,0,arg1,res1);
    ScanInterval(from1,to1,
                 sg.code[from].FLOAT_SIZE-sg.code[from1].FLOAT_SIZE,
                 arg2,res2);
    b := ListsCanIntersect(arg1.m,res2.m,res1.r+res2.r) OR
         ListsCanIntersect(arg2.m,res1.m,res1.r+res2.r);
    ClearScales(arg1.m); ClearScales(arg2.m);
    ClearScales(res1.m); ClearScales(res2.m);
    RETURN b OR (arg1.r*res2.r <> def.Regs{}) OR
                (arg1.f*res2.f <> def.Flags{}) OR
                (arg2.r*res1.r <> def.Regs{}) OR
                (arg2.f*res1.f <> def.Flags{});
END IntersectArgRes;

(* ��६�訢��� ��� ������ᨬ�� ���ࢠ�� � ��㡮 ����⢥��묨 �����ﬨ,
   �����頥� �᫮ ����������� FXCH
*)
PROCEDURE Glue(sg         : ocir.Segment;
               from1, to1,
               from2,to2  : INTEGER) : INTEGER;
VAR old           : ocir.Segment;
    i, pos1, pos2,
    added         : INTEGER;
    old_tpos      : ir.TPOS;
BEGIN
    old := ocir.c_seg;
    ocir.copy_segm_by_len(ocir.c_seg,sg.code_len);
    ocir.c_seg.code_len := 0;
    FOR i := 0 TO from1+1 DO
        ocir.c_seg.code[i] := sg.code[i];
        INC(ocir.c_seg.code_len);
    END;
    IncUseSTi(sg.code[from2],0);
    ocir.simple_add(ocir.c_seg,sg.code[from2]);
    IncUseSTi(sg.code[from2+1],1);
    ocir.simple_add(ocir.c_seg,sg.code[from2+1]);
    pos1  := from1+2;
    pos2  := from2+2;
    added := 0;
    WHILE (pos1 < to1) & (pos2 < to2) DO
        INC(added,2);
        old_tpos := def.CURRENT_TPOS;
        def.CURRENT_TPOS := sg.code[pos1].tpos;
        Emit.work.GenFOp(D.FXCH);
        def.CURRENT_TPOS := old_tpos;
        IncUseSTi(sg.code[pos1],1);
        ocir.simple_add(ocir.c_seg,sg.code[pos1]);
        old_tpos := def.CURRENT_TPOS;
        def.CURRENT_TPOS := sg.code[pos2].tpos;
        Emit.work.GenFOp(D.FXCH);
        def.CURRENT_TPOS := old_tpos;
        IncUseSTi(sg.code[pos2],1);
        ocir.simple_add(ocir.c_seg,sg.code[pos2]);
        INC(pos1);
        INC(pos2);
    END;
    IF pos1=to1 THEN
        INC(added);
        old_tpos := def.CURRENT_TPOS;
        def.CURRENT_TPOS := sg.code[pos1].tpos;
        Emit.work.GenFOp(D.FXCH);
        def.CURRENT_TPOS := old_tpos;
        IncUseSTi(sg.code[pos1],1);
        ocir.simple_add(ocir.c_seg,sg.code[pos1]);
        WHILE pos2 <= to2 DO
            ocir.simple_add(ocir.c_seg,sg.code[pos2]);
            INC(pos2);
        END;
    ELSE
        INC(added);
        old_tpos := def.CURRENT_TPOS;
        def.CURRENT_TPOS := sg.code[pos1].tpos;
        Emit.work.GenFOp(D.FXCH);
        def.CURRENT_TPOS := old_tpos;
        IncUseSTi(sg.code[pos1],1);
        ocir.simple_add(ocir.c_seg,sg.code[pos1]);
        INC(added);
        old_tpos := def.CURRENT_TPOS;
        def.CURRENT_TPOS := sg.code[pos2].tpos;
        Emit.work.GenFOp(D.FXCH);
        def.CURRENT_TPOS := old_tpos;
        IncUseSTi(sg.code[pos2],1);
        ocir.simple_add(ocir.c_seg,sg.code[pos2]);
        INC(pos1);
        WHILE pos1<=to1 DO
            ocir.simple_add(ocir.c_seg,sg.code[pos1]);
            INC(pos1);
        END;
    END;
    FOR i := to1+1 TO from2-1 DO ocir.simple_add(ocir.c_seg,sg.code[i]); END;
    FOR i := to2+1 TO sg.code_len-1 DO ocir.simple_add(ocir.c_seg,sg.code[i]); END;
    sg.code := ocir.c_seg.code;
    sg.code_len := ocir.c_seg.code_len;
    ocir.c_seg := old;
    RETURN added;
END Glue;

(* does interval [from,to] include a call instruction? *)
PROCEDURE WithCall(sg : ocir.Segment;
                      from, to : INTEGER) : BOOLEAN;
VAR i : INTEGER;
    bin : def.BinRecipe;
BEGIN
  IF from>to THEN 
    RETURN FALSE; 
  END;
  FOR i := from TO to DO 
    bin := sg.code[i].bin;
    WITH
      bin : Rrd2Bin.Call_R DO 
        RETURN TRUE;
    | bin : Rrd2Bin.Call_M DO
        RETURN TRUE;
    | bin : Rrd2Bin.Call_Iglobal DO
        RETURN TRUE;
    | bin : Rrd2Bin.Halt DO
         RETURN TRUE;
    | bin : Rrd2Bin.Raise DO 
        RETURN TRUE;
    | bin : Rrd2Bin.CallToOrdinal DO 
        RETURN TRUE;
    ELSE
    END;
  END;
  RETURN FALSE;
END WithCall;

PROCEDURE Insert_FXCH*(node: ir.Node);
VAR sg : ocir.Segment;
    loop : Loop;
    from1,  to1,
    from2, to2,
    cur_start,
    next_start : INTEGER;
BEGIN
    sg := ocir.ProcSegms[node];
    loop := ir.Nodes[node].LoopNo;
    cur_start := 0;
    LOOP
        IF cur_start = sg.code_len THEN EXIT; END;
        IF FindTrace(sg,cur_start,from1,to1,next_start,TRUE) &
           FindTrace(sg,to1+1,from2,to2,next_start,FALSE)    &
           (NOT IntersectArgRes(sg,from1,to1,from2,to2,loop)) &
           (NOT IntersectArgRes(sg,to1+1,from2-1,from2,to2,loop)) &
           (NOT WithCall(sg,to1+1,from2-1))
        THEN
            (*
            ocirtxt.PrintSegmentInterval(sg,FALSE,TRUE,from1,to1);
            ocirtxt.PrintSegmentInterval(sg,FALSE,TRUE,to1+1,from2-1);
            ocirtxt.PrintSegmentInterval(sg,FALSE,TRUE,from2,to2);
            *)
            cur_start := to2 + Glue(sg,from1,to1,from2,to2) + 1;
        ELSE
            cur_start := next_start;
        END;
    END;
END Insert_FXCH;

(*
BEGIN
    ocirtxt.Init_ocirtxt("floops.txt");
*)
END FLoops.
