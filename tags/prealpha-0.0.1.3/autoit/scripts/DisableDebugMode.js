var WshShell = WScript.CreateObject("WScript.Shell");
WshShell.RegWrite("HKCU\\SOFTWARE\\FoonoteReaper\\gDebug", 0, "REG_DWORD");
//WshShell.RegWrite("HKCU\\SOFTWARE\\FoonoteReaper\\gLoggerEnabled", 1, "REG_DWORD");
WshShell.RegWrite("HKCU\\SOFTWARE\\FoonoteReaper\\gLoggerIgnoreLevel", 10, "REG_DWORD");
