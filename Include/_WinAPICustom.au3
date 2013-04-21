#include-once

;--------------------------------------------------------------------------------
;AutoIt Version: 3x
;Language:       English
;Platform:       All
;Author:         Xt (xthaus@yahoo.com)
;    
;Script Function:
; 	 Functions to dress up and tweak Windows functionality
;
;	 FixClientSize(ByRef $size)
;	 ModifyMenu($hMenu, $nID, $nFlags, $nNewID, $ptrItemData)
;    SetOwnerDrawn($hMenu, $MenuItemID, $sText)
;    
;NOTES:
;  	 None
;
;THANKS:
;	 None yet
;--------------------------------------------------------------------------------

Func WinWaitActivate($label)
   Logger($ETRACE, "WinWaitActivate(" & $label & ")", false)
   WinActivate($label_confirm_save_as)
   WinWaitActive($label_confirm_save_as)
EndFunc


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
;================ End Window Routines =================