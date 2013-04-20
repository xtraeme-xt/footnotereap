;--------------------------------------------------------------------------------
;AutoIt Version: 3x
;Language:       English
;Platform:       All
;Author:         Xt (xthaus@yahoo.com)
;    
;Script Function:
;	 Webpage and Fold3 specific functions
;
;	 Public:
;	 GetCurrentURL(ByRef $clip)
;	 ValidFootnotePage($testString = "")
;	 
;	 EnableEntireImageDialog()
;	 DisableEntireImageDialog()
;	 IsSaveImageDialogUp($automated = false, $count = 0, $timeout = 60)
;
;	 Private:
;	 _EnableOrDisableEntireImageDialog($state, $bForce = false)
;    
;NOTES:
;    None
;
;THANKS:
;	 None yet
;--------------------------------------------------------------------------------

Func GetCurrentURL(ByRef $clip)
	;TODO: There's still a bug in here where occassionally I don't get the URL bar.
	;      I suspect it's an issue with Send(). Though somehow it seems to manifest
	;      as an issue with the clipget() and put()
	Logger($ETRACE, "GetCurrentURL()", false)
	Local $count = 0
	Local $err = 0
	Local $tempClip = ""
	
	do
		Sleep(130 * $gSleepMultiplier)
		
		;BUG: Finally figured out the bug. Flash steals focus. I created a function to give focus back to FF
		;HackGiveFocusFirefox(). Unfortunately though https://bugzilla.mozilla.org/show_bug.cgi?id=78414
		;details how complicated this bug actually is. The problem also exists in Chrome. For the sake of
		;simplicity I've decided to just use Internet Explorer. For more information also see:
		;https://www.ibm.com/developerworks/opensource/library/os-78414-firefox-flash/
		
		Send("{ALTDOWN}d{ALTUP}", 0) ; Grab the URL off the clipboard
		Sleep(150 * $gSleepMultiplier)
		;Sleep(10000)
		$err = GetClip($tempClip, true, true, $count)
		;Todo: add in a comment to the user to tell them to click in the URL bar?
		if(StringCompare($tempClip, "d") = 0) Then
			Send("{CTRLDOWN}z{CTRLUP}", 0)
			sleep(300)
			$tempClip = ""
		EndIf
		;if($err <= 1) then ExitLoop ; NOTE: I may have to check for <= 1 because the clip can theoretically be empty
		$count += 1
		if($count > 1) then MakeActive() ; Send("!{TAB}!{TAB}") ;try to get some focus
		
	until($err = 0 And StringCompare($tempClip, "") <> 0)
	$clip = $tempClip
	
	Logger($EVERBOSE, "$clip: " & $clip, false)
EndFunc   ;==>GetCurrentURL


