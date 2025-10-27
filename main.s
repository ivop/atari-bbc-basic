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

    opt r+          ; optimize mva #0 dest

; ----------------------------------------------------------------------------

BOOT   = $09
DOSVEC = $0a
DOSINI = $0c
APPMHI = $0e
RTCLOK = $12
ROWCRS = $54
COLCRS = $55
RAMTOP = $6a

VDSLST = $0200
VBREAK = $0206
VIMIRQ = $0216
VVBLKI = $0222
BRKKY  = $0236

COLDST = $0244

PADDL0 = $0270
PADDL1 = $0271
PADDL2 = $0272
PADDL3 = $0273

STICK0 = $0278
STICK1 = $0279

PTRIG0 = $027c
PTRIG1 = $027d
PTRIG2 = $027e
PTRIG3 = $027f

STRIG0 = $0284
STRIG1 = $0285

COLOR0 = $02c4
COLOR1 = $02c5
COLOR2 = $02c6
COLOR3 = $02c7
COLOR4 = $02c8

_MEMTOP = $02e5
_MEMLO  = $02e7

CRSINH = $02f0
CHBAS  = $02f4
ATACHR = $02fb
CHCH   = $02fc

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
CDRAW = 17

AUDF1  = $d200
AUDC1  = $d201
AUDCTL = $d208
SKCTL  = $d20f

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

start_addr = $d0
end_addr   = $d2
bufp       = $d4
tmp1       = $d6

; ----------------------------------------------------------------------------

; MOS Translation Layer ZP locations

ptr    = $d0
ptr2   = $d2
save_a = $d4
save_x = $d5
save_y = $d6
irq_a  = $d7
color  = $d8

; ----------------------------------------------------------------------------

    org $2000

; BBC Micro font with Atari control characters

FONT:
    ins 'font.fnt'

; ----------------------------------------------------------------------------

; Splash screen
; Code will be overwritten

    org $2400

.proc splash
    mva #>FONT CHBAS                            ; set font
    sta CRSINH                                  ; disable cursor
    mwa #$3c00 _MEMLO                           ; set MEMLO

    ; print message via CIO

    mwa #message IOCB0+ICBAL
    mwa #(end_message-message) IOCB0+ICBLL
    mva #CPBIN IOCB0+ICCOM
    ldx #0
    jsr CIOV                                    ; the OS is still on

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
    inc PORTB           ; enable ROM
    jsr CIOV            ; call CIOV
    dec PORTB           ; disable ROM
    cpy #0              ; reset flags
    rts
.endp

; ----------------------------------------------------------------------------

; NMI/IRQ prologue, switches off ROM again

.proc nmi_end
    pla                 ; restore X
    tax
.endp

; [[fallthrough]]

.proc irq_end
    dec PORTB           ; disable ROM
    pla                 ; restore A
    rti
.endp

; ----------------------------------------------------------------------------

; NMI when ROM is off

.proc nmi_proc
    bit NMIST           ; check for DLIs
    bpl @+
    jmp (VDSLST)        ; jump through vector

@:
    pha                 ; save A
    txa
    pha                 ; save X

    lda #>nmi_end       ; return to nmi_end after rti
    pha
    lda #<nmi_end
    pha
    tsx
    lda $0105,x         ; get value of P
    pha                 ; and restack

    cld
    pha                 ; OS VVBLK routine expects A,X,Y to be saved
    txa
    pha
    tya
    pha

    inc PORTB           ; enable ROM
    sta NMIRES          ; ack VBI
    jmp (VVBLKI)
.endp

; ----------------------------------------------------------------------------

; IRQ when ROM is off

.proc irq_proc
    sta irq_a           ; save A here because we need to do some PLAs

    pla
    pha
    and #$10            ; check B bit
    beq no_BRK

    pla                 ; drop P
    pla                 ; get return address
    sec
    sbc #1              ; and subtract 1
    sta FAULT+0         ; set FAULT vector
    pla
    sbc #0
    sta FAULT+1
    jmp (BRKV)          ; jump to where BASIC has directed us

no_BRK:
    lda irq_a           ; restore A
    pha                 ; save on machine stack as the OS routine expects

    lda #>irq_end       ; return to irq_end by rti
    pha
    lda #<irq_end
    pha
    php                 ; save P for rti

    inc PORTB           ; enable ROM

    jmp (VIMIRQ)
.endp

; ----------------------------------------------------------------------------

