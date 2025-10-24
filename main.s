; ----------------------------------------------------------------------------
;
; BBC BASIC 3.10 for the ATARI 8-BIT
;
; MOS Translation layer Copyright © 2025 by Ivo van Poorten
; BBC BASIC 3.10 © 1983 by Acorn and Sophie Wilson
; mads disassembly by Ivo van Poorten, October 2025
; Loader based on Turbo Basic 1.5 Copyright © 1985 by Frank Ostrowski
; Disassembled by DMSC 2017-2021
;
; ----------------------------------------------------------------------------

BOOT   = $09
DOSVEC = $0a
DOSINI = $0c
APPMHI = $0e
RTCLOK = $12
RAMTOP = $6a

VDSLST = $0200
VBREAK = $0206
VIMIRQ = $0216
VVBLKI = $0222
BRKKY  = $0236

COLDST = $0244

COLOR0 = $02c4
COLOR1 = $02c5
COLOR2 = $02c6
COLOR3 = $02c7
COLOR4 = $02c8

_MEMTOP = $02e5
_MEMLO  = $02e7

CRSINH = $02f0

CHBAS  = $02f4

IOCB0  = $0340
IOCB1  = $0350
IOCB2  = $0360
IOCB3  = $0370
IOCB4  = $0380
IOCB5  = $0390
IOCB6  = $03a0
IOCB7  = $03b0

BASICF = $03f8

ICHID  = $00
ICDNO  = $01
ICCOM  = $02
ICSTA  = $03
ICBAL  = $04
ICBAH  = $05
ICPTL  = $06
ICPTH  = $07
ICBLL  = $08
ICBLH  = $09
ICAX1  = $0a
ICAX2  = $0b
ICAX3  = $0c
ICAX4  = $0d
ICAX5  = $0e
ICAX6  = $0f

COPEN = 3
CCLSE = 12
CGTXT = 5
CPTXT = 9
CGBIN = 7
CPBIN = 11

PORTB  = $d301

NMIEN  = $d40e
NMIRES = $d40f
NMIST  = $d40f

EDITRV = $e400
KEYBDV = $e420

CIOV   = $e456

NMI_VECTOR = $fffa
IRQ_VECTOR = $fffe

; ----------------------------------------------------------------------------

; Load temporary ZP locations

start_addr = $e0
end_addr   = $e2
bufp       = $e4
tmp1       = $e6

; ----------------------------------------------------------------------------

; MOS Translation Layer ZP locations

ptr = $e0
ptr2 = $e2
save_a = $e4
save_x = $e5
save_y = $e6
irq_a = $e7

; ----------------------------------------------------------------------------

    org $2000

; BBC Micro font with Atari control characters

FONT:
    icl 'font.s'

; ----------------------------------------------------------------------------

; Splash screen
; Code will be overwritten

    org $2400

.proc splash
    mva #>FONT CHBAS
    sta CRSINH
    mwa #$3c00 _MEMLO

    mwa #message IOCB0+ICBAL
    mwa #(end_message-message) IOCB0+ICBLL
    mva #$0b IOCB0+ICCOM
    ldx #0
    jsr CIOV
    rts
.endp

message:
    dta 125,155,155,'BBC BASIC 3.10',155,155
end_message:

; ----------------------------------------------------------------------------

    ini splash

; ----------------------------------------------------------------------------
; ============================================================================
; ----------------------------------------------------------------------------

; Permanent code

    org $2400

; CIOV wrapper

.proc call_ciov
    inc PORTB
    jsr CIOV
    dec PORTB
    cpy #0
    rts
.endp

; ----------------------------------------------------------------------------

; NMI/IRQ prologue, switches off ROM again

.proc nmi_end
    pla
    tax
.endp

; [[fallthrough]]

.proc irq_end
    dec PORTB
    pla
    rti
.endp

; ----------------------------------------------------------------------------

; NMI when ROM is off

.proc nmi_proc
    bit NMIST
    bpl @+
    jmp (VDSLST)

