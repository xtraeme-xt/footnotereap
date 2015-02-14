/*
* Generic Screen Grab and Save (GSGS) Auto Hot Key script
* Note: requires the "AppTitle" application to accept "Page downs" to advance to the next segment of content
*
* Instructions:
* Make sure you have IrfanView installed and change line 54 to the correct path for the executable. 
*
* Change lines 39-47 to reflect:
*
* DocTitle = The name of the directory where you want to save the exported images
* AppTitle = The text in the title area of the reader window
* End = Approximate or guess the total number of pages
*
* Next edit lines 91 and 95 to adjust the boundaries of how the script extracts the page from the ALT+PRINTSCREEN of the "AppTitle" window (tip: use AutoIt3 Window Spy).
* 
* If you want high resolution images keep lines 136 to 147, otherwise just comment them out.
*
* Once everything is configured give it a run to watch it extract each frame and save it as either a BMP or a JPG. If the script goes beserk and it's not working properly hit CTRL+C to break execution.
* 
* After it's done take all of the images and stitch them together into whatever happens to be your favorite format (cbr, etc).
*  
* TODO:
*  1. I need to make sure I return all windows to their previous location and size on startup
*  2. It would be nice to have some sort of GUI so I don't have to edit the script every time I want to update
* 		the numbers
*  3. It would also be nice to have a page "comparison" feature to make sure I didn't screw up somewhere.
*  4. Generalize the whole process to make it easier to work with any document
*/

#NoEnv
#SingleInstance force
#EscapeChar \
Hotkey, ^c, Endrun
Hotkey, Pause, Pause

SetTitleMatchMode 2
SetTitleMatchMode Slow

;Add a pre-created directory name for the document in .\user\Pictures
DocTitle = SOME_FOLDER_NAME

;Partial title of the program (firefox/acrobat/etc) that contains the document to copy
AppTitle = Window title

DrawingTitle = Untitled - Paint
Start = 1
End = 360

;
;Setup paths
;

;Necessary to make sure the images are the right size
IrfanView = "C:\\app \(x86\)\\players and viewers\\imaging\\IrfanView\\i_view32.exe"

EnvGet, UserDir, USERPROFILE
CDir := UserDir . "\\Pictures\\" . DocTitle . "\\"


LoopCount := End - Start
;MsgBox %LoopCount%
Counter += Start
Counter := SubStr("0000" . Counter, -3)

WinWait, %AppTitle%, 
IfWinNotActive, %AppTitle%, , WinActivate, %AppTitle%, 
WinWaitActive, %AppTitle%, 

