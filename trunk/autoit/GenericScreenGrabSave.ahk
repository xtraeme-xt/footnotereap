/*
* Generic Screen Grab and Save (GSGS) Auto Hot Key script
* Note: requires the "AppTitle" application to accept "Page downs" to advance to the next segment of content
*
* Instructions: 
* Change lines 37-41 to reflect:
*
* DocTitle = The name of the directory where you want to save the exported images
* AppTitle = The text in the title area of the reader window
* End = Approximate or guess the total number of pages
*
* Next edit lines 73 and 77 to adjust the boundaries of how the script extracts the page from the ALT+PRINTSCREEN of the "AppTitle" window (tip: use AutoIt3 Window Spy).
* 
* If you want high resolution images keep lines 118 to 127, otherwise just comment them out.
*
* Once everything is configured give it a run to watch it extract each frame and save it as either a BMP or a JPG. If the script goes beserk and it's not working properly hit CTRL+C to break execution.
* 
* After it's done take all of the images and stitch them together into whatever happens to be your favorite format (cbr, etc).
*  
* TODO:
*  1. I need to make sure I return all windows to their previous location and size on startup and # change
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

DocTitle = Partial directory name for document ;Add a pre-created directory name for the document in .\user\Pictures
AppTitle = Window title ;Partial title of the program (firefox/acrobat/etc) that contains the document to copy
DrawingTitle = Untitled - Paint
Start = 360
End = 361

LoopCount := End - Start
;MsgBox %LoopCount%
Counter += Start
Counter := SubStr("0000" . Counter, -3)

WinWait, %AppTitle%, 
IfWinNotActive, %AppTitle%, , WinActivate, %AppTitle%, 
WinWaitActive, %AppTitle%, 

Loop, %LoopCount%
{
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
MouseClick, left,  202,  184,	, ,D
Sleep, 100
Send, {WheelDown 2}
Sleep, 200
MouseClick, left,  890, 1090, , ,U

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

;
;Navigates back to the textbox, pastes in the directory name, and sends enter
;
Send, {Tab 11}
Sleep, 200
Send, %DocTitle%{ENTER}
Sleep, 200

;
;Inserts the filename (which is just an incrementing sequence to indicate the page number) and saves the file to disk
;
Send, {Tab 2}
Send, %Counter%{ENTER}
Sleep, 300

;
;Increment the page number
;
Counter += 1
Counter := SubStr("0000" . Counter, -3)

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
Send, {PgDn}
Sleep, 1000
}

Endrun:
MsgBox, Script aborted...
ExitApp

Pause:
Pause, Toggle