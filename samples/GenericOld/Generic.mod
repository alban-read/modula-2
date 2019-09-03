<* +M2EXTENSIONS *>
<* +CPPCOMMENTS *>

 
MODULE Generic;

IMPORT SYSTEM;
IMPORT Windows;
IMPORT WinUser;
FROM Windows IMPORT UINT, LPARAM, WPARAM, LRESULT,
HWND, HMENU, HDC, HBRUSH, HFONT, PAINTSTRUCT, POINT,
LOWORD, HIWORD;
IMPORT CommCtrl;
IMPORT WholeStr;
 


  
CONST
  AppName = "Generic";
  Title = AppName + " Application 2";
 
CONST 
  IDM_NEW = 100;
  IDM_OPEN = 101;
  IDM_SAVE = 102;
  IDM_SAVEAS = 103;
  IDM_PRINT = 104;
  IDM_PRINTSETUP = 105;
  IDM_EXIT = 106;
  IDM_UNDO = 200;
  IDM_CUT = 201;
  IDM_COPY = 202;

  IDM_PASTE = 203;
  IDM_LINK = 204;
  IDM_LINKS = 205;
  IDC_MAIN_STATUS = 601;
  IDC_MAIN_TOOL = 602;
  

CONST 
  IDSTR_FILTER = 1000;
  
CONST 
  LineLength = 132;
  ScreenLines = 32;
  
TYPE 
  line = ARRAY [1..LineLength] OF CHAR;
  lines = ARRAY [1..ScreenLines] OF line; 
 
VAR
  PlainFont: HFONT; 
  BoldFont: HFONT; 
  Screen: lines;
  hStatus: HWND;
  iStatusHeight:INTEGER;
  hTool: HWND;
  
PROCEDURE FillScreen(filler: CHAR);
VAR 
  r: INTEGER;
  c: INTEGER;
  
BEGIN
  FOR r := 1 TO ScreenLines DO
    FOR c := 1 TO LineLength DO
      Screen[r][c] := filler;
    END;
  END;
END FillScreen;
  

PROCEDURE StatusMessage(n: INTEGER; text: ARRAY OF CHAR);
BEGIN 
  Windows.SendMessage(hStatus, CommCtrl.SB_SETTEXT, n, SYSTEM.CAST(LPARAM, SYSTEM.ADR(text)))
END StatusMessage; 
  
PROCEDURE OpenFile(owner: HWND);
VAR
  filter: ARRAY [0..1000] OF CHAR;
  of: Windows.OPENFILENAME;
  file: ARRAY [0..1000] OF CHAR;
  s: ARRAY [0..1100] OF CHAR;

CONST 
  DefExt = "";
  Title = "Select file to open";
  
BEGIN
  
  SYSTEM.FILL(SYSTEM.ADR(filter), 0, SIZE(filter));
  Windows.LoadString(Windows.GetModuleHandle(NIL), IDSTR_FILTER, filter, SIZE(filter));
  file [0] := 0C;

  SYSTEM.FILL(SYSTEM.ADR(of), 0, SIZE(of));
  of.lStructSize := SIZE(of);
  of.hwndOwner := NIL;
  of.lpstrFilter := SYSTEM.ADR(filter);
  of.lpstrDefExt := SYSTEM.ADR(DefExt);
  of.lpstrFile := SYSTEM.ADR(file);
  of.nMaxFile := SIZE(file);
  of.lpstrTitle := SYSTEM.ADR(Title);
  of.Flags := Windows.OFN_HIDEREADONLY;

  IF Windows.GetOpenFileName(of)THEN
    Windows.wsprintf(s, "File selected: %s", file);
    Windows.MessageBox(owner, s, "Open command", Windows.MB_OK);
  END;
END OpenFile;


PROCEDURE onPaint(hWnd: HWND; hdc:HDC);
VAR
  rect: Windows.RECT;
  hfOld: HFONT;
  maxDrop:INTEGER;
  i: INTEGER;
  text: ARRAY[1..31] OF CHAR;
  
  PROCEDURE Min( a:INTEGER; b:INTEGER):INTEGER;
  BEGIN
    IF a < b THEN RETURN a; END;
    RETURN b;
  END Min;  
  
BEGIN
  

  hfOld := Windows.SelectObject(hdc, BoldFont);
   
  Windows.GetClientRect(hWnd, rect);
  maxDrop := rect.bottom - iStatusHeight; 
  WholeStr.IntToStr(iStatusHeight, text);
  StatusMessage(2, text);
 
  
  Windows.SetTextColor(hdc, Windows.RGB(0, 0, 0));
  Windows.SetBkMode(hdc, Windows.OPAQUE);
           
  FOR i := 1 TO ScreenLines DO
    rect.top := -16 + (i * 16);
    rect.bottom := (i * 20);
    WholeStr.IntToStr(rect.bottom , text);
    StatusMessage(3, text);
    WholeStr.IntToStr(maxDrop , text);
    StatusMessage(4, text);
    IF rect.bottom < maxDrop THEN
      IF ODD(i)THEN 
        Windows.SelectObject(hdc, BoldFont);
      ELSE
        Windows.SelectObject(hdc, PlainFont);
      END;
      Windows.DrawText(hdc, Screen[i], LineLength, rect,
        Windows.DT_SINGLELINE);
    END;
  END;
      
  Windows.SelectObject(hdc, hfOld); 

