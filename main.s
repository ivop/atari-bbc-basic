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
KEYBDV = $d420

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
    mwa #$3c00 _MEMLO

    mwa #message IOCB0+ICBAL
    mwa #(end_message-message) IOCB0+ICBLL
    mva #$0b IOCB0+ICCOM
    ldx #0
    jsr CIOV
    rts
.endp

message:
    dta 125,'BBC BASIC 3.10',155
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

    jmp $c000
.endp

; ----------------------------------------------------------------------------

.proc getkey
    inc PORTB
jsr_getkey:
    jsr $1234
    dec PORTB
    rts
.endp

; ----------------------------------------------------------------------------
; MOS TRANSLATION LAYER
;

.proc OSFIND
    jmp *
.endp

; ----------------------------------------------------------------------------

.proc OSBPUT
    jmp *
.endp

; ----------------------------------------------------------------------------

.proc OSBGET
    jmp *
.endp

; ----------------------------------------------------------------------------

.proc OSARGS
    jmp *
.endp

; ----------------------------------------------------------------------------

.proc OSFILE
    jmp *
.endp

; ----------------------------------------------------------------------------

.proc OSRDCH
    jmp *
.endp

; ----------------------------------------------------------------------------

.proc OSASCI
    jmp *
.endp

; ----------------------------------------------------------------------------

.proc OSNEWL
    lda #$0d
.endp

    ; [[fallthrough]]

; ----------------------------------------------------------------------------

.proc OSWRCH
    sta save_a
    stx save_x
    sty save_y

    cmp #$0d
    bne @+
    lda #155
@:
    sta buf

    mva #11 IOCB0+ICCOM
    mwa #1 IOCB0+ICBLL
    mwa #buf IOCB0+ICBAL
    ldx #0
    jsr call_ciov

    ldy save_y
    ldx save_x
    lda save_a
    rts

buf:
    dta 0
.endp

; ----------------------------------------------------------------------------

.proc OSWORD
    cmp #$00
    beq read_line

    jmp *

read_line:
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
    mva #5 IOCB0+ICCOM
    ldx #0

    jsr call_ciov

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

; ----------------------------------------------------------------------------

.proc OSBYTE
    cmp #$83
    beq get_LOMEM
    cmp #$84
    beq get_HIMEM

    jmp *
    dta 'OSBYTE'

get_LOMEM:
    ldx _MEMLO
    ldy _MEMLO+1
    rts

get_HIMEM:
    ldx _MEMTOP
    ldy _MEMTOP+1
    rts

.endp

; ----------------------------------------------------------------------------

.proc OS_CLI
    jmp *
.endp

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
    stx getkey.jsr_getkey+1     ; store
    sty getkey.jsr_getkey+2

    mva #0 NMIEN                ; disable NMI
    sei                         ; disable IRQ
    mva #$fe PORTB              ; disable BASIC and OS ROM

    mwa #nmi_proc nmi_vector    ; setup hardware vectors
    mwa #irq_proc irq_vector

    mva #$40 NMIEN              ; enable NMI

    inc PORTB                   ; enable OS

    jsr load_blocks

    mwa DOSINI reset_proc.INIDOS+1  ; save old DOSINI
    mwa #reset_proc DOSINI          ; set new DOSINI

    mva #1 BASICF               ; set flags for warm start
    ora BOOT
    sta BOOT
    mva #0 COLDST

    mva #>$c000 RAMTOP          ; set RAMTOP
    lsr
    sta APPMHI+1                ; and APPMHI

;    jsr open_editor

    dec PORTB

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
; ============================================================================
; ----------------------------------------------------------------------------

    TARGET_ATARI=1
    NO_MOS_VECTORS=1

    icl 'basic/basic.s'

; vi:syntax=mads
