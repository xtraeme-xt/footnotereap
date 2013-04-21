#include-once

;--------------------------------------------------------------------------------
;AutoIt Version: 3x
;Language:       English
;Platform:       All
;Author:         Xt (xthaus@yahoo.com)
;    
;Script Function:
; 	 Provides asserts and logging control. The general idea behind this UDF 
;	 is to filter by a base numeric log level. All enumerated values above are 
;    displayed and those below-or-equal are not. As an example:
;	   $EVERBOSE = 3
;	   $EUSERVERBOSE = 12
;	   $EUSER = 13 
;
;	 So running $gDisableLoggerLevels = $EUSERVERBOSE. Means any call to
;	 Logger($EVERBOSE, "some message") will be ignored. 
;
;    To make exceptions for logging levels >=EVERBOSE the developer would call:
;	   PushLoggerIgnoreLevel($EVERBOSE-1, false) ;filters at >=val, need -1
;	   Logger($EVERBOSE, "some message is displayed") 
;      PopLoggerIgnoreLevel()
;
;	 Sometimes it's necessary (especially when hunting down race conditions or 
;	 intermittent infinite loops) to exempt a level despite it being below the
;	 secondary base level ($gDisableLoggerLevels). To do this you would want 
;    to run something like:
;	   SetLoggerIgnoreLevel($EUSERVERBOSE, true)
;      Logger($EVERBOSE, "this won't be displayed", false) 
;      Dim $exceptionArray[1] = [$EVERBOSE, $EINFINITELOOPDBG]
;      SetLoggerIgnoreException($exceptionArray, $EADD)
;      Logger($EVERBOSE, "this message *will* display", false) 
;      Logger($EINFINITELOOPDBG, "..", false) 

;    The inverse is not possible going from permissive to restrictive. E.g.
;      SetLoggerIgnoreLevel($ENOTHING, true)
;      Dim $exceptionArray[1] = [$EVERBOSE]
;      SetLoggerIgnoreException($exceptionArray, $EADD)
;	   Logger($EVERBOSE, "some message won't be displayed") 
;      PopLoggerIgnoreLevel(true)

;    gLoggerIgnoreLevel is the base level that the logger will never go 
;	 beneath. To change this either (1) directly set the base value (not 
;	 recommended) or (2) call:
; 	   SetLoggerIgnoreLevel(**new base level**, true, $ENOP, true) ; 4th param is key	
;
;
;FUNCTIONS:
;	 AssertMsg($msg, $bMsgBox = true, $timeout = 60)	
;	 Assert($expression, $textExpression, $msg, $bMsgBox = true, $timeout = 60)	
;
;	 Logger($code, $msg, $bMsgBox, $timeout = 0)
;	 SetLoggerIgnoreException($newArray, $operation)
;	 RemoveAllLoggerExceptions()
;	 IsLoggerCodeExempt($code)
;	 SetLoggerIgnoreLevel($code, $squelching, $op=$ENOP, $override = false)
;	 PopLoggerIgnoreLevel($squelching=false)
;	 PushLoggerIgnoreLevel($code, $squelching)
;    
;NOTES:
;	 Also see: logger.au3 in footnotereap to get an idea of how the logger can be 
;    decoupled from the application.
;
;THANKS:
;	 None yet -- be the first to fix something here. =)
;--------------------------------------------------------------------------------

;For long/automated runs /w no interaction 60 is a good value. When actively debugging use 0.
Global $gAssertTimeout = 60	
Global $gLoggerTimeout = 0		


Func _ConsoleWrite($string)
	ConsoleWrite($string)
	;if($gLoggerEnabled) then _Console_Write($string)
EndFunc


Global Enum Step +2 $EINFINITELOOPDBG=1, $EVERBOSE, $ETRACE, $EASSERT, $EUNHANDLED, $EINTERNAL, $EUSER, $EEVERYTHING
Global Enum Step +2 $ENOTHING = 0, $EUSERVERBOSE = 12
Global $gDisableLoggerLevels = $ENOTHING


