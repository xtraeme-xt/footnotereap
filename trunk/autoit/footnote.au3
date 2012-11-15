;FootNote Reaper
; AutoIt Version: 3.0
; Language:       English
; Platform:       Win9x/NT
; Description:    A tool to download content off footnote.com
; Author:         Xtraeme (xthaus@yahoo.com)
;
; Postscript: It may have been better to just use autoitx and a real language like C#. This
; way I would have been able to use pointers rather than having to copy data all over the place
; and manually synchronizing everything. Once done with this script I'll try to port it to see
; if it makes things cleaner or if there are any impasses.
;
; Todos:
; 1. I need to add in an option to allow a resume (from a currently open tab)
; 2. Allow a resume from data that's been stored in the registry (due to a pause or stop)
; 3. Have a start state where it knows nothing about anything -- open a new tab or window
; 4. Implement user defined (download button) x,y pos. This will be useful for different layouts
; 5. Create an options panel with boxes? (i.e. two textboxes with coords for download loc?)
;    This may be overkill since a person can just make the modifications in regedit. Instead
;    just create a readme with all the values?
; 6. In the directory it's probably worthwhile to save the URL of the starting grouping for each
;    set. This will allow easy review. It may even be worthwhile to grab as much metadata as
;    possible including comments, and other factoids. This can be stored in a .meta file.
; 7. Create a function that runs through all the check items to make sure they're over Then
;    correct widget. Basically I'll try to calculate their location, and then get confirmation
; 8. Have an array that keeps the information for the last 3 entries. This should be good enough
;    for recovery if things go south.
; 9. For a logging facility use ConsoleWrite()? Then just hook it? Or write to file instead?
; 10. With $lookforwin = PixelChecksum(20, 40, 100, 100) I can probably automate detecting if
;     a button is actually being activated.
; 11. Configured basic hotkeys using F12 as Pause and END as stop. Perhaps F11 as resume/start?

;BUGS:
; 1. Having Firefox open, starting the app, closing FF, and then trying to do initialize doesn't work
;    I'm pretty sure it's getting stuck in a WinWaitActive() of some sort. So probably in the MakeActive
;    loop

#include <WindowsConstants.au3>
#include <GuiMenu.au3>
#include <GUIConstantsEx.au3>
#include <GuiConstants.au3>
#include <INet.au3>
#include <date.au3>
#include <process.au3>
#Include <Array.au3>
#Include <Memory.au3>
#include <nomadmemory.au3>
#include <misc.au3>

;for about
#include <StaticConstants.au3>
#include <ButtonConstants.au3>

Global Const $WindowMargin[2] = [16, 36]
Global Const $MF_BYCOMMAND = 0x00000000
;Global Const $MF_OWNERDRAW			= 0x00000100

Func FixClientSize(ByRef $size)
	if(Not IsArray($size)) then return False
	$size[0] += $WindowMargin[0]
	$size[1] += $WindowMargin[1]
	return true
EndFunc
	

;================= Window Routines ====================

Func ModifyMenu($hMenu, $nID, $nFlags, $nNewID, $ptrItemData)
	Local $bResult = DllCall('user32.dll', 'int', 'ModifyMenu', _
			'hwnd', $hMenu, _
			'int', $nID, _
			'int', $nFlags, _
			'int', $nNewID, _
			'ptr', $ptrItemData)
	Return $bResult[0]
EndFunc   ;==>ModifyMenu

Func SetOwnerDrawn($hMenu, $MenuItemID, $sText)
	$stItemData = DllStructcreate('int')
	DllStructSetData($stItemData, 1, $MenuItemID)
	
	$nFlags = BitOr($MF_BYCOMMAND, $MF_OWNERDRAW)
	
	If StringLen($sText) = 0 Then $nFlags = BitOr($nFlags, $MF_SEPARATOR)
	
	ModifyMenu($hMenu, _
			$MenuItemID, _
			$nFlags, _
			$MenuItemID, _
			DllStructGetPtr($stItemData))
EndFunc   ;==>SetOwnerDrawn

;================ End Window Routines =================



;================== File Routines =====================

Func _FileSearch($S_ROOT, $S_FILEPATTERN)
	Logger($ETRACE, "_FileSearch(" & $_ROOT & "," & $S_FILEPATTERN & ")", false)
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
	Logger($ETRACE, "FileInstalledWhere()", false)
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
	Logger($ETRACE, "DirInstalledWhere()", false)
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

;================= End File Routines ===================



Func OnOffOrError($keyname, $valuename)
	Logger($ETRACE, "OnOffOrError(" & $keyname & "," & $valuename & ")", false)
	$temp = RegRead($keyname, $valuename)
	;$error = @Error
	If $temp = "" AND @Error Then
		;If $error > 0 Then  $error = -($error + 2 )
		return -1
	EndIf
	return $temp
EndFunc   ;==>OnOffOrError


Func SetArrays()
	Logger($ETRACE, "SetArrays()", false)
EndFunc   ;==>SetArrays

Func _RegButtonsSet($start = 0, $loadData = false)
	Logger($ETRACE, "CountRegButtonsSet(" & $start & ")", false)
	Local $buttonXY[2] = [0, 0]
	Local $max = Ubound($gFootnoteButtonArray) - 1
	If $max < 0 Then CleanupExit(5, "$gFootnoteButtonArray has no objects" & @error, true)
	for $I = $start to $max
		$buttonXY[0] = OnOffOrError($gKeyName, $gFootnoteButtonArray[$I][$EREGSZ] & "X")
		$buttonXY[1] = OnOffOrError($gKeyName, $gFootnoteButtonArray[$I][$EREGSZ] & "Y")
		
		if(NOT($buttonXY[0] = -1 or $buttonXY[1] = -1)) Then
			if($loadData = true) then $gFootnoteButtonArray[$I][$EOBJECT] = $buttonXY
			$successfulLoads += 1
		Else
			Logger($EVERBOSE, "Load failed locate anything for " & $gFootnoteButtonArray[$I][$EREGSZ], false)
		EndIf
	next
	return $successfulLoads
EndFunc

Func CountRegButtonsSet($start = 0)
	return _RegButtonsSet($start, false)
EndFunc

Func LoadRegButtons($start = 0)
	return _RegButtonsSet($start, true)
EndFunc


Func CountObjButtonsSet()
	Logger($ETRACE, "CountObjButtonsSet()", false)
	Local $countCoords = 0
	For $I = 0 to Ubound($gFootnoteButtonArray) - 1
		$objcoords = $gFootnoteButtonArray[$I][$EOBJECT]
		if(Not IsArray($objcoords) or Ubound($objcoords < 2)) Then ContinueLoop
		if($objcoords[0] <> 0 and $objcoords[1] <> 0) Then $countCoords += 1
	Next
	return $countCoords
EndFunc


Func SetCoordinates($buttonName, $timer, $baseKey, $keyname, ByRef $coords)
	Logger($ETRACE, "SetCoordinates(" & $buttonName & "," & $timer & "," & $baseKey & "," & $keyname & "," & "coords)", false)
	MsgBox(48, "Need Coordinates", "Due to differing screen layouts, we need to establish several reference points. Please move the mouse cursor over the '" & $buttonName & "' button. After " & $timer & " seconds the application will ask you to confirm the location.")
	Do
		$label = GuiCtrlCreateLabel("Countdown:", 5, 10, 160)
		GUICtrlSetFont($label, 18, 400)
		Opt("GUICoordMode", 0) ; make the items appear relative to the last object
		WinActivate("FootnoteReap")
		$label1 = GuiCtrlCreateLabel("" & $timer & "", 5, 30, 160)
		GUICtrlSetFont($label1, 18, 400)
		WinWaitActive("FootnoteReap")
		For $counter = $timer to 0 Step -1
			;$label1 = GuiCtrlCreateLabel($counter, 5, 30, 160)
			GUICtrlSetData($label1, "" & $counter & "")
			GUISetState()
			Sleep(1000)
			;GUICtrlDelete($label1)
		Next
		$coords = MouseGetPos()
		GUICtrlDelete($label)
		GUICtrlDelete($label1)
		Opt("GUICoordMode", 1)
		MouseMove(Random(0, @DesktopWidth), Random(0, @DesktopHeight))
		MouseMove($coords[0], $coords[1])
	Until(MsgBox(4, "Checking Location...", "Is the mouse pointer over the '" & $buttonName & "' button?") <> 7)
	
	$ret = WindowResizedOrMoved(true)
	RegWrite($baseKey, $keyname & "X", "REG_DWORD", $coords[0])
	RegWrite($baseKey, $keyname & "Y", "REG_DWORD", $coords[1])
	
	;The Download button tries to perform some automagic guessing where everything is on the screen.
	if($buttonName = $gDownloadButtonKey) Then
		$gPositionsValid = true
		RegWrite($gKeyName, "gPositionsValid", "REG_DWORD", $gPositionsValid)
		if($gSaveImageDialogUp = false) Then
			MouseClick("Left", $coords[0], $coords[1])
			$gSaveImageDialogUp = True
		endif
		
		Local $countCoords = CountObjButtonsSet()
		if($ret = true or $countCoords = 0) then
			CalcAndSetCoordsRelativeToDownload()
		endif
	EndIf
	return true
