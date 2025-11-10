; Copy LINE to AELINE, then get handle
; ====================================
; Returns file handle in Y and A

AECHAN:
    lda zpCURSOR
    sta zpAECUR        ; copy cursor/offset
    lda zpLINE
    sta zpAELINE
    lda zpLINE+1
    sta zpAELINE+1

; Check for '#', evaluate channel
; ===============================
; Returns file handle in Y and A

CHANN:
    jsr AESPAC        ; Skip spaces, and get next character
    cmp #'#'          ; If not '#', jump to give error
    bne CHANNE

    jsr INTFAC        ; Evaluate as integer

    ldy zpIACC
    tya               ; Get low byte and return

NULLRET:
    rts

; ----------------------------------------------------------------------------

; Print inline text
; =================

VSTRNG:
    pla
    sta zpWORK
    pla
    sta zpWORK+1      ; Pop return address to WORK+0/1

    ldy #$00
    beq VSTRLP        ; Jump into loop

VSTRLM:
    jsr OSASCI        ; Print character

VSTRLP:
    jsr GETWK2        ; increment pointer and get next character
    bpl VSTRLM        ; loop until bit 7 is set

    jmp (zpWORK)      ; Jump back to program

; ----------------------------------------------------------------------------

; REPORT
; ======

REPORT:
    jsr DONE           ; check end of statement
    jsr NLINE          ; print newline, clear COUNT

    ldy #$01

REPLOP:
    lda (FAULT),Y     ; get byte from FAULT block
    beq REPORX        ; exit if $00 terminator

    jsr TOKOUT        ; print character or (expanded) token

    iny
    bne REPLOP        ; loop for next

REPORX:
    jmp NXT           ; Jump to main execution loop

CHANNE:
    jsr fake_brk
    dta $2D, 'Missing #', 0

; vi:syntax=mads
