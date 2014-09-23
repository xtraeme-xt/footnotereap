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

#include ".\Include\_CSVLib.au3"
#include ".\Include\_LogLevels.au3"
#include ".\Include\_ConfigData.au3"
#include ".\Include\_WinAPICustom.au3"
#include ".\Include\_FileManager.au3"
#include ".\Include\_StringClipHelpers.au3"
#include ".\Include\_SyncArraysGlobals.au3"
#include ".\Include\_HumanInputEmulation.au3"

#include "footnote_window.au3"
#include "footnote_file.au3"
#include "footnote_url_pageobjects.au3"

;for about
#include <StaticConstants.au3>
#include <ButtonConstants.au3>

;----------------- Global Definitions -----------------
Const $version = "0.0.1.5.1"
Const $buildnum = "10"

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
		Logger($EUNHANDLED, "SetSaveDialogDirectory(508), Directory possibly not set correctly:" & $dir, 0)
	EndIf
	$timeout = $timeoutUpperBound
	
	Send("{ENTER}", 0)
	Sleep(2000 * $gSleepMultiplier)
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
			Logger($EUNHANDLED, "SetSaveDialogDirectory(524), Filename possibly not set correctly:" & $clip, 0)
		endif
	EndIf
	;Logger($EUSERVERBOSE, "leaving SetSaveDialogDirectory(" & $dir & ", " & $clip & ")", false)
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
	local $lastFileTime = ""
	Local $currentFileSize = 0
	Local $currentFileTime = ""
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

			$gDirectoryNotSet = True
			WinWaitActivate($label_confirm_save_as)
			Send("{Enter}", 0)

			;NOTE: Extremely time sensitive code 
			; r89 on 2008 Intel Core 2 Extreme X9000 worked with lower sleep timeouts (150/100) due 
			; to slower system performance
			; r90> on a Intel Core i7 3930K requires higher timeouts (150/500 didn't even work)
						
			;Sleep(1500 * $gSleepMultiplier)
			WinWaitActive($label_select_location)
			;AssertMsg($clip_temp_filename)
			
			;Win. 7 ultimate IE 9.10.9200.16540 / 10.0.4 sometimes puts the cursor at the "Save in" location?
			;Vista Pro IE 9.0.8112.16421 / 9.0.10 no problems
			;   Send_KeysIndividually("{tab}{tab}{tab}{tab}{tab}{tab}{tab}{enter}", 0, 200)
			Send_KeysIndividually("{tab}{tab}{tab}{enter}", 0, 50)

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
			$lastFileTime = $currentFileTime
			sleep(360 * $gSleepMultiplier)
			
			$currentFileSize = FileGetSize($dir & "\" & $clip)	
			$currentFileTime = FileGetTime($dir & "\" & $clip, 0, 1)
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
		Until($lastFileSize = $currentFileSize and StringCompare($lastFileTime, $currentFileTime) = 0)
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

Logger($EUSER, "FootnoteReap ver: " & $version, false)
Logger($EUSER, "Build number: " & $buildnum, false)

$debug = OnOffOrError($gKeyName, $gDebugRegSz)
if($debug = "-1") then 
    $gDebug = false
	RegWrite($gKeyName, $gDebugRegSz, "REG_DWORD", $gDebug)
 Else
	$gDebug = $debug
    if($gDebug = true) Then	
	   $gLoggerIgnoreLevel = $ENOTHING
	   Dim $exceptionArray[2] = [$EASSERT, $EINFINITELOOPDBG]
	   SetLoggerIgnoreException($exceptionArray, $EADD)
    EndIf
endif

;AssertMsg("FootnoteReap" & _Iif($gDebug, "Dbg", "")) ; StringTrimRight(@ScriptName, 4) & _Iif($gDebug, "ReapDbg", "Reap"))

WinActivate("cmd.exe") 								   ;For Vista
WinActivate("FootnoteReap" & _Iif($gDebug, "Dbg", "")) ;For Win. 7

Local $logIgnoreLevel = OnOffOrError($gKeyName, $gLoggerIgnoreLevelRegSz)
if($logIgnoreLevel <> "-1") then 
	$gLoggerIgnoreLevel = $logIgnoreLevel
else 
	$gLoggerIgnoreLevel = $EUSERVERBOSE-1 ;$ENOTHING		;TODO; Before release set to $EUSER_VERBOSE
	RegWrite($gKeyName, $gLoggerIgnoreLevelRegSz, "REG_DWORD", $gLoggerIgnoreLevel)
endif
SetLoggerIgnoreLevel($gLoggerIgnoreLevel, true)

;this has to happen early for all the functions to get the benefit of it.

InitializeOrReadRegistryEntry($gKeyName, $gSleepMultiplierRegSz, $gSleepMultiplier, "REG_SZ")
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