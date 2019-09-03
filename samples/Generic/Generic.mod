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
IMPORT Strings;
 
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
  CharWidth = 7;
  
TYPE 
  cursor = RECORD
    x: INTEGER;
    y: INTEGER;
  END; 
  
TYPE 
  line = ARRAY [1..LineLength] OF CHAR;
  lines = ARRAY [1..ScreenLines] OF line; 
 
VAR
  PlainFont: HFONT; 
  BoldFont: HFONT; 
  Screen: lines;
  hStatus: HWND;
  iStatusHeight: INTEGER;
  hTool: HWND;
  csr: cursor;

PROCEDURE EnableMenuItems(hWnd: HWND);
VAR 
  hMenu: HMENU;
BEGIN
  hMenu := Windows.GetMenu(hWnd);
  Windows.EnableMenuItem(hMenu, IDM_NEW, Windows.MF_ENABLED + Windows.MF_BYCOMMAND);
  Windows.EnableMenuItem(hMenu, IDM_OPEN, Windows.MF_ENABLED + Windows.MF_BYCOMMAND);
  Windows.EnableMenuItem(hMenu, IDM_SAVE, Windows.MF_ENABLED + Windows.MF_BYCOMMAND);
  Windows.EnableMenuItem(hMenu, IDM_SAVEAS, Windows.MF_ENABLED + Windows.MF_BYCOMMAND);
END EnableMenuItems;

  
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

PROCEDURE displayCursorInStatus;
VAR 
  xtext: ARRAY [0..9] OF CHAR;
  ytext: ARRAY [0..9] OF CHAR;
  xytext: ARRAY [0..20] OF CHAR;
BEGIN
  xtext := ""; ytext := ""; xytext := "";
  WholeStr.IntToStr(csr.x, xtext);
  WholeStr.IntToStr(csr.y, ytext);
  Strings.Append(xtext, xytext);
  Strings.Append(".", xytext);
  Strings.Append(ytext, xytext);
  StatusMessage(0, xytext);
END displayCursorInStatus;
  
  

PROCEDURE OpenFile(owner: HWND);
VAR
  filter: ARRAY [0..1000] OF CHAR;
  of: Windows.OPENFILENAME;
  file: ARRAY [0..1000] OF CHAR;
  s: ARRAY [0..1100] OF CHAR;

CONST 
  DefExt = "*.TXT\0";
  Title = "Select file to open";
  Dir = "s:\projects\modula-2\samples";
  
BEGIN
  
  SYSTEM.FILL(SYSTEM.ADR(filter), 0, SIZE(filter));
  Windows.LoadString(Windows.GetModuleHandle(NIL), IDSTR_FILTER, filter, SIZE(filter));
  file [0] := 0C;
  StatusMessage(4, filter);
  SYSTEM.FILL(SYSTEM.ADR(of), 0, SIZE(of));
  
  of.lStructSize := SIZE(of);
  of.hwndOwner := owner;
  of.hInstance := Windows.GetModuleHandle(NIL);
  of.lpstrFilter := SYSTEM.ADR(filter);
  of.nFilterIndex := 1;
  of.lpstrDefExt := SYSTEM.ADR(DefExt);
  of.lpstrFile := SYSTEM.ADR(file);
  of.nMaxFile := SIZE(file);
  of.lpstrTitle := SYSTEM.ADR(Title);
  of.lpstrInitialDir := SYSTEM.ADR(Dir);
  
  // this the hell doesnt work.
  IF Windows.GetOpenFileName(of)THEN
    Windows.wsprintf(s, "File selected: %s", file);
    Windows.MessageBox(owner, s, "Open command", Windows.MB_OK);
  END;
  
END OpenFile;


PROCEDURE SaveFile(owner: HWND; filename: ARRAY OF CHAR);
VAR
  filter: ARRAY [0..1000] OF CHAR;
  of: Windows.OPENFILENAME;
  file: ARRAY [0..1000] OF CHAR;
  s: ARRAY [0..1100] OF CHAR;

CONST 
  DefExt = "*.TXT\0";
  Title = "Save File";
  Dir = "s:\projects\modula-2\samples";
  
