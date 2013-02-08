@ECHO OFF
Rem FootnoteReap.lnk should typically only be used with build number 1
REM FootnoteReapDbg.lnk should *only* be used with build number 1
REM FootnoteReapDev.lnk should only be used with build numbers >2

set GROUP=%1
set DEBUG=%2

if NOT DEFINED GROUP set GROUP=
if NOT DEFINED DEBUG set DEBUG=false

if /I "%DEBUG%" EQU "true" (
	cscript ".\scripts\EnableDebugMode.js" > NUL
) ELSE (
	cscript ".\scripts\DisableDebugMode.js" > NUL
)

set DATETIME=%DATE:/=-%_%TIME::=.%
set LOGFILE="log\%GROUP%\%DATETIME%_footnotereap_log.txt" 

mkdir log\%GROUP% 2> NUL
mkdir config\%GROUP% 2> NUL

reg export HKEY_CURRENT_USER\Software\FoonoteReaper ".\config\%GROUP%\%DATETIME%_begin_cfg.reg" /y
cscript ".\scripts\InternetExplorerVersion.js" >> %LOGFILE% 
echo. >> %LOGFILE% 
reg query HKEY_CURRENT_USER\Software\FoonoteReaper >> %LOGFILE% 
echo. >> %LOGFILE% 
footnote.exe | tee -a %LOGFILE%
echo. >> %LOGFILE% 
reg query HKEY_CURRENT_USER\Software\FoonoteReaper >> %LOGFILE% 

reg export HKEY_CURRENT_USER\Software\FoonoteReaper ".\config\%GROUP%\%DATETIME%_end_cfg.reg" /y
copy /y ".\config\%GROUP%\%DATETIME%_end_cfg.reg" ".\config\%GROUP%\cfg.reg"
