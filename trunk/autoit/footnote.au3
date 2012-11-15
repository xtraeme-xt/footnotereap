;
; AutoIt Version: 3.0
; Language:       English
; Platform:       Win9x/NT
; Description:    A tool to download content off footnote.com
; Author:         Dustin Darcy (ddarcy@digipen.edu)
;
; Todos:
; 1. I need to add in an option to allow a resume (from a currently open tab)
; 2. Allow a resume from data that's been stored in the registry (due to a pause or stop)
; 3. Have a start state where it knows nothing about anything -- open a new tab or window
; 4. Implement user defined (download button) x,y pos. This will be useful for different layouts

#include <GUIConstantsEx.au3>
#include <GuiConstants.au3>
#include <INet.au3>
#include <date.au3>
#include <process.au3>


Func _FileSearch($S_ROOT, $S_FILEPATTERN)
	Dim $SEARCH, $FILE, $I, $X, $Y
	; $s_root - where to start searching from
	Dim $S_TROOT = $S_ROOT
	Dim $A_FOLDERS[1], $A_FILES[1], $ATTRIB
	Dim $T_ARRAY
	$A_FOLDERS[0] = 0
	$A_FILES[0] = 0
	$S_TROOT = StringReplace($S_TROOT, "/", "\")
	If(Not(StringMid($S_TROOT, StringLen($S_TROOT), 1) == "\")) Then
		$S_TROOT = $S_TROOT & "\"
	EndIf
	; let's not be a cpu hog
	Sleep(10)
	; search the folder for all files and folders
	$SEARCH = FileFindFirstFile($S_TROOT & "*.*")
	; Check if the search was successful
	If $SEARCH = -1 Then
;~MsgBox(0, "Error", "No files/directories matched the search pattern")
		Return 0
	EndIf
	While 1
		$FILE = FileFindNextFile($SEARCH)
		If @error Then ExitLoop
		if($FILE <> "." And $FILE <> "..") Then
			$ATTRIB = FileGetAttrib($S_TROOT & $FILE)
			; set folders for recursion search
			if(StringInStr($ATTRIB, "D")) Then
				ReDim $A_FOLDERS[$A_FOLDERS[0] + 2]
				$A_FOLDERS[0] = $A_FOLDERS[0] + 1
				$A_FOLDERS[$A_FOLDERS[0]] = $FILE
			EndIf
			; wild cards accepted
			; only wild cards used
			if($S_FILEPATTERN == "*.*" Or $S_FILEPATTERN == "*") Then
				; add to array
				ReDim $A_FILES[$A_FILES[0] + 2]
				$A_FILES[0] = $A_FILES[0] + 1
				$A_FILES[$A_FILES[0]] = $S_TROOT & $FILE
			Else
				; lets search with wild cards in the string
				Dim $S_TEMP = $FILE
				; take care of the left side if *. is used
				If(StringInStr($S_FILEPATTERN, "*.")) Then
					$S_TEMP = StringMid($S_TEMP, 1, StringInStr($S_FILEPATTERN, "*.") - 1) & "*." & StringMid($S_TEMP, StringInStr($S_TEMP, ".", 0, -1) + 1)
				EndIf
				; take care of any ?
				$X = 1
				While $X
					if(StringInStr($S_FILEPATTERN, "?", 0, $X)) Then
						$S_TEMP = StringReplace($S_TEMP, StringInStr($S_FILEPATTERN, "?", 0, $X), "?", 1)
						$X = $X + 1
					Else
						$X = 0
					EndIf
				WEnd
				; take care of right side if .* is used
				If(StringMid($S_FILEPATTERN, StringLen($S_FILEPATTERN) - 1, 2) = ".*") Then
					$S_TEMP = StringReplace($S_TEMP, StringMid($S_TEMP, StringInStr($S_TEMP, ".", 0, -1)), ".*", 1)
				EndIf
				; if file matches the search file, then add to array
				If(StringUpper($S_TEMP) == StringUpper($S_FILEPATTERN)) Then
					ReDim $A_FILES[$A_FILES[0] + 2]
					$A_FILES[0] = $A_FILES[0] + 1
					$A_FILES[$A_FILES[0]] = $S_TROOT & $FILE
				EndIf
			EndIf
		EndIf
	WEnd
	; Close the search handle
	FileClose($SEARCH)
	; found folders, let's search them also
	For $I = 1 To $A_FOLDERS[0]
		$T_ARRAY = _FileSearch($S_TROOT & $A_FOLDERS[$I], $S_FILEPATTERN)
		if(IsArray($T_ARRAY)) Then
			$X = $A_FILES[0]
			ReDim $A_FILES[$A_FILES[0] + $T_ARRAY[0] + 1]
			$A_FILES[0] = $A_FILES[0] + $T_ARRAY[0]
			For $Y = 1 To $T_ARRAY[0]
				$A_FILES[$Y + $X] = $T_ARRAY[$Y]
			Next
		EndIf
	Next
	; file found, return array listing of path\file listing
	if($A_FILES[0] > 0) Then
		Return $A_FILES
	Else
		; no files found
		Return 0
	EndIf
EndFunc   ;==>_FileSearch


Func FileInstalledWhere($Text, $FileMask, $FileToIdentify)
	$InstallDir = FileOpenDialog($Text, @ProgramFilesDir, $FileMask, 2)
	If NOT @error Then
		While StringRight($InstallDir, 13) <> $FileToIdentify
			$A_FILES = _FileSearch( StringLeft($InstallDir, StringInStr($InstallDir, "\", 0, -1) - 1), $FileToIdentify)
			If $A_FILES <> 0 Then
				ExitLoop
			EndIf
			$InstallDir = FileOpenDialog($Text, @ProgramFilesDir, $FileMask, 2)
			If @error Then ExitLoop
		WEnd
	EndIf
	return StringLeft($InstallDir, StringInStr($InstallDir, "\", 0, -1) - 1)
EndFunc   ;==>FileInstalledWhere



Func DirInstalledWhere($Text, $FileMask, $FileToIdentify)
	$InstallDir = FileOpenDialog($Text, @ProgramFilesDir, $FileMask, 2)
	If NOT @error Then
		While StringRight($InstallDir, 13) <> $FileToIdentify
			$A_FILES = _FileSearch( StringLeft($InstallDir, StringInStr($InstallDir, "\", 0, -1) - 1), $FileToIdentify)
			If $A_FILES <> 0 Then
				ExitLoop
			EndIf
			$InstallDir = FileOpenDialog($Text, @ProgramFilesDir, $FileMask, 2)
			If @error Then return -1
		WEnd
	EndIf
	return StringLeft($InstallDir, StringInStr($InstallDir, "\", 0, -1) - 1)
EndFunc   ;==>DirInstalledWhere


Dim $answer = 0
Global $gNT = 1
Global $gOffset = 160
Global $gVerbosity
Global $gCWD = @WorkingDir
Global $gKeyName = "HKEY_CURRENT_USER\SOFTWARE\FoonoteReaper"
Global $gChanges = 0
Global $gChangesLabel
Global $gButton
Global $gWindow
Global $label5
Global $label6
Global $gMakeChangesButton
Global $firstEntry = 0
Global $param1 ;For functions that are called dynamically
Global $gProgramName = "Firefox"
Global $gExeName = "firefox.exe"
Global $gTaskIdentifier = "Firefox"
Global $gDownloadButton

Dim $gGuiItem[4][4]
Dim $gWinPos

#requireadmin
Opt("WinTitleMatchMode", 2)
;Opt("GUIOnEventMode", 1)
If $gNT = 1 Then
	GuiCreate("Overview", 160, 200) ;10, 10, $WS_SIZEBOX
Else
	GuiCreate("Overview", 180, 200)
EndIf
;GuiSetIcon($gCWD & "\a8950027.ico", 0)
GUISetBkColor(0xffffff)

$commands = GuiCtrlCreateMenu("&Commands")
$startitem = GuiCtrlCreateMenuItem("&Start", $commands)
$exititem = GuiCtrlCreateMenuItem("&Exit", $commands)

;WinSetOnTop(GUICreate("Status Window",500,30,500,1), '', 1)

GuiSetState()
;Dim $gWinPos = WinGetPos("Overview", "Steps Completed")
do
	$msg = GuiGetMsg()
	Select
		Case $msg = $GUI_EVENT_CLOSE Or $msg = $exititem
			ExitLoop
		
		               Case $msg = $registrationitem
                    If $gNT = 1 Then RegWrite("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Applets\Regedit\Favorites", "TheUltimateCollection", "REG_SZ", "My Computer\HKEY_CURRENT_USER\SOFTWARE\TheUltimateCollection")
                    Run("regedit.exe")
                    WinWaitActive("Registry Editor")
                    If $gNT = 1 Then Send("!at{F5}")
                    RegDelete("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Applets\Regedit\Favorites", "TheUltimateCollection")
		
		Case $msg = $startitem
			;MsgBox(48, "File Not Found", "Can't find user.cfg file. Exiting.")
			If ProcessExists($gExeName) Then
				;WinWaitActive($gTaskIdentifier, "", 5)
				
				WinActivate($gTaskIdentifier)
				WinSetState($gTaskIdentifier, "", @SW_MAXIMIZE)
				WinWaitActive($gTaskIdentifier, 2)
				WinMove($gTaskIdentifier, "", 0, 0) ; @DesktopWidth, @DesktopHeight)
				Send("^t^l")
				Send("http://www.footnote.com/image/{#}1|7276034{ENTER}")
				Sleep(5 * 1000)
				;This clicks past any form of flash block. So lets use DesktopHeight/2=600 - 175 px = 425px. 425/1200 = 35.416%
				MouseClick("left", @DesktopWidth / 2, @DesktopHeight * 0.3, 1)
				;Refactor as a function
				MsgBox(48, "Need Coordinates", "Due to varying different screen layouts. Please move the mouse cursor over the 'Download' button. After 10 seconds the application will ask you to confirm the location.")
				Do
					$label = GuiCtrlCreateLabel("Countdown:", 5, 10, 160)
					GUICtrlSetFont($label, 18, 400)
					Opt("GUICoordMode", 0) ; make the items appear relative to the last object
					WinActivate("Overview")
					$label1 = GuiCtrlCreateLabel("10", 5, 30, 160)
					GUICtrlSetFont($label1, 18, 400)
					WinWaitActive("Overview")
					For $counter = 10 to 0 Step -1
						;$label1 = GuiCtrlCreateLabel($counter, 5, 30, 160)
						GUICtrlSetData($label1, "" & $counter & "")
						GUISetState()
						Sleep(1000)
						;GUICtrlDelete($label1)
					Next
					$gDownloadButton = MouseGetPos()
					GUICtrlDelete($label)
					GUICtrlDelete($label1)
					Opt("GUICoordMode", 1)
					MouseMove(Random(0, @DesktopWidth), Random(0, @DesktopHeight))
					MouseMove($gDownloadButton[0], $gDownloadButton[1])
				Until(MsgBox(4, "Checking Location...", "Is the mouse pointer over the 'Download' button?" <> 7)
				RegWrite($gKeyName, "noupdate", "REG_DWORD", 1)
				MsgBox(48, "Success", "Success")
				;Impl get Download location part...
				;$list = WinList()
				;for $i = 1 to $list[0][0]
				;  msgbox(0, $list[$i][1], $list[$i][0])
				;next
			Else
				$firefoxdir = DirInstalledWhere("Please specify where you installed " & $gProgramName, "Program (" & $gExeName & ")", $gExeName)
				MsgBox(48, "Debug", FileGetShortName($firefoxdir) & "\" & $gExeName)
				$ret = Run(@ComSpec & " /c " & FileGetShortName($firefoxdir) & "\" & $gExeName, "", @SW_MINIMIZE)
				If $ret <> 0 Then ;AND NOT @Error
					;WinWaitActive("Mozilla Firefox", 20)
				Else
					MsgBox(48, "Debug", $ret)
				EndIf
			EndIf
			
	EndSelect

Until $msg = $GUI_EVENT_CLOSE OR $msg = $exititem
