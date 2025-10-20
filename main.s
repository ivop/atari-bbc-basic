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
RAMTOP = $6a

VDSLST = $0200
VBREAK = $0206
VIMIRQ = $0216
VVBLKI = $0222

COLDST = $0244

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

PORTB  = $d301

NMIEN  = $d40e
NMIRES = $d40f
NMIST  = $d40f

EDITRV = $e400
CIOV   = $e456

NMI_VECTOR = $fffa
IRQ_VECTOR = $fffe

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
    mva #15 COLOR1
    mvx #0 COLOR2       ; X=0, also IOCB number later

    mwa #message IOCB0+ICBAL
    mwa #(end_message-message) IOCB0+ICBLL
    mva #$0b IOCB0+ICCOM
    jsr CIOV
    rts
.endp

message:
    dta 125,'Loading BBC BASIC 3.10',155
end_message:

; ----------------------------------------------------------------------------

    ini splash

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
    ; skip jsr_getkey init

    mva #0 NMIEN                ; disable NMI
    sei                         ; disable IRQ
    mva #$fe PORTB              ; disable BASIC and OS ROM

    mwa #nmi_proc nmi_vector    ; setup hardware vectors
    mwa #irq_proc irq_vector

    mva #$40 NMIEN              ; enable NMI

    inc PORTB                   ; enable OS

    jsr load_blocks

    mwa DOSINI INIDOS           ; save old DOSINI
    mwa #reset_proc DOSINI      ; set new DOSINI

    mva #1 BASICF               ; set flags for warm start
    ora BOOT
    sta BOOT
    mva #0 COLDST

    mva #>$c000 RAMTOP          ; set RAMTOP
    lsr
    sta APPMHI+1                ; and APPMHI

    jsr open_editor

    dec PORTB

    jmp *                       ; jump to BBC BASIC
.endp

.proc open_editor
    lda EDITRV+1
    pha
    lda EDITRV
    pha
    rts
.endp

; Temporary ZP locations

start_addr = $e0
end_addr   = $e2
bufp       = $e4
tmp1       = $e6

.proc load_blocks
    ldx #$10                ; IOCB #1

    ; load 4 bytes, start and end address

    mwa #start_addr IOCB0+ICBAL,x
    mwa #4 IOCB0+ICBLL,x
    mwa #7 IOCB0+ICCOM,x
    jsr CIOV
    bmi load_end

    ; load data to buffer

    lda #<LOAD_BUFFER
    sta bufp
    sta IOCB0+ICBAL,x
    lda #>LOAD_BUFFER
    sta bufp+1
    sta IOCB0+ICBAH,x

    ; calculate length, end_addr - start_addr + 1

    sbw end_addr start_addr tmp1
    inw tmp1

    mwa tmp1 IOCB0+ICBLL,x
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

    TARGET_ATARI=1

    icl 'basic/basic.s'

; vi:syntax=mads