.proc reset_proc
    mva #>FONT CHBAS            ; reset CHBAS to out BBC font

INIDOS:
    jsr $1234                   ; set by loader, reset D: device driver

    mva #$fe PORTB              ; disable ROM
    mwa #$3c00 _MEMLO           ; reset MEMLO
    mwa #irq_break_key BRKKY    ; our BREAK key routine for ESCFLG
    mva #1 plot_needed          ; reset to 1 if no plot or drawto has occurred
    mva #0 ESCFLG               ; clear ESCFLG
    sta AUDCTL
    mva #3 SKCTL+$10

    jmp BASIC_ENTRY
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
    mva #$ff ESCFLG             ; set ESCFLAG
old_vector = * + 1
    jmp $1234                   ; old vector set by loader
.endp

; ----------------------------------------------------------------------------

.proc save_axy
    sta save_a
.endp

    ; [[fallthrough]]

.proc save_xy
    stx save_x
    sty save_y
    rts
.endp

; ----------------------------------------------------------------------------

.proc restore_axy
    lda save_a
.endp

    ; [[fallthrough]]

.proc restore_xy
    ldx save_x
    ldy save_y
    rts
.endp

; ----------------------------------------------------------------------------

; Convert CR ($0D) to Atari EOL ($9B)
; On entry, ptr2 points to the string to be converted

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
; A=$00 close handle Y, close all if Y=0, on exit, A,X,Y are preserved
; A=$40 OPENIN, YX points to filename, on exit, X,Y are preserved, A=handle
; A=$80 OPENOUT, YX points to filename, on exit, X,Y are preserved, A=handle
; A=$C0 OPENUP, YX points to filename, not supported
;
; if A is supposed to be a handle on exit, A=0 on error

.proc handle_out_of_range
    brk
    dta 0,'Handle out of range',0
.endp

.proc osfind_openup_unsupported
    brk
    dta 0,'OPENUP unsupported',0
.endp

.proc __OSFIND
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
    bcs handle_out_of_range         ; >= 6 is out of range

    lda #0
    sta channels_inuse-1,y
    sta channels_ungetc_flags-1,y

    tya                             ; convert to CIO $x0 channel number in X
    asl
    asl
    asl
    asl
    tax

    jsr close_iocb
    jmp restore_axy
.endp

.proc close_all_handles
    ldx #$50                        ; loop from $50 to $10 and close all
close_all:
    jsr close_iocb
    txa
    sec
    sbc #$10
    tax
    bne close_all

    ldy #4                          ; loop from 4-0
    txa
set_free:
    sta channels_inuse,y            ; clear inuse flags
    sta channels_ungetc_flags,y     ; clear ungetc flags
    dey
    bpl set_free

    jmp restore_axy
.endp

.proc osfind_openin
    lda #4                          ; reading
    bne osfind_open_common
.endp

.proc osfind_openout
    lda #8                          ; writing
.endp

    ; [[fallthrough]]

; enter with A=4 for reading, and A=8 for writing

.proc osfind_open_common
    sta save_a
    jsr save_xy

    stx ptr2
    sty ptr2+1

    jsr eol_to_atari_ptr2

    ldx #0                          ; find free IOCB channel
@:
    lda channels_inuse,x
    beq channel_found
    inx
    cpx #5
    beq error
    bne @-

channel_found:
    stx ptr                         ; index into channels table is 0-4

    inx                             ; now it's 1-5
    txa                             ; convert to CIO number $x0
    asl
    asl
    asl
    asl
    tax

    mwa ptr2 IOCB0+ICBAL,x          ; filename
    mva save_a IOCB0+ICAX1,x        ; 4 (reading) or 8 (writing)
    mva #0 IOCB0+ICAX2,x
    mva #COPEN IOCB0+ICCOM,x
    jsr call_ciov
    bmi error

    ldx ptr                         ; restore index into channels tables
    lda #1
    sta channels_inuse,x            ; mark in-use
    inx
    txa                             ; return handle 1-5 in A

    jmp restore_xy

error:
    lda #0                          ; return 0 on error
    jmp restore_xy
.endp

; ----------------------------------------------------------------------------
; OSBPUT
;
; On entry, Y=handle, A=byte to put
;
.proc __OSBPUT
    jsr save_axy
    cpy #7              ; we allow BPUT #0 and BPUT #6
    bcs too_high

    lda #CPBIN
    jsr bput_bget_common

too_low:                    ; docs say nothing about errors returned
too_high:
    jmp restore_axy