BEGIN
  
  SYSTEM.FILL(SYSTEM.ADR(filter), 0, SIZE(filter));
  Windows.LoadString(Windows.GetModuleHandle(NIL), IDSTR_FILTER, filter, SIZE(filter));
  Strings.Assign(filename, file);
  StatusMessage(4, filter);
  SYSTEM.FILL(SYSTEM.ADR(of), 0, SIZE(of));
  
  of.lStructSize := SIZE(of);
  of.hwndOwner := owner;
  of.hInstance := Windows.GetModuleHandle(NIL);
  of.lpstrFilter := SYSTEM.ADR(filter);
  of.nFilterIndex := 1;
  of.lpstrDefExt := SYSTEM.ADR(DefExt);
  of.lpstrFile := SYSTEM.ADR(file);
  of.nMaxFile := SIZE(file);
  of.lpstrTitle := SYSTEM.ADR(Title);
  of.lpstrInitialDir := SYSTEM.ADR(Dir);
  
  // this the hell doesnt work.
  IF Windows.GetSaveFileName(of)THEN
    Windows.wsprintf(s, "File selected to save: %s", file);
    Windows.MessageBox(owner, s, "Save command", Windows.MB_OK);
  END;
  
END SaveFile;




PROCEDURE onPaintLine(hWnd: HWND; hdc: HDC; line: INTEGER);
VAR
  rect: Windows.RECT;
  crect: Windows.RECT;
  hfOld: HFONT;
  maxDrop: INTEGER;
  i: INTEGER;
 
  PROCEDURE Min(a: INTEGER; b: INTEGER): INTEGER;
  BEGIN
    IF a < b THEN 
      RETURN a; 
    END;
    RETURN b;
  END Min; 
  
BEGIN
  
 
  hfOld := Windows.SelectObject(hdc, BoldFont);
  Windows.GetClientRect(hWnd, rect);
  maxDrop := rect.bottom - iStatusHeight; 
 
  Windows.SetTextColor(hdc, Windows.RGB(0, 0, 0));
  Windows.SetBkMode(hdc, Windows.OPAQUE);
         
 
  rect.top := Min(14 + (line * 16), maxDrop);
  rect.bottom := Min(28 + (line * 20), maxDrop);
  IF ODD(line)THEN 
    Windows.SelectObject(hdc, BoldFont);
  ELSE
    Windows.SelectObject(hdc, PlainFont);
  END;
  Windows.DrawText(hdc, Screen[line], LineLength, rect,
    Windows.DT_SINGLELINE);
 
 
  Windows.SelectObject(hdc, hfOld); 

END onPaintLine;




// the cursor is repainted including the line above and below 
PROCEDURE onPaintCursor(hWnd: HWND; hdc: HDC; cline: INTEGER);
VAR
  rect: Windows.RECT;
  crect: Windows.RECT;
  rrect: Windows.RECT;
  hfOld: HFONT;
  hrgn: Windows.HRGN;
  maxDrop: INTEGER;
  line: INTEGER;
  i: INTEGER;
  cstring: ARRAY [0..3] OF CHAR;

 
  PROCEDURE Min(a: INTEGER; b: INTEGER): INTEGER;
  BEGIN
    IF a < b THEN 
      RETURN a; 
    END;
    RETURN b;
  END Min; 
  
  PROCEDURE Max(a: INTEGER; b: INTEGER): INTEGER;
  BEGIN
    IF a > b THEN 
      RETURN a; 
    END;
    RETURN b;
  END Max; 
  
BEGIN
 
  hfOld := Windows.SelectObject(hdc, BoldFont);
  Windows.GetClientRect(hWnd, rect);
  maxDrop := rect.bottom - iStatusHeight; 
  Windows.SetTextColor(hdc, Windows.RGB(0, 0, 0));
  line := csr.y;
  rect.top := Min(14 + (line * 16), maxDrop);
  rect.bottom := Min(28 + (line * 20), maxDrop);
  crect := rect;
  crect.left := - CharWidth + csr.x * CharWidth;
  crect.right := crect.left + CharWidth;
  Windows.SelectObject(hdc, PlainFont);
  Windows.SetBkMode(hdc, Windows.TRANSPARENT);
  Windows.DrawText(hdc, "_", 1, crect, Windows.DT_SINGLELINE);
  Windows.SelectObject(hdc, hfOld); 

END onPaintCursor;

