
; ----------------------------------------------------------------------------

VDSLST = $0200
VBREAK = $0206
VIMIRQ = $0216
VVBLKI = $0222

COLOR0 = $02c4
COLOR1 = $02c5
COLOR2 = $02c6
COLOR3 = $02c7
COLOR4 = $02c8

_MEMTOP = $02e5
_MEMLO  = $02e7

CHBAS  = $02f4

IOCB0  = $0340
IOCB1  = $0350
IOCB2  = $0360
IOCB3  = $0370
IOCB4  = $0380
IOCB5  = $0390
IOCB6  = $03a0
IOCB7  = $03b0

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

PORTB  = $d301

NMIRES = $d40f
NMIST  = $d40f

CIOV   = $e456

; ----------------------------------------------------------------------------

    org $2000

FONT:
    icl 'font.s'

; ----------------------------------------------------------------------------

    org $2400

.proc splash
    mva #>FONT CHBAS
    mva #15 COLOR1
    mvx #0 COLOR2       ; X=0, also IOCB number later

    mwa #message IOCB0+ICBAL
    mwa #(end_message-message) IOCB0+ICBLL
    mva #$0b IOCB0+ICCOM
    jsr CIOV
    rts
.endp

message:
    dta 'Loading BBC BASIC 3.10', 155
end_message:

; ----------------------------------------------------------------------------

    ini splash

; ----------------------------------------------------------------------------

    org $2400

.proc call_ciov
    inc PORTB
    jsr CIOV
    dec PORTB
    cpy #0
    rts
.endp

; ----------------------------------------------------------------------------

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

.proc irq_proc
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

INIDOS:
.proc reset_proc
    jsr $1234

    mva #$fe PORTB
    mwa #$3c00 _MEMLO

    jmp *
.endp

; ----------------------------------------------------------------------------

    org $6000

.proc under_rom_loader
    jmp *
.endp

; ----------------------------------------------------------------------------

    TARGET_ATARI=1

    icl 'basic/basic.s'

; vi:syntax=mads
