 ;FootNote Reaper
; AutoIt Version: 3.0
; Language:       English
; Platform:       Win9x/NT
; Description:    A tool to download content off footnote.com
; Author:         Dustin Darcy (ddarcy@digipen.edu)
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

;for about
#include <StaticConstants.au3>
#include <ButtonConstants.au3>


Global Const $MF_BYCOMMAND			= 0x00000000
;Global Const $MF_OWNERDRAW			= 0x00000100

;================= Window Routines ====================

Func ModifyMenu($hMenu, $nID, $nFlags, $nNewID, $ptrItemData)
	Local $bResult = DllCall('user32.dll', 'int', 'ModifyMenu', _
												'hwnd', $hMenu, _
												'int', $nID, _
												'int', $nFlags, _
												'int', $nNewID, _
												'ptr', $ptrItemData)
	Return $bResult[0]
EndFunc

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
EndFunc
		
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


Func SetCoordinates($buttonName, $timer, $baseKey, $keyname, ByRef $coords)
	Logger($ETRACE, "SetCoordinates(" & $buttonName & "," & $timer & "," & $baseKey & "," & $keyName & "," & "coords)", false)
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
	WindowResizedOrMoved(true)
	RegWrite($baseKey, $keyname & "X", "REG_DWORD", $coords[0])
	RegWrite($baseKey, $keyname & "Y", "REG_DWORD", $coords[1])
	return true
EndFunc   ;==>SetCoordinates


Func WindowResizedOrMoved($regwrite = false) ;$x = $, $y, $width, $height)
	Logger($ETRACE, "WindowResizedOrMoved()", false)
	$changed = false
	$winPos = WinGetPos($gTaskIdentifier)
	$winSize = WinGetClientSize($gTaskIdentifier)
	
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
		if($regwrite = true) then
			RegWrite($gKeyName, "gWinPosX", "REG_DWORD", $gBrowserWinPos[0])
			RegWrite($gKeyName, "gWinPosY", "REG_DWORD", $gBrowserWinPos[1])
			RegWrite($gKeyName, "gWinSizeX", "REG_DWORD", $gBrowserWinSize[0])
			RegWrite($gKeyName, "gWinSizeY", "REG_DWORD", $gBrowserWinSize[1])
			RegWrite($gKeyName, "gPositionsValid", "REG_DWORD", $gPositionsValid)
		endif
		return true
	EndIf
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


Func CheckParity(ByRef $array, $indice, ByRef $globalvar, $msg, $msgbox)
	Logger($ETRACE, "CheckParity()", false)
	;Only works with arrays of [2] and coords
	If Not(IsArray($array)) Then return 1
	
	Local $subarray = $array[$indice][1]
	
	If Not(IsArray($subarray) or IsArray($globalvar)) Then return 1
	If Not(UBound($subarray) >= 2 and UBound($globalvar) >= 2) Then return 2
	
	If($subarray[0] <> $globalvar[0] Or($subarray[1] <> $globalvar[1])) Then
		Logger($ETRACE, "gButtonArray and Coords unsynchronized ... (possible error)", true)
		$array[$indice][1] = $globalvar ;let the global have precedence over the buttonarray ...
		CheckParity($array, $indice, $globalvar, $msg, $msgbox)
	EndIf
	return 0
EndFunc   ;==>CheckParity


