#include-once

;--------------------------------------------------------------------------------
;AutoIt Version: 3x
;Language:       English
;Platform:       All
;Author:         Xt (xthaus@yahoo.com)
;    
;Script Function:
;	 Input overrides ...
;
;	 Public:
;	 Send_KeysIndividually($keys, $flag)
;
;	 Private:
;    None
;    
;NOTES:
;    This is useful for debugging. It helps to slow down each action to make it
;    visible
;
;THANKS:
;	 None yet
;--------------------------------------------------------------------------------

;Take an innocuous command like:
;  Send("{tab}{tab}{tab}{enter}")
; This will send three tabs and then hit enter. The problem?
; The Send() only takes advantage of the gWaitDelay once (250ms).
; All subsequent issuances will be sent as quickly as possible. 
; This is problematic when trying to emulate user behavior sending keys at a human rate. 
; So rather than having to do:
; Send("{tab}")
; Sleep(250)
; Send("{tab}")
; This function automates the process. 
Func Send_KeysIndividually($keys, $flag=0, $delayms=0)
   Logger($ETRACE, "Send_KeysIndividually(" & $keys & ", " & $flag & ")", false)
   $bSimkeys = _Iif(StringInStr($keys, "{"), true, false)
   Dim $test[1] = [""]
   for $I = 1 to StringLen($keys)
	  $vkey = StringLeft($keys, 1)
	  if($bSimkeys And StringCompare($vkey, "{") = 0) Then
		 $vkey = StringRegExpMatch($keys, "(\{(?U).*\})", 1)
		 $I += StringLen($vkey)-1
		 ;AssertMsg($vkey)
	  EndIf
	  _ArrayAdd($test, $vkey)
	  Send($vkey, $flag)
	  if($delayms > 0) then Sleep($delayms)
	  $keys = StringTrimLeft($keys, StringLen($vkey))
	  ;AssertMsg($keys)
   Next
   ;_ArrayDisplay($test, "List of keys")
EndFunc