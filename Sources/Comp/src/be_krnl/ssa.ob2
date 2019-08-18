MODULE ssa;

<* IF DEFINED(MeDebugMode) AND MeDebugMode THEN *>
  <* procinline- *>
  <* noregvars+  *>
<* ELSE *>
  <* procinline+ *>
<* END *>

(*
  ��ॢ�� �ணࠬ�� � SSA ��� (�뢮� �� �� ��� - ����� Color)
*)

IMPORT ir;
IMPORT gr := ControlGraph;
IMPORT opProcs;
IMPORT opAttrs;
IMPORT opTune;
IMPORT TestIO;
IMPORT bv := BitVect;
IMPORT at := opAttrs;
IMPORT lh := LocalHeap;
IMPORT SYSTEM;
(*----------------------------------------------------------------------------*)

TYPE
    INT          = ir.INT;
    Node         = ir.Node;
    ParamPtr     = ir.ParamPtr;
    ParamArray   = ir.ParamArray;
    TriadePtr    = ir.TriadePtr;
    TriadeArray  = ir.TriadeArray;
    Local        = ir.Local;
    VarNum       = ir.VarNum;
    TPOS         = ir.TPOS;
    BitVector    = bv.BitVector;
    TypeType     = ir.TypeType;
    SizeType     = ir.SizeType;

    VarRange  = ir.VarNum[ir.VarNum{0}..ir.VarNum{32767}];
    NodeRange = ir.Node[ir.Node{0}..ir.Node{32767}];

    BitVectArrayVar  = POINTER ["Modula"] TO ARRAY VarRange OF BitVector;
    BitVectArrayNode = POINTER ["Modula"] TO ARRAY NodeRange OF BitVector;

    NodeArray = POINTER ["Modula"] TO ARRAY NodeRange OF ir.Node;

(*
  NodeRec - ���ଠ�� �� 㪠��⥫� � ���� ��������� ���⪠:
      AnyRef         - 㪠��⥫� �� ����� ��६���� ����� ���� � �����
      LocalsPointsTo - �㤠 ����� 㪠�뢠�� ������
*)

    NodeRec      = RECORD
                        AnyRef:         BitVector;
                        LocalsPointsTo: BitVectArrayVar;
                   END;
    SRecord      = RECORD
                        len: INT;
                        v:   ARRAY 32768 OF VarNum;
                   END;
    SPtr         = POINTER ["Modula"] TO SRecord;


CONST
    UNDEFINED = ir.UNDEFINED;
    UndefNode = ir.UndefNode;

VAR
    HasAlready:    BitVectArrayVar;
    Work:          BitVectArrayVar;
    Count:         POINTER ["Modula"] TO ARRAY VarRange OF INTEGER;
    S:             POINTER ["Modula"] TO ARRAY VarRange OF SPtr;
    PointersArray: POINTER ["Modula"] TO ARRAY NodeRange OF NodeRec;
    AnyLocal:      Local;
    VarsPointsTo:  BitVectArrayVar;
    AnyRef:        BitVector;
    AllFalse:      BitVector;
    Changed:       BOOLEAN;
    current:       NodeRec;
    tmp2:          BitVector;
    tmp:           BitVector;

(*----------------------------------------------------------------------------*)

(*PROCEDURE BitVect_In (p: bv.BitVector; e: INT): BOOLEAN;
--inlined from bitvect
BEGIN
<* IF backend = "C" THEN *>
    RETURN ({e MOD bv.BitsPerSet} * p^.v [VAL (CARDINAL, e) / bv.BitsPerSet]) # {};
<* ELSE *>
    RETURN ({e MOD bv.BitsPerSet} * p^.v [e DIV bv.BitsPerSet]) # {};
<* END *>
END BitVect_In;

PROCEDURE BitVect_Incl (p: bv.BitVector; e: INT);
--inlined from bitvect
BEGIN
<* IF backend = "C" THEN *>
    INCL (p^.v [VAL (CARDINAL, e)  / bv.BitsPerSet], e MOD bv.BitsPerSet);
<* ELSE *>
    INCL (p^.v [e DIV bv.BitsPerSet], VAL(SYSTEM.CARD8, e MOD bv.BitsPerSet));
<* END *>
END BitVect_Incl;
*)
(*----------------------------------------------------------------------------*)

(*
  ������� �� ����� ᪠��஬?
*)

PROCEDURE IsScalar (l: Local): BOOLEAN;
BEGIN
    RETURN ir.Locals^[l].VarType IN ir.TypeTypeSet{ ir.t_int, ir.t_unsign,
                                      ir.t_float, ir.t_ref };
END IsScalar;

(*----------------------------------------------------------------------------*)

(*
  ����쪮 ������ ��⠭������ � ��⮢�� �����?
*)

PROCEDURE CalcOnes (v: BitVector): INT;
VAR n: INT;
    i: ir.Local;
BEGIN
    n := 0;
    FOR i:= 0 TO ir.NLocals DO
        IF bv.In (v, ORD(i)) THEN
            INC (n);
        END;
    END;
    RETURN n;
END CalcOnes;

(*----------------------------------------------------------------------------*)

(*
  ��ࠬ��� - ���᭠� ����⠭� ?
*)

PROCEDURE GetAddrConst (p: ParamPtr): Local;
VAR q: TriadePtr;
BEGIN
    LOOP
        IF p^.tag = ir.y_AddrConst THEN
            RETURN p^.name;
        ELSIF p^.tag <> ir.y_Variable THEN
            RETURN UNDEFINED;
        END;
        q := ir.Vars^[p^.name].Def;
        IF ((q^.Op <> ir.o_assign) & (q^.Op <> ir.o_val)) OR
           (q^.ResType = ir.t_float) OR (q^.ResSize <> opTune.addr_sz)
        THEN
            RETURN UNDEFINED;
        END;
        p := q^.Params^[0];
    END;
END GetAddrConst;

(*----------------------------------------------------------------------------*)

(*
  ����⠫쭠� ����窠: �᫨ �� ��६ ���� RE(x), � �����६����
  �� ��६ � ���� IM(x)
*)

PROCEDURE CheckImaginary (l: Local; v: BitVector);
BEGIN
    IF (ir.Locals^[l].VarType = ir.t_float) & opProcs.IsComplexParam (l) THEN
        bv.Incl (v, ORD(opProcs.ImPart (l)));
    END;
END CheckImaginary;

(*----------------------------------------------------------------------------*)
(*
  �㤠 ����� 㪠�뢠�� ��ࠬ���?
*)