;Technically I use two types of Asserts(). Ones where I want to evaluate a condition.
;And another where a condition has already been satisfied that is an edge case where
;I attempt to do something to address it, but I expect there might be bad behavior. 
;For the second type just use either:
;  Logger($EASSERT, "Year is in a nonstandard/unknown format: " & $year, true, 60)
;   Or
;  AssertMsg()
Func AssertMsg($msg, $bMsgBox = true, $timeout = $gLoggerTimeout)
	Assert(false, "AssertMsg:", $msg, $bMsgBox, $timeout)
EndFunc
	
	
Func Assert($expression, $textExpression, $msg, $bMsgBox = true, $timeout = $gLoggerTimeout)		
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


Func Logger($code, $msg, $bMsgBox, $timeout = $gLoggerTimeout)
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
			_ConsoleWrite("Verbose: " & $msg & @CRLF)
			if $bMsgBox then MsgBox(64, "Verbose", $msg, $timeout);
		Case $code = $ETRACE
			_ConsoleWrite("Trace: " & $msg & @CRLF)
			if $bMsgBox then MsgBox(64, "Trace", $msg & @CRLF, $timeout);
		Case $code = $EASSERT
			_ConsoleWrite("Assert: " & $msg & @CRLF)
			if $bMsgBox then MsgBox(64, "Assert", $msg & @CRLF, $timeout);
		Case $code = $EUNHANDLED ;was 1
			_ConsoleWrite("Unhandled Exception: " & $msg & @CRLF)
			if $bMsgBox then MsgBox(64, "Unhandled Exception", $msg, $timeout);
		Case $code = $EINTERNAL ;was 5
			_ConsoleWrite("Internal Error: " & $msg & @CRLF)
			if $bMsgBox then MsgBox(48, "Internal Error", $msg, $timeout);
		Case $code = $EUSERVERBOSE
			_ConsoleWrite("UVerbose: " & $msg & @CRLF)
			if $bMsgBox then MsgBox(48, "User Verbose", $msg, $timeout);
		Case $code = $EUSER
			_ConsoleWrite("Notification: " & $msg & @CRLF)
			if $bMsgBox then MsgBox(48, "Notification", $msg, $timeout);
		Case Else
			_ConsoleWrite("Unknown Error Level: (#" & $code & "): " & $msg & @CRLF)
			if $bMsgBox then MsgBox(64, "Unknown Error Level:", "(Err#:" & $code & "): " & $msg & @CRLF, $timeout);
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
Func SetLoggerIgnoreLevel($code, $squelching, $op=$ENOP, $override = false, $verbose=true)
;If $EPOP fails then it will use the $code as the new 
	if($verbose) Then Logger($ETRACE, "SetLoggerIgnoreLevel(" & $code & "," & $squelching & ")", false)
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
			;BUG?: $gDisableLoggerLevels isn't an array! 
		endif
	Else
		;The setting we read in from the registry determines how low the logger can go
		if($gLoggerIgnoreLevel > $code) Then
			if($op = $EPUSH and $gLoggerIgnoreLevel = $gPushLevels[$index]) Then
				_ArrayDelete($gDisableLoggerLevels, $index)
				;BUG?: $gDisableLoggerLevels isn't an array! 
			endif
			$gDisableLoggerLevels = $gLoggerIgnoreLevel
		Else
			$gDisableLoggerLevels = $code
		endif
	endif
	;ConsoleWrite($gDisableLoggerLevels & @CRLF)
EndFunc   ;==>SetLoggerIgnoreLevel


Func PopLoggerIgnoreLevel($squelching=false, $verbose=true)
	if($verbose) Then Logger($ETRACE, "PopLoggerIgnoreLevel(" & $squelching & ")", false)
	SetLoggerIgnoreLevel($gDisableLoggerLevels, $squelching, $EPOP, false, $verbose)
EndFunc


Func PushLoggerIgnoreLevel($code, $squelching, $verbose=true)
	if($verbose) Then Logger($ETRACE, "PushLoggerIgnoreLevel(" & $code & "," & $squelching & ")", false)
	return SetLoggerIgnoreLevel($code, $squelching, $EPUSH, false, $verbose)
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