PROCEDURE onUnPaintCursor(hWnd: HWND; hdc: HDC; cline: INTEGER);
VAR
  rect: Windows.RECT;
  crect: Windows.RECT;
  rrect: Windows.RECT;
  hfOld: HFONT;
  hrgn: Windows.HRGN;
  maxDrop: INTEGER;
  line: INTEGER;
  i: INTEGER;
  cstring: ARRAY [0..3] OF CHAR;

 
  PROCEDURE Min(a: INTEGER; b: INTEGER): INTEGER;
  BEGIN
    IF a < b THEN 
      RETURN a; 
    END;
    RETURN b;
  END Min; 
  
  PROCEDURE Max(a: INTEGER; b: INTEGER): INTEGER;
  BEGIN
    IF a > b THEN 
      RETURN a; 
    END;
    RETURN b;
  END Max; 
  
BEGIN
  StatusMessage(1, "Paint Line");
  hfOld := Windows.SelectObject(hdc, BoldFont);
  Windows.GetClientRect(hWnd, rect);
  maxDrop := rect.bottom - iStatusHeight; 
 
  Windows.SetTextColor(hdc, Windows.RGB(0, 0, 0));
  line := csr.y;
  rect.top := Min(14 + (line * 16), maxDrop);
  rect.bottom := Min(28 + (line * 20), maxDrop);
  IF ODD(line)THEN 
    Windows.SelectObject(hdc, BoldFont);
  ELSE
    Windows.SelectObject(hdc, PlainFont);
  END;
    
  crect := rect;
  crect.left := - CharWidth + csr.x * CharWidth;
  crect.right := crect.left + CharWidth;
  cstring[0] := Screen[line][csr.x]; 
  cstring[1] := 0C;
  Windows.SetBkMode(hdc, Windows.OPAQUE);
  Windows.DrawText(hdc, cstring, 1, crect,
    Windows.DT_SINGLELINE);
  Windows.SelectObject(hdc, hfOld); 

END onUnPaintCursor;


PROCEDURE onPaint(hWnd: HWND; hdc: HDC);
VAR
  rect: Windows.RECT;
  crect: Windows.RECT;
  hfOld: HFONT;
  maxDrop: INTEGER;
  i: INTEGER;
  
 
  PROCEDURE Min(a: INTEGER; b: INTEGER): INTEGER;
  BEGIN
    IF a < b THEN 
      RETURN a; 
    END;
    RETURN b;
  END Min; 
  
BEGIN
  
  StatusMessage(1, "Paint All lines");
  hfOld := Windows.SelectObject(hdc, BoldFont);

  Windows.GetClientRect(hWnd, rect);
  maxDrop := rect.bottom - iStatusHeight; 
  Windows.SetTextColor(hdc, Windows.RGB(0, 0, 0));
  Windows.SetBkMode(hdc, Windows.OPAQUE);
         
  FOR i := 1 TO ScreenLines DO
    rect.top := Min(14 + (i * 16), maxDrop);
    rect.bottom := Min(28 + (i * 20), maxDrop);
    
    IF ODD(i)THEN 
      Windows.SelectObject(hdc, BoldFont);
    ELSE
      Windows.SelectObject(hdc, PlainFont);
    END;
    Windows.DrawText(hdc, Screen[i], LineLength, rect,
      Windows.DT_SINGLELINE);
      
  END;
 
  Windows.SelectObject(hdc, hfOld); 
 
END onPaint;


PROCEDURE redisplayCursorOn(hWnd: HWND; line: INTEGER);
VAR 
  hdc: HDC;
BEGIN
  hdc := Windows.GetDC(hWnd);
  onPaintCursor(hWnd, hdc, line); 
  Windows.SendMessage(hStatus, Windows.WM_SIZE, 0, 0);
  Windows.ReleaseDC(hWnd, hdc); 
  displayCursorInStatus;
END redisplayCursorOn;

PROCEDURE redisplayCursorOff(hWnd: HWND; line: INTEGER);
VAR 
  hdc: HDC;
BEGIN
  hdc := Windows.GetDC(hWnd);
  onUnPaintCursor(hWnd, hdc, line); 
  Windows.SendMessage(hStatus, Windows.WM_SIZE, 0, 0);
  Windows.ReleaseDC(hWnd, hdc); 
END redisplayCursorOff;


PROCEDURE redisplay(hWnd: HWND);
VAR 
  hdc: HDC;
