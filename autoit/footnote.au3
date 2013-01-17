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
; 1. DONE - I need to add in an option to allow a resume (from a currently open tab)
; 2. DONE - Allow a resume from data that's been stored in the registry (due to a pause or stop)
; 3. DONE - Have a start state where it knows nothing about anything -- open a new tab or window
; 4. DONE - Implement user defined (download button) x,y pos. This will be useful for different layouts
; 5. Create an options panel with boxes? (i.e. two textboxes with coords for download loc?)
;    This may be overkill since a person can just make the modifications in regedit. Instead
;    just create a readme with all the values? Readme is the solution here.
; 6. DONE - In the directory it's probably worthwhile to save the URL of the starting grouping for each
;    set. This will allow easy review.
;6a. It may even be worthwhile to grab as much metadata as possible including comments, and
;    other factoids. This can be stored in a .meta file.
; 7. DONE - Create a function that runs through all the check items to make sure they're over Then
;    correct widget. Basically I'll try to calculate their location, and then get confirmation
; 8. DONE - Have an array that keeps the information for the last 3 entries. This should be good enough
;    for recovery if things go south.
; 9. PARTIALLY DONE - For a logging facility use ConsoleWrite()? Then just hook it? Or write to file instead?
;    This is implemented through Logger() and will pipe through the test_logging facility
; 10. With $lookforwin = PixelChecksum(20, 40, 100, 100) I can probably automate detecting if
;     a button is actually being activated.
; 11. DONE - Configured basic hotkeys using F12 as Pause and END as stop. Perhaps F11 as resume/start?
; 12. Scale the Sleeps() based on the persons CPU and connection speed? This is an advanced feature
;     for some later point.
; 13. Create a distributed database with all the ids and add two columns: downloaded and claimed. This
;     will allow numerous people to help participate in the project.
; 14. Implement an FTP upload feature. This should be spawned as it's own thread or process that doesn't
;     block the reaping tool. A low priority background task would be best.
; 15. Design the application so in the event of a browser crash it can restore itself. This means all
;     the user dialogs need to have time limits. Double check that this works before release.

;BUGS:
; 1. Having Firefox open, starting the app, closing FF, and then trying to do initialize doesn't work
;    I'm pretty sure it's getting stuck in a WinWaitActive() of some sort. So probably in the MakeActive
;    loop
; 2. There's a bug with EnableEntireImageDialog() where it asks twice whether or not the dialog is enabled.
;    Cases that work:
;    a. Browser is open, FootnoteReap open/closed/reopened, it asks if entireimagedialog is up (saying yes or no)
;       works in both cases. It does the right thing.
;    b. Browser is closed, FootnoteReap is started first, footnotereap loads a page and then asks, if the dialog
;       is up. This is a bug. It should know since it just had to launch a browser that it can't be open.
; 3. There's an infinite loop somewhere in the main download loop.
; 4. There may be a race condition where a person pauses and if a person hits start a second afterwards. 
;    Might want to test for this.
; 5. The console application breaks the about dialog. Actually the about dialog seems to be broken probably more
;    due to moving the code around with all the globals at the top and the functions rejiggered to get rid
;    of the warnings. 
; 6. HUGE bug -- IsEntireImageUp when called when "Select location for download" is up ... ends up clicking
;    one of the filenames. This causes it to use an old file name. THen it thinks it tries to not overwrite
;    and since the state is now different it can't even progress. This is a big issue. To repro use Google
;    Book Downloader. That seems to slow the connection down significantly.
; 7. Somehow CTRL is getting stuck due to the console routines? 

#include <WindowsConstants.au3>
#include <GuiMenu.au3>
#include <GUIConstantsEx.au3>
#include <GuiConstants.au3>
#include <INet.au3>
#include <IE.au3>
#include <file.au3>
#include <date.au3>
#include <process.au3>
#Include <Array.au3>
#Include <Memory.au3>
;#include <nomadmemory.au3>
;#include <Console.au3>
#include <misc.au3>
#include "_CSVLib.au3"

;for about
#include <StaticConstants.au3>
#include <ButtonConstants.au3>

;----------------- Global Definitions -----------------
Const $version = "0.0.1.3"
Const $buildnum = "17"

Dim $answer = 0
Global $gNT = 1
Global $gOffset = 172
;Global $gVerbosity
Global $gCWD = @WorkingDir
Global $gKeyName = "HKEY_CURRENT_USER\SOFTWARE\FoonoteReaper"
Global $gChanges = 0
;Global $gChangesLabel
Global $gButton
Global $gWindow
Global $label5
Global $label6
Global $gMakeChangesButton
Global $param1 ;For functions that are called dynamically

;----Establish all app states here----
Global $gFirstEntry = true
Global $gInitialized = false ;Used primarily to handle graphical "init" button. This somewhat mimics $gPositionsValid
Global $gPositionsValid = false ;Are all Firefox footnote.com buttons configured properly? More specifically is $gDownloadPosition correct?
Global $gSaveImageDialogUp = false
Global $gPaused = false
Global $gRunning = false ;the program doesn't have to be executing the download functions so this is necessary
Global $gBrowserActiveBeforeFootnoteReap = false
Global $gSavedClipboard = false
;-------------------------------------

Global $gDebug = true
Global $gDebugRegSz = "gDebug"

Global $gSleepMultiplier = 1
Global $gSleepMultiplierRegSz = "gSleepMultiplier"
Global $gWaitDelay = 250	; this is the default: Opt("WinWaitDelay", 250)        ;250 milliseconds
Global $gWaitDelayRegSz = "gWaitDelay"

Global $gSendKeyDelay = 5
Global $gSendKeyDelaySz = "gSendKeyDelay"
Global $gSendKeyDownDelay = 5
Global $gSendKeyDownDelaySz = "gSendKeyDownDelay"

Global $gSavetoDirectory = ""
Global $gSavetoDirectoryRegSz = "gSaveToDirectory"
Global $gCurrentSavetoDirectory = ""
Global $gCurrentSavetoDirectoryRegSz = "gCurrentSavetoDirectory"

Global $gBaseDomain = "fold3.com"
Global $gBaseURL = "http://www." & $gBaseDomain & "/"
Global $gInitialURL = $gBaseURL & "image/#1|7276022" ;old escaped string "http://www.footnote.com/image/{#}1|7276022"
Global $gPrevURL = "" ; I can dynamically determine if a person was moving fowards or backwards with this information. If the current url and the backbutton leads to the prev url then that means the person is navigating forwards.
Global $gPrevURLRegSz = "gPrevURL"
Global $gCurrentURL = $gInitialURL
Global $gCurrentURLRegSz = "gCurrentURL"
Global $gCurrentDocumentStartURL = $gInitialURL
Global $gCurrentDocumentStartURLRegSz = "gCurrentDocumentStartURL"

Global $gFileExtension = "jpg"	;What if we do mixed extensions at some point?

;_For the foreeeable future I'm going to compile the application as a console app. So this isn't necessary since 
;_a console app will always spawn a terminal whether I want it or not.

;global $gLoggerEnabled 			;Should I default this to: = false
;global $gLoggerEnabledRegSz = "gLoggerEnabled"
global $gLoggerIgnoreLevel
global $gLoggerIgnoreLevelRegSz = "gLoggerIgnoreLevel"


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


;--------Browser details--------------
Global $gProgramName = "Internet Explorer" ;"Firefox"
Global $gExeName = "iexplore.exe" ;"firefox.exe"
Global $gTaskIdentifier = "Internet Explorer" ;"Firefox"
Global $gRegistryProgramPathSz = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\iexplore.exe"
;"HKEY_LOCAL_MACHINE\SOFTWARE\Clients\StartMenuInternet\FIREFOX.EXE\shell\open\command"
Global $gBrowserWindowId = -1

Global $gProgramPathSz = "gProgramPath"
Global $gProgramPath = ""

Dim $gWinPos[2] = [0, 0]
Dim $gWinSize[2] = [0, 0]
Dim $gGuiItem[4][4]

Dim $gBrowserWinPos[2] = [0, 0]
Dim $gBrowserWinSize[2] = [0, 0]
;----End Browser details-------------


;----------- Statistics -------------
global $gStartResumeTotalPageCount = 0
global $gStartResumeTotalPageCountRegSz = "gStartResumeTotalPageCount"
global $gStartResumeTotalDocCount = 0 
global $gStartResumeTotalDocCountRegSz = "gStartResumeTotalDocCount"
global $gCumulativeAvgTimeToDownload = 0
global $gOverallAverageTimeToDownloadRegSz = "gCumulativeAvgTimeToDownload"


global $gStartResumeSessionPageCount = 0
global $gStartResumeSessionDocCount = 0
global $gStartResumeTotalSessionPageCount = 0
global $gStartResumeTotalSessionDocCount = 0
global $gAvgTimeToDownload = 0 
;--------- End Statistics -----------


;---------GUI elements---------------
Global $commands

Global $fileitem, $saveitem, $loaditem
Global $dashitem
Global $startitem, $pauseitem
Global $exititem

Global $edit
Global $registrationitem
Global $setitem, $downloaditem, $nextitem, $previtem , $entireimageitem 
Global $checkitem, $checkdownloaditem, $checknextitem, $checkprevitem, $checkentireimageitem
Global $verifybuttons

Global $help, $projectitem, $aboutitem 

Global $initializebutton 
;-------End GUI elements-------------


;---------Global Labels--------------
Global $label_select_location = "Select location" ; possibly add: "for download" ?
Global $label_select_location_for_download = "Select location for download"
Global $label_save_as = "Save As"
Global $label_confirm_save_as = "Confirm Save As"
;--------Emd Global Labels--------------


Global $gOriginalClipboard = ""
Global $gCSVArray
;----------------End Global Definitions-----------------


Global Enum Step +2 $EINFINITELOOPDBG=1, $EVERBOSE, $ETRACE, $EASSERT, $EUNHANDLED, $EINTERNAL, $EUSER
Global Enum Step +2 $ENOTHING = 0, $EUSERVERBOSE = 12
Global $gDisableLoggerLevels = $ENOTHING


Func _ConsoleWrite($string)
	ConsoleWrite($string)
	;if($gLoggerEnabled) then _Console_Write($string)
EndFunc


Func OnOffOrError($keyname, $valuename)
	Logger($ETRACE, "OnOffOrError(" & $keyname & "," & $valuename & ")", false)
	$temp = RegRead($keyname, $valuename)
	;$error = @Error
	If $temp = "" AND @Error Then
		;If $error > 0 Then  $error = -($error + 2 )
		Logger($EVERBOSE, "@Error: " & @Error, false)
		return -1
	EndIf
	if($temp = "-1") then
		;XT: Never seen this come up remove eventually?
		Logger($EUNHANDLED, "FIX ME: Returning a value of -1 rather than an ERROR as -1!!!!!", true)
	EndIf
	return $temp
EndFunc   ;==>OnOffOrError


Func InitializeOrReadRegistryEntry($keyname, $regsz, ByRef $global, $type = "REG_SZ")	
	Logger($ETRACE, "InitializeOrReadRegistryEntry(" & $keyname & "," & $regsz & "," & $global & "," & $type & ")", false)
	Local $read = OnOffOrError($keyname, $regsz)
	if($read <> -1) then 
		$global = $read
	else 
		RegWrite($keyname, $regsz, $type, $global)
	endif
	return $global
EndFunc


