@ECHO OFF
cscript ".\scripts\EnableDebugMode.js" > NUL
set LOGFILE="log\%DATE:/=-%_%TIME::=.%_footnotereap_log.txt" 
mkdir log 2> NUL
cscript ".\scripts\InternetExplorerVersion.js" > %LOGFILE% 
footnote.exe | tee -a %LOGFILE%