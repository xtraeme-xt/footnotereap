#include-once

;--------------------------------------------------------------------------------
;AutoIt Version: 3x
;Language:       English
;Platform:       All
;Author:         Xt (xthaus@yahoo.com)
;    
;Script Function:
;	 FoonoteReap window specific object functions. 
;
;	 Public:
;	 CountRegButtonsSet($start = 0)
;	 LoadRegButtons($start = 0)
;	 CountObjButtonsSet()
;
;    SetCoordinates($buttonName, $timer, $baseKey, $keyname, ByRef $coords)
; 	 WindowResizedOrMoved($regwrite = false)
;	 CalcAndSetCoordsRelativeToDownload()
;	 MakeActive($winState = "")
;
;	 GetArrayValue($keyname, $index)
;
;    GenericSetButtonPosition(ByRef $buttonKey, ByRef $regSz, ByRef $obj, $winState = "", $skipClosingInitializeCheck = false)
;	 SetDownloadPosition($winState = "")
;    SetNextPosition($winState = "")
;	 SetPrevPosition($winState = "")
;	 SetEntireImagePosition($winState = "")
;
;	 VerifyButtons($skip = 1, $changeButtonState = true)
;
;	 HackFixResize()
;	 HackGiveFocusFirefox()
;
;	 Private:
;	 _RegButtonsSet($start = 0, $loadData = false)
;	 _SetCoords(ByRef $name, $X, $Y, $baseKey, $regSz)
;
;    Not Implemented:
;	 GUIUpdate()
;    
;NOTES:
;    None
;
;THANKS:
;	 None yet
;--------------------------------------------------------------------------------

Func _RegButtonsSet($start = 0, $loadData = false)
	Logger($ETRACE, "_RegButtonSet(" & $start & ", " & $loadData & ")", false)
	Local $buttonXY[2] = [0, 0]
	Local $max = Ubound($gFootnoteButtonArray) - 1
	Local $successfulLoads = 0
	If $max < 0 Then CleanupExit(5, "$gFootnoteButtonArray has no objects" & @error, true)
	for $I = $start to $max
		$buttonXY[0] = OnOffOrError($gKeyName, $gFootnoteButtonArray[$I][$EREGSZ] & "X")
		$buttonXY[1] = OnOffOrError($gKeyName, $gFootnoteButtonArray[$I][$EREGSZ] & "Y")
		
		if(NOT($buttonXY[0] = -1 or $buttonXY[1] = -1)) Then
			if($loadData = true) then $gFootnoteButtonArray[$I][$EOBJECT] = $buttonXY
			$successfulLoads += 1
		Else
			Logger($EVERBOSE, "Load failed to locate anything for " & $gFootnoteButtonArray[$I][$EREGSZ], false)
		EndIf
	next
	return $successfulLoads
EndFunc   ;==>_RegButtonsSet


Func CountRegButtonsSet($start = 0)
	Logger($ETRACE, "CountRegButtonsSet()", false)
	return _RegButtonsSet($start, false)
EndFunc   ;==>CountRegButtonsSet


Func LoadRegButtons($start = 0)
	Logger($ETRACE, "LoadRegButtonSet()", false)
	return _RegButtonsSet($start, true)
EndFunc   ;==>LoadRegButtons


Func CountObjButtonsSet()
	Logger($ETRACE, "CountObjButtonsSet()", false)
	Local $countCoords = 0
	For $I = 0 to Ubound($gFootnoteButtonArray) - 1
		$objcoords = $gFootnoteButtonArray[$I][$EOBJECT]
		if(Not IsArray($objcoords) or Ubound($objcoords < 2)) Then ContinueLoop
		if($objcoords[0] <> 0 and $objcoords[1] <> 0) Then $countCoords += 1
	Next
	return $countCoords
 EndFunc   ;==>CountObjButtonsSet
 