PROCEDURE CanPointsTo (p: ParamPtr): BitVector;
VAR l: Local;
BEGIN
    CASE p^.tag OF
    | ir.y_Variable:    IF VarsPointsTo^[p^.name] <> NIL THEN
                            RETURN VarsPointsTo^[p^.name];
                        ELSE
                            l := GetAddrConst (p);
                            IF l = UNDEFINED THEN
                                RETURN current.AnyRef;
                            ELSE
                                bv.Fill (tmp2, FALSE, ORD(ir.NLocals) + 1);
                                bv.Incl (tmp2, ORD(l));
                                CheckImaginary (l, tmp2);
                                RETURN tmp2;
                            END;
                        END;
    | ir.y_RealVar:     IF current.LocalsPointsTo^[p^.name] <> NIL THEN
                            RETURN current.LocalsPointsTo^[p^.name];
                        ELSE
                            RETURN current.AnyRef;
                        END;
    | ir.y_AddrConst:   IF p^.name <> MAX (Local) THEN
                            bv.Fill (tmp2, FALSE, ORD(ir.NLocals) + 1);
                            bv.Incl (tmp2, ORD(p^.name));
                            CheckImaginary (p^.name, tmp2);
                            RETURN tmp2;
                        ELSE
                            RETURN AllFalse;
                        END;
    | ir.y_NumConst,
      ir.y_RealConst,
      ir.y_ComplexConst:
                        RETURN AllFalse;

    | ir.y_ProcConst:   RETURN current.AnyRef;
    END;
END CanPointsTo;


-- returns closure of sequential applications
-- CanPointsTo(CanPointsTo(...CanPointsTo(p)..))
-- thus any location reachable by dereferences from p is included 
-- into resulting bit vector
PROCEDURE CanPointsToCl (p: ParamPtr): BitVector;
VAR v, v2: BitVector;
    flag: BOOLEAN;
    i: ir.Local;
BEGIN
    v := CanPointsTo(p);
    IF v = NIL THEN
        RETURN NIL;
    END;
    REPEAT
        flag := FALSE;
        FOR i := 0 TO ir.NLocals-1 DO 
            v2 := current.LocalsPointsTo^[i];
            IF v2 # NIL THEN
                flag := bv.UnionAssign(v, v2) OR flag;
            END;
        END;
    UNTIL flag = FALSE;
    RETURN v;
END CanPointsToCl;

(*----------------------------------------------------------------------------*)

VAR AliasHeap: lh.heapID;
(*
  �뤥���� ������ ��� ���� NodeRec
*)

PROCEDURE InitNodeRec (VAR n: NodeRec);
VAR a: BitVectArrayVar;
    l: ir.Local;
BEGIN
    n.AnyRef := bv.New_Ex (AliasHeap, ORD(ir.NLocals)+1, FALSE);
    bv.Move (AnyRef, n.AnyRef);
    IF ir.NLocals = 0 THEN
        a := NIL;
    ELSE
        lh.ALLOCATE( AliasHeap, a, VAL (INT, ir.NLocals) * SIZE (BitVector) );
        FOR l:=0 TO ir.NLocals-1 DO
            IF ir.Locals^[l].VarType = ir.t_ref THEN
                a^[l] := bv.New_Ex (AliasHeap, ORD(ir.NLocals)+1, FALSE);
            ELSE
                a^[l] := NIL;
            END;
        END;
    END;
    n.LocalsPointsTo := a;
END InitNodeRec;

(*----------------------------------------------------------------------------*)

(*
  d := s
*)

PROCEDURE MoveNodeRec (VAR s, d: NodeRec);
VAR l: Local;
BEGIN
    bv.Move (s.AnyRef, d.AnyRef);
    FOR l:=0 TO ir.NLocals-1 DO
        IF s.LocalsPointsTo^[l] <> NIL THEN
            bv.Move (s.LocalsPointsTo^[l], d.LocalsPointsTo^[l]);
        END;
    END;
END MoveNodeRec;

(*----------------------------------------------------------------------------*)

(*
  d += s
*)

PROCEDURE UnionAssignNodeRec (VAR s, d: NodeRec);
VAR l: Local;
BEGIN
    Changed := bv.UnionAssign (d.AnyRef, s.AnyRef) OR Changed;
    FOR l:=0 TO ir.NLocals-1 DO
        IF s.LocalsPointsTo^[l] <> NIL THEN
            Changed := bv.UnionAssign (d.LocalsPointsTo^[l],
                                            s.LocalsPointsTo^[l]) OR Changed;
        END;
    END;
END UnionAssignNodeRec;

(*----------------------------------------------------------------------------*)

(*
  ������� ���ଠ�� �� �室� � ������� ���⮪ � current -
           ���� ��ꥤ����� �� �� �ᥬ �।��⢥������
*)

PROCEDURE Enter (n: Node);
VAR i: INT;
    l: Local;
BEGIN
    MoveNodeRec (PointersArray^[ir.Nodes^[n].In^[0]], current);
    FOR i:=1 TO ir.Nodes^[n].NIn-1 DO
        FOR l:=0 TO ir.NLocals-1 DO
            IF current.LocalsPointsTo^[l] <> NIL THEN
                bv.Union (current.LocalsPointsTo^[l],
                         PointersArray^[ir.Nodes^[n].In^[i]].LocalsPointsTo^[l],
                         current.LocalsPointsTo^[l]);
            END;
        END;
        bv.Union (current.AnyRef,
                       PointersArray^[ir.Nodes^[n].In^[i]].AnyRef,
                       current.AnyRef);
    END;
END Enter;

(*----------------------------------------------------------------------------*)

(*
  �ந�����஢��� (��� ������� 㪠��⥫��) ���� �ਠ��
*)

PROCEDURE InterpreteTriade (p: TriadePtr);
VAR vec: BitVector;
      i: INT;
      l: Local;
      r: ir.VarNum;