EndFunc   ;==>SetCoordinates


Func WindowResizedOrMoved($regwrite = false) ;$x = $, $y, $width, $height)
	Logger($ETRACE, "WindowResizedOrMoved()", false)
	$changed = false
	$winPos = WinGetPos($gTaskIdentifier)
	$winSize = WinGetClientSize($gTaskIdentifier)
	FixClientSize($winSize)
	;if we don't have a window open we have nothing to work with.
	if(Not IsArray($winPos) or UBound($winPos) < 2) then return true ;BUG: had it as false before and that causes errors when opening a window setting the values, closing a window, and then trying to do a check/set
	
	if(($winPos[0] <> $gBrowserWinPos[0]) or($winPos[1] <> $gBrowserWinPos[1])) Then
		$changed = True
	EndIf
	;The size of the y-axis may not matter too much. I'll say if it's changed and if it's less
	;than the current length and less than 400px then something may be messed up.
	if(($winSize[0] <> $gBrowserWinSize[0]) or($winSize[1] < $gBrowserWinSize[1] and $winSize[1] <= 400)) Then
		$changed = True
	EndIf
	
	if($changed = true) Then
		$gPositionsValid = false
		$gBrowserWinPos = $winPos
		$gBrowserWinSize = $winSize
	EndIf
	
	if(($regwrite = true and $changed = true) OR (OnOffOrError($gKeyName, "gWinPosX") = -1)) Then
		RegWrite($gKeyName, "gWinPosX", "REG_DWORD", $gBrowserWinPos[0])
		RegWrite($gKeyName, "gWinPosY", "REG_DWORD", $gBrowserWinPos[1])
		RegWrite($gKeyName, "gWinSizeX", "REG_DWORD", $gBrowserWinSize[0])
		RegWrite($gKeyName, "gWinSizeY", "REG_DWORD", $gBrowserWinSize[1])
		RegWrite($gKeyName, "gPositionsValid", "REG_DWORD", $gPositionsValid)
	endIf
	
	if($changed = true) then 
		return true
	Endif
	return false
EndFunc   ;==>WindowResizedOrMoved


Func _SetCoords(ByRef $name, $X, $Y, $baseKey, $regSz)
	Logger($ETRACE, "_SetCoords()", false)
	If Not IsArray($name) Then return false
	$name[0] = $X
	$name[1] = $Y
	
	RegWrite($baseKey, $regSz & "X", "REG_DWORD", $name[0])
	RegWrite($baseKey, $regSz & "Y", "REG_DWORD", $name[1])
	return true
EndFunc   ;==>_SetCoords


;XTRAEME: May want to have an option to choose global over indice or indice over global
Func CheckParity(ByRef $array, $indice, ByRef $globalvar, $msg, $msgbox)
	Logger($ETRACE, "CheckParity()", false)
	;Only works with arrays of [2] and coords
	If Not(IsArray($array)) Then return 1
	
	Local $subarray = $array[$indice][1]
	
	If Not(IsArray($subarray) or IsArray($globalvar)) Then return 1
	If Not(UBound($subarray) >= 2 and UBound($globalvar) >= 2) Then return 2
	
	If($subarray[0] <> $globalvar[0] Or($subarray[1] <> $globalvar[1])) Then
		;TODO: reenable the msgbox at some point to test to make sure we're not missing anything
		Logger($ETRACE, "gButtonArray and Coords unsynchronized ... (possible error)", false)
		$array[$indice][1] = $globalvar ;let the global have precedence over the buttonarray ...
		CheckParity($array, $indice, $globalvar, $msg, $msgbox)
	EndIf
	return 0
EndFunc   ;==>CheckParity


;Order = 0 means assign global to array
;Order = 1 means assign array to globals
Func SyncArrayAndGlobals($order = 0)
	Logger($ETRACE, "SyncArrayAndGlobals()", false)
	$max = Ubound($gFootnoteButtonArray) - 1
	If $max < 0 Then CleanupExit(5, "$gFootnoteButtonArray has no objects" & @error, true)
	
	for $I = 0 to $max
		if(StringCompare($gFootnoteButtonArray[$I][$EBUTTON_KEY], $gDownloadButtonKey) = 0) then
			if($order = 0) then
				$gFootnoteButtonArray[$I][$EOBJECT] = $gDownloadButton ;1
			Else
				$gDownloadButton = $gFootnoteButtonArray[$I][$EOBJECT]
			EndIf
			CheckParity($gFootnoteButtonArray, $I, $gDownloadButton, "gDownloadButton and $gFootnoteButtonArray sync fail...", true)
		ElseIf(StringCompare($gFootnoteButtonArray[$I][$EBUTTON_KEY], $gEntireImageButtonKey) = 0) then
			if($order = 0) Then
				$gFootnoteButtonArray[$I][$EOBJECT] = $gEntireImageButton
			Else
				$gEntireImageButton = $gFootnoteButtonArray[$I][$EOBJECT]
			EndIf
			CheckParity($gFootnoteButtonArray, $I, $gEntireImageButton, "$gEntireImageButton and $gFootnoteButtonArray sync fail...", true)
		ElseIf(StringCompare($gFootnoteButtonArray[$I][$EBUTTON_KEY], $gNextButtonKey) = 0) then
			if($order = 0) Then
				$gFootnoteButtonArray[$I][$EOBJECT] = $gNextButton
			Else
				$gNextButton = $gFootnoteButtonArray[$I][$EOBJECT]
			EndIf
			CheckParity($gFootnoteButtonArray, $I, $gNextButtonKey, "$gNextButtonKey and $gFootnoteButtonArray sync fail...", true)
		ElseIf(StringCompare($gFootnoteButtonArray[$I][$EBUTTON_KEY], $gPrevButtonKey) = 0) then
			If($order = 0) Then
				$gFootnoteButtonArray[$I][$EOBJECT] = $gPrevButton
			Else
				$gPrevButton = $gFootnoteButtonArray[$I][$EOBJECT]
			EndIf
			CheckParity($gFootnoteButtonArray, $I, $gPrevButtonKey, "$gPrevButtonKey and $gFootnoteButtonArray sync fail...", true)
		Else
			Logger($EINTERNAL, $gFootnoteButtonArray[$I][$EBUTTON_KEY] & " has no handler", true)
		EndIf
	Next
	;Final step --- do this: CheckParity(ByRef array, ByRef globalvar, $msg, $msgbox)
EndFunc   ;==>SyncArrayAndGlobals


