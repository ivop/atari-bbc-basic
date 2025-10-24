# BBC BASIC for the Atari XL/XE

### Differences

* The BREAK key interrupts like ESCape on the BBC. RESET key does coldstart, but you can recover your listing with OLD.
* SOUND works like Atari BASIC, i.e. SOUND channel, frequency, distortion, volume. channel+8 is right pokey if a stereo upgrade is installed
* MODE works like GRAPHICS
* POINT, PLOT, DRAW, and MOVE work like Atari BASIC's LOCATE, PLOT, DRAWTO, and POSITION. It's not trivial to emulate the BBC viewport as the Atari OS does not accept offscreen coordinates. Resolution and colors are off anyway.

* ADVAL(255) to check if there's a pending keypress, all other values return 0

* OPENUP, EXT# and PTR# do not work because there's no byte accurate way
to do fseek/ftell with DOS 2.5.
* ENVELOPE does nothing
