MADS=mads
ATR=atr

all: bbcbasic.atr

bbcbasic.atr: autorun.sys
	cp atr/clean25.atr bbcbasic.atr
	$(ATR) bbcbasic.atr put autorun.sys
	$(ATR) bbcbasic.atr put test/clocksp.bbc
	$(ATR) bbcbasic.atr put test/hello.bbc
	$(ATR) bbcbasic.atr put test/rphone.bbc
	$(ATR) bbcbasic.atr put test/wphone.bbc
	$(ATR) bbcbasic.atr put test/rainbow.bbc
	$(ATR) bbcbasic.atr put test/dli.bbc

autorun.sys: main.s
	$(MADS) -l:debug.lst -o:$@ $<

clean:
	rm -f *.sys *.lst *.atr

cleaner: clean
	rm -f *~ */*~