.endp

; ----------------------------------------------------------------------------

.proc bput_bget_common
    pha

    tya                                 ; convert handle to CIO index in X
    asl
    asl
    asl
    asl
    tax

    pla
    sta IOCB0+ICCOM,x
    mwa #1 IOCB0+ICBLL,x                ; get 1 byte
    mwa #save_a IOCB0+ICBAL,x           ; into save_a
    jsr call_ciov
    rts
.endp

; ----------------------------------------------------------------------------
; OSBGET
;
; On entry, Y=handle
; On exit, X and Y are preserved, A=byte read, C=0 on success, C=1 on failure
;
.proc __OSBGET
    jsr save_xy

    cpy #1                              ; check handle is in [1...5]
    bcc too_low
    cpy #6
    bcs too_high

    lda channels_ungetc_flags-1,y       ; check if we have an ungetc'd byte
    beq get_byte_from_media

    ; we have an 'ungetc'd byte stored, return it

    lda #0
    sta channels_ungetc_flags-1,y       ; clear flag
    lda channels_ungetc_data-1,y        ; get byte to return
    clc
    jmp restore_xy

get_byte_from_media:
    lda #CGBIN
    jsr bput_bget_common

    bmi eof

    lda save_a                          ; return our byte read

    clc                                 ; C=0 on success
    jmp restore_xy

eof:
too_low:
too_high:
    sec                                 ; C=1 on failure
    jmp restore_xy
.endp

; ----------------------------------------------------------------------------
; OSARGS
;
.proc __OSARGS
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
; On entry, pointer in YX to information block
; A=0x00    SAVE
; A=0x01    LOAD
;
.proc __OSFILE
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
    mva (ptr),y IOCB7+ICBAL         ; save address
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
    sta save_a                      ; save open mode

    ldx #$70
    jsr close_iocb

    ldy #0                          ; get pointer to filename
    mva (ptr),y ptr2                ; into ptr2
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
.proc __OSRDCH
    jmp getkey
.endp

; ----------------------------------------------------------------------------
; OSWRCH
;
.proc print_esc
    pha
    lda #27
    jsr putchar
    pla
    rts
.endp

.proc __OSWRCH
    jsr save_axy

    cmp #125
    bcs do_esc

    cmp #27
    bcc noesc
    cmp #32
    bcs noesc

do_esc:
    jsr print_esc

noesc:
    cmp #$0d
    bne noeol

    lda #155

noeol:
    jsr putchar
    jmp restore_axy
.endp

.proc putchar
    sta buf

    mva #CPBIN IOCB0+ICCOM
    mwa #1 IOCB0+ICBLL
    mwa #buf IOCB0+ICBAL
    ldx #0
    jmp call_ciov

buf:
    dta 0
.endp

.proc cls_intercept
    lda #125
    jmp putchar
.endp

.proc clg_intercept
    rts
.endp

; ----------------------------------------------------------------------------
; OSWORD
;
.proc osword_error
    brk
    dta 0,'Unsupported OSWORD call', 0
.endp

.proc locate_pixel
    stx ptr
    sty ptr+1
    ldy #0
    mva (ptr),y COLCRS
    iny
    mva (ptr),y COLCRS+1
    iny
    mva (ptr),y ROWCRS
    iny
    iny
    tya
    pha

    ldx #$60
    mva #CGBIN IOCB6+ICCOM
    mwa #1 IOCB6+ICBLL
    mwa #save_a IOCB6+ICBAL
    jsr call_ciov

    pla
    tay
    lda save_a
    sta (ptr),y
    rts
.endp

.proc __OSWORD
    cmp #$00
    beq read_line
    cmp #$01
    beq get_clock_in_cs
    cmp #$02
    beq set_clock
    cmp #$09
    beq locate_pixel
    bne osword_error
.endp

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
    mva #0 NMIEN            ; disable VBI during RTCLOK operations
    stx ptr
    sty ptr+1
    ldy #0

    lda RTCLOK+2            ; multiply RTCLOK by 2 (50Hz to 100Hz ticks)
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

    mva #$40 NMIEN          ; re-enable VBI
    rts
.endp

.proc set_clock
    mva #0 NMIEN            ; disable VBI during RTCLOK operations
    stx ptr
    sty ptr+1
    ldy #2

    lda (ptr),y             ; divide by 2 (100Hz ticks to 50Hz ticks)
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

    mva #$40 NMIEN          ; re-enable VBI
    rts
