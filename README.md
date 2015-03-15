FootnoteReaper is a quick and dirty screen scraping macro used to download content off Fold3 (previously footnote.com). The default configuration starts the user at NARA's Blue Book archive on case #2853 (November 1945 Tom's River, New Jersey incident). This can be easily changed by navigating the browser to any other page and starting the application. For more information about the impetus behind this project see Isaac Koi's "[Massive UFO disclosure in USA: A challenge for ATS](http://www.abovetopsecret.com/forum/thread730972/pg1)." 

An active discussion about the project is ongoing in "[The 154 GB NARA Blue Book Archive](http://www.abovetopsecret.com/forum/thread1032358/pg1)."

**Latest Release**: [v0.0.1.5.1](https://mega.co.nz/#!INlCWD7Z!bz_bxENvRtxrggAI1MTl8LDgGVgSoZoh8lOpA0SOsgw) (2014-09-22, pre-alpha development build). See [changelog](https://code.google.com/p/footnotereap/wiki/Changelog) for updates. Google removed the ability to add material to the download section and is now disposing of Google Code. So I'll be hosting binaries on mega.co.nz.

**Current Downloadable Archive**: BT Sync Key: [BNNTUQ6MXC2KCBONQ4DEKZ3Q5CM2V3RXF](https://link.getsync.com/?f=footnote.com&sz=0&s=2YUYYHCTX3LGHMOHY4NH2RFKSVBET3SH&i=C5ZIUMQQ6JEGEVGUVZMZJENDVJDXEUZCS&p=CAIFEKLUCVHGSQ24QY5HKSMRYPW236VP) ([instructions](http://www.abovetopsecret.com/forum/thread1032358/pg3#pid18424602))

**Project Donations**: [1KuPNuPEXCcSox4jGBq36vJxsgheuEr5b1](https://blockchain.info/address/1KuPNuPEXCcSox4jGBq36vJxsgheuEr5b1) ([instructions](https://www.youtube.com/watch?v=yeKUU3c2SmU) — see: [Coinbase](https://coinbase.com) or [WeUseCoins.com](http://weusecoins.com) for more information)

## Instructions

To run the application, you will have to have a version of Internet Explorer installed. Originally I designed the tool to be browser independent, but unfortunately due to a longstanding bug in Firefox and Chrome ([Bug #649021](https://bugzilla.mozilla.org/show_bug.cgi?id=649021 ) - ''Flash steals focus from inputs floated over it on double click''). I was forced to use browser specific features. Ideally the user should have Internet Explorer version 9 or greater. While the tool will work with IE 8 and under. Some of the more advanced features to get the year, month, case id, and location information won't be operational. 

1. [Download the application](https://mega.co.nz/#!INlCWD7Z!bz_bxENvRtxrggAI1MTl8LDgGVgSoZoh8lOpA0SOsgw) and [data files here](https://code.google.com/p/footnotereap/downloads/detail?name=DataFiles_v0.0.1.1.zip) (the data will change very infrequently)
2. Unzip the contents
3. Run FootnoteReap.lnk (or for more verbose output FootnoteReapDbg - avoid running footnote.exe directly)
4. Navigate the browser to a footnote document that you'd like to download
5. Login to your account (make sure to do this every time <i>before</i> you "Start/Resume")
6. Click "Initialize" and follow the instructions
7. Click "Start/Resume" <br>(note: when pausing please give the application 10 to 20 seconds to finish operating. If the logging facility is enabled you'll know this has completed when it prints out the statistics detailing what was recently downloaded.)

## Tips
- If the application gets stuck or you need to do a quick exit. Hit ALT+CTRL+SHIFT+E or go down to the task tray and find the following icon:

 Then right click to open the context menu:

 And click ''Exit''.

- If the program seems to be running too fast and Internet Explorer can't keep up with the input. 
    - Go to the registry by clicking, 'Edit → Registry Keys.' Then double click and edit 'gSleepMultiplier' to a value greater than 1, but less than or equal to 2. This multiplier adjusts *all* Sleep() delays in FootnoteReap by the new value. So if one of the sleeps normally runs for 200 milliseconds. After an edit with a multiplier of "1.5," the sleep will complete in 300 ms. 
    - Another option to address issue 6 (Filename/Path gets prematurely shortened in the Save As dialog), is to modify gWaitDelay in the registry to a value higher than 250ms (this is the base delay for all windows actions).

- The easiest way to enter debug mode is to run FootnoteReapDbg. To manually enable the full debug output, go to the registry (Edit → Registry Keys). Then add or edit key name "gDebug" as a REG_DWORD set to a value of 1 (or true). This will print patterns in the debug output to help locate possible race conditions. To enable all the trace and verbose output, modify gLoggerIgnoreLevel from the default 11 (user level notifications) down to 0. 

- To save the debug output, launch the application with the FootnoteReapDbg.lnk shortcut. If you experience problems. First read the [ConsoleLog] faq. Next open a command line (from the start button, click "Run," type in cmd.exe) and then [navigate to the directory](http://www.wikihow.com/Change-Directories-in-Command-Prompt) where you installed the footnotereap executable. Finally start the application by typing:`

```footnote.exe > "%DATE:/=-%_%TIME::=.%_footnotereap_log.txt"```

If this doesn't solve the problem please search the [issues list](http://code.google.com/p/footnotereap/issues/list).