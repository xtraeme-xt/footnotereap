@ECHO OFF

set GROUP=%1
if NOT DEFINED GROUP set GROUP=

cscript ".\scripts\EnableDebugMode.js" > NUL

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
