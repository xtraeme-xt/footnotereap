var WshShell = WScript.CreateObject ("WScript.Shell");
WScript.Echo(WshShell.RegRead("HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Internet Explorer\\Version"));
WScript.Echo(WshShell.RegRead("HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Internet Explorer\\svcUpdateVersion"));