;Technically I use two types of Asserts(). Ones where I want to evaluate a condition.
;And another where a condition has already been satisfied that is an edge case where
;I attempt to do something to address it, but I expect there might be bad behavior. 
;For the second type just use either:
;  Logger($EASSERT, "Year is in a nonstandard/unknown format: " & $year, true, 60)
;   Or
;  AssertMsg()
Func AssertMsg($msg, $bMsgBox = true, $timeout = 60)
	Assert(false, "AssertMsg:", $msg, $bMsgBox, $timeout)
EndFunc
	
	
Func Assert($expression, $textExpression, $msg, $bMsgBox = true, $timeout = 60)		
	;Even though I can execute an expression locally:
	;  if(_Iif(IsString($expression), Execute($expression), $expression))
	;If it's not composed of global values I would need to pass in all the parameters to do the 
	;evaluations. This is overkill. Since we don't have any preprocessor features I just 
	;duplicate the expression first to evaluate the condition locally in the call and second 
	;to give a text representation to display what was being evaluated in the assert popup
	
	if(NOT $expression) Then
		Logger($EASSERT, $textExpression & @CRLF & $msg, $bMsgBox, $timeout)
		return true
	else 
		return false
	EndIf
EndFunc


Func Logger($code, $msg, $bMsgBox, $timeout = 0)
	;Overall levels will be:
	; 0. nothing
	; 1. Infinite loop patterns
	; 3. Verbose output
	; 4. 
	; 5. Traces
	; 6. 
	; 7. Asserts
	; 8.
	; 9. Unhandled exceptions
	; 10.
	; 11. Internal errors
	; 12. User messages
	; 13. User level messages.
	if($gDisableLoggerLevels >= $code and NOT IsLoggerCodeExempt($code)) then return
	Select
		Case $code = $EINFINITELOOPDBG
			_ConsoleWrite($msg)	;the $msg acts as a "pattern" to print
		Case $code = $EVERBOSE
			if $bMsgBox then MsgBox(64, "Verbose", $msg, $timeout);
			_ConsoleWrite("Verbose: " & $msg & @CRLF)
		Case $code = $ETRACE
			if $bMsgBox then MsgBox(64, "Trace", $msg & @CRLF, $timeout);
			_ConsoleWrite("Trace: " & $msg & @CRLF)
		Case $code = $EASSERT
			if $bMsgBox then MsgBox(64, "Assert", $msg & @CRLF, $timeout);
			_ConsoleWrite("Assert: " & $msg & @CRLF)
		Case $code = $EUNHANDLED ;was 1
			if $bMsgBox then MsgBox(64, "Unhandled Exception", $msg, $timeout);
			_ConsoleWrite("Unhandled Exception: " & $msg & @CRLF)
		Case $code = $EINTERNAL ;was 5
			if $bMsgBox then MsgBox(48, "Internal Error", $msg, $timeout);
			_ConsoleWrite("Internal Error: " & $msg & @CRLF)
		Case $code = $EUSERVERBOSE
			if $bMsgBox then MsgBox(48, "User Verbose", $msg, $timeout);
			_ConsoleWrite("UVerbose: " & $msg & @CRLF)
		Case $code = $EUSER
			if $bMsgBox then MsgBox(48, "Notification", $msg, $timeout);
			_ConsoleWrite("Notification: " & $msg & @CRLF)
		Case Else
			if $bMsgBox then MsgBox(64, "Unknown Error Level:", "(Err#:" & $code & "): " & $msg & @CRLF, $timeout);
			_ConsoleWrite("Unknown Error Level: (#" & $code & "): " & $msg & @CRLF)
	EndSelect
EndFunc   ;==>Logger


Global $gExceptionArray[1]
Global Enum Step +1 $EADD, $EREMOVE
Func SetLoggerIgnoreException($newArray, $operation)
	Logger($ETRACE, "SetLoggerIgnoreException(" & $newArray & ", " & $operation & ")", false)
	;This routine assumes the user is smart enough to not add duplicates in the same call
	if(NOT IsArray($newArray)) then return
	$completed = 0 
	$newmax = UBound($newArray)-1
	
	if($gExceptionArray[0] = "") Then
		if($operation = $EADD) Then
			$gExceptionArray[0] = $newArray[0]
		Else
			;nothing to remove
			Return
		EndIf
	endif
	
	$exceptionmax = UBound($gExceptionArray)-1
	
	for $I = 0 to $newmax
		for $J = 0 to $exceptionmax
			if($operation = $EREMOVE) Then
				$newmax = UBound($gExceptionArray)-1
				if($exceptionMax > $newmax and $J > $newmax) then
					$exceptionMax = $newmax
					ExitLoop
				endif
			endif
			if($newArray[$I] < $gExceptionArray[$J]) then
				if($operation = $EADD) then
					_ArrayAdd($gExceptionArray, $newArray[$I])
					$completed += 1
				Else
					ExitLoop	; if the value is less than the lowest value it doesn't exist in our exception list
				EndIf
			elseif($newArray[$I] = $gExceptionArray[$J]) then
				if($operation = $EADD) Then
					ExitLoop 	; it's already in our list
				Else
					_ArrayDelete($gExceptionArray, $J)
					$completed += 1
				EndIf
			elseif($newArray[$I] > $gExceptionArray[$exceptionmax]) then
				if($operation = $EADD) Then
					_ArrayAdd($gExceptionArray, $newArray[$I])
					$completed += 1
					ExitLoop
				Else
					ExitLoop  ;if the value is greater than our greatest value it doesn't exist in our exception list
				EndIf
			EndIf
		Next
	Next
	_ArraySort($gExceptionArray, 0)
	;_ArrayDisplay($gExceptionArray, "after SetLoggerIgnoreException()")
EndFunc


Func RemoveAllLoggerExceptions()
	Logger($ETRACE, "RemoveAllLoggerExceptions()", false)
	if($gExceptionArray[0] = "") Then
		Return	;nothing to do
	endif
	ReDim $gExceptionArray[1]
	$gExceptionArray[0] = ""
	;_ArrayDisplay($gExceptionArray, "after SetLoggerIgnoreException()")
EndFunc


Func IsLoggerCodeExempt($code)
	if($gExceptionArray[0] = "") then return False
	$max = UBound($gExceptionArray)-1
	for $I = 0 to $max
		if($code = $gExceptionArray[$I]) then return True
	Next
	return false
EndFunc


Global $gPushLevels[1]
Global Enum Step +1 $ENOP, $EPUSH, $EPOP
Func SetLoggerIgnoreLevel($code, $squelching, $op=$ENOP, $override = false)
;If $EPOP fails then it will use the $code as the new 
	Logger($ETRACE, "SetLoggerIgnoreLevel(" & $code & "," & $squelching & ")", false)
	if($override) then $gDisableLoggerLevels = $code
	Local $index, $max = UBound($gPushLevels)	
	if($op <> $ENOP) Then
		if($op = $EPUSH and $gDisableLoggerLevels <> $code) Then
			if($gPushLevels[0] = "" and $max = 1) Then
				$index = 0
				$gPushLevels[$index] = $gDisableLoggerLevels
			Else
				_ArrayAdd($gPushLevels, $gDisableLoggerLevels)
				$index = $max
			EndIf
			;ConsoleWrite($gDisableLoggerLevels & @CRLF)
			;_ArrayDisplay($gPushLevels, "after SetLoggerIgnoreLevel(push)")
		elseif($op = $EPOP) Then
			if($gPushLevels[0] <> "" and $max >= 1) Then
				$gDisableLoggerLevels = $gPushLevels[$max-1]
				if($max > 1) then
					_ArrayDelete($gPushLevels, $max-1)
				Else
					$gPushLevels[0] = ""
				endif
				;ConsoleWrite($gDisableLoggerLevels & @CRLF)
				;_ArrayDisplay($gPushLevels, "after SetLoggerIgnoreLevel(pop)")
				return
			Else
				Logger($EVERBOSE, "Nothing to pop, using $code: " & $code, false)
				;TODO: This is why this is a 
			endif
		EndIf
	endif
	if($squelching = true) then 
		;When squelching we only restrict more not less. This is necessary
		;for the release build when the default log level is very restrictive.
		if($code > $gDisableLoggerLevels) then 
			$gDisableLoggerLevels = $code
		elseif($code <= $gDisableLoggerLevels and $op = $EPUSH) Then
			;The squelch failed so we need our old level back.
			_ArrayDelete($gDisableLoggerLevels, $index)
		endif
	Else
		;The setting we read in from the registry determines how low the logger can go
		if($gLoggerIgnoreLevel > $code) Then
			if($op = $EPUSH and $gLoggerIgnoreLevel = $gPushLevels[$index]) Then
				_ArrayDelete($gDisableLoggerLevels, $index)
			endif
			$gDisableLoggerLevels = $gLoggerIgnoreLevel
		Else
			$gDisableLoggerLevels = $code
		endif
	endif
	;ConsoleWrite($gDisableLoggerLevels & @CRLF)
EndFunc   ;==>SetLoggerIgnoreLevel


Func PopLoggerIgnoreLevel($squelching=false)
	Logger($ETRACE, "PopLoggerIgnoreLevel(" & $squelching & ")", false)
	SetLoggerIgnoreLevel($gDisableLoggerLevels, $squelching, $EPOP)
EndFunc


Func PushLoggerIgnoreLevel($code, $squelching)
	Logger($ETRACE, "PushLoggerIgnoreLevel(" & $code & "," & $squelching & ")", false)
	return SetLoggerIgnoreLevel($code, $squelching, $EPUSH)
EndFunc 

#cs 
;------------- Test Code----------------
;SetLoggerIgnoreLevel($EUSER-1, true)
SetLoggerIgnoreLevel($EVERBOSE, true)
Dim $testArray[2] = [$EASSERT, $EINFINITELOOPDBG]
Dim $testArray2[1] = [$EINFINITELOOPDBG]
;Dim $testArray3[1] = [$ETRACE]
;SetLoggerIgnoreException($testArray, $EADD)
;SetLoggerIgnoreException($testArray2, $EREMOVE)
;SetLoggerIgnoreException($testArray3, $EADD)
PushLoggerIgnoreLevel($ETRACE, false)
PushLoggerIgnoreLevel($EASSERT, false)
PopLoggerIgnoreLevel()
PopLoggerIgnoreLevel()
PopLoggerIgnoreLevel()
Logger($EINFINITELOOPDBG, "ccccccccccccccccc", false)
RemoveAllLoggerExceptions()
;------------- End Test Code----------------
#ce


Global Enum Step +1 $ECLEAN_EXIT = 0, $EEMERGENCY_EXIT, $EPREMATURE_EXIT, $E3_EXIT, $E4_EXIT, $EINTERNALERR_EXIT
Func CleanupExit($code, $msg, $bMsgBox)
	Logger($ETRACE, "CleanupExit()", false)
	;IMPL -- two params? code, message, msgbox and then write location or other details.
	;the code will determine if we exit (i.e. 5)
	;Exit(5)  ;worst error
	;0 is (verbosity just normal clean exit?)	
	;1 is (perhaps the user quitting prematurely?)
	;2 is (a problem where the program has some unsolvable state and must quit)
	;3-4 ... ?
	;5 is internal error (worst case scenario, something really screwed up worse than premature like bad data)
	Select
		Case $code = $ECLEAN_EXIT
			if $bMsgBox then MsgBox(48, "Clean Exit", $msg);
			_ConsoleWrite("Clean Exit: " & $msg)
		Case $code = $EEMERGENCY_EXIT
			if $bMsgBox then MsgBox(48, "Emergency Exit", $msg);
			_ConsoleWrite("Emergency Exit: " & $msg)
		Case $code = $EPREMATURE_EXIT
			if $bMsgBox then MsgBox(48, "Premature Exit", $msg);
			_ConsoleWrite("Premature Exit: " & $msg)
		Case $code = $EINTERNALERR_EXIT
			if $bMsgBox then MsgBox(48, "Internal Error", $msg);
			_ConsoleWrite("Internal Error Exit: " & $msg)
	EndSelect
	;if($gLoggerEnabled) then _Console_Free()
	if($gSavedClipboard and StringCompare($gOriginalClipboard, "") <> 0) Then
		Local $ret = MsgBox(4, "Restore Clipboard", "Would you like to restore the old clipboard data (below) before quitting?" & @CRLF & @CRLF & StringGetLenChars($gOriginalClipboard, 200), 60)
		if($ret = 6 or $ret = -1) Then
			ClipPut($gOriginalClipboard)
		endif
	endif
	Exit($code)
