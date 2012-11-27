var WshShell = WScript.CreateObject("WScript.Shell");
WshShell.RegWrite("HKCU\\SOFTWARE\\FoonoteReaper\\gDebug", 1, "REG_DWORD");
//WshShell.RegWrite("HKCU\\SOFTWARE\\FoonoteReaper\\gLoggerEnabled", 0, "REG_DWORD");
WshShell.RegWrite("HKCU\\SOFTWARE\\FoonoteReaper\\gLoggerIgnoreLevel", 0, "REG_DWORD");