;Order = 0 means assign global to array
;Order = 1 means assign array to globals
Func SyncArrayAndGlobals($order = 0)
	Logger($ETRACE, "SyncArrayAndGlobals()", false)
	$max = Ubound($gButtonArray) - 1
	If $max < 0 Then CleanupExit(5, "$gButtonArray has no objects" & @error, true)
	
	for $I = 0 to $max
		if(StringCompare($gButtonArray[$I][$EBUTTON_KEY], $gDownloadButtonKey) = 0) then
			if($order = 0) then
				$gButtonArray[$I][$EOBJECT] = $gDownloadButton  ;1
			Else
				$gDownloadButton = $gButtonArray[$I][$EOBJECT]
			EndIf
			CheckParity($gButtonArray, $I, $gDownloadButton, "gDownloadButton and $gButtonArray sync fail...", true)
		ElseIf(StringCompare($gButtonArray[$I][$EBUTTON_KEY], $gEntireImageButtonKey) = 0) then
			if($order = 0) Then
				$gButtonArray[$I][$EOBJECT] = $gEntireImageButton
			Else
				$gEntireImageButton = $gButtonArray[$I][$EOBJECT]
			EndIf
			CheckParity($gButtonArray, $I, $gEntireImageButton, "$gEntireImageButton and $gButtonArray sync fail...", true)
		ElseIf(StringCompare($gButtonArray[$I][$EBUTTON_KEY], $gNextButtonKey) = 0) then
			if($order = 0) Then
				$gButtonArray[$I][$EOBJECT] = $gNextButton
			Else
				$gNextButton = $gButtonArray[$I][$EOBJECT]
			EndIf
			CheckParity($gButtonArray, $I, $gNextButtonKey, "$gNextButtonKey and $gButtonArray sync fail...", true)
		ElseIf(StringCompare($gButtonArray[$I][$EBUTTON_KEY], $gPrevButtonKey) = 0) then
			If($order = 0) Then
				$gButtonArray[$I][$EOBJECT] = $gPrevButton
			Else
				$gPrevButton = $gButtonArray[$I][$EOBJECT]
			EndIf
			CheckParity($gButtonArray, $I, $gPrevButtonKey, "$gPrevButtonKey and $gButtonArray sync fail...", true)
		Else
			Logger($EINTERNAL, $gButtonArray[$I][$EBUTTON_KEY] & " has no handler", true)
		EndIf
	Next
	;Final step --- do this: CheckParity(ByRef array, ByRef globalvar, $msg, $msgbox)
EndFunc   ;==>SyncArrayAndGlobals


Func CalcAndSetCoordsRelativeToDownload()
	Logger($ETRACE, "CalcAndSetCoordsRelativeToDownload()", false)
	If(WindowResizedOrMoved() or $gPositionsValid = false) Then
		return False
	EndIf
	$max = Ubound($gButtonArray) - 1
	If $max < 0 Then CleanupExit(5, "$gButtonArray has no objects" & @error, true)
	
	CheckParity($gButtonArray, 0, $gDownloadButton, "gButtonArray and Coords unsynchronized ... (possible error)", true)
	
	If($gDownloadButton[0] = 0 And $gDownloadButton[1] = 0) Then ;Initial values
		$gDownloadButton[0] = OnOffOrError($gKeyName, $gDownloadButtonRegSz & "X") ;Check registry
		$gDownloadButton[1] = OnOffOrError($gKeyName, $gDownloadButtonRegSz & "Y")
		If($gDownloadButton[0] = -1 Or $gDownloadButton[1] = -1) Then ;If reg not set
			;"Download", 5, ...
			SetCoordinates($gDownloadButtonKey, $gButtonArray[0][$ETIMER], $gKeyName, $gDownloadButtonRegSz, $gDownloadButton)
		Endif
	EndIf
	$gBrowserWinPos = WinGetPos($gTaskIdentifier)
	$gBrowserWinSize = WinGetClientSize($gTaskIdentifier)
	
	for $I = 1 to $max
		if(StringCompare($gButtonArray[$I][$EBUTTON_KEY], $gEntireImageButtonKey) = 0) then
			_SetCoords($gEntireImageButton, $gBrowserWinPos[0] + $gBrowserWinSize[0] * .48, $gDownloadButton[1] + 60, $gKeyName, $gEntireImageButtonRegSz)
		ElseIf(StringCompare($gButtonArray[$I][$EBUTTON_KEY], $gNextButtonKey) = 0) then
			_SetCoords($gNextButton, $gBrowserWinPos[0] + $gBrowserWinSize[0] - 25, $gDownloadButton[1] - 33, $gKeyName, $gNextButtonRegSz)
		ElseIf(StringCompare($gButtonArray[$I][$EBUTTON_KEY], $gPrevButtonKey) = 0) then
			_SetCoords($gPrevButton, $gBrowserWinPos[0] + $gBrowserWinSize[0] - (25 + 15), $gDownloadButton[1] - 33, $gKeyName, $gPrevButtonRegSz)
		Else
			Logger($EINTERNAL, $gButtonArray[$I][$EBUTTON_KEY] & " has no handler", true)
		EndIf
	Next
	SyncArrayAndGlobals()
	return True
