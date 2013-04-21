@ECHO OFF
Rem FootnoteReap.lnk should typically only be used with build number 1
REM FootnoteReapDbg.lnk should *only* be used with build number 1
REM FootnoteReapDev.lnk should only be used with build numbers >2

set GROUP=%1
set DEBUG=%2

if NOT DEFINED GROUP set GROUP=
if NOT DEFINED DEBUG set DEBUG=false

if /I "%DEBUG%" EQU "true" (
	cscript //E:jscript ".\scripts\EnableDebugMode.js" > NUL 
) ELSE (
	cscript //E:jscript ".\scripts\DisableDebugMode.js" > NUL
)
REM If you get the error message below:
REM Input Error: There is no script engine for file extension ".js".
REM
REM First you might want to try:
REM assoc .js=JSFile
REM
REM If the association doesn't fix it. Try running:
REM regsvr32 /s %systemroot%\system32\jscript.dll

set DATETIME=%DATE:/=-%_%TIME::=.%
set LOGFILE="log\%GROUP%\%DATETIME%_footnotereap_log.txt" 

mkdir log\%GROUP% 2> NUL
mkdir config\%GROUP% 2> NUL

reg export HKEY_CURRENT_USER\Software\FoonoteReaper ".\config\%GROUP%\%DATETIME%_begin_cfg.reg" /y
cscript //E:jscript ".\scripts\InternetExplorerVersion.js" >> %LOGFILE% 
echo. >> %LOGFILE% 
reg query HKEY_CURRENT_USER\Software\FoonoteReaper >> %LOGFILE% 
echo. >> %LOGFILE% 
footnote.exe | tee -a %LOGFILE%
echo. >> %LOGFILE% 
reg query HKEY_CURRENT_USER\Software\FoonoteReaper >> %LOGFILE% 

reg export HKEY_CURRENT_USER\Software\FoonoteReaper ".\config\%GROUP%\%DATETIME%_end_cfg.reg" /y
copy /y ".\config\%GROUP%\%DATETIME%_end_cfg.reg" ".\config\%GROUP%\cfg.reg"