Func CalcAndSetCoordsRelativeToDownload()
	;This should only be called after a SetDownloadPosition()
	Logger($ETRACE, "CalcAndSetCoordsRelativeToDownload()", false)
	$ret = WindowResizedOrMoved()
	Logger($EVERBOSE, "WindowResizedOrMoved()=" & $ret & ", $gPositionsValid=" & $gPositionsValid, false)
	;The function only works if the Download button position is correct.
	If($ret = true or $gPositionsValid = false) Then
		return False
	EndIf
	$max = Ubound($gFootnoteButtonArray) - 1
	If $max < 0 Then CleanupExit(5, "$gFootnoteButtonArray has no objects" & @error, true)
	
	CheckParity($gFootnoteButtonArray, 0, $gDownloadButton, "gButtonArray and Coords unsynchronized ... (possible error)", true)
	
	If($gDownloadButton[0] = 0 And $gDownloadButton[1] = 0) Then ;Initial values
		$gDownloadButton[0] = OnOffOrError($gKeyName, $gDownloadButtonRegSz & "X") ;Check registry
		$gDownloadButton[1] = OnOffOrError($gKeyName, $gDownloadButtonRegSz & "Y")
		If($gDownloadButton[0] = -1 Or $gDownloadButton[1] = -1) Then ;If reg not set
			;"Download", 5, ...
			SetCoordinates($gDownloadButtonKey, $gFootnoteButtonArray[0][$ETIMER], $gKeyName, $gDownloadButtonRegSz, $gDownloadButton)
		Endif
	EndIf
	$gBrowserWinPos = WinGetPos($gTaskIdentifier)
	$gBrowserWinSize = WinGetClientSize($gTaskIdentifier)
	FixClientSize($gBrowserWinSize)
	
	for $I = 1 to $max
		if(StringCompare($gFootnoteButtonArray[$I][$EBUTTON_KEY], $gEntireImageButtonKey) = 0) then
			_SetCoords($gEntireImageButton, $gBrowserWinPos[0] + $gBrowserWinSize[0] * .47, $gDownloadButton[1] + 60, $gKeyName, $gEntireImageButtonRegSz)
		ElseIf(StringCompare($gFootnoteButtonArray[$I][$EBUTTON_KEY], $gNextButtonKey) = 0) then
			_SetCoords($gNextButton, $gBrowserWinPos[0] + $gBrowserWinSize[0] - (25 + $WindowMargin[0]), $gDownloadButton[1] - 33, $gKeyName, $gNextButtonRegSz)
		ElseIf(StringCompare($gFootnoteButtonArray[$I][$EBUTTON_KEY], $gPrevButtonKey) = 0) then
			_SetCoords($gPrevButton, $gBrowserWinPos[0] + $gBrowserWinSize[0] - (25 + 15 + $WindowMargin[0]), $gDownloadButton[1] - 33, $gKeyName, $gPrevButtonRegSz)
		Else
			Logger($EINTERNAL, $gFootnoteButtonArray[$I][$EBUTTON_KEY] & " has no handler", true)
		EndIf
	Next
	SyncArrayAndGlobals()
	return True
EndFunc   ;==>CalcAndSetCoordsRelativeToDownload


Func MakeActive($winState = "")
	Logger($ETRACE, "MakeActive()", false)
	
	;BUG: (RESOLVED) If just a download task list is open it will screw up everything because the exe is resident
	;     but no windows are available. This causes the script to go into an indefinite MakeActive()
	;BUG: (RESOLVED) Another issue are processes that don't fully close. These are perceived as valid windows. 
	If Not ProcessExists($gExeName) Then
		return 0
	EndIf

	;WinWaitActive($gTaskIdentifier, "", 5)
	Local $test
	Local $count = 0
	
	;Get the window active
	While($gBrowserWindowId = 0 or $gBrowserWindowId = -1)
		$gBrowserWindowId = WinActivate($gTaskIdentifier)
		Sleep(500)
		$count += 1
		if($count = 20) Then
			;HACK: (500*20 = 10,000ms = 10secs) This is to handle dangling processes and orphaned windows
			Logger($EUSER, "There appears to be a Firefox process open, but it's not responding to messages. Please close the process and reload a new instance.", true)
			return 0
		EndIf
	Wend
	$count = 0
	
	;Now we can set the state and wait for the change to take place
	Do
		$gBrowserWindowId = WinActivate($gTaskIdentifier)
		if($gBrowserWindowId = 0) Then
			return 0
		EndIf
		If $winState <> "" Then
			WinSetState($gTaskIdentifier, "", $winState)
		EndIf
		$test = WinWaitActive($gTaskIdentifier, "", 2)
		$count += 1
		if($count = 5) Then
			;This is to handle dangling processes and orphaned windows
			Logger($EUSER, "There appears to be a Firefox process open, but it's not responding to messages. Please close the process and reload a new instance.", true)
			return 0
		EndIf
		Sleep(50)
	Until($test <> 0)
	WindowResizedOrMoved()
	;$gBrowserWinSize = WinGetClientSize($gTaskIdentifier)
	;$gBrowserWinPos = WinGetPos($gTaskIdentifier)
	return 1
EndFunc   ;==>MakeActive



;grep string for root domain in url bar. If it's footnote.com then everything's fine.
Func ValidFootnotePage()
	;TODO: Two fail states (couldn't make active, not correct page) have two return codes or use @error?
	Logger($ETRACE, "ValidFootnotePage()", false)
	If(Not MakeActive()) Then
		return false
	EndIf
	
	Send("^l^c") ; Open a new tab, and go to the location bar
	Sleep(100)
	$clip = ClipGet() ; Grab the clipboard
	If(StringCompare(StringLower(StringLeft($clip, 30)), "http://www.footnote.com/image/") = 0) Then
		ClipPut("")
		$gPrevURL = $gCurrentURL
		$gCurrentURL = $clip
		RegWrite($gKeyName, $gPrevURLRegSz, "REG_SZ", $gPrevURL)
		RegWrite($gKeyName, $gCurrentURLRegSz, "REG_SZ", $gCurrentURL)
		Logger($EVERBOSE, "$gPrevURL: " & $gPrevURL, false)
		Logger($EVERBOSE, "$gCurrentURL: " & $gCurrentURL, false)
		return True
	EndIf
	return false
EndFunc   ;==>ValidFootnotePage


Func GetArrayValue($keyname, $index)
	Logger($ETRACE, "GetArrayValue(" & $keyname & "," & $index & ")", false)
	$max = Ubound($gFootnoteButtonArray) - 1
	If $max < 0 Then CleanupExit(5, "$gFootnoteButtonArray has no objects" & @error, true)
	
	for $I = 0 to $max
		if(StringCompare($gFootnoteButtonArray[$I][$EBUTTON_KEY], $keyname) = 0) then
			;$subVal = $gFootnoteButtonArray[$I]
			;This is actually an _ERROR!_ I want $gFootnoteButtonArray[$I] but it won't let me :(
			$subMax = Ubound($gFootnoteButtonArray) - 1
			if($index <= $subMax) then
				return $gFootnoteButtonArray[$I][$index]
			else
				SetError(2) ; BAD Index
				return -1
			EndIf
		EndIf
	Next
	SetError(1) ; No such key
	return -1
EndFunc   ;==>GetArrayValue

Func GUIUpdate()
	Logger($ETRACE, "GUIUpdate()", false)
EndFunc   ;==>GUIUpdate

;======================= SETTER FUNCTIONS ========================
;Everything is based off the Download Button Position so long as this is set everything else is probably good
Func GenericSetButtonPosition(ByRef $buttonKey, ByRef $regSz, ByRef $obj, $winState = "", $skipClosingInitializeCheck = false)
	Logger($ETRACE, "GenericSetButtonPosition()", false)
	if($gInitialized = false) then
		GuiCtrlSetState($initializebutton, $GUI_HIDE)
	endif

	If Not ValidFootnotePage() Then InitializePage($winState) ;@SW_MAXIMIZE)
	If(Not WindowResizedOrMoved() and $gPositionsValid = true) Then
		Return
	EndIf
	
	$timer = GetArrayValue($buttonKey, $ETIMER)
	SetCoordinates($buttonKey, $timer, $gKeyName, $regSz, $obj)
	SyncArrayAndGlobals()
	if($gInitialized = false and $skipClosingInitializeCheck = false) then
		GuiCtrlSetState($initializebutton, $GUI_SHOW)
	endif
EndFunc