END onPaint;


PROCEDURE [Windows.CALLBACK] WndProc(hWnd: HWND; message: UINT;
  wParam: WPARAM; lParam: LPARAM): LRESULT;

VAR 
  wmId: INTEGER;
  pnt: POINT;
  hMenu: HMENU;
  rect: Windows.RECT;  
  rcStatus:Windows.RECT;
  hdc: HDC;
  ps: PAINTSTRUCT;
  hBrush: HBRUSH;
  
BEGIN
  
  CASE message OF
  
  
  
  | Windows.WM_CREATE:
    hMenu := Windows.GetMenu(hWnd);
    Windows.EnableMenuItem(hMenu, IDM_NEW, Windows.MF_ENABLED + Windows.MF_BYCOMMAND);
    Windows.EnableMenuItem(hMenu, IDM_OPEN, Windows.MF_ENABLED + Windows.MF_BYCOMMAND);
    
    RETURN 0;
   
  | Windows.WM_CHAR:
    FillScreen(CHAR(wParam)); 
    hdc     := Windows.GetDC(hWnd);
    onPaint(hWnd ,hdc); 
    Windows.ReleaseDC(hWnd, hdc); 
      
    
  | Windows.WM_SIZE: 
 
    Windows.SendMessage(hStatus, Windows.WM_SIZE, 0, 0);
    Windows.GetWindowRect(hStatus, rcStatus);
    iStatusHeight := rcStatus.bottom - rcStatus.top;
    
  | Windows.WM_COMMAND:
    wmId := LOWORD(wParam);
 
    CASE wmId OF
    | IDM_EXIT: 
      Windows.DestroyWindow(hWnd);


    | IDM_NEW: 
    
      Windows.MessageBox(hWnd, "'New' menu item pressed", AppName, Windows.MB_OK);
   
    | IDM_OPEN: 
      OpenFile(hWnd);

       
    | IDM_SAVE:
    | IDM_SAVEAS:
    | IDM_UNDO:
    | IDM_CUT:
    | IDM_COPY:
    | IDM_PASTE:
    | IDM_LINK:
    | IDM_LINKS:
    ELSE
      RETURN Windows.DefWindowProc(hWnd, message, wParam, lParam);
    END;

  | Windows.WM_RBUTTONDOWN: 
    StatusMessage(1, "POPUP MENU NEW");
 
  
    
    pnt.x := LOWORD(lParam);
    pnt.y := HIWORD(lParam);
    Windows.ClientToScreen(hWnd, pnt);

    hMenu := Windows.GetSubMenu(Windows.GetMenu(hWnd), 0);
    IF hMenu <> NIL THEN
      Windows.TrackPopupMenu(hMenu, Windows.TPM_SET {}, pnt.x, pnt.y, 0, hWnd, NIL);
    ELSE
      Windows.MessageBeep(Windows.MB_SET {});
    END;

  | Windows.WM_PAINT: // display window contents here.
    StatusMessage(1, "PAINTING");
    
    hdc := Windows.BeginPaint(hWnd, ps);
    hBrush := Windows.CreateSolidBrush(Windows.RGB(0, 0, 255));
    Windows.GetClientRect(hWnd, rect);
    Windows.FillRect(hdc, rect, hBrush);
    Windows.DeleteObject(hBrush); 
    onPaint(hWnd, hdc);
    Windows.EndPaint(hWnd, ps);
    
  | Windows.WM_DESTROY:
    Windows.PostQuitMessage(0);
  ELSE
    RETURN Windows.DefWindowProc(hWnd, message, wParam, lParam);
  END;
  RETURN 0;
END WndProc;





PROCEDURE InitApplication(): BOOLEAN;
VAR 
  wc: Windows.WNDCLASSEX;
  
BEGIN
  
  CommCtrl.InitCommonControls();
  
  wc.style := Windows.CS_HREDRAW + Windows.CS_VREDRAW;
  wc.lpfnWndProc := WndProc;
  wc.cbClsExtra := 0;
  wc.cbWndExtra := 0;
  wc.hInstance := Windows.GetModuleHandle(NIL);
  wc.hIcon := Windows.LoadIcon(wc.hInstance, AppName);
  wc.hCursor := Windows.LoadCursor(NIL, Windows.IDC_ARROW);
  wc.hbrBackground := NIL; 
  wc.lpszMenuName := SYSTEM.ADR(AppName);
  wc.lpszClassName := SYSTEM.ADR(AppName);
 
  wc.cbSize := SIZE(Windows.WNDCLASSEX);
  wc.hIconSm := Windows.LoadIcon(wc.hInstance, "SMALL");
 
  FillScreen("*");

  RETURN Windows.RegisterClassEx(wc) <> 0;
END InitApplication;



