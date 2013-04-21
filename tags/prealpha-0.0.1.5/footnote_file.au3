;--------------------------------------------------------------------------------
;AutoIt Version: 3x
;Language:       English
;Platform:       All
;Author:         Xt (xthaus@yahoo.com)
;    
;Script Function:
;	 Fold3 specific directory naming / managing file tools
;
;	 Public:
;	 GetDirectoryNameFromURL($url)
;	 CreateNewDirectory($name = "")
;	 DirectoryManager()
;	 LoadOldWindowState($bForceLoad = false)
;
;	 Private:
;	 None
;
;    Not Implemented:
;	 SaveWindowState()
;    
;NOTES:
;    None
;
;THANKS:
;	 None yet
;--------------------------------------------------------------------------------

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
		;AssertMsg("The URL " & _IEPropertyGet($oIE, "locationurl"))
		$bodyText = _IEBodyReadText($oIE)
		;AssertMsg($bodyText, true, 0)
		
		$year = StringRegExpMatch($bodyText, "Year:\s*(\d+)", 1, 0, "xxxx")
				
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
		
		$location = StringRegExpMatch($bodyText, "(?m)Location:\s*(.*)\s{2,}$", 1, 0, "[BLANK]")
		$incident = StringRegExpMatch($bodyText, "Incident Number:\s*(\d+)", 1, 0, "")
		;Note: More often than not cases don't have incident numbers. Due to this the debug output will show: 
		;Unhandled Exception: err: 1, using: 
		
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