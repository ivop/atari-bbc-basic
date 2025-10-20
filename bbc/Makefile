MADS=mads

all: basic310hi.rom

basic.s: vars.s
	touch basic.s

basic310hi.rom: basic.s
	$(MADS) -d:BUILD_BBC_BASIC310HI=1 -o:$@ $<

clean:
	rm -f *.rom *.lst

cleaner: clean
	rm -f *~ */*~
