; COPYRIGHT (c) 1995,97,99,2002 XDS. All Rights Reserved.

                cpu 386
      bits 32

%ifdef OS2
group    DGROUP   _DATA
      section _DATA  use32  align=4  FLAT  public 'DATA'
%else
group    DGROUP   _DATA
      section _DATA  use32  align=4  public 'DATA'
%endif

%ifdef OS2
      section .text  use32  public  align=4  FLAT  public 'CODE'
%else
      section .text  use32  public  align=16  public 'CODE'
%endif

                global  X2C_IS_CALL

X2C_IS_CALL:

; ASSUME : it's guaranteed that the address passed is always in the code segment
;          and is GREATER than the beginning of codeseg + 6
;          ( checking before a call to this proc )

                mov     eax, [esp+4]

; ���砫� �஢��塞 �� call reg � call [reg]
;
; don't test (eax-i) if i>7 ( see X2C_IS_CODESEG - VitVit )
;
check:          dec     eax
                dec     eax
                cmp     byte [cs:eax], 0FFh
                jne     not0
                mov     cl, byte [cs:eax+1]
                cmp     cl, 14h                 ; �� �뢠�� [esp]
                je      not0
                cmp     cl, 15h                 ; � [ebp]
                je      not0
                cmp     cl,0D4h                 ; � esp
                je      not0
                and     cl, 0F8h
                cmp     cl, 0D0h
                je      near true
                cmp     cl, 10h
                je      near true

; ������ �஢��塞 �� call d8 [reg]

not0:           dec     eax
                cmp     byte [cs:eax], 0FFh
                jne     not1
                mov     cl, byte [cs:eax+1]
                cmp     cl, 54h                 ; �� �뢠�� d8 [esp]
                je      not1
                and     cl, 0F8h
                cmp     cl, 50h
                je      true

; �஢��塞 �� call [reg1 + scale * reg2]

                cmp     byte [cs:eax+1], 14h
                jne     not1
                mov     cl, byte [cs:eax+2]
                and     cl, 7
                cmp     cl, 5                   ; �� �뢠�� [ebp + scale * reg2]
                jne     true

; ������ �஢��塞 �� call d8 [reg1 + scale * reg2]

not1:           dec     eax
                cmp     byte [cs:eax], 0FFh
                jne     not2
                mov     cl, byte [cs:eax+1]
                and     cl, 0F8h
                cmp     cl, 50h
                je      true

; ������ �஢��塞 �� call relative

not2:           dec     eax
                cmp     byte [cs:eax], 0E8h
                je      true

; ������ �஢��塞 �� call d32 � �� d32 [reg]

                dec     eax
                cmp     byte [cs:eax], 0FFh
                jne     not3
                mov     cl, byte [cs:eax+1]
                cmp     cl, 94h                 ; �� �뢠�� � ��⨡��⮢�� �������
                je      not3
                cmp     cl, 15h                 ; call [disp32]
                je      true
                and     cl, 0F8h
                cmp     cl, 90h
                je      true

; � ������� �஢��塞 �� call d32 [reg1 + scale * reg2]

not3:           dec     eax
                cmp     byte [cs:eax], 0FFh
                jne     false
                cmp     byte [cs:eax+1], 94h
                je      true

false:          xor     eax, eax
true:           ret