nparams: INT;
BEGIN
(*
  �०�� �ᥣ�: ����� ����� ���� ������ ��䥪� �� �ᯮ������ �ਠ��?
  - �맮�: ���� �� - ���� � �⠥� ���� ������, �஬� ⮣�, �� ���� �
                      �⠥� ��ᢥ��� �� ��ࠬ��ࠬ, � ⠪�� �� �������,
                      � ����� ��뢠���� ��楤�� ����� �����
                      (����� ��� �������)
  - ��ᢥ���� ������: �� ����, �㤠 ��� 㪠�뢠�� 㪠��⥫�, �� ���஬�
                      ��襬, ⥯��� ����� 㪠�뢠�� �㤠, �㤠 ����� 㪠�뢠��
                      ��ன ��ࠬ���
  - ����뫪� ��᪠ �����: �� ����, �㤠 ��� 㪠�뢠�� ��ன ��ࠬ���,
                      ⥯��� ����� 㪠�뢠�� �㤠 㣮���
*)
    CASE p^.Op OF
    | ir.o_call:
        bv.Move (current.AnyRef, tmp);
        nparams := opProcs.NumParamsByProto (p^.Prototype);
        FOR i:=1 TO LEN (p^.Params^)-1 DO
            IF (i > nparams) OR NOT opProcs.ProcParamRO (p^.Prototype, i-1) THEN
                bv.Union (tmp, CanPointsTo (p^.Params^[i]), tmp);
            END;
        END;
        r := UNDEFINED;
        IF (p^.Params^[0].tag = ir.y_ProcConst) &
           opProcs.IsNested (VAL(opProcs.ProcNum,p^.Params^[0].name))
        THEN
            r := p^.Params^[0].name;
            FOR l:=0 TO ir.NLocals-1 DO
                IF opProcs.HasAccess (VAL(opProcs.ProcNum,r), l) THEN
                    bv.Incl (tmp, ORD(l))
                END;
            END;
        END;
        IF opAttrs.NOALIAS IN opAttrs.COMP_MODE THEN
            FOR l:=0 TO ir.NLocals-1 DO
                IF NOT IsScalar (l) & bv.In (tmp, ORD(l)) THEN
                    bv.Incl (current.AnyRef, ORD(l));
                END;
            END;
        ELSE
            bv.Move (tmp, current.AnyRef);
        END;
        FOR l:=0 TO ir.NLocals-1 DO
            IF (current.LocalsPointsTo^[l] <> NIL) &
               ((r <> UNDEFINED) OR bv.In (tmp, ORD(l)) OR ir.IsExternal (l))
            THEN
                bv.Move (current.AnyRef, current.LocalsPointsTo^[l]);
            END;
        END;
    | ir.o_storer:
        IF NOT (opAttrs.NOALIAS IN opAttrs.COMP_MODE) OR
           (p^.ResSize = opTune.addr_sz) & (p^.ResType = ir.t_ref)
        THEN
            vec := CanPointsTo (p^.Params^[0]);
            bv.Move (vec, tmp);
            vec := CanPointsTo (p^.Params^[1]);
            FOR l:=0 TO ir.NLocals-1 DO
                IF (current.LocalsPointsTo^[l] <> NIL) & bv.In (tmp,ORD(l)) THEN
                    bv.Union (current.LocalsPointsTo^[l], vec,
                                   current.LocalsPointsTo^[l]);
                END;
            END;
            bv.Union (current.AnyRef, vec, current.AnyRef);
        END;
    | ir.o_copy:
        vec := CanPointsTo (p^.Params^[1]);
        FOR l:=0 TO ir.NLocals-1 DO
            IF (current.LocalsPointsTo^[l] <> NIL) & bv.In (vec, ORD(l)) THEN
                bv.Move (current.AnyRef, current.LocalsPointsTo^[l]);
            END;
        END;
    ELSE
    END;
(*
  �᫨ १���� �ਠ�� - 㪠��⥫�, � ࠧ�������, �㤠 ��
                                     ��뭥 ����� 㪠�뢠��:
        - �ਥ� ��ࠬ���: ���� �� ����
        - ��ᢠ������:    �㤠 ��, �㤠 � ���࠭�
        - loadr,
          �맮�:           ����
        - ᫮�����:        ���� ��ࠬ��� - 㪠��⥫�: �㤠 ��, �㤠 � ��;
                           ����, �᫨ ���� ᫠������-��६�����, � ����;
                           ���� ���㤠
        - fi-�㭪��:      ����, �㤠 ����� 㪠�뢠�� ��ࠬ����
        - �ਥ� ��ࠬ���: �᫨ noptralias, � ����� dummy-��६����� ��
          p^.Prototype, ���������� �㤠 ࠭��
*)
    IF p^.ResType = ir.t_ref THEN
        CASE p^.Op OF
        | ir.o_assign,
          ir.o_cast,
          ir.o_val:
            vec := CanPointsTo (p^.Params^[0]);
        | ir.o_fi:
            bv.Fill (tmp, FALSE, ORD(ir.NLocals) + 1);
            vec := tmp;
            FOR i:=0 TO LEN (p^.Params^)-1 DO
                bv.Union (vec, CanPointsTo (p^.Params^[i]), vec);
            END;
        | ir.o_call,
          ir.o_loadr:
            vec := current.AnyRef;
        | ir.o_add:
            IF NOT (p^.Params^[0].reverse) &
               ((p^.Params^[0].tag = ir.y_RealVar) &
                (ir.Locals^[p^.Params^[0].name].VarType = ir.t_ref) OR
                (p^.Params^[0].tag = ir.y_AddrConst) OR
                (p^.Params^[0].tag = ir.y_Variable) &
                (ir.Vars^[p^.Params^[0].name].Def^.ResType = ir.t_ref))
            THEN
                vec := CanPointsTo (p^.Params^[0]);
            ELSE
                FOR i:=0 TO LEN(p^.Params^)-1 DO
                    IF p^.Params^[i].tag = ir.y_AddrConst THEN
                        bv.Incl (current.AnyRef, ORD(p^.Params^[i].name));
                    END;
                END;
                vec := current.AnyRef;
            END;
        | ir.o_getpar:
            IF opAttrs.NOALIAS IN opAttrs.COMP_MODE THEN
                bv.Fill (tmp, FALSE, ORD(ir.NLocals) + 1);
                bv.Incl (tmp, ORD(p^.Prototype));
                vec := tmp;
            ELSE
                vec := current.AnyRef;
            END;
        | ir.o_alloca:
            bv.Fill (tmp, FALSE, ORD(ir.NLocals) + 1);
            bv.Incl (tmp, ORD(p^.Prototype));
            vec := tmp;
        | ELSE
            vec := current.AnyRef;
        END;
        IF (p^.Tag = ir.y_Variable) & (VarsPointsTo^[p^.Name] <> NIL) THEN
            bv.Union (VarsPointsTo^[p^.Name], vec, VarsPointsTo^[p^.Name]);
        ELSIF (p^.Tag = ir.y_RealVar) &
              (current.LocalsPointsTo^[p^.Name] <> NIL)
        THEN
            bv.Move (vec, current.LocalsPointsTo^[p^.Name]);
        ELSE
            bv.Union (current.AnyRef, vec, current.AnyRef);
        END;
    ELSIF p^.Params <> NIL THEN
        CASE p^.Op OF
        | ir.o_call, ir.o_loadr, ir.o_copy, ir.o_storer:
        | ir.o_assign, ir.o_cast, ir.o_val:
            bv.Union (current.AnyRef, CanPointsTo (p^.Params^[0]),
                           current.AnyRef);
        ELSE
            FOR i:=0 TO LEN (p^.Params^)-1 DO
                IF p^.Params^[i].tag = ir.y_AddrConst THEN
                    bv.Incl (current.AnyRef, ORD(p^.Params^[i].name));
                END;
            END;
        END;
    END;
END InterpreteTriade;

(*----------------------------------------------------------------------------*)

(*
  ������� � ����� �� 㪠��⥫�, ����� ����� ������஢���
  ��뢠���� ��楤�� (���� ����� ����� ���ॡ������� ��᫥ ������)
*)

PROCEDURE InclAllExternals (vec: BitVector);
VAR l: Local;
BEGIN
    IF opAttrs.NOALIAS IN opAttrs.COMP_MODE THEN
        FOR l:=0 TO ir.NLocals-1 DO
            IF ir.IsExternal (l) THEN
                bv.Incl (vec, ORD(l));
            END;
        END;
    END;