.endp

.proc break_key
    mva #$ff ESCFLG         ; BREAK on empty line
    rts
.endp

; ----------------------------------------------------------------------------
; OSBYTE
;

; Table with MEMTOP values for each graphics mode

    .macro memtops
        dta :1$bc1f, :1$bd5d, :1$be57, :1$be4d      ;  0-3
        dta :1$bd49, :1$bb69, :1$b781, :1$afa1      ;  4-7
        dta :1$a04f, :1$a035, :1$a035, :1$a035      ;  8-11
        dta :1$bb7d, :1$bd67, :1$af51, :1$a04f      ; 12-15
        dta :1$bc1f, :1$bd5f, :1$be5b, :1$be4f      ;  0-3  (+16)
        dta :1$bd47, :1$bb67, :1$b777, :1$af97      ;  4-7  (+16)
        dta :1$a035, :1$a035, :1$a035, :1$a035      ;  8-11 (+16)
        dta :1$bb7f, :1$bd6b, :1$af37, :1$a035      ; 12-15 (+16)
    .endm

memtopsL:
    memtops <
memtopsH:
    memtops >

.proc bottom_of_screen_mode_X
    pha
    txa
    and #$1f                    ; modes 0-31
    tax
    lda memtopsL,x
    ldy memtopsH,x              ; return MSB in Y
    tax                         ; return LSB in X
    pla
    rts
.endp

; Check EOF by trying to read a byte. On success, put it in the ungetc
; buffer, flag it as such, and return false.
; On failure, return true. We reached EOF.

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

.proc unsupported_osbyte
    brk
    dta 0,'Unsupported OSBYTE call',0
.endp

.proc __OSBYTE
    cmp #$7e
    beq set_escflg
    cmp #$7f
    beq check_eof_on_handle
    cmp #$80
    beq do_adval
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
    beq pos_vpos
    cmp #$da
    beq vdu_queue
    bne unsupported_osbyte
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

.proc do_adval
    cpx #$ff
    beq keyboard
    bne retzero

keyboard:
    cpx CHCH                ; if CH is equal to $ff, there's no key pending
    beq retzero

    ldx #1                  ; there's one key pending
    bne rety

retzero:
    ldx #0
rety:
    ldy #0
    rts
.endp

.proc read_key_with_timeout
    stx ptr
    sty ptr+1

    mwa #0 ptr2

outer_loop:
    lda RTCLOK+2            ; we count changes of the LSB of RTCLOK

inner_loop:
    cmp RTCLOK+2
    beq check_key_press

    adw ptr2 #2 ptr2        ; each 50Hz tick is two 100Hz ticks
    cpw ptr2 ptr
    bcc outer_loop
    bcs exit

check_key_press:
    ldx CHCH
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

.proc pos_vpos
    ldx COLCRS
    ldy ROWCRS
    rts
.endp

; ----------------------------------------------------------------------------
; OSCLI
;
; Maybe add *LOAD and *SAVE for binary files later
;
; Very simple strcmp to match *DIR and *DOS
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

.proc __OSCLI
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
.endp

.proc do_stardos
    inc PORTB
    mwa reset_proc.INIDOS+1 DOSINI
    jmp (DOSVEC)
.endp

.proc do_stardir
    ldx #$70
    jsr close_iocb

    mwa #dirstardotstar IOCB7+ICBAL
    mva #6 IOCB7+ICAX1                  ; open mode 6, directory listing
    mva #0 IOCB7+ICAX2
    mva #COPEN IOCB7+ICCOM
    jsr call_ciov
    jmi cio_error

    ; print all bytes we can retrieve from channel 7

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
    ; no close, each time #7 is used, it is closed before usage
    rts

dirstardotstar:
    dta 'D:*.*',$9b
.endp

; ----------------------------------------------------------------------------

; A=7 BEEP, A=8 ENVELOPE

.proc BEEP_ENVELOPE
    cmp #7
    beq beep
    ; ignore ENVELOPE
    rts

beep:
    lda zpWORK
    and #%0001011           ; allow +8 for stereo pokey
    asl
    tay

    lda zpWORK+4            ; get distortion
    asl                     ; shift left 4 times
    asl
    asl
    asl
    sta zpWORK+4            ; store because we need A
    lda zpWORK+6            ; get volume
    and #$0f                ; mask bottom 4 bits
    ora zpWORK+4            ; OR in the distortion bits
    sta AUDC1,y             ; store in POKEY register

    lda zpWORK+2            ; get pitch
    sta AUDF1,y             ; and store in POKEY register

    rts