Global $gFirstDownloadSet = true
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
			Sleep(1000)    ;* $gSleepMultiplier
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
		;if($gBrowserActiveBeforeFootnoteReap = true And $gFirstDownloadSet) Then
		;	IsSaveImageDialogUp()
		;	$gFirstDownloadSet = false
		;endif
		if($gSaveImageDialogUp = false) Then ;And $gBrowserActiveBeforeFootnoteReap = false
			;NOTE: I have to do it this way instead of using EnableEntireImageDialog() because
			;      the globals and array values aren't synced yet.
			MouseClick("Left", $coords[0], $coords[1])
			$gSaveImageDialogUp = True
			;TODO: Maybe just have a check after we do this click?
			;ConsoleWrite("DUSTIN FIND ME");
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
	Local $oldRegBrowserWinpos[2] = [0, 0]
	Local $oldRegBrowserWinsize[2] = [0, 0]
	Local $changed = false
	Local $winPos = WinGetPos($gTaskIdentifier)
	Local $winSize = WinGetClientSize($gTaskIdentifier)
	FixClientSize($winSize)
	;if we don't have a window open we have nothing to work with.
	if(Not IsArray($winPos) or UBound($winPos) < 2) then return true ;BUG: had it as false before and that causes errors when opening a window setting the values, closing a window, and then trying to do a check/set
	
	;Has the window moved at all since this function was last called?
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
	
	;If we're trying to write lets find out if there's parity between our current window data
	;and the window data in the registry. If there isn't we'll update the registry.
	$oldRegBrowserWinpos[0] = OnOffOrError($gKeyName, "gWinPosX")
	if($regwrite = true) Then
		$oldRegBrowserWinpos[1] = OnOffOrError($gKeyName, "gWinPosY")
		$oldRegBrowserWinsize[0] = OnOffOrError($gKeyName, "gWinSizeX")
		$oldRegBrowserWinsize[1] = OnOffOrError($gKeyName, "gWinSizeY")
		
		if(($oldRegBrowserWinsize[0] <> $gBrowserWinSize[0]) or($oldRegBrowserWinsize[1] < $gBrowserWinSize[1] and $oldRegBrowserWinsize[1] <= 400)) Then
			$changed = True
		EndIf
		if(($oldRegBrowserWinpos[0] <> $gBrowserWinPos[0]) or($oldRegBrowserWinpos[1] <> $gBrowserWinPos[1])) Then
			$changed = True
		EndIf
	EndIf
	
	if(($regwrite = true and $changed = true) OR _		;We only write when forced (this happens when we set our buttons) and there's been a change of some sort to the window or the registry
			($oldRegBrowserWinpos[0] = -1)) Then ;If we have nothing then we should get some position information
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
		$gBrowserWindowId = 0
		Logger($EVERBOSE, "No process yet, returning 0", false)
		return 0
	EndIf

	;WinWaitActive($gTaskIdentifier, "", 5)
	Local $test = 0
	Local $count = 0
	
	;Get the window active
	Logger($EVERBOSE, "Trying to get the window active. Will try for 10 seconds ...", false)
	While($gBrowserWindowId = 0 or $gBrowserWindowId = -1)
		$gBrowserWindowId = WinActivate($gTaskIdentifier)
		Sleep(500 * $gSleepMultiplier)
		$count += 1
		if($count = 20) Then
			;HACK: (500*20 = 10,000ms = 10secs) This is to handle dangling processes and orphaned windows
			Logger($EUSER, "There appears to be a " & $gTaskIdentifier & " process open, but it's not responding to messages. Please close the process and reload a new instance.", true)
			return 0
		EndIf
	Wend
	$count = 0
	
	;Now we can set the $winState and wait for the change to take place
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
			Logger($EUSER, "There appears to be a " & $gTaskIdentifier & " process open, but it's not responding to messages. Please close the process and reload a new instance.", true)
			return 0
		EndIf
		Sleep(50 * $gSleepMultiplier)
	Until($test <> 0)
	WindowResizedOrMoved()
	;$gBrowserWinSize = WinGetClientSize($gTaskIdentifier)
	;$gBrowserWinPos = WinGetPos($gTaskIdentifier)
	return 1
 EndFunc   ;==>MakeActive
 
 
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
	Local $runpauseCase = false
	if($gInitialized = false) then
		GuiCtrlSetState($initializebutton, $GUI_HIDE)
	Else
		;$gRunning & NOT $gPaused
		;t t -> the app is running	(NEED TO HANDLE THIS CASE -- But is there the chance we might need this when the browser crashes? Shouldn't be load does it's own thing.
		;t f -> the app is running and paused (ok to reset in this mode)
		;f t -> the idle state, ok to reset in this mode 
		;f f -> the app isn't running, but it is paused (basically the same as "t f" (not an error case because the main loop exits on pause now))
		if($gRunning and NOT $gPaused) Then
			Logger($EUSER, "Pause script execution before trying to change the button positions", false)
			Return
		EndIf
		;ConsoleWrite("Dustin find this: " & GUICtrlGetState($initializebutton))
		if(BitAnd(GUICtrlGetState($initializebutton), $GUI_SHOW) > 0) Then
			$runpauseCase = True
			GuiCtrlSetState($initializebutton, $GUI_HIDE)
		EndIf
	endif

	If Not ValidFootnotePage() Then InitializePage(true, $winState) ;@SW_MAXIMIZE)
	If(Not WindowResizedOrMoved() and $gPositionsValid = true) Then
		Return
	EndIf
	
	$timer = GetArrayValue($buttonKey, $ETIMER)
	SetCoordinates($buttonKey, $timer, $gKeyName, $regSz, $obj)
	SyncArrayAndGlobals()
	;if($gRunning = false AND ($gInitialized = true OR $gPaused = true)) then
	if(($gInitialized = false and $skipClosingInitializeCheck = false) Or $runpauseCase) then
		GuiCtrlSetState($initializebutton, $GUI_SHOW)
	endif