END InclAllExternals;

(*----------------------------------------------------------------------------*)

(*
  ������� ����� read/write; �᫨ noaliases, �
  �모���� ��� �� ������� �� ⨯�/ࠧ����
*)

PROCEDURE CreateReadWrite (p: ParamPtr; tp: TypeType; sz: SizeType): BitVector;
VAR vec: BitVector;
    l:   Local;
BEGIN
    vec := bv.New (ORD(ir.NLocals)+1, FALSE);
    bv.Move (CanPointsTo (p), vec);
    IF (sz <> 0) & (opAttrs.NOALIAS IN opAttrs.COMP_MODE) THEN
        FOR l:=0 TO ir.NLocals-1 DO
            IF IsScalar (l) & ((VAL(SizeType,ir.Locals^[l].VarSize) <> sz) OR
                               (ir.Locals^[l].VarType <> tp))
            THEN
                bv.Excl (vec, ORD(l));
            END;
        END;
    END;
    RETURN vec;
END CreateReadWrite;

(*----------------------------------------------------------------------------*)

(*
  �� ��⮢��� ����� �모���� ���� ��� ����⠭�
*)

PROCEDURE ExclAllConstants (v: BitVector);
VAR l: Local;
BEGIN
    FOR l:=0 TO ir.NLocals-1 DO
        IF opProcs.LocalIsConstant (l) THEN
            bv.Excl (v, ORD(l));
        END;
    END;
END ExclAllConstants;

(*----------------------------------------------------------------------------*)

(*
  ����⢥��� ࠧ������ ����� Read � Write
*)

PROCEDURE PutReadWrite (p: TriadePtr);
VAR   i: INT;
      r: ir.VarNum;
      l: Local;
    vec: BitVector;
nparams: INT;
BEGIN
    CASE p^.Op OF
    | ir.o_call:
        vec := bv.New (ORD(ir.NLocals)+1, FALSE);
        bv.Move (current.AnyRef, vec);
        InclAllExternals (vec);
        nparams := opProcs.NumParamsByProto (p^.Prototype);
        FOR i:=1 TO LEN (p^.Params^)-1 DO
            IF (i > nparams) OR NOT opProcs.ProcParamRO (p^.Prototype, i-1) THEN
                bv.Union (vec, CanPointsToCl (p^.Params^[i]), vec);
            END;
        END;
        IF (p^.Params^[0].tag = ir.y_ProcConst) &
           opProcs.IsNested (VAL(opProcs.ProcNum, p^.Params^[0].name))
        THEN
            r := p^.Params^[0].name;
            FOR l:=0 TO ir.NLocals-1 DO
                IF opProcs.HasAccess (VAL(opProcs.ProcNum, r), l) THEN
                    bv.Incl (vec, ORD(l))
                END;
            END;
        END;
        p^.Write := vec;
        p^.Read  := bv.New (ORD(ir.NLocals)+1, FALSE);
        bv.Move (vec, p^.Read);
        FOR i:=1 TO LEN (p^.Params^)-1 DO
            bv.Union (p^.Read, CanPointsTo (p^.Params^[i]), p^.Read);
        END;
    | ir.o_loadr:
        p^.Read := CreateReadWrite (p^.Params^[0], p^.ResType, p^.ResSize);
    | ir.o_storer:
        p^.Write := CreateReadWrite (p^.Params^[0], p^.ResType, p^.ResSize);
    | ir.o_load:
        p^.Read := bv.New (ORD(ir.NLocals)+1, FALSE);
        bv.Incl (p^.Read, ORD(p^.Params^[0].name));
    | ir.o_store:
        p^.Write := bv.New (ORD(ir.NLocals)+1, FALSE);
        bv.Incl (p^.Write, ORD(p^.Name));
    | ir.o_copy:
        p^.Read  := CreateReadWrite (p^.Params^[0], ir.t_void, 0);
        p^.Write := CreateReadWrite (p^.Params^[1], ir.t_void, 0);
    | ir.o_in:
        IF p.ResType = ir.t_ref THEN
          p^.Read  := CreateReadWrite (p^.Params^[1], ir.t_void, 0);
        END;

    | ELSE IF (ir.OptionsSet{ ir.o_Dangerous, ir.o_Checked } * p^.Options <> ir.OptionsSet{}) OR
              (p^.Op = ir.o_ret)
         THEN
            p^.Read := bv.New (ORD(ir.NLocals) + 1, FALSE);
            bv.Move  (AnyRef, p^.Read);
            InclAllExternals (p^.Read);
         END;
    END;
    IF p^.Write <> NIL THEN
        ExclAllConstants (p^.Write);
    END;
END PutReadWrite;

(*----------------------------------------------------------------------------*)

(*
  �஢��� ������ 㪠��⥫�� - �� ������ �ਠ�� call, loadr � storer
                               ���ᮢ���, � ����� ������� ��� ����� ����.
*)

PROCEDURE AnalyzePointers;
VAR
    l: Local;
    v: VarNum;
    n: Node;
    t: ir.TSNode;
    p: TriadePtr;
BEGIN
    gr.TopSort;
    ir.Squeeze;
(*
  ������ dummy-�������, �� ����� ���� 㪠�뢠�� ��ࠬ���� (�᫨ NOPTRALIAS)
  � १���� alloca, � ᯠ�� �� � ���� Prototype ᮮ⢥�����饩 �ਠ��
  (�� ᠬ�� �ࠢ��쭮� ����, �� ����-� ����...)
*)
    p := ir.Nodes^[ir.ZERONode].First;
    REPEAT
        IF p^.ResType = ir.t_ref THEN
            CASE p^.Op OF
            | ir.o_getpar:
                IF opAttrs.NOALIAS IN opAttrs.COMP_MODE THEN
                    l := ir.AddLocal (NIL, ir.ZEROScope, 1);
                    ir.Locals^[l].VarType := ir.t_arr;
                    ir.Locals^[l].VarSize := 0;
                    p^.Prototype := VAL(ir.ProtoNum, l);
                END;
            | ir.o_alloca:
                l := ir.AddLocal (NIL, ir.TmpScope, 1);
                ir.Locals^[l].VarType := ir.t_arr;
                ir.Locals^[l].VarSize := 0;
                p^.Prototype := VAL(ir.ProtoNum, l);
            | ELSE
            END;
        END;
        p := p^.Next;
    UNTIL p = NIL;
(*
  ���樠����஢����� �����
*)

    AnyLocal := ir.NLocals;
    AllFalse := bv.New_Ex(AliasHeap, ORD(ir.NLocals)+1, FALSE);
    tmp2     := bv.New_Ex(AliasHeap, ORD(ir.NLocals)+1, FALSE);
    tmp      := bv.New_Ex(AliasHeap, ORD(ir.NLocals)+1, FALSE);
