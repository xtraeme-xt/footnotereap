## Console Output and Logging Features ##

1. **Q:** I downloaded the FootnoteReapDbg.lnk but I couldn't get it to work.  I am not sure what sort of file it is or how to get it to do anything.

> <b>A:</b> The FootnoteReapDbg.lnk is the same type of file that exists for all of the shortcuts in the start menu. You can think of it like a one line batch or cmd script. If you ever want to see the command it is executing. Right click on the lnk file, select properties, and take a look at the target field. In this case it should read:

> `%COMSPEC% /E:ON /V:ON /Q /C ".\scripts\footnotedbg.bat"`

> It's important to make sure the FootnoteReapDbg.lnk file is in the directory with the footnote.exe file. Also there should be a subdirectory in the folder named .\scripts. In the scripts folder should be EnableDebugMode.js and footnotedbg.bat.

2. **Q:** I see there is an attached batch file which starts a text log to store the output of the console window (which I can see with the log information), but I cannot cut and paste. How do I do this?

> <b>A:</b> To copy and paste the text out of the console window right click in the title bar and then click "Edit → Mark"

> ![http://s6.postimage.org/vgr1vukch/ieifijcg.png](http://s6.postimage.org/vgr1vukch/ieifijcg.png)

> Next select the region of text you want to copy out and hit enter.

> ![http://s6.postimage.org/4uel6vg5d/gjcgegfh.png](http://s6.postimage.org/4uel6vg5d/gjcgegfh.png)

> At this point the text should be on the clipboard. Now in an email or a document you can paste the contents using the normal keyboard shortcut "CTRL+V" or by clicking "Edit → Paste".

> I usually modify the command window to have a buffer with a height of 9999. This way I can scroll up further.

> ![http://s6.postimage.org/vyqspfzb5/hdhegajb.png](http://s6.postimage.org/vyqspfzb5/hdhegajb.png)


3. **Q:** After running the Reaper for about 30 minutes, I exited the Reaper but I don't know where the log file is. Is it OK if I just give you a copy paste of the last few lines?

> <b>A:</b> I'd prefer it at all possible to have the entire log over a cut and paste. As a quick test, grab and unzip the [latest build](http://code.google.com/p/footnotereap/downloads/list). After it is done inflating run FootnoteReapDbg. Once the application has run for a second or two quit out of the program. Then check in the `log` folder. The name should look something like `Sun 02-12-2012_13.01.21.76_footnotereap_log`. If the log has a non-zero  size everything is working. In the event you are seeing something different. Please search the [issue list](http://code.google.com/p/footnotereap/issues/list).