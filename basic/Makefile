MADS=mads

all: basic310hi.rom basic.xex

basic.s: vars.s
	touch basic.s

basic.xex: basic.s
	$(MADS) -d:TARGET_ATARI=1 -d:SKIP_INI_LOADER=1 -d:VBREAK=0x0206 -o:$@ $<

basic310hi.rom: basic.s
	$(MADS) -d:TARGET_BBC=1 -o:$@ $<

clean:
	rm -f *.rom *.xex *.lst

cleaner: clean
	rm -f *~ */*~