(*
  �� �� ����� 㪠�뢠�� 㪠��⥫� � ������ �室� � ��楤���
*)
    AnyRef   := bv.New_Ex (AliasHeap, ORD(ir.NLocals)+1, FALSE);
    FOR l:=0 TO ir.NLocals-1 DO
        IF ir.CanBePointed (l) &
           NOT (IsScalar (l) & (opAttrs.NOALIAS IN opAttrs.COMP_MODE)) &
           NOT opProcs.LocalIsConstant (l)
        THEN
            bv.Incl (AnyRef, ORD(l));
        END;
    END;
    bv.Incl (AnyRef, ORD(AnyLocal));
(*
  �뤥����� �����
*)
    IF ir.NVars <> 0 THEN
        lh.ALLOCATE(AliasHeap, VarsPointsTo, ir.NVars*SIZE(BitVector));
        FOR v:=0 TO ir.NVars-1 DO
            IF ir.Vars^[v].Def^.ResType = ir.t_ref THEN
                VarsPointsTo^[v] := bv.New_Ex (AliasHeap,
                                               ORD(ir.NLocals)+1, FALSE);
            ELSE
                VarsPointsTo^[v] := NIL;
            END;
        END;
    END;
    lh.ALLOCATE(AliasHeap, PointersArray, ir.Nnodes*SIZE(NodeRec));
     FOR t:=ir.StartOrder TO SYSTEM.PRED(LEN(ir.Order^)) DO
        InitNodeRec (PointersArray^[ir.Order^[t]]);
    END;
(*
  �⤥�쭮 �ந�����஢��� 0 ������� ���⮪
*)
    InitNodeRec (current);
    FOR l:=ir.ZEROVarNum TO SYSTEM.PRED(ir.NLocals) DO
        IF (current.LocalsPointsTo^[l] <> NIL) & ir.IsExternal (l) THEN
            bv.Move (AnyRef, current.LocalsPointsTo^[l]);
        END;
    END;
    ir.SetSilentMode;
    p := ir.Nodes^[ir.ZERONode].First;
    WHILE p <> NIL DO
        PutReadWrite     (p);
        InterpreteTriade (p);
        p := p^.Next;
    END;
    MoveNodeRec (current, PointersArray^[ir.ZERONode]);
(*
  ����⢥��� 横� ������� - ��������, ���� �� ᮩ�����
*)
    REPEAT
        Changed := FALSE;
        FOR t:=SYSTEM.SUCC(ir.StartOrder) TO SYSTEM.PRED(LEN(ir.Order^)) DO
            n := ir.Order^[t];
            Enter (n);
            p := ir.Nodes^[n].First;
            WHILE p <> NIL DO
                InterpreteTriade (p);
                p := p^.Next;
            END;
            UnionAssignNodeRec (current, PointersArray^[n]);
        END;
    UNTIL NOT Changed;
(*
  ������ ᮡ�⢥��� ࠧ����� �����
*)
    FOR t:=SYSTEM.SUCC(ir.StartOrder) TO SYSTEM.PRED(LEN(ir.Order^)) DO
        n := ir.Order^[t];
        Enter (n);
        p := ir.Nodes^[n].First;
        WHILE p <> NIL DO
            PutReadWrite     (p);
            InterpreteTriade (p);
            p := p^.Next;
        END;
    END;
(*
  ���, ��...
*)
    current.LocalsPointsTo := NIL;
    PointersArray          := NIL;
    VarsPointsTo           := NIL;
    AnyRef   := NIL;
    AllFalse := NIL;
    tmp  := NIL;
    tmp2 := NIL;
    lh.DEALLOCATE_ALL(AliasHeap);
END AnalyzePointers;

(*----------------------------------------------------------------------------*)

(*
  ������� �ਠ�� "l = load l"
*)

PROCEDURE MakeLoad (l: Local; pos-: TPOS): TriadePtr;
VAR p: TriadePtr;
BEGIN
    p := ir.NewTriadeTInit (1, ir.o_load, ir.y_RealVar, ir.Locals^[l].VarType,
                            VAL(SizeType, ir.Locals^[l].VarSize));
    p^.Name := l;
    ir.MakeParLocal(p.Params[0], l);
--    p^.Params^[0].tag  := ir.y_RealVar;
--    p^.Params^[0].name := l;
    p^.Read := bv.New (ORD(ir.NLocals)+1, FALSE);
    p^.Position := pos;
    bv.Incl (p^.Read, ORD(l));
    RETURN p;
END MakeLoad;

(*----------------------------------------------------------------------------*)

(*
  ������� �ਠ�� "store l = l"
*)

PROCEDURE MakeStore (l: Local): TriadePtr;
VAR p: TriadePtr;
BEGIN
    p := ir.NewTriadeTInit (1, ir.o_store, ir.y_RealVar, ir.Locals^[l].VarType,
                            VAL(SizeType, ir.Locals^[l].VarSize));
    p^.Name := l;
    ir.MakeParLocal(p.Params[0], l);
--    p^.Params^[0].tag  := ir.y_RealVar;
--    p^.Params^[0].name := l;
    p^.Write := bv.New (ORD(ir.NLocals)+1, FALSE);
    bv.Incl (p^.Write, ORD(l));
    RETURN p;
END MakeStore;

(*----------------------------------------------------------------------------*)

(*
  ����⠢��� �ਠ�� load ��᫥ ������ ����� �� 㪠��⥫� � ����� 㧫�
*)

PROCEDURE PutLoads (q: TriadePtr; v: BitVector);
VAR l: Local;
    i: INT;
BEGIN
    LOOP
        IF (q^.Params <> NIL) & (q^.Op <> ir.o_load) THEN
            FOR i:=0 TO LEN (q^.Params^)-1 DO
                IF (q^.Params^[i].tag = ir.y_RealVar) &
                   ((ir.o_Volatile IN ir.Locals^[q^.Params^[i].name].Options) OR
                    bv.In (v, ORD(q^.Params^[i].name)))
                THEN
                    l := q^.Params^[i].name;
                    bv.Excl (v, ORD(l));
                    gr.InsertTriade (MakeLoad (l, q^.Position), q);
                END;
            END;
        END;
        IF q^.Write <> NIL THEN
            FOR l:=ir.ZEROVarNum TO SYSTEM.PRED(ir.NLocals) DO
                IF IsScalar (l) &
                   (bv.In (q^.Write, ORD(l)) OR
                    ir.IsExternal (l) & (q^.Op = ir.o_call))
                THEN
                    bv.Incl (v, ORD(l));
                END;
            END;
        END;
        IF q^.Tag = ir.y_RealVar THEN
            bv.Excl (v, ORD(q^.Name));
        END;
        IF q^.Next = NIL THEN
            FOR l:=ir.ZEROVarNum TO SYSTEM.PRED(ir.NLocals) DO
                IF bv.In (v, ORD(l)) THEN
                    gr.InsertTriade (MakeLoad (l, q^.Position), q);
                END;
            END;
            RETURN;
        END;
        q := q^.Next;
    END;