@:
    pha
    txa
    pha

    lda #>nmi_end
    pha
    lda #<nmi_end
    pha
    tsx
    lda $0105,x
    pha

    cld
    pha
    txa
    pha
    tya
    pha

    inc PORTB
    sta NMIRES
    jmp (VVBLKI)
.endp

; ----------------------------------------------------------------------------

; IRQ when ROM is off

.proc irq_proc
    sta irq_a

    pla
    pha
    and #$10
    beq no_BRK

    pla
    pla
    sec
    sbc #1
    sta FAULT+0
    pla
    sbc #0
    sta FAULT+1
    jmp (BRKV)

no_BRK:
    lda irq_a
    pha

    lda #>irq_end
    pha
    lda #<irq_end
    pha
    php

    inc PORTB

    jmp (VIMIRQ)
.endp

; ----------------------------------------------------------------------------

.proc reset_proc
    mva #>FONT CHBAS

INIDOS:
    jsr $1234

    mva #$fe PORTB
    mwa #$3c00 _MEMLO
    mwa #irq_break_key BRKKY

    jmp $c000
.endp

; ----------------------------------------------------------------------------

.proc close_iocb
    mva #CCLSE IOCB0+ICCOM,x
    jmp call_ciov
.endp

; ----------------------------------------------------------------------------

.proc getkey
    inc PORTB
vector = * + 1
    jsr $1234
    dec PORTB
    rts
.endp

; ----------------------------------------------------------------------------

.proc irq_break_key
    mva #$ff ESCFLG
old_vector = * + 1
    jmp $1234
.endp

; ----------------------------------------------------------------------------

.proc save_axy
    sta save_a
.endp
.proc save_xy
    stx save_x
    sty save_y
    rts
.endp

; ----------------------------------------------------------------------------

.proc restore_axy
    lda save_a
.endp
.proc restore_xy
    ldx save_x
    ldy save_y
    rts
.endp

; ----------------------------------------------------------------------------

.proc eol_to_atari_ptr2
    ldy #$ff
@:
    iny
    lda (ptr2),y
    cmp #$0d            ; check for CR/EOL
    bne @-

    lda #155            ; restore Atari EOL
    sta (ptr2),y
    rts
.endp

; ----------------------------------------------------------------------------
; MOS TRANSLATION LAYER
;

; CIO Channels
;   #0      Reserved, always opened by E:
;   #1-#5   Used for file handles
;   #6      Opened by S: for graphical modes
;   #7      Internal use, LOAD, SAVE, DIR

; Channels / file handles #1-#5
;  0 - free
; !0 - in-use

channels_inuse:
    dta 0,0,0,0,0
channels_ungetc_data:
    dta 0,0,0,0,0
channels_ungetc_flags:
    dta 0,0,0,0,0

; ----------------------------------------------------------------------------
; OSFIND
;
.proc handle_out_of_range
    brk
    dta 0,'Handle out of range',0
.endp

.proc osfind_openup_unsupported
    brk
    dta 0,'OPENUP unsupported',0
.endp

.proc OSFIND
    cmp #$00
    beq osfind_close_handle
    cmp #$40                        ; openin
    beq osfind_openin
    cmp #$80                        ; openout
    beq osfind_openout
    cmp #$c0                        ; openup not possible with DOS 2.5
    beq osfind_openup_unsupported

    brk
    dta 0,'Unsuported OSFIND call',0
.endp

.proc osfind_close_handle
    jsr save_axy
    tya
    beq close_all_handles

    cpy #6
    bcs handle_out_of_range     ; >= 6 is out of range

    lda #0
    sta channels_inuse-1,y
    sta channels_ungetc_flags-1,y
    tya
    asl
    asl
    asl
    asl
    tax
    jsr close_iocb
    jmp restore_axy
.endp

.proc close_all_handles
    ldx #$50
close_all:
    jsr close_iocb
    txa
    sec
    sbc #$10
    tax
    bne close_all

    ldy #4
    txa
set_free:
    sta channels_inuse,y
    sta channels_ungetc_flags,y
    dey
    bpl set_free

    jmp restore_axy
.endp

.proc osfind_openin
    lda #4
    bne osfind_open_common