;grep string for root domain in url bar. If it's footnote.com then everything's fine.
Func ValidFootnotePage($testString = "")
	;TODO: Two fail states (couldn't make active, not correct page) have two return codes or use @error?
	Logger($ETRACE, "ValidFootnotePage()", false)
	
	Local $clip = ""
	If(Not MakeActive()) Then
		Logger($ETRACE, "Failed to MakeActive() ...", false)
		return false
	EndIf
	
	if(StringCompare($testString, "") = 0) then
		GetCurrentURL($clip)
		Logger($EVERBOSE, "$clip: " & $clip, false)
	Else
		$clip = $testString
	endif
	
	If(StringCompare(StringLower(StringLeft($clip, 27)), $gBaseURL & "image/") = 0) Then
		;ClipPut("")
		if($gPrevURL <> $gCurrentURL) then $gPrevURL = $gCurrentURL
		$gCurrentURL = $clip
		RegWrite($gKeyName, $gPrevURLRegSz, "REG_SZ", $gPrevURL)
		RegWrite($gKeyName, $gCurrentURLRegSz, "REG_SZ", $gCurrentURL)
		Logger($EVERBOSE, "$gPrevURL: " & $gPrevURL, false)
		Logger($EVERBOSE, "$gCurrentURL: " & $gCurrentURL, false)
		return True
	EndIf
	return false
 EndFunc   ;==>ValidFootnotePage
 
 
 Func _EnableOrDisableEntireImageDialog($state, $bForce = false)
	Logger($ETRACE, "_EnableOrDisableEntireImageDialog()", false)
	Dim $defaultButtonValues[2] = [0, 0]
	if(Not $bForce) Then
		If(($gSaveImageDialogUp = true and $state = true) Or _
				($gSaveImageDialogUp = false and $state = false)) then
			return false
		EndIf
	Endif
	if(($gDownloadButton[0] = $defaultButtonValues[0] and $gDownloadButton[1] = $defaultButtonValues[1]) Or _ 
		NOT $gPositionsValid) then
		  return False
	EndIf
	$gSaveImageDialogUp = $state
	;if($gBrowserActiveBeforeFootnoteReap = true) then
	MouseClick("Left", $gDownloadButton[0], $gDownloadButton[1])
	return true
EndFunc   ;==>_EnableOrDisableEntireImageDialog


Func EnableEntireImageDialog()
	Logger($ETRACE, "EnableEntireImageDialog()", false)
	return _EnableOrDisableEntireImageDialog(true)
EndFunc   ;==>EnableEntireImageDialog


Func DisableEntireImageDialog()
	Logger($ETRACE, "DisableEntireImageDialog()", false)
	return _EnableOrDisableEntireImageDialog(false)
 EndFunc   ;==>DisableEntireImageDialog
 
 
 ;potential bug where entireimagebutton isn't set properly by calcandsetcoords resulting in infinite loop
Global $gIsSaveImageDialogUpTries = 0
Global $gIsSaveImageDialogUpTries2 = 0
Func IsSaveImageDialogUp($automated = false, $count = 0, $timeout = 60)
	PushLoggerIgnoreLevel($ENOTHING, false)
	Logger($ETRACE, "IsSaveImageDialogUp(" & $automated & ", " & $count & ", " & $timeout & ")", false)
	Dim $defaultButton[2] = [0, 0]
	Dim $failedRegValues[2] = [-1, -1]
	if(NOT $automated) then
		Local $ret = MsgBox(4, "Checking State...", "Is the 'Save Image' dialog containing the 'Entire Image' and 'Select Portion of Image' visible?", $timeout)
		if($ret = -1) then SetError(1)
		$gSaveImageDialogUp = _Iif($ret == 6, True, False)
		;TODO: Is this really appropriate in an Is... function? Especially after a user tells us the state.
		if($gSaveImageDialogUp = false And $ret <> -1) then
			EnableEntireImageDialog()
		endif
		return $gSaveImageDialogUp
	Else
		if($gEntireImageButton[0] <> $defaultButton[0] And $gEntireImageButton[1] <> $defaultButton[1] And _
				$gEntireImageButton[0] <> $failedRegValues[0] And $gEntireImageButton[1] <> $failedRegValues[1] And _
				$count < 2) Then
			;ConsoleWrite($gEntireImageButton[0] & ", " & $gEntireImageButton[1] & @CRLF)
			;ConsoleWrite($gDownloadButton[0] & ", " & $gDownloadButton[1] & @CRLF)
			Switch $count
				case 1
					;ConsoleWrite("case #3" & @CRLF)
					;Since we're here that means our case 0 didn't work ... Maybe 'Save Image' wasn't up? Lets click Download.
					MouseClick("left", $gDownloadButton[0], $gDownloadButton[1])
					Sleep(600 * $gSleepMultiplier)
					ContinueCase
				case 0
					;ConsoleWrite("case #2" & @CRLF)
					;click and see if we get a dialog. If so it was up. Now lets reenable it.
					MouseClick("left", $gEntireImageButton[0], $gEntireImageButton[1])
					Sleep(600 * $gSleepMultiplier)
					If(WinExists($label_select_location) = true Or _    ;"Select location for download") = true Or _
					   WinExists($label_save_as) = true ) Then 			;by www.fold3.com
						Send("{Tab}{Tab}{Tab}{ENTER}", 0)
						Sleep(100 * $gSleepMultiplier)
						$gSaveImageDialogUp = false
						$gIsSaveImageDialogUpTries = $gIsSaveImageDialogUpTries2 = 0
						return false ;We can be confident about our choice now.
					EndIf
			EndSwitch
			IsSaveImageDialogUp(true, $count + 1)
		Else
			if($gDownloadButton[0] <> $defaultButton[0] And $gDownloadButton[1] <> $defaultButton[1] And _
					$gDownloadButton[0] <> $failedRegValues[0] And $gDownloadButton[1] <> $failedRegValues[1] And _
					$gIsSaveImageDialogUpTries = 0) Then ;count = 2 or $count = 0
				;if($count = 0) then
				;ConsoleWrite("case #0" & @CRLF)
				CalcAndSetCoordsRelativeToDownload()
				$gIsSaveImageDialogUpTries += 1
				return IsSaveImageDialogUp(true, _Iif($gEntireImageButton[1] <> $defaultButton[1] And $gEntireImageButton[1] <> $failedRegValues[1], 0, $count + 1))
			else
				if($gIsSaveImageDialogUpTries2 = 0) Then ;$count = 0 or $count = 1 or $count = 3
					;ConsoleWrite("case #1" & @CRLF)
					$gIsSaveImageDialogUpTries2 += 1
					;SetLoggerIgnoreLevel($ETRACE)
					if(LoadOldWindowState(true) = true) Then
						;SetLoggerIgnoreLevel($ENOTHING)
						return IsSaveImageDialogUp(true, _Iif($gEntireImageButton[1] <> $defaultButton[1] And $gEntireImageButton[1] <> $failedRegValues[1], 0, $count + 1))
					EndIf
				EndIf
			endif
			;Without information about the $gEntireImageButton and no $downloadbutton data we're stuck.
			;We'll have to wait for the user to tell us where things are. This means blocking indefinitely
			;ConsoleWrite("case #4 giving up" & @CRLF)
			$gIsSaveImageDialogUpTries = $gIsSaveImageDialogUpTries2 = 0
			;fold3.com occassionally outputs a message: 
			;"Oops, we couldn't load information about this image"
			;  And more commonly, 
			;"We're sorry, it is taking longer than expected to load information about this image."
			;Over time clicking on "Download" eventually causes this to disappear. So I should put a long time out and keep trying.
			return IsSaveImageDialogUp(false, $count + 1, 60)
			
		endif
	EndIf
	PopLoggerIgnoreLevel()
EndFunc   ;==>IsSaveImageDialogUp