EndFunc   ;==>CleanupExit



Global Const $WindowMargin[2] = [16, 36]
Global Const $MF_BYCOMMAND = 0x00000000
;Global Const $MF_OWNERDRAW			= 0x00000100

;===========================================================================================
; Function Name: 	FixClientSize
; Description:		Adds the 16px and 36px margins to get the actual window size
; Syntax:           FixClientSize($coords)
; Parameter(s):     $coords[2]	-	The results from WinGetClientSize()
; Requirement(s):   None
; Return Value(s):  On Success	-	1 (true) is returned
;					On Failure	-	0 (false) is returned.
; Date:				2011/08/13
; Author:			DJD
;===========================================================================================
Func FixClientSize(ByRef $size)
	Logger($ETRACE, "FixClientSize()", false)
	if(Not IsArray($size)) then return False
	$size[0] += $WindowMargin[0]
	$size[1] += $WindowMargin[1]
	return true
EndFunc   ;==>FixClientSize


;================= Window Routines ====================

Func ModifyMenu($hMenu, $nID, $nFlags, $nNewID, $ptrItemData)
	Logger($ETRACE, "ModifyMenu()", false)
	Local $bResult = DllCall('user32.dll', 'int', 'ModifyMenu', _
			'hwnd', $hMenu, _
			'int', $nID, _
			'int', $nFlags, _
			'int', $nNewID, _
			'ptr', $ptrItemData)
	Return $bResult[0]
EndFunc   ;==>ModifyMenu

Func SetOwnerDrawn($hMenu, $MenuItemID, $sText)
	Logger($ETRACE, "SetOwnerDrawn()", false)
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
	Logger($ETRACE, "_FileSearch(" & $S_ROOT & "," & $S_FILEPATTERN & ")", false)
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




Func SetArrays()
	Logger($ETRACE, "SetArrays()", false)
EndFunc   ;==>SetArrays


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


;Add a parameter to specify sleep time for GetClip?
Func GetClip(ByRef $clip, $sendCtrlC = false, $stripCR = true, $count = "")
	Logger($ETRACE, "GetClip()", false)
	
	;Santize and store old input
	if($sendCtrlC) then
		if(not $gSavedClipboard) Then
			$gOriginalClipboard = ClipGet()
			Logger($EVERBOSE, "$gOriginalClipboard: " & $gOriginalClipboard, false)
			$gSavedClipboard = true
		endif
		if(ClipPut("") = 0) then  ; May want to make sure we have something we can check for.
			Logger($EUNHANDLED, "ClipPut() failed to empty the clipboard", false)
		endif
		Send("{CTRLDOWN}")
		Send("c")
		Send("{CTRLUP}")
		Sleep(200 * $gSleepMultiplier) ; give it some time to grab it as the transfer might take a moment
	endif
	
	$clip = _Iif($stripCR, StringStripCR(ClipGet()), ClipGet()) 
	$ret = @error
	
	
	if($gDisableLoggerLevels < $EUNHANDLED) then 
		ConsoleWrite("THIS IS THE TEMPCLIP: " & $clip & @CRLF)
	endif
	
	if($ret <> 0) then
		if($ret = 1) then
			Logger($EVERBOSE, "err#:" & $ret & " clipboard (#" & $count & ") empty clipboard", false)
		elseif($ret = 2) then
			Logger($EVERBOSE, "err#:" & $ret & " clipboard (#" & $count & ") non-text entry on clipboard", false)
		elseif($ret > 2 And $ret <= 4) then
			Logger($EVERBOSE, "err#:" & $ret & " clipboard (#" & $count & ") cannot access clipboard", false)
		else
			Logger($EVERBOSE, "err#:" & $ret & " clipboard (#" & $count & ") unknown error", false)
		endif
	endif
	
	;Retore the original clip
	;if($sendCtrlC) then 
	;	ClipPut($oldclip)
	;	if(StringCompare(ClipGet(), $oldclip) <> 0) Then
	
	return $ret
EndFunc   ;==>GetClip


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

;========================= TOGGLE FUNCS ===========================
Func TogglePause()
	;There should only be one state where it's neither running nor paused. This is
	;when a person does a load. So I should probably
	;SetLoggerIgnoreLevel($ENOTHING)
	Logger($ETRACE, "TogglePause()", false)
	if($gRunning) Then
		$gPaused = True
		Logger($EUSERVERBOSE, "Please give footnotereap 10 to 20 seconds to finish executing and come to a stop ...", false)
		;ConsoleWrite("DUSTIN HERE: " & $gPaused)
		GuiCtrlSetState($initializebutton, $GUI_SHOW)
#cs
;It's probably better to just have it exclusively pause. No toggle.
	Else
		if($gPaused = true) Then
			;$gPaused = False
			;$gRunning = True
			return StartResume()
		endif
#ce
	EndIf
EndFunc   ;==>TogglePause


;~ Func Stop()
;~ 	;IMPL
;~ 	Logger($ETRACE, "Stop()", false)
;~ EndFunc   ;==>Stop

Func EmergencyExit()
	Logger($ETRACE, "EmergencyExit()", false)
	CleanupExit($EEMERGENCY_EXIT, "Hotkey shutdown...", false)
EndFunc


