MADS=mads
ATR=atr

all: bbcbasic.atr

bbcbasic.atr: autorun.sys
	cp atr/clean25.atr bbcbasic.atr
	$(ATR) bbcbasic.atr put autorun.sys

autorun.sys: main.s
	$(MADS) -l:debug.lst -o:$@ $<

clean:
	rm -f *.sys *.lst *.atr

cleaner: clean
	rm -f *~ */*~