EndFunc   ;==>CalcAndSetCoordsRelativeToDownload


Func MakeActive($winState = "")
	Logger($ETRACE, "MakeActive()", false)
	If Not ProcessExists($gExeName) Then
		return 0
	EndIf
	
	;WinWaitActive($gTaskIdentifier, "", 5)
	Local $test
	While($gBrowserWindowId = 0 or $gBrowserWindowId = -1)
		$gBrowserWindowId = WinActivate($gTaskIdentifier)
		Sleep(500)
	Wend
	Do
		$gBrowserWindowId = WinActivate($gTaskIdentifier)
		if($gBrowserWindowId = 0) Then
			return 0
		EndIf
		If $winState <> "" Then
			WinSetState($gTaskIdentifier, "", $winState)
		EndIf
		$test = WinWaitActive($gTaskIdentifier, "", 2)
		Sleep(50)
	Until($test <> 0)
	WindowResizedOrMoved()
	;$gBrowserWinSize = WinGetClientSize($gTaskIdentifier)
	;$gBrowserWinPos = WinGetPos($gTaskIdentifier)
	return 1
EndFunc   ;==>MakeActive

Func InitializePage($winState = "")
	Logger($ETRACE, "InitializePage()", false)
	if(MakeActive($winState) <> 0 and $gBrowserWinSize[0] > 0 and $gBrowserWinSize[1] > 0) Then
		WinMove($gTaskIdentifier, "", 0, 0) ; @DesktopWidth, @DesktopHeight)
		Send("^t^l") ; Open a new tab, and go to the location bar
		;TODO: This should be based on the current position
		Send("http://www.footnote.com/image/{#}1|7276022{ENTER}") ; In the URL bar go to some start URL
		Sleep(5 * 1000) ; Wait 5 seconds for everything to load
		MouseClick("left", $gBrowserWinPos[0] + ($gBrowserWinSize[0] / 2), $gBrowserWinPos[1] + ($gBrowserWinSize[1] * 0.3), 1)
	EndIf
EndFunc   ;==>InitializePage


;grep string for root domain in url bar. If it's footnote.com then everything's fine.
Func ValidFootnotePage()
	Logger($ETRACE, "ValidFootnotePage()", false)
	If(Not MakeActive()) Then
		return false
	EndIf
	
	Send("^l^c") ; Open a new tab, and go to the location bar
	Sleep(100)
	$clip = ClipGet() ; Grab the clipboard
	If(StringCompare(StringLower(StringLeft($clip, 30)), "http://www.footnote.com/image/") = 0) Then
		return True
	EndIf
EndFunc   ;==>ValidFootnotePage


Func GetArrayValue($keyName, $index)
	Logger($ETRACE, "GetArrayValue(" & $keyName & "," & $index & ")", false)
	$max = Ubound($gButtonArray) - 1
	If $max < 0 Then CleanupExit(5, "$gButtonArray has no objects" & @error, true)
		
	for $I = 1 to $max
		if(StringCompare($gButtonArray[$I][$EBUTTON_KEY], $keyName) = 0) then
			;$subVal = $gButtonArray[$I]
			;This is actually an ___ERROR!!!___ I want $gButtonArray[$I] but it won't let me :(
			$subMax = Ubound($gButtonArray)-1
			if($index <= $subMax) then
				return $gButtonArray[$i][$index]
			else 
				SetError(2) ; BAD Index
				return -1
			EndIf
		EndIf
	Next
	SetError(1) ; No such key
	return -1
EndFunc

Func GUIUpdate()
	Logger($ETRACE, "GUIUpdate()", false)