.endp

.proc osfind_openout
    lda #8
    ; [[fallthrough]]
.endp

; enter with A=4 for reading, and A=8 for writing

.proc osfind_open_common
    sta save_a
    jsr save_xy

    stx ptr2
    sty ptr2+1

    jsr eol_to_atari_ptr2

    ldx #0
@:
    lda channels_inuse,x
    beq channel_found
    inx
    cpx #5
    beq error
    bne @-

channel_found:
    stx ptr
    inx
    txa
    asl
    asl
    asl
    asl
    tax
    mwa ptr2 IOCB0+ICBAL,x            ; filename
    mva save_a IOCB0+ICAX1,x
    mva #0 IOCB0+ICAX2,x
    mva #COPEN IOCB0+ICCOM,x
    jsr call_ciov
    bmi error

    ldx ptr
    lda #1
    sta channels_inuse,x
    inx
    txa                             ; handle 1-5 in A

    jmp restore_xy

error:
    lda #0
    jmp restore_xy
.endp

; ----------------------------------------------------------------------------
; OSBPUT
;
.proc OSBPUT
    jsr save_axy
    cpy #1
    bcc too_low
    cpy #6
    bcs too_high

    tya
    asl
    asl
    asl
    asl
    tax

    mva #CPBIN IOCB0+ICCOM,x
    mwa #1 IOCB0+ICBLL,x
    mwa #save_a IOCB0+ICBAL,x
    jsr call_ciov

too_low:                    ; docs say nothing about errors returned
too_high:
    jmp restore_axy
.endp

; ----------------------------------------------------------------------------
; OSBGET
;
.proc OSBGET
    jsr save_xy

    cpy #1
    bcc too_low
    cpy #6
    bcs too_high

    lda channels_ungetc_flags-1,y
    beq get_byte_from_media

    ; we have an 'ungetc'd byte stored

    lda #0
    sta channels_ungetc_flags-1,y
    lda channels_ungetc_data-1,y
    clc
    jmp restore_xy

get_byte_from_media:
    tya
    asl
    asl
    asl
    asl
    tax

    mva #CGBIN IOCB0+ICCOM,x
    mwa #1 IOCB0+ICBLL,x
    mwa #save_a IOCB0+ICBAL,x
    jsr call_ciov
    bmi eof

    clc
    jmp restore_xy

eof:
too_low:
too_high:
    sec
    jmp restore_xy
.endp

; ----------------------------------------------------------------------------
; OSARGS
;
.proc OSARGS
    brk
    dta 0,'PTR/EXT Unsupported',0
    ; Not possible with DOS 2.5
    ; 0x00 PTR#
    ; 0x01 PTR#=
    ; 0x02 EXT#=
.endp

; ----------------------------------------------------------------------------
; OSFILE
;
.proc OSFILE
    stx ptr
    sty ptr+1

    cmp #$ff
    beq osfile_load
    cmp #$00
    beq osfile_save

    brk
    dta 0,'Unsupported OSFILE call',0
.endp

.proc osfile_load
    lda #4                          ; open for reading
    jsr osfile_common_load_save

    ldy #2
    lda (ptr),y                     ; get LOAD address
    sta IOCB7+ICBAL
    iny
    lda (ptr),y
    sta IOCB7+ICBAH

    lda #$ff                        ; 65535 bytes maximum length
    sta IOCB7+ICBLL                 ; (just load until EOF)
    sta IOCB7+ICBLH

    mva #CGBIN IOCB7+ICCOM
    jmp call_ciov
.endp

.proc osfile_save
    lda #8                          ; open for writing
    jsr osfile_common_load_save

    ldy #10
    mva (ptr),y IOCB7+ICBAL
    iny
    mva (ptr),y IOCB7+ICBAH

    ldy #14
    sec
    lda (ptr),y                     ; length = end address - save address
    sbc IOCB7+ICBAL
    sta IOCB7+ICBLL
    iny
    lda (ptr),y
    sbc IOCB7+ICBAH
    sta IOCB7+ICBLH

    mva #CPBIN IOCB7+ICCOM
    jsr call_ciov
    bmi cio_error

    jmp close_iocb