Func SetDownloadPosition($winState = "")
	Logger($ETRACE, "SetDownloadPosition()", false)
	GenericSetButtonPosition($gDownloadButtonKey, $gDownloadButtonRegSz, $gDownloadButton, $winState, true)
EndFunc   ;==>SetDownloadPosition
	
Func SetNextPosition($winState = "")
	Logger($ETRACE, "SetNextPosition()", false)
	GenericSetButtonPosition($gNextButtonKey, $gNextButtonRegSz, $gNextButton, $winState)
EndFunc   ;==>SetNextPosition


Func SetPrevPosition($winState = "")
	Logger($ETRACE, "SetPrevPosition()", false)
	GenericSetButtonPosition($gPrevButtonKey, $gPrevButtonRegSz, $gPrevButton, $winState)
EndFunc   ;==>SetPrevPosition


Func SetEntireImagePosition($winState = "")
	Logger($ETRACE, "SetEntireImagePosition", false)
	GenericSetButtonPosition($gEntireImageButtonKey, $gEntireImageButtonRegSz, $gEntireImageButton, $winState)
EndFunc   ;==>SetEntireImagePosition
;====================== END SETTER FUNCTIONS ======================

;========================= TOGGLE FUNCS ===========================
Func TogglePause()
	;IMPL
	;MsgBox(48, "Debug", "Pause ... IMPLEMENT")
	Logger($ETRACE, "TogglePause()", false)
	ConsoleWrite("Pause ... Implement")
EndFunc   ;==>TogglePause


;~ Func Stop()
;~ 	;IMPL
;~ 	Logger($ETRACE, "Stop()", false)
;~ EndFunc   ;==>Stop


