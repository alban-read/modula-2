#ifndef _xdTypes_H
#define _xdTypes_H

typedef unsigned char  BYTE;
typedef unsigned short WORD;
typedef unsigned long  DWORD;

extern DWORD DWChEnd(DWORD dw);
extern WORD  WChEnd (WORD w);

/* -----------------------------------------------------*/
typedef char PROGRAM_NAME[256];

typedef BYTE APP_TYPE;
#define apptypeNone    0
#define apptypeConsole 1


typedef BYTE ATTRIBS;
#define attrExecute 1
#define attrRead    2
#define attrWrite   4



typedef struct{
  ATTRIBS Attributes;
  DWORD   Begin;
  DWORD   End;
} OBJECT;

typedef char typeDebugInfoTag[5];

typedef struct{
  PROGRAM_NAME      short_name;
  PROGRAM_NAME      full_name;
  APP_TYPE          app_type;
  int               Handle;
  DWORD             MainEntry;
  typeDebugInfoTag  DebugInfoTag;
  DWORD             DebugInfoStart;
  DWORD             DebugInfoSize;
  DWORD             N_Objects;
  OBJECT            Objects[3];
  DWORD             CodeObject;
} EXEC_INFO;        


#define EXEC_INFO_SIZE (sizeof(PROGRAM_NAME) * 2 + \
                       sizeof(APP_TYPE) + \
                       sizeof(int) + \
                       sizeof(DWORD) * 5 + \
                       sizeof(typeDebugInfoTag) + \
                       sizeof(OBJECT*))

#define OBJECT_SIZE (sizeof(ATTRIBS) + sizeof(DWORD) * 2)

/* -----------------------------------------------------*/
typedef BYTE EXCEPTION_ID;
#define excID_OutOfMemory       0   /* ����� �� ����� ��� ��������� ���ᮢ */
#define excID_WriteProtected    1   /* ������ � ���饭��� ������� �����     */
#define excID_ProgramException  2   /* �ணࠬ���� ���뢠���                 */
#define excID_UserException     3   /* �ᯮ������ ��ࢠ�� ���짮��⥫��      */


typedef BYTE EVENT_TYPE;
#define eventType_InternalError    0   /* �᪫��⥫쭠� ����� � �⫠�稪� */
#define eventType_Exception        1   /* �᪫��⥫쭠� ����� � �ணࠬ�� */
#define eventType_BreakpointHit    2   /* ��窠 ��⠭���                      */
#define eventType_SingleStep       3   /* �ᯮ����� ���� �������              */
#define eventType_Call             4   /* �믮����� �������� CALL           */
#define eventType_Return           5   /* �믮����� �������� RET            */
#define eventType_MemoryAccess     6   /* ����� � �����                    */
#define eventType_CompCreated      7   /* ������� ����� ��������� �ணࠬ��  */
#define eventType_CompDestroyed    8   /* ������� ����� ��������� �ணࠬ��  */
#define eventType_ThreadCreated    9   /* ������ thread                       */
#define eventType_ThreadDestroyed  10  /* ������ thread                       */


typedef BYTE ACCESS_TYPE;    
#define accesType_Nothing    0
#define accesType_Read       1
#define accesType_Write      2
#define accesType_ReadWrite  3

/* ���ଠ�� � ��᫥���� �ந��襤襬 ᮡ�⨨ */
typedef union {

  struct{
    DWORD      pc;        /* ����訩 ���� */
    EVENT_TYPE Event;     /* ����⨥       */
  } Common;

  struct{
    DWORD      pc;        /* ����訩 ����           */
    EVENT_TYPE Event;     /* ����⨥                 */
  } SingleStep;           /* �ᯮ����� ���� �������  */

  struct{
    DWORD      pc;           /* ����訩 ����                       */
    EVENT_TYPE Event;        /* ����⨥                             */
    DWORD      ErrorNo;      /* ����� �訡��                        */
    DWORD      ErrorContext; /* �������⥫�� ��ਡ���             */
  } InternalError;           /* �᪫��⥫쭠� ����� � �⫠�稪� */

  struct{
    DWORD        pc;           /* ����訩 ����                       */
    EVENT_TYPE   Event;        /* ����⨥                             */
    EXCEPTION_ID Exception_ID;
    DWORD        XCPT_INFO_1;
    DWORD        XCPT_INFO_2;    
    DWORD        XCPT_INFO_3;    
    DWORD        XCPT_INFO_4;    
  } Exception;                 /* �᪫��⥫쭠� ����� � �ணࠬ�� */

  struct{
    DWORD        pc;           /* ����訩 ����              */
    EVENT_TYPE   Event;        /* ����⨥                    */
    DWORD        CallAddr;     /* ���� ��뢠���� �������   */
  } Call;                      /* �믮����� �������� CALL  */

  struct{
    DWORD        pc;           /* ����訩 ����              */
    EVENT_TYPE   Event;        /* ����⨥                    */
    DWORD        ReturnAddr;   /* ���� ������             */
  } Return;                    /* �믮����� �������� RET   */

  struct{
    DWORD        pc;           /* ����訩 ����              */
    EVENT_TYPE   Event;        /* ����⨥                    */
    DWORD        BreakpointInd;
  } BreakpointHit;             /* ��窠 ��⠭���             */

  struct{
    DWORD        pc;           /* ����訩 ����              */
    EVENT_TYPE   Event;        /* ����⨥                    */
    EXEC_INFO    Component;
    BYTE         Stopable;
  } CompCreated;

  struct{
    DWORD        pc;           /* ����訩 ����              */
    EVENT_TYPE   Event;        /* ����⨥                    */
    DWORD        Handle;
  } CompDestroyed;

  struct{
    DWORD        pc;           /* ����訩 ����              */
    EVENT_TYPE   Event;        /* ����⨥                    */
    DWORD tid;                 /* Task ID                    */
  } ThreadCreated;

  struct{
    DWORD        pc;           /* ����訩 ����              */
    EVENT_TYPE   Event;        /* ����⨥                    */
    DWORD tid;                 /* Task ID                    */
  } ThreadDestroyed;


} EVENT;

#define MAX_EVENTS 10


typedef BYTE MODE;
#define modeNone        0    /* ������ �ᯮ������ �ணࠬ��             */
#define modeSingleStep  1    /* �ᯮ����� ���� �������                  */
#define modeRangeStep   2    /* �ᯮ����� � 㪠������ ��������� ���ᮢ */
#define modeGo          3    /* �ᯮ����� �� ������������� ᮡ���      */
  

typedef union{

  MODE mode;

  struct{
    MODE  mode;
    DWORD Begin, End; /* �������� ���ᮢ                        */
  } RangeStep;        /* �ᯮ����� � 㪠������ ��������� ���ᮢ */

  struct{
    MODE mode;
    BYTE add_step;    /* ��������� ᮡ�⨥ SingleStep? */
  } SingleStep;       /* �ᯮ����� ���� �������        */

} GO_MODE;

typedef char ENTRY_NAME[256];


typedef struct{
  DWORD      obj;
  DWORD      offset;
  ENTRY_NAME name;
} EXPORTED;


#endif