/* "@(#)Generic.c Aug 17 11:05:33 2019" */
/* Generated by XDS Modula-2 to ANSI C v4.20 translator */

#define X2C_int32
#define X2C_index32
#ifndef X2C_H_
#include "X2C.h"
#endif
#define Generic_C_
#include "Windows.h"

#define Generic_AppName "Generic"

#define Generic_Title "Generic Application"

#define Generic_IDM_NEW 100

#define Generic_IDM_OPEN 101

#define Generic_IDM_SAVE 102

#define Generic_IDM_SAVEAS 103

#define Generic_IDM_PRINT 104

#define Generic_IDM_PRINTSETUP 105

#define Generic_IDM_EXIT 106

#define Generic_IDM_UNDO 200

#define Generic_IDM_CUT 201

#define Generic_IDM_COPY 202

#define Generic_IDM_PASTE 203

#define Generic_IDM_LINK 204

#define Generic_IDM_LINKS 205

#define Generic_IDSTR_FILTER 1000

#define Generic_DefExt ""

#define Generic_Title0 "Select file to open"


static void OpenFile0(HWND owner)
{
   char filter[1001];
   OPENFILENAME of;
   char file[1001];
   char s[1101];
   memset((char *)filter,(char)0U,1001UL);
   LoadStringA(GetModuleHandleA(0), 1000U, filter, 1001L);
   file[0U] = 0;
   memset((char *) &of,(char)0U,X2C_CHKUL(sizeof(OPENFILENAMEA),0U,
                X2C_max_longcard));
   of.lStructSize = X2C_CHKUL(sizeof(OPENFILENAMEA),0U,X2C_max_longcard);
   of.hwndOwner = 0;
   of.lpstrFilter = filter;
   of.lpstrDefExt = (PSTR)Generic_DefExt;
   of.lpstrFile = file;
   of.nMaxFile = 1001UL;
   of.lpstrTitle = (PSTR)Generic_Title0;
   of.Flags = 0x4UL;
   if (GetOpenFileNameA(&of)) {
      wsprintfA(s, "File selected: %s", file);
      MessageBoxA(owner, s, (PSTR)"Open command", 0UL);
   }
} /* end OpenFile() */

static long X2C_STDCALL WndProc(HWND, unsigned, unsigned, long);


static long X2C_STDCALL WndProc(HWND hWnd, unsigned message, unsigned wParam,
                 long lParam)
{
   long wmId;
   PAINTSTRUCT ps;
   HDC hdc;
   POINT pnt;
   HMENU hMenu;
   HGDIOBJ hBrush;
   RECT rect;
   switch (message) {
   case 1U:
      hMenu = GetMenu(hWnd);
      EnableMenuItem(hMenu, 100U, 0U);
      EnableMenuItem(hMenu, 101U, 0U);
      return 0L;
   case 273U:
      wmId = (long)LOWORD(wParam);
      switch (wmId) {
      case 106L:
         DestroyWindow(hWnd);
         break;
      case 100L:
         MessageBoxA(hWnd, "\'New\' menu item pressed",
                (PSTR)Generic_AppName, 0UL);
         break;
      case 101L:
         OpenFile0(hWnd);
         break;
      case 102L:
         break;
      case 103L:
         break;
      case 200L:
         break;
      case 201L:
         break;
      case 202L:
         break;
      case 203L:
         break;
      case 204L:
         break;
      case 205L:
         break;
      default:;
         return DefWindowProcA(hWnd, message, wParam, lParam);
      } /* end switch */
      break;
   case 516U:
      pnt.x = (long)LOWORD((unsigned long)X2C_CHKL(lParam,0L,
                X2C_max_longint));
      pnt.y = (long)HIWORD((unsigned long)X2C_CHKL(lParam,0L,
                X2C_max_longint));
      ClientToScreen(hWnd, &pnt);
      hMenu = GetSubMenu(GetMenu(hWnd), 0L);
      if (hMenu) TrackPopupMenu(hMenu, 0U, pnt.x, pnt.y, 0L, hWnd, 0);
      else MessageBeep(0UL);
      break;
   case 15U:
      hdc = BeginPaint(hWnd, &ps);
      hBrush = CreateSolidBrush(RGB(0U, 0U, 255U));
      GetClientRect(hWnd, &rect);
      FillRect(hdc, &rect, hBrush);
      DeleteObject(hBrush);
      SetTextColor(hdc, RGB(255U, 255U, 255U));
      SetBkMode(hdc, TRANSPARENT);
      DrawTextA(hdc, (PSTR)"Generic application", -1L, &rect, 0x25UL);
      EndPaint(hWnd, &ps);
      break;
   case 2U:
      PostQuitMessage(0L);
      break;
   default:;
      return DefWindowProcA(hWnd, message, wParam, lParam);
   } /* end switch */
   return 0L;
} /* end WndProc() */


static char InitApplication(void)
{
   WNDCLASSEXA wc;
   wc.style = 0x3UL;
   wc.lpfnWndProc = WndProc;
   wc.cbClsExtra = 0L;
   wc.cbWndExtra = 0L;
   wc.hInstance = GetModuleHandleA(0);
   wc.hIcon = LoadIconA(wc.hInstance, (PSTR)Generic_AppName);
   wc.hCursor = LoadCursorA(0, (PSTR)32512U);
   wc.hbrBackground = 0;
   wc.lpszMenuName = (PSTR)Generic_AppName;
   wc.lpszClassName = (PSTR)Generic_AppName;
   wc.cbSize = X2C_CHKUL(sizeof(WNDCLASSEXA),0U,X2C_max_longcard);
   wc.hIconSm = LoadIconA(wc.hInstance, (PSTR)"SMALL");
   return RegisterClassExA(&wc)!=0U;
} /* end InitApplication() */


static char InitMainWindow(void)
{
   HWND hWnd;
   hWnd = CreateWindowA((PSTR)Generic_AppName, (PSTR)Generic_Title,
                0xCF0000UL, X2C_min_longint, 0L, X2C_min_longint, 0L, 0, 0,
                GetModuleHandleA(0), 0);
   if (hWnd==0) return 0;
   ShowWindow(hWnd, SW_SHOWDEFAULT);
   UpdateWindow(hWnd);
   return 1;
} /* end InitMainWindow() */

static MSG msg;


X2C_STACK_LIMIT(100000l)
extern int main(int argc, char **argv)
{
   X2C_BEGIN(&argc,argv,1,2000000l,4000000l);
   if (InitApplication() && InitMainWindow()) {
      while (GetMessageA(&msg, 0, 0U, 0U)) {
         TranslateMessage(&msg);
         DispatchMessageA(&msg);
      }
   }
   X2C_EXIT();
   return 0;
}

X2C_MAIN_DEFINITION
