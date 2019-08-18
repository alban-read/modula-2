/******************************************************************************\
|*                                                                            *|
|*  File        :  xdrKernelTypes.h                                           *|
|*  Author      :  AlexS                                                      *|
|*  Description :  This header file contains special data types and constants *|
|*                 definitions.                                               *|
|*                                                                            *|
\******************************************************************************/

#ifndef _xdrKernelTypes_h
#define _xdrKernelTypes_h


#include "xdrTypes.h"


typedef char xdrKernelTypes_ProgramName[256];
typedef char xdrKernelTypes_ProgramArgs[512];
typedef char xdrKernelTypes_SymbolName [256];


typedef BYTE xdrKernelTypes_AppType;
#define xdrKernelTypes_apptypeNone    0
#define xdrKernelTypes_apptypeConsole 1


typedef BYTE xdrKernelTypes_Attribs;
#define xdrKernelTypes_attrExecute 1
#define xdrKernelTypes_attrRead    2
#define xdrKernelTypes_attrWrite   4



typedef struct xdrKernelTypes_tagObject{
  xdrKernelTypes_Attribs Attributes;
  DWORD                  Begin;
  DWORD                  End;
} xdrKernelTypes_Object;

typedef char xdrKernelTypes_typeDebugInfoTag[5];

typedef struct xdrKernelTypes_tagModuleInfo{
  xdrKernelTypes_ProgramName       short_name;
  xdrKernelTypes_ProgramName       full_name;
  xdrKernelTypes_AppType           app_type;
  int                              Handle;
  DWORD                            MainEntry;
  xdrKernelTypes_typeDebugInfoTag  DebugInfoTag;
  DWORD                            DebugInfoStart;
  DWORD                            DebugInfoSize;
  DWORD                            N_Objects;
  xdrKernelTypes_Object            Objects[3];
  DWORD                            CodeObject;
} xdrKernelTypes_ModuleInfo;        


#define xdrKernelTypes_ModuleInfoSize \
                      (sizeof(xdrKernelTypes_ProgramName) * 2 + \
                       sizeof(xdrKernelTypes_AppType) + \
                       sizeof(int) + \
                       sizeof(DWORD) * 5 + \
                       sizeof(xdrKernelTypes_typeDebugInfoTag) + \
                       sizeof(xdrKernelTypes_Object*))

#define xdrKernelTypes_ObjectSize (sizeof(xdrKernelTypes_Attribs) + sizeof(DWORD) * 2)



typedef char xdrKernelTypes_EntryName[256];

typedef struct{
  DWORD                    obj;
  DWORD                    offset;
  xdrKernelTypes_EntryName name;
} xdrKernelTypes_Exported;



/*----------------------------------------------------------------------------*/
#define xdrKernelTypes_GoMode_None	  0  /* ������ �ᯮ������ �ணࠬ��             */
#define xdrKernelTypes_GoMode_SingleStep  1  /* �ᯮ����� ���� �������                  */
#define xdrKernelTypes_GoMode_RangeStep   2  /* �ᯮ����� � 㪠������ ��������� ���ᮢ */
#define xdrKernelTypes_GoMode_Go          3  /* �ᯮ����� �� ������������� ᮡ���      */
  

typedef struct xdrKernelTypes_tagGoMode{

  struct{
    BYTE mode;
  } Header;

  union{
    struct{
      DWORD Begin, End; /* �������� ���ᮢ                        */
    } RangeStep;        /* �ᯮ����� � 㪠������ ��������� ���ᮢ */

    struct{
      BYTE add_step;    /* ��������� ᮡ�⨥ SingleStep? */
    } SingleStep;       /* �ᯮ����� ���� �������        */
  } Body;

} xdrKernelTypes_GoMode;


