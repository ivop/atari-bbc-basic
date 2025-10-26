# BBC BASIC for the Atari XL/XE

### Differences

* The BREAK key interrupts like ESCape on the BBC. RESET key does coldstart, but you can recover your listing with OLD.
* SOUND works like Atari BASIC, i.e. SOUND voice, pitch, distortion, volume. voice+8 is right pokey if a stereo upgrade is installed
* MODE works like GRAPHICS 0-15. +16 without text window
* POINT, PLOT, DRAW, MOVE work with the Atari coordinate system(!)
* POINT works like LOCATE
* PLOT action, x, y support action 4 (MOVE), 5 (DRAW), and 69 (PLOT POINT)
* DRAW x,y shortcut for PLOT 5,x,y  (Atari BASIC DRAWTO)
* MOVE x,y shortcut for PLOT 4,x,y  (Atari BASIC POSITION)
* COLOR selects the drawing color 0-4
* GCOL acts like SETCOLOR, but takes two arguments. The color number 0-4, and what value to set it to (&00-&ff)

* ADVAL(255) to check if there's a pending keypress, all other values return 0

* OPENUP, EXT# and PTR# do not work because there's no byte accurate way
to do fseek/ftell with DOS 2.5.
* ENVELOPE does nothing
