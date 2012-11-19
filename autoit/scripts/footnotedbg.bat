@ECHO OFF
cscript ".\scripts\EnableDebugMode.js" > NUL
set DATETIME=%DATE:/=-%_%TIME::=.%
set LOGFILE="log\%DATETIME%_footnotereap_log.txt" 
mkdir log 2> NUL
mkdir config 2> NUL
reg export HKEY_CURRENT_USER\Software\FoonoteReaper ".\config\%DATETIME%_cfg.reg" /y
cscript ".\scripts\InternetExplorerVersion.js" >> %LOGFILE% 
echo. >> %LOGFILE% 
reg query HKEY_CURRENT_USER\Software\FoonoteReaper >> %LOGFILE% 
echo. >> %LOGFILE% 
footnote.exe | tee -a %LOGFILE%
echo. >> %LOGFILE% 
reg query HKEY_CURRENT_USER\Software\FoonoteReaper >> %LOGFILE% 
reg export HKEY_CURRENT_USER\Software\FoonoteReaper ".\config\cfg.reg" /y