EndFunc

;======================= SETTER FUNCTIONS ========================
;Everything is based off the Download Button Position so long as this is set everything else is probably good
Func SetDownloadPosition()
	Logger($ETRACE, "SetDownloadPosition()", false)
	if($gInitialized = false) then
		GuiCtrlSetState($initializebutton, $GUI_HIDE)
	endif

	If Not ValidFootnotePage() Then InitializePage(@SW_MAXIMIZE)
	If(Not WindowResizedOrMoved() and $gPositionsValid = true) Then
		Return
	EndIf
	;TODO: DUSTIN -- before ship set timer to 10 over array val for first entry?
	SetCoordinates($gDownloadButtonKey, $gButtonArray[0][$ETIMER], $gKeyName, $gDownloadButtonRegSz, $gDownloadButton)
	CalcAndSetCoordsRelativeToDownload()
	;CalcAndSetCoordsRelativeToDownload($gKeyName, $gDownloadButton, $gNextButton, $gEntireImageButton, $gPrevButton)
	
	$gPositionsValid = true
	;DUSTIN; No reason to turn it back on initializing downloadposition initializes everything.
;~ 	if($gInitialized = false)
;~ 		GuiCtrlSetState($initializebutton, $GUI_SHOW)
;~ 	endif
EndFunc   ;==>SetDownloadPosition


Func SetNextPosition()
	Logger($ETRACE, "SetNextPosition()", false)
	if($gInitialized = false) then
		GuiCtrlSetState($initializebutton, $GUI_HIDE)
	endif

	If Not ValidFootnotePage() Then InitializePage(@SW_MAXIMIZE)
	If(Not WindowResizedOrMoved() and $gPositionsValid = true) Then
		Return
	EndIf
	
	$timer = GetArrayValue($gNextButtonKey, 2)
	SetCoordinates($gNextButtonKey, $timer, $gKeyName, $gNextButtonRegSz, $gNextButton)
	SyncArrayAndGlobals()
	if($gInitialized = false) then
		GuiCtrlSetState($initializebutton, $GUI_SHOW)
	endif
	;CalcAndSetCoordsRelativeToDownload()
EndFunc


Func SetPrevPosition()
	Logger($ETRACE, "SetPrevPosition()", false)
	if($gInitialized = false) then
		GuiCtrlSetState($initializebutton, $GUI_HIDE)
	endif
	If Not ValidFootnotePage() Then InitializePage(@SW_MAXIMIZE)
	If(Not WindowResizedOrMoved() and $gPositionsValid = true) Then
		Return
	EndIf
	
	$timer = GetArrayValue($gPrevButtonKey, 2)
	SetCoordinates($gPrevButtonKey, $timer, $gKeyName, $gPrevButtonRegSz, $gPrevButton)
	SyncArrayAndGlobals()
	if($gInitialized = false) then
		GuiCtrlSetState($initializebutton, $GUI_SHOW)
	endif
EndFunc


Func SetEntireImagePosition()
	Logger($ETRACE, "SetEntireImagePosition", false)
	if($gInitialized = false) then
		GuiCtrlSetState($initializebutton, $GUI_HIDE)
	endif

	If Not ValidFootnotePage() Then InitializePage(@SW_MAXIMIZE)
	If(Not WindowResizedOrMoved() and $gPositionsValid = true) Then
		Return
	EndIf
	
	$timer = GetArrayValue($gEntireImageButtonKey, 2)
	SetCoordinates($gEntireImageButtonKey, $timer, $gKeyName, $gEntireImageButtonRegSz, $gEntireImageButton)
	SyncArrayAndGlobals()
	if($gInitialized = false) then
		GuiCtrlSetState($initializebutton, $GUI_SHOW)
	endif
EndFunc
;====================== END SETTER FUNCTIONS ======================

;========================= TOGGLE FUNCS ===========================
Func TogglePause()
	;IMPL
	;MsgBox(48, "Debug", "Pause ... IMPLEMENT")
	Logger($ETRACE, "TogglePause()", false)
	ConsoleWrite("Pause ... Implement")
