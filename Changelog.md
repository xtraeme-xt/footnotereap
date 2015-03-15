## Change Log ##



&lt;hr&gt;


<font size='1'>ver. <b>a</b>.<b>b</b>.<b>c</b>.<b>d</b>.<b>e</b></font><br>
<font size='1'><b>a</b> = major version</font>
<br><font size='1'><b>b</b> = milestone goal reached</font>
<br><font size='1'><b>c</b> = todo enhancements and feature additions</font>
<br><font size='1'><b>d</b> = bugs and more involved fixes</font>
<br><font size='1'><b>e</b> = hotfix (minor changes and platform specific issues)</font><br>

<br>
<br>
<hr><br>
<br>
<br>
<br>
Head = <a href='http://sigsno.org/footnotereap/FootnoteReap_v0.0.1.5.1.zip'>v0.0.1.5.1</a> (2014-09-22)<br>
<ul><li>Fixed broken build - updated code so it's compatible with new Fold3 URLs (see <a href='https://code.google.com/p/footnotereap/source/detail?r=103'>r103</a> & <a href='https://code.google.com/p/footnotereap/source/detail?r=104'>r104</a>)</li></ul>


<a href='http://code.google.com/p/footnotereap/downloads/detail?name=FootnoteReap_v0.0.1.5.zip'>v0.0.1.5</a> (2013-04-20)<br>
<ul><li>Compatibility Build — should run on all versions of Windows 7 (see <a href='https://code.google.com/p/footnotereap/source/detail?r=90'>r90</a>)<br>
</li><li>Found and resolved several timing issues (using bindings based on WinWaits and other definitive knowns rather than magic number timeouts in Sleep() calls - see <a href='https://code.google.com/p/footnotereap/source/detail?r=90'>r90</a>)<br>
</li><li>Fixed several console issues (see <a href='https://code.google.com/p/footnotereap/source/detail?r=92'>r92</a>)<br>
</li><li>Miscellaneous bug fixes</li></ul>


<a href='http://code.google.com/p/footnotereap/downloads/detail?name=FootnoteReap_v0.0.1.4%20%28v2%29.zip'>v0.0.1.4</a> (2013-02-08)<br>
<ul><li>Numerous modifications to attempt to solve <a href='https://code.google.com/p/footnotereap/issues/detail?id=6'>issue 6</a>, <a href='https://code.google.com/p/footnotereap/issues/detail?id=14'>issue 14</a>, and <a href='https://code.google.com/p/footnotereap/issues/detail?id=18'>issue 18</a>. (see <a href='https://code.google.com/p/footnotereap/source/detail?r=73'>r73</a> 2.E)<br>
</li><li>On program restart, improved capacity to check whether the current URL is a part of the last batch of downloaded files, a part of a previous batch of downloaded files, or if the person is starting from a new URL. So, in affect, footnotereap more tightly pairs the current URL with the correct directory so it doesn't overwrite old data or miss new data. (see <a href='https://code.google.com/p/footnotereap/source/detail?r=73'>r73</a> 2.F and 2.D)<br>
</li><li>Minor bug fixes (directory partial match issue - <a href='https://code.google.com/p/footnotereap/source/detail?r=73'>r73</a> 2.C, cleaning text on clipboard - <a href='https://code.google.com/p/footnotereap/source/detail?r=73'>r73</a> 2.A, and more)<br>
</li><li>FootnoteReap.lnk switches user back to release mode (low debug output). FootnoteReapDbg.lnk switches users to verbose output.</li></ul>


<a href='http://code.google.com/p/footnotereap/downloads/detail?name=FootnoteReap_v0.0.1.3.zip'>v0.0.1.3</a> (2012-11-24)<br>
<ul><li>Testing modifications to address <a href='https://code.google.com/p/footnotereap/issues/detail?id=6'>issue 6</a> (Filename/Path gets prematurely shortened in the Save As dialog). Try setting gWaitDelay in the registry to a value higher than 250 if the application is missing clicks or advancing too quickly. (see <a href='https://code.google.com/p/footnotereap/source/detail?r=65'>r65</a>)<br>
</li><li>Fixes to <a href='https://code.google.com/p/footnotereap/issues/detail?id=22'>issue 22</a> (Incorrect date format (year.month) where month is >12) (see <a href='https://code.google.com/p/footnotereap/source/detail?r=65'>r65</a>)<br>
</li><li>The debug script now saves registry entries between runs, better categorizes log files, and the batch has been updated to auto-save IE version, reg values, and other system data each run (see <a href='https://code.google.com/p/footnotereap/source/detail?r=66'>r66</a>)</li></ul>


<a href='http://wiki.razing.net/footnotereap/FootnoteReap_v0.0.1.2.3.zip'>v0.0.1.2.3</a> (2012-02-18, Hotfix)<br>
<ul><li>Fixed: Line 11298 (File "C:\Users\Extreme\Desktop\Footnote\footnote.exe"): Error: Variable used without being declared''<br>
</li><li>Modified launch scripts</li></ul>


<a href='http://wiki.razing.net/footnotereap/FootnoteReap_v0.0.1.2.2.zip'>v0.0.1.2.2</a> (2012-02-17, Hotfix)<br>
<ul><li>Recompiled the executable as a console application and disabled embedded kernel32.dll calls. The logger is now always enabled. All output should be capturable through STDOUT. The gLoggerEnabled REG_DWORD is now deprecated.<br>
</li><li>Fixed dynamic directory creation. FootnoteReap should now correctly detect "page 1" and "page 1.jpg" in the "Save As" dialog.<br>
</li><li>Added a new emergency exit hotkey (ALT+CTRL+SHIFT+E) and resolved a logic bug that should have prevented the application from ever working.</li></ul>


<a href='http://wiki.razing.net/footnotereap/FootnoteReap_v0.0.1.2.1.zip'>v0.0.1.2.1</a> (2011-10-03, Hotfix)<br>
<ul><li>Now detects "Save As" and "Select location for download ..." after clicking "Entire Image"</li></ul>


<a href='http://wiki.razing.net/footnotereap/footnote_v0.0.1.2.exe'>v0.0.1.2</a> (2011-08-21)<br>
<ul><li>GUI fixes (the start/resume and initialize button toggles correctly now; and the 'about' dialog anchors properly to the main window in all cases)<br>
</li><li>improved logging tool / better debug features (to help detect and prevent infinite loops -- see "<a href='http://code.google.com/p/footnotereap/#Tips'>tips</a>")<br>
</li><li>fixed several race conditions where the application would get stuck:<br>
<ul><li>trying to rediscover the "Entire Image" button,<br>
</li><li>when resolving "Confirm Save As" during a collision, and<br>
</li><li>an instance where the download would wait indefinitely for the data pump to start when the pipe was inactive</li></ul></li></ul>


<a href='http://wiki.razing.net/footnotereap/footnote_v0.0.1.1.exe'>v0.0.1.1</a> (2011-08-20)<br>
<ul><li>bug fixes (better directory handling and more)<br>
</li><li>using "ALT+D" now instead of "CTRL+L" for greater compatibility</li></ul>


<a href='http://wiki.razing.net/footnotereap/FootnoteReap_v0.0.1.0.zip'>v0.0.1.0</a> (2011-08-19)<br>
<ul><li>Basic feature set functional (downloading, resuming, recovery cases, automated directory creation, etc)<br>
</li><li>Global hotkeys (F10 - start, F11 - pause)<br>
</li><li>Logging feature set<br>
</li><li>Simple statistics (page and doc counts)<br>
</li><li>Identifies new documents not previously stored in CSV.