.endp

.proc cio_error
    brk
    dta 0,'I/O Error',0
.endp

; Enter with A=4 (read) or A=8 (write)
;
.proc osfile_common_load_save
    sta save_a          ; save open mode

    ldx #$70
    jsr close_iocb

    ldy #0              ; get pointer to filename
    mva (ptr),y ptr2    ; into ptr2
    iny
    mva (ptr),y ptr2+1

    jsr eol_to_atari_ptr2

    mwa ptr2 IOCB7+ICBAL            ; open file
    mva save_a IOCB7+ICAX1          ; open mode from save_a
    mva #0 IOCB7+ICAX2
    mva #COPEN IOCB7+ICCOM
    jsr call_ciov
    bmi cio_error

    rts
.endp

; ----------------------------------------------------------------------------
; OSRDCH
;
.proc OSRDCH
    jmp getkey
.endp

; ----------------------------------------------------------------------------
; OSNEWL
;
.proc OSNEWL
    lda #$0d
.endp

    ; [[fallthrough]]

; ----------------------------------------------------------------------------
; OSASCI
;
.proc OSASCI
.endp

    ; [[fallthrough]]

; ----------------------------------------------------------------------------
; OSWRCH
;
.proc OSWRCH
    jsr save_axy

;    cmp #$0c
;    bne nocls
;    lda #125
;nocls:

    cmp #$0d
    bne noeol

    lda #155

noeol:
    sta buf

    mva #11 IOCB0+ICCOM
    mwa #1 IOCB0+ICBLL
    mwa #buf IOCB0+ICBAL
    ldx #0
    jsr call_ciov

    jmp restore_axy

buf:
    dta 0
.endp

; ----------------------------------------------------------------------------
; OSWORD
;
.proc osword_error
    brk
    dta 0,'Unsupported OSWORD call', 0
.endp

.proc OSWORD
    cmp #$00
    beq read_line
    cmp #$01
    beq get_clock_in_cs
    cmp #$02
    beq set_clock
    bne osword_error
.endp

    ; $09   read pixel value

.proc read_line
    stx ptr
    sty ptr+1

    ldy #0
    lda (ptr),y
    sta IOCB0+ICBAL
    sta ptr2
    iny
    lda (ptr),y
    sta IOCB0+ICBAH
    sta ptr2+1

    mwa #127 IOCB0+ICBLL
    mva #CGTXT IOCB0+ICCOM
    ldx #0

    jsr call_ciov
    bmi break_key

    ldy #$ff
@:
    iny
    lda (ptr2),y
    cmp #$9b            ; Atari EOL
    bne @-

    lda #$0d
    sta (ptr2),y

    iny
    clc
    rts
.endp

.proc get_clock_in_cs
    mva #0 NMIEN
    stx ptr
    sty ptr+1
    ldy #0

    lda RTCLOK+2
    asl
    sta (ptr),y

    iny
    lda RTCLOK+1
    rol
    sta (ptr),y

    iny
    lda RTCLOK+0
    rol
    sta (ptr),y

    iny
    lda #0
    rol
    sta (ptr),y

    iny
    lda #0
    sta (ptr),y

    mva #$40 NMIEN
    rts
.endp

.proc set_clock
    mva #0 NMIEN
    stx ptr
    sty ptr+1
    ldy #2

    lda (ptr),y
    lsr
    sta RTCLOK+0

    dey
    lda (ptr),y
    ror
    sta RTCLOK+1

    dey
    lda (ptr),y
    ror
    sta RTCLOK+2

    mva #$40 NMIEN
    rts
.endp

.proc break_key
    mva #$ff ESCFLG
    rts
.endp

; ----------------------------------------------------------------------------
; OSBYTE
;
; Graphics MODES                                        MEMTOP
;   0       40x24 text                                  $bc1f
;
;   7       160x80 graphics (4 colors) +  40x4 text     $afa1
;   8       320x160 graphics (mono) + 40x4 text         $a04f
;   15      160x160 graphics (4 colors) + 40x4 text     $a04f
;
;   7+16    160x96 graphics (4 colors)                  $af97
;   8+16    320x192 graphics (mono)                     $a035
;   15+16   160x192 graphics (4 colors)                 $a035