// some fonts needed by the editor panes.
PROCEDURE InitFonts(hWnd: HWND): BOOLEAN;

  
  PROCEDURE MulDiv(a, b, c: CARDINAL): INTEGER;
  VAR 
    Result: INTEGER;
  BEGIN
    Result := a * b / c;
    RETURN Result;
  END MulDiv; 


VAR
  hdc: HDC;
  hf: HFONT;
  lfHeight: INTEGER;
  
BEGIN
  
  hdc := Windows.GetDC(hWnd);
  lfHeight := - MulDiv(11, Windows.GetDeviceCaps(hdc, Windows.LOGPIXELSY), 72);
  hf := Windows.CreateFont(
    lfHeight, // height
    0, // width
    0, // cEscapement
    0, // cOrientation
    Windows.FW_NORMAL, // cWeight
    FALSE, // bItalic
    FALSE, // bUnderline
    FALSE, // bStrikeOut
    0, // iCharSet
    Windows.OUT_DEFAULT_PRECIS, // iOutPrecision (enum)
    Windows.CLIP_DEFAULT_PRECIS, // iClipPrecision (set)
    Windows.PROOF_QUALITY, // iQuality (enum)
    Windows.FIXED_PITCH, // iPitchAndFamily
    "CONSOLAS" // pszFaceName
    );
    
  IF hf # NIL THEN
    PlainFont := hf;
  ELSE
    Windows.MessageBox(hWnd, "Plain Font creation failed!", "Error",
      Windows.MB_OK + Windows.MB_ICONEXCLAMATION);
    RETURN FALSE; 
  END;
    
  // bold
  hf := Windows.CreateFont(
    lfHeight, // height
    0, // width
    0, // cEscapement
    0, // cOrientation
    Windows.FW_BOLD, // cWeight
    FALSE, // bItalic
    FALSE, // bUnderline
    FALSE, // bStrikeOut
    0, // iCharSet
    Windows.OUT_DEFAULT_PRECIS, // iOutPrecision (enum)
    Windows.CLIP_DEFAULT_PRECIS, // iClipPrecision (set)
    Windows.PROOF_QUALITY, // iQuality (enum)
    Windows.FIXED_PITCH, // iPitchAndFamily
    "CONSOLAS" // pszFaceName
    );
    
  IF hf # NIL THEN
    BoldFont := hf;
  ELSE
    Windows.MessageBox(hWnd, "Bold Font creation failed!", "Error",
      Windows.MB_OK + Windows.MB_ICONEXCLAMATION);
    RETURN FALSE; 
  END;
    
  
  RETURN TRUE; 
END InitFonts;



PROCEDURE InitMainWindow(): BOOLEAN;

VAR 
  hWnd: HWND;
  rcStatus: Windows.RECT;
 
  PROCEDURE MakeStatusBar;
  TYPE 
    statusBarArray = ARRAY [0..4] OF INTEGER;
  CONST 
    statwidths = statusBarArray{100,200,300,400, - 1}; 
  BEGIN
    
    hStatus := Windows.CreateWindowEx(Windows.WS_EX_LEFT, CommCtrl.STATUSCLASSNAME, "",
      SYSTEM.CAST(Windows.WS_SET, WinUser.WS_CHILD + WinUser.WS_VISIBLE + CommCtrl.SBARS_SIZEGRIP),
      0, 0, 0, 0, hWnd,
      SYSTEM.CAST(HMENU, IDC_MAIN_STATUS), Windows.GetModuleHandle(NIL), NIL);
   
    Windows.SendMessage(hStatus, CommCtrl.SB_SETPARTS,
      SIZE(statwidths) DIV SIZE(INTEGER),
      SYSTEM.CAST(LPARAM,SYSTEM.ADR(statwidths))); 
      
    Windows.SendMessage(hStatus, Windows.WM_SIZE, 0, 0);
    Windows.GetWindowRect(hStatus, rcStatus);
    iStatusHeight := rcStatus.bottom - rcStatus.top;

       
  END MakeStatusBar; 
 
 
BEGIN
  
  hWnd := Windows.CreateWindow(AppName, Title, Windows.WS_OVERLAPPEDWINDOW,
    Windows.CW_USEDEFAULT, 0, Windows.CW_USEDEFAULT, 0,
    NIL, NIL, Windows.GetModuleHandle(NIL), NIL);
    
  IF hWnd = NIL THEN
    RETURN FALSE;
  END;

  IF InitFonts(hWnd) = FALSE THEN
    RETURN FALSE;
  END;

  MakeStatusBar;

  Windows.ShowWindow(hWnd, Windows.SW_SHOWDEFAULT);
  Windows.UpdateWindow(hWnd);
  RETURN TRUE;
  
END InitMainWindow;










VAR 
  msg: Windows.MSG;

BEGIN
  IF InitApplication()AND InitMainWindow()THEN
    WHILE Windows.GetMessage(msg, NIL, 0, 0)DO
      Windows.TranslateMessage(msg);
      Windows.DispatchMessage(msg);
    END;
  END;
END Generic.

