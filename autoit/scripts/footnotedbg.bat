@ECHO OFF
cscript ".\scripts\EnableDebugMode.js" > NUL
set LOGFILE="log\%DATE:/=-%_%TIME::=.%_footnotereap_log.txt" 
mkdir log 2> NUL
cscript ".\scripts\InternetExplorerVersion.js" >> %LOGFILE% 
echo. >> %LOGFILE% 
reg query HKEY_CURRENT_USER\Software\FoonoteReaper >> %LOGFILE% 
echo. >> %LOGFILE% 
footnote.exe | tee -a %LOGFILE%
echo. >> %LOGFILE% 
reg query HKEY_CURRENT_USER\Software\FoonoteReaper >> %LOGFILE% 