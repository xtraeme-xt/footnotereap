#include-once

;--------------------------------------------------------------------------------
;AutoIt Version: 3x
;Language:       English
;Platform:       All
;Author:         Xt (xthaus@yahoo.com)
;    
;Script Function:
; 	 Wrappers for configuration details as currently stored in the registry. This 
;    will change to allow the user to select loading from file or registry. 
;
;	 OnOffOrError($keyname, $valuename)
;	 InitializeOrReadRegistryEntry($keyname, $regsz, ByRef $global, $type = "REG_SZ")	
;    
;NOTES:
;	 Nada
;
;THANKS:
;	 None yet. 
;--------------------------------------------------------------------------------

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