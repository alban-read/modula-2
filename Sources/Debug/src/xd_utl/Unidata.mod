
<* STORAGE+ *>
<*M2EXTENSIONS+*>
IMPLEMENTATION MODULE Unidata;


IMPORT sys:= SYSTEM;
FROM Printf IMPORT printf;

TYPE
<* PUSH *>
<* ALIGNMENT = "1" *>


  PBYTE     =  POINTER TO ARRAY OF sys.CARD8;
  PHashTbl  =  POINTER TO ARRAY OF CARDINAL;
  PHASHTBLS =  POINTER TO ARRAY OF PHashTbl;

  HASHSTRUCT = RECORD
               Tables : PHASHTBLS;
               Hash   : HASH;
             END;

  STORAGE   = POINTER TO RECORD
                           HashStruct: HASHSTRUCT;
                           slots     : ARRAY[0..N_SLOTS-1] OF PBYTE;
                           Slot_size : CARDINAL;
                           curr_slot : CARDINAL;
                           used      : CARDINAL;   (* ���� ᢮����� ��� ����� *)
                         END;

<*POP *>


PROCEDURE PrintHashTbl( storage:STORAGE);
VAR i,j: CARDINAL;
BEGIN

 ASSERT(storage # NIL);
  WITH storage^.HashStruct DO
    IF Tables # NIL THEN
     FOR i:= 0 TO  HIGH(Tables^) DO
       printf('HashTbl[%d]  : \n', i+1);
       IF Tables^[i] # NIL THEN
         FOR j:= 0 TO HIGH(Tables^[i]^) DO
           printf(' Hash[%d] :  %d\n', j, Tables^[i]^[j]);
         END;
       END;
     END;
    END;
  END;
END PrintHashTbl;

PROCEDURE PrintStorageInfo(storage:STORAGE);
VAR size,i: CARDINAL;
BEGIN
  WITH storage^ DO
    WITH HashStruct DO
      size := 0;
      IF Tables # NIL THEN
        size := SIZE(Tables^);
        FOR i:= 0 TO HIGH(Tables^) DO
          IF Tables^[i] # NIL THEN
            size := size + SIZE(Tables^[i]^);
          END;
        END;
      END;
    END;
    printf(' Slot_size : %d\n', Slot_size);
    printf(' Number of slots used : %d\n', curr_slot + 1);
    printf(' used :%d\n', used);
    printf(' All memory used : %d\n',(curr_slot + 1)*Slot_size);
    printf(' The size of the hash table : %d\n', size);
  END;
END PrintStorageInfo;



CONST
  Slot_Marker_Final    = MAX(CARDINAL)-1; -- ��થ� ���� ᫮�
  Slot_Marker_Next_Ref = MAX(CARDINAL)-2; -- ��થ� ���� ᫮�: � ᫥���饬 � ��砫� ��뫪�


PROCEDURE IsRefValid(storage:STORAGE; ref: IMAGE_REF): BOOLEAN;
VAR slot, pos : CARDINAL;
BEGIN
  IF ref = Invalid_Ref THEN
    RETURN FALSE;
  ELSE
    slot:= ref DIV 1000000H;
    pos := ref MOD 1000000H;
    WITH storage^ DO
      RETURN (slot < curr_slot) OR ((slot = curr_slot)AND(pos < used));
    END;
  END;
END IsRefValid;


PROCEDURE CreateStorage(VAR storage: STORAGE; SLOT_SIZE : CARDINAL; Sizes-: ARRAY OF CARDINAL; hash : HASH);
VAR i,count: CARDINAL;
BEGIN
  NEW(storage);
  WITH storage^.HashStruct DO
    count := HIGH(Sizes) + 1;
    NEW(Tables, count);
    FOR i:= 0 TO count-1 DO
      IF Sizes[i] = 0 THEN
        Tables^[i] := NIL;
      ELSE
        NEW(Tables^[i], Sizes[i]);
        sys.FILL(sys.ADR(Tables^[i]^), 0, SIZE(Tables^[i]^));
      END;
    END;
    Hash:=  hash;
  END;
  sys.FILL(sys.ADR(storage^.slots), 0, SIZE(storage^.slots));
  storage^.curr_slot:= 0;
  NEW(storage^.slots[storage^.curr_slot], SLOT_SIZE);
  storage^.slots[0]^[0]:= ORD(0C);   -- �⮡� �᪫���� ��뫪� = NIL
  storage^.used:= 1;
  storage^.Slot_size:= SLOT_SIZE;
END CreateStorage;


PROCEDURE DestroyStorage(VAR storage: STORAGE);
BEGIN
 ASSERT(storage # NIL);
END DestroyStorage;

PROCEDURE ClearData(storage: STORAGE);
VAR i,count: CARDINAL;
BEGIN
  WITH storage^ DO
    curr_slot:= 0;
    used:= 1;
    WITH HashStruct DO
      count := HIGH(Tables^) + 1;
      FOR i:= 0 TO count-1 DO
        IF Tables^[i] # NIL THEN
          sys.FILL(sys.ADR(Tables^[i]^), 0, SIZE(Tables^[i]^));
        END;
      END;
    END;
  END;
END ClearData;


PROCEDURE Get(storage: STORAGE; image_ref: IMAGE_REF): IMAGE;
VAR slot, pos : CARDINAL;
BEGIN
  IF image_ref = 0 THEN
    RETURN  sys.ADR(storage^.slots[0]^[0]);
  END;
  slot:= image_ref DIV 1000000H ;
  pos:= image_ref MOD 1000000H;
  ASSERT(IsRefValid(storage, image_ref));
  RETURN sys.ADR(storage^.slots[slot]^[pos]);
END Get;




PROCEDURE Next(storage: STORAGE; ref: IMAGE_REF; Length: LENGTH_IMAGE): IMAGE_REF;
VAR slot, pos, len : CARDINAL;
    image : IMAGE;
    r_image:  IMAGE_REF;
    p_image: POINTER TO IMAGE_REF;
BEGIN
  IF  ref = 0 THEN
    RETURN 1;
  END;
  slot := ref DIV 1000000H;
  pos  := ref MOD 1000000H;
  image:= Get(storage,ref);
  len  := Length(image);
  pos  := pos + len +1;
  WITH storage^ DO
    IF slots[slot]^[pos] = ORD(0C) THEN
      p_image := sys.ADR (slots[slot]^[pos+1]);
      IF IsRefValid (storage, p_image^) THEN
        -- ��। ᫥���騬 ������   ��室���� ��뫪�
        INC(pos, 1+SIZE(IMAGE_REF));
      ELSE
        -- ��몠-��થ� �����蠥� ��᫥���� ��� � �⮬ ᫮�
        INC (slot);
        IF p_image^ = Slot_Marker_Final THEN
          pos := 0;
        ELSE
          pos := 1+SIZE(IMAGE_REF);
        END;
      END;
    END;
    r_image:= slot* 1000000H + pos;
    IF IsRefValid(storage, r_image) THEN
      RETURN r_image;
    ELSE
      RETURN MAX(CARDINAL);
    END;
  END;
END Next;


PROCEDURE Add(VAR storage: STORAGE; image: IMAGE;  IsEqual: COMPARE_IMAGE; Length : LENGTH_IMAGE; VAR unique : BOOLEAN ):  IMAGE_REF;

VAR
  p_image: POINTER TO IMAGE_REF;
  k   : CARDINAL;
  len,len2 : CARDINAL;
  ind : HASH_RESULT;
  r_image: IMAGE_REF;
  slot,pos  : CARDINAL;
BEGIN
  len := Length(image);
  ASSERT(storage # NIL);
  IF len = 0 THEN
    unique:= FALSE;
    RETURN 0;
  END;
  ASSERT(len < storage^.Slot_size);
  IF NOT unique THEN
     WITH storage^ DO
        ind:= HashStruct.Hash(image);
        r_image:= HashStruct.Tables^[ind.number]^[ind.index];
     END;
     WHILE r_image # 0 DO
       slot := r_image DIV 1000000H;
       pos := r_image MOD 1000000H;
       -- ���� 㦥 image � ⠪�� �襬
       ASSERT(slot <=  HIGH(storage^.slots));
       ASSERT(storage^.slots[slot] # NIL);
       ASSERT(pos < HIGH(storage^.slots[slot]^));   -- �� <= �.�. �� 0C
       len2 := Length(sys.ADR(storage^.slots[slot]^[pos]));
       IF (len = len2) AND (IsEqual(sys.ADR(storage^.slots[slot]^[pos]), image,len))  THEN
         RETURN r_image;
       END;
       IF (pos < 1+SIZE(IMAGE_REF))                  -- � ��砫� �� ����� ���� ��뫪�
         OR (storage^.slots[slot]^[pos-1] = ORD(0C)) -- �� �।��騬 ������ ��室���� 0�
       THEN
         r_image := 0;
       ELSE
         p_image:= sys.ADR(storage^.slots[slot]^[pos-SIZE(IMAGE_REF)]);
         r_image:= p_image^;
         ASSERT (r_image # 0);
       END;
     END;
  END;
  WITH storage^ DO
    p_image := NIL;
    IF used + (1+SIZE(IMAGE_REF)) + (len+1) + (1+SIZE(IMAGE_REF)) >= HIGH(slots[curr_slot]^)  THEN
      slots[curr_slot]^[used]:= ORD(0C); --��। ��뫪�� �㤥� �� ���� 0� ��� �ਧ��� ��뫪�
      INC(used);
      p_image:= sys.ADR(slots[curr_slot]^[used]); -- ��࠭�� ������ ��થ� ᫮�
      p_image^ := Slot_Marker_Final;
      -- � ⥯��� ���室�� � ��।���� ᫮��
      INC(curr_slot);
      IF slots[curr_slot] = NIL THEN -- ࠭�� ��� ᫮� �� �ᯮ�짮����?
        NEW(slots[curr_slot], Slot_size);
      END;
      used:= 0;
    END;
    IF NOT unique THEN
       IF HashStruct.Tables^[ind.number]^[ind.index] # 0 THEN
         IF p_image # NIL THEN
           -- �.�. �� ���室 �� ��।��� ᫮�: ��થ� �㦭� ��������
           p_image^ := Slot_Marker_Next_Ref;
         END;
         r_image:= HashStruct.Tables^[ind.number]^[ind.index];
         slots[curr_slot]^[used]:= ORD(0C); --��। ��뫪�� �㤥� �� ���� 0� ��� �ਧ��� ��뫪�
         INC(used);
         sys.MOVE(sys.ADR(r_image), sys.ADR(slots[curr_slot]^[used]), SIZE(IMAGE_REF));
         INC (used, SIZE(IMAGE_REF));
       END;
    END;
    sys.MOVE(image, sys.ADR(slots[curr_slot]^[used]), len);
    k := used;
    INC(used, len);
    slots[curr_slot]^[used]:= ORD(0C);
    INC(used);
    r_image := curr_slot*1000000H + k;
    IF NOT unique THEN
      unique := TRUE;
      HashStruct.Tables^[ind.number]^[ind.index] := r_image;
    END;
    RETURN r_image;
  END;
END Add;

PROCEDURE IsEmptyStorage( storage:STORAGE) : BOOLEAN;
BEGIN
  ASSERT(storage # NIL);
  RETURN  (storage^.used = 1 ) AND (storage^.curr_slot = 0);
END IsEmptyStorage;


PROCEDURE First(storage:STORAGE ): IMAGE_REF;
BEGIN
  ASSERT(storage # NIL);
  RETURN (*curr_slot=*)0*1000000H + (*used=*)1;
END First;

BEGIN
END Unidata.