EndFunc   ;==>GenericSetButtonPosition

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


Func VerifyButtons($skip = 1, $changeButtonState = true)
	Logger($ETRACE, "VerifyButtons()", false)
	
	if($changeButtonState) then GuiCtrlSetState($initializebutton, $GUI_HIDE)
	
	Local $max = Ubound($gFootnoteButtonArray) - 1
	Local $ret = 0
	
	;For $item in $gFootnoteButtonArray
	for $I = $skip to $max
		;[["Download", $gDownloadButton, 10, $gDownloadButtonRegSz],
		$buttonName = $gFootnoteButtonArray[$I][$EBUTTON_KEY]
		$object = $gFootnoteButtonArray[$I][$EOBJECT]
		$timer = $gFootnoteButtonArray[$I][$ETIMER]
		$regSz = $gFootnoteButtonArray[$I][$EREGSZ]
		
		MouseMove($object[0], $object[1])
		
		;Xtraeme change to msgbox(4...) -- cancel is temporary for bug fixing
		$ret = MsgBox(3, "Checking Location...", "Is the mouse pointer over the '" & $buttonName & "' button?", 60)
		
		;Did we time out?
		if($ret = -1) Then
			;Yes, let's see if our button data is semi-valid, can we get a "Save Image" dialog up?
			IsSaveImageDialogUp(true)
			if(@error = 1) Then
				;We timed out and didn't get user feedback so we're absolutely dependent on user information
				$ret = MsgBox(3, "Checking Location...", "Is the mouse pointer over the '" & $buttonName & "' button?", 0)
			endif
		endif
		if($ret = 7) Then
			SetCoordinates($buttonName, $timer, $gKeyName, $regSz, $gFootnoteButtonArray[$I][$EOBJECT])
		elseif($ret = 2) then
			ExitLoop
		EndIf
	Next

	if($changeButtonState) then
		if($gRunning and NOT $gPaused) Then
			GuiCtrlSetState($initializebutton, $GUI_HIDE)
		Else
			GuiCtrlSetState($initializebutton, $GUI_SHOW)
		EndIf
	endif

#cs	
	if ((NOT $gRunning and $gPaused) or (NOT $gRunning and NOT $gPaused)) then
		GuiCtrlSetState($initializebutton, $GUI_SHOW)
	EndIf

	if($gRunning = false and ($gInitialized = true or $gPaused = true)) Then
		GuiCtrlSetState($initializebutton, $GUI_SHOW)
	endif
#ce
	SyncArrayAndGlobals(1) ; we are storing the values in the array so need to set globals
 EndFunc   ;==>VerifyButtons
 
 
 Func HackFixResize()
	;Hack: Trying to fix issue where flash doesn't refresh properly after resize if there
	;	   isn't enough of a delay. This provides a delay, but on a small interval
	Logger($ETRACE, "HackFixResize()", false)
	Dim $winPos = WinGetPos($gTaskIdentifier)
	Dim $winSize = WinGetClientSize($gTaskIdentifier)
	FixClientSize($winSize)
	WinMove($gTaskIdentifier, "", $winPos[0], $winPos[1], $winSize[0] - 5, $winSize[1] - 5, 50)
EndFunc   ;==>HackFixResize


Func HackGiveFocusFirefox()
	;Finally figured out the bug. Flash steals focus. I created a function to give focus back to FF
	;Another solution is to install addon windowfocus and the nightly tester tools. Though this "fix"
	;doesn't work in all instances. This is why I've chosen to use IE as the default browser. Chrome
	;has the same bug as FF.
	Logger($ETRACE, "HackGiveFocusFirefox()", false)
	if($gDownloadButton[0] <> -1 and $gDownloadButton[0] <> 0 and _
			$gDownloadButton[1] <> -1 and $gDownloadButton[1] <> 0) then
		MouseClick("Left", $gDownloadButton[0], $gDownloadButton[1] - 30)
	EndIf
EndFunc   ;==>HackGiveFocusFirefox