BEGIN
  hdc := Windows.GetDC(hWnd);
  onPaint(hWnd, hdc); 
  redisplayCursorOn(hWnd, csr.y);
  Windows.SendMessage(hStatus, Windows.WM_SIZE, 0, 0);
  Windows.ReleaseDC(hWnd, hdc); 
END redisplay;


PROCEDURE redisplayLine(hWnd: HWND; line: INTEGER);
VAR 
  hdc: HDC;
BEGIN
  hdc := Windows.GetDC(hWnd);
  onPaintLine(hWnd, hdc, line); 
  redisplayCursorOn(hWnd, csr.y);
  Windows.SendMessage(hStatus, Windows.WM_SIZE, 0, 0);
  Windows.ReleaseDC(hWnd, hdc); 
END redisplayLine;

// key pressed in wParam.
PROCEDURE moveCursor(hWnd: HWND; wParam: WPARAM);
BEGIN
  IF wParam = Windows.VK_LEFT THEN
    redisplayCursorOff(hWnd, csr.y);
    csr.x := csr.x - 1;
    IF csr.x <= 1 THEN
      csr.x := 1;
    END;
    redisplayCursorOn(hWnd, csr.y);
  END;
  IF wParam = Windows.VK_RIGHT THEN
    redisplayCursorOff(hWnd, csr.y);
    csr.x := csr.x + 1;
    IF csr.x > LineLength THEN
      csr.x := LineLength;
    END;
    redisplayCursorOn(hWnd, csr.y);
  END; 
  IF wParam = Windows.VK_UP THEN
    redisplayCursorOff(hWnd, csr.y);
    csr.y := csr.y - 1;
    IF csr.y < 1 THEN
      csr.y := 1;
    END;
    redisplayCursorOn(hWnd, csr.y);
  END; 
  IF wParam = Windows.VK_DOWN THEN
    redisplayCursorOff(hWnd, csr.y);
    csr.y := csr.y + 1;
    IF csr.y > ScreenLines THEN
      csr.y := ScreenLines;
    END;
    redisplayCursorOn(hWnd, csr.y);
  END; 
  // backspace; rub out.
  IF wParam = Windows.VK_BACK THEN
     redisplayCursorOff(hWnd, csr.y);
     csr.x := csr.x - 1;
     IF csr.x <= 1 THEN
       csr.x := 1;
     END;
     IF (csr.x < LineLength) AND (csr.y < ScreenLines) THEN
         Screen[csr.y][csr.x] := CHAR(" ");
         redisplayCursorOff(hWnd, csr.y);
     END;
     redisplayCursorOn(hWnd, csr.y);
   END;
   
END moveCursor;

// insert at cursor and advance.
PROCEDURE insertAtCursor(hWnd: HWND; wParam: WPARAM);
BEGIN
  
  IF (wParam < 32)  OR (wParam>127) THEN 
    RETURN;
  END;
   
  IF (csr.x < LineLength) AND (csr.y < ScreenLines) THEN
    Screen[csr.y][csr.x] := CHAR(wParam);
    redisplayCursorOff(hWnd, csr.y);
    csr.x := csr.x + 1;
    IF csr.x > LineLength THEN
      csr.x := LineLength;
    END;
    redisplayCursorOn(hWnd, csr.y);
  END;
END insertAtCursor;

PROCEDURE [Windows.CALLBACK] WndProc(hWnd: HWND; message: UINT;
  wParam: WPARAM; lParam: LPARAM): LRESULT;

VAR 
  wmId: INTEGER;
  pnt: POINT;
  hMenu: HMENU;
  rect: Windows.RECT; 
  rcStatus: Windows.RECT;
  hdc: HDC;
  ps: PAINTSTRUCT;
  hBrush: HBRUSH;
  
