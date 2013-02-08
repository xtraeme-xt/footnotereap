#include <Constants.au3> 
;C:\Program Files\AutoIt3
;Local $str = StringFormat( "'%s\AutoIt3Wrapper.exe /run /prod /ErrorStdOut /in %s\Test_logger.au3 /autoit3dir ""%s"" /UserParams', %s, %s, $STDERR_CHILD + $STDOUT_CHILD", @ScriptDir, @ScriptDir,StringLeft(@AutoItExe, StringLen(@AutoItExe)-11), @SystemDir, @SW_HIDE)

if(@ScriptDir = "") Then
	$dir = @WorkingDir
Else
	$dir = @ScriptDir 
endif

$wrapperexe = FileGetShortName($dir & "\AutoIt3Wrapper.exe")
;$scriptToRun = FileGetShortName($dir & "\footnote.au3")   ;Test_logger.au3
$scriptToRun = FileGetShortName($dir & "\Test_logger.au3")   ;Test_logger.au3
$exeToRun = FileGetShortName($dir & "\footnote.exe")   ;Test_logger.au3
$auotitdir = FileGetShortName(StringLeft(@AutoItExe, StringLen(@AutoItExe)-11))

;This works with .au3's -- great for testing for errors etc.
Local $str = "" & $wrapperexe & " /run /prod /ErrorStdOut /in " & $scriptToRun & " /autoit3dir " & $auotitdir & " /UserParams"""
;Local $str = $exeToRun

;Local $str = @ScriptDir & "\AutoIt3Wrapper.exe /run /prod /ErrorStdOut /in """ & @ScriptDir & "\Test_logger.au3"" /autoit3dir """ & StringLeft(@AutoItExe, StringLen(@AutoItExe)-11) & _ 
;		        """ /UserParams', @SystemDir, @SW_HIDE, $STDERR_CHILD + $STDOUT_CHILD"
ConsoleWrite($str & @CRLF)
Local $foo = Run($str, @SystemDir, @SW_HIDE, $STDERR_CHILD + $STDOUT_CHILD) 
Local $line 
While 1
	ProcessWaitClose($foo)
	$line = StdoutRead($foo)
	If @error Then ExitLoop
	;MsgBox(0, "STDOUT read:", $line)
	ConsoleWrite("STDOUT read: " &  $line)
Wend 
While 1
	ProcessWaitClose($foo)
	$line = StderrRead($foo)
	If @error Then ExitLoop
	;MsgBox(0, "STDERR read:", $line)
	ConsoleWrite("STDERR read: " & $line
Wend
ConsoleWrite("done" & @CRLF)