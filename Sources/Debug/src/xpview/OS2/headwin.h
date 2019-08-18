#ifndef __HEADWIN__
#define __HEADWIN__
#include <OS2.H>

// �������﫪� ����ᮢ ����
//
BOOL InitHeadwin(HAB hAB);

//////////////////////////////////////////////////////////////////////////////
//
// ����� ���� WC_HEADWIN - ����� �� �᪮�������� �� ��ਧ��⠫� ������.
// �����ন���� ����᪨����� �ਭ� ������, �� �⮬ ���뫠�� WM_CONTROL�.
// ������ ������ ����� �������� � ����� ��ࠧ��, ����� �� � 㭨�⮦���.
//

    #define WC_HEADWIN "WCHeadwin"
    #define PP_FONT    "8.Helv"

    enum HMODES
    {
      HMOD_DRAGABLE,    // ��⠭���� �� ᮧ����� � �ࠣ���� ��让 (��䮫��)
      HMOD_NODRAGABLE,  // ��⠭���� �� ᮧ�����, �ࠣ���� ����饭�
      HMOD_TASKBAR      // ���-ࠧ��饭��, �ࠣ���� ����饭� (��� �᪡��)
    };

    struct HBTNCREATESTRUCT
    {
      PSZ     pszText;     // ����� ������
      LONG    lWidth;      // ��ਭ� (�祪)
      USHORT  usCmd;       // �����䨪���
      USHORT  usCmdBefore; // ��⠢��� ��। (���� - � �����)
    };
    typedef HBTNCREATESTRUCT *PHBTNCREATESTRUCT;


    // �������� ������
    //
    // m1 - PHBTNCREATESTRUCT
    // Returns: ��� ������ ��� 0
    //
    #define HM_ADDBUTTON      WM_USER+1000


    // ����� �ࠢ����� ࠧ��ࠬ� ������
    //
    // m1 - ०�� �� HMODES
    //
    #define HM_SIZEMODE       WM_USER+1001


    // ������ �ਭ� ������
    //
    // SHORT1FROMMP(m1) - usCmd ��� ���浪��� ����� ������
    // SHORT2FROMMP(m1) - TRUE/FALSE == usCmd/�����
    // Returns: �ਭ� ��� -1 �� �訡��
    //
    #define HM_QUERYBTNWIDTH  WM_USER+1002


    // ��⠭����� �ਭ� ������
    //
    // SHORT1FROMMP(m1) - usCmd ��� ���浪��� ����� ������
    // SHORT2FROMMP(m1) - TRUE/FALSE == usCmd/�����
    // m2               - �ਭ�
    // Returns: �ਭ� ��� -1 �� �訡��
    //
    #define HM_SETBTNWIDTH  WM_USER+1003


    // ������ ��⨬����� ����� ����
    //
    #define HM_QUERYOPTHEIGHT WM_USER+1004


    //---- WM_CONTROL:
    #define HBN_TRACKING   BN_PAINT+100 // m2 = usCmd,sWidth - ��������� �ਭ� ������
    #define HBN_SIZE       BN_PAINT+101 // m2 = usCmd,sWidth - ��⠭������ (�ࠣ��) �ਭ� ������


#endif  /* ifndef __HEADWIN__ */