Func StartResumeInit()
	; returns false if error, true if success
	
	;Questions: Best time do a loadoldwindow?
	
	;Are we initialized? (have a window up)
	;	if the instance claims so do we have a window up?
	;	is it a valid page?
	;	is it the page we remember being on?
	;If we are do we have any button data? (in the globals, obj arrays)?
	;Is the button data valid?
	;	if not do we have anything in the registry?
	;	is it valid?
	;	if not lets setdownloadposition()
	;Do we have all the dialogs up that we need to move forward?
	;Is our current page we're already handled?
	
	Local $max = Ubound($gFootnoteButtonArray) - 1
	Local $registryInitialized = (CountRegButtonsSet() = ($max + 1))
	Logger($EVERBOSE, CountRegButtonsSet() & "    " & $registryInitialized, false)
	
	;Do we have a window up?
	if(LoadBrowserInstance() = true) Then
		;TODO: Make sure I set $gBrowserWindowId to 0 in all the spots where I try to LoadBrowserInstance
		;      when we get a true response when we shouldn't be getting true.
		$gBrowserWindowId = 0 ;We get the gBrowserWindowId in MakeActive()
		$gSaveImageDialogUp = false
		
		;We didn't, but we should now. Are we initialized?
		if($gInitialized Or $gPositionsValid) Then ;$gPositionsValid should always be false here...
			;the browser must of crashed or been closed. So lets check to make sure now that we
			;reloaded our window that everything's correct.
			if(MakeActive() = false) then
				Logger($EUSER, "Couldn't restart and activate the browser. Try again.", true) ;TODO: Add timer?
				return false
				;TODO: Need to handle this case
			EndIf
			
			InitializePage(false)
			if(WindowResizedOrMoved() And $registryInitialized) Then
				;The new window doesn't match the internal array/globals. Lets try to get
				;old registry values.
				if(LoadOldWindowState(true)) Then
					;since we know we crashed we know it has to be off. So lets just enable it?
					;TODO: test this ... (fake crash the app and see what happens)
					$gSaveImageDialogUp = false
					Sleep(1000 * $gSleepMultiplier)
					ConsoleWrite("DUSTIN: here")
					EnableEntireImageDialog()
					#cs
						if($gSaveImageDialogUp = true) then
						;internally it's true so it won't toggle properly without a force
						_EnableOrDisableEntireImageDialog(true, true)
						EndIf
					#ce
				Else
					;We can't continue till we know where the buttons are
					VerifyButtons(0)
				endif
			Else
				;Since the window didn't change on reload we can reuse the old data.
				$gPositionsValid = true
				;Now we can reenable the dialog
				EnableEntireImageDialog()
			EndIf
		EndIf
	Else
		;Xtraeme: This is pretty much defunct code ... I probably should remove it at some point.
		if($gInitialized And WindowResizedOrMoved()) Then
			Logger($EUNHANDLED, "$gInitialized And WindowResizedOrMoved() -- do something?", false)
			;REPRO: delete registry, Initialize, resize window, click Start/Resume
			;		Perhaps change the notification to, "The window has changed. Do you want to restore the old window size and position? Clicking 'Yes' will reload the old positions."
			#cs
				If(MsgBox(4, "Confirmation Dialog", "Footnote Reaper appears to be initialized. Clicking 'Yes' will reload everything. Continue?") = 7) Then
				return
				EndIf
				$gInitialized = False
				$gPositionsValid = false
			#ce
		EndIf
	EndIf
	
	;Is this our first attempt to initialize the program?
	if($gInitialized = false) then
		Local $loadSuccessful = false
		GuiCtrlSetState($initializebutton, $GUI_HIDE)
		
		if($registryInitialized) Then
			$loadSuccessful = LoadOldWindowState(true)
		EndIf

		;BUG: There's a bug where if a person chooses to not reload everything that it doesn't
		;     enable the "Save Image" and "Entire Image" dialog
		;Previously just Initialize() which defaults to maximizing the screen (decided I don't like that)
		$ret = Initialize(false, "", false, true)
		If($ret <> false) Then
			VerifyButtons(_Iif($loadSuccessful, 0, 1), false) ;_Iif($gSaveImageDialogUp = true And $ret <>2, 0, 1)
			;GuiCtrlSetState($initializebutton, $GUI_HIDE)
			DirectoryManager()
			$gInitialized = true
			$gFirstEntry = false
			RegWrite($gKeyName, "gFirstEntry", "REG_DWORD", $gFirstEntry)
		Else
			;BUG: If a person starts the application, does a normal button initialize. Then later clicks
			;     start. The program will reshow the initialize button. I may just need to include lots of
			;     states. One for the button one for the global init state
			if($gPositionsValid = false) then
				GuiCtrlSetState($initializebutton, $GUI_SHOW)
			endif
		EndIf
	EndIf
	return true
EndFunc   ;==>StartResumeInit


Func MonthNameToNumber($monthName, $prependZero = false)
	PushLoggerIgnoreLevel($ENOTHING, false)
	Logger($ETRACE, "MonthNameToNumber(" & $monthName & "," & $prependZero & ")", false)

	if( StringLeft($monthName, 1) = "0" Or StringLeft($monthName, 1) = "1") then return $monthName
	$month = 0
	Select
		Case $monthName = "january"
			$month = 1
		Case $monthName = "february"
			$month = 2
		Case $monthName = "march"
			$month = 3
		Case $monthName = "april"
			$month = 4
		Case $monthName = "may"
			$month = 5
		Case $monthName = "june"
			$month = 6
		Case $monthName = "july"
			$month = 7
		Case $monthName = "august"
			$month = 8
		Case $monthName = "september"
			$month = 9
		Case $monthName = "october"
			$month = 10
		Case $monthName = "november"
			$month = 11
		Case $monthName = "december"
			$month = 12
		Case Else
			;Possible that we might get jan, feb, etc. Also this is necessary for season name
			Logger($EVERBOSE, "MonthNameToNumber() expected a full month name, but received: " & $monthName, false)
			$month = $monthName
	EndSelect
	if($prependZero And IsNumber($month) And $month < 10) then $month = "0" & $month
	return $month
	PopLoggerIgnoreLevel()
EndFunc   ;==>MonthNameToNumber


Global $gDynamicCreateNewDirectory = true
Func GetDirectoryNameFromURL($url)
	Logger($ETRACE, "GetDirectoryNameFromURL(" & $url & ")", false)
	;strlen(http://www.footnote.com/image/#1) = 33
	;strlen(http://www.fold3.com/image/#1 = 30
	Local $len = StringLen($gBaseURL & "image/#1") + 1
	Local $id = StringTrimLeft($url, $len)	;gCurrentURL
	Local $array = 0
	Local $dir = ""
	Local $ret = 0 
	Local $year, $monthseason, $docid, $location
	
	$arraySearch = _CSVSearch($gCSVArray, $id, "|")
	;_ArrayDisplay($arraySearch, 'Your file with "|" as delimiter')
	if($arraySearch <> 0 And $arraySearch[0][0] <> 0) Then
		Local $index = 1
		for $I = 1 to $arraySearch[0][0]
			Dim $larray = StringSplit($arraySearch[$I][2], "|", 1)
			if($larray[1] = $id) Then
				$array = $larray
				ExitLoop
			EndIf
		next
	EndIf
	
	Logger($EUSER, "Found new document id#: " & $id, false)
	if($array <> 0 And IsArray($array) And $array[0] > 0) Then
		$year = $array[2] ;[1]
		$monthseason = $array[3] ;[2]
		$docid = $array[1]
		$location = $array[4]
		if($docid <> $id) then Logger($EUSERVERBOSE, "Data mismatch in CSV. $docid (" & $docid & ") isn't the same as $id (" & $id & ").", true)
	Else
		;Logger($EUNHANDLED, "Found new document id #( " & $id & ") that doesn't exist in footnote CSV database. Skipping entry.", true)
		if($gDynamicCreateNewDirectory) then
			;Only notify the user once per session*
			;TODO: Try to automate closing any extra tabs?
			Local $timeout = 0
			if(OnOffOrError($gKeyName, "gDynamicCreateNewDirectory") = 1) then $timeout = 120
			Logger($EUSER, "Since the CSV is missing data about document (#" & $id & "). We need to dynamically fetch the data from the browser. To do this requires there be only one tab active. Please close all other open tabs." & @CRLF & "(Note: this feature only works with IE 9 and greater)", true, $timeout)
			RegWrite($gKeyName, "gDynamicCreateNewDirectory", "REG_DWORD", true)
			$gDynamicCreateNewDirectory = False
		endif
			
		$oIE = _IEAttach($gBrowserWindowId, "HWND") 
		;MsgBox(0, "The URL", _IEPropertyGet ($oIE, "locationurl"))
		$bodyText = _IEBodyReadText($oIE)
		;Assert(true, $bodyText)
		
		$year = StringRegExpMatch($bodyText, "Year:\s*(\d+)", 1, "xxxx")
				
		$monthArray = StringRegExp($bodyText, "Month Season Number:\s*(\d+)", 1)
		if(@error > 0) then 
			;Logger($EUSER, @error, 1)
			$monthseason = "xx"
		Else
			$monthseason = $monthArray[0]
			if($monthseason > 12) Then
				$seasonArray = StringRegExp($bodyText, "Month:\s*(\w+)", 1)
				Assert(@error = 0, "@error = 0", "month season number ($monthseason) > 12, but season is undefined")
				$monthseason = $seasonArray[0]
				Logger($EVERBOSE, "season name is: " & $monthseason, false)
			endif
		endif
		
		$location = StringRegExpMatch($bodyText, "(?m)Location:\s*(.*)\s{2,}$", 1, "[BLANK]")		
		$incident = StringRegExpMatch($bodyText, "Incident Number:\s*(\d+)", 1, "")
		
		$docid = $id
		;ConsoleWrite($year & @CRLF)
		;ConsoleWrite($monthseason & @CRLF)
		;ConsoleWrite($location & @CRLF)
		;ConsoleWrite($incident & @CRLF)
		if($incident <> "") Then
			$location = $location & " (#" & $incident & ")"
		endif
		$location = StringRegExpReplace($location, "&", "and")
		$location = StringRegExpReplace($location, '"', "''")
		;SetError(1)
	endif
	
	;Windows doesn't allow files with periods and no subsequent characters at the end of the filename.
	$location = StringRegExpReplace($location, "(?m)\.$", "")
	
	if(StringCompare($year, "[illegible]") = 0 or StringCompare($year,"[blank]") = 0) Then 
		AssertMsg("Year is in a nonstandard/unknown format: " & $year, true, 60)
		$year = "xxxx"
	EndIf
	
	if(StringCompare($monthseason, "[illegible]") = 0 or StringCompare($monthseason, "[blank]") = 0 or $monthseason = "0") Then
		Logger($EUSERVERBOSE, "Month unclear tag: " & $monthseason, true, 60)
		$monthseason = "xx"
	else
		$monthseason = MonthNameToNumber($monthseason, true)		
	EndIf
	
	$dir = $gSavetoDirectory & "\" & $year & "." & $monthseason & " - " & $docid & " - " & $location
	return $dir
EndFunc


Func CreateNewDirectory($name = "")
	Logger($ETRACE, "CreateNewDirectory()", false)
	Local $dir = ""
	
	if(StringCompare($name, "") = 0) then
		$dir = GetDirectoryNameFromURL($gCurrentURL)
	Else
		$dir = $name
	EndIf
	
	if(Not FileExists($dir)) Then 
		Logger($EUSER, "Creating directory: " & $dir, false)
		$ret = DirCreate($dir)
	EndIf
	
	if(FileExists($dir)) Then
		Logger($EUSERVERBOSE, "Committing $gCurrentSavetoDirectory to registry...", false)
		$gCurrentSavetoDirectory = $dir
		RegWrite($gKeyName, $gCurrentSavetoDirectoryRegSz, "REG_SZ", $gCurrentSavetoDirectory)
	EndIf
	
	return $dir
	;_CSVGetRecords($gCWD & "\bluebook\bluebook-page1docs.psv", -1, -1, 1)
EndFunc   ;==>CreateNewDirectory


Func DirectoryManager()
	Logger($ETRACE, "DirectoryManager()", false)
	Local $temp = ""
	if(StringCompare($gSavetoDirectory, "") <> 0 and FileExists($gSavetoDirectory)) then return
	Do
		$temp = FileSelectFolder("Where would you like to save the " & $gBaseDomain & " image files?", "", 5, @MyDocumentsDir) ;$FileMask,
	Until($temp <> "" and @error <> 1)
	if(FileExists($temp)) then
		$gSavetoDirectory = $temp
		RegWrite($gKeyName, $gSavetoDirectoryRegSz, "REG_SZ", $gSavetoDirectory)
	endif
EndFunc   ;==>DirectoryManager


Func IsSameAsClip($text, $selectKeyCombo="")
	Logger($ETRACE, "IsSameAsClip(" & $text & ", " & $selectKeyCombo & ")", false)
	
	Local $tempClip = ""
	Local $counter = 3		;we try 3 times before we fail out
	
	if(StringCompare($selectKeyCombo, "") <> 0) Then
		Send($selectKeyCombo, 0)
	EndIf
	
	while(GetClip($tempClip, true) > 0 and $counter <> 0)
		$counter -= 1
	wend

	if(StringCompare($text, $tempClip) = 0 and $counter <> 0) Then
		return True
	EndIf
	
	return False
EndFunc


Func SetSaveDialogDirectory($dir, $clip)
	; Issue 6: 	Filename/Path gets prematurely shortened in the Save As dialog
	Logger($ETRACE, "SetSaveDialogDirectory(" & $dir & ", " & $clip & ")", false)
	Local $tempClip = ""
	Local Const $timeoutUpperBound = 3
	Local $timeout = $timeoutUpperBound
	
	Do
		Send($dir, 1)
		Sleep(300 * $gSleepMultiplier)
		if($timeout < $timeoutUpperBound-1) then
			Logger($EUSERVERBOSE, "The application may have lost focus. Try clicking inside 'File name:' textbox", false)
		endif
		$timeout -= 1
	until(IsSameAsClip($dir, "{END}{SHIFTDOWN}{HOME}{SHIFTUP}") or $timeout = 0)
	
	if($timeout = 0) Then
		Logger($EUNHANDLED, "SetSaveDialogDirectory(1676), Directory possibly not set correctly:" & $dir, 0)
	EndIf
	$timeout = $timeoutUpperBound
	
	Send("{ENTER}", 0)
	Sleep(1000 * $gSleepMultiplier)
	if(WinExists($label_select_location)) then ; Select location for download")) Then
		while(Not IsSameAsClip($clip, "{END}{SHIFTDOWN}{HOME}{SHIFTUP}") and $timeout <> 0)
			Send($clip, 1)
			Sleep(500 * $gSleepMultiplier)
			if($timeout < $timeoutUpperBound-1) then
				Logger($EUSERVERBOSE, "The application may have lost focus. Try clicking inside 'File name:' textbox", false)
			endif
			$timeout -= 1
		wend	
		if($timeout = 0) Then
			Logger($EUNHANDLED, "SetSaveDialogDirectory(1689), Filename possibly not set correctly:" & $clip, 0)
		endif
	EndIf
	;Logger($EUSERVERBOSE, "leaving SetSaveDialogDirectory(" & $dir & ", " & $clip & ")", false)
EndFunc


Func StringGetLenChars(ByRef $origstring, $outlen)
	Local $actuallen = StringLen($origstring)
	Logger($ETRACE, "StringGetLenChars(" & $actuallen & ", " & $outlen & ")", false)
	;_Iif($len <= 80, $origstring, StringTrimRight($origstring, $len-80))
	return _Iif($actuallen <= $outlen, $origstring, StringTrimRight($origstring, $actuallen-$outlen))
EndFunc


Func StringRegExpMatch($origstring, $pattern, $flag = 0, $errorstring = -1, $offset = 1)
	Logger($ETRACE, "StringRegExpMatch(" &  StringGetLenChars($origstring, 80) & ", " & $pattern & ", " & $flag & ", " & $errorstring & ", " & $offset & ")", false)
	Local $resultstring = ""
	$returnArray  = StringRegExp($origstring, $pattern, $flag, $offset)
	if(@error > 0) then 
		Logger($EUNHANDLED, "err: " & @error & ", using: " & $errorstring, false, 60)
		if($errorstring <> -1) Then
			$resultstring  = $errorstring
		endif
	Else
		$resultstring = $returnArray[0]
	endif
	return $resultstring
EndFunc


Global Enum Step +1 $ENODOC_NOPAGE_ERROR = 0, $ENEWPAGE, $ENEWDOC, $ESKIPPED
;Global $testOnce = true
Global $gDirectoryNotSet = false
Func StartDownloadImage()
	;Return codes: 0 error, 1 downloaded an image, 2 created a directory and downloaded image, 3 skipped a file.
	;seterror = 1, when we had to break out of the loop (possible event when a persons internet connection goes down)
	;Do a check to make sure this is set?
	Logger($ETRACE, "StartDownloadImage()", false)
	Local $clip = ""
	Local $dir = ""
	Local $lastFileSize = 0
	Local $currentFileSize = 0
	Local $origsecs = 0
	Local $count = 0
	Local $retCode = $ENODOC_NOPAGE_ERROR 
	Local $newurl = ""
	Local $page1 = "Page 1.jpg"
	
	do
		GetCurrentURL($newurl)
		;ConsoleWrite("Is this where we're stuck?")
		Sleep(200 * $gSleepMultiplier)
		if($count = 15) then return $retCode
		$count += 1
		;creating a few "text" loop patterns will help me locate where we're getting stuck
		Logger($EINFINITELOOPDBG, "44", false) 
	until(StringCompare($newurl, "") <> 0 And ValidFootnotePage($newurl))
	$gCurrentURL = $newurl
	$count = 0
	
	Logger($EUSERVERBOSE, "Currently working on URL: " & $gCurrentURL, false)
	MouseClick("left", $gEntireImageButton[0], $gEntireImageButton[1])
	Sleep(1000 * $gSleepMultiplier)
	
	;Logger($EUSERVERBOSE, Not WinExists("Select location"), true)
	while (Not WinExists($label_select_location) and Not WinExists($label_save_as)) ; or $testOnce = true) 
		;$testOnce = false
		;To handle the: 
		;	"Oops, we couldn't load information about this image"
		; And more common,
		; 	"We're sorry, it is taking longer than expected to load information about this image."
		; We should just try clicking to go back. Maybe we can also try adding another button for 
		; "close" and "try again"? That would be hard though because we don't know where they are
		; precisely.
		;Another condition that comes up is when the pane partially loads and the download "starts"
		; but it never seems to actually start grabbing data. Originally I thought a simple refresh 
		; would solve the issue, but it doesn't. Then I thought maybe navigating forward and backwards
		; might jostle the system. Unfortunately it seems when this happens next, prev, and current
		; all refuse to load. So the only solution then is tearing down the browser and reloading.
		; Kind of dramatic, but it's probably better than getting completely stuck.
		$count += 1
		if($count = 2) then 
			MouseClick("left", $gPrevButton[0], $gPrevButton[1])
		elseif($count = 10) Then
			Return $retCode
		endif
		IsSaveImageDialogUp(true)
		Logger($EUSERVERBOSE, "Didn't get the 'Select Location' dialog ... trying to work back to a good state", false, 10)
		$gSaveImageDialogUp = false
		EnableEntireImageDialog()
		Sleep(1000 * $gSleepMultiplier)
		MouseClick("left", $gEntireImageButton[0], $gEntireImageButton[1])
		Logger($EINFINITELOOPDBG, "zz", false) 
		Sleep(1000 * $gSleepMultiplier)
	Wend
		
;~ 	PushLoggerIgnoreLevel($EVERBOSE, false)
	GetClip($clip, true)
;~ 	PopLoggerIgnoreLevel()
	
	;BROWSER DEPENDENT ...
	;Send("{Tab}{Tab}{Tab}{ENTER}",0)
	;Consolewrite("clip: " & $clip & @CRLF)
	
	;TODO: On mom's box during the first init this came out as "Page 1" not "Page 1.jpg" causing it to think we had case #2
;~ 	Logger($EUSERVERBOSE, $gFileExtension, false)
	If(StringCompare(StringRight($clip, 3), $gFileExtension) <> 0) Then
		$page1 = "Page 1"
		Logger($EUSERVERBOSE, "No ." &  $gFileExtension & " in the 'Save As' dialog. Looking for: " & $page1, false)
	EndIf
;~ 	Logger($EUSERVERBOSE, $page1, false)
		
	if(StringCompare($clip, $page1) = 0) then
		;Create new directory
		$gCurrentDocumentStartURL = $gCurrentURL
		RegWrite($gKeyName, $gCurrentDocumentStartURLRegSz, "REG_SZ", $gCurrentDocumentStartURL)
		$dir = CreateNewDirectory()
		;if(@ERROR = 1) then
		;EndIf
		SetSaveDialogDirectory($dir, $clip)
		$retCode = $ENEWDOC
	elseif($gStartResumeSessionPageCount = 0 And StringCompare($clip, $page1) <> 0) Then
		;Need to make sure we have a sane directory
		
		Local $dir = GetDirectoryNameFromURL($gCurrentURL)
		Local $list = _FileListToArray($gSavetoDirectory)
		Local $index = 0
		Dim $finalDir[1] = [""]
		

		;Logger($EUSERVERBOSE, $dir, true)
		$partiallyCorrectName = StringRegExpMatch($dir, "(?m)\\([\d{4,}|xxxx].*)$", 1)
		;Logger($EUSER, $partiallyCorrectName, true)
		
		;The left hand side is usually year.month or dddd.dd
		$correctLeftHandSide = StringLeft($partiallyCorrectName, 7)
		;ConsoleWrite($correctLeftHandSide & @CRLF)
		
		;For nonstandard seasons ...
		if(Not Number(StringRight($correctLeftHandSide, 1))) Then
			$correctLeftHandSide = StringRegExpMatch($partiallyCorrectName, "(?m)([\d{4,}|xxxx]\.\w+)\s*\-\s+\d+\s+\-\s+(.*)$", 1)
			Logger($EUSERVERBOSE, "season is: $correctLeftHandSide = " & $correctLeftHandSide, false)
			Assert($correctLeftHandSide <> "", "$correctLeftHandSide <> """, true)
		endif

		$correctRightHandSide = StringRegExpMatch($partiallyCorrectName, "(?m)^.*\-\s+\d+\s+\-\s+(.*)$", 1)
		;Logger($EUSERVERBOSE, $correctRightHandSide, true)
		
		;ConsoleWrite($partiallyCorrectName & @CRLF)
		;ConsoleWrite($correctLeftHandSide & @CRLF)
		;ConsoleWrite($correctRightHandSide & @CRLF)
		
		$currentSaveToDirName = StringRegExpMatch($gCurrentSavetoDirectory, "(?m)\\([\d{4,}|xxxx].*)$", 1)
		
		;Check to see if the gCurrentSaveToDirectory possibly matches our partially corect name.
		;If it doesn't we don't consider the gCurrentSaveToDirectory as valid. 
		;TODO: This will have to be changed when I add automation.
		if(StringCompare(StringLeft($currentSaveToDirName, StringLen($correctLeftHandSide)), $correctLeftHandSide) = 0 and _ 
			   StringInStr($currentSaveToDirName, $correctRightHandSide) <> 0) Then
			   $finalDir[0] = $currentSaveToDirName
			   ;ConsoleWrite("finalDir[0]: " & $finalDir[0] & @CRLF)
		endif

		for $I = 0 to UBound($list)-1
			if(StringCompare(StringLeft($list[$I], StringLen($correctLeftHandSide)), $correctLeftHandSide) = 0 and _ 
			   StringInStr($list[$I], $correctRightHandSide) <> 0) Then
				;if(StringCompare($finalDir[$index], "") <> 0) then 
					;We iterate over the entire list to make sure there isn't a second or third match
					_ArrayAdd($finalDir, $list[$I])
					$index += 1
					Logger($EUSERVERBOSE, "Found possible directory match: " & $finalDir[$index], false)
					;ExitLoop
				;endif
			endif
		next
		
		Local $breg = _Iif(StringCompare($finalDir[0], "") <> 0, true, false)
		
		if($index > 1) Then
			;handle the case of numerous possible directories
			Local $I = 1
			if($breg) Then
				for $I = 1 to UBound($finalDir)-1
					if(StringCompare($finalDir[0], $finalDir[$I]) = 0) Then
						;We found our directory
						$dir = $gSavetoDirectory & "\" & $finalDir[$I]
						ExitLoop
					endif
				Next
				if($I = UBound($finalDir)) Then
					;we didn't find a matching directory
					Logger($EUSERVERBOSE, "Several similar directories were found, but none match the registry: " & $gCurrentSavetoDirectory, false)
					Logger($EUSERVERBOSE, "Recreating ...", false)
					$dir = CreateNewDirectory($gSavetoDirectory & "\" & $finalDir[0])
				endif
			Else
				;Give the person the option to choose?
				Local $selection = ""
				MsgBox(48, "Select An Entry", "Since several directories were found that could correspond to:" & @CRLF & @CRLF & $partiallyCorrectName & @CRLF & @CRLF & "On the next screen please select one of the entries and click the button that says 'Copy Selected' and close the dialog. More often than not you'll want to select the directory that has the most current modification date.")
				_RunDOS("start " & $gSavetoDirectory)
				Do
					_ArrayDisplay($finalDir, "List of Known Similar Directories", -1, 0, "", "|", "Index|Known Directories ([0] = last known good registry entry)")
					GetClip($selection)
					$selection = StringStripCR(StringRegExpMatch($selection, "(?m)\|([\d{4,}|xxxx].*)\s*$", 1))
				until(StringCompare($selection, "") <> 0)
				;AssertMsg($selection)
				$dir = CreateNewDirectory($gSavetoDirectory & "\" & $selection)
				WinActivate($label_select_location)
			endif
			
		elseif($breg Or $index = 1) then
			;handle the case of previous registry entry match and/or a directory match
			;AssertMsg("number: " & $index)
			;_ArrayDisplay($finalDir)
			
			;If the registry and directory are the same ...
			if(StringCompare($finalDir[0], _Iif($index = 1, $finalDir[$index], "fail")) = 0) Then
				;This is what should normally happen ...
				Logger($EUSERVERBOSE, "Everything looks as it should, the registry and directory structure both match.", false)
				$dir = $gSavetoDirectory & "\" & $finalDir[1]
			
			;or we have no registry but we do have a directory then ...
			elseif(not $breg and $index = 1) Then
				Logger($EUSERVERBOSE, "The registry is missing, but a directory matches.", false)
				$dir = $gSavetoDirectory & "\" & $finalDir[1]
			
			;If the registry and directory both exist but they're different ...
			elseif ($index = 1 and $breg and StringCompare($finalDir[0], _Iif($index = 1, $finalDir[$index], "fail")) <> 0) Then
				Logger($EUSERVERBOSE, "The registry doesn't match the corresponding directory ..." & $finalDir[0], false)
				$dir = $gSavetoDirectory & "\" & $finalDir[0]
				if(FileExists($dir)) then
					Logger($EUSERVERBOSE, "Warning: The hard-drive may be failing or something was changed midrun. Please check your data.", false)
				Else
					Logger($EUSERVERBOSE, "Did you rename the directory?", false)
				endif
				Logger($EUSERVERBOSE, "Defaulting to the registry ...", false)
				
			Else
				;We have to choose, so always give preference to the registry
				;this also handles the case of index = 0 and StringCompare($finalDir[0], "") <> 0
				;meaning the case of no directories but a previous registry entry
				$dir = $gSavetoDirectory & "\" & $finalDir[0]
				Logger($EUSERVERBOSE, "The last known working directory is missing ... " & $gCurrentSavetoDirectory, false)
				Logger($EUSERVERBOSE, "Recreating ...", false)
			endif
			$dir = CreateNewDirectory($dir)
		Else
			;no registry data and no known directories starting at a random url
			;If all else fails lets just use the best known guess for the last directory
			if(MsgBox(2, "Warning...", "Starting from a random URL that isn't at 'Page 1.jpg' may result in downloading duplicate files due to inconsistency in directory names." & @CRLF & @CRLF & "'Ignore' to proceed or 'Abort' and navigate to Page 1.") <> 5) Then
				TogglePause()
				SetError(2)
				return $ENODOC_NOPAGE_ERROR 
			endif
			$dir = CreateNewDirectory()
		endif

		
		Logger($EUSERVERBOSE, "Using directory name: " & $dir, false)
		if(StringCompare($dir, $gCurrentSavetoDirectory) <> 0 and FileExists($dir)) Then
			$gCurrentSavetoDirectory = $dir
		endif
		SetSaveDialogDirectory($dir, $clip)
	Else
		;TODO: Need to check if this is our first run. $gCurrentSaveDirectory may not be valid
		;      if the browser was already open and we're on a page that's not a continuation
		;      of where we were previously.
		$dir = $gCurrentSavetoDirectory
		if($gDirectoryNotSet) Then
			SetSaveDialogDirectory($dir, $clip)
		endif
	endif
	
	Local $hitConfirmSaveAs = false
	$count = 0
	do
		WinActivate($label_select_location)
		if($count > 2) Then
			;Send($clip, 1)
			;Sometimes the directory doesn't "reset" and revert to the filename. When this happens 
			;we navigate up to the parent directory and then reset the save path($dir) and the 
			;page name($clip)
			Logger($EUSERVERBOSE, "Save Dialog is rejecting: " & $dir & ". Navigating to parent directory and back again.", false)
			SetSaveDialogDirectory("..", "")
			SetSaveDialogDirectory($dir, $clip)
			Sleep(1000 * $gSleepMultiplier)
		endif
		$count += 1
		Send("{tab}{tab}{ENTER}",0)
		Sleep(100 * $gSleepMultiplier)
		
		;creating a few "text" loop patterns will help me locate where we're getting stuck
		Logger($EINFINITELOOPDBG, "st", false) 
		;TODO: Add generic routine for breaking out if this fails?
		if(WinExists($label_confirm_save_as)) then 
			WinActivate($label_confirm_save_as)
			$gDirectoryNotSet = True
			Send("{Enter}", 0)
			Sleep(150 * $gSleepMultiplier)
			Send("{tab}{tab}{tab}{enter}", 0)
			Sleep(100 * $gSleepMultiplier)
			Logger($EUSER, "'" & $clip & "' already exists in " & $gCurrentSavetoDirectory & ". Skipping and going to the next...", false)
			if($retCode <> $ENEWDOC) then $retCode = $ESKIPPED
			$hitConfirmSaveAs = true
		EndIf
	Until (NOT WinExists($label_select_location)) ;"Select location for download"))
	
	if($hitConfirmSaveAs = false) then 	;Not WinExists("Confirm Save As")
		;TODO: Need to handle collisions. Particularly the case where I don't get to set the directory
		;      so when it goes to save "page 2.jpg" since "page 1.jpg" wasn't saved to the directory. 
		;      The old folder is used.
		Sleep(200 * $gSleepMultiplier)
		$origsecs = _DateDiff('s', "2011/07/01 00:00:00", _NowCalc())
		
		Local $timeoutHit = false
		Local $counter = 0
		do 
			$lastFileSize = $currentFileSize
			$currentFileSize = FileGetSize($dir & "\" & $clip)	
			if($currentFileSize < 10000 AND $counter < 10000) then ;used to be 19456, 15456
				;infinite loop bug occurs when it's not writing to disk. So $currentFileSize keeps getting set to 0
				$counter += 1
				$currentFileSize = $lastFileSize + 1 
			else 
				sleep(2000 * $gSleepMultiplier)
				$diff = _DateDiff('s', "2011/07/01 00:00:00", _NowCalc()) - $origsecs
				if($diff > 45 And NOT $timeoutHit) then
					Logger($EUSERVERBOSE, "It's taken over a minute to download the image ... please check your internet connection. Waiting a minute longer before exiting out.", false)
					$timeoutHit = true
				EndIf
				if($diff > 105) then 
					Logger($EUSERVERBOSE, "Nearly two minutes have passed. Aborting. Please check your internet connection.", false)
					SetError(1)
					return 0
				endif
			endif
			;creating a few "text" loop patterns will help me locate where we're getting stuck
			Logger($EINFINITELOOPDBG, ".", false) 
			;ConsoleWrite("currentFileSize: " & $currentFileSize & ", lastFileSize: " & $lastFileSize & @CRLF)
		Until($lastFileSize = $currentFileSize)
		Logger($EUSER, "Downloading '" & $clip & "' took " & _DateDiff('s', "2011/07/01 00:00:00", _NowCalc()) - $origsecs & " seconds to complete", false)
		if($retCode <> $ENEWDOC) then $retCode = $ENEWPAGE
	EndIf
	Sleep(100 * $gSleepMultiplier)
	MouseClick("left", $gNextButton[0], $gNextButton[1])
	Sleep(1500 * $gSleepMultiplier)
	MouseClick("left", $gDownloadButton[0], $gDownloadButton[1])
	Sleep(700 * $gSleepMultiplier)
	;MouseClick("left", $gEntireImageButton[0], $gEntireImageButton[1])
	;sleep(200)
	;Sleep(10000)
	return $retCode

EndFunc   ;==>StartDownloadImage



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
	Local $ret = 0, $downloadRetCode = 0
	$gPaused = false
	GuiCtrlSetState($initializebutton, $GUI_HIDE)
	
	$ret = StartResumeInit()
	;Impl main loop this needs to:
	; 	1. DONE - Always make sure we have a Process open (in case FF crashes)
	; 	2. DONE - Make sure we have a page available
	;	3. DONE - Make sure all the buttons are present
	;	4. Has to be able to try to find a good position to know how to resume from a last good state

	if($gRunning = false And $gInitialized = true And $gPositionsValid = true) Then
		$gRunning = true
		
		SetLoggerIgnoreLevel($ETRACE, true)
		$gStartResumeSessionPageCount = 0
		$gStartResumeSessionDocCount = 0
		
		while(NOT $gPaused)
			$msg = GuiGetMsg()
			$ret = StateMachine($msg)
			if($ret <> 0) then
				ExitLoop ; quit message
			EndIf

			Switch(StartDownloadImage())
				Case 2
					$gStartResumeSessionDocCount += 1
					ContinueCase
				Case 1
					$gStartResumeSessionPageCount += 1
				Case 0
					if(@error = 1) Then
						;Since we didn't advance the page it should try again ... Should I have a timeout here too?
					elseif(@error = 2) then
						;This means we were at a random url without the page 1 id. So we just want to pause
						;The user already gets a notification so is there anything else we should do here?
					endif
			EndSwitch
			
			;Spawn the FTP tool.
			;IsNewDocument()
			;	CreateAndNameDirectory()
			;FinishDownloadImage()
			;IsImageDownloaded()
			; 	AdvancePage()
			
			sleep(100 * $gSleepMultiplier)
		Wend
		SetLoggerIgnoreLevel($ENOTHING, false)
		$gStartResumeTotalSessionPageCount += $gStartResumeSessionPageCount 
		$gStartResumeTotalPageCount += $gStartResumeSessionPageCount 
		
		$gStartResumeTotalSessionDocCount += $gStartResumeSessionDocCount
		$gStartResumeTotalDocCount += $gStartResumeSessionDocCount
		RegWrite($gKeyName, $gStartResumeTotalPageCountRegSz, "REG_DWORD", $gStartResumeTotalPageCount)
		RegWrite($gKeyName, $gStartResumeTotalDocCountRegSz, "REG_DWORD", $gStartResumeTotalDocCount)
		
		;Add in some stats for files skipped? This could be useful.
		Logger($EUSER, "Statistics: FootnoteReap handled," & @CRLF & _ 
						$gStartResumeSessionPageCount & " page(s) across," & @CRLF & _ 
					    $gStartResumeSessionDocCount & " document(s) since the last pause." & @CRLF & @CRLF & _
						"Out of:" & @CRLF & _
						$gStartResumeTotalSessionPageCount & " page(s) across," & @CRLF & _
						$gStartResumeTotalSessionDocCount & " document(s) this session." & @CRLF & @CRLF & _
						"Over a grand total of:" & @CRLF & _
						$gStartResumeTotalPageCount & " page(s) across," & @CRLF & _
						$gStartResumeTotalDocCount & " document(s) for the lifetime of the application.", false)
		$gRunning = false
	EndIf
	return $ret
	;return 0
EndFunc   ;==>StartResume
;======================== END TOGGLE FUNCS =========================


Func DumpAllGlobalStates()
	Logger($ETRACE, "DumpAllGlobalStates()", false)
	;TODO: Implement me...
EndFunc   ;==>DumpAllGlobalStates



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


Global $gFirstInitializePageCall = true
Func InitializePage($checkSaveImageDialogUp = true, $winState = "")
	;returns 0 if the page fails to init, 1 if we create a new page, 2 if a page is already open.
	Logger($ETRACE, "InitializePage(" & $checkSaveImageDialogUp & ", " & $winState & ")", false)
	If ValidFootnotePage() Then
		;60 second wait then we assume the browser crashed and the msgbox is down.
		Local $allow = false
		if(NOT $gBrowserActiveBeforeFootnoteReap And Not $gInitialized) then ;$gFirstInitializePageCall
			;Since we know we had to create the browser. Then that means we can't possibly have
			;the "Save Image" dialog up. So no reason to ask.
			$gFirstInitializePageCall = False
		Elseif($gBrowserActiveBeforeFootnoteReap And $gFirstEntry = true) Then
			$allow = true
		Elseif($checkSaveImageDialogUp) then
			$allow = True
		EndIf
		if($allow = true) then
			if(IsSaveImageDialogUp() = false And @error = 1) Then
				IsSaveImageDialogUp(true)
			endif
		endif
		return 2
	EndIf
	if(MakeActive($winState) <> 0 and $gBrowserWinSize[0] > 0 and $gBrowserWinSize[1] > 0) Then
		Local $count = 0
		Local $clip = ""
		
		;Since the first validfootnotepage doesn't have the benefit of a makeactive() lets try one more time
		;and if we don't get a page then we'll open a new tab but only once
		while(Not ValidFootnotePage())
			Logger($EUSERVERBOSE, "Opening a new tab page. Waiting 7 seconds to let everything load ...", false)
			if($count = 0) Then Send("^t", 0); Open a new tab
			Send("!d", 0) ; "^l" and go to the location bar	
						; TODO: Need to check for 'd' now instead of 'l'
			Send($gCurrentURL, 1) ;send the URL raw
			Logger($EVERBOSE, "Sending $gCurrentURL to the url bar: " & $gCurrentURL, false)
			sleep(100 * $gSleepMultiplier)
			Send("{ENTER}", 0) ; now submit the enter
			Sleep(7000 * $gSleepMultiplier) ; Wait 7 seconds for everything to load
			$count += 1
			if($count = 3) Then
				Logger($EUSER, "Failed to initialize page", true, 5)
				return false
			EndIf
			GetCurrentURL($clip)
			If(StringCompare(StringLower($clip), $gBaseURL & "missing.php") = 0) Then
				if(StringCompare($gPrevURL, $gCurrentURL) <> 0) then
					Logger($EVERBOSE, "$gPrevURL <> $gCurrentURL", true)
					$gCurrentURL = $gPrevURL
				Else
					Logger($EVERBOSE, "$gPrevURL = $gCurrentURL", true)
					;TODO: Set this to something from the registry? Or dig through files?
					$gCurrentURL = $gInitialURL
				EndIf
			EndIf
		Wend
		
		Logger($EUSERVERBOSE, "In case of FlashBlock clicking on the surface to enable flash. Please wait 4 seconds to let the footnote application load ...", false)
		;If a person is using flashblock lets activate the canvas
		MouseClick("left", $gBrowserWinPos[0] + ($gBrowserWinSize[0] / 2), $gBrowserWinPos[1] + ($gBrowserWinSize[1] * 0.3))
		;send a click to change focus so it doesn't keep the hand icon from grabbing the footnote document causing it to scroll.
		Send("^", 0)
		
		Sleep(4000 * $gSleepMultiplier)
		;$gSaveImageDialogUp = false
		EnableEntireImageDialog() ;if($count > 1) then
		
		return true
	EndIf
	return false
EndFunc   ;==>InitializePage


Global $gLoadBrowserInstanceFirstCall = true
Func LoadBrowserInstance()
	Logger($ETRACE, "LoadBrowserInstance()", false)
	If ProcessExists($gExeName) Then
		if($gLoadBrowserInstanceFirstCall = true) then
			$gBrowserActiveBeforeFootnoteReap = True
			$gLoadBrowserInstanceFirstCall = False
		endif
		Logger($EVERBOSE, "Process already exists, not loading another ...", false)
		return False
	Else
		$gLoadBrowserInstanceFirstCall = false
	EndIf

	;"HKEY_LOCAL_MACHINE\SOFTWARE\Clients\StartMenuInternet\FIREFOX.EXE\shell\open\command"
	$gProgramPath = OnOffOrError($gRegistryProgramPathSz, "")
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
	Else
		Sleep(350 * $gSleepMultiplier) ;Give the process some time to launch
		
	EndIf
	return true
EndFunc   ;==>LoadBrowserInstance


;This makes sure the browser, footnote.com and footnotereaper are all in a useable state
Func Initialize( _
		$skipSetDownloadPosition = false, _
		$winState = @SW_MAXIMIZE, _
		$winMove = true, _
		$checkSaveImageDialogUp = true _
		)
	;Return 0 = error, 1 success, 2 success (set downloadposition)
	Logger($ETRACE, "Initialize(" & $skipSetDownloadPosition & ", " & $winState & ", " & $winMove & ", " & $checkSaveImageDialogUp & ")", false)

	LoadBrowserInstance()
	;TODO: Ensure the user is actually signed in...
	$ret = InitializePage($checkSaveImageDialogUp, $winState)
	If($ret <> false) Then
		if($winMove = true) then
			WinMove($gTaskIdentifier, "", 0, 0) ; @DesktopWidth, @DesktopHeight)
		endif
		if(Not $skipSetDownloadPosition) then
			Local $blogin = false
			if($ret <> 2) then
				;TODO: Check do we even get here any more? 
				$blogin = MsgBox(1, "Confirm Login", "Before continuing login to " & $gBaseDomain) <> 2
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
	$ret = Initialize(false, "", true, false) ;if we're running this we know we don't have an entireimage dialog up.
	If($ret <> false) Then
		VerifyButtons() ;_Iif($gSaveImageDialogUp = true And $ret <>2, 0, 1)
		DirectoryManager()
		$gInitialized = true
		$gFirstEntry = false
		RegWrite($gKeyName, "gFirstEntry", "REG_DWORD", $gFirstEntry)
		GUICtrlSetData($initializebutton, "Start/Resume")
		GuiCtrlSetState($initializebutton, $GUI_SHOW)
		;$gFirstEntry = OnOffOrError($gKeyName, "gFirstEntry")
	Else
		;BUG: If a person starts the application, does a normal button initialize. Then later clicks
		;     start. The program will reshow the initialize button. I may just need to include lots of
		;     states. One for the button one for the global init state
		if($gPositionsValid = false) then
			GuiCtrlSetState($initializebutton, $GUI_SHOW)
		endif
	EndIf
EndFunc   ;==>MasterInitialize


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


Func TwosComplementToSignedInt(ByRef $coords)
	Logger($ETRACE, "TwosComplementToSignedInt()", false)
	Local $modified = False
	if(Not IsArray($coords)) Then Return false
	
	$power = _Iif(StringCompare(@CPUArch, "X86"), 32, 64)
	Logger($EVERBOSE, "power: " & $power, false)
	
	For $I = 0 To UBound($coords) - 1
		if(BitAND($coords[$I], 0xFFFF0000) = true) Then
			Logger($EVERBOSE, "$coords[" & $I & "]: " & $coords[$I], false)
			;NOTE: this is platform specific (i.e. 64-bit versus 32-bit vars)
			$coords[$I] = -(2 ^ $power - $coords[$I]) ;0xFFFFFFFF - $coords[0]
			Logger($EVERBOSE, "$coords[" & $I & "]: " & $coords[$I], false)
			$modified = true
		EndIf
	Next
	return $modified
EndFunc   ;==>TwosComplementToSignedInt


Func LoadOldWindowState($bForceLoad = false)
	Logger($ETRACE, "LoadOldWindowState()", false)
	
	Local $successfulLoads = 0
	Dim $dlButtonXY[2] = [0, 0]
	Local $buttonXY[2] = [0, 0]
	
	Local $max = Ubound($gFootnoteButtonArray) - 1
	If $max < 0 Then CleanupExit(5, "$gFootnoteButtonArray has no objects" & @error, true)
	
	;First get our the new window values.
	if($bForceLoad = false And((WindowResizedOrMoved() = false and $gInitialized = true) or $gPositionsValid = true)) Then
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
	
	Local $sleepMod = OnOffOrError($gKeyName, $gSleepMultiplierRegSz)
	if($sleepMod <> -1) then $gSleepMultiplier = $sleepMod
	
	;This has to be before initialize so we have the right page to load.
	Local $currentURL = OnOffOrError($gKeyName, $gCurrentURLRegSz)
	Local $prevURL = OnOffOrError($gKeyName, $gPrevURLRegSz)
	Local $docStartURL = OnOffOrError($gKeyName, $gCurrentDocumentStartURLRegSz)
	if($currentURL <> -1) Then $gCurrentURL = $currentURL
	if($prevURL <> -1) then $gPrevURL = $prevURL
	if($gCurrentDocumentStartURL <> -1) then $gCurrentDocumentStartURL = $docStartURL
	
	Local $path = OnOffOrError($gKeyName, $gSavetoDirectoryRegSz)
	if($path <> "" And $path <> -1) then $gSavetoDirectory = $path
	Local $currentpath = OnOffOrError($gKeyName, $gCurrentSavetoDirectoryRegSz)
	if($currentpath <> "" And $currentpath <> -1) then $gCurrentSavetoDirectory = $currentpath
		
	;statistics
	Local $pagesDownloaded = OnOffOrError($gKeyName, $gStartResumeTotalPageCountRegSz)
	if($pagesDownloaded <> -1) then $gStartResumeTotalPageCount = $pagesDownloaded
	Local $docsDownloaded = OnOffOrError($gKeyName, $gStartResumeTotalDocCountRegSz)
	if($docsDownloaded <> -1) then $gStartResumeTotalDocCount = $docsDownloaded
	
	if($gInitialized = false) Then
		if(Not Initialize(true, "", false, false)) then
			return false
		EndIf
	EndIf
	
	$oldPositionsValid = OnOffOrError($gKeyName, "gPositionsValid")
	
	;No reason to continue if we know it's already invalid
	if($oldPositionsValid = false) Then
		;This should only happen when a window is resized and a person does a manual save.
		;Even in this scenario I should be querying the person to try to prevent this state
		AssertMsg("$oldPositionsValid = false", true, 0)
		return false
	EndIf
	
	$oldBrowserWinpos[0] = OnOffOrError($gKeyName, "gWinPosX")
	$oldBrowserWinpos[1] = OnOffOrError($gKeyName, "gWinPosY")
	$oldBrowserWinsize[0] = OnOffOrError($gKeyName, "gWinSizeX")
	$oldBrowserWinsize[1] = OnOffOrError($gKeyName, "gWinSizeY")
	
	;When can this type of thing happen? Basically only if a user quits the program
	;mid-execution. Because all regwrites have a WindowResizedOrMoved() before them
	;Basically if this is the case we should just bail. The data's likely garbage.
	If($oldBrowserWinpos[0] = -1 Or _
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
		;On crash we give a minute timeout. If it fails we resize our window and continue.
		If(MsgBox(4, "Confirmation Dialog", "The window has been moved or resized. Reset window? Answering 'No' will cancel the remainder of the load.", 60) = 7) Then
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
	;TODO: When $bForce = true should we tell the user how everything loaded?
	if($gPositionsValid = true And($successfulLoads - 1) = $max) Then
		$gInitialized = True
		Logger($EUSER, "Load successful", _Iif(Not $bForceLoad, true, false))
	Else
		Logger($EUSER, "Not all data was loaded successfully. Please click 'Edit -> Verify Buttons'", _Iif(Not $bForceLoad, true, false))
		Logger($EVERBOSE, $max & " " & $successfulLoads & " " & $gPositionsValid, false)
	EndIf
	
	;grunning T and gpaused F = hide
	;grunning T and gpaused T = show
	;grunning F and gpaused T = (error)
	;grunning F and gpaused F = (show 	
	if($gRunning and NOT $gPaused) Then
		GuiCtrlSetState($initializebutton, $GUI_HIDE)
	Else
		if(NOT $gRunning and NOT $gPaused and $gInitialized and $bForceLoad) then
			GuiCtrlSetState($initializebutton, $GUI_HIDE)
		else
			GuiCtrlSetState($initializebutton, $GUI_SHOW)
		endif
	EndIf

#cs
	if($gRunning = false AND ($gInitialized = false OR $gPaused = true)) then
		Logger($EVERBOSE, "1:" & $gRunning & "   " & $gInitialized & "     " & $gPaused, true)
		GuiCtrlSetState($initializebutton, $GUI_SHOW)
	else
		;Logger($EVERBOSE, "2:" & $gRunning & "   " & $gInitialized & "     " & $gPaused, true)
		GuiCtrlSetState($initializebutton, $GUI_HIDE)
	endif
#ce
	
	;Sleep(3000)
	;$gSaveImageDialogUp = false
	;EnableEntireImageDialog()
	
	return $gInitialized
EndFunc   ;==>LoadOldWindowState


Func SaveWindowState()
	Logger($ETRACE, "SaveWindowState()", false)
	;impl
EndFunc   ;==>SaveWindowState


Func StoreByRef(ByRef $src, ByRef $dest)
	Logger($ETRACE, "StoreByRef()", false)
	$dest = $src
EndFunc   ;==>StoreByRef


Func StateMachine($msg)
	Select
		Case $msg = $GUI_EVENT_CLOSE Or $msg = $exititem
			;ExitLoop
			return 1

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
			if($gFirstEntry) then
				MasterInitialize()
			Else
				return StartResume()
			EndIf
			
		Case $msg = $startitem
			return StartResume()
			
		Case $msg = $pauseitem
			TogglePause()
			
		Case $msg = $loaditem
			LoadOldWindowState()
			
		Case $msg = $saveitem
			SaveWindowState()
			
		Case $msg = $registrationitem
			If $gNT = 1 Then RegWrite("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Applets\Regedit\Favorites", "FoonoteReaper", "REG_SZ", "Computer\HKEY_CURRENT_USER\SOFTWARE\FoonoteReaper")
			Run("regedit.exe")
			WinWaitActive("Registry Editor")
			If $gNT = 1 Then Send("!af{ENTER}{F5}", 0)
			RegDelete("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Applets\Regedit\Favorites", "FoonoteReaper")
			
			;==================== Set Button ==========================
		Case $msg = $downloaditem
			If (Not MakeActive() or $gRunning) Then return 0 ; ContinueLoop
			$gPositionsValid = false
			SetDownloadPosition()
			
		Case $msg = $nextitem
			If (Not MakeActive() or $gRunning) Then return 0 ; ContinueLoop
			$gPositionsValid = false
			SetNextPosition()
			;Todo: verify is a way to ensure all buttons are set create another function to check non-0'ness as check?
			
		Case $msg = $previtem
			If (Not MakeActive() or $gRunning) Then return 0 ; ContinueLoop
			$gPositionsValid = false
			SetPrevPosition()
			
		Case $msg = $entireimageitem
			If (Not MakeActive() or $gRunning) Then return 0 ; ContinueLoop
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
			If (Not MakeActive() or $gRunning) Then return 0 ; ContinueLoop
			VerifyButtons(0)
			;=================== End Check Buttons ======================
			
			
			;================  ABOUT DIALOGUE CASES =================
		Case $msg = $aboutitem
			If WinExists("The FootNote Reaper") Then return 0 ; ContinueLoop
			If $gNT <> 1 Then
				$width = 242
			Else
				$width = 220
			EndIf
			$height = 110
			Dim $pos = WinGetPos("[TITLE:FootnoteReap; CLASS:AutoIt v3 GUI]") ;("FootnoteReap")
			Dim $tempSize = WinGetClientSize("[TITLE:FootnoteReap; CLASS:AutoIt v3 GUI]") ;"FootnoteReap")
			$tempSize[0] += 12
			$gWindow = GUICreate("The FootNote Reaper", "112", $height, $pos[0] + $tempSize[0], $pos[1], $WS_POPUPWINDOW) ;280x160
			$label1 = GuiCtrlCreateLabel("The Footnote Reaper ", (8 * ($width / 2)) / 100, 3, 100)
			GUICtrlSetFont($label1, 14, 800, 4, "Times New Roman")
			GUICtrlSetColor($label1, 0xff0000)
			$spacer = 20
			$lab2h = 32 ;36
			$label2 = GuiCtrlCreateLabel("Created By:  Xtraeme", 5, $lab2h)
			$lab3h = $lab2h + $spacer
			$label3 = GuiCtrlCreateLabel("Contact:", 5, $lab3h)
			$lab4h = $lab3h + $spacer
			$label4 = GuiCtrlCreateLabel("Website:", 5, $lab4h)
			$lab45h = $lab4h + $spacer
			$label45 = GuiCtrlCreateLabel("Version:        " & $version & ", build " & $buildnum, 5, $lab45h)

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
					_RunDOS("start http://wiki.razing.net/")
				EndIf
			EndIf
		
		Case $msg = $projectitem 
			If FileExists(@ProgramFilesDir & "\Internet Explorer\iexplore.exe") Then
				;Run(@ProgramFilesDir & "\Internet Explorer\iexplore.exe http://wiki.razing.net")
				_RunDOS("start http://footnotereap.googlecode.com")
			EndIf
		
		Case $msg = $label5
			_INetMail("xthaus@yahoo.com", "[FootnoteReaper] ", "Please leave the [FootnoteReaper] in the Subject so my mail filter can sort by it, thanks!")

		Case $msg = $gButton
			If WinExists("The FootNote Reaper") Then
				$width = 220
				$height = 110
				$pos = WinGetPos("[TITLE:FootnoteReap; CLASS:AutoIt v3 GUI]") ;"FootnoteReap")
				$tempSize = WinGetClientSize("[TITLE:FootnoteReap; CLASS:AutoIt v3 GUI]") ; ("FootnoteReap")
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
			$tempPos = WinGetPos("[TITLE:FootnoteReap; CLASS:AutoIt v3 GUI]") ;("FootnoteReap")
			$tempSize = WinGetClientSize("[TITLE:FootnoteReap; CLASS:AutoIt v3 GUI]") ;("FootnoteReap")
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
		Case $msg = $GUI_EVENT_MOUSEMOVE
			;ConsoleWrite("moved ..")
			$tempPos = WinGetPos("[TITLE:FootnoteReap; CLASS:AutoIt v3 GUI]") ;("FootnoteReap")
			$tempSize = WinGetClientSize("[TITLE:FootnoteReap; CLASS:AutoIt v3 GUI]") ;("FootnoteReap")
			$tempSize[0] += 12
			if IsArray($tempPos) AND $tempPos[0] <> $gWinPos[0] AND $tempPos[1] <> $gWinPos[1] Then
				If WinExists("The FootNote Reaper") Then WinMove("The FootNote Reaper", "", $tempPos[0] + $tempSize[0], $tempPos[1])
				$gWinPos[0] = $tempPos[0]
				$gWinPos[1] = $tempPos[1]
				$gWinSize[0] = $tempSize[0]
				$gOffset = $tempSize[0]
				$gWinSize[1] = $tempSize[1]
			EndIf
			
		Case $msg = $GUI_EVENT_RESIZED
			;ConsoleWrite("resized ..")
			$tempPos = WinGetPos("[TITLE:FootnoteReap; CLASS:AutoIt v3 GUI]") ;("FootnoteReap")
			$tempSize = WinGetClientSize("[TITLE:FootnoteReap; CLASS:AutoIt v3 GUI]") ;("FootnoteReap")
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
	return 0
EndFunc   ;==>StateMachine




#requireadmin
Opt("WinTitleMatchMode", 2)
;Opt("GUIOnEventMode", 1)

;$gLoggerEnabled = OnOffOrError($gKeyName, $gLoggerEnabledRegSz)

;NOTE: When loggerEnabled is disabled we're presuming we're writing to Stdout (when a person runs footnote.exe from the batch)
;      When LoggerEnabled is enabled we presume we write to the Alloc'ed window (basically when a person runs footnote.exe standalone)
;if($gLoggerEnabled = "-1") then RegWrite($gKeyName, $gLoggerEnabledRegSz, "REG_DWORD", false)
;if($gLoggerEnabled) then _Console_Alloc()

WinActivate("cmd.exe")
Logger($EUSER, "FootnoteReap ver: " & $version, false)
Logger($EUSER, "Build number: " & $buildnum, false)

$debug = OnOffOrError($gKeyName, $gDebugRegSz)
if($debug = "-1") then 
	RegWrite($gKeyName, $gDebugRegSz, "REG_DWORD", false)
elseif($debug = 1) Then
	$gLoggerIgnoreLevel = $ENOTHING
	Dim $exceptionArray[2] = [$EASSERT, $EINFINITELOOPDBG]
	SetLoggerIgnoreException($exceptionArray, $EADD)
endif

Local $logIgnoreLevel = OnOffOrError($gKeyName, $gLoggerIgnoreLevelRegSz)
if($logIgnoreLevel <> "-1") then 
	$gLoggerIgnoreLevel = $logIgnoreLevel
else 
	$gLoggerIgnoreLevel = $EUSERVERBOSE-1 ;$ENOTHING		;TODO; Before release set to $EUSER_VERBOSE
	RegWrite($gKeyName, $gLoggerIgnoreLevelRegSz, "REG_DWORD", $gLoggerIgnoreLevel)
endif
SetLoggerIgnoreLevel($gLoggerIgnoreLevel, true)

;this has to happen early for all the functions to get the benefit of it.

InitializeOrReadRegistryEntry($gKeyName, $gSleepMultiplierRegSz, $gSleepMultiplier, "REG_DWORD")
InitializeOrReadRegistryEntry($gKeyName, $gWaitDelayRegSz, $gWaitDelay, "REG_DWORD")
InitializeOrReadRegistryEntry($gKeyName, $gSendKeyDelaySz, $gSendKeyDelay, "REG_DWORD")
InitializeOrReadRegistryEntry($gKeyName, $gSendKeyDownDelaySz, $gSendKeyDownDelay, "REG_DWORD")

Opt("WinWaitDelay", $gWaitDelay) 
Opt("SendKeyDelay", $gSendKeyDelay)
Opt("SendKeyDownDelay", $gSendKeyDownDelay) 

;------------CSV data----------------
Local $origsecs = _DateDiff('s', "2011/07/01 00:00:00", _NowCalc())
Logger($EUSER, "Loading footnote website data. This can take a second or two ... ", false)
$gCSVdata = OnOffOrError($gKeyName, "gCSVdata")
if($gCSVdata = -1) Then
	$gCSVdata = ".\bluebook\bluebook-data.psv"
	;$gCSVdata = ".\bluebook\bluebook-page1docs.psv"
	RegWrite($gKeyName, "gCSVdata", "REG_SZ", $gCSVdata)
endif

$gCSVArray = _CSVFileReadRecords($gCWD & $gCSVdata)
Logger($EUSER, "Load took " & _DateDiff('s', "2011/07/01 00:00:00", _NowCalc()) - $origsecs & " seconds to complete", false)
;-----------End CSV data-------------

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
HotKeySet("^!+e", "EmergencyExit")
;~ HotKeySet("{ESC}", "Stop")

;GuiSetIcon($gCWD & "\a8950027.ico", 0)
GUISetBkColor(0xffffff)

$commands = GuiCtrlCreateMenu("&Commands")
$fileitem = GuiCtrlCreateMenu("&File", $commands)
$saveitem = GuiCtrlCreateMenuItem("&Save", $fileitem)
$loaditem = GuiCtrlCreateMenuItem("&Load", $fileitem)

$dashitem = GuiCtrlCreateMenuItem("", $commands)
SetOwnerDrawn($commands, $dashitem, "")

$startitem = GuiCtrlCreateMenuItem("&Start (F10)", $commands)
$pauseitem = GuiCtrlCreateMenuItem("&Pause (F11)", $commands)
;$stopitem = GuiCtrlCreateMenuItem("S&top", $commands)
$exititem = GuiCtrlCreateMenuItem("&Exit (Alt+Ctrl+Shift+E)", $commands)

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
$projectitem = GuiCtrlCreateMenuItem("View &Project", $help)
$aboutitem = GuiCtrlCreateMenuItem("&About", $help)

WindowResizedOrMoved()
$gFirstEntry = OnOffOrError($gKeyName, "gFirstEntry")
if($gFirstEntry = -1) then
	$gFirstEntry = true
EndIf

$initializebutton = GUICtrlCreateButton("Initialize", 20, 20, 120)
;$startresumebutton = GUICtrlCreateButton("Start/Resume", 20, 20, 120)

if($gFirstEntry = false) then
	GUICtrlSetData($initializebutton, "Start/Resume")
EndIf
;WinSetOnTop(GUICreate("Status Window",500,30,500,1), '', 1)

ConsoleWrite("Initialized GUI and global ..." & @CRLF)

GuiSetState()
;Dim $gBrowserWinPos = WinGetPos("FootnoteReap", "Steps Completed")

do
	$msg = GuiGetMsg()
	if(StateMachine($msg) <> 0) Then ExitLoop
Until $msg = $GUI_EVENT_CLOSE OR $msg = $exititem

CleanupExit($ECLEAN_EXIT, "Shutting down...", false)