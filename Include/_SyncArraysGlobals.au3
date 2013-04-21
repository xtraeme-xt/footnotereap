#include-once

;--------------------------------------------------------------------------------
;AutoIt Version: 3x
;Language:       English
;Platform:       All
;Author:         Xt (xthaus@yahoo.com)
;    
;Script Function:
; 	 An embarassing series of functions to try to sync arrays and globals so I don't have
;    to remember long multi-dimensional indices to get to a value. Basically this was a hack
;    to try to emulate having a pointer. All of this needs to go away at some point. 
;    
;    WARNING: Use only if you must!
;
;	 Public:
;	 CheckParity(ByRef $array, $indice, ByRef $globalvar, $msg, $msgbox)
;	 SyncArrayAndGlobals($order = 0)
;
;	 Private:
;    None
;    
;NOTES:
;    None
;
;THANKS:
;	 None yet
;--------------------------------------------------------------------------------

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
 
 
 Func SetArrays()
	Logger($ETRACE, "SetArrays()", false)
EndFunc   ;==>SetArrays