EndFunc   ;==>TogglePause


Func Stop()
	;IMPL
	Logger($ETRACE, "Stop()", false)
	MsgBox(48, "Debug", "Stop ... IMPLEMENT")
EndFunc   ;==>Stop


Func StartResume()
	;IMPL
	Logger($ETRACE, "StartResume()", false)
	MsgBox(48, "Debug", "Start/Resume ... IMPLEMENT")
EndFunc   ;==>StartResume
;======================== END TOGGLE FUNCS =========================

Global Enum Step +2 $EVERBOSE=1, $ETRACE, $EASSERT, $EUNHANDLED, $EINTERNAL, $EUSER
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
		Case $code = 5
			if $bMsgBox then MsgBox(48, "Internal Error", $msg);
			ConsoleWrite("Internal Error: " & $msg)
	EndSelect
	Exit($code)
EndFunc   ;==>CleanupExit


Func VerifyButtons($skip = 1)
	Logger($ETRACE, "VerifyButtons()", false)
	CalcAndSetCoordsRelativeToDownload()
	$max = Ubound($gButtonArray) - 1
	;For $item in $gButtonArray
	for $I = 0 to $max
		If $skip > 0 Then
			$skip -= 1
			ContinueLoop
		EndIf
		;[["Download", $gDownloadButton, 10, $gDownloadButtonRegSz],
		$buttonName = $gButtonArray[$I][$EBUTTON_KEY]
		$object = $gButtonArray[$I][$EOBJECT]
		$timer = $gButtonArray[$I][$ETIMER]
		$regSz = $gButtonArray[$I][$EREGSZ]
		;SetCoordinates("Download", 10, $baseKey, $gDownloadButtonRegSz, $downloadcoords)
		;MsgBox(48, "Debug", IsArray($object) & " " & $object[0])
		
		MouseMove($object[0], $object[1])
		
		if(MsgBox(4, "Checking Location...", "Is the mouse pointer over the '" & $buttonName & "' button?") = 7) Then
			SetCoordinates($buttonName, $timer, $gKeyName, $regSz, $gButtonArray[$I][$EOBJECT])
		EndIf
	Next
	SyncArrayAndGlobals(1) ; we are storing the values in the array so need to set globals
EndFunc   ;==>VerifyButtons


Func Initialize()
	Logger($ETRACE, "Initialize()", false)
	If Not ProcessExists($gExeName) Then
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
			MsgBox(48, "Debug", $ret)
		EndIf
	EndIf
	
	;TODO: Ensure the user is actually signed in...
	InitializePage(@SW_MAXIMIZE)
	If(MsgBox(1, "Confirm Login", "Before continuing login to footnote.com") <> 2) Then
		SetDownloadPosition()
	Else
		return 0
	EndIf
	return 1
EndFunc   ;==>Initialize


Func MasterInitialize()
	Logger($ETRACE, "MasterInitialize()", false)
	GuiCtrlSetState($initializebutton, $GUI_HIDE)
	If(Initialize()) Then
		VerifyButtons()
	Else
		GuiCtrlSetState($initializebutton, $GUI_SHOW)
	EndIf
EndFunc   ;==>MasterInitialize



Func LoadOldWindowState()
	Logger($ETRACE, "LoadOldWindowState()", false)
	
	Local $successfulLoads = 0
	Dim $dlButtonXY[2] = [0,0]
	Local $buttonXY[2] = [0,0]
	
	Local $max = Ubound($gButtonArray) - 1
	If $max < 0 Then CleanupExit(5, "$gButtonArray has no objects" & @error, true)
	
	;First get our the new window values.
	if((WindowResizedOrMoved() = false and $gInitialized = true) or $gPositionsValid = true) Then	
	; WindowResizedOrMoved & $gInitialized
	; true true -> true: a person may want to fetch data from reg because they already initialized with different window layout and new window layout mimics registry 
	; true false -> true: If we're not initialized the window resize is pretty irrelevant we want to perform the operation
	; (false true -> false: (SPECIAL CASE) If we're initialized and nothing's changed with the window this is pretty suspect.  
	; false false -> true: If we're not initialized irregardless of no window change we want to move ahead.
		If(MsgBox(4, "Confirmation Dialog", "Footnote Reaper appears to be initialzied. Clicking 'Yes' will load information from the registry which may be out of date. Continue?") = 7) Then
			return false
		EndIf
	EndIf
	
	Dim $oldBrowserWinpos[2] = [-1,-1]
	Dim $oldBrowserWinsize[2] = [-1,-1]
	$oldPositionsValid = False
	
	$oldPositionsValid = OnOffOrError($gKeyName, $oldPositionsValid)
	
	;No reason to continue if we know it's already invalid
	if($oldPositionsValid = false) Then 
		;This should only happen when a window is resized and a person does a manual save.
		;Even in this scenario I should be querying the person to try to prevent this state 
		Logger($EASSERT, "$oldPositionsValid = false", true)
		return false
	EndIf
		
	$oldBrowserWinPos[0] = OnOffOrError($gKeyName, "gWinPosX")
	$oldBrowserWinPos[1] = OnOffOrError($gKeyName, "gWinPosX")
	$oldBrowserWinsize[0] = OnOffOrError($gKeyName, "gWinSizeX")
	$oldBrowserWinsize[1] = OnOffOrError($gKeyName, "gWinSizeY")
	
	;When can this type of thing happen? Basically only if a user quits the program
	;mid-execution. Because all regwrites have a WindowResizedOrMoved() before them
	;Basically if this is the case we should just bail. The data's likely garbage.
	If( $oldBrowserWinPos[0] = -1 Or _
		$oldBrowserWinPos[1] = -1 Or _
		$oldBrowserWinSize[0] = -1 Or _
		$oldBrowserWinSize[1] = -1) Then
			;$regMissingPosOrSize = True
			Logger($EUSER, "No previous sessions has been saved.", true)
			return false
	EndIf
			
	;if($oldBrowserWinPos <> $gBrowserWinPos OR $oldBrowserWinSize <> $gBrowserWinSize)) Then
	
	;Do we need to reposition the window to get all the old data to work?
	if((($oldBrowserWinPos[0] <> $gBrowserWinPos[0]) or ($oldBrowserWinPos[1] <> $gBrowserWinPos[1])) Or  _
	   (($oldBrowserWinSize[0] <> $gBrowserWinSize[0]) or ($gBrowserWinSize[1] < $oldBrowserWinSize[1] and $gBrowserWinSize[1] <= 400))) Then
		If(MsgBox(4, "Confirmation Dialog", "The window has been moved or resized. Reset window? Answering 'No' will cancel the load.") = 7) Then 
			return False
		Else
			if(WinMove($gTaskIdentifier, "", $oldBrowserWinPos[0], $oldBrowserWinPos[1], $oldBrowserWinSize[0], $oldBrowserWinSize[1]) = 0) Then
				Logger($EINTERNAL, "Failed to move and resize window. Aborting. Try loading again or reinitialize the program.", true)
				return false
			EndIf
			$gBrowserWinPos = $oldBrowserWinPos
			$gBrowserWinSize = $oldBrowserWinSize
		EndIf
	EndIf
	
	$gInitialized = false	 ;unless we get to the end the function things have been modified that can ruin proper init.
	$gPositionsvalid = false ;...
	
	;TODO: Dustin set this to the array instead.
	if(IsArray($gButtonArray[0][$EOBJECT])) Then
		$dlButtonXY[0] = OnOffOrError($gKeyName, $gDownloadButtonRegSz & "X") ;Check registry
		$dlButtonXY[1] = OnOffOrError($gKeyName, $gDownloadButtonRegSz & "Y")
		$gButtonArray[0][$EOBJECT] = $dlButtonXY
	Else
		Logger($EINTERNAL, "Failed to grab $gDownloadButton object from internal array", true)
		return False
	EndIf

	;If $gDownloadButton returns -1 that probably means nothing's valid. Should we force user 
	;to init? No. Instead I'll load what I can and just inform the user at the end that the 
	;load was only partly successful. We'll base this off $gPositionsvalid
	If($dlButtonXY[0] = -1 Or $dlButtonXY[1] = -1) Then
		$gButtonArray[0][$EOBJECT] = $buttonXY 	;set it to the original defaults.
	Else
		$successfulLoads += 1
		$gPositionsvalid = true
	Endif

	for $I = 1 to $max
		$buttonXY[0] = OnOffOrError($gKeyName, $gButtonArray[$I][$EREGSZ] & "X")
		$buttonXY[1] = OnOffOrError($gKeyName, $gButtonArray[$I][$EREGSZ] & "Y")
		
		if(NOT($buttonXY[0] = -1 or $buttonXY[1] = -1)) Then
			$gButtonArray[$I][$EOBJECT] = $buttonXY
			$successfulLoads += 1
		Else
			Logger($EVERBOSE, "Load failed locate anything for " & $gButtonArray[$I][$EREGSZ], false)
		EndIf
	next

	SyncArrayAndGlobals(1) ;arrays -> globals
	;CheckParity($gButtonArray, 0, $gDownloadButton, "gButtonArray and Coords unsynchronized ... (possible error)", true)
	if($gPositionsvalid = true And ($successfulLoads-1) = $max) Then
		$gInitialized = True
	Else
		Logger($EUSER, "Not all data was loaded successfully. Please click 'Edit -> Verify Buttons'", true)
		ConsoleWrite($max & " " & $successfulLoads & " " & $gPositionsvalid)
	EndIf
	
	if($gInitialized = false) then
		GuiCtrlSetState($initializebutton, $GUI_SHOW)
	else
		GuiCtrlSetState($initializebutton, $GUI_HIDE)
	endif
EndFunc   ;==>LoadOldWindowState


Func SaveWindowState()
	Logger($ETRACE, "SaveWindowState()", false)
	;impl
EndFunc


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
Global $gInitialized = false
Global $gPositionsValid = false
;-------------------------------------

Global $gProgramName = "Firefox"
Global $gExeName = "firefox.exe"
Global $gTaskIdentifier = "Firefox"
Global $gBrowserWindowId = -1

Global $gProgramPathSz = "gProgramPath"
Global $gProgramPath = ""

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

Dim $gWinPos[2] = [0, 0]
Dim $gWinSize[2] = [0, 0]
Dim $gGuiItem[4][4]


;Firefox window details
Dim $gBrowserWinPos[2] = [0, 0]
Dim $gBrowserWinSize[2] = [0, 0]

Dim $gButtonDictionary[4] = [$gDownloadButtonKey, $gNextButtonKey, $gPrevButtonKey, $gEntireImageButtonKey]

Global Enum Step +1 $EBUTTON_KEY=0, $EOBJECT, $ETIMER, $EREGSZ
;                    Button Name,           Object,        , Timer,    RegSz
Dim $gButtonArray[4][4] = [[$gButtonDictionary[0], $gDownloadButton, 5, $gDownloadButtonRegSz], _
		[$gButtonDictionary[1], $gNextButton, 5, $gNextButtonRegSz], _
		[$gButtonDictionary[2], $gPrevButton, 5, $gPrevButtonRegSz], _
		[$gButtonDictionary[3], $gEntireImageButton, 5, $gEntireImageButtonRegSz]]
;;==>Firefox window details


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

HotKeySet("{F11}", "TogglePause")
HotKeySet("{ESC}", "Stop")

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
$stopitem = GuiCtrlCreateMenuItem("S&top", $commands)
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

$help = GuiCtrlCreateMenu("&Help")
$readmeitem = GuiCtrlCreateMenuItem("View &Readme", $help)
$aboutitem = GuiCtrlCreateMenuItem("&About", $help)

WindowResizedOrMoved()
$initializebutton = GUICtrlCreateButton("Initialize", 20, 20, 120)
;WinSetOnTop(GUICreate("Status Window",500,30,500,1), '', 1)

ConsoleWrite("Initialized GUI and global ..." & @CRLF)

GuiSetState()
;Dim $gBrowserWinPos = WinGetPos("FootnoteReap", "Steps Completed")
do
	$msg = GuiGetMsg()
	Select
		Case $msg = $GUI_EVENT_CLOSE Or $msg = $exititem
			ExitLoop

		Case $msg = $initializebutton
			MasterInitialize()
			
		Case $msg = $startitem
			MasterInitialize()
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
			CalcAndSetCoordsRelativeToDownload()
			;Perhaps record a state to remember whether a person manually set a position versus one autoconfigured?
			MouseMove($gDownloadButton[0], $gDownloadButton[1])
			
		Case $msg = $checknextitem
			CalcAndSetCoordsRelativeToDownload()
			MouseMove($gNextButton[0], $gNextButton[1])
			
		Case $msg = $checkprevitem
			CalcAndSetCoordsRelativeToDownload()
			MouseMove($gPrevButton[0], $gPrevButton[1])
			
		Case $msg = $checkentireimageitem
			CalcAndSetCoordsRelativeToDownload()
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
			$label2 = GuiCtrlCreateLabel("Created By:  Dustin", 5, $lab2h)
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

			Global $label5 = GuiCtrlCreateLabel("dustin@razing-the.net", 70, $lab3h - 2, $SS_NOTIFY)
			GUICTRLSetFont($label5, 9, 400, 4)
			GUICtrlSetColor($label5, 0x0000ff)
			Global $label6 = GuiCtrlCreateLabel("http://wiki.razing.net", 70, $lab4h - 2, $SS_NOTIFY)
			GUICTRLSetFont($label6, 9, 400, 4)
			GUICtrlSetColor($label6, 0x0000ff)

			$gButton = GUICtrlCreateButton("i", $width - 15, 5, 12, 12, BitOr($BS_BITMAP, $BS_DEFPUSHBUTTON))
			GuiCtrlSetImage($gButton, $gCWD & "\left.bmp")
			;GUISetState(@SW_SHOW, $gButton)
			;Msgbox(0,"The Ultimate Collection","Created by Dustin." & @LF & "Contact: dustin@razing-the.net" & @LF & "Website: http://www.razing-the.net")
			

		Case $msg = $label6
			If WinExists("The FootNote Reaper") Then
				If FileExists(@ProgramFilesDir & "\Internet Explorer\iexplore.exe") Then
					;Run(@ProgramFilesDir & "\Internet Explorer\iexplore.exe http://www.razing.net")
					_RunDOS("start http://wiki.razing.net")
				EndIf
			EndIf
			
		Case $msg = $label5
			_INetMail ( "dustin@razing-the.net", "[FootnoteReaper] ", "Please leave the [FootnoteReaper] in the Subject so my mail filter can sort by it, thanks!")

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

		Case $msg = $GUI_EVENT_MOUSEMOVE
			;ConsoleWrite("moved ..")
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
			
		case $msg = $GUI_EVENT_RESIZED
			;ConsoleWrite("resized ..")
			$tempPos = WinGetPos("FootnoteReap")
			$tempSize = WinGetClientSize("FootnoteReap")
			if IsArray($tempPos) AND ($tempPos[0] <> $gWinPos[0] OR $tempPos[1] <> $gWinPos[1] OR $tempSize[0] <> $gWinSize[0] OR $tempSize[1] <> $gWinSize[1]) Then
					;ConsoleWrite("resized ..")
					If WinExists("The FootNote Reaper") Then WinMove("The FootNote Reaper", "", $tempPos[0] + $tempSize[0] + 12, $tempPos[1])
					$gWinPos[0] = $tempPos[0]
					$gWinPos[1] = $tempPos[1]
					$gWinSize[0] = $tempSize[0]+12
					$gOffset = $tempSize[0]
					$gWinSize[1] = $tempSize[1]
			EndIf

		;===============  END ABOUT DIALOGUE CASES ==============
	EndSelect

Until $msg = $GUI_EVENT_CLOSE OR $msg = $exititem
