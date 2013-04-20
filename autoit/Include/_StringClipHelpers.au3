#include-once

;--------------------------------------------------------------------------------
;AutoIt Version: 3x
;Language:       English
;Platform:       All
;Author:         Xt (xthaus@yahoo.com)
;    
;Script Function:
; 	 Functions to simplify managing the clipboard, sending from the clipboard, 
;    performing regular expressions, etc.
;
;	 Public:
;	 GetClip(ByRef $clip, $sendCtrlC = false, $stripCR = true, $count = "")
;	 IsSameAsClip($text, $selectKeyCombo="")
;	 StringGetLenChars(ByRef $origstring, $outlen)
;    StringRegExpMatch($origstring, $pattern, $flag = 0, $index = 0, $errorstring = -1, $offset = 1)
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
	    
		PushLoggerIgnoreLevel($EEVERYTHING, true, false)
		Send_KeysIndividually("{CTRLDOWN}c{CTRLUP}")
		PopLoggerIgnoreLevel(false, true)
		;Send("c")
		;Send("{CTRLUP}")
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


Func StringGetLenChars(ByRef $origstring, $outlen)
	Local $actuallen = StringLen($origstring)
	Logger($ETRACE, "StringGetLenChars(" & $actuallen & ", " & $outlen & ")", false)
	;_Iif($len <= 80, $origstring, StringTrimRight($origstring, $len-80))
	return _Iif($actuallen <= $outlen, $origstring, StringTrimRight($origstring, $actuallen-$outlen))
EndFunc


Func StringRegExpMatch($origstring, $pattern, $flag = 0, $index = 0, $errorstring = -1, $offset = 1)
	Logger($ETRACE, "StringRegExpMatch(" &  StringGetLenChars($origstring, 80) & ", " & $pattern & ", " & $flag & ", " & $index & ", " & $errorstring & ", " & $offset & ")", false)
	Local $resultstring = ""
	$returnArray  = StringRegExp($origstring, $pattern, $flag, $offset)
	if(@error > 0) then 
		Logger($EUNHANDLED, "err: " & @error & ", using: " & $errorstring, false, 60)
		if($errorstring <> -1) Then
			$resultstring  = $errorstring
		endif
	Else
		$resultstring = $returnArray[$index]
	endif
	return $resultstring
EndFunc