END PutLoads;

(*----------------------------------------------------------------------------*)

(*
  �㦭� �� ����� ����������� ��६����� � ������ ��। �믮�������� �ਠ��?
*)

PROCEDURE MustSaveInMem (q: TriadePtr; l: Local; exceptions: BOOLEAN): BOOLEAN;
BEGIN
    RETURN (exceptions OR ir.IsExternal (l)) &
           ((ir.OptionsSet{ ir.o_Checked, ir.o_Dangerous } * q^.Options <> ir.OptionsSet{}) OR
            (q^.Op = ir.o_call) OR (q^.Op = ir.o_ret) OR
            (q^.Op = ir.o_checklo) OR (q^.Op = ir.o_checkhi) OR
            (q^.Op = ir.o_checknil) OR (q^.Op = ir.o_stop) OR
            (q^.Op = ir.o_error));
END MustSaveInMem;

(*----------------------------------------------------------------------------*)

(*
  ����⠢��� �ਠ�� store ��। �⥭���/������� �� 㪠��⥫� � ����� 㧫�,
  �����६���� ��������� tmp2 - ������⢮ ����������, �� ��
                               ��襭��� � ������ ��६�����.
*)

PROCEDURE PutStores (q: TriadePtr; exceptions: BOOLEAN);
VAR l: Local;
BEGIN
    WHILE q <> NIL DO
        IF (q^.Read <> NIL) & (q^.Op <> ir.o_load) THEN
            FOR l:=ir.ZEROVarNum TO SYSTEM.PRED(ir.NLocals) DO
                IF bv.In (tmp2, ORD(l)) & IsScalar (l) &
                   (bv.In (q^.Read, ORD(l)) OR MustSaveInMem (q, l, exceptions))
                THEN
                    Changed := TRUE;
                    gr.InsertTriade (MakeStore (l), q);
                    bv.Excl    (tmp2, ORD(l));
                END;
            END;
        END;
        IF q^.Write <> NIL THEN
            IF q^.Op = ir.o_store THEN
                bv.Excl (tmp2, ORD(q^.Name));
            ELSE
                FOR l:=ir.ZEROVarNum TO SYSTEM.PRED(ir.NLocals) DO
                    IF bv.In (tmp2, ORD(l)) & IsScalar (l) &
                       bv.In (q^.Write, ORD(l))
                    THEN
                        IF (CalcOnes (q^.Write) <> 1) OR
                          (ORD(q^.ResSize) # ir.Locals[l].VarSize)  -- we change only a part of variable
                        THEN
                            Changed := TRUE;
                            gr.InsertTriade (MakeStore (l), q);
                        END;
                        bv.Excl (tmp2, ORD(l));
                    END;
                END;
            END;
        END;
        IF q^.Tag = ir.y_RealVar THEN
            l := q^.Name;
            IF (q^.Op = ir.o_load) OR (q^.Op = ir.o_store) THEN
                bv.Excl (tmp2, ORD(l));
            ELSIF (ir.o_Volatile IN ir.Locals^[l].Options) & (q^.Next <> NIL) &
                  ((q^.Next^.Op <> ir.o_store) OR (q^.Next^.Name <> l))
            THEN
                gr.PutAfterTriade (MakeStore (l), q);
                bv.Excl (tmp2, ORD(l));
                q := q^.Next;
(*
            ELSIF ir.IsExternal (l) & (q^.Next <> NIL) &
                  ((q^.Next^.Op   <> ir.o_store)    OR
--                 (q^.Next^.Tag  <> ir.y_Varuable) OR
                   (q^.Next^.Name <> l))
            THEN
                ir.PutAfterTriade (MakeStore (l), q);
                bv.Excl (tmp2, l);
                q := q^.Next;
*)
            ELSE
                bv.Incl (tmp2, ORD(l));
            END;
        END;
        q := q^.Next;
    END;
END PutStores;

(*----------------------------------------------------------------------------*)

VAR LoadStoreHeap : lh.heapID;
(*
  ����⠢��� � �ணࠬ�� �ਠ�� load � store
*)

PROCEDURE MakeLoadsStores (exceptions: BOOLEAN);
VAR q, w:     TriadePtr;
    n:        Node;
    l:        Local;
     j:       INT;
     i:       ir.TSNode;
    Modified: BitVectArrayNode;
BEGIN
    gr.TopSort;
    ir.SetSilentMode;
(*
  ��⠢��� � �ணࠬ�� load-� � 0 㧫�
*)
    tmp2 := bv.New_Ex (LoadStoreHeap, ORD(ir.NLocals), FALSE);
    FOR l:=ir.ZEROVarNum TO SYSTEM.PRED(ir.NLocals) DO
        IF IsScalar (l) & (ir.IsExternal (l) OR (opAttrs.nooptimize IN opAttrs.COMP_MODE)) THEN
            bv.Incl (tmp2, ORD(l));
        END;
    END;
    PutLoads (ir.Nodes^[ir.ZERONode].First, tmp2);
(*
  ������ �� ���� ���⠢��� � ��砫� EXCEPT-�����
*)
    IF exceptions & (ir.Nodes^[ir.ZERONode].NOut = 2) THEN
        q := ir.Nodes^[ir.Nodes^[ir.ZERONode].Out^[0]].First;
        FOR l:=ir.ZEROVarNum TO SYSTEM.PRED(ir.NLocals) DO
            IF IsScalar (l) THEN
                w := MakeLoad (l, q^.Position);
                INCL (w^.Options, ir.o_Volatile);
                gr.InsertTriade (w, q);
            END;
        END;
    END;
(*
  ������ �� ���� ���⠢��� ��᫥ ������ ����� �� 㪠��⥫�
*)
    FOR i:=SYSTEM.SUCC(ir.StartOrder) TO SYSTEM.PRED(LEN(ir.Order^)) DO
        bv.Fill (tmp2, FALSE, ORD(ir.NLocals));
        PutLoads (ir.Nodes^[ir.Order^[i]].First, tmp2);
    END;
(*
  ������ ���⠢�� store; ᭠砫� �⤥�쭮 ��ࠡ�⠥� 0 㧥�
*)
    bv.Fill (tmp2, FALSE, ORD(ir.NLocals));
    q := ir.Nodes^[ir.ZERONode].First;
    WHILE q^.Op = ir.o_getpar DO
<* IF TARGET_RISC OR TARGET_SPARC THEN *>
        IF (q^.Tag = ir.y_RealVar) &
           opProcs.IsParInReg(opProcs.ProcProtoNum(opAttrs.curr_procno),q^.NPar)
        THEN
           bv.Incl(tmp2,ORD(q^.Name));
        END;
<* END *>
        q := q^.Next;
    END;
    PutStores (q, exceptions);
(*
  � ⥯��� ����� ����� ������: ��६���� ���������� ��� ���?
*)
    lh.ALLOCATE( LoadStoreHeap, Modified, ir.Nnodes*SIZE(BitVector));
    FOR i:=ir.StartOrder TO SYSTEM.PRED(LEN(ir.Order^)) DO
        Modified^[ir.Order^[i]] := bv.New_Ex (LoadStoreHeap, ORD(ir.NLocals), FALSE);
    END;
    bv.Move (tmp2, Modified^[ir.ZERONode]);
    REPEAT
        Changed := FALSE;
        FOR i:=SYSTEM.SUCC(ir.StartOrder) TO SYSTEM.PRED(LEN(ir.Order^)) DO
            n := ir.Order^[i];
            bv.Move (Modified^[ir.Nodes^[n].In^[0]], tmp2);
            FOR j:=1 TO ir.Nodes^[n].NIn-1 DO
                bv.Union (tmp2, Modified^[ir.Nodes^[n].In^[j]], tmp2);
            END;
            PutStores (ir.Nodes^[n].First, exceptions);
            IF NOT bv.Eq (tmp2, Modified^[n]) THEN
                Changed := TRUE;
                bv.Move (tmp2, Modified^[n]);
            END;
        END;
    UNTIL NOT Changed;
(*
    �����訫�
*)
    FOR i:=ir.StartOrder TO SYSTEM.PRED(LEN(ir.Order^)) DO
        bv.Free_Ex (LoadStoreHeap, Modified^[ir.Order^[i]]);
    END;
    bv.Free_Ex (LoadStoreHeap, tmp2);
    ir.SetNormalMode;
    lh.DEALLOCATE_ALL(LoadStoreHeap);
END MakeLoadsStores;

(*----------------------------------------------------------------------------*)

(*
  � 㧫� n ᮧ���� fi-�㭪�� ��� ��६����� l
*)

PROCEDURE MakeFi (n: ir.Node; l: Local);
VAR p: TriadePtr;
    i: INT;
BEGIN
    p := ir.NewTriadeTInit (ir.Nodes^[n].NIn, ir.o_fi, ir.y_RealVar,
                            ir.Locals^[l].VarType,
                            VAL(SizeType, ir.Locals^[l].VarSize));
    p^.Name := l;
    FOR i:=0 TO ir.Nodes^[n].NIn-1 DO
        ir.MakeParLocal(p.Params[i], l);
--        p^.Params^[i].tag  := ir.y_RealVar;
--        p^.Params^[i].name := l;
    END;
    gr.PutTriadeFirst (p, n);
    IF (at.VolatilePlus IN at.COMP_MODE) AND
       (ir.o_Volatile IN ir.Locals^[l].Options)
    THEN
      gr.PutAfterTriade (MakeStore (l), p);
    END;
END MakeFi;

(*----------------------------------------------------------------------------*)

(*
  ��������� fi-�㭪樨
*)

VAR
  PlaceFiHeap: lh.heapID;

PROCEDURE PlaceFi;
VAR i, o: INT;
    n, m: Node;
       p: TriadePtr;
       l: Local;
       t: ir.TSNode;
       W: POINTER ["Modula"] TO ARRAY NodeRange OF NodeArray;

BEGIN
    gr.FindDF;
(*
  ������� ࠡ�稥 �⥪�/���ᨢ�
*)
    lh.ALLOCATE(PlaceFiHeap, W,     ir.NLocals * SIZE(NodeArray));
    lh.ALLOCATE(PlaceFiHeap, Count, ir.NLocals * SIZE(INTEGER));

    FOR l:=ir.ZEROVarNum TO SYSTEM.PRED(ir.NLocals) DO
        lh.ALLOCATE( PlaceFiHeap, W^[l], ir.Nnodes * SIZE(ir.Node) );
        Count^[l] := 0;
    END;
    lh.ALLOCATE (PlaceFiHeap, HasAlready, ir.NLocals * SIZE (BitVector));
    lh.ALLOCATE (PlaceFiHeap, Work,       ir.NLocals * SIZE (BitVector));
    FOR l:=ir.ZEROVarNum TO SYSTEM.PRED(ir.NLocals) DO
        HasAlready^[l] := bv.New_Ex (PlaceFiHeap, ir.Nnodes, FALSE);
        Work^[l]       := bv.New_Ex (PlaceFiHeap, ir.Nnodes, FALSE);
    END;
(*
  ��ࠡ���� �� ����砫�� ��ᢠ������
*)
    FOR t:=ir.StartOrder TO SYSTEM.PRED(LEN(ir.Order^)) DO
        n := ir.Order^[t];
        p := ir.Nodes^[n].First;
        WHILE p <> NIL DO
            IF p^.Tag = ir.y_RealVar THEN
                l := p^.Name;
                IF NOT bv.In (Work^[l], ORD(n)) THEN
                    bv.Incl (Work^[l], ORD(n));
                    W^[l]^[Count^[l]] := n;
                    INC (Count^[l]);
                END;
            END;
            p := p^.Next;
        END;
    END;
(*
  � ⥯��� ᮡ�⢥��� ���⠢��� fi-�㭪樨
*)
    FOR l:=SYSTEM.PRED(ir.NLocals) TO ir.ZEROVarNum BY -1 DO
        o := Count^[l];
        WHILE o <> 0 DO
            DEC (o);
            n := W^[l]^[o];
            FOR i:=0 TO gr.dfLen^[n]-1 DO
                m := gr.dfArray^[n]^[i];
                IF NOT bv.In (HasAlready^[l], ORD(m)) THEN
                    bv.Incl (HasAlready^[l], ORD(m));
                    MakeFi (m, l);
                    IF NOT bv.In (Work^[l], ORD(m)) THEN
                        bv.Incl (Work^[l], ORD(m));
                        W^[l]^[o] := m;
                        INC (o);
                    END;
                END;
            END;
        END;
    END;
(*
  �᢮������ ������
*)
    lh.DEALLOCATE_ALL(PlaceFiHeap);
    HasAlready := NIL;
    Work := NIL;
END PlaceFi;

(*----------------------------------------------------------------------------*)

VAR ReplaceHeap: lh.heapID;

PROCEDURE NewSPtr (n: INT): SPtr;
VAR p: SPtr;
BEGIN
    lh.ALLOCATE (ReplaceHeap, p, SIZE (INT) + n * SIZE (VarNum));
    p^.len := n;
    RETURN p;
END NewSPtr;

PROCEDURE FreeSPtr (p: SPtr);
BEGIN
    lh.DEALLOCATE (ReplaceHeap, p, SIZE (INT) + p^.len * SIZE (VarNum));
END FreeSPtr;

(*
  �������� RealVars �� Variables � ����� ��ࠬ���
*)

PROCEDURE RepParameter (p: ParamPtr);
BEGIN
    IF p^.tag = ir.y_RealVar THEN
        IF Count^[p^.name] = 0 THEN
            ir.MakeParNothing(p);
        ELSE
            ir.MakeParVar_Ex(p, S^[p^.name]^.v [Count^[p^.name]-1],
                             TRUE, p.reverse);
        END;
    END;
END RepParameter;

(*----------------------------------------------------------------------------*)

(*
  �������� RealVars �� Variables - ��ࠡ�⪠ ������ 㧫�
*)

PROCEDURE SEARCH (n: Node);
VAR    p: TriadePtr;
       l: Local;
       m: Node;
    i, j: INT;
       s: SPtr;
BEGIN
(*
  ���� �� �ᥬ �ਠ��� � �⮬ �������� ���⪥ - �������� १����� �
                                                 � �� fi-�㭪権 ��ࠬ����
*)
    p := ir.Nodes^[n].First;
    WHILE p <> NIL DO
        EXCL (p^.Options, ir.o_Processed);
        IF (p^.Op <> ir.o_fi) & (p^.Op <> ir.o_load) & (p^.Params <> NIL) THEN
            FOR i:=0 TO LEN(p^.Params^)-1 DO
                RepParameter (p^.Params^[i]);
            END;
        END;
        IF (p^.Tag = ir.y_RealVar) & (p^.Op <> ir.o_store) THEN
            INCL (p^.Options, ir.o_Processed);
            l := p^.Name;
            p^.Tag := ir.y_Variable;
            ir.GenVar (l, p^.Name, p);
            IF Count^[l] = S^[l]^.len THEN
                s := NewSPtr (S^[l]^.len * 2);
                FOR i:=0 TO S^[l]^.len-1 DO
                    s^.v [i] := S^[l]^.v [i];
                END;
                FreeSPtr (S^[l]);
                S^[l] := s;
            END;
            S^[l]^.v [Count^[l]] := p^.Name;
            INC (Count^[l]);
        END;
        p := p^.Next;
    END;
(*
  ������ �������� ᮮ⢥�����騥 ��ࠬ���� � fi-�㭪権 � �॥������ �⮣� 㧫�
*)
    FOR i:=0 TO ir.Nodes^[n].NOut-1 DO
        m := ir.Nodes^[n].Out^[i];
        j := gr.FindInArc (ir.Nodes^[n].OutArcs^[i]);
        p := ir.Nodes^[m].First;
        WHILE p^.Op = ir.o_fi DO
            RepParameter (p^.Params^[j]);
            p := p^.Next;
        END;
    END;
(*
  ������ ��ࠡ���� �� 㧫�, ��� ����묨 n �����।�⢥��� ���������
*)
    m := ir.Nodes^[n].DomChild;
    WHILE m <> UndefNode DO
        SEARCH (m);
        m := ir.Nodes^[m].DomLink;
    END;
(*
    ����� � �⥪�� ����� ᮧ����� ��६����
*)
    p := ir.Nodes^[n].First;
    WHILE p <> NIL DO
        IF ir.o_Processed IN p^.Options THEN
            DEC (Count^[ir.Vars^[p^.Name].LocalNo]);
        END;
        p := p^.Next;
    END;
END SEARCH;

(*----------------------------------------------------------------------------*)

(*
  ������ RealVars �� Variables
*)

PROCEDURE ReplaceRealVars;
VAR l: Local;
BEGIN
    lh.ALLOCATE(ReplaceHeap, S,     ir.NLocals * SIZE(SPtr));
    lh.ALLOCATE(ReplaceHeap, Count, ir.NLocals * SIZE(INTEGER));
    FOR l:=ir.ZEROVarNum TO SYSTEM.PRED(ir.NLocals) DO
        S^[l] := NewSPtr (6);
        Count^[l] := 0;
    END;
    SEARCH (ir.ZERONode);
    lh.DEALLOCATE_ALL(ReplaceHeap);
END ReplaceRealVars;

(*----------------------------------------------------------------------------*)

(*
  �������� ���� � �ணࠬ��
    a = * & b
  ��
    a = b,
  �
    * & a = b
  ��
    a = b.
*)

PROCEDURE ReplaceLoadsStores;
VAR i: ir.TSNode;
    n: Node;
    p: TriadePtr;
    r: ParamArray;
BEGIN
    FOR i:=ir.StartOrder TO LEN(ir.Order^)-1 DO
        n := ir.Order^[i];
        p := ir.Nodes^[n].First;
        REPEAT
            IF p^.Op = ir.o_loadr THEN
                IF (p^.Params^[0].tag = ir.y_AddrConst) &
                   (p^.Params^[0].offset = 0) & IsScalar (p^.Params^[0].name) &
                   (ORD(p^.ResSize) = ir.Locals^[p^.Params^[0].name].VarSize)
                THEN
                    p^.Op := ir.o_assign;
                    ir.MakeParLocal(p.Params[0], p.Params[0].name);
--                    p^.Params^[0].tag := ir.y_RealVar;
                END;
            ELSIF p^.Op = ir.o_storer THEN
                IF (p^.Params^[0].tag = ir.y_AddrConst) &
                   (p^.Params^[0].offset = 0) & IsScalar (p^.Params^[0].name) &
                   (ORD(p^.ResSize) = ir.Locals^[p^.Params^[0].name].VarSize)
                THEN
                    p^.Op   := ir.o_assign;
                    p^.Tag  := ir.y_RealVar;
                    p^.Name := p^.Params^[0].name;
                    r := ir.NewParams (1, p);
                    ir.CopyParam (p^.Params^[1], r^[0]);
                    IF p^.Params^[1].tag = ir.y_Variable THEN
                        ir.RemoveUse(p^.Params^[1]);
                    END;
                    p^.Params := r;
                END;
            END;
            p := p^.Next;
        UNTIL p = NIL;
    END;
END ReplaceLoadsStores;

(*----------------------------------------------------------------------------*)

(*
  ��ॢ��� �ணࠬ�� � SSA-���
*)

PROCEDURE ConvertToSSA* (exceptions: BOOLEAN);
BEGIN
    ReplaceLoadsStores;
<* IF gen_qfile THEN *>
    TestIO.WriteTest ("R", "after ReplaceLoadsStores (R)");
<* END *>
    AnalyzePointers;
    IF ir.NLocals > ir.ZEROVarNum THEN
        MakeLoadsStores (exceptions);
<* IF gen_qfile THEN *>
        TestIO.WriteTest ("M", "after MakeLoadsStores (M)");
<* END *>
        PlaceFi;
<* IF gen_qfile THEN *>
        TestIO.WriteTest ("P", "after PlaceFi (P)");
<* END *>
        ReplaceRealVars;
<* IF gen_qfile THEN *>
        TestIO.WriteTest ("V", "after ReplaceRealVars (V)");
<* END *>
    END;
END ConvertToSSA;

(*----------------------------------------------------------------------------*)

BEGIN
    lh.Create( AliasHeap );
    lh.Create( LoadStoreHeap );
    lh.Create( PlaceFiHeap );
    lh.Create( ReplaceHeap );
END ssa.
