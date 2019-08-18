<* IF NOT(TARGET_386) THEN *>
This module can be used only in TARGET_386
<* END *>
MODULE RDefs_D;
IMPORT Emit;
IMPORT D := desc386;
IMPORT CodeDef;
IMPORT ir;

CONST
    UNDEF_REG   *= D.UNDEF_REG;
    SPILLED_REG *= D.ESP;

TYPE
    Reg       *= D.Reg;
    Contents  *= ARRAY Reg OF ir.VarNum;
    NODEPTR_TYPE *= POINTER TO TREE;
    TREE         *= RECORD
                        place*:             Emit.RegPlacement;
                        a*:                 Emit.AddrMode;
                    END;

    NodeInfoType*= RECORD
                     o*:  LONGINT;  -- ᬥ饭�� �⭮�⥫쭮
                                   -- ��砫� ��楤���
                     sg*: CodeDef.CODE_SEGM;
                     ultimateRegContents*:  Contents; -- ����ﭨ� ॣ���஢ �
                                    -- ���� 㧫��
                     ultimateDirtyRegs*:  D.RegSet; -- ����ﭨ� ॣ���஢ �
                     c*:  Contents; -- ����ﭨ� ॣ���஢ �
                                    -- ���� 㧫��
                     j*: D.Condition; -- �᫮��� ���室�
                     j2*: BOOLEAN;  -- ���� �� ����᫮���
                                   -- ���室 ��᫥ �᫮�����
                     l1*,
                     l2*: BOOLEAN;  -- ������ �� ���室�?
                     a*:  SHORTINT; -- �� ����� ��室��� ���
                                   -- (0 ��� 1) ����� ����
                                   -- ���室 � 㧫�
                     l*:  ir.INT;      -- 0..3 - ᪮�쪮 ���⮢
                                   -- ����ᠫ� ���
                                   -- ��ࠢ�������
                     lb*: Emit.LABEL;
                     ca*: Emit.LABEL;
                   END;

END RDefs_D.