/*----------------------------------------------------------------------------*/
typedef BYTE xdrKernelTypes_ExceptionID;
#define xdrKernelTypes_ExceptionID_OutOfMemory       0   /* ����� �� ����� ��� ��������� ���ᮢ */
#define xdrKernelTypes_ExceptionID_WriteProtected    1   /* ������ � ���饭��� ������� �����     */
#define xdrKernelTypes_ExceptionID_ProgramException  2   /* �ணࠬ���� ���뢠���                 */
#define xdrKernelTypes_ExceptionID_UserException     3   /* �ᯮ������ ��ࢠ�� ���짮��⥫��      */


typedef BYTE xdrKernelTypes_EventType;
#define xdrKernelTypes_EventType_InternalError      0   /* �᪫��⥫쭠� ����� � �⫠�稪� */
#define xdrKernelTypes_EventType_Exception          1   /* �᪫��⥫쭠� ����� � �ணࠬ�� */
#define xdrKernelTypes_EventType_BreakpointHit      2   /* ��窠 ��⠭���                      */
#define xdrKernelTypes_EventType_SingleStep         3   /* �ᯮ����� ���� �������              */
#define xdrKernelTypes_EventType_Call               4   /* �믮����� �������� CALL           */
#define xdrKernelTypes_EventType_Return             5   /* �믮����� �������� RET            */
#define xdrKernelTypes_EventType_MemoryAccess       6   /* ����� � �����                    */
#define xdrKernelTypes_EventType_ComponentCreated   7   /* ������� ����� ��������� �ணࠬ��  */
#define xdrKernelTypes_EventType_ComponentDestroyed 8   /* ������� ����� ��������� �ணࠬ��  */
#define xdrKernelTypes_EventType_ThreadCreated      9   /* ������ thread                       */
#define xdrKernelTypes_EventType_ThreadDestroyed    10  /* ������ thread                       */


typedef BYTE xdrKernelTypes_AccessType;
#define xdrKernelTypes_AccessType_Nothing    0
#define xdrKernelTypes_AccessType_Read       1
#define xdrKernelTypes_AccessType_Write      2
#define xdrKernelTypes_AccessType_ReadWrite  3

/* ���ଠ�� � ��᫥���� �ந��襤襬 ᮡ�⨨ */
typedef struct xdrKernelTypes_tagEvent{

  struct{
    DWORD                    pc;        /* ����訩 ���� */
    xdrKernelTypes_EventType eventType; /* ��� ᮡ���   */
  } Header;

  union{

    struct{
    } SingleStep;     /* �ᯮ����� ���� �������  */

    struct{
      DWORD      ErrorNo;      /* ����� �訡��                        */
      DWORD      ErrorContext; /* �������⥫�� ��ਡ���             */
    } InternalError;           /* �᪫��⥫쭠� ����� � �⫠�稪� */

    struct{
      xdrKernelTypes_ExceptionID exceptionID;
      DWORD                      XCPT_INFO_1;
      DWORD                      XCPT_INFO_2;    
      DWORD                      XCPT_INFO_3;    
      DWORD                      XCPT_INFO_4;    
    } Exception;      /* �᪫��⥫쭠� ����� � �ணࠬ�� */

    struct{
      DWORD CallAddr;          /* ���� ��뢠���� �������   */
    } Call;           /* �믮����� �������� CALL  */

    struct{
      DWORD ReturnAddr;        /* ���� ������             */
    } Return;         /* �믮����� �������� RET   */

    struct{
      DWORD BreakpointInd;
    } BreakpointHit;  /* ��窠 ��⠭���             */

    struct{
      xdrKernelTypes_ModuleInfo Component;
      BYTE                      Stopable;
    } ComponentCreated;

    struct{
      DWORD        Handle;
    } ComponentDestroyed;

    struct{
      DWORD tid;                 /* Task ID                    */
    } ThreadCreated;

    struct{
      DWORD tid;                 /* Task ID                    */
    } ThreadDestroyed;

  } Body;

} xdrKernelTypes_Event;

#define MAX_EVENTS 10



#endif