.proc bottom_of_screen_mode_X
    cpx #7
    beq gr7
    cpx #8
    beq gr8gr15
    cpx #15
    beq gr8gr15

    cpx #7+16
    beq gr7_16
    cpx #8+16
    beq gr8gr15_16
    cpx #15+16
    beq gr8gr15_16

gr0:
    ldx #<$bc1f
    ldy #>$bc1f
    rts

gr7:
    ldx #<$afa1
    ldy #>$afa1
    rts

gr8gr15:
    ldx #<$a04f
    ldy #>$a04f
    rts

gr7_16:
    ldx #<$af97
    ldy #>$af97
    rts

gr8gr15_16:
    ldx #<$a035
    ldy #>$a035
    rts
.endp

.proc check_eof_on_handle
    pha
    tya
    pha

    cpx #1
    bcc eof
    cpx #6
    bcs eof

    lda channels_ungetc_flags-1,x
    bne have_byte                   ; we already have a byte ungetc'd

    txa
    tay
    jsr OSBGET                      ; try reading a byte
    bcs eof

    sta channels_ungetc_data-1,x    ; save for when BGET is called
    lda #1
    sta channels_ungetc_flags-1,x   ; flag we have an ungetc'd byte

have_byte:
    ldx #0
    beq done
eof:
    ldx #$ff
done:
    pla
    tay
    pla
    rts
.endp

.proc OSBYTE
    cmp #$7e
    beq set_escflg
    cmp #$7f
    beq check_eof_on_handle
    cmp #$80
    beq no_adval
    cmp #$81
    beq read_key_with_timeout
    cmp #$82
    beq get_high_order_address
    cmp #$83
    beq get_LOMEM
    cmp #$84
    beq get_HIMEM
    cmp #$85
    beq bottom_of_screen_mode_X
    cmp #$86
    beq pos_vpos_notimpl
    cmp #$da
    beq vdu_queue

    jmp *
.endp

.proc set_escflg
    sta ESCFLG
    rts
.endp

.proc get_high_order_address
    ldx #$ff
    ldy #$ff
    rts
.endp

.proc get_LOMEM
    ldx _MEMLO
    ldy _MEMLO+1
    rts
.endp

.proc get_HIMEM
    ldx _MEMTOP
    ldy _MEMTOP+1
    rts
.endp

.proc vdu_queue
    rts
.endp

.proc no_adval
    brk
    dta 0,'ADVAL not supported',0
.endp

.proc read_key_with_timeout
    stx ptr
    sty ptr+1

    mwa #0 ptr2

outer_loop:
    lda RTCLOK+2

inner_loop:
    cmp RTCLOK+2
    beq check_key_press

    adw ptr2 #2 ptr2        ; each 50Hz tick is two 100Hz ticks
    cpw ptr2 ptr
    bcc outer_loop
    bcs exit

check_key_press:
    ldx 764
    cpx #$ff
    bne key_pressed
    beq inner_loop

exit:
    ldy #$ff
    clc
    rts

key_pressed:
    jsr getkey
    tax
    ldy #0
    clc
    rts
.endp

.proc pos_vpos_notimpl
    brk
    dta 0,'POS/VPOS not supported',0
.endp

; ----------------------------------------------------------------------------
; OSCLI
;
.proc strcmp
    ldy #-1
compare:
    iny
    lda (ptr),y
    cmp (ptr2),y
    bne exit
    cmp #$0d
    beq exit
    bne compare
exit:
    rts
.endp

.proc OS_CLI
    stx ptr
    sty ptr+1

    mwa #stardos ptr2
    jsr strcmp
    beq do_stardos

    mwa #stardir ptr2
    jsr strcmp
    beq do_stardir

    brk
    dta 0,'Invalid OSCLI',0

stardos:
    dta '*DOS',$0d
stardir
    dta '*DIR',$0d