BEGIN
  
  CASE message OF
  
  | Windows.WM_CREATE:
    EnableMenuItems(hWnd);
    RETURN 0;
   
    // insert char at cursor position 
  | Windows.WM_CHAR:
    insertAtCursor(hWnd, wParam);
  
    // all about cursor movement.
  | Windows.WM_KEYDOWN:
    moveCursor(hWnd, wParam);
    
  | Windows.WM_SIZE: 
 
    Windows.SendMessage(hStatus, Windows.WM_SIZE, 0, 0);
    Windows.SendMessage(hTool, Windows.WM_SIZE, 0, 0);
    Windows.GetWindowRect(hStatus, rcStatus);
    iStatusHeight := rcStatus.bottom - rcStatus.top;
    
  | Windows.WM_COMMAND:
    wmId := LOWORD(wParam);
 
    CASE wmId OF
    | IDM_EXIT: 
      Windows.DestroyWindow(hWnd);

      // new screen
    | IDM_NEW: 
      FillScreen(CHAR(" ")); 
      redisplay(hWnd);
   
    | IDM_OPEN: 
      OpenFile(hWnd);

       
    | IDM_SAVE:
      SaveFile(hWnd, "filename.txt");
    | 
    IDM_SAVEAS:
      SaveFile(hWnd, "filename.txt");
      
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
    hBrush := Windows.CreateSolidBrush(Windows.RGB(100, 100, 100));
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
  
  csr.x := 10;
  csr.y := 10;
  
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
      HIGH(statwidths) + 1, 
      SYSTEM.CAST(LPARAM, SYSTEM.ADR(statwidths))); 
      
    Windows.SendMessage(hStatus, Windows.WM_SIZE, 0, 0);
    Windows.GetWindowRect(hStatus, rcStatus);
    iStatusHeight := rcStatus.bottom - rcStatus.top;

       
  END MakeStatusBar; 


  PROCEDURE MakeToolBar;
  VAR
    tbb: ARRAY [0..3] OF CommCtrl.TBBUTTON;
    tbab: CommCtrl.TBADDBITMAP;
 
  BEGIN
  
    hTool := Windows.CreateWindowEx(
      Windows.WS_EX_LEFT, CommCtrl.TOOLBARCLASSNAME, "",
      Windows.WS_CHILD + Windows.WS_VISIBLE, 0, 0, 0, 0,
      hWnd, SYSTEM.CAST(HMENU, IDC_MAIN_TOOL), Windows.GetModuleHandle(NIL), NIL);
    Windows.SendMessage(hTool, CommCtrl.TB_BUTTONSTRUCTSIZE, SIZE(CommCtrl.TBBUTTON), 0);
    
    tbab.hInst := CommCtrl.HINST_COMMCTRL;
    tbab.nID := CommCtrl.IDB_STD_SMALL_COLOR;
    Windows.SendMessage(hTool, CommCtrl.TB_ADDBITMAP, 0, SYSTEM.CAST(LPARAM, SYSTEM.ADR(tbab)));
     
    tbb[0].iBitmap := CommCtrl.STD_FILENEW;
    tbb[0].iString := 0;
    tbb[0].fsState := CommCtrl.TBSTATE_ENABLED;
    tbb[0].fsStyle := CommCtrl.TBSTYLE_BUTTON;
    tbb[0].idCommand := IDM_NEW;

    tbb[1].iBitmap := CommCtrl.STD_FILEOPEN;
    tbb[1].iString := 0;
    tbb[1].fsState := CommCtrl.TBSTATE_ENABLED;
    tbb[1].fsStyle := CommCtrl.TBSTYLE_BUTTON;
    tbb[1].idCommand := IDM_OPEN;

    tbb[2].iBitmap := CommCtrl.STD_FILESAVE;
    tbb[2].iString := 0;
    tbb[2].fsState := CommCtrl.TBSTATE_ENABLED;
    tbb[2].fsStyle := CommCtrl.TBSTYLE_BUTTON;
    tbb[2].idCommand := IDM_SAVE;
    
    
    
    Windows.SendMessage(hTool, CommCtrl.TB_ADDBUTTONS, HIGH(tbb),
      SYSTEM.CAST(LPARAM, SYSTEM.ADR(tbb)));
    
  END MakeToolBar; 


  // some fonts needed by the editor panes.
  PROCEDURE InitFonts(): BOOLEAN;

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
 
 
 
BEGIN
  
  hWnd := Windows.CreateWindow(AppName, Title, Windows.WS_OVERLAPPEDWINDOW,
    Windows.CW_USEDEFAULT, 0, Windows.CW_USEDEFAULT, 0,
    NIL, NIL, Windows.GetModuleHandle(NIL), NIL);
    
  IF hWnd = NIL THEN
    RETURN FALSE;
  END;

  IF InitFonts() = FALSE THEN
    RETURN FALSE;
  END;

  MakeStatusBar;
  MakeToolBar;

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