Func StartResume()
	;TODO: This needs to change to become a resume feature for pause/stop. Init
	;      will only happen through the button for now on. Actually on second thought
	;      if the application crashes it needs to be able to relaunch everything to 
	;      get back to a state where it's running. So I can't block based on $gInitialized = true.
	;	   Also this needs to be pretty smart. It should check to see if the user has 
	;      past information in the registry. So this needs to be sort of the master function
	;      for not only original launch, keeping track of where everything is, and getting
	;      the user out of a bind if things go south. 
	Logger($ETRACE, "StartResume()", false)
	
	;Questions: Best time do a loadoldwindow?
	
	;Are we initialized? (have a window up)
	;	if the program claims so do we have a window up?
	;	is it a valid page? 
	;	is it the page we remember being on?
	;If we are do we have any button data? (in the globals, obj arrays)?
	;Is the button data valid?
	;	if not do we have anything in the registry?
	;	is it valid?
	;	if not lets setdownloadposition()
	;Do we have all the dialogs up that we need to move forward?
	;Is our current page we're already handled?
	
	;Do we have a window up?
	if(LoadFirefoxInstance() = true) Then
		;We didn't, but we should now. Are we initialized? 
		if($gInitialized = true Or $gPositionsValid = true) Then
			;the browser must of crashed or been closed. So lets check to make sure now that we 
			;reloaded our window that everything's correct.
			InitializePage()
			if(WindowResizedOrMoved() = true) Then
				;The new window doesn't match the internal array/globals. Lets try to get 
				;old registry values.
				LoadOldWindowState(true)
			EndIf
		EndIf
			;Try to do a load()
			
			
	Else
		if($gInitialized = true And WindowResizedOrMoved()) Then 
			If(MsgBox(4, "Confirmation Dialog", "Footnote Reaper appears to be initialized. Clicking 'Yes' will reload everything. Continue?") = 7) Then
				return
			EndIf
			$gInitialized = False
			$gPositionsValid = false
		EndIf
	EndIf
	if($gInitialized = false) then
		GuiCtrlSetState($initializebutton, $GUI_HIDE)
		;Previously just Initialize() which defaults to maximizing the screen (decided I don't like that)
		$ret = Initialize(false, "", false)
		If($ret <> false) Then
			VerifyButtons()  ;_Iif($gSaveImageDialogUp = true And $ret <>2, 0, 1)
			$gInitialized = true
		Else
			;BUG: If a person starts the application, does a normal button initialize. Then later clicks 
			;     start. The program will reshow the initialize button. I may just need to include lots of
			;     states. One for the button one for the global init state
			if($gPositionsValid = false) then
				GuiCtrlSetState($initializebutton, $GUI_SHOW)
			endif
		EndIf
	EndIf
	if($gPaused) Then	;or $gStopped?
		;resume
	EndIf
	;Impl main loop this needs to:
	; 	1. Always make sure we have a Process open (in case FF crashes)
	; 	2. Make sure we have a page available
	;	3. Make sure all the buttons are present 
	;	4. Has to be able to try to find a good position to know how to resume from a last good state
EndFunc   ;==>StartResume
;======================== END TOGGLE FUNCS =========================

Global Enum Step +2 $EVERBOSE = 1, $ETRACE, $EASSERT, $EUNHANDLED, $EINTERNAL, $EUSER
Func Logger($code, $msg, $bMsgBox)
	;Overall levels will be:
	; 1. Verbose output
	;
	; 3. Traces
	;
	; 5. Asserts
	;
	; 7. Unhandled exceptions
	;
	; 9. Internal errors
	;
	; 11. User level messages.
	Select
		Case $code = 1
			if $bMsgBox then MsgBox(64, "Verbose", $msg);
			ConsoleWrite("Verbose: " & $msg & @CRLF)
		Case $code = 3
			if $bMsgBox then MsgBox(64, "Trace", $msg & @CRLF);
			ConsoleWrite("Trace: " & $msg & @CRLF)
		Case $code = 5
			if $bMsgBox then MsgBox(64, "Assert", $msg & @CRLF);
			ConsoleWrite("Assert: " & $msg & @CRLF)
		Case $code = 7 ;was 1
			if $bMsgBox then MsgBox(64, "Unhandled Exception", $msg);
			ConsoleWrite("Unhandled Exception: " & $msg & @CRLF)
		Case $code = 9 ;was 5
			if $bMsgBox then MsgBox(48, "Internal Error", $msg);
			ConsoleWrite("Internal Error: " & $msg & @CRLF)
		Case $code = 11
			if $bMsgBox then MsgBox(48, "Notification", $msg);
			ConsoleWrite("Notification: " & $msg & @CRLF)
		Case Else
			if $bMsgBox then MsgBox(64, "Unknown Error Level:", "(Err#:" & $code & "): " & $msg & @CRLF);
			ConsoleWrite("Unknown Error Level: (#" & $code & "): " & $msg & @CRLF)
	EndSelect
EndFunc   ;==>Logger

Global Enum Step +1 $ECLEAN_EXIT = 0, $EPREMATURE_EXIT, $E2_EXIT, $E3_EXIT, $E4_EXIT, $EINTERNALERR_EXIT
Func CleanupExit($code, $msg, $bMsgBox)
	Logger($ETRACE, "CleanupExit()", false)
	;IMPL -- two params? code, message, msgbox and then write location or other details.
	;the code will determine if we exit (i.e. 5)
	;Exit(5)  ;worst error
	;0 is (verbosity just normal clean exit?)
	;1 is (perhaps the user quitting prematurely?)
	;2-4 ... ?
	;5 is internal error
	Select
		Case $code = 0
			if $bMsgBox then MsgBox(48, "Clean Exit", $msg);
			ConsoleWrite("Clean Exit: " & $msg)
		Case $code = 5
			if $bMsgBox then MsgBox(48, "Internal Error", $msg);
			ConsoleWrite("Internal Error Exit: " & $msg)
	EndSelect
	Exit($code)
EndFunc   ;==>CleanupExit


Func VerifyButtons($skip = 1)
	Logger($ETRACE, "VerifyButtons()", false)
	$max = Ubound($gFootnoteButtonArray) - 1
	;For $item in $gFootnoteButtonArray
	for $I = $skip to $max
		;[["Download", $gDownloadButton, 10, $gDownloadButtonRegSz],
		$buttonName = $gFootnoteButtonArray[$I][$EBUTTON_KEY]
		$object = $gFootnoteButtonArray[$I][$EOBJECT]
		$timer = $gFootnoteButtonArray[$I][$ETIMER]
		$regSz = $gFootnoteButtonArray[$I][$EREGSZ]
		
		MouseMove($object[0], $object[1])
		
		if(MsgBox(4, "Checking Location...", "Is the mouse pointer over the '" & $buttonName & "' button?") = 7) Then
			SetCoordinates($buttonName, $timer, $gKeyName, $regSz, $gFootnoteButtonArray[$I][$EOBJECT])
		EndIf
	Next
	SyncArrayAndGlobals(1) ; we are storing the values in the array so need to set globals
EndFunc   ;==>VerifyButtons


Func InitializePage($winState = "")
;returns 0 if the page fails to init, 1 if we create a new page, 2 if a page is already open.
	Logger($ETRACE, "InitializePage()", false)
	If ValidFootnotePage() Then 
		Local $ret = MsgBox(4, "Checking State...", "Is the 'Save Image' dialog containing the 'Entire Image' and 'Select Portion of Image' visible?")
		$gSaveImageDialogUp = _Iif($ret == 6, True, False)
		return 2
	EndIf
	if(MakeActive($winState) <> 0 and $gBrowserWinSize[0] > 0 and $gBrowserWinSize[1] > 0) Then		
		Send("^t^l") ; Open a new tab, and go to the location bar
		;TODO: This should be based on the current position
		Send($gCurrentURL & "{ENTER}") ; In the URL bar go to some start URL
		Sleep(5 * 1000) ; Wait 5 seconds for everything to load
		MouseClick("left", $gBrowserWinPos[0] + ($gBrowserWinSize[0] / 2), $gBrowserWinPos[1] + ($gBrowserWinSize[1] * 0.3))
		;send a click to change focus so it doesn't keep the hand icon from grabbing the footnote document causing it to scroll.
		Send("^")
		$gSaveImageDialogUp = false
		return 1
	EndIf
	return 0
EndFunc   ;==>InitializePage


Func LoadFirefoxInstance()
	If ProcessExists($gExeName) Then return False
	
	;HKEY_LOCAL_MACHINE\SOFTWARE\Clients\StartMenuInternet\FIREFOX.EXE\shell\open\command
	$gProgramPath = OnOffOrError("HKEY_LOCAL_MACHINE\SOFTWARE\Clients\StartMenuInternet\FIREFOX.EXE\shell\open\command", "")
	If $gProgramPath = -1 Or $gProgramPath = "" Then
		$gProgramPath = OnOffOrError($gKeyName, $gProgramPathSz)
	Else
		$temp = OnOffOrError($gKeyName, $gProgramPathSz)
		If($temp = -1 Or $temp = "") Then
			RegWrite($gKeyName, $gProgramPathSz, "REG_SZ", $gProgramPath)
		EndIf
	EndIf
	If $gProgramPath = -1 Or $gProgramPath = "" Then
		$gProgramPath = FileInstalledWhere("Please specify where you installed " & $gProgramName, "Program (" & $gExeName & ")", $gExeName)
		$gProgramPath = $gProgramPath & "\" & $gExeName
		RegWrite($gKeyName, $gProgramPathSz, "REG_SZ", $gProgramPath)
	EndIf
	
	;MsgBox(48, "Debug", FileGetShortName($gProgramPath)) ;& "\" & $gExeName)
	$ret = Run(FileGetShortName($gProgramPath))
	;$ret = Run(@ComSpec & " /c " & FileGetShortName($gProgramPath), "", @SW_MINIMIZE); & "\" & $gExeName, "", @SW_MINIMIZE)
	;If $ret <> 0 Then ;AND NOT @Error
	;WinActivate($gTaskIdentifier)
	;WinWaitActive($gTaskIdentifier, 5)
	If $ret = 0 Then
		Logger($EINTERNAL, "(ERR# " & $ret & ") Found executable '" & $gProgramPath & "' but failed to run.", true)
	EndIf
	return true
EndFunc

;This makes sure the browser, footnote.com and footnotereaper are all in a useable state
Func Initialize( _
	$skipSetDownloadPosition = false, _
	$winState = @SW_MAXIMIZE, _
	$winMove = true _
 )
;Return 0 = error, 1 success, 2 success (set downloadposition)
	Logger($ETRACE, "Initialize()", false)
	
	LoadFirefoxInstance()
	;TODO: Ensure the user is actually signed in...
	$ret = InitializePage($winState)
	If($ret <> false) Then
		if($winMove = true) then
			WinMove($gTaskIdentifier, "", 0, 0) ; @DesktopWidth, @DesktopHeight)
		endif
		if(Not $skipSetDownloadPosition) then
			Local $blogin = false
			if($ret <> 2) then
				$blogin = MsgBox(1, "Confirm Login", "Before continuing login to footnote.com") <> 2
			endif
			;Logger($ETRACE, "$blogin: " & $blogin & "  $ret: "& $ret, false)
			If($blogin Or $ret = 2) Then
				SetDownloadPosition($winState)
				return 2
			Else
				return 0
			EndIf
		endif
	Else
		return 0
	EndIf
	return 1
EndFunc   ;==>Initialize


Func MasterInitialize()
	;TODO: This function needs to be setup as basically a $firstEntry. Meaning I'd like to have the window
	;      by default in the 0,0 position so I can have the log output on the right. 
	Logger($ETRACE, "MasterInitialize()", false)
	GuiCtrlSetState($initializebutton, $GUI_HIDE)
	;Previously just Initialize() which defaults to maximizing the screen (decided I don't like that)
	$ret = Initialize(false, "", true)
	If($ret <> false) Then
		VerifyButtons()  ;_Iif($gSaveImageDialogUp = true And $ret <>2, 0, 1)
		$gInitialized = true
	Else
		;BUG: If a person starts the application, does a normal button initialize. Then later clicks 
		;     start. The program will reshow the initialize button. I may just need to include lots of
		;     states. One for the button one for the global init state
		if($gPositionsValid = false) then
			GuiCtrlSetState($initializebutton, $GUI_SHOW)
		endif
	EndIf
EndFunc   ;==>MasterInitialize

	

Func StateMachine()
EndFunc


Func HackFixResize()
	;Hack: Trying to fix issue where flash doesn't refresh properly after resize if there
	;	   isn't enough of a delay. This provides a delay, but on a small interval
	Dim $winPos = WinGetPos($gTaskIdentifier)
	Dim $winSize = WinGetClientSize($gTaskIdentifier)
	FixClientSize($winSize)
	WinMove($gTaskIdentifier, "", $winPos[0], $winPos[1], $winSize[0]-5, $winSize[1]-5, 50)
EndFunc


Func TwosComplementToSignedInt(ByRef $coords)
	Local $modified = False
	if(Not IsArray($coords)) Then Return false
	
	$power = _Iif(StringCompare(@CPUArch, "X86"), 32, 64)
	Logger($EVERBOSE, "power: " & $power & @CRLF, false)
	
	For $I = 0 To UBound($coords)-1
		if(BitAND($coords[$I], 0xFFFF0000) = true) Then
			Logger($EVERBOSE, "$coords[" & $I &"]: " & $coords[$I], false)
			;NOTE: this is platform specific (i.e. 64-bit versus 32-bit vars)
			$coords[$I] = -(2^$power - $coords[$I]) ;0xFFFFFFFF - $coords[0]
			Logger($EVERBOSE, "$coords[" & $I &"]: " & $coords[$I], false)
			$modified = true
		EndIf
	Next
	return $modified
EndFunc


Func LoadOldWindowState($bForceLoad = false)
	Logger($ETRACE, "LoadOldWindowState()", false)
	
	Local $successfulLoads = 0
	Dim $dlButtonXY[2] = [0, 0]
	Local $buttonXY[2] = [0, 0]
	
	Local $max = Ubound($gFootnoteButtonArray) - 1
	If $max < 0 Then CleanupExit(5, "$gFootnoteButtonArray has no objects" & @error, true)
	
	;First get our the new window values.
	if($bForceLoad = false And ((WindowResizedOrMoved() = false and $gInitialized = true) or $gPositionsValid = true)) Then
		; WindowResizedOrMoved & $gInitialized
		; true true -> true: a person may want to fetch data from reg because they already initialized with different window layout and new window layout mimics registry
		; true false -> true: If we're not initialized the window resize is pretty irrelevant we want to perform the operation
		; (false true -> false: (SPECIAL CASE) If we're initialized and nothing's changed with the window this is pretty suspect.
		; false false -> true: If we're not initialized irregardless of no window change we want to move ahead.
		If(MsgBox(4, "Confirmation Dialog", "Footnote Reaper appears to be initialized. Clicking 'Yes' will load information from the registry which may be out of date. Continue?") = 7) Then
			return false
		EndIf
	EndIf
	
	Dim $oldBrowserWinpos[2] = [-1, -1]
	Dim $oldBrowserWinsize[2] = [-1, -1]
	$oldPositionsValid = False
	
	$gInitialized = false ;unless we get to the end the function things have been modified that can ruin proper init.
	$gPositionsValid = false ;...
	
	;This has to be before initialize so we have the write page to load.
	Local $currentURL = OnOffOrError($gKeyName, $gCurrentURLRegSz)
	Local $prevURL = OnOffOrError($gKeyName, $gPrevURLRegSz)
	if($currentURL <> -1) Then $gCurrentURL = $currentURL 
	if($prevURL <> -1) then $gPrevURL = $prevURL
	
	if($gInitialized = false) Then
		if(Not Initialize(true, "", false)) then
			return false
		EndIf
	EndIf
	
	$oldPositionsValid = OnOffOrError($gKeyName, "gPositionsValid")
	
	;No reason to continue if we know it's already invalid
	if($oldPositionsValid = false) Then
		;This should only happen when a window is resized and a person does a manual save.
		;Even in this scenario I should be querying the person to try to prevent this state
		Logger($EASSERT, "$oldPositionsValid = false", true)
		return false
	EndIf
	
	$oldBrowserWinpos[0] = OnOffOrError($gKeyName, "gWinPosX")
	$oldBrowserWinpos[1] = OnOffOrError($gKeyName, "gWinPosY")
	$oldBrowserWinsize[0] = OnOffOrError($gKeyName, "gWinSizeX")
	$oldBrowserWinsize[1] = OnOffOrError($gKeyName, "gWinSizeY")
	
	;When can this type of thing happen? Basically only if a user quits the program
	;mid-execution. Because all regwrites have a WindowResizedOrMoved() before them
	;Basically if this is the case we should just bail. The data's likely garbage.
	If( $oldBrowserWinpos[0] = -1 Or _
		$oldBrowserWinpos[1] = -1 Or _
		$oldBrowserWinsize[0] = -1 Or _
		$oldBrowserWinsize[1] = -1) Then
			;$regMissingPosOrSize = True
			Logger($EUSER, "No previous sessions has been saved.", true)
			return false
	EndIf

	TwosComplementToSignedInt($oldBrowserWinpos)
	
	;Do we need to reposition the window to get all the old data to work?
	if((($oldBrowserWinpos[0] <> $gBrowserWinPos[0]) or($oldBrowserWinpos[1] <> $gBrowserWinPos[1])) Or _
			(($oldBrowserWinsize[0] <> $gBrowserWinSize[0]) or($gBrowserWinSize[1] < $oldBrowserWinsize[1] and $gBrowserWinSize[1] <= 400))) Then
		Logger($EVERBOSE, $oldBrowserWinpos[0] & " " & $gBrowserWinPos[0] & ", " & $oldBrowserWinpos[1] & " " & $gBrowserWinPos[1] & ", " & $oldBrowserWinsize[0] & " " & $gBrowserWinSize[0] & ", " & $oldBrowserWinsize[1] & " " & $gBrowserWinSize[1], false)
		If(MsgBox(4, "Confirmation Dialog", "The window has been moved or resized. Reset window? Answering 'No' will cancel the load.") = 7) Then
			return False
		Else
			HackFixResize()
			if(WinMove($gTaskIdentifier, "", $oldBrowserWinpos[0], $oldBrowserWinpos[1], $oldBrowserWinsize[0], $oldBrowserWinsize[1]) = 0) Then
				Logger($EINTERNAL, "Failed to move and resize window. Aborting. Try loading again or reinitialize the program.", true)
				return false
			EndIf
			
			$gBrowserWinPos = $oldBrowserWinpos
			$gBrowserWinSize = $oldBrowserWinsize
		EndIf
	EndIf
	

	
	if(IsArray($gFootnoteButtonArray[0][$EOBJECT])) Then
		$dlButtonXY[0] = OnOffOrError($gKeyName, $gDownloadButtonRegSz & "X") ;Check registry
		$dlButtonXY[1] = OnOffOrError($gKeyName, $gDownloadButtonRegSz & "Y")
		$gFootnoteButtonArray[0][$EOBJECT] = $dlButtonXY
	Else
		Logger($EINTERNAL, "Failed to grab $gDownloadButton object from internal array", true)
		return False
	EndIf

	;If $gDownloadButton returns -1 that probably means nothing's valid. Should we force user
	;to init? No. Instead I'll load what I can and just inform the user at the end that the
	;load was only partly successful. We'll base this off $gPositionsvalid
	If($dlButtonXY[0] = -1 Or $dlButtonXY[1] = -1) Then
		$gFootnoteButtonArray[0][$EOBJECT] = $buttonXY ;set it to the original defaults.
	Else
		$successfulLoads += 1
		$gPositionsValid = true
	Endif

	$successfulLoads = LoadRegButtons()

	SyncArrayAndGlobals(1) ;arrays -> globals
	;CheckParity($gFootnoteButtonArray, 0, $gDownloadButton, "gButtonArray and Coords unsynchronized ... (possible error)", true)
	if($gPositionsValid = true And($successfulLoads - 1) = $max) Then
		$gInitialized = True
		Logger($EUSER, "Load successful", true)
	Else
		Logger($EUSER, "Not all data was loaded successfully. Please click 'Edit -> Verify Buttons'", true)
		Logger($EVERBOSE, $max & " " & $successfulLoads & " " & $gPositionsValid, false)
	EndIf
	
	if($gInitialized = false) then
		GuiCtrlSetState($initializebutton, $GUI_SHOW)
	else
		GuiCtrlSetState($initializebutton, $GUI_HIDE)
	endif
	return $gInitialized
EndFunc   ;==>WindowState


Func SaveWindowState()
	Logger($ETRACE, "SaveWindowState()", false)
	;impl
EndFunc   ;==>SaveWindowState


Func StoreByRef(ByRef $src, ByRef $dest)
	Logger($ETRACE, "StoreByRef()", false)
	$dest = $src
EndFunc   ;==>StoreByRef





Dim $answer = 0
Global $gNT = 1
Global $gOffset = 172
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
Global $param1 ;For functions that are called dynamically

;----Establish all app states here----
Global $firstEntry = 0
Global $gInitialized = false		;Used primarily to handle graphical "init" button. This somewhat mimics $gPositionsValid
Global $gPositionsValid = false		;Are all Firefox footnote.com buttons configured properly? More specifically is $gDownloadPosition correct? 
Global $gSaveImageDialogUp = false
Global $gPaused = false
;-------------------------------------

Global $gInitialURL = "http://www.footnote.com/image/{#}1|7276022"
Global $gPrevURL = ""
Global $gPrevURLRegSz = "gPrevURL"
Global $gCurrentURL = $gInitialURL
Global $gCurrentURLRegSz = "gCurrentURL"

;---------footnote button data---------
Global $gEntireImageButtonKey = "Entire Image"
Global $gEntireImageButtonRegSz = "gEntireImage"
Global $gEntireImageButton[2] = [0, 0]

Global $gNextButtonKey = "Next Image"
Global $gNextButtonRegSz = "gNextButton"
Global $gNextButton[2] = [0, 0]

Global $gPrevButtonKey = "Previous Image"
Global $gPrevButtonRegSz = "gPrevButton"
Global $gPrevButton[2] = [0, 0]

Global $gDownloadButtonKey = "Download"
Global $gDownloadButtonRegSz = "gDownloadButton"
Global $gDownloadButton[2] = [0, 0]

Dim $gButtonDictionary[4] = [$gDownloadButtonKey, $gNextButtonKey, $gPrevButtonKey, $gEntireImageButtonKey]

Global Enum Step +1 $EBUTTON_KEY = 0, $EOBJECT, $ETIMER, $EREGSZ
;                    				  Button Name,           Object,        , Timer,    RegSz
Dim $gFootnoteButtonArray[4][4] = [[$gButtonDictionary[0], $gDownloadButton, 5, $gDownloadButtonRegSz], _
		[$gButtonDictionary[1], $gNextButton, 5, $gNextButtonRegSz], _
		[$gButtonDictionary[2], $gPrevButton, 5, $gPrevButtonRegSz], _
		[$gButtonDictionary[3], $gEntireImageButton, 5, $gEntireImageButtonRegSz]]
;--------End footnote button data------


;--------Firefox details--------------
Global $gProgramName = "Firefox"
Global $gExeName = "firefox.exe"
Global $gTaskIdentifier = "Firefox"
Global $gBrowserWindowId = -1

Global $gProgramPathSz = "gProgramPath"
Global $gProgramPath = ""

Dim $gWinPos[2]  = [0, 0]
Dim $gWinSize[2] = [0, 0]
Dim $gGuiItem[4][4]

Dim $gBrowserWinPos[2] = [0, 0]
Dim $gBrowserWinSize[2] = [0, 0]
;----End Firefox details-------------


#requireadmin
Opt("WinTitleMatchMode", 2)
;Opt("GUIOnEventMode", 1)

If StringRight($gCWD, 1) = "\" OR StringRight($gCWD, 1) = "/" Then
	$gCWD = StringTrimRight($gCWD, 1)
EndIf

If @OSVersion = "WIN_ME" OR @OSVersion = "WIN_98" OR @OSVersion = "WIN_95" Then
	$gNT = 0
	$gOffset = 0;180
EndIf

If $gNT = 1 Then
	GuiCreate("FootnoteReap", 160, 140, -1, -1, $WS_SIZEBOX) ;10, 10, $WS_SIZEBOX -- height 200 old
Else
	GuiCreate("FootnoteReap", 180, 140) ;height 200
EndIf

HotKeySet("{F10}", "StartResume")
HotKeySet("{F11}", "TogglePause")
;~ HotKeySet("{ESC}", "Stop")

;GuiSetIcon($gCWD & "\a8950027.ico", 0)
GUISetBkColor(0xffffff)

$commands = GuiCtrlCreateMenu("&Commands")
$fileitem = GuiCtrlCreateMenu("&File", $commands)
$saveitem = GuiCtrlCreateMenuItem("&Save", $fileitem)
$loaditem = GuiCtrlCreateMenuItem("&Load", $fileitem)

$dashitem = GuiCtrlCreateMenuItem("", $commands)
SetOwnerDrawn($commands, $dashitem, "")

$startitem = GuiCtrlCreateMenuItem("&Start", $commands)
$pauseitem = GuiCtrlCreateMenuItem("&Pause", $commands)
;$stopitem = GuiCtrlCreateMenuItem("S&top", $commands)
$exititem = GuiCtrlCreateMenuItem("&Exit", $commands)

$edit = GuiCtrlCreateMenu("&Edit")
;$resetitem = GuiCtrlCreateMenuItem("&Undo Changes", $edit)
;$output = GuiCtrlCreateMenu ("&Output", $edit)
;$verboseitem = GuiCtrlCreateMenuItem("&Verbose", $output)
;$quietitem = GuiCtrlCreateMenuItem("&Quiet", $output)
$registrationitem = GuiCtrlCreateMenuItem("Registry &Keys", $edit)
$setitem = GuiCtrlCreateMenu("&Set Buttons", $edit)
$downloaditem = GuiCtrlCreateMenuItem("&Download coords", $setitem)
$nextitem = GuiCtrlCreateMenuItem("&Next coords", $setitem)
$previtem = GuiCtrlCreateMenuItem("&Prev coords", $setitem)
$entireimageitem = GuiCtrlCreateMenuItem("'&Entire Image' coords", $setitem)
;I can calculate the "Entire Image" button by finding the window width div 2 - subtract fixed amount relative to download button
;Ditto for "next coords" -- browser width download button + y
;TODO: Perhaps have an override though? May be worthwhile to just save these values in the registry. However I will need to
;      create a $msg item to check for resizes. This will change everything. Actually I should just save the size too.
$checkitem = GuiCtrlCreateMenu("&Check Buttons", $edit)
$checkdownloaditem = GuiCtrlCreateMenuItem("&Download coords", $checkitem)
$checknextitem = GuiCtrlCreateMenuItem("&Next coords", $checkitem)
$checkprevitem = GuiCtrlCreateMenuItem("&Prev coords", $checkitem)
$checkentireimageitem = GuiCtrlCreateMenuItem("'&Entire Image' coords", $checkitem)

$verifybuttons = GuiCtrlCreateMenuItem("&Verify Buttons", $edit)
;$winmove = GuiCtrlCreateMenuItem("&Winmove test", $edit)

$help = GuiCtrlCreateMenu("&Help")
$readmeitem = GuiCtrlCreateMenuItem("View &Readme", $help)
$aboutitem = GuiCtrlCreateMenuItem("&About", $help)

WindowResizedOrMoved()
$initializebutton = GUICtrlCreateButton("Initialize", 20, 20, 120)
$startresumebutton = GUICtrlCreateButton("Start/Resume", 20, 20, 120)
GuiCtrlSetState($startresumebutton, $GUI_HIDE)
;WinSetOnTop(GUICreate("Status Window",500,30,500,1), '', 1)

ConsoleWrite("Initialized GUI and global ..." & @CRLF)

GuiSetState()
;Dim $gBrowserWinPos = WinGetPos("FootnoteReap", "Steps Completed")
do
	$msg = GuiGetMsg()
	Select
		Case $msg = $GUI_EVENT_CLOSE Or $msg = $exititem
			ExitLoop

		;Case $msg = $winmove
		;	Local $poss = WinGetPos($gTaskIdentifier)
		;	Local $tempSizee = WinGetClientSize($gTaskIdentifier)
		;	FixClientSize($tempSizee)
		;	WinMove($gTaskIdentifier, "", $poss[0]-30, $poss[1], $tempSizee[0], $tempSizee[1]) 
		;	ConsoleWrite($tempSizee[0] & "   " & $tempSizee[1] & @CRLF)
			

		;TODO: I need to make this smarter. On closing down and restarting the app it should check
		;      the registry to see if there's anything there. If there is it's better to say:
		;      "Load Old State"
		;      The commands menu should have: 
		;			1. Initialize (perhaps edit the label to 'reinitialize' once $gInitialize is set?)
		Case $msg = $initializebutton
			MasterInitialize()
			
		Case $msg = $startitem
			StartResume()
			;GUICtrlDelete($initializebutton)

			;Impl get Download location part...
			;$list = WinList()
			;for $i = 1 to $list[0][0]
			;  msgbox(0, $list[$i][1], $list[$i][0])
			;next
			
		Case $msg = $loaditem
			LoadOldWindowState()
			
		Case $msg = $saveitem
			SaveWindowState()
			
		Case $msg = $registrationitem
			If $gNT = 1 Then RegWrite("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Applets\Regedit\Favorites", "FoonoteReaper", "REG_SZ", "Computer\HKEY_CURRENT_USER\SOFTWARE\FoonoteReaper")
			Run("regedit.exe")
			WinWaitActive("Registry Editor")
			If $gNT = 1 Then Send("!af{ENTER}{F5}")
			RegDelete("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Applets\Regedit\Favorites", "FoonoteReaper")
			
			;==================== Set Button ==========================
		Case $msg = $downloaditem
			If Not MakeActive() Then ContinueLoop
			$gPositionsValid = false
			SetDownloadPosition()
			
		Case $msg = $nextitem
			If Not MakeActive() Then ContinueLoop
			$gPositionsValid = false
			SetNextPosition()
			;Todo: verify is a way to ensure all buttons are set create another function to check non-0'ness as check?
			
		Case $msg = $previtem
			If Not MakeActive() Then ContinueLoop
			$gPositionsValid = false
			SetPrevPosition()
			
		Case $msg = $entireimageitem
			If Not MakeActive() Then ContinueLoop
			$gPositionsValid = false
			SetEntireImagePosition()
			;================= End Set Buttons ========================
			
			;====================== Check Buttons =====================
		Case $msg = $checkdownloaditem
			;Perhaps record a state to remember whether a person manually set a position versus one autoconfigured?
			MouseMove($gDownloadButton[0], $gDownloadButton[1])
			
		Case $msg = $checknextitem
			MouseMove($gNextButton[0], $gNextButton[1])
			
		Case $msg = $checkprevitem
			MouseMove($gPrevButton[0], $gPrevButton[1])
			
		Case $msg = $checkentireimageitem
			MouseMove($gEntireImageButton[0], $gEntireImageButton[1])
			
		Case $msg = $verifybuttons
			If Not MakeActive() Then ContinueLoop
			VerifyButtons(0)
			;=================== End Check Buttons ======================
			
			
			;================  ABOUT DIALOGUE CASES =================
		Case $msg = $aboutitem
			If WinExists("The FootNote Reaper") Then ContinueLoop
			If $gNT <> 1 Then
				$width = 242
			Else
				$width = 220
			EndIf
			$height = 110
			Dim $pos = WinGetPos("FootnoteReap")
			Dim $tempSize = WinGetClientSize("FootnoteReap")
			$tempSize[0] += 12
			$gWindow = GUICreate("The FootNote Reaper", "112", $height, $pos[0] + $tempSize[0], $pos[1], $WS_POPUPWINDOW) ;280x160
			$label1 = GuiCtrlCreateLabel("The Footnote Reaper", (8 * ($width / 2)) / 100, 3, 100)
			GUICtrlSetFont($label1, 14, 800, 4, "Times New Roman")
			GUICtrlSetColor($label1, 0xff0000)
			$spacer = 20
			$lab2h = 36
			$label2 = GuiCtrlCreateLabel("Created By:  Xtraeme", 5, $lab2h)
			$lab3h = $lab2h + $spacer
			$label3 = GuiCtrlCreateLabel("Contact:", 5, $lab3h)
			$lab4h = $lab3h + $spacer
			$label4 = GuiCtrlCreateLabel("Website:", 5, $lab4h)

			;GUICtrlSetColor($label, 0xff0000)
			;GUICtrlSetFont($label2, 9, 400, 4)
			GUISetState(@SW_SHOW, $gWindow)
			$max = $width - 112
			For $counter = 0 to $max
				WinMove("The FootNote Reaper", "", $pos[0] + $tempSize[0], $pos[1], 112 + $counter, $height)
			Next

			Global $label5 = GuiCtrlCreateLabel("xthaus@yahoo.com", 70, $lab3h - 2, $SS_NOTIFY)
			GUICTRLSetFont($label5, 9, 400, 4)
			GUICtrlSetColor($label5, 0x0000ff)
			Global $label6 = GuiCtrlCreateLabel("http://wiki.razing.net", 70, $lab4h - 2, $SS_NOTIFY)
			GUICTRLSetFont($label6, 9, 400, 4)
			GUICtrlSetColor($label6, 0x0000ff)

			$gButton = GUICtrlCreateButton("i", $width - 15, 5, 12, 12, BitOr($BS_BITMAP, $BS_DEFPUSHBUTTON))
			GuiCtrlSetImage($gButton, $gCWD & "\left.bmp")
			;GUISetState(@SW_SHOW, $gButton)
			;Msgbox(0,"The Ultimate Collection","Created by Xtraeme." & @LF & "Contact: xthaus@yahoo.com" & @LF & "Website: http://wiki.razing.net")
			

		Case $msg = $label6
			If WinExists("The FootNote Reaper") Then
				If FileExists(@ProgramFilesDir & "\Internet Explorer\iexplore.exe") Then
					;Run(@ProgramFilesDir & "\Internet Explorer\iexplore.exe http://wiki.razing.net")
					_RunDOS("start http://wiki.razing.net")
				EndIf
			EndIf
			
		Case $msg = $label5
			_INetMail("xthaus@yahoo.com", "[FootnoteReaper] ", "Please leave the [FootnoteReaper] in the Subject so my mail filter can sort by it, thanks!")

		Case $msg = $gButton
			If WinExists("The FootNote Reaper") Then
				$width = 220
				$height = 110
				$pos = WinGetPos("FootnoteReap")
				$tempSize = WinGetClientSize("FootnoteReap")
				$tempSize[0] += 12
				GUICtrlDelete($gButton)
				GUICtrlDelete($label5)
				GUICtrlDelete($label6)
				For $counter = $width to 112 step -1
					WinMove("The FootNote Reaper", "", $pos[0] + $tempSize[0], $pos[1], $counter, $height)
				Next
				GUIDelete($gWindow)
			EndIf

		Case $msg = $GUI_EVENT_PRIMARYUP
			;GUIGetState($window,
			;If $gVerbosity = 1 Then MsgBox(0, "Clicked", "Clucked")
			$tempPos = WinGetPos("FootnoteReap")
			$tempSize = WinGetClientSize("FootnoteReap")
			$tempSize[0] += 12
			if IsArray($tempPos) AND $tempPos[0] <> $gWinPos[0] AND $tempPos[1] <> $gWinPos[1] Then
				If WinExists("The FootNote Reaper") Then WinMove("The FootNote Reaper", "", $tempPos[0] + $tempSize[0], $tempPos[1])
				$gWinPos[0] = $tempPos[0]
				$gWinPos[1] = $tempPos[1]
				$gWinSize[0] = $tempSize[0]
				$gOffset = $tempSize[0]
				$gWinSize[1] = $tempSize[1]
			EndIf

		;XTRAEME: Undo the commented block at some point ...
		;Case $msg = $GUI_EVENT_MOUSEMOVE
			;ConsoleWrite("moved ..")
			;$tempPos = WinGetPos("FootnoteReap")
			;$tempSize = WinGetClientSize("FootnoteReap")
			;$tempSize[0] += 12
			;if IsArray($tempPos) AND $tempPos[0] <> $gWinPos[0] AND $tempPos[1] <> $gWinPos[1] Then
			;	If WinExists("The FootNote Reaper") Then WinMove("The FootNote Reaper", "", $tempPos[0] + $tempSize[0], $tempPos[1])
			;	$gWinPos[0] = $tempPos[0]
			;	$gWinPos[1] = $tempPos[1]
			;	$gWinSize[0] = $tempSize[0]
			;	$gOffset = $tempSize[0]
			;	$gWinSize[1] = $tempSize[1]
			;EndIf
			
		case $msg = $GUI_EVENT_RESIZED
			;ConsoleWrite("resized ..")
			$tempPos = WinGetPos("FootnoteReap")
			$tempSize = WinGetClientSize("FootnoteReap")
			if IsArray($tempPos) AND($tempPos[0] <> $gWinPos[0] OR $tempPos[1] <> $gWinPos[1] OR $tempSize[0] <> $gWinSize[0] OR $tempSize[1] <> $gWinSize[1]) Then
				;ConsoleWrite("resized ..")
				If WinExists("The FootNote Reaper") Then WinMove("The FootNote Reaper", "", $tempPos[0] + $tempSize[0] + 12, $tempPos[1])
				$gWinPos[0] = $tempPos[0]
				$gWinPos[1] = $tempPos[1]
				$gWinSize[0] = $tempSize[0] + 12
				$gOffset = $tempSize[0]
				$gWinSize[1] = $tempSize[1]
			EndIf

			;===============  END ABOUT DIALOGUE CASES ==============
	EndSelect

Until $msg = $GUI_EVENT_CLOSE OR $msg = $exititem

CleanupExit($ECLEAN_EXIT, "Shutting down...", false)