do_stardos:
    inc PORTB
    mwa reset_proc.INIDOS+1 DOSINI
    jmp (DOSVEC)

do_stardir:
    ldx #$70
    jsr close_iocb

    mwa #dirstardotstar IOCB7+ICBAL
    mva #6 IOCB7+ICAX1
    mva #0 IOCB7+ICAX2
    mva #COPEN IOCB7+ICCOM
    jsr call_ciov
    jmi cio_error

@:
    mva #CGBIN IOCB7+ICCOM
    mwa #1 IOCB7+ICBLL
    mwa #save_a IOCB7+ICBAL
    jsr call_ciov
    bmi done

    lda save_a
    jsr OSWRCH
    jmp @-

done:
    rts

dirstardotstar:
    dta 'D:*.*',$9b

.endp

; ----------------------------------------------------------------------------

default_report:
    dta 0, '(C)1983 Acorn', 13, 0

; ----------------------------------------------------------------------------
; ============================================================================
; ----------------------------------------------------------------------------

    org $6000

.proc under_rom_loader
    ldx KEYBDV+4                ; get address from keyboard vector table
    ldy KEYBDV+5
    inx                         ; add 1
    bne @+
    iny
@:
    stx getkey.vector           ; store
    sty getkey.vector+1

    mva #0 NMIEN                ; disable NMI
    sei                         ; disable IRQ
    mva #$fe PORTB              ; disable BASIC and OS ROM

    mwa BRKKY irq_break_key.old_vector
    mwa #irq_break_key BRKKY

    mwa #nmi_proc nmi_vector    ; setup hardware vectors
    mwa #irq_proc irq_vector

    mva #$40 NMIEN              ; enable NMI
    cli

    inc PORTB                   ; enable OS

    jsr load_blocks

    mwa DOSINI reset_proc.INIDOS+1  ; save old DOSINI
    mwa #reset_proc DOSINI          ; set new DOSINI

    mva #1 BASICF               ; set flags for warm start
    ora BOOT
    sta BOOT
    mva #0 COLDST
    sta CRSINH

    mva #>$c000 RAMTOP          ; set RAMTOP
    lsr
    sta APPMHI+1                ; and APPMHI

;    jsr open_editor

    dec PORTB

    mwa #default_report FAULT

    jsr close_all_handles       ; close #1 - #5

    jmp $c000                   ; jump to BBC BASIC
.endp

.proc open_editor
    lda EDITRV+1
    pha
    lda EDITRV
    pha
    rts
.endp

.proc load_blocks
    ldx #$10                ; IOCB #1

    ; load 4 bytes, start and end address

    mwa #start_addr IOCB1+ICBAL
    mwa #4 IOCB1+ICBLL
    mva #7 IOCB1+ICCOM
    jsr CIOV
    bmi load_end

    ; load data to buffer

    lda #<LOAD_BUFFER
    sta bufp
    sta IOCB1+ICBAL
    lda #>LOAD_BUFFER
    sta bufp+1
    sta IOCB1+ICBAH

    ; calculate length, end_addr - start_addr + 1

    sbw end_addr start_addr tmp1
    inw tmp1

    mwa tmp1 IOCB1+ICBLL
    jsr CIOV
    bmi load_error

    ; copy to RAM under ROM

    dec PORTB

    ldy #0
    ldx tmp1+1
    beq check_lsb

copy_loop:
    lda (bufp),y
    sta (start_addr),y
    iny
    bne copy_loop

    inc start_addr+1
    inc bufp+1
    dex
    bne copy_loop

check_lsb:
    ldx tmp1
    beq copy_done

copy_loop_last_page:
    lda (bufp),y
    sta (start_addr),y
    iny
    dex
    bne copy_loop_last_page

copy_done:
    inc PORTB
    jmp load_blocks

load_end:
    rts

load_error:
    jmp(DOSVEC)
.endp

 LOAD_BUFFER = *

; ----------------------------------------------------------------------------
; ============================================================================
; ----------------------------------------------------------------------------

    TARGET_ATARI=1
    NO_MOS_VECTORS=1

    icl 'basic/basic.s'

; vi:syntax=mads