.endp

; ----------------------------------------------------------------------------

; On entry:
;
; A=$16 MODE        IACC=number
; A=$12 GCOL        IACC=2nd number    IACC+1=1st number
; A=$11 COLOUR      IACC=number

.proc sendtwo_intercept
    cmp #$16
    beq mode
    cmp #$11
    beq colour
    bne setcolor

mode:
    ldx #$60
    jsr close_iocb

    ; Open S: on channel #6

    mwa #sdevice IOCB6+ICBAL
    lda zpIACC                      ; get mode number
    tay
    and #$f0                        ; top nibble
    eor #$1c                        ; invert bit4, set bit 2,3 (read/write)
    sta IOCB6+ICAX1
    tya
    and #$0f                        ; bottom nibble of mode number
    sta IOCB6+ICAX2
    mva #COPEN IOCB6+ICCOM
    jsr call_ciov

    mva #>FONT CHBAS                ; restore font after "graphics" call
    mva #1 plot_needed              ; reset flag
    rts

colour:
    mva zpIACC COLOR
    rts

; GCOL acts like SETCOLOR. 1st argument is 0-4, 2nd argument is value &00-&ff

setcolor:
    lda zpIACC
    cmp #5
    bcs ret                         ; jump if >= 5

    tax
    lda zpIACC
    sta COLOR0,x                    ; set shadow register

ret:
    rts
.endp

sdevice:
    dta 'S:',$9b

; ----------------------------------------------------------------------------

; A = PLOT action, zpWORK+0/1 first coordinate, zpIACC+0/1 second coordinate
;
;      PLOT action, xcoor, ycoor
; A=4  MOVE         xcoor, ycoor
; A=5  DRAW         xcoor, ycoor
; A=69 PLOT         xcoor, ycoor

.proc plot_intercept
    cmp #4
    beq position
    cmp #5
    beq drawto
    cmp #69
    beq plot_point

    brk
    dta 0,'PLOT action unsupported',0
.endp

.proc position
    mwa zpWORK COLCRS               ; 16-bit value
    mva zpIACC ROWCRS               ; 8-bit value
    mva #1 plot_needed              ; need plot if we do drawto after position
    rts
.endp

.proc plot_point
    jsr position

skip_position:
    ldx #$60
    mva #CPBIN IOCB6+ICCOM
    mwa #0 IOCB6+ICBLL
    mva #0 plot_needed
    lda COLOR
    jsr call_ciov
    rts
.endp

.proc drawto
    lda plot_needed
    beq continue_drawto

    jsr plot_point.skip_position

continue_drawto:
    jsr position
    ldx #$60
    mva #CDRAW IOCB6+ICCOM
    mwa #12 IOCB6+ICAX1
    jsr call_ciov
    rts
.endp

plot_needed:
    dta 1

; ----------------------------------------------------------------------------

; MOS Vectors at page $2f. LSB is equal to vectors on the BBC

    org $2fb9

OSDRM:      rts:nop:nop
VDUCHR:     rts:nop:nop
OSEVEN:     rts:nop:nop
GSINIT:     rts:nop:nop
GSREAD:     rts:nop:nop
NVRDCH:     rts:nop:nop
NVWRCH:     rts:nop:nop
OSFIND:     jmp __OSFIND
OSGBPB:     rts:nop:nop
OSBPUT:     jmp __OSBPUT
OSBGET:     jmp __OSBGET
OSARGS:     jmp __OSARGS
OSFILE:     jmp __OSFILE
OSRDCH:     jmp __OSRDCH
OSASCI:     jmp __OSWRCH
            nop
OSNEWL:     lda #$0d
            nop:nop:nop:nop:nop         ; [[fallthrough]]
OSWRCH:     jmp __OSWRCH
OSWORD:     jmp __OSWORD
OSBYTE:     jmp __OSBYTE
OS_CLI:     jmp __OSCLI

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
    sta AUDCTL
    sta CRSINH
    mva #3 SKCTL+$10

    mva #>$c000 RAMTOP          ; set RAMTOP
    lsr
    sta APPMHI+1                ; and APPMHI

;    jsr open_editor

    dec PORTB

    mwa #default_report FAULT

    jsr close_all_handles       ; close #1 - #5

    jmp BASIC_ENTRY             ; jump to BBC BASIC
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
