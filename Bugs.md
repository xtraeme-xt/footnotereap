## Bugs ##
As of v0.0.1.3:
  1. Occasionally gets stuck during the main download loop. Due to:
    1. <s>Send() pushing 'l' (now 'd') to the URL bar</s> - fixed v0.0.1.1
    1. Possible infinite loop because of quirky directory names
    1. <s>Getting stuck in file download due to null response</s> - fixed v0.0.1.2
    1. Other Send()'s being sent before the appropriate UI is up. More checks needed to prevent this.
  1. <s>"start/resume" and "initialize" shows and hides incorrect</s> - fixed v0.0.1.2
  1. Need to find a better way to deal with the message when ...
    1. it reports,
      1. "We're sorry, it is taking longer than expected to load information about this image." (somewhat handled)
      1. "Oops, we couldn't load information about this image." (this is more problematic)
    1. clicking "Download" and the "Save Image" dialog doesn't appear
  1. Compatibility bugs, different dialog window names prevent proper activation
  1. Dragging the console window occasionally causes the application to quit (originally noticed in v.0.0.1.2.2 ? possibly related to console routines?). <u>'''Note'''</u>: when the application crashes often the CTRL key will be hardlocked into the DOWN position. Meaning if you have a notepad open and you try to write the letter 'f' it will instead send 'CTRL+f'. To resolve this tap the CTRL key several times.