Loop, %LoopCount%
{
File := CDir . Counter . ".bmp"
; 
;Grab a screen cap of the %AppTitle% Reader Window. 
;
Send, {ALTDOWN}{PRINTSCREEN}{ALTUP}{ALTDOWN}{TAB}{ALTUP}
Sleep, 100

;
;Paste the screenshot in MS Paint.
;
WinWait, Paint, 
IfWinNotActive, Paint, , WinActivate, Paint, 
WinWaitActive, Paint, 
Send, {CTRLDOWN}v{CTRLUP}
MouseClick, left,  47,  66
Sleep, 100

;
;Create a selection rectangle around the part that represents the page to remove the unnecessary UI elements like the menu.
;
MouseClick, left,  81,  186,	, ,D
Sleep, 100
Send, {WheelDown 2}
Sleep, 200
MouseClick, left,  884, 1277, , ,U

;
;Cuts the selection rectangle out of the canvas
;
Send, {CTRLDOWN}x{CTRLUP}

;
;Open the "File" drop-down and selects "New." Then it tabs from "Save" to "Don't Save" and hits enter.
;
Send, {ALTDOWN}f{ALTUP}{ENTER}
Sleep, 300
WinWait, Paint, 
IfWinNotActive, Paint, , WinActivate, Paint, 
WinWaitActive, Paint, 
Send, {TAB}{ENTER}

;
;Waits for the new canvas to load. AHK knows when this has happened when the window title changes to "Untitled - Paint"
;
WinWait, %DrawingTitle%, 
IfWinNotActive, %DrawingTitle%, , WinActivate, %DrawingTitle%, 
WinWaitActive, %DrawingTitle%, 

;
;Pastes the final page that we plan to save to disk into the canvas
;
Send, {CTRLDOWN}v{CTRLUP}
Sleep, 300

;
;Opens the "File" drop-down and selects "Save As"
;
Send, {ALTDOWN}f{ALTUP}a
WinWait, Save As, 
IfWinNotActive, Save As, , WinActivate, Save As, 
WinWaitActive, Save As, 

;
; Changes the file extension to get a BMP instead of a JPG
;
Send, {Tab}
Sleep, 200
Send, 2	
Send, 2
Sleep, 200

;
;Navigates back to the textbox, pastes in the directory name, and sends enter
;IMPORTANT: Sometimes it seems to need 12 tabs rather than 11 (not sure why)
;Using Mspaint from:
;http://www.askvg.com/how-to-get-the-good-old-ms-paint-without-ribbons-working-in-windows-7/
;Uses 9 tabs. Also using %CDir% is better than using %DocTitle% as a more 
;reliable path.
;
Send, {Tab 9}
Sleep, 200
Send, %CDir%{ENTER}
Sleep, 200

;
;Inserts the filename (which is just an incrementing sequence to indicate the page number) and saves the file to disk
;
;Send, {Tab 2}
Send, %Counter%{ENTER}
Sleep, 300

Sleep, 1000
accurate := DimensionsAccurate()
if (accurate = false) {
	FileDelete, %File%
	LoopCount += 1
}

;
;Increment the page number
;
if (accurate = true) {
	Counter += 1
	Counter := SubStr("0000" . Counter, -3)
}

;
;Wait to make sure the save has finished and then navigates back to the "AppTitle" reader.
;
WinWait, Paint, 
IfWinNotActive, Paint, , WinActivate, Paint, 
WinWaitActive, Paint, 
Send, {ALTDOWN}{TAB}{ALTUP}
Sleep, 100
WinWait, %AppTitle%, 
IfWinNotActive, %AppTitle%, , WinActivate, %AppTitle%, 
WinWaitActive, %AppTitle%, 

;
;Gives the %AppTitle% reader focus by clicking in the window and hits PgDn to go to the next page. 
;
MouseClick, left,  301,  109
Sleep, 100
if(accurate = true) {
	Send, {PgDn}
}
Sleep, 1000
}

Endrun:
MsgBox, Script aborted...
ExitApp

Pause:
Pause, Toggle

DimensionsAccurate()
{
	global CDir
	global IrfanView
	global File
	
	static CorrectX = 0
	static CorrectY = 0
	
	Info := CDir . "info.txt"
	Dims := CDir . "dims.txt"
	
	;Run Irfanview on %File%
	;i_view32 %File% /info=%Info%
	RunWait, %comspec% /c %IrfanView% %File% /info=%Info%, CDir, Min
	
	;Run findstr
	;findstr /I "image dim" %Info% > %Dims%
	RunWait, %comspec% /c findstr /I "image dim" %Info% > %Dims%, CDir, Min
	
	FileRead, Contents, %Dims%
	
	StringTrimLeft, Contents, Contents, 19
	StringTrimRight, Contents, Contents, 15
	StringSplit, wh, Contents, x, %A_Space%%A_Tab%
	
	if (CorrectX = 0) {
		CorrectX = %wh1%
		MsgBox, The width is %wh1%
	}
	if (CorrectY = 0) { 
		CorrectY = %wh2%
		MsgBox, The height is %wh2%
	} 
	
	if (wh1 <> CorrectX or wh2 <> CorrectY) {
		return false
	}
	return true
}