MADS=mads
ATR=atr

all: bbcbasic.atr

bbcbasic.atr: autorun.sys
	cp atr/clean25.atr bbcbasic.atr
	$(ATR) bbcbasic.atr put autorun.sys
	$(ATR) bbcbasic.atr put test/clocksp.bbc
	$(ATR) bbcbasic.atr put test/rphone.bbc
	$(ATR) bbcbasic.atr put test/wphone.bbc
	$(ATR) bbcbasic.atr put test/rainbow.bbc
	$(ATR) bbcbasic.atr put test/dli.bbc
	$(ATR) bbcbasic.atr put test/sound.bbc
	$(ATR) bbcbasic.atr put test/mathspd.bbc
	$(ATR) bbcbasic.atr put test/allchars.bbc
	$(ATR) bbcbasic.atr put test/copybar.bbc
	$(ATR) bbcbasic.atr put test/overbar.bbc
	$(ATR) bbcbasic.atr put data/hp100lx.fnt
	$(ATR) bbcbasic.atr put test/asm1.bbc
	$(ATR) bbcbasic.atr put test/owl.bbc
	$(ATR) bbcbasic.atr put test/curve.bbc
	$(ATR) bbcbasic.atr put test/dmscfp.bbc

autorun.sys: main.s
	$(MADS) -l:debug.lst -o:$@ $<

clean:
	rm -f *.sys *.lst *.atr

cleaner: clean
	rm -f *~ */*~
