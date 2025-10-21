
; Evaluate integer expression

ASEXPR:
    jsr AEEXPR       ; evaluate expression
    jsr INTEGB       ; ensure it is integer

ASCUR:
    ldy zpAECUR
    sty zpCURSOR     ; move cursor offset
    rts

; ----------------------------------------------------------------------------

; Add constants to zpOPCODE

PLUS10:             ; + $10 (+16)
    jsr PLUS8
PLUS8:
    jsr PLUS4
PLUS4:
    lda zpOPCODE
    clc
    adc #$04
    sta zpOPCODE
    rts

; ----------------------------------------------------------------------------

; Note: copying LINE to AELINE is replicated several times, and could
;       be made a subroutine

; Check for '=', evaluate Arithmetic Expression, check for end of statement

AEEQEX:
    lda zpLINE      ; copy LINE pointer to AELINE pointer
    sta zpAELINE
    lda zpLINE+1
    sta zpAELINE+1
    lda zpCURSOR    ; and its offset
    sta zpAECUR

EQEXPR:
    ldy zpAECUR
    inc zpAECUR
    lda (zpAELINE),Y
    cmp #' '
    beq EQEXPR      ; loop to skip spaces

    cmp #'='
    beq EXPRDN      ; jump to evaluate expression, else fallthrough to error

EQERRO:
    brk
    dta 4, 'Mistake'

STDED:
    brk                       ; also end of Mistake
    dta 16, 'Syntax error'    ; Terminated by following BRK

; Escape error
; ------------
DOBRK:
    brk               ; doubles as end of Syntax error on TARGET_BBC
    dta 17, 'Escape', 0

EQEAT:
    jsr AESPAC      ; skip spaces and get next character
    cmp #'='
    bne EQERRO      ; error if not '='
    rts

EXPRDN:
    jsr EXPR        ; evaluate the expression

FDONE:
    txa
    ldy zpAECUR
    jmp DONET       ; check for end of statement, tail call

AEDONE:
    ldy zpAECUR
    jmp DONE_WITH_Y

; ----------------------------------------------------------------------------

; Check for end of statement, check for Escape
; ============================================
DONE:
    ldy zpCURSOR       ; Get program pointer offset

DONE_WITH_Y:
    dey                ; Step back to previous character

BLINK:
    iny
    lda (zpLINE),Y     ; Get next character
    cmp #' '
    beq BLINK          ; Skip spaces, and get next character

DONET:
    cmp #':'
    beq CLYADP         ; Colon, jump to update program pointer

    cmp #$0D
    beq CLYADP         ; <cr>, jump to update program pointer

    cmp #tknELSE
    bne STDED          ; Not 'ELSE', jump to 'Syntax error'

; Update program pointer

CLYADP:
    clc
    tya
    adc zpLINE
    sta zpLINE         ; Update program pointer in zpLINE
    bcc SECUR

    inc zpLINE+1

SECUR:
    ldy #$01
    sty zpCURSOR

; Check background Escape state

TSTBRK:

; BBC - check background Escape state
; -----------------------------------
    .ifdef MOS_BBC
        bit ESCFLG
        bmi DOBRK     ; If Escape set, jump to give error
    .endif

SECEND:
    rts

; ----------------------------------------------------------------------------

; Move to the next statement
;
; This routine advances zpLINE to point to the start of the next statement,
; moving to the next line if necessary.

FORR:
    jsr DONE        ; check for end of statement
    dey
    lda (zpLINE),Y  ; get character that caused end of statement
    cmp #':'
    beq SECEND      ; exit if it was a colon

    lda zpLINE+1
    cmp #>BUFFER
    beq LEAVER      ; leave if statement came from BUFFER (immediate mode)

LINO:
    iny
    lda (zpLINE),Y
    bmi LEAVER      ; leave if end of program is reached

    lda zpTRFLAG
    beq NOTR        ; jump if TRACE is turned off

    tya             ; save current offset on the stack
    pha

    iny
    lda (zpLINE),Y  ; get LSB of line number and save on stack
    pha

    dey
    lda (zpLINE),Y  ; get MSB of line number
    tay             ; into Y

    pla             ; retrieve LSB in A again

    jsr AYACC       ; put YA in IACC
    jsr TRJOBA      ; print TRACE info if required

    pla             ; restore offset from the stack
    tay

NOTR:
    iny
    sec             ; C=1, add one more
    tya
    adc zpLINE
    sta zpLINE      ; save addjusted LINE
    bcc LINOIN

    inc zpLINE+1

LINOIN:
    ldy #$01        ; set offset to 1
    sty zpCURSOR

NOTRDE:
    rts

LEAVER:
    jmp CLRSTK      ; jump to immediate mode

; ----------------------------------------------------------------------------

; IF numeric
; ==========
;
; First evaluate expression. If the result is zero, the remainder of the line
; is scanned for ELSE. If it is found, the statements following are executed.
; If noy, control passes to the next line.
; If the expression is non-zero, the statements after the word THEN are
; executed.
; The complicating factors are the possible ommission of the word THEN and the
; possible presence of a line number after either THEN or ELSE, as in:
;   IF A=2 THEN 320

IFE:
    jmp LETM        ; 'Type mismatch' error

IF:
    jsr AEEXPR      ; evaluate the expression
    beq IFE         ; Type mismatch if expression is a string
    bpl IFX         ; skip conversion to int if it's already an int

    jsr IFIX        ; convert FACC to IACC

IFX:
    ldy zpAECUR
    sty zpCURSOR    ; update cursor past Arithmetic Expression

    lda zpIACC      ; check if IACC is zero
    ora zpIACC+1
    ora zpIACC+2
    ora zpIACC+3
    beq ELSE        ; if so, jump to scan for ELSE

    cpx #tknTHEN
    beq THEN        ; handle THEN token

THENST:
    jmp STMT        ; start executing statement(s)

THEN:
    inc zpCURSOR    ; increment past THEN token

THENLN:
    jsr SPTSTN      ; check for line number token
    bcc THENST      ; jump to start executing statements if not a line number

    jsr GOTGO       ; check that line number exists
    jsr SECUR       ; make zpLINE point directly after the line number
    jmp GODONE      ; join GOTO code

ELSE:
    ldy zpCURSOR    ; try to find else clause

ELSELP:
    lda (zpLINE),Y
    cmp #$0D
    beq ENDED       ; exit if end of line

    iny             ; increment to next character
    cmp #tknELSE
    bne ELSELP      ; loop until ELSE or EOL is found

    sty zpCURSOR    ; save cursor position
    beq THENLN      ; branch always (Z by cmp #tknELSE), join THEN code

ENDED:
    jmp ENDEDL      ; jump to skip everything after ELSE

; TRACE output if required

TRJOBA:
    lda zpIACC
    cmp zpTRNUM
    lda zpIACC+1
    sbc zpTRNUM+1
    bcs NOTRDE      ; return if current line number is greater than limit

    lda #'['
    jsr CHOUT
    jsr POSITE      ; print the line number
    lda #']'
    jsr CHOUT
    jmp LISTPT

; ----------------------------------------------------------------------------

; Print IACC as a 16-bit decimal number
; =====================================

POSITE:
    lda #$00          ; No padding
    beq NPRN+2        ; skip lda #5

NPRN:
    lda #$05          ; Pad to five characters
    sta zpPRINTS
    ldx #$04

NUMLOP:
    lda #$00
    sta zpWORK+8,X   ; zero current digit
    sec

NUMLP:
    lda zpIACC
    sbc VALL,X       ; Subtract 10s low byte
    tay
    lda zpIACC+1
    sbc VALM,X       ; Subtract 10s high byte
    bcc OUTNUM       ; Result<0, no more for this digit

    sta zpIACC+1
    sty zpIACC       ; Update number
    inc zpWORK+8,X
    bne NUMLP        ; branch always

OUTNUM:
    dex
    bpl NUMLOP        ; loop until all digits are done

    ldx #$05

LZB:
    dex
    beq LASTZ         ; reached end of number

    lda zpWORK+8,X    ; get current digit
    beq LZB           ; continue if it's zero

LASTZ:
    stx zpWORK      ; index of first non-zero digit, or last digit if IACC=0

    lda zpPRINTS
    beq PLUME       ; skip leading spaces if field width is 0

    sbc zpWORK      ; carry clear
    beq PLUME

    ; print required number of spaces

    tax
    jsr LISTPL
    ldx zpWORK

    ; print digits

PLUME:
    lda zpWORK+8,X
    ora #'0'        ; add ASCII offset
    jsr CHOUT
    dex
    bpl PLUME       ; loop until all digits are printed

    rts

; ----------------------------------------------------------------------------

; Low bytes of powers of ten
VALL:
    dta 1, 10, 100, <1000, <10000

; ----------------------------------------------------------------------------

; Line Search, find line number in IACC
; On exit, C=1 means line does not exist, C=0 if it does, and zpWORK+6/7
; points to one less than the address of the text of the line

FNDLNO:
    ldy #$00            ; LSB always zero
    sty zpWORK+6
    lda zpTXTP
    sta zpWORK+7        ; set WORK+6/7 to PAGE

SIGHT:
    ldy #$01
    lda (zpWORK+6),Y    ; get MSB of line number
    cmp zpIACC+1        ; compare against MSB being sought
    bcs LOOK            ; jump of >=

LOOKR:
    ldy #$03
    lda (zpWORK+6),Y    ; get length of current line
    adc zpWORK+6        ; add to pointer
    sta zpWORK+6
    bcc SIGHT           ; and continue search

    inc zpWORK+7        ; adjust MSB of pointer
    bcs SIGHT           ; and continue search

LOOK:
    bne PAST            ; not equal, exit with C=1

    ldy #$02
    lda (zpWORK+6),Y    ; get LSB of line number
    cmp zpIACC          ; compare against what's being sought
    bcc LOOKR           ; continue search if it being too small
    bne PAST            ; not equal, exit with C=1

    tya                 ; Y=A=2
    adc zpWORK+6        ; add 3 because C is always set here
    sta zpWORK+6        ; store
    bcc PAST

    inc zpWORK+7        ; possibly increment MSB of pointer
    clc                 ; indicate line number exists

PAST:
    ldy #$02            ; return with Y=2
    rts

; ----------------------------------------------------------------------------

ZDIVOR:
    brk
    dta $12, 'Division by zero'
    ; ending zero overlaps with VALM

; ----------------------------------------------------------------------------

; High byte of powers of ten
VALM:
    dta 0, 0, 0, >1000, >10000

; ----------------------------------------------------------------------------

; Divide top of stack by IACC
;
; This routine does integer division. It's used by both MOD and DIV.

DIVOP:              ; divide with remainder
    tay
    jsr INTEGB      ; ensure dividend is an integer

    lda zpIACC+3
    pha             ; save byte with sign on stack

    jsr ABSCOM      ; take absolute value of IACC
    jsr PHPOW       ; push dividend and get another operand

    stx zpTYPE
    tay
    jsr INTEGB      ; ensure divisor is an integer

    pla             ; get sign byte back
    sta zpWORK+1

    eor zpIACC+3    ; eor with sign of divisor
    sta zpWORK      ; and store

    jsr ABSCOM      ; take the absolute value of the divisor

    ldx #zpWORK+2
    jsr POPX        ; pop from stack into zpWORK+2 ... zpWORK+5

    sty zpWORK+6    ; clear next dword in zpWORK space
    sty zpWORK+7
    sty zpWORK+8
    sty zpWORK+9

    lda zpIACC+3    ; check divisor
    ora zpIACC
    ora zpIACC+1
    ora zpIACC+2
    beq ZDIVOR      ; Divide by 0 error

    ldy #32         ; number of iterations

DIVJUS:
    dey
    beq DIVRET      ; exit if enough iterations have taken place

    asl zpWORK+2    ; shift the dividend left
    rol zpWORK+3
    rol zpWORK+4
    rol zpWORK+5
    bpl DIVJUS      ; repeat until most significant bit is 1

DIVER:
    rol zpWORK+2    ; shift dividend left...
    rol zpWORK+3
    rol zpWORK+4
    rol zpWORK+5
    rol zpWORK+6    ; and shift bit into the accumulator
    rol zpWORK+7
    rol zpWORK+8
    rol zpWORK+9

    sec             ; subtract the divisor from IACC and stack result (LSB)
    lda zpWORK+6
    sbc zpIACC
    pha

    lda zpWORK+7    ; same for the next byte
    sbc zpIACC+1
    pha

    lda zpWORK+8    ; same for the third byte, but keep in X
    sbc zpIACC+2
    tax

    lda zpWORK+9    ; and finally the MSB
    sbc zpIACC+3
    bcc NOSUB       ; if the subtraction did not 'go', discard the result

    sta zpWORK+9    ; store it in out work Accu
    stx zpWORK+8
    pla             ; pull saved bytes from stack
    sta zpWORK+7
    pla
    sta zpWORK+6

    bcs NOSUB+2     ; skip pla, pla

NOSUB:
    pla             ; discard our two bytes saved
    pla

    dey
    bne DIVER       ; continue the loop

; Later BASICs have this check, disabled for now because it fails for
; Atom and System targets...
;    .if .hi(DIVER) != .hi(*)
;        .error "ASSERT: page crossing in DIVOP loop"
;    .endif

DIVRET:
    rts

; ----------------------------------------------------------------------------

; FCOMPS is called when a comparison is attempted where the first operand
; is an integer and the second is a floating point. On entry, the integer
; is on the stack and the floating point value is in FACC.

FCOMPS:
    stx zpTYPE

    jsr POPACC      ; pop integer from stack into IACC
    jsr PHFACC      ; push FACC

    jsr IFLT        ; convert integer to float
    jsr FTOW        ; copy to FWRK
    jsr POPSET      ; discard FP on stack, but have zpARGP point to it
    jsr FLDA        ; then unpack from (zpARGP) to FACC
    jmp FCMPA       ; jump to main floating point comparison routine

; Floating point comparison

FCOMPR:
    jsr PHFACC      ; save first operand on stack
    jsr ADDER       ; get second operand via 'level 4' parser
    stx zpTYPE
    tay
    jsr FLOATI      ; ensure it's a float
    jsr POPSET      ; discard FP on stack, but have zpARGP point to it

FCMP:
    jsr FLDW        ; load to FWRK via ARGP

; Compare FACC with FWRK

FCMPA:
    ldx zpTYPE
    ldy #$00

    lda zpFWRKS     ; isolate sign of FWRK
    and #$80
    sta zpFWRKS

    lda zpFACCS     ; isolate sign of FACC
    and #$80
    cmp zpFWRKS     ; compare signs
    bne FCMPZ       ; not equal, exit

    lda zpFWRKX     ; compare exponents
    cmp zpFACCX
    bne FCMPZZ      ; not equal, exit with proper flags

    lda zpFWRKMA    ; compare first mantissa
    cmp zpFACCMA
    bne FCMPZZ      ; not equal, exit with proper flags

    lda zpFWRKMB    ; etc...
    cmp zpFACCMB
    bne FCMPZZ

    lda zpFWRKMC
    cmp zpFACCMC
    bne FCMPZZ

    lda zpFWRKMD
    cmp zpFACCMD
    bne FCMPZZ

FCMPZ:
    rts

FCMPZZ:
    ror             ; clear top bit of A
    eor zpFWRKS     ; eor with sign
    rol             ; shift sign bit to C
    lda #$01        ; make suer Z=0
    rts

COMPRE:
    jmp LETM         ; Jump to 'Type mismatch' error

; Evaluate next expression and compare with previous
; --------------------------------------------------
; On exit:
;   A=B     Z=1
;   A<>B    Z=0
;   A>B     C=1 and Z=0
;   A<B     C=0

COMPR:
    txa

COMPRP1:
    beq STNCMP        ; Jump if current is string
    bmi FCOMPR        ; Jump if current is float

; Integer comparison

    jsr PHACC         ; Stack integer
    jsr ADDER         ; evaluate second operand expression
    tay               ; examine type
    beq COMPRE        ; Error if string
    bmi FCOMPS        ; Float, jump to compare int to float

; Compare IACC with top of stack

    lda zpIACC+3      ; flip sign bit of IACC ; this is to avoid the problem
    eor #$80          ; where a negative number will be interpreted as being
    sta zpIACC+3      ; bigger than any positive number by SBC and CMP below

    sec               ; prepare for subtraction

    ldy #$00          ; subtract byte for byte with top of AE stack
    lda (zpAESTKP),Y
    sbc zpIACC
    sta zpIACC

    iny
    lda (zpAESTKP),Y
    sbc zpIACC+1
    sta zpIACC+1

    iny
    lda (zpAESTKP),Y
    sbc zpIACC+2
    sta zpIACC+2

    iny
    lda (zpAESTKP),Y
    ldy #$00
    eor #$80          ; flip sign of top of stack int, too
    sbc zpIACC+3
    ora zpIACC        ; check rest of result for zero
    ora zpIACC+1
    ora zpIACC+2

    php                   ; save flags
    clc
    lda #$04
    adc zpAESTKP          ; Drop integer from stack
    sta zpAESTKP
    bcc COMPRX

    inc zpAESTKP+1

COMPRX:
    plp                   ; restore flags
    rts

; Compare string with next expression
; -----------------------------------

STNCMP:
    jsr PHSTR       ; push first string to the stack
    jsr ADDER       ; evaluate next expression

    tay             ; set flags on A
    bne COMPRE      ; 'Type mismatch' if not a string

                    ; Y=A=0

    stx zpWORK      ; save the next character

    ldx zpCLEN

                        ; Y=0

    lda (zpAESTKP),Y    ; get length of first string from stack
    sta zpWORK+2        ; save in zpWORK+2
    cmp zpCLEN          ; compare both lengths
    bcs COMPRF          ; skip next instruction if second string is shorter

    tax

COMPRF:
    stx zpWORK+3        ; save length of the (shortest) string

                        ; Y=0
COMPRG:
    cpy zpWORK+3
    beq COMPRH          ; exit if shorter string has zero length

    ; compare string in STRACC with string on top of stack

    iny
    lda (zpAESTKP),Y
    cmp STRACC-1,Y
    beq COMPRG          ; loop to next character if equal
    bne COMPRI          ; leave when not equal

COMPRH:
    lda zpWORK+2        ; compare the lengths of the strings
    cmp zpCLEN

COMPRI:
    php                 ; save the flags
    jsr POPSTX          ; discard string on top of stack
    ldx zpWORK          ; get the character back
    plp                 ; restore the flags
    rts


; EXPRESSION EVALUATOR
; ====================

; Evaluate expression at (zpLINE)
; -------------------------------

AEEXPR:
    lda zpLINE
    sta zpAELINE          ; Copy zpLINE to zpAELINE
    lda zpLINE+1
    sta zpAELINE+1
    lda zpCURSOR
    sta zpAECUR

; Evaluate expression at zpAELINE
; ---------------------------
; TOP LEVEL EVALUATOR
;
; Evaluator Level 7 - OR, EOR
; ---------------------------

; EXPR reads a rhs. If status is eq then it returned a string.
; If status is neq and plus then it returned a word.
; If status is neq and minus then it returned an fp.

EXPR:
    jsr ANDER         ; Call Evaluator Level 6 - AND
                      ; Returns A=type, value in IACC/FACC/STRACC, X=next char
EXPRQ:
    cpx #tknOR
    beq OR            ; Jump if next char is OR

    cpx #tknEOR
    beq EOR_          ; Jump if next char is EOR

    dec zpAECUR       ; Step zpAECUR back to last char
    tay
    sta zpTYPE
    rts               ; Set flags from type, store type in $27 and return

; OR numeric
; ----------

OR:
    jsr PHANDR        ; push as integer, evaluate next expression
    tay
    jsr INTEGB        ; ensure it's also an integer, if not, convert

    ldy #$03

ORLP:
    lda (zpAESTKP),Y
    ora zpIACC,Y      ; OR IACC with top of stack    ; abs,y (!)
    sta zpIACC,Y      ; abs,y (!)
    dey
    bpl ORLP          ; Store result in IACC

EXPRP:
    jsr POPINC        ; Drop integer from stack
    lda #$40          ; return type is integer
    bne EXPRQ         ; check for more OR/EOR, branch always

; EOR numeric
; -----------

EOR_:
    jsr PHANDR        ; push as integer, evaluate next expression
    tay
    jsr INTEGB        ; ensure it's also an integer, if not, convert

    ldy #$03

EORLP:
    lda (zpAESTKP),Y
    eor zpIACC,Y      ; EOR IACC with top of stack       ; abs,y (!)
    sta zpIACC,Y      ; abs,y (!)
    dey
    bpl EORLP         ; Store result in IACC
    bmi EXPRP         ; Jump to drop from stack and continue

; Stack current as integer, evaluate another Level 6
; --------------------------------------------------

PHANDR:
    tay
    jsr INTEGB        ; ensure it's an integer, else, convert to integer
    jsr PHACC         ; push to stack

; Evaluator Level 6 - AND
; -----------------------

ANDER:
    jsr RELATE         ; Call Evaluator Level 5, < <= = >= > <>

ANDERQ:
    cpx #tknAND
    beq AND
    rts               ; Return if next char not AND

; AND numeric
; -----------

AND:
    tay
    jsr INTEGB        ; ensure it's an integer, convert otherwise
    jsr PHACC         ; push onto stack
    jsr RELATE        ; Call Evaluator Level 5, < <= = >= > <>

    tay
    jsr INTEGB        ; ensure it's an integer

    ldy #$03

ANDLP:
    lda (zpAESTKP),Y
    and zpIACC,Y      ; AND IACC with top of stack   ; abs,y (!)
    sta zpIACC,Y      ; abs,y (!)
    dey
    bpl ANDLP         ; Store result in IACC

    jsr POPINC        ; Drop integer from stack
    lda #$40          ; return type is integer
    bne ANDERQ        ; jump to check for another AND

; Evaluator Level 5 - >... =... or <...
; -------------------------------------

RELATE:
    jsr ADDER         ; Call Evaluator Level 4, + -
    cpx #'>'+1
    bcs RELATX        ; Larger than '>', return

    cpx #'<'
    bcs RELTS         ; Smaller than '<', return

RELATX:
    rts

; >... =... or <...
; -----------------

RELTS:
    beq RELTLT        ; Jump with '<'
    cpx #'>'
    beq RELTGT        ; Jump with '>'
                      ; Must be '='
; = numeric
; ---------

    tax
    jsr COMPRP1
    bne FAIL          ; Jump with result=0 for not equal

PASS:
    dey               ; Decrement to $FF for equal

FAIL:
    sty zpIACC        ; Store 0/-1 in IACC
    sty zpIACC+1
    sty zpIACC+2
    sty zpIACC+3
    lda #$40          ; return type is integer
    rts

; < <= <>
; -------
RELTLT:               ; RELate Less Than
    tax
    ldy zpAECUR
    lda (zpAELINE),Y  ; Get next char from zpAELINE
    cmp #'='
    beq LTOREQ        ; Jump for <=

    cmp #'>'
    beq NEQUAL        ; Jump for <>

; Must be < numeric
; -----------------
    jsr COMPR         ; test less than, evaluate next and compare
    bcc PASS          ; Jump to return TRUE if <
    bcs FAIL          ; return FALSE if not <

; <= numeric
; ----------
LTOREQ:
    inc zpAECUR       ; step past '='
    jsr COMPR         ; evaluate next and compare
    beq PASS          ; jump if equal
    bcc PASS          ; jump if less than
    bcs FAIL          ; Jump to return FALSE otherwise

; <> numeric
; ----------
NEQUAL:
    inc zpAECUR       ; step past '>'
    jsr COMPR         ; evaluate next and compare
    bne PASS          ; jump if not equal
    beq FAIL          ; or fail

; > >=
; ----
RELTGT:               ; RELate Greater Than
    tax
    ldy zpAECUR
    lda (zpAELINE),Y  ; Get next char from zpAELINE
    cmp #'='
    beq GTOREQ        ; Jump for >=

; > numeric
; ---------
    jsr COMPR         ; test greater than, evaluate next and compare
    beq FAIL          ; fail if equal
    bcs PASS          ; pass if greater than (and not equal)
    bcc FAIL          ; fail if less than

; >= numeric
; ----------
GTOREQ:
    inc zpAECUR       ; step past '='
    jsr COMPR         ; evaluate next and compare
    bcs PASS          ; pass if greater than or equal
    bcc FAIL          ; fail if less than, branch always

; ----------------------------------------------------------------------------

STROVR:
    brk
    dta $13, 'String too long', 0

; String addition / concatenation
; -------------------------------

STNCON:
    jsr PHSTR         ; Stack string
    jsr POWER         ; call Evaluator Level 2
    tay
    bne ADDERE        ; string + number, jump to 'Type mismatch' error

    clc
    stx zpWORK
    ldy #$00
    lda (zpAESTKP),Y  ; Get stacked string length
    adc zpCLEN
    bcs STROVR        ; If added string length >255, jump to error

    tax
    pha
    ldy zpCLEN        ; Save new string length
CONLOP:
    lda STRACC-1,Y
    sta STRACC-1,X    ; Move current string up in string buffer
    dex
    dey
    bne CONLOP

    jsr POPSTR        ; Unstack string to start of string buffer

    pla
    sta zpCLEN
    ldx zpWORK        ; Set new string length
    tya               ; set type is string
    beq ADDERQ        ; jump to check for more + or -, branch always

; Evaluator Level 4, + -
; ----------------------

ADDER:
    jsr TERM          ; Call Evaluator Level 3, * / DIV MOD

ADDERQ:
    cpx #'+'
    beq PLUS          ; Jump for addition

    cpx #'-'
    beq MINUS         ; Jump for subtraction

    rts               ; Return otherwise

; + <value>
; ---------

PLUS:
    tay
    beq STNCON        ; Jump if current value is a string (concatenation)
    bmi FPLUS         ; Jump if current value is a float

; Integer addition
; ----------------

    jsr PHTERM        ; Stack current and call Evaluator Level 3
    tay
    beq ADDERE        ; If int + string, jump to 'Type mismatch' error
    bmi FPLUST        ; If int + float, jump ...

    ldy #$00
    clc
    lda (zpAESTKP),Y
    adc zpIACC         ; Add top of stack to IACC
    sta zpIACC         ; Store result in IACC
    iny
    lda (zpAESTKP),Y
    adc zpIACC+1
    sta zpIACC+1
    iny
    lda (zpAESTKP),Y
    adc zpIACC+2
    sta zpIACC+2
    iny
    lda (zpAESTKP),Y
    adc zpIACC+3

ADDERP:
    sta zpIACC+3
    clc
    lda zpAESTKP
    adc #$04
    sta zpAESTKP       ; Drop integer from stack
    lda #$40
    bcc ADDERQ         ; Set result=integer, jump to check for more + or -

    inc zpAESTKP+1
    bcs ADDERQ         ; Jump to check for more + or -

ADDERE:
    jmp LETM           ; Jump to 'Type mismatch' error

; Floating point addition
; -----------------------

FPLUS:
    jsr PHFACC         ; push FACC
    jsr TERM           ; Stack float, call Evaluator Level 3
    tay
    beq ADDERE         ; float + string, jump to 'Type mismatch' error

    stx zpTYPE
    bmi FPLUSS         ; float + float, skip conversion

    jsr IFLT           ; float + int, convert int to float

FPLUSS:
    jsr POPSET         ; Pop float from stack, point ARGP to it
    jsr FADD           ; load FWRK via ARGP, and add to FACC

FFFFA:
    ldx zpTYPE         ; Get nextchar back
    lda #$FF
    bne ADDERQ         ; Set result=float, loop to check for more + or -

; int + float
; -----------

FPLUST:
    stx zpTYPE
    jsr POPACC         ; Unstack integer to IACC
    jsr PHFACC         ; push FACC
    jsr IFLT           ; convert integer in IACC to float in FACC
    jmp FPLUSS         ; Jump to do float + <stacked float>

; - numeric
; ---------

MINUS:
    tay
    beq ADDERE         ; If current value is a string, jump to error
    bmi FMINUS         ; Jump if current value is a float

; Integer subtraction
; -------------------

    jsr PHTERM         ; Stack current and call Evaluator Level 3
    tay
    beq ADDERE         ; int + string, jump to error
    bmi FMINUT         ; int + float, jump to convert and do real subtraction

    sec
    ldy #$00
    lda (zpAESTKP),Y
    sbc zpIACC         ; Subtract IACC from top of stack
    sta zpIACC         ; Store in IACC
    iny
    lda (zpAESTKP),Y
    sbc zpIACC+1
    sta zpIACC+1
    iny
    lda (zpAESTKP),Y
    sbc zpIACC+2
    sta zpIACC+2
    iny
    lda (zpAESTKP),Y
    sbc zpIACC+3
    jmp ADDERP         ; Jump to pop stack and loop for more + or -

; Floating point subtraction
; --------------------------

FMINUS:
    jsr PHFACC         ; push FACC
    jsr TERM           ; Stack float, call Evaluator Level 3

    tay
    beq ADDERE         ; float - string, jump to 'Type mismatch' error
    stx zpTYPE
    bmi FMINUR         ; float - float, skip conversion

    jsr IFLT           ; float - int, convert int to float

FMINUR:
    jsr POPSET         ; Pop float from stack and point ARGP to it
    jsr FXSUB          ; load FWRK via ARGP, and subtract it from FACC
    jmp FFFFA          ; Jump to set result and loop for more + or -

; int - float
; -----------

FMINUT:
    stx zpTYPE
    jsr POPACC         ; Unstack integer to IACC
    jsr PHFACC         ; push FACC
    jsr IFLT           ; convert integer in IACC to float in FACC
    jsr POPSET         ; Pop float from stack, point ARGP to it
    jsr FSUB           ; Subtract ARGP float from FACC float
    jmp FFFFA          ; Jump to set result and loop for more + or -

; Floating point multiplication
; -----------------------------

FTIMLF:
    jsr IFLT        ; convert IACC to FACC

FTIML:
    jsr POPACC      ; pull integer from stack
    jsr PHFACC      ; push FACC to stack
    jsr IFLT        ; convert IACC to FACC
    jmp FTIMR       ; jump to floating point multiplication

FTIMFL:
    jsr IFLT        ; convert IACC to FACC

FTIM:
    jsr PHFACC      ; push FACC to stack
    jsr POWER       ; evaluate next expression
    stx zpTYPE      ; save the next character
    tay
    jsr FLOATI      ; ensure operand is floating point number

FTIMR:
    jsr POPSET      ; pop float, leave ARGP pointing to it
    jsr FMUL        ; multiply!
    lda #$FF
    ldx zpTYPE
    jmp TERMQ       ; rejoin parser

FTIME:
    jmp LETM        ; jump to 'Type mismatch' error

; * <value>
; ---------

TIMES:
    tay
    beq FTIME         ; If current value is string, jump to error
    bmi FTIM          ; Jump if current valus ia a float

; Integer multiplication
;
; This algorithm is complicated by checks that are made for overflow before
; it starts (e.g. &100000 * &100000 would overflow in integer arithmetic)
; Thus the routine tries to sense whether multiplication would be better
; carried out using floating point arithmetic. This is done bye checking
; if either operand is outside the -&8000 to &7FFF range. If either is,
; floating point multiplication is used.

    lda zpIACC+3
    cmp zpIACC+2
    bne FTIMFL      ; do FP mul if top two bytes of operand are not equal

    tay
    beq TIMESA      ; skip if (both) byte(s) are zero

    cmp #$FF
    bne FTIMFL      ; if not $ff, do floating point multiplication

    ; we can be sure the top bytes are either $0000 or $ffff

TIMESA:
    eor zpIACC+1
    bmi FTIMFL      ; top bit differs from previous two bytes --> fp mul

    jsr PHPOW       ; save current operand and evaluate next

    stx zpTYPE
    tay
    beq FTIME       ; 'Type mismatch' error if 2nd expression is a string
    bmi FTIML       ; floating point multiplication if it's a real

    lda zpIACC+3    ; same range checks as done on first operand
    cmp zpIACC+2
    bne FTIMLF

    tay
    beq TIMESB

    cmp #$FF
    bne FTIMLF

TIMESB:
    eor zpIACC+1
    bmi FTIMLF

    lda zpIACC+3    ; save byte containing sign bit on the stack
    pha
    jsr ABSCOM      ; take absolute value of IACC

    ldx #zpWORK+2
    jsr ACCTOM      ; stash IACC in zpWORK+2 and onwards

    jsr POPACC      ; pop first operand to IACC

    pla             ; retrieve the other sign
    eor zpIACC+3    ; eor to get sign of answer
    sta zpWORK      ; store in zpWORK

    jsr ABSCOM      ; absolute value of IACC

; Mostly the same multiplication as we have seen before
; multiply IACC by zpWORK+2/3, result in zpWORK+6..9
; for speed, zpWORK+6/7 are kept in XY, and stored at the end

    ldy #$00
    ldx #$00
    sty zpWORK+8
    sty zpWORK+9

NUL:
    lsr zpWORK+3    ; shift right
    ror zpWORK+2
    bcc NAD         ; no addition if there's no carry

    clc             ; add IACC to answer, keep LSB and LSB+1 in XY
    tya
    adc zpIACC
    tay
    txa
    adc zpIACC+1
    tax

    lda zpWORK+8
    adc zpIACC+2
    sta zpWORK+8
    lda zpWORK+9
    adc zpIACC+3
    sta zpWORK+9

NAD:
    asl zpIACC      ; shift IACC left
    rol zpIACC+1
    rol zpIACC+2
    rol zpIACC+3
    lda zpWORK+2
    ora zpWORK+3
    bne NUL         ; continue until zpWORK value is zero

    sty zpWORK+6    ; finally store XY in result
    stx zpWORK+7
    lda zpWORK
    php             ; save flags / sign of result

REMIN:
    ldx #zpWORK+6   ; 'M' offset

DIVIN:
    jsr MTOACC      ; move 'M' to IACC

    plp             ; pull sign of result
    bpl TERMA       ; exit if ok.

    jsr COMPNO      ; negate the answer

TERMA:
    ldx zpTYPE      ; get back the next letter
    jmp TERMQ

; * <value>
; ---------
TIMESJ:
    jmp TIMES         ; Bounce back to multiply code

; ----------------------------------------------------------------------------

; Stack current value and continue in Evaluator Level 3
; -------------------------------------------------------
PHTERM:
    jsr PHACC

; Evaluator Level 3, * / DIV MOD
; ------------------------------
TERM:
    jsr POWER          ; Call Evaluator Level 2, ^

TERMQ:
    cpx #'*'
    beq TIMESJ         ; Jump with multiply

    cpx #'/'
    beq DIVIDE         ; Jump with divide

    cpx #tknMOD
    beq REMAIN         ; Jump with MOD

    cpx #tknDIV
    beq INTDIV         ; Jump with DIV

    rts

; / <value>
; ---------
DIVIDE:
    tay
    jsr FLOATI         ; Ensure current value is real
    jsr PHFACC         ; push FACC to stack
    jsr POWER          ; call Evaluator Level 2

    stx zpTYPE         ; save next character
    tay
    jsr FLOATI         ; Ensure current value is real
    jsr POPSET         ; pop, and have ARGP point to popped float
    jsr FXDIV          ; call divide routine

    ldx zpTYPE         ; get back character
    lda #$FF           ; indicate result is floating point
    bne TERMQ          ; loop for more * / MOD DIV

; MOD <value>
; -----------

REMAIN:
    jsr DIVOP         ; call the integer division routine

    lda zpWORK+1      ; save sign of the dividend
    php               ; on the stack

    jmp REMIN         ; join int mul code to retrieve 'M' to IACC

; DIV <value>
; -----------

INTDIV:
    jsr DIVOP         ; call the integer division routine

    rol zpWORK+2      ; multiply dividend by 2 (final operation)
    rol zpWORK+3
    rol zpWORK+4
    rol zpWORK+5
    bit zpWORK        ; save the sign
    php               ; on the stack

    ldx #zpWORK+2     ; for MTOACC
    jmp DIVIN         ; join int mul code to retrieve 'M' to IACC

; ----------------------------------------------------------------------------

; Stack current integer and evaluate another Level 2
; --------------------------------------------------
PHPOW:
    jsr PHACC         ; Stack IACC

; Evaluator Level 2, ^
; --------------------
POWER:
    jsr FACTOR         ; Call Evaluator Level 1, - + NOT function ( ) ? ! $ | "

POWERB:
    pha                 ; save the type of operand

POWERA:
    ldy zpAECUR
    inc zpAECUR
    lda (zpAELINE),Y    ; Get character
    cmp #' '
    beq POWERA          ; Skip spaces, and get next character

    tax                 ; transfer next character to X
    pla                 ; retrieve type back in A
    cpx #'^'
    beq POW             ; jump if exponentiation

    rts                 ; Return if not ^

; ^ <value>
; ---------
POW:
    tay
    jsr FLOATI      ; ensure current value is a float
    jsr PHFACC      ; push FACC
    jsr FLTFAC      ; evaluate expression, make sure it's a real number

    lda zpFACCX
    cmp #$87
    bcs FPOWA       ; jump if abs(n) >= 64

    jsr FFRAC       ; set FQUAD to the integer part of FACC, and FACCC to
                    ; its fractional part
    bne FPOWE       ; jummp if fractional part != 0

                    ; exponent n is integer between -64 and +64

    jsr POPSET      ; pop float from stack, leave ARGP pointing to it
    jsr FLDA        ; unpack to FACC

    lda zpFQUAD     ; get (integer) exponent n in A
    jsr FIPOW       ; calculate FACC ^ n

    lda #$FF        ; result is floating point
    bne POWERB      ; loop to check for more ^

    ; here when exponent is not an integer

FPOWE:
    jsr STARGC      ; copy fractional part to FWSC temporary workspace

    lda zpAESTKP    ; make ARGP point to top of stack
    sta zpARGP
    lda zpAESTKP+1
    sta zpARGP+1

    jsr FLDA        ; unpack top of stack to FACC

    lda zpFQUAD
    jsr FIPOW       ; calculate FACC = FACC ^ INT(n)

FPOWC:
    jsr STARGB      ; save intermediate answer in FWSB temporary workspace

    jsr POPSET      ; pop float from stack, leave ARGP pointing to it
    jsr FLDA        ; unpack to FACC
    jsr FLOG        ; calculate FACC = LN(FACC)
    jsr ACMUL       ; calculate FACC = FACC * FWSC (FWSC = fractional part of n)
    jsr FEXP        ; calculate FACC = e ^ FACC
    jsr ARGB        ; make ARGP point to FWSB (partial answer)
    jsr FMUL        ; multiply, FACC = FACC * FWSB

    lda #$FF        ; result is floating point
    bne POWERB      ; loop to check for more ^

FPOWA:
    jsr STARGC      ; store FACC at FWSC temporary workspace
    jsr FONE        ; set FACC to 1
    bne FPOWC       ; branch always

; ----------------------------------------------------------------------------

; Convert number to hex string in STRACC
; --------------------------------------

FCONHX:
    tya
    bpl FCONHF

    jsr IFIX          ; convert floating point to to integer

FCONHF:
    ldx #$00          ; pointer into zpWORK+8
    ldy #$00          ; pointer into IACC

HEXPLP:
    lda zpIACC,Y      ; get first byte (abs,y (!))
    pha               ; save
    and #$0F          ; lower nibble
    sta zpWORK+8,X    ; save in workspace

    pla               ; retrieve original byte
    lsr               ; shift right 4 times
    lsr
    lsr
    lsr

    inx
    sta zpWORK+8,X    ; save upper nibble as digit
    inx
    iny
    cpy #$04
    bne HEXPLP        ; Loop for four bytes

HEXLZB:
    dex
    beq HEXP          ; No digits left, output a single zero

    lda zpWORK+8,X
    beq HEXLZB        ; Skip leading zeros

HEXP:
    lda zpWORK+8,X    ; traverse storage backwards
    cmp #$0A
    bcc NOTHX         ; less than 10

                      ; carry is set, so it's +7
    adc #$06          ; >= 10, convert byte to hex (A-F after '0' is added)

NOTHX:
    adc #'0'          ; to ASCII
    jsr CHTOBF        ; store in STRACC buffer
    dex
    bpl HEXP          ; loop for remaining digits

    rts

; ----------------------------------------------------------------------------

; Output nonzero real number
; --------------------------
FPRTA:
    bpl FPRTC          ; Jump forward if positive

    lda #'-'
    sta zpFACCS        ; A='-', clear sign flag
    jsr CHTOBF         ; Add '-' to string buffer

FPRTC:
    lda zpFACCX       ; Get exponent
    cmp #$81          ; get into range 1.0000 to 9.9999
    bcs FPRTD         ; If m*2^1 or larger, number>=1, jump to output it

    jsr FTENFX        ; FACC=FACC*10

    dec zpFPRTDX
    jmp FPRTC         ; Loop until number is >=1

; Convert numeric value to string
; ===============================
; On entry, FACC ($2E-$35)    = number
;           or IACC ($2A-$2D) = number
;                           Y = type
;                          @% = print format
;                     $15.b7 set if hex
; Uses,     zpWORK=format type 0/1/2=G/E/F
;           zpWORK+1=max digits
;           zpFPRTDX
; On exit,  STRACC contains string version of number
;           zpCLEN=string length
;
FCON:
    ldx VARL_AT+2     ; Get format byte, flag forcing E
    cpx #$03
    bcc FCONOK        ; If <3, ok - use it

    ldx #$00          ; If invalid, $00 for General format
FCONOK:
    stx zpWORK        ; Store format type
    lda VARL_AT+1
    beq FCONC         ; If digits=0, jump to check format

    cmp #$0A
    bcs FCONA         ; If 10+ digits, jump to use 10 digits

;  In G,E formats VARL is no. of significant figs > 0
;  In F format it is no. of decimals and can e >= 0

    bcc FCONB         ; If <10 digits, use specified number

FCONC:
    cpx #$02
    beq FCONB         ; If fixed format, use zero digits

; STR$ enters here to use general format, having set zpWORK to 0
; --------------------------------------------------------------

FCONA:
    lda #$0A          ; Otherwise, default to ten digits

FCONB:
    sta zpWORK+1
    sta zpFDIGS       ; Store digit length
    lda #$00
    sta zpCLEN        ; set initial STRACC length to 0
    sta zpFPRTDX      ; set initial exponent to 0
    bit zpPRINTF      ; check bit 7
    bmi FCONHX        ; Jump for hex conversion if bit 7 set

    tya
    bmi FCONFX        ; ensure we have float

    jsr IFLT          ; convert integer to floating point

FCONFX:
    jsr FTST      ; Get -1/0/+1 sign
    bne FPRTA     ; jump if not zero to output nonzero number

    lda zpWORK
    bne FPRTHJ    ; If not General format, output fixed or exponential zero

    lda #'0'
    jmp CHTOBF    ; Store single '0' into string buffer and return

FPRTHJ:
    jmp FPRTHH     ; Jump to output zero in fixed or exponential format

FPRTEE:
    jsr FONE        ; FACC = 1.0
    bne FPRTEP3     ; branch always

; FACC now is >=1, check that it is <10
; -------------------------------------

FPRTD:
    cmp #$84        ; exponent of 9.99
    bcc FPRTF       ; 1.0 to 7.999999 all OK
    bne FPRTE       ; exponent 85 or more
    lda zpFACCMA    ; fine check when exponent=84
    cmp #$A0
    bcc FPRTF       ; 8.0000 to 9.9999

FPRTE:
    jsr FTENFQ      ; divide FACC by 10.0

FPRTEP3:
    inc zpFPRTDX    ; indicate decimal point moved 1 position to the left
    jmp FPRTC       ; jump back to get the number >=1 again

; FACC is now between 1 and 9.999999999
; --------------------------------------

FPRTF:
    lda zpFACCMG      ; save rounding byte separately
    sta zpTYPE
    jsr STARGA        ; Copy FACC to FWSA, workspace temporary float

    lda zpFDIGS
    sta zpWORK+1      ; Get number of digits
    ldx zpWORK        ; Get print format
    cpx #$02
    bne FPRTFH        ; Not fixed format, jump to do exponent/general

    adc zpFPRTDX      ; fix up the precision
    bmi FPRTZR

    sta zpWORK+1
    cmp #$0B
    bcc FPRTFH        ; precision still reasonable

    lda #$0A          ; ten digits
    sta zpWORK+1
    lda #$00
    sta zpWORK        ; treat as G format

FPRTFH:
    jsr FCLR          ; Clear FACC

    lda #$A0
    sta zpFACCMA
    lda #$83
    sta zpFACCX       ;  5.0 --> FACC

    ldx zpWORK+1
    beq FPRTGJ        ; loop if remaining digits

FPRTGG:
    jsr FTENFQ        ; divide FACC by 10.0
    dex
    bne FPRTGG        ; continue until the digit count is zero

FPRTGJ:
    jsr ARGA          ; Point ARGP to workspace FP temp A (FWSA)
    jsr FLDW          ; Unpack (ARGP) to FWRK

    lda zpTYPE
    sta zpFWRKMG      ; restore rounding byte

    jsr FADDW1        ; Add FWRK to FACC

FPRTFF:
    lda zpFACCX
    cmp #$84
    bcs FPRTG         ; exit if exponent >= $84

    ror zpFACCMA      ; shift mantissa right (share code with end of FTENFX?)
    ror zpFACCMB
    ror zpFACCMC
    ror zpFACCMD
    ror zpFACCMG
    inc zpFACCX       ; compensate by increasing exponent
    bne FPRTFF        ; continue

FPRTG:
    lda zpFACCMA
    cmp #$A0          ; see if unnormalized
    bcs FPRTEE        ; fix up if so

    lda zpWORK+1
    bne FPRTH         ; skip next section if number of digits != 0, always here

; Output zero in Exponent or Fixed format
; ---------------------------------------

FPRTHH:
    cmp #$01
    beq FPRTK       ; goto 'E' format

FPRTZR:
    jsr FCLR        ; Clear FACC

    lda #$00
    sta zpFPRTDX    ; set decimal exponent to zero
    lda zpFDIGS
    sta zpWORK+1    ; set number of digits to be printed to value in @%
    inc zpWORK+1    ; increment by one to allow for the leading zero

;  The exponent is $84, so the top digit of FACC is the first digit to print

FPRTH:
    lda #$01
    cmp zpWORK
    beq FPRTK       ; goto 'E' format

    ldy zpFPRTDX
    bmi FPRTKK      ; print leading zeroes

    cpy zpWORK+1
    bcs FPRTK       ; use scientific is <1.0 or > 10^digits

    lda #$00
    sta zpFPRTDX    ; set exponent to zero
    iny
    tya             ; location of decimal point in A
    bne FPRTK       ; use F type format

FPRTKK:
    lda zpWORK
    cmp #$02
    beq FPRTKL      ; F format case

    lda #$01
    cpy #$FF
    bne FPRTK       ; set E format

FPRTKL:
    lda #'0'
    jsr CHTOBF      ; Output '0'

    lda #'.'
    jsr CHTOBF      ; Output '.'

    lda #'0'        ; Prepare '0'
FPRTKM:
    inc zpFPRTDX    ; increment exponent
    beq FPRTKN      ; exit when it becomes zero

    jsr CHTOBF      ; Output '0'
    bne FPRTKM      ; repeat the process

FPRTKN:
    lda #$80        ; indicate decimal point is at $80, will not be printed

FPRTK:
    sta zpFPRTWN    ; save decimal point location

FPRTI:
    jsr FPRTNN      ; print next digit to buffer

    dec zpFPRTWN    ; decrement decimal point location
    bne FPRTL

    lda #'.'        ; add decimal point to buffer
    jsr CHTOBF

FPRTL:
    dec zpWORK+1
    bne FPRTI       ; loop for the required number of digits

    ldy zpWORK
    dey
    beq FPRTTX      ; print exponent part if 'E' mode is in use

    dey
    beq FPRTTYp2    ; print exponent part in 'F' mode

    ; 'G' mode, remove trailing zeros

    ldy zpCLEN

FPRTTZ:
    dey
    lda STRACC,Y
    cmp #'0'
    beq FPRTTZ      ; remove 0s

    cmp #'.'
    beq FPRTTY      ; and decimal point if needed

    iny

FPRTTY:
    sty zpCLEN      ; store string length

FPRTTYp2:
    lda zpFPRTDX
    beq FPRTX       ; return if exponent = 0

FPRTTX:
    lda #'E'
    jsr CHTOBF      ; Output 'E'

    lda zpFPRTDX
    bpl FPRTJ       ; skip next part if exponent is positive

    lda #'-'
    jsr CHTOBF      ; Output '-'

    sec
    lda #$00
    sbc zpFPRTDX    ; Negate exponent

FPRTJ:
    jsr IPRT        ; print exponent to the buffer

    lda zpWORK
    beq FPRTX       ; exit if 'G' format is in use

    lda #' '
    ldy zpFPRTDX
    bmi FPRTTW      ; skip if exponent was minus

    jsr CHTOBF      ; when positive, add space to make up for the minus sign

FPRTTW:
    cpx #$00
    bne FPRTX

    jmp CHTOBF      ; add another ' ' if exponent is a single digit, tail call

FPRTX:
    rts

; print next mantissa digit

FPRTNN:
    lda zpFACCMA    ; get top nibble
    lsr
    lsr
    lsr
    lsr
    jsr FPRTDG      ; print digit

    lda zpFACCMA
    and #$0F        ; mask out top nibble
    sta zpFACCMA    ; and store

    jmp FTENX       ; multiply by 10, tail call

; ----------------------------------------------------------------------------

; Print Accu in decimal unsigned, output of exponent as a number (0-99)

IPRT:
    ldx #$FF        ; start with most significant digit as -1
    sec

IPRTA:
    inx             ; increment digit
    sbc #$0A        ; subtract 10
    bcs IPRTA       ; if still >= 0, keep subtracting 10 and increasing X

    adc #$0A        ; add last 10 back
    pha             ; and save on stack
    txa
    beq IPRTB       ; skip printing if it's 0

    jsr FPRTDG      ; print digit

IPRTB:
    pla             ; get remainder back in A

FPRTDG:
    ora #'0'        ; add '0' to make it ASCII

; Store character in string buffer
; --------------------------------
CHTOBF:
    stx zpWORK+4    ; save X register
    ldx zpCLEN
    sta STRACC,X    ; Store character
    ldx zpWORK+4    ; restore X register
    inc zpCLEN      ; Increment string length
    rts

; ----------------------------------------------------------------------------

; READ ROUTINES

FRDDXX:
    clc             ; indicate failure
    stx zpFACCMG    ; set rounding byte to zero (always entered with X=0)
    jsr FTST        ; set sign and under/overflow to zero
    lda #$FF        ; indidcate answer is floating point
    rts

; Get decimal number from AELINE
; ------------------------------

FRDD:
    ldx #$00
    stx zpFACCMA        ; Clear FACC
    stx zpFACCMB
    stx zpFACCMC
    stx zpFACCMD
    stx zpFACCMG
    stx zpFRDDDP        ; Clear 'Decimal point' flag
    stx zpFRDDDX        ; Set exponent to zero
    cmp #'.'
    beq FRDDDD          ; Leading decimal point

    cmp #'9'+1
    bcs FRDDXX          ; Not a decimal digit, finish

    sbc #'0'-1          ; carry is clear
    bmi FRDDXX          ; Convert to binary, if not digit finish

    sta zpFACCMG        ; Store digit

FRDDC:
    iny
    lda (zpAELINE),Y  ; Get next character
    cmp #'.'
    bne FRDDD         ; Not decimal point

FRDDDD:
    lda zpFRDDDP      ; seen before?
    bne FRDDQ         ; Already got decimal point,

    inc zpFRDDDP      ; set decimal point flag, indicate period has been seen
    bne FRDDC         ; loop for next

FRDDD:
    cmp #'E'
    beq FRDDEX        ; Jump to scan exponent

    cmp #'9'+1
    bcs FRDDQ         ; Not a digit, jump to finish

    sbc #'0'-1
    bcc FRDDQ         ; Not a digit, jump to finish, end of number

    ldx zpFACCMA      ; Get mantissa top byte
    cpx #$18
    bcc FRDDE         ; If <25, still small enough to add another digit

    ldx zpFRDDDP
    bne FRDDC         ; Decimal point found, go back for next character

    inc zpFRDDDX      ; Otherwise, increment tens
    bcs FRDDC         ; go back and examine the next character

FRDDE:
    ldx zpFRDDDP
    beq FRDDF         ; No period yet

    dec zpFRDDDX      ; Decimal point found, decrement exponent

FRDDF:
    jsr FTENX         ; Multiply mantissa by 10

    adc zpFACCMG
    sta zpFACCMG      ; Add digit to mantissa low byte
    bcc FRDDC         ; No overflow

    inc zpFACCMD      ; Add carry through mantissa
    bne FRDDC

    inc zpFACCMC
    bne FRDDC

    inc zpFACCMB
    bne FRDDC

    inc zpFACCMA
    bne FRDDC         ; Loop to check next digit

; Deal with Exponent in scanned number

FRDDEX:
    jsr IRDD          ; Scan following number
    adc zpFRDDDX      ; Add to current exponent
    sta zpFRDDDX

; End of number found

FRDDQ:
    sty zpAECUR       ; Store AELINE offset
    lda zpFRDDDX
    ora zpFRDDDP      ; Check exponent and 'decimal point' flag
    beq FRINT         ; No exponent, no decimal point, return integer

    jsr FTST          ; was it zero?
    beq FRDDZZ        ; if so, exit at once

FRFP:
    lda #$A8          ; set exponent to indicate "bicemal" point
    sta zpFACCX       ; is to the right of the rounding byte
    lda #$00          ; clear sign and under/overflow bytes
    sta zpFACCXH
    sta zpFACCS
    jsr FNRM          ; normalise the number

; Now I have to MUL or DIV by power of ten given in zpFRDDDX

    lda zpFRDDDX
    bmi FRDDM         ; jump if it's negative
    beq FRDDZ         ; exit if it's zero

FRDDP:
    jsr FTENFX        ; times 10.0
    dec zpFRDDDX      ; decrement exponent
    bne FRDDP         ; keep adjusting until exponent is zero
    beq FRDDZ         ; exit, branch always

FRDDM:
    jsr FTENFQ        ; divide by 10.0
    inc zpFRDDDX      ; increment exponent
    bne FRDDM         ; until it's zero

FRDDZ:
    jsr FTIDY         ; round, check overflow

FRDDZZ:
    sec               ; indicate success
    lda #$FF          ; result is floating point
    rts

FRINT:
    lda zpFACCMB      ; make sure numbe is not too big to be an integer
    sta zpIACC+3
    and #$80
    ora zpFACCMA
    bne FRFP          ; jump if too big

    lda zpFACCMG      ; copy relevant parts of mantissa to IACC
    sta zpIACC
    lda zpFACCMD
    sta zpIACC+1
    lda zpFACCMC
    sta zpIACC+2

    lda #$40          ; indicate it's an integer
    sec               ; and success
    rts

IRDDB:
    jsr IRDDC         ; Scan following number
    eor #$FF          ; Negate it
    sec               ; return ok
    rts

; Scan exponent, allows E E+ E- followed by one or two digits
; -----------------------------------------------------------

IRDD:
    iny
    lda (zpAELINE),Y  ; Get next character
    cmp #'-'
    beq IRDDB         ; If '-', jump to scan and negate

    cmp #'+'
    bne IRDDA         ; If not '+', don't get next character

IRDDC:
    iny
    lda (zpAELINE),Y  ; Get next character

IRDDA:
    cmp #'9'+1
    bcs IRDDOW        ; Not a digit, exit with C=0 and A=0

    sbc #'0'-1
    bcc IRDDOW        ; Not a digit, exit with C=0 and A=0

    sta zpFRDDW       ; Store exponent digit
    iny
    lda (zpAELINE),Y  ; Get next character
    cmp #'9'+1
    bcs IRDDQ         ; Not a digit, exit with C=0 and A=exp

    sbc #'0'-1
    bcc IRDDQ         ; Not a digit, exit with C=0 and A=exp

    iny
    sta zpFTMPMA      ; Step past digit, store current digit
    lda zpFRDDW       ; Get current exponent
    asl
    asl               ; exp *= 4
    adc zpFRDDW       ; exp += exp (total *5)
    asl               ; exp *= 2   (total *10)
    adc zpFTMPMA      ; exp=exp*10+digit
    rts

IRDDQ:
    lda zpFRDDW
    clc
    rts               ; Get exp and return CC=Ok

IRDDOW:
    lda #$00
    clc
    rts               ; Return exp=0 and CC=Ok

; ----------------------------------------------------------------------------

; Add FWRK mantissa to FACC mantisa, result in FACC

FPLW:
    lda zpFACCMG
    adc zpFWRKMG
    sta zpFACCMG
    lda zpFACCMD
    adc zpFWRKMD
    sta zpFACCMD
    lda zpFACCMC
    adc zpFWRKMC
    sta zpFACCMC
    lda zpFACCMB
    adc zpFWRKMB
    sta zpFACCMB
    lda zpFACCMA
    adc zpFWRKMA
    sta zpFACCMA
    rts

; ----------------------------------------------------------------------------

; Multiply FACC mantissa by 10

FTENX:
    pha             ; preserve A

    ldx zpFACCMD    ; save mantissa in X and on the stack in the order we
    lda zpFACCMA    ; need to add it later
    pha
    lda zpFACCMB
    pha
    lda zpFACCMC
    pha

    lda zpFACCMG    ; shift left (m*2)
    asl
    rol zpFACCMD
    rol zpFACCMC
    rol zpFACCMB
    rol zpFACCMA

    asl             ; shift left (m*2, total m*4)
    rol zpFACCMD
    rol zpFACCMC
    rol zpFACCMB
    rol zpFACCMA

    adc zpFACCMG    ; add original version (m*4+m, total m*5)
    sta zpFACCMG
    txa
    adc zpFACCMD
    sta zpFACCMD
    pla
    adc zpFACCMC
    sta zpFACCMC
    pla
    adc zpFACCMB
    sta zpFACCMB
    pla
    adc zpFACCMA

    asl zpFACCMG    ; shift left (m*2, total m*10)
    rol zpFACCMD
    rol zpFACCMC
    rol zpFACCMB
    rol
    sta zpFACCMA

    pla             ; restore A
    rts

; ----------------------------------------------------------------------------

; FTST sets N,Z flags on FACC, tidies up if zero

FTST:
    lda zpFACCMA
    ora zpFACCMB
    ora zpFACCMC
    ora zpFACCMD
    ora zpFACCMG
    beq FTSTZ       ; it is zero

    lda zpFACCS     ; get sign byte
    bne FTSTR       ; exit if it's not zero

    lda #$01        ; non-zero and positive
    rts

FTSTZ:
    sta zpFACCS     ; zero sign, exponent, and under/overflow
    sta zpFACCX
    sta zpFACCXH

FTSTR:
    rts

; ----------------------------------------------------------------------------

; FACC times 10.0
;
;   FX:=FX+3            \ exponent + 3 --> *8
;   FW:=FACC            \ FWRK = FACC
;   FW:=FW>>2           \ divide by 4, i.e. two times the original value
;   FACC:=FACC+FW       \ add it to FACC, result is original *10
;   IF CARRY THEN {     \ in case of overflow
;     FACC:=FACC>>1;    \ divide by 2
;     FX:=FX+1 }        \ adjust exponent to compensate

FTENFX:
    clc
    lda zpFACCX     ; add 3 to exponent, *8
    adc #$03
    sta zpFACCX
    bcc FTENFA

    inc zpFACCXH    ; increment overflow if needed

FTENFA:
    jsr FTOW        ; copy FACC to FWRK
    jsr FASRW       ; divide by 2
    jsr FASRW       ; divide by 2 (FWRK contains original *2)

FPLWF:
    jsr FPLW        ; FACC = FACC + FWRK, total is original *10

;   CY is set on carry out of FACCMA and FWRKMA

FRENRM:
    bcc FRENX       ; exit if no overflow occurred

    ror zpFACCMA    ; shift mantissa right, divide by 2
    ror zpFACCMB
    ror zpFACCMC
    ror zpFACCMD
    ror zpFACCMG

    inc zpFACCX     ; increment exponent to compensate for divide
    bne FRENX

    inc zpFACCXH    ; possible exponent overflow

FRENX:
    rts

; ----------------------------------------------------------------------------

; FTOW -- Copy FACC to FWRK

FTOW:
    lda zpFACCS
    sta zpFWRKS
    lda zpFACCXH
    sta zpFWRKXH
    lda zpFACCX
    sta zpFWRKX
    lda zpFACCMA
    sta zpFWRKMA
    lda zpFACCMB
    sta zpFWRKMB
    lda zpFACCMC
    sta zpFWRKMC
    lda zpFACCMD
    sta zpFWRKMD
    lda zpFACCMG
    sta zpFWRKMG
    rts

; FTOWAS -- Copy FACC to FWRK and Arithmetic Shift Right

FTOWAS:
    jsr FTOW

; FASRW -- Mantissa Arithmetic Shift Right FWRK

FASRW:
    lsr zpFWRKMA
    ror zpFWRKMB
    ror zpFWRKMC
    ror zpFWRKMD
    ror zpFWRKMG
    rts

; ----------------------------------------------------------------------------

; FTENFQ -- Divide FACC by 10.0
;
; original author notes:
;
;   FX:=FX-4; WRK:=ACC; WRK:=WRK>>1; ACC:=ACC+WRK
;   ADJUST IF CARRY
;   WRK:=ACC; WRK:=WRK>>4; ACC:=ACC+WRK
;   ADJUST IF CARRY
;   WRK:=ACC>>8; ACC:=ACC>>8
;   ADJUST IF CARRY
;   WRK:=ACC>>16; ACC:=ACC+WRK
;   ADJUST IF CARRY
;   ACC:=ACC+(ACC>>32)
;   ADJUST IF CARRY

FTENFQ:
    sec
    lda zpFACCX     ; subtract 4 from the exponent, divide by 16
    sbc #$04
    sta zpFACCX
    bcs FTENB

    dec zpFACCXH    ; adjust underflow if needed

FTENB:
    jsr FTOWAS      ; copy FACC to FWRK and divide by 2 (>>1)
    jsr FPLWF       ; FACC += FWRK, (* 0.00011)

    jsr FTOWAS      ; copy FACC to FWRK and divide by 2
    jsr FASRW       ; divide FWRK by 2
    jsr FASRW       ; divide FWRK by 2
    jsr FASRW       ; divide FWRK by 2 (total FWRK divided by 16, >>4)
    jsr FPLWF       ; FACC += FWRK, (* 0.000110011)

    lda #$00        ; FWRK = FACC DIV 256 (shifted right one byte, >>8)
    sta zpFWRKMA
    lda zpFACCMA
    sta zpFWRKMB
    lda zpFACCMB
    sta zpFWRKMC
    lda zpFACCMC
    sta zpFWRKMD
    lda zpFACCMD
    sta zpFWRKMG

    lda zpFACCMG    ; include rounding bit
    rol             ; set carry bit properly
    jsr FPLWF       ; FACC += FWRK
    lda #$00
    sta zpFWRKMA    ; later BASICs skip this, because FWRKMA is already 0
    sta zpFWRKMB

    lda zpFACCMA    ; FWRK = FACC DIV 65536 (shift right two bytes, >>16)
    sta zpFWRKMC
    lda zpFACCMB
    sta zpFWRKMD
    lda zpFACCMC
    sta zpFWRKMG

    lda zpFACCMD    ; include rounding bit
    rol
    jsr FPLWF       ; FACC += FWRK

    lda zpFACCMB    ; get rounding bit of byte 2 in carry
    rol
    lda zpFACCMA    ; get byte 1

FPLNF:
    adc zpFACCMG    ; add to mantissa
    sta zpFACCMG
    bcc FPLNY       ; jump if no carry

    inc zpFACCMD    ; ripple carry through whole mantissa
    bne FPLNY

    inc zpFACCMC
    bne FPLNY

    inc zpFACCMB
    bne FPLNY

    inc zpFACCMA
    bne FPLNY

    jmp FRENRM      ; right shift and increment exponent if still carry

FPLNY:
    rts

; ----------------------------------------------------------------------------

; Convert IACC to FACC

IFLT:
    ldx #$00        ; zero under/overflow and rounding bytes
    stx zpFACCMG
    stx zpFACCXH

    lda zpIACC+3
    bpl IFLTA       ; skip negating if it is already positive

    jsr COMPNO      ; negate it
    ldx #$FF        ; indicate floating point sign

IFLTA:
    stx zpFACCS     ; save sign

    lda zpIACC      ; copy IACC to mantissa
    sta zpFACCMD
    lda zpIACC+1
    sta zpFACCMC
    lda zpIACC+2
    sta zpFACCMB
    lda zpIACC+3
    sta zpFACCMA

    lda #$A0        ; set exponent, indicate "bicemal" point is at 32 bits
    sta zpFACCX

    jmp FNRM        ; normalise the number

; ----------------------------------------------------------------------------

; Copy A to sign, exponent, and exponent under/overflow bytes

FNRMZ:
    sta zpFACCS
    sta zpFACCX
    sta zpFACCXH

FNRMX:
    rts

; Convert A to FACC

FLTACC:
    pha             ; save A
    jsr FCLR        ; zero FACC
    pla             ; restore A

    beq FNRMX       ; done if 0.0
    bpl FLTAA       ; >0.0

    sta zpFACCS     ; indicate negative sign

    lda #$00        ; negate
    sec
    sbc zpFACCS

FLTAA:
    sta zpFACCMA    ; store in most significant byte of mantissa
    lda #$88        ; set "bicemal" point at 8 bits
    sta zpFACCX

; FNRM normalizes the FACC using 16 bit exponent, so no worry about
; exponent overflow

FNRM:
    lda zpFACCMA
    bmi FNRMX       ; exit if already normalised

    ora zpFACCMB
    ora zpFACCMC
    ora zpFACCMD
    ora zpFACCMG
    beq FNRMZ       ; if mantissa is zero, set rest to zero and exit

    lda zpFACCX     ; rescue the exponent, A is always the current exponent

FNRMA:
    ldy zpFACCMA
    bmi FNRMX       ; exit if number is normalised
    bne FNRMC       ; if top byte is not zero, no (more) byte shifts

    ldx zpFACCMB    ; byte shift on mantissa (<<8)
    stx zpFACCMA
    ldx zpFACCMC
    stx zpFACCMB
    ldx zpFACCMD
    stx zpFACCMC
    ldx zpFACCMG
    stx zpFACCMD
    sty zpFACCMG    ; zero rounding byte

    sec             ; subtract 8 of exponent
    sbc #$08
    sta zpFACCX     ; and save
    bcs FNRMA       ; restart loop

    dec zpFACCXH    ; update underflow
    bcc FNRMA       ; restart loop, branch always

FNRMB:
    ldy zpFACCMA
    bmi FNRMX       ; exit if normalised

FNRMC:
    asl zpFACCMG    ; shift mantissa left (<<1)
    rol zpFACCMD
    rol zpFACCMC
    rol zpFACCMB
    rol zpFACCMA
    sbc #$00        ; subtract 1 of exponent
    sta zpFACCX     ; and save
    bcs FNRMB       ; restart the loop

    dec zpFACCXH
    bcc FNRMB       ; restart the loop, branch always

; ----------------------------------------------------------------------------

; FLDW -- Load FWRK via zpARGP

FLDW:
    ldy #5-1        ; five bytes

    lda (zpARGP),Y  ; get four mantissa bytes
    sta zpFWRKMD

    dey
    lda (zpARGP),Y
    sta zpFWRKMC

    dey
    lda (zpARGP),Y
    sta zpFWRKMB

    dey
    lda (zpARGP),Y
    sta zpFWRKS

    dey
    sty zpFWRKMG    ; zero over/underflow bytes
    sty zpFWRKXH

    lda (zpARGP),Y  ; get exponent
    sta zpFWRKX

    ora zpFWRKS
    ora zpFWRKMB
    ora zpFWRKMC
    ora zpFWRKMD
    beq FLDWX       ; if zero, set top byte of mantissa to zero

    lda zpFWRKS     ; set top byte from the sign byte
    ora #$80

FLDWX:
    sta zpFWRKMA    ; store
    rts

; ----------------------------------------------------------------------------

; Store FACC to one of the workspace FP temps via ARGP

STARGB:
    lda #<FWSB
    bne FSTAP

STARGC:
    lda #<FWSC
    bne FSTAP

STARGA:
    lda #<FWSA

FSTAP:
    sta zpARGP
    lda #>FWSA          ; MSB of all FWS / FP TEMP variables
    sta zpARGP+1

FSTA:
    ldy #$00
    lda zpFACCX
    sta (zpARGP),Y

    iny
    lda zpFACCS         ; tidy up sign bit
    and #$80
    sta zpFACCS

    lda zpFACCMA
    and #$7F
    ora zpFACCS         ; set true sign bit
    sta (zpARGP),Y

    lda zpFACCMB
    iny
    sta (zpARGP),Y

    lda zpFACCMC
    iny
    sta (zpARGP),Y

    lda zpFACCMD
    iny
    sta (zpARGP),Y
    rts

; ----------------------------------------------------------------------------

LDARGA:
    jsr ARGA        ; set ARGP to point to FWSA

; Load FACC via ARGP

FLDA:
    ldy #$04
    lda (zpARGP),Y
    sta zpFACCMD

    dey
    lda (zpARGP),Y
    sta zpFACCMC

    dey
    lda (zpARGP),Y
    sta zpFACCMB

    dey
    lda (zpARGP),Y
    sta zpFACCS

    dey
    lda (zpARGP),Y
    sta zpFACCX

    sty zpFACCMG    ; zero under/overflow bytes
    sty zpFACCXH

    ora zpFACCS
    ora zpFACCMB
    ora zpFACCMC
    ora zpFACCMD
    beq FLDAX       ; zero top byte of the mantissa if rest is zero

    lda zpFACCS     ; set top byte from sign
    ora #$80

FLDAX:
    sta zpFACCMA    ; store
    rts

; ----------------------------------------------------------------------------

; Convert floating point to integer
; =================================

IFIX:
    jsr FFIX         ; Convert floating point to integer

COPY_FACC_TO_IACC:
    lda zpFACCMA
    sta zpIACC+3     ; Copy to Integer Accumulator
    lda zpFACCMB
    sta zpIACC+2
    lda zpFACCMC
    sta zpIACC+1
    lda zpFACCMD
    sta zpIACC
    rts

; FFIX converts float to integer
; ==============================
;
; On entry, FACCX-FACCMD ($30-$34) holds a float
; On exit,  FACCX-FACCMD ($30-$34) holds integer part
; ---------------------------------------------------
; The real value is partially denormalised by repeatedly dividing the mantissa
; by 2 and incrementing the exponent to multiply the number by 2, until the
; exponent is $80, indicating that we have got to mantissa * 2^0.
; Truncates towards zero.
; The fractional part is left in FWRK.

FFIXQ:
    jsr FTOW       ; Copy FACC to FWRK
    jmp FCLR       ; Set FACC to zero and return

FFIX:
    lda zpFACCX
    bpl FFIXQ      ; Exponent<$80, number<1, jump to return 0

    jsr FCLRW      ; Set FWRK to zero
    jsr FTST       ; test FACC
    bne FFIXG      ; Always shift at least once
    beq FFIXY      ; except for 0

FFIXB:
    lda zpFACCX    ; Get exponent
    cmp #$A0
    bcs FFIXC      ; Exponent is +32, float has been denormalised to an integer

    cmp #$99
    bcs FFIXG      ; Loop to keep dividing

    adc #$08
    sta zpFACCX    ; Increment exponent by 8, allow for byte shift

    lda zpFWRKMC   ; byte shift, divide by 256 (>>8)
    sta zpFWRKMD
    lda zpFWRKMB
    sta zpFWRKMC
    lda zpFWRKMA
    sta zpFWRKMB
    lda zpFACCMD
    sta zpFWRKMA
    lda zpFACCMC
    sta zpFACCMD
    lda zpFACCMB
    sta zpFACCMC
    lda zpFACCMA
    sta zpFACCMB
    lda #$00        ; shift in zeros at the top
    sta zpFACCMA
    beq FFIXB       ; Loop to keep dividing, branch always

FFIXG:
    lsr zpFACCMA    ; bitwise right shift, divide by 2 (>>1)
    ror zpFACCMB
    ror zpFACCMC
    ror zpFACCMD
    ror zpFWRKMA    ; rotate into FWRK
    ror zpFWRKMB
    ror zpFWRKMC
    ror zpFWRKMD

    inc zpFACCX     ; increment exponent by 1
    bne FFIXB       ; continue and repeat the test

; Here I have overflow

FFIXV:
    jmp FOVR        ; 'Too big' error message

; ----------------------------------------------------------------------------

; Clear FWRK

FCLRW:
    lda #$00
    sta zpFWRKS
    sta zpFWRKXH
    sta zpFWRKX
    sta zpFWRKMA
    sta zpFWRKMB
    sta zpFWRKMC
    sta zpFWRKMD
    sta zpFWRKMG
    rts

; ----------------------------------------------------------------------------

FFIXC:
    bne FFIXV         ; Exponent > 32, jump to 'Too big' error

FFIXY:
    lda zpFACCS
    bpl FFIXZ         ; If positive, jump to return

FINEG:
    sec               ; Negate the mantissa to get integer
    lda #$00
    sbc zpFACCMD
    sta zpFACCMD
    lda #$00
    sbc zpFACCMC
    sta zpFACCMC
    lda #$00
    sbc zpFACCMB
    sta zpFACCMB
    lda #$00
    sbc zpFACCMA
    sta zpFACCMA

FFIXZ:
    rts

; ----------------------------------------------------------------------------

; FFRAC sets FQUAD to the integer part of FACC, and FACCC to its fractional
; part. Returns with condition code set zero if fraction is zero.
; Assumes that on input FIX(FACC) < 128.

FFRAC:
    lda zpFACCX
    bmi FFRACA      ; normal case

    lda #$00
    sta zpFQUAD
    jmp FTST        ; exit, set flags, if FACC's integer part is zero

FFRACA:
    jsr FFIX        ; fix FACC

    lda zpFACCMD    ; get least significant integer part
    sta zpFQUAD

    jsr FMWTOA      ; copy FWRK to FACC

    lda #$80        ; set exponent to $80, "bicemal" at the start of the number
    sta zpFACCX
    ldx zpFACCMA
    bpl FNEARN      ; exit if fractional part < 0.5

    eor zpFACCS
    sta zpFACCS     ; change sign of fractional part
    bpl FNEARQ      ; if it's now positive, round down

    inc zpFQUAD     ; round upwards
    jmp FNEARR      ; skip next instruction (could be BIT to save 2 bytes)

FNEARQ:
    dec zpFQUAD     ; round integral part downwards

FNEARR:
    jsr FINEG       ; Negate FACC

FNEARN:
    jmp FNRM        ; normalise and exit, tail call

; ----------------------------------------------------------------------------

; Increment FACC mantissa

FINC:
    inc zpFACCMD
    bne FNEARZ

    inc zpFACCMC
    bne FNEARZ

    inc zpFACCMB
    bne FNEARZ

    inc zpFACCMA
    beq FFIXV       ; overflow, 'Too big' error message

FNEARZ:
    rts

; ----------------------------------------------------------------------------

; Decrement FACC mantissa

FNEARP:
    jsr FINEG   ; negate
    jsr FINC    ; increment
    jmp FINEG   ; negate, tail call

; ----------------------------------------------------------------------------

; Subtraction, FACC = FACC - (ARGP)

FSUB:
    jsr FXSUB   ; FACC = (ARGP) - FACC
    jmp FNEG    ; negate, and exit, tail call

; Exchange FACC and (ARGP)

FSWOP:
    jsr FLDW        ; load FWRK from (ARGP)
    jsr FSTA        ; save FACC to (ARGP)

    ; copy FWRK sign and exponent to FACC

FWTOA:
    lda zpFWRKS
    sta zpFACCS
    lda zpFWRKXH
    sta zpFACCXH
    lda zpFWRKX
    sta zpFACCX

    ; copy FWRK mantissa to FACC

FMWTOA:
    lda zpFWRKMA
    sta zpFACCMA
    lda zpFWRKMB
    sta zpFACCMB
    lda zpFWRKMC
    sta zpFACCMC
    lda zpFWRKMD
    sta zpFACCMD
    lda zpFWRKMG
    sta zpFACCMG

FADDZ:
    rts

; ----------------------------------------------------------------------------

; FACC = (ARGP) - FACC

FXSUB:
    jsr FNEG    ; negate FACC

    ; fallthrough

; FACC = (ARGP) + FACC

FADD:
    jsr FLDW        ; load FWRK from (ARGP)
    beq FADDZ       ; A + 0.0 = A, answer is already in FACC

FADDW:
    jsr FADDW1      ; do the addition
    jmp FTIDY       ; tidy up and exit, tail call

FADDW1:
    jsr FTST        ; see if FACC is 0
    beq FWTOA       ; if so, load FACC with FWRK

    ; Here I have non-trivial add

    ldy #$00        ; Y=0 so we can zero memory locations with sty

    sec
    lda zpFACCX
    sbc zpFWRKX     ; subtract FWRK exponent from FACC exponent
    beq FADDA       ; if zero, no shifts are needed
    bcc FADDB       ; jump if X(FACC) < X(FWRK) (FACC needs shifting)

                    ; FWRK needs shifting

    cmp #$25
    bcs FADDZ       ; jump if shift too large for significance
                    ; basically, FACC + FWRK = FACC

    pha             ; save the difference
    and #$38        ; find out number of bytes to shift (bottom 3 bits ignored)
    beq FADDCA      ; jump if no bytes need to be moved

    lsr             ; divide by 8
    lsr
    lsr
    tax             ; transfer to X as loop counter

FADDCB:
    lda zpFWRKMD    ; shift whole FWRK mantissa one byte to the right (>>8)
    sta zpFWRKMG
    lda zpFWRKMC
    sta zpFWRKMD
    lda zpFWRKMB
    sta zpFWRKMC
    lda zpFWRKMA
    sta zpFWRKMB
    sty zpFWRKMA    ; zero to top byte
    dex
    bne FADDCB      ; loop X number of times

FADDCA:
    pla             ; retreive the difference
    and #$07        ; keep bottom 3 bits (0-7 bits to shift)
    beq FADDA       ; jump if zero shifts are needed

    tax             ; transer to X as loop counter again

FADDC:
    lsr zpFWRKMA    ; shift mantissa of FWRK right (>>1)
    ror zpFWRKMB
    ror zpFWRKMC
    ror zpFWRKMD
    ror zpFWRKMG
    dex
    bne FADDC       ; loop for indicated number of bits
    beq FADDA       ; alligned, skip shifting FACC, branch always

; --------------------------------------

FADDB:
    sec
    lda zpFWRKX
    sbc zpFACCX     ; amount to shift FACC
    cmp #$25
    bcs FWTOA       ; jump if FACC not significant
                    ; basically FACC + FWRK = FWRK

; Now shift FACC right

    pha             ; save difference on the stack
    and #$38        ; same as for FWRK, ignore bottom 3 bits
    beq FADDDA      ; jump if zero byte shifts are to be done

    lsr             ; divide by 8
    lsr
    lsr
    tax             ; into X for loop counter

FADDDB:
    lda zpFACCMD    ; shift mantissa of FACC one byte to the right (>>8)
    sta zpFACCMG
    lda zpFACCMC
    sta zpFACCMD
    lda zpFACCMB
    sta zpFACCMC
    lda zpFACCMA
    sta zpFACCMB
    sty zpFACCMA    ; zero in top byte
    dex
    bne FADDDB      ; loop for X number of bytes

FADDDA:
    pla             ; retrieve difference from stack
    and #$07        ; check bottom 3 bits
    beq FADDAL      ; jump if no more shifts are needed

    tax             ; loop counter again

FADDD:
    lsr zpFACCMA    ; shift FACC mantissa to the right (>>1)
    ror zpFACCMB
    ror zpFACCMC
    ror zpFACCMD
    ror zpFACCMG
    dex
    bne FADDD       ; loop for required number of shifts

FADDAL:
    lda zpFWRKX     ; copy FWRK exponent
    sta zpFACCX     ; to FACC exponent

FADDA:
    lda zpFACCS     ; eor the signs of the two number
    eor zpFWRKS
    bpl FADDE       ; jump if both same sign

    lda zpFACCMA    ; compare mantissas
    cmp zpFWRKMA
    bne FADDF

    lda zpFACCMB
    cmp zpFWRKMB
    bne FADDF

    lda zpFACCMC
    cmp zpFWRKMC
    bne FADDF

    lda zpFACCMD
    cmp zpFWRKMD
    bne FADDF

    lda zpFACCMG
    cmp zpFWRKMG
    bne FADDF

    jmp FCLR        ; mantissas are the same mgnitude, the result is zero, tail

FADDF:
    bcs FADDG       ; jump if abs(FACC) > abs(FWRK)

    ; calculate FAACCM = FWRKM - FACCM

    sec
    lda zpFWRKMG
    sbc zpFACCMG
    sta zpFACCMG
    lda zpFWRKMD
    sbc zpFACCMD
    sta zpFACCMD
    lda zpFWRKMC
    sbc zpFACCMC
    sta zpFACCMC
    lda zpFWRKMB
    sbc zpFACCMB
    sta zpFACCMB
    lda zpFWRKMA
    sbc zpFACCMA
    sta zpFACCMA
    lda zpFWRKS     ; use the sign of FWRK as the sign of the result
    sta zpFACCS

    jmp FNRM        ; normalise, and exit, tail call

FADDE:
    clc             ; numbers are of the same sign,
    jmp FPLWF       ; so add FWRK to FACC, and exit, tail call

    ; calculate FACCM = FACCM - FWRKM

FADDG:
    sec
    lda zpFACCMG
    sbc zpFWRKMG
    sta zpFACCMG
    lda zpFACCMD
    sbc zpFWRKMD
    sta zpFACCMD
    lda zpFACCMC
    sbc zpFWRKMC
    sta zpFACCMC
    lda zpFACCMB
    sbc zpFWRKMB
    sta zpFACCMB
    lda zpFACCMA
    sbc zpFWRKMA
    sta zpFACCMA

    jmp FNRM        ; normalise and exit, tail call

; ----------------------------------------------------------------------------

FMULZ:
    rts

; Multiply, FACC = FACC * (ARGP)

IFMUL:
    jsr FTST        ; check if FACC is zero
    beq FMULZ       ; exit if it is

    jsr FLDW        ; unpack (ARGP) to FWRK
    bne FMULA       ; jump if non-zero, so real work

    jmp FCLR        ; FWRK is zero, so clear FACC, and exit, tail call

; Multiply, FACC = FACC * FWRK, both non-zero

FMULA:
    clc
    lda zpFACCX
    adc zpFWRKX     ; add exponents
    bcc FMULB       ; skip next if no overflow occurred

    inc zpFACCXH    ; increment overflow flag

    ; Subtract $80 bias from exponent, do not check over/underflow yet
    ; in case renormalisation fixes things

    clc

FMULB:
    sbc #$7F        ; carry subtracts extra 1
    sta zpFACCX     ; save as exponent of the result
    bcs FMULC       ; skip next if no underflow occurred

    dec zpFACCXH    ; decrement over/underflow flag

; Copy FACC to FTMP, clear FACC then I can do FACC:=FWRK*FTMP
; as a fixed point operation. FTMP is mantissa only.

FMULC:
    ldx #$05
    ldy #$00        ; to preset FACC to 0.0

FMULD:
    lda zpFACCMA-1,X    ; copy mantissa of FACC
    sta zpFTMPMA-1,X    ; to FTMP
    sty zpFACCMA-1,X    ; and clear FACC
    dex
    bne FMULD

    lda zpFACCS
    eor zpFWRKS
    sta zpFACCS     ; get sign right

; Now for 1:32 do {
;   IF MSB(FTMP)=1 FACC:=FACC+FWRK
;   FTMP:=FTMP<<1
;   FWRK:=FWRK>>1 }

    ldy #$20

FMULE:
    lsr zpFWRKMA    ; shift FWRK mantissa one bit to the right
    ror zpFWRKMB
    ror zpFWRKMC
    ror zpFWRKMD
    ror zpFWRKMG

                    ; FTMPG cannot affect answer

    asl zpFTMPMD    ; shift FTMP mantissa one bit to the left
    rol zpFTMPMC
    rol zpFTMPMB
    rol zpFTMPMA
    bcc FMULF       ; skip addition if carry did not 'fall out'

    clc
    jsr FPLW        ; add FWRK to FACC

FMULF:
    dey
    bne FMULE       ; loop until Y=0

    rts

; --------------------------------------

; FACC = FACC * (ARGP), and check overflow

FMUL:
    jsr IFMUL       ; do the multiplication

NRMTDY:
    jsr FNRM        ; normalise the result

FTIDY:
    lda zpFACCMG
    cmp #$80
    bcc FTRNDZ      ; rounding byte < $80, jump to round to zero
    beq FTRNDA

    lda #$FF
    jsr FPLNF       ; add 0.$ff to mantissa of FACC

    jmp FTRNDZ      ; exit via round to zero (sets rounding byte to zero)

FOVR:
    brk
    dta $14, 'Too big', 0

FTRNDA:
    lda zpFACCMD    ; set least significant bit of the mantissa
    ora #$01
    sta zpFACCMD    ; as a partial rounding operation

FTRNDZ:
    lda #$00        ; set mantissa rounding byte to zero
    sta zpFACCMG

    lda zpFACCXH
    beq FTIDYZ      ; exit if over/underflow byte is zero
    bpl FOVR        ; 'Too big' error message if overflow

    ; otherwise, fallthrough to zero FACC

; ----------------------------------------------------------------------------

; Clear FACC

FCLR:
    lda #$00
    sta zpFACCS
    sta zpFACCXH
    sta zpFACCX
    sta zpFACCMA
    sta zpFACCMB
    sta zpFACCMC
    sta zpFACCMD
    sta zpFACCMG

FTIDYZ:
    rts

; ----------------------------------------------------------------------------

; Set FACC to 1.000

FONE:
    jsr FCLR        ; clear FACC
    ldy #$80
    sty zpFACCMA    ; set mantissa to $80000000
    iny
    sty zpFACCX     ; and exponent to $81
    tya
    rts             ; always return with !Z

; ----------------------------------------------------------------------------

; FACC = 1.0 / FACC

FRECIP:
    jsr STARGA      ; save FACC at workspace temporary FWSA, also sets ARGP
    jsr FONE        ; set FACC to 1.0
    bne FDIV        ; divide, branch always, FONE returns !Z

; ----------------------------------------------------------------------------

; FACC = (ARGP) / FACC

FXDIV:
    jsr FTST        ; test FACC
    beq FDIVZ       ; if zero, divide by zero error

    jsr FTOW        ; copy FACC to FWRK
    jsr FLDA        ; load FACC from (ARGP)
    bne FDIVA       ; if not zero, jump to divide

    rts             ; 0/x is always zero

FDIVZ:
    jmp ZDIVOR      ; Divide by zero error

; ----------------------------------------------------------------------------

; =TAN numeric
; ============

; FTAN works as FSIN(X)/FCOS(X)

TAN:
    jsr FLTFAC      ; get operand, ensure it's a floating point value
    jsr FRANGE      ; compute the quadrant of the angle

    lda zpFQUAD
    pha             ; save the quadrant on the stack

    jsr ARGD        ; set ARGP to point to FWSD
    jsr FSTA        ; store FACC at (ARGP)

    ; the FSC function is common to sine and cosine, just a quadrant apart

    inc zpFQUAD     ; increase quadrant for cosine

    jsr FSC         ; calculate cosine
    jsr ARGD        ; set ARGP to point to FWSD
    jsr FSWOP       ; swap FACC with (ARGP)

    pla             ; retrieve quadrant
    sta zpFQUAD     ; and store

    jsr FSC         ; calculate sine
    jsr ARGD        ; set ARGP to point to FWSD
    jsr FDIV        ; FACC = FACC / (ARGP)  ; sin(x)/cos(x)

    lda #$FF        ; indicate it's a floating point number
    rts

; ----------------------------------------------------------------------------

FDIV:
    jsr FTST        ; test FACC
    beq FTIDYZ      ; 0.0/anything = 0.0 (including 0.0/0.0)

    jsr FLDW        ; load FWRK from (ARGP)
    beq FDIVZ       ; if it's zero, error 'Divide by zero'

FDIVA:
    lda zpFACCS     ; eor the signs to get the sign of the result
    eor zpFWRKS
    sta zpFACCS

    sec
    lda zpFACCX
    sbc zpFWRKX     ; difference of exponents
    bcs FDIVB       ; jump if no underflow

    dec zpFACCXH    ; adjust underflow
    sec

FDIVB:
    adc #$80        ; $81 because carry is set
    sta zpFACCX     ; store as exponent of the answer
    bcc FDIVC       ; jump if no overflow

    inc zpFACCXH    ; adjust overflow flag
    clc

FDIVC:
    ldx #$20        ; loop counter

FDIVE:
    bcs FDIVH       ; skip test if previous shift set the carry flag

    lda zpFACCMA
    cmp zpFWRKMA
    bne FDIVF       ; not equal, test <

    lda zpFACCMB
    cmp zpFWRKMB
    bne FDIVF       ; not equal, test <

    lda zpFACCMC
    cmp zpFWRKMC
    bne FDIVF       ; not equal, test <

    lda zpFACCMD
    cmp zpFWRKMD

FDIVF:
    bcc FDIVG       ; skip subtraction if FACCM < FWRKM

; Calculate FACCM = FACCM - FWRKM, carry already set for sbc

FDIVH:
    lda zpFACCMD
    sbc zpFWRKMD
    sta zpFACCMD
    lda zpFACCMC
    sbc zpFWRKMC
    sta zpFACCMC
    lda zpFACCMB
    sbc zpFWRKMB
    sta zpFACCMB
    lda zpFACCMA
    sbc zpFWRKMA
    sta zpFACCMA

    sec             ; C=1, subtraction tookplace

FDIVG:
    rol zpFTMPMD    ; shift carry into FTMPM
    rol zpFTMPMC
    rol zpFTMPMB
    rol zpFTMPMA

    asl zpFACCMD    ; multiply FACM by two, shift left
    rol zpFACCMC
    rol zpFACCMB
    rol zpFACCMA

    dex
    bne FDIVE       ; loop as often as necessary

; Here, the same process is repeated, except the rounding byte is used

    ldx #$07        ; 7 iterations required (7 guard bits)

FDIVJ:
    bcs FDIVL       ; skip the comparison if the previous shift generated carry

    lda zpFACCMA    ; compare FACCM to FWRKM
    cmp zpFWRKMA
    bne FDIVK       ; not equal, test <

    lda zpFACCMB
    cmp zpFWRKMB
    bne FDIVK       ; not equal, test <

    lda zpFACCMC
    cmp zpFWRKMC
    bne FDIVK       ; not equal, test <

    lda zpFACCMD
    cmp zpFWRKMD
FDIVK:
    bcc FDIVM       ; skip subtraction if FACCM < FWRKM

    ; carry always set (fallthrough, or came via bcs FDIVL)

    ; calculate FACCM = FACCM - FWRKM

FDIVL:
    lda zpFACCMD
    sbc zpFWRKMD
    sta zpFACCMD
    lda zpFACCMC
    sbc zpFWRKMC
    sta zpFACCMC
    lda zpFACCMB
    sbc zpFWRKMB
    sta zpFACCMB
    lda zpFACCMA
    sbc zpFWRKMA
    sta zpFACCMA

    sec             ; subtraction took place

FDIVM:
    rol zpFACCMG    ; shift carry flag into mantissa via rounding byte
    asl zpFACCMD
    rol zpFACCMC
    rol zpFACCMB
    rol zpFACCMA
    dex
    bne FDIVJ       ; loop for as many times as necessary

    ; since only seven iterations were performed, this instruction is
    ; needed to line the rounding byte up

    asl zpFACCMG    ; shift left once

    lda zpFTMPMD    ; transfer result from FTMPM to FACCM
    sta zpFACCMD
    lda zpFTMPMC
    sta zpFACCMC
    lda zpFTMPMB
    sta zpFACCMB
    lda zpFTMPMA
    sta zpFACCMA

    jmp NRMTDY      ; normalize, and tidy up, tail call

; ----------------------------------------------------------------------------

; Read -ve as negative

FSQRTE:
    brk
    dta $15, '-ve root', 0

; =SQR numeric
; ============

; Newton method: SQR(n): x[i+1] = 0.5 * (x[i] + N / x[i])

SQR:
    jsr FLTFAC      ; evaluate operand, ensure it's floating point

FSQRT:
    jsr FTST        ; set flags
    beq FSQRTZ      ; exit if zero, sqr(0) is easy
    bmi FSQRTE      ; argument is negative, jump to '-ve root'

    jsr STARGA      ; store FACC at temporary workspace FWSA

    lda zpFACCX
    lsr             ; halve the exponent of the number
    adc #$40        ; and add $40
    sta zpFACCX     ; store, new number is first approximation

    lda #$05        ; loop 5 times
    sta zpFRDDW

    jsr ARGB        ; set ARGP to point to FWSB

FSQRTA:
    jsr FSTA        ; store FACC at (ARGP) --> FWSB

    lda #<FWSA
    sta zpARGP      ; set ARGP to point to FWSA (value of n)
    jsr FXDIV       ; FACC = (ARGP) / FACC --> n / x[i]

    lda #<FWSB
    sta zpARGP      ; set ARGP to point to FWSB (x[i])
    jsr FADD        ; FACC = FACC + (ARGP) --> x[i] + n / x[i]

    dec zpFACCX     ; divide by 2 by decreasing exponent (*0.5)
    dec zpFRDDW     ; decrement counter
    bne FSQRTA      ; loop required times

FSQRTZ:
    lda #$FF        ; return type is floating point
    rts

; ----------------------------------------------------------------------------

; Point zpARGP to a workspace floating point temps
; ------------------------------------------------

ARGD:
    lda #<FWSD
    bne ARGCOM

ARGB:
    lda #<FWSB
    bne ARGCOM

ARGC:
    lda #<FWSC
    bne ARGCOM

ARGA:
    lda #<FWSA


ARGCOM:
    sta zpARGP
    lda #>FWSD          ; MSB the same for all four temp registers
    sta zpARGP+1
    rts

; ----------------------------------------------------------------------------

; FLOG sets FACC= LOG(FACC) (base e)
; works by
; (A) Check for acc <= 0.0
; (B) Strip exponent to put FACC in range 1.0 - 2.0
;     and renormalize to .707 TO 1.414
; (B2) Extra care with smallest possible exponent
; (C) Approximate log using (x-1)+(x-1)^2*cf(x-1)
;     where cf is a minimax continued fraction
; (D) Add result to exponent * LOG(2.0)
; N.B. Result can not overflow so no worry there.
; The series approximation used for LOGs is a continued
; fraction: F(X)=C(0)+X/(C(1)+X/(...

; =LN numeric
; ===========

LN:
    jsr FLTFAC  ; evaluate argument, ensure it's floating point

FLOG:
    jsr FTST    ; test and set flags
    beq FLOGA   ; LOG(0) is illegal
    bpl FLOGB   ; LOG(>0.0) is OK

    ; error when argument is negative or zero

FLOGA:
    brk
    dta $16, 'Log range', 0         ; xxx: tknLOG ?

FLOGB:
    jsr FCLRW       ; clear FWRK

    ldy #$80        ; set FWRK to -1.0
    sty zpFWRKS
    sty zpFWRKMA
    iny
    sty zpFWRKX

    ldx zpFACCX     ; skip mantissa test if exponent of argument is zero
    beq FLOGC

    lda zpFACCMA    ; check if mantissa < $b5000000
    cmp #$B5
    bcc FLOGD

FLOGC:
    inx             ; increment exponent in X
    dey             ; decrement Y (Y=$80)

FLOGD:
    txa
    pha             ; save exponent on stack

    sty zpFACCX     ; set exponent of result (strip exponent)
    jsr FADDW       ; calculate FACC = FACC + FWRK

    lda #<FWSD
    jsr FSTAP       ; store FACC in FWSD (workspace temporary)

    lda #<FLOGTC    ; set YA to point to FLOGTC table for continued fraction
    ldy #>FLOGTC
    jsr FCF         ; evaluate continued fraction
    jsr ARGD        ; make ARGP point to FWSD
    jsr FMUL        ; FACC = FACC * (ARGP)
    jsr FMUL        ; FACC = FACC * (ARGP)
    jsr FADD        ; FACC = FACC + (ARGP)
    jsr STARGA      ; save partial result in FWSA

    pla             ; recover exponent byte

    sec
    sbc #$81        ; subtract bias
    jsr FLTACC      ; turn A into float in FACC

    lda #<LOGTWO
    sta zpARGP
    lda #>LOGTWO
    sta zpARGP+1

    jsr FMUL        ; calculate FACC = FACC * LOGTWO
    jsr ARGA        ; make ARGP point to FWSA
    jsr FADD        ; FACC = FACC + (ARGP)

    lda #$FF        ; result is a floating point value
    rts

LOGTWO:
    dta $80, $31, $72, $17, $f8         ; LN(2.0)

FLOGTC:
    dta $06                             ; length -1
    dta $7a, $12, $38, $a5, $0b         ; 0.0089246379611723
    dta $88, $79, $0e, $9f, $f3         ; 249.0571281313896179
    dta $7c, $2a, $ac, $3f, $b5         ; 0.0416681755596073
    dta $86, $34, $01, $a2, $7a         ; 45.0015963613986969
    dta $7f, $63, $8e, $37, $ec         ; 0.4444444156251848
    dta $82, $3f, $ff, $ff, $c1         ; 2.9999999413266778
    dta $7f, $ff, $ff, $ff, $ff         ; -0.4999999998835847

    .if .hi(*) != .hi(FLOGTC)
        .error "Table FLOGTC crosses page!"
    .endif

; ----------------------------------------------------------------------------

; FCF - Evaluates a rational function of the form
;       A0 + X/(A1+X/(A2+X/ ...
;       i.e. a continued fraction.
;       It takes a table of the form:
;       <BYTE N> <AN> ... <A0>
;       where AN through A0 are floating point values.
;       Sam demands that no table cross a page!
;
; Note that the tables are in reverse order. The formula is evaluated
; from right to left.

FCF:
    sta zpCOEFP         ; store pointer to coefficients
    sty zpCOEFP+1
    jsr STARGA          ; save FACC (X value in formula) to FWSA

    ldy #$00
    lda (zpCOEFP),Y     ; length of series - always downstairs
    sta zpFRDDDP        ; store as counter

    inc zpCOEFP         ; point to next byte, start of first constant
    bne FCFA

    inc zpCOEFP+1

FCFA:
    lda zpCOEFP         ; copy COEFP to ARGP
    sta zpARGP
    lda zpCOEFP+1
    sta zpARGP+1

    jsr FLDA            ; load FACC with constant at (ARGP)

FCFLP:
    jsr ARGA            ; make ARGP point to FWSA (value of X in formula)
    jsr FXDIV           ; calculate FACC = (ARGP) / FACC

    clc
    lda zpCOEFP         ; move COEFP pointer to next floating point value
    adc #$05            ; size of float is 5 bytes
    sta zpCOEFP
    sta zpARGP
    lda zpCOEFP+1
    adc #$00
    sta zpCOEFP+1
    sta zpARGP+1

    jsr FADD            ; FACC = FACC + (ARGP)

    dec zpFRDDDP        ; decrement counter
    bne FCFLP           ; and loop if necessary

    rts

; ----------------------------------------------------------------------------

; =ACS numeric
; ============

ACS:
    jsr ASN         ; calculate ASN
    jmp PISUB       ; subtract PI/2

; ----------------------------------------------------------------------------

; =ASN numeric
; ============

; Calculates by ASN(x) = ATN(x/SQR(x^2+1))

ASN:
    jsr FLTFAC      ; evaluate the operand, and make sure it's floating point
    jsr FTST        ; test, and set flags
    bpl ASNA        ; jump if operand is positive

    lsr zpFACCS     ; clear sign bit. cleverly with one instruction
    jsr ASNA        ; call positive code
    jmp SETNEG      ; make negative, and exit, tail call

ASNA:               ; operand is positive
    jsr STARGC      ; store FACC at FWSC
    jsr SQRONE      ; calculate SQR(FACC^2-1)
    jsr FTST        ; test, and set flags
    beq ASINAA      ; skip if result is zero

    jsr ARGC        ; make ARGP point to FWSC
    jsr FXDIV       ; calculate (ARGP) / FACC
    jmp FATAN       ; take ATN of result, and exit, tail call

ASINAA:
    jsr ARGHPI      ; make ARGP point to PI/2
    jsr FLDA        ; load into FACC

FATANZ:
    lda #$FF        ; indicate that result is floating point
    rts

; ----------------------------------------------------------------------------

;   FATAN computes arctangent
;   Method:
;   (A) ATAN(-X) = - ATAN(X)
;   (B) IF X>1.0 use
;       ATAN(X)=PI/2 - ATAN(1/X)
;   (C0) IF X<0.0001 result is X
;     ELSE ...
;   (C1) LET Y=(X-0.5), so Y is in range -0.5 TO 0.5
;   (D) Compute series in Y so that it gives ATAN(X)/X
;   (E) Multiply by X to get result
;   (F) (Put back PI/2 and '-')

; =ATN numeric
; ============

ATN:
    jsr FLTFAC      ; evaluate operand, make sure it's floating point

FATAN:
    jsr FTST        ; test and set flags
    beq FATANZ      ; if zero, return zero
    bpl FATANA      ; positive, do ATAN(x)

    lsr zpFACCS     ; force +ve
    jsr FATANA      ; ATAN(-x)

SETNEG:
    lda #$80
    sta zpFACCS     ; negate at end
    rts

FATANA:
    lda zpFACCX
    cmp #$81        ; is FACC >= 1.0 ?
    bcc FATANB      ; jump if it isn't

    jsr FRECIP      ; calcualte FACC = 1.0/FACC
    jsr FATANB      ; ATAN(1/X), call code for X < 1

PISUB:
    jsr AHPIHI
    jsr FADD        ; add -PI/2
    jsr AHPILO
    jsr FADD        ; in two steps for enhanced precission
    jmp FNEG        ; negate, and exit, tail call

FATANB:
    lda zpFACCX
    cmp #$73
    bcc FATANZ      ; very small number, return zero, and exit

    jsr STARGC      ; save FACC at FWSC
    jsr FCLRW       ; clear FWRK

    lda #$80
    sta zpFWRKX
    sta zpFWRKMA
    sta zpFWRKS

    jsr FADDW       ; W = -0.5

; Now FACC is in (-0.5,0.5)

    lda #<FATANC
    ldy #>FATANC
    jsr FCF         ; sum magic series
    jsr ACMUL       ; multiply by arg, exit

    lda #$FF
    rts

FATANC:
    dta $09                             ; length -1
    dta $85, $a3, $59, $e8, $67         ; -20.4189003035426140
    dta $80, $1c, $9d, $07, $36         ; 0.6117710596881807
    dta $80, $57, $bb, $78, $df         ; 0.8427043480332941
    dta $80, $ca, $9a, $0e, $83         ; -0.7914132184814662
    dta $84, $8c, $bb, $ca, $6e         ; -8.7958473488688469
    dta $81, $95, $96, $06, $de         ; -1.1686409553512931
    dta $81, $0a, $c7, $6c, $52         ; 1.0842109108343720
    dta $7f, $7d, $ad, $90, $a1         ; 0.4954648205311969
    dta $82, $fb, $62, $57, $2f         ; -3.9278772315010428
    dta $80, $6d, $63, $38, $2c         ; 0.9272952182218432

    .if .hi(*) != .hi(FATANC)
        .error "Table FATANC crosses page!"
    .endif

; ----------------------------------------------------------------------------

; =COS numeric
; ============

COS:
    jsr FLTFAC      ; evaluate float argument
    jsr FRANGE      ; reduce to < PI/2, compute quadrant
    inc zpFQUAD     ; increment quadrant counter (offset to SIN)
    jmp FSC         ; common code SIN/COS

; =SIN numeric
; ============

SIN:
    jsr FLTFAC      ; evaluate argument and ensure it's floating point
    jsr FRANGE      ; compute the quadrant of the angle

FSC:
    lda zpFQUAD     ; check quadrant if result needs to be negated
    and #$02        ; quadrants 4-7
    beq FSCA        ; jump if no negation is necessary

    jsr FSCA        ; calculate sine
    jmp FNEG        ; negate, and exit, tail call

FSCA:
    lsr zpFQUAD     ; check quadrant
    bcc FSCB        ; jump if 1st or 2nd (+ve)

    jsr FSCB

SQRONE:             ; SQR(FACC^2-1)
    jsr STARGA      ; store FACC at FWSA
    jsr FMUL        ; calculate FACC = FACC * FWSA  ; = FACC^2
    jsr FSTA        ; store FACC at FWSA
    jsr FONE        ; set FACC to 1.0
    jsr FSUB        ; calculate FACC = FWSA - FACC
    jmp FSQRT       ; calculate SQR(FACC), and exit, tail call

FSCB:
    jsr STARGC      ; store FACC at FWSC
    jsr FMUL        ; calculate FACC = FACC * FWSC  ; = FACC^2
    lda #<FSINC
    ldy #>FSINC
    jsr FCF         ; evaluate approximation (sin(x)/x)
    jmp ACMUL       ; multiply by FWSC, and exit, tail call

; ----------------------------------------------------------------------------

; FRANGE subtracts an integral multiple of PI/2 from FACC,
; and sets FQUAD to indicate (MOD 4, at least) what the
; integer was. Note that the subtraction is done with a
; certain degree of care so that large arguments still give
; decent accuracy.

FRANGE:
    lda zpFACCX
    cmp #$98
    bcs FRNGQQ      ; argument too big, error 'Accuracy lost'

    jsr STARGA      ; save FACC at FWSA
    jsr ARGHPI      ; set ARGP to PI/2
    jsr FLDW        ; load FWRK from (ARGP)

    lda zpFACCS     ; copy sign of FACC to FWRK
    sta zpFWRKS
    dec zpFWRKX     ; decrement exponent --> FWRK = PI/4*SGN(FACC)

    jsr FADDW       ; FACC = FACC + FWRK
    jsr FDIV        ; FACC = FACC / (ARGP)      ; FACC /(PI/2)

; Note that the above division only has to get its result about right to
; the nearest integer.

    jsr FFIX        ; fix to integer

    lda zpFACCMD    ; save least significant byte as quadrant
    sta zpFQUAD
    ora zpFACCMC
    ora zpFACCMB
    ora zpFACCMA
    beq FRNGD       ; if mantissa is zero, FIX(A/(PI/2))=0

    lda #$A0        ; set exponent to $a0
    sta zpFACCX
    ldy #$00        ; clear rounding byte
    sty zpFACCMG
    lda zpFACCMA    ; move sign into the sign byte
    sta zpFACCS
    bpl FFLOTA      ; skip next if positive

    jsr FINEG       ; negate the mantissa if needed

FFLOTA:
    jsr FNRM        ; normalise the result
    jsr STARGB      ; store FACC in FWSB
    jsr AHPIHI      ; make ARGP point to -PI/2 (almost)
    jsr FMUL        ; FACC = FACC * (ARGP), and check overflow
    jsr ARGA        ; make ARGP point to FWSA
    jsr FADD        ; FACC = FACC + (ARGP)
    jsr FSTA        ; store FACC in FWSA
    jsr ARGB        ; set ARGP to FWSB
    jsr FLDA        ; unpack (ARGP) to FACC
    jsr AHPILO      ; make ARGP point to -PI/2 (residue, almost zero)
    jsr FMUL        ; FACC = FACC * (ARGP)
    jsr ARGA        ; set ARGP to FWSA again
    jmp FADD        ; and add to FACC, exit, tail call

FRNGD:
    jmp LDARGA      ; copy (ARGP) to FACC = PI/2

; ----------------------------------------------------------------------------

FRNGQQ:
    brk
    dta $17, 'Accuracy lost', 0

; ----------------------------------------------------------------------------

; Set ARGP to HPIHI

AHPIHI:
    lda #<HPIHI
    .if (HPIHI & 0xff) == 0
        .error "BNE as BRA will not be taken!"
    .endif
    bne SETARGP

; Set ARGP to HPILO

AHPILO:
    lda #<HPILO

SETARGP:
    sta zpARGP
    lda #>HPIHI     ; shared MSB between them, hence the possible error below
    sta zpARGP+1
    rts

; Set ARGP to HALFPI

ARGHPI:
    lda #<HALFPI
    .if (HALFPI & 0xff) == 0
        .error "BNE as BRA will not be taken!"
    .endif
    bne SETARGP

    .if (>HALFPI) != (>HPIHI)
        .error "HPIHI and HALFPI are not on the same page"
    .endif

; ----------------------------------------------------------------------------

; HPIHI + HPILO = -PI/2
; Done this way for accuracy to 1.5 precision approx.

HPIHI:
    dta $81, $c9, $10, $00, $00     ; -1.5708007812500000
HPILO:
    dta $6f, $15, $77, $7a, $61     ; 0.0000044544551105
HALFPI:
    dta $81, $49, $0f, $da, $a2     ; 1.5707963267341256
FPIs18:
    dta $7b, $0e, $fa, $35, $12     ; 0.0174532925157109 = PI/180 (1° in in rad)
F180sP:
    dta $86, $65, $2e, $e0, $d3     ; 57.2957795113325119 = 180/PI (1 rad in °)
RPLN10:
    dta $7f, $5e, $5b, $d8, $aa     ; 0.4342944819945842 = LOG10(e)

    .if .hi(*) != .hi(HPIHI)
        .error "PI table crosses page!"
    .endif

; ----------------------------------------------------------------------------

FSINC:
    dta $05                             ; length -1
    dta $84, $8a, $ea, $0c, $1b         ; -8.6821404509246349
    dta $84, $1a, $be, $bb, $2b         ; 9.6715652160346508
    dta $84, $37, $45, $55, $ab         ; 11.4544274024665356
    dta $82, $d5, $55, $57, $7c         ; -3.3333338461816311
    dta $83, $c0, $00, $00, $05         ; -6.0000000093132257
    dta $81, $00, $00, $00, $00         ; 1.0000000000000000

    .if .hi(*) != .hi(FSINC)
        .error "Table FSINC crosses page!"
    .endif

; ----------------------------------------------------------------------------

; FEXP algorithm:
; (A) If ABS(ARG) > 89.5 (Approx.) THEN GIVE UNDER/OVERFLOW.
; (B) LET P=nearest integer to ARG, and F be residue.
;   (If ABS(X)<0.5 to start with compute this quickly)
; (C) Compute EXP(P) as power of e=2.71828...
; (D) Note ABS(F)<=0.5, compute EXP(F) by continued fraction
; (E) Combine partial results

; = EXP numeric
; =============

EXP:
    jsr FLTFAC      ; evaluate argument, make sure it's floating point

FEXP:
    lda zpFACCX     ; check if it's in range
    cmp #$87
    bcc FEXPA       ; jump if certainly in range
    bne FEXPB       ; jump if certainly not

    ldy zpFACCMA    ; check MSB of mantissa
    cpy #$B3
    bcc FEXPA       ; in range, at least nearly

FEXPB:
    lda zpFACCS
    bpl FEXPC       ; overflow case

    jsr FCLR        ; clear FACC, return 0

    lda #$FF        ; indicate it's a floating point value
    rts

FEXPC:
    brk
    dta $18, 'Exp range', 0     ; xxx: tknEXP

FEXPA:
    jsr FFRAC       ; get fractional part, leave integer part in FQUAD
    jsr FEXPS       ; EXP(fraction), calculate continued fraction
    jsr STARGC      ; save it away at FWSC

    lda #<FNUME     ; set ARGP to point to FNUME (the constant 'e')
    sta zpARGP
    lda #>FNUME
    sta zpARGP+1
    jsr FLDA        ; load value into FACC

    lda zpFQUAD     ; get integral part
    jsr FIPOW       ; calcualte e^N

ACMUL:
    jsr ARGC        ; make ARGP point to FWSC where we stored fractional result
    jsr FMUL        ; multiply, FACC = FACC * (ARGP)

    lda #$FF        ; indicate result is floating point
    rts

FEXPS:
    lda #<FEXPCO
    ldy #>FEXPCO
    jsr FCF         ; sum continued fraction

    lda #$FF
    rts

FNUME:
    dta $82, $2d, $f8, $54, $58         ; 2.7182818278670311 = e

FEXPCO:
    dta $07                             ; length -1
    dta $83, $e0, $20, $86, $5b         ; -7.0039703156799078
    dta $82, $80, $53, $93, $b8         ; -2.0051011368632317
    dta $83, $20, $00, $06, $a1         ; 5.0000031609088182
    dta $82, $00, $00, $21, $63         ; 2.0000079600140452
    dta $82, $c0, $00, $00, $02         ; -3.0000000018626451
    dta $82, $80, $00, $00, $0c         ; -2.0000000111758709
    dta $81, $00, $00, $00, $00         ; 1.0000000000000000
    dta $81, $00, $00, $00, $00         ; 1.0000000000000000

; Later versions of BBC BASIC enforce this, but it fails for BASIC II/III
;    .if .hi(*) != .hi(FEXPCO)
;        .error "Table FEXPCO crosses page!"
;    .endif

; ----------------------------------------------------------------------------

; FIPOW - Computes X**N where X is passed in FP Accu, N is a one byte
;         signed integer passed in A

FIPOW:
    tax
    bpl FIPOWA      ; jump if positive

    dex             ; minus 1
    txa
    eor #$FF        ; complement = two's complement
    pha             ; save exponent on stack

    jsr FRECIP      ; FACC = 1 / FACC

    pla             ; recover exponent

FIPOWA:
    pha             ; save exponent

    jsr STARGA      ; store FACC at FWSA, set ARGP to point to FWSA
    jsr FONE        ; set FACC to 1, which results in X**1 = X

FIPOWB:
    pla             ; retrieve exponent
    beq FIPOWZ      ; exit if power is zero, return 1.0, or result of loop(s)

    sec             ; subtract 1
    sbc #$01
    pha             ; and push back to stack

    jsr FMUL        ; FACC = FACC * (ARGP)
    jmp FIPOWB      ; keep repeating

FIPOWZ:
    rts

; ----------------------------------------------------------------------------

; =ADVAL numeric - Call OSBYTE to read buffer/device
; ==================================================

ADVAL:
    jsr INTFAC        ; Evaluate integer
    ldx zpIACC        ; X=low byte of IACC
    lda #$80          ; A=$80 for ADVAL

    .if .def MOS_BBC
        .if .def TARGET_C64
            jsr C64_XY_OSBYTE
        .else
            jsr OSBYTE
        .endif
    .endif
    txa
    jmp AYACC

; ----------------------------------------------------------------------------

; =NOT
; ====

NOT:
    jsr INTFAC      ; evaluate expression, ensure it's integer

    ldx #$03        ; loop 3..0

NOTLOP:
    lda zpIACC,X    ; invert IACC
    eor #$FF
    sta zpIACC,X
    dex
    bpl NOTLOP

    lda #$40        ; return type is integer
    rts

; ----------------------------------------------------------------------------

; =POS
; ====
POS:
    jsr VPOS            ; do OSBYTE $86, preserves X
    stx zpIACC          ; store X position in IACC
                            ; A = $40 already set by VPOS calling SINSTK
    rts

; ----------------------------------------------------------------------------

; =VPOS
; =====
VPOS:
    lda #$86        ; get cursor position in X and Y
    jsr OSBYTE
    tya
    jmp SINSTK      ; put A into IACC, preserves X, exit, tail call

; ----------------------------------------------------------------------------

; =LOG numeric
; ============

LOG:
    jsr LN              ; evaluate natural logarithm
    ldy #<RPLN10        ; set YA to constant
    .error <RPLN10 == 0
    bne CX              ; branch always, check during assembly

; ----------------------------------------------------------------------------

; =RAD numeric
; ============

RAD:
    jsr FLTFAC          ; evaluate expression, ensure it's floating point
    ldy #<FPIs18        ; set YA to constant factor

CX:
    lda #>FPIs18        ; share setting MSB, see checks during assembly below
    sty zpARGP
    sta zpARGP+1
    jsr FMUL            ; multiply, FACC = FACC * (ARGP)

    lda #$FF
    rts

    .if (>FPIs18) != (>RPLN10) || (>FPIs18) != (>F180sP)
        .error "MSB of FPIs18, F180sP, and RPLN10 must be equal"
    .endif

; ----------------------------------------------------------------------------

; =DEG numeric
; ============

DEG:
    jsr FLTFAC          ; evaluate expression, ensure it's floating point
    ldy #<F180sP        ; set YA to constant factor
    .error  <F180sP == 0
    bne CX               ; branch always, check during assembly

; ----------------------------------------------------------------------------

; =PI
; ===

PI:
    jsr ASINAA          ; get value of PI/2 in FACC
    inc zpFACCX         ; multiply by 2 by incrementing the exponent
    tay                 ; repeat setting of flags (instead of lda #$ff)
    rts

; ----------------------------------------------------------------------------

; =USR numeric
; ============

USR:
    jsr INTFAC          ; Evaluate integer
    jsr USER            ; Set up registers and call code at IACC
    sta zpIACC          ; Store returned A,X,Y in IACC
    stx zpIACC+1
    sty zpIACC+2

    php
    pla
    sta zpIACC+3        ; Store returned flags in IACC
    cld                 ; Ensure in binary mode on return

    lda #$40            ; indicate return type is integer
    rts

; ----------------------------------------------------------------------------

; =EVAL string$ - Tokenise and evaluate expression
; ================================================

EVAL:
    jsr FACTOR              ; Evaluate value
    bne EVALE               ; 'Type mismatch' error

    inc zpCLEN
    ldy zpCLEN        ; Increment string length to add a <cr>
    lda #$0D
    sta STRACC-1,Y    ; Put in terminating <cr>

    jsr PHSTR         ; Stack the string
                      ; String has to be stacked as otherwise would
                      ; be overwritten by any string operations
                      ; called by Evaluator
    lda zpAELINE
    pha               ; Save AELINE pointer on machine stack
    lda zpAELINE+1
    pha
    lda zpAECUR
    pha               ; including its cursor offset

    ldy zpAESTKP
    ldx zpAESTKP+1    ; XY = stackbottom
    iny               ; Step over length byte
    sty zpAELINE      ; AELINE => stacked string
    sty zpWORK        ; WORK => stacked string
    bne EVALX         ; skip if MSB does not needs to be adjusted

    inx               ; adjust MSB

EVALX:
    stx zpAELINE+1     ; store AELINE and WORK high bytes
    stx zpWORK+1

    ldy #$FF
    sty zpWORK+4       ; set tokenising flag to indicate not start of statement
    iny                ; Y=0
    sty zpAECUR        ; Point AELINE offset back to start of string

    jsr MATCEV         ; Tokenise string on stack
    jsr EXPR           ; Call expression evaluator
    jsr POPSTX         ; Drop string from stack

VALOUT:
    pla
    sta zpAECUR        ; Restore AELINE from machine stack
    pla
    sta zpAELINE+1
    pla
    sta zpAELINE
    lda zpTYPE         ; Get expression return value type
    rts                ; And return

EVALE:
    jmp LETM           ; 'Type mismatch' error

; ----------------------------------------------------------------------------

; =VAL numeric
; ============

VAL:
    jsr FACTOR          ; evaluate argument
    bne EVALE           ; 'Type mismatch' error

VALSTR:
    ldy zpCLEN          ; add zero to the end of the string
    lda #$00
    sta STRACC,Y

    lda zpAELINE        ; save AELINE on machine stack
    pha
    lda zpAELINE+1
    pha
    lda zpAECUR         ; and its cursor offset position
    pha

    lda #$00
    sta zpAECUR         ; reset cursor to 0

    sta zpAELINE        ; set AELINE to point to the beginning of STRACC
    lda #>STRACC
    sta zpAELINE+1

    jsr AESPAC          ; skip spaces, and get next character

    cmp #'-'
    beq VALMIN          ; jump is negative value

    cmp #'+'
    bne VALNUB          ; jump if not a '+' sign

    jsr AESPAC          ; skip '+' and optional spaces, get next character

VALNUB:
    dec zpAECUR         ; one position backwards, because next character has
                        ; been read already

    jsr FRDD            ; get decimal number from AELINE

    jmp VALTOG          ; exit via end of EVAL routine, tail call

VALMIN:
    jsr AESPAC          ; skip spaces, and get next character

    dec zpAECUR         ; one position backwards, point to current character
    jsr FRDD            ; get decimal number from AELINE

    bcc VALTOG          ; exit via end of EVAL routine to restore AELINE/CUR

    jsr VALCMP          ; negate value via unary minus code

VALTOG:
    sta zpTYPE          ; store the type
    jmp VALOUT          ; exit, restore AELINE/CUR, tail call

; ----------------------------------------------------------------------------

; =INT numeric
; ============
INT:
    jsr FACTOR              ; evaluate argument

    beq FACTE               ; 'Type mismatch' error

    bpl INTX                ; exit if it's already an integer ($40)

    lda zpFACCS             ; save the sign of FACC
    php

    jsr FFIX                ; fix into an integer

    plp                     ; get flags (sign bit)
    bpl INTF                ; jump if positive

    lda zpFWRKMA
    ora zpFWRKMB
    ora zpFWRKMC
    ora zpFWRKMD
    beq INTF                ; jump if negative, but fractional part is zero

    jsr FNEARP              ; otherwise, decrement FACC mantissa
                            ; INT(-7.9) is rounded down to -8

INTF:
    jsr COPY_FACC_TO_IACC   ; what the function name says :)

    lda #$40                ; indicate return type is integer

INTX:
    rts

; ----------------------------------------------------------------------------

; =ASC string$
; ============

ASC:
    jsr FACTOR              ; evaluate argument
    bne FACTE               ; 'Type mismatch' error if it's not a string

    lda zpCLEN
    beq TRUE                ; return -1 in IACC if string length is 0

    lda STRACC              ; get first character of string

ASCX:
    jmp SINSTK              ; put A in IACC, and exit, tail call

; ----------------------------------------------------------------------------

; =INKEY numeric
; ==============

INKEY:
    jsr INKEA               ; call INKEY master routine
    tya                     ; faster way to set flags on Y, but clobbers A
    bne TRUE                ; return -1 in IACC if no character was recorded

    txa                     ; move character from X to A
    jmp AYACC               ; place A in IACC, and exit, tail call

FACTE:
    jmp LETM                ; 'Type mismatch' error

; ----------------------------------------------------------------------------

; =EOF#numeric
; ============

EOF:
    jsr CHANN               ; evaluate the handle of the file
    tax
    lda #$7F
    .ifdef MOS_BBC
        jsr OSBYTE
    .endif
    txa
    beq TRUTWO          ; return 0 in IACC if not EOF (32-bit int)

    ; fallthrough, return -1 in IACC if EOF

; ----------------------------------------------------------------------------

; =TRUE
; =====
TRUE:
    ldx #$FF                ; set fill value in X

TRUTWO:
    stx zpIACC          ; fill IACC with X
    stx zpIACC+1
    stx zpIACC+2
    stx zpIACC+3

SGNINT:
    lda #$40        ; return type is integer
    rts

; ----------------------------------------------------------------------------

; =FALSE
; ======

FALSE:
    ldx #$00
    beq TRUTWO       ; branch always, fill IACC with 0, and exit

; ----------------------------------------------------------------------------

SGNFLT:
    jsr FTST        ; test the floating point argument, set flags
    beq FALSE       ; return 0 in IACC
    bpl SGNPOS      ; return 1 in IACC
    bmi TRUE        ; return -1 in IACC

; =SGN numeric
; ============

SGN:
    jsr FACTOR      ; evaluate expression, 
    beq FACTE       ; 'Type mismatch' error if it's a string
    bmi SGNFLT      ; jump if it's a float

    lda zpIACC+3
    ora zpIACC+2
    ora zpIACC+1
    ora zpIACC
    beq SGNINT      ; if zero, return zero, exit

    lda zpIACC+3
    bmi TRUE        ; if negative, return -1 in IACC, and exit

SGNPOS:
    lda #$01        ; return 1

SGNSIN:
    jmp SINSTK      ; set IACC from A, and exit, tail call

; ----------------------------------------------------------------------------

; =POINT(numeric, numeric)
; ========================
POINT:
    jsr INEXPR      ; evaluate expression as an integer
    jsr PHACC       ; push to stack
    jsr COMEAT      ; expect comma
    jsr BRA         ; handle second argument, and closing bracket
    jsr INTEGB      ; make sure it's an integer

    lda zpIACC      ; LSB second argument
    pha             ; save on stack
    ldx zpIACC+1    ; MSB second argument, save in X

    jsr POPACC      ; pop first argument into IACC

    stx zpIACC+3    ; set MSB of second argument in MSB of IACC
    pla             ; restore LSB second argument
    sta zpIACC+2    ; and LSB just below it

    ldx #zpIACC     ; pointer to XY-coordinates block
    lda #$09        ; OSWORD POINT routine
    jsr OSWORD

    lda zpFACCS     ; zpIACC+4, return value
    bmi TRUE        ; return TRUE if point is off the screen
    bpl SGNSIN      ; put A in IACC, and exit

; ----------------------------------------------------------------------------

; =INSTR(string$, string$ [, numeric])
; ====================================

INSTR:
    jsr EXPR                ; evaluate expression
    bne FACTE               ; 'Type mismatch' error if it's not a string

    cpx #','
    bne INSTRE              ; 'Missing ,' if not followed by a comma

    inc zpAECUR             ; increment past comma
    jsr PHSTR               ; push searched string on the stack
    jsr EXPR                ; evaluate next expression

    bne FACTE           ; 'Type mismatch' error if it's not a string

    lda #$01            ; set default start position to 1
    sta zpIACC
    inc zpAECUR         ; increment for next character
    cpx #')'
    beq INSTRG          ; jump if current character is a ')'

    cpx #','
    beq INSTRH          ; jump if current character is a comma

INSTRE:
    jmp COMERR          ; 'Missin ,' error

INSTRH:
    jsr PHSTR           ; push second string on the stack
    jsr BRA             ; evaluate expression and closing bracket
    jsr INTEGB          ; ensure it was an integer
    jsr POPSTR          ; pop string

INSTRG:
    ldy #$00            ; Y=0 for later use (quick way to set A=0)
    ldx zpIACC          ; X is starting position
    bne INSTRF          ; if it's zero, set it to one

    ldx #$01

INSTRF:
    stx zpIACC          ; store current position

    txa                 ; transfer to A
    dex                 ; decrement X to make it a proper offset
    stx zpIACC+3        ; save in an unused part of IACC

    clc                 ; add AE stack pointer
    adc zpAESTKP
    sta zpWORK          ; and store in WORK

    tya                 ; handle MSB
    adc zpAESTKP+1
    sta zpWORK+1        ; now points to start position in the search string

    lda (zpAESTKP),Y    ; get length of searched string
    sec
    sbc zpIACC+3        ; subtract modified start position
    bcc INSTRY          ; exit with zero if position is past the end of
                        ; searched string

    sbc zpCLEN          ; subtract length
    bcc INSTRY          ; exit with zero if the string could not fit
                        ; between start and end

    adc #$00            ; increment by 1
    sta zpIACC+1        ; save as number of search positions left
    jsr POPSTX          ; pop string

INSTRL:
    ldy #$00            ; start searching at the beginning
    ldx zpCLEN          ; X counts number of characters to be scanned
    beq INSTRO          ; skip if count is zero

INSTRM:
    lda (zpWORK),Y      ; compare searched string
    cmp STRACC,Y        ; with search string
    bne INSTRN          ; bail out if not equal

    iny
    dex
    bne INSTRM          ; loop until all characters are matched

INSTRO:
    lda zpIACC          ; current search position in A

INSTRP:
    jmp SINSTK          ; put A in IACC, and exit, tail call

INSTRY:
    jsr POPSTX          ; discard string

INSTRZ:
    lda #$00            ; return with zero result
    beq INSTRP          ; branch always to jmp SINSTK

INSTRN:
    inc zpIACC          ; increment current search position
    dec zpIACC+1        ; decrement positions left
    beq INSTRZ          ; return 0 if we have no more positions left

    inc zpWORK          ; increment pointer into the searched string
    bne INSTRL

    inc zpWORK+1
    bne INSTRL          ; and continue searching

ABSE:
    jmp LETM            ; 'Type mismatch' error

; ----------------------------------------------------------------------------

; =ABS numeric
; ============

ABS:
    jsr FACTOR      ; evaluate argument
    beq ABSE        ; 'Type mismatch' if it's a string
    bmi FABS        ; jump to FABS if it's a floating point

ABSCOM:
    bit zpIACC+3    ; check MSB of integer
    bmi COMPNO      ; jump if negative
    bpl COMPDN      ; jump and exit if it's (already) positive

FABS:
    jsr FTST        ; test FACC, and set flags
    bpl FNEGX       ; if it's (already) positive, exit
    bmi NEGACC      ; jump to negate FACC

; Negate FACC

FNEG:
    jsr FTST        ; test FACC, and set flags
    beq FNEGX       ; exit if it's zero

NEGACC:
    lda zpFACCS     ; load sign
    eor #$80        ; invert
    sta zpFACCS     ; save sign

FNEGX:
    lda #$FF        ; result type is floating point
    rts

; ----------------------------------------------------------------------------

; unary minus

UNMINS:
    jsr UNPLUS      ; evaluate expression as if it was positive

VALCMP:
    beq ABSE        ; 'Type mismatch' error if it was a string
    bmi FNEG        ; if it was a floating point value, jump to FNEG

; Negate integer in IACC

COMPNO:
    sec             ; calculate IACC = 0 - IACC
    lda #$00
    tay             ; use Y to quickly get 0 back into A every time
    sbc zpIACC
    sta zpIACC

    tya
    sbc zpIACC+1
    sta zpIACC+1

    tya
    sbc zpIACC+2
    sta zpIACC+2

    tya
    sbc zpIACC+3
    sta zpIACC+3

COMPDN:
    lda #$40        ; return type is integer
    rts

; ----------------------------------------------------------------------------

; Get string into string buffer

DATAST:
    jsr AESPAC          ; skip spaces, and get the next character
    cmp #'"'
    beq QSTR            ; jump to quoted string routine if it's a "

    ldx #$00            ; start at beginning of string buffer

DATASL:
    lda (zpAELINE),Y    ; load character from AE line
    sta STRACC,X        ; store in string buffer
    iny
    inx
    cmp #$0D            ; compare with EOL/CR
    beq QSTRF           ; jump to common finish code if EOL is detected

    cmp #','
    bne DATASL          ; continue as long as character is not a comma

QSTRF:
    dey                 ; one character less than , or CR
QSTRE:
    dex             ; one character less than , or CR
    stx zpCLEN      ; store as string length of STRACC
    sty zpAECUR     ; store as new AE cursor position
    lda #$00        ; return type is a string
    rts

; Copy quoted string from AELINE to STRACC

QSTR:
    ldx #$00            ; start at the beginning of STRACC

QSTRP:
    iny                 ; skip past "

QSTRL:
    lda (zpAELINE),Y    ; get next character
    cmp #$0D
    beq QSTREG          ; 'Missing "' error if it's an EOL/CR

    sta STRACC,X        ; store character in string buffer
    iny                 ; point to next source character

    inx                     ; increment destination index
    cmp #'"'
    bne QSTRL               ; get next character if current is not "

    lda (zpAELINE),Y        ; get the next character
    cmp #'"'
    beq QSTRP               ; if it's another ", continue loop
                            ; note that the first " has been put in the buffer

    bne QSTRE           ; set string length and new AE cursor position,
                        ; exit with type is string, branch always

QSTREG:
    jmp NSTNG           ; 'Missing "' error

; ----------------------------------------------------------------------------

; Evaluator Level 1, - + NOT function ( ) ? ! $ | "
; -------------------------------------------------
FACTOR:
    ldy zpAECUR
    inc zpAECUR
    lda (zpAELINE),Y   ; Get next character
    cmp #' '
    beq FACTOR         ; Loop to skip spaces

    cmp #'-'
    beq UNMINS         ; Jump with unary minus

    cmp #'"'
    beq QSTR           ; Jump with string

    cmp #'+'
    bne DOPLUS         ; Jump with unary plus

UNPLUS:
    jsr AESPAC         ; Get current character

DOPLUS:
    cmp #tknOPENIN
    bcc TSTVAR         ; Lowest function token, test for indirections

    cmp #tknEOF+1
    bcs FACERR         ; Highest function token, jump to error

    jmp DISPATCH       ; Jump via function dispatch table

; Indirection, hex, brackets
; --------------------------

TSTVAR:
    cmp #'?'
    bcs TSTVB         ; Jump with ?numeric or higher

    cmp #'.'
    bcs TSTN          ; Jump with .numeric or higher

    cmp #'&'
    beq HEXIN         ; Jump with hex number

    cmp #'('
    beq BRA           ; Jump with brackets, evaluate and expect closing bracket

TSTVB:
    dec zpAECUR       ; decrement, cursor position back
    jsr LVCONT        ; evaluate variable name
    beq ERRFAC        ; Jump with undefined variable or bad name

    jmp VARIND        ; exit, getting the value of the variable, tail call

TSTN:
    jsr FRDD          ; get number from the text
    bcc FACERR        ; 'No such variable' error if the number does not exist
    rts

ERRFAC:
    lda zpBYTESM      ; Check assembler option
    and #$02          ; Is 'ignore undefined variables' set?
    bne FACERR        ; b1=1, jump to give No such variable
    bcs FACERR        ; Jump with bad variable name

    stx zpAECUR       ; store our current AELINE offset

GETPC:
    lda PC        ; Use P% for undefined variable
    ldy PC+1
    jmp AYACC     ; Jump to return 16-bit integer, tail call

; ----------------------------------------------------------------------------

FACERR:
    brk
    dta $1A, 'No such variable'
    ; brk overlap
BKTERR:
    brk
    dta $1B, 'Missing )'

HEXDED:
    brk                 ; both end of BKTERR and start of HEXDED
    dta $1C, 'Bad HEX', 0

; ----------------------------------------------------------------------------

; Deal with bracketed expression

BRA:
    jsr EXPR            ; evaluate expression, next character in X
    inc zpAECUR         ; step past
    cpx #')'
    bne BKTERR          ; error if there's no closing bracket
    tay                 ; set flags on A
    rts

HEXIN:
    jsr FALSE           ; set IACC to all zeros
    iny                 ; next cursor position

HEXIP:
    lda (zpAELINE),Y        ; get next character
    cmp #'0'
    bcc HEXEND

    cmp #'9'+1
    bcc OKHEX       ; '0'-'9' ok

    sbc #$37        ; carry is set, subtract ASCII factor
    cmp #$0A
    bcc HEXEND      ; exit if less than 10

    cmp #$10
    bcs HEXEND      ; exit if > 'F'

OKHEX:
    asl             ; shift digit into upper nibble
    asl
    asl
    asl

    ldx #$03        ; loop 3..0

INLOOP:
    asl             ; shift digit into bottom of IACC
    rol zpIACC
    rol zpIACC+1
    rol zpIACC+2
    rol zpIACC+3
    dex
    bpl INLOOP      ; shift four times for complete nibble

    iny             ; step to next character
    bne HEXIP       ; and loop

HEXEND:
    txa             ; x is $ff if a conversion took place
    bpl HEXDED      ; exit with error if it was still 0, meaning no
                    ; character was read and converted

    sty zpAECUR     ; store our current position

    lda #$40        ; return type is integer
    rts

; ----------------------------------------------------------------------------

; =TOP - Return top of program
; ============================
; There is no TOP token, only TO (as in FOR), so a check for 'P' is done

TO:
    iny
    lda (zpAELINE),Y    ; get next character
    cmp #'P'
    bne FACERR          ; no 'P' found, error 'No such variable'

    inc zpAECUR         ; increment past 'P'
    lda zpTOP           ; load YA with value of TOP
    ldy zpTOP+1
    bcs AYACC           ; branch always (because of cmp)
                        ; set IACC to value of YA, and exit

; ----------------------------------------------------------------------------

; =PAGE - Read PAGE
; =================

RPAGE:
    ldy zpTXTP      ; load YA with PAGE value
    lda #$00
    beq AYACC       ; branch always, set IACC to YA, and exit

LENB:
    jmp LETM        ; error, 'Type mismatch'

; ----------------------------------------------------------------------------

; =LEN string$
; ============

LEN:
    jsr FACTOR      ; evaluate argument
    bne LENB        ; 'Type mismatch' if it's not a string

    lda zpCLEN      ; get length of string STRACC

    ; fallthrough to return it in IACC

; Return 8-bit integer
; --------------------
SINSTK:
    ldy #$00      ; Clear b8-b15, jump to return 16-bit int

; Return 16-bit integer in YA
; ---------------------------
AYACC:
    sta zpIACC
    sty zpIACC+1      ; Store YA in integer accumulator
    lda #$00
    sta zpIACC+2
    sta zpIACC+3      ; Set b16-b31 to 0
    lda #$40          ; type integer
    rts

; ----------------------------------------------------------------------------

; =COUNT - Return COUNT
; =====================

COUNT:
    lda zpTALLY    ; get COUNT
    bcc SINSTK     ; jump to return in IACC

; ----------------------------------------------------------------------------

; =LOMEM - Start of BASIC heap
; ============================

RLOMEM:
    lda zpLOMEM     ; get LOMEM to YA
    ldy zpLOMEM+1
    bcc AYACC       ; jump to return in IACC

; ----------------------------------------------------------------------------

; =HIMEM - Top of BASIC memory
; ============================

RHIMEM:
    lda zpHIMEM     ; get HIMEM to YA
    ldy zpHIMEM+1
    bcc AYACC       ; jump to return in IACC

; ----------------------------------------------------------------------------

; =ERL - Return error line number
; ===============================

ERL:
    ldy zpERL+1     ; get ERL into YA
    lda zpERL
    bcc AYACC       ; jump to return in IACC

; ----------------------------------------------------------------------------

; =ERR - Return current error number
; ==================================

ERR:
    ldy #$00
    lda (FAULT),Y   ; FAULT points to the error number after the BRK
    bcc AYACC       ; jump to return in IACC

; ----------------------------------------------------------------------------

; =TIME - Read system TIME
; ========================

RTIME:
    ldx #zpIACC       ; YX pointr to IACC
    ldy #$00
    lda #$01          ; Read TIME to IACC via OSWORD $01
    .ifdef MOS_BBC
        jsr OSWORD
    .endif
    lda #$40          ; return type is integer
    rts

; ----------------------------------------------------------------------------

; =RND(numeric)
; -------------

RNDB:
    inc zpAECUR     ; increment past opening bracket
    jsr BRA         ; evaluate expression, and check closing bracket
    jsr INTEGB      ; make sure it's an integer

    lda zpIACC+3
    bmi RNDSET      ; if IACC is negative, jump to set SEED manually

    ora zpIACC+2
    ora zpIACC+1
    bne RNDBB       ; jump if argument is not zero

    lda zpIACC
    beq FRND        ; jump if argument is 0

    cmp #$01
    beq FRNDAA      ; jump if argument is 1

; RND(+X) entry

RNDBB:
    jsr IFLT        ; convert limit to a floating point number
    jsr PHFACC      ; push FACC to the stack
    jsr FRNDAA      ; get a random number between 0 and 1 into FACC
    jsr POPSET      ; discard top of stack, but leave ARGP pointing to it
    jsr IFMUL       ; multiply, FACC = FACC * (ARGP)
    jsr FNRM        ; normalise the result
    jsr IFIX        ; fix back to an integer
    jsr INCACC      ; increment the number, so range is [1...limit]

    lda #$40        ; return type is integer
    rts

; --------------------------------------

; Set seed manually

RNDSET:
    ldx #zpSEED     ; point 'M' destination to SEED location
    jsr ACCTOM      ; copy IACC to M
    lda #$40        ; set fifth byte to $40, also return type is integer
    sta zpSEED+4

    rts

; RND [(numeric)]
; ===============
; Notice that RND(10) is computed using floating point arithmetic, so it's
; faster to use RND MOD X, although statistacally that's not 100% uniform.

RND:
    ldy zpAECUR
    lda (zpAELINE),Y  ; get next character
    cmp #'('
    beq RNDB          ; jump to RND(numeric)

; get integer random number

    jsr FRNDAB        ; one round of xor-shift

    ldx #zpSEED       ; offset to seed location relative to start of ZP

MTOACC:
    lda 0+0,X        ; copy number pointed to by X to IACC
    sta zpIACC
    lda 0+1,X
    sta zpIACC+1
    lda 0+2,X
    sta zpIACC+2
    lda 0+3,X
    sta zpIACC+3

    lda #$40          ; return type is integer
    rts

; get floating point random number

FRNDAA:
    jsr FRNDAB        ; one round of xor-shift

FRND:
    ldx #$00          ; sign, overflow, and rounding bytes to zero
    stx zpFACCS
    stx zpFACCXH
    stx zpFACCMG
    lda #$80          ; exponent to $80 so the number is between 0 and 1
    sta zpFACCX

MTOFACC:
    lda zpSEED,X      ; copy seed to mantissa
    sta zpFACCMA,X
    inx
    cpx #$04
    bne MTOFACC

    jsr NRMTDY        ; normalise and tidy up

    lda #$FF          ; return type is a floating point number
    rts

; ----------------------------------------------------------------------------

; Simple xor-shift

FRNDAB:

    ldy #$04      ; Rotate through four bytes, faster but bigger
RTOP:
    ror zpSEED+4
    lda zpSEED+3
    pha
    ror
    sta zpSEED+4
    lda zpSEED+2
    tax
    asl
    asl
    asl
    asl
    sta zpSEED+3
    lda zpSEED+1
    sta zpSEED+2
    lsr
    lsr
    lsr
    lsr
    ora zpSEED+3
    eor zpSEED+4
    stx zpSEED+3
    ldx zpSEED
    stx zpSEED+1
    sta zpSEED
    pla
    sta zpSEED+4
    dey
    bne RTOP
    rts

; ----------------------------------------------------------------------------

; INKEY
; =====

INKEA:
    jsr INTFAC         ; evaluate time limit

; BBC - Call MOS to wait for keypress
; -----------------------------------

INKEALP:
    .ifdef MOS_BBC
        lda #$81
C64_XY_OSBYTE:
        ldx zpIACC      ; timeout in YA
        ldy zpIACC+1
        jmp OSBYTE
    .endif

; ----------------------------------------------------------------------------

; =GET
; ====

GET:
    jsr OSRDCH      ; call MOS
    jmp SINSTK      ; return A in IACC

; ----------------------------------------------------------------------------

; =GET$
; =====

GETD:
    jsr OSRDCH      ; read a character

SINSTR:
    sta STRACC      ; store in string buffer
    lda #$01        ; set length to 1
    sta zpCLEN
    lda #$00        ; return type is string
    rts

; ----------------------------------------------------------------------------

; Note how LEFTD and RIGHTD are partly the same. We might be able to save
; some space here.

; =LEFT$(string$, numeric)
; ========================

LEFTD:
    jsr EXPR        ; eveluate expression
    bne LEFTE       ; 'Type mismatch' error if it's not a string

    cpx #','
    bne MIDC        ; 'Missing ,' error if the next character is not a comma

    inc zpAECUR     ; step past comma

    jsr PHSTR       ; push the string to the stack
    jsr BRA         ; evaluate next expression, and check closing bracket
    jsr INTEGB      ; make sure it's an integer
    jsr POPSTR      ; pop the string of the stack

    lda zpIACC      ; check specified length against string length
    cmp zpCLEN
    bcs LEFTX       ; exit if length is too big

    sta zpCLEN      ; store numeric argument as new string length

LEFTX:
    lda #$00        ; return type is a string
    rts

; ----------------------------------------------------------------------------

; =RIGHT$(string$, numeric)
; =========================

RIGHTD:
    jsr EXPR        ; evaluate expression
    bne LEFTE       ; 'Type mismatch' error if it's not a string

    cpx #','
    bne MIDC        ; 'Missing ,' error if the next character is not a comma

    inc zpAECUR     ; step past comma

    jsr PHSTR       ; push the string to the stack
    jsr BRA         ; evaluate next expression, and check closing bracket
    jsr INTEGB      ; make sure it's an integer
    jsr POPSTR      ; pop the string of the stack

    lda zpCLEN      ; subtract required length from the actual length
    sec
    sbc zpIACC
    bcc RALL        ; requested length is too big, exit
    beq RIGHTX      ; requested length is exactly the string length, exit

    tax             ; save difference in X as offset of the required string
    lda zpIACC      ; set new string length
    sta zpCLEN
    beq RIGHTX      ; exit if required string length is zero

    ldy #$00        ; destination location is 0 (X is source location)

RGHLOP:
    lda STRACC,X    ; copy string to beginning of string buffer
    sta STRACC,Y
    inx
    iny
    dec zpIACC      ; use LSB of IACC as counter
    bne RGHLOP      ; loop until all characters are copied

RALL:
    lda #$00        ; return type is string

RIGHTX:
    rts

; ----------------------------------------------------------------------------

; =INKEY$ numeric
; ===============

INKED:
    jsr INKEA       ; call the generic INKEY routine
    txa             ; save character in A
    cpy #$00
    beq SINSTR      ; if zero, time limit was not reached, return character

RNUL:
    lda #$00        ; return empty string if no key was pressed
    sta zpCLEN
    rts

LEFTE:
    jmp LETM        ; 'Type mismatch' error

MIDC:
    jmp COMERR      ; 'Missing ,' error

; ----------------------------------------------------------------------------

; =MID$(string$, numeric [, numeric] )
; ====================================

MIDD:
    jsr EXPR        ; evaluate expression
    bne LEFTE       ; 'Type mismatch' error if it's not string

    cpx #','
    bne MIDC        ; 'Missing ,' error if next character is not a comma

    jsr PHSTR       ; push string to stack

    inc zpAECUR     ; increment past comma
    jsr INEXPR      ; evaluate integer expression (starting point)

    lda zpIACC
    pha             ; save starting position on the machine stack

    lda #$FF        ; set default length to $ff
    sta zpIACC

    inc zpAECUR     ; step past the next character
    cpx #')'
    beq MIDTWO      ; skip evaluating length if next character is a ')'

    cpx #','
    bne MIDC        ; 'Missing ,' error if next character is not a comma

    jsr BRA         ; evaluate length expression, and check closing bracket
    jsr INTEGB      ; make sure it's an integer

MIDTWO:
    jsr POPSTR      ; pop string from stack

    pla             ; retrieve starting position from machine stack
    tay             ; and put it in Y  (length is in IACC)

    clc
    beq MIDLB       ; jump if starting location is zero

    sbc zpCLEN
    bcs RNUL        ; return empty string if start is past string length

    dey             ; decrement Y to make it a proper offset
    tya             ; and move back to A

MIDLB:
    sta zpIACC+2    ; start offset in IACC+2
    tax             ; and X

    ldy #$00        ; destination offset in Y

    lda zpCLEN      ; take string length
    sec
    sbc zpIACC+2    ; subtract offset
    cmp zpIACC      ; compare to requested length
    bcs MIDLA       ; if not too big, skip store

    sta zpIACC      ; if too big, use the remaining length of the string as
                    ; the requested length

MIDLA:
    lda zpIACC
    beq RNUL        ; return empty string if length of substring is zero

MIDLP:
    lda STRACC,X    ; copy string buffer from source offset
    sta STRACC,Y    ; to destination offset
    iny
    inx
    cpy zpIACC
    bne MIDLP       ; loop until all requested characters are copied

    sty zpCLEN      ; store new string length

    lda #$00        ; return type is string
    rts

; ----------------------------------------------------------------------------

; =STR$ [~] numeric
; =================

STRD:
    jsr AESPAC        ; skip spaces, and get next character
    ldy #$FF          ; Y=$FF for hexadecimal
    cmp #'~'
    beq STRDT         ; jump if hex string is requested

    ldy #$00          ; Y=$00 for decimal
    dec zpAECUR       ; step past ~

STRDT:
    tya
    pha               ; Save format on stack

    jsr FACTOR        ; evaluate the argument
    beq STRE          ; 'Type mismatch' error if it's a string

    tay               ; save argument type in Y
    pla               ; retrieve output format from stack

    sta zpPRINTF      ; and save in PRINTF

    lda VARL_AT+3     ; MSB of @%
    bne STRDM         ; if not zero, jump to convert using @% format

    sta zpWORK        ; zero WORK

    jsr FCONA         ; convert using general format

    lda #$00          ; return type is string
    rts

STRDM:
    jsr FCON          ; Convert using @% format

    lda #$00          ; return type is string
    rts

STRE:
    jmp LETM          ; Jump to Type mismatch error

; ----------------------------------------------------------------------------

; =STRING$(numeric, string$)
; ==========================

STRND:
    jsr INEXPR      ; evaluate expression as an integer
    jsr PHACC       ; push IACC to the stack
    jsr COMEAT      ; check for comma
    jsr BRA         ; evaluate expression, and closing bracket
    bne STRE        ; 'Type mismatch' error if it's not a string

    jsr POPACC      ; pop number of repetitions back into IACC

    ldy zpCLEN      ; get length in Y (also offset start of first repetition)
    beq STRNX       ; exit if string length is zero

    lda zpIACC
    beq STRNY       ; return empty string if repetitions is zero

    dec zpIACC      ; decrement number of repetitions
    beq STRNX       ; exit with one repetition of the string

STRNL:
    ldx #$00        ; copy from beginning of string buffer

STRNLP:
    lda STRACC,X    ; copy source
    sta STRACC,Y    ; to destination in string buffer
    inx
    iny
    beq STRNOV      ; 'String too long' error if destination offset overflows

    cpx zpCLEN
    bcc STRNLP      ; loop until original string length bytes have been copied

    dec zpIACC      ; decrement number of repetitions
    bne STRNL       ; loop until it becomes zero

    sty zpCLEN      ; store destination offset as new string length

STRNX:
    lda #$00        ; return type is a string
    rts

STRNY:
    sta zpCLEN      ; A is always zero here, return empty string, and
                    ; return type in A indicates it's a string
    rts

STRNOV:
    jmp STROVR      ; 'String too long' error

; ----------------------------------------------------------------------------

FNMISS:
    pla             ; pop MSB of LINE
    sta zpLINE+1
    pla             ; pop LSB of LINE
    sta zpLINE

    brk
    dta $1D, 'No such ', tknFN, '/', tknPROC, 0

; Look through program for FN/PROC
; --------------------------------
; On entry, zpWORK points to the name being sought
; zpWORK+2 contains the length of the name being sought

FNDEF:
    lda zpTXTP
    sta zpLINE+1       ; Start at PAGE
    lda #$00
    sta zpLINE

FNFIND:
    ldy #$01
    lda (zpLINE),Y     ; Get line number high byte
    bmi FNMISS         ; End of program, jump to 'No such FN/PROC' error

    ldy #$03

FNFINS:
    iny
    lda (zpLINE),Y
    cmp #' '
    beq FNFINS         ; Skip past spaces

    cmp #tknDEF
    beq DEFFND         ; Found DEF at start of line

NEXLIN:
    ldy #$03
    lda (zpLINE),Y     ; Get line length
    clc
    adc zpLINE
    sta zpLINE         ; Point to next line
    bcc FNFIND         ; loop back to check the next line

    inc zpLINE+1
    bcs FNFIND         ; loop back to check the next line

    ; DEF token found

DEFFND:
    iny
    sty zpCURSOR        ; save offset of character after DEF
    jsr SPACES          ; skip spaces and get the next character

    tya                 ; offset of next character to A
    tax                 ; and X
    clc
    adc zpLINE          ; add LINE pointer LSB
    ldy zpLINE+1        ; put MSB in Y
    bcc FNFDIN

    iny                 ; increment MSB
    clc

FNFDIN:
    ; here carry is always clear
    sbc #$00            ; subtract 1 of LINE pointer
    sta zpWORK+5        ; and save in WORK+5/6
    tya                 ; get MSB from Y
    sbc #$00
    sta zpWORK+6        ; save MSB

    ldy #$00            ; index into zpWORK+5/6 and into name being sought

FNFDLK:
    iny
    inx
    lda (zpWORK+5),Y
    cmp (zpWORK),Y      ; compare name being sought
    bne NEXLIN          ; skip to next line if it's not equal

    cpy zpWORK+2
    bne FNFDLK          ; loop until end of name being sought

    iny
    lda (zpWORK+5),Y    ; get next character from the program text
    jsr WORDCQ          ; check if it's alphanumeric
    bcs NEXLIN          ; jump if name found is longer than being sought

    txa                 ; transfer offset of end of name to Y (via A)
    tay
    jsr CLYADP          ; update program pointer
    jsr LOOKFN          ; create a catalogue entry for the PROC/FN

    ldx #$01
    jsr CREAX           ; clear the byte after the name in the catalogue

    ldy #$00
    lda zpLINE          ; store the address of the PROC/FN
    sta (zpFSA),Y
    iny
    lda zpLINE+1
    sta (zpFSA),Y
    jsr FSAPY           ; update VARTOP

    jmp FNGO            ; join the PROC/FN code

FNCALL:
    brk
    dta $1E, 'Bad call', 0

; ----------------------------------------------------------------------------

; =FNname [parameters]
; ====================

; Below, there are two separate parameters areas.
; The parameter area of the difinition will be called the defined parameter
; area. The parameter area of the caller will be referred to as the
; calling parameter area.

FN:
    lda #tknFN        ; indicate we were called as a function

; Call subroutine
; ---------------
; A=tknFN or tknPROC
; zpLINE => start of FN/PROC name
;

FNBODY:
    sta zpTYPE        ; save call type

    tsx               ; get machine stack pointer in X and A
    txa
    clc
    adc zpAESTKP      ; adjust BASIC stack pointer by size of 6502 stack
    jsr HIDEC         ; store new BASIC stack pointer, check for No Room

    ldy #$00
    txa
    sta (zpAESTKP),Y  ; store machine Stack Pointer on BASIC stack

FNPHLP:
    inx
    iny
    lda $0100,X
    sta (zpAESTKP),Y  ; copy machine stack onto BASIC stack
    cpx #$FF
    bne FNPHLP        ; loop until top of machine stack


    txs               ; clear 6502 stack, X=$ff
    lda zpTYPE
    pha               ; push call type, $01ff will contain call type

    lda zpCURSOR
    pha               ; push LINE pointer offset
    lda zpLINE
    pha               ; push LINE pointer
    lda zpLINE+1
    pha

    lda zpAECUR       ; get AE line offset
    tax               ; also in X
    clc               ; add AE line pointer
    adc zpAELINE
    ldy zpAELINE+1    ; get MSB in Y
    bcc FNNOIC

    iny               ; increment MSB
    clc

FNNOIC:
    ; here, carry is always clear
    sbc #$01           ; subtract 2
    sta zpWORK         ; store as WORK pointer
    tya                ; get MSB
    sbc #$00           ; handle borrow
    sta zpWORK+1       ; (zpWORK) => PROC/FN token

    ldy #$02
    jsr WORDLP         ; Check name is valid

    cpy #$02           ; if Y is still 2, name was omitted
    beq FNCALL         ; in that case, jump to 'Bad call' error

    stx zpAECUR        ; Line pointer offset => after valid FN/PROC name
    dey
    sty zpWORK+2       ; save the length of the name

    jsr CREAFN         ; find catalogue entry
    bne FNGOA          ; if found, jump to it

    jmp FNDEF          ; Not in catalogue, jump to look through program

; FN/PROC destination found
; -------------------------

FNGOA:
    ldy #$00
    lda (zpIACC),Y
    sta zpLINE          ; Set zpLINE to address from FN/PROC infoblock
    iny
    lda (zpIACC),Y
    sta zpLINE+1

FNGO:
    lda #$00
    pha                 ; keep track of number of parameters

    sta zpCURSOR        ; set LINE offset to zero

    jsr SPACES          ; skip spaces, and get next character
    cmp #'('
    beq FNARGS          ; if equal to '(', jump to handle arguments

    dec zpCURSOR        ; one position back

DOFN:
    lda zpAECUR         ; save return location, AE cursor offset
    pha
    lda zpAELINE        ; and AE line pointer
    pha
    lda zpAELINE+1
    pha

    jsr STMT            ; execute the statements comprising the PROC/FN

    ; zpTYPE now contains return value type

    pla                 ; retrieve AE line pointer from stack
    sta zpAELINE+1
    pla
    sta zpAELINE
    pla                 ; and its cursor offset
    sta zpAECUR

    pla                 ; pop number of parameters
    beq DNARGS          ; skip if there were no parameters

    sta zpWORK+8

GTARGS:
    jsr POPWRK          ; pop the address and type of the parameter
    jsr STORST          ; replace with its original value from the BASIC stack

    dec zpWORK+8
    bne GTARGS          ; loop until all parameters have been dealt with

DNARGS:
    pla                 ; restore LINE pointer
    sta zpLINE+1
    pla
    sta zpLINE
    pla                 ; and its cursor offset
    sta zpCURSOR

    pla                 ; drop call type

    ldy #$00
    lda (zpAESTKP),Y    ; get old machine stack pointer
    tax
    txs                 ; restore

FNPLLP:
    iny
    inx
    lda (zpAESTKP),Y
    sta $0100,X         ; copy saved machine stack back onto machine stack
    cpx #$FF
    bne FNPLLP

    tya
    adc zpAESTKP
    sta zpAESTKP        ; adjust BASIC stack pointer
    bcc FNPL

    inc zpAESTKP+1

FNPL:
    lda zpTYPE          ; get return value type in A
    rts

; Parse argument list

FNARGS:
    lda zpAECUR         ; push AE line cursor offset
    pha
    lda zpAELINE        ; push AE line pointer
    pha
    lda zpAELINE+1
    pha

    jsr CRAELV          ; get name of the defined parameter
    beq ARGMAT          ; 'Arguments' error if the name is invalid

    lda zpAECUR         ; update cursor to the comma or closing bracket
    sta zpCURSOR

    pla                 ; pull AE line pointer
    sta zpAELINE+1
    pla
    sta zpAELINE
    pla
    sta zpAECUR         ; and its cursor offset

    pla                 ; retrieve number of arguments
    tax                 ; and hold in X

    lda zpIACC+2        ; push lvalue type
    pha
    lda zpIACC+1        ; push lvalue address
    pha
    lda zpIACC
    pha

    inx                 ; increment number of arguments
    txa
    pha                 ; and push it to the stack

    jsr RETINF          ; save the value, addres, and type of the
                        ; defined parameter variable

    jsr SPACES          ; skip spaces, and get next character

    cmp #','
    beq FNARGS          ; deal with the next parameter is it's a comma

    cmp #')'
    bne ARGMAT          ; 'Arguments' error if there's no closing bracket

    lda #$00
    pha                 ; save the numner of calling parameters as zero

    jsr AESPAC          ; get next caller character

    cmp #'('
    bne ARGMAT          ; 'Arguments' error if the first character is not '('

FNARGP:
    jsr EXPR            ; evaluate an expression
    jsr PHTYPE          ; push value to BASIC stack

    lda zpTYPE          ; get variable type
    sta zpIACC+3        ; store in MSB of IACC

    jsr PHACC           ; push IACC to BASIC stack

    pla                 ; pull number of arguments
    tax
    inx                 ; increment number of arguments
    txa
    pha                 ; push number of arguments

    jsr AESPAC          ; get next character from calling parameter area

    cmp #','
    beq FNARGP          ; handle next parameter if character is a comma

    cmp #')'
    bne ARGMAT          ; 'Arguments' error if it's not a closing bracket

    pla                 ; get number of calling parameters
    pla                 ; get number of defined parameters
    sta zpCOEFP         ; store in COEFP
    sta zpCOEFP+1       ; and COEFP+1           (why? see FNARGW below)
    cpx zpCOEFP         ; compare them
    beq FNARGZ          ; jump if they match

    ; 'Arguments' error

ARGMAT:
    ldx #$FB            ; setup stack pointer
    txs

    pla                 ; restore LINE pointer
    sta zpLINE+1
    pla
    sta zpLINE

    brk                 ; and trigger error
    dta $1F, 'Arguments', 0

FNARGZ:
    jsr POPACC          ; pull type of the calling parameter from BASIC stack

    pla                 ; pull type and address of the defined parameter
    sta zpIACC          ; from the machine stack into IACC
    pla
    sta zpIACC+1
    pla
    sta zpIACC+2        ; defined parameter type

    bmi FNARGY          ; jump if parameter is a string

    lda zpIACC+3        ; calling parameter type is still in MSB
    beq ARGMAT          ; 'Arguments' error if it's a string

    sta zpTYPE          ; save calling parameter type

    ldx #zpWORK         ; pointer to WORK
    jsr ACCTOM          ; copy IACC to WORK

    lda zpTYPE          ; retrieve calling parameter type
    bpl FNARPO          ; jump if it's an integer

    jsr POPSET          ; discard float from stack, leave ARGP pointing to it
    jsr FLDA            ; load FACC from (ARGP)

    jmp FNAROP          ; skip integer code, jump to common end

FNARPO:
    jsr POPACC          ; pop integer from stack into IACC

FNAROP:
    jsr STORF           ; assign the variable
    jmp FNARGW          ; skip string code, jump to common end

FNARGY:
    lda zpIACC+3        ; get calling parameter type
    bne ARGMAT          ; 'Arguments' error if it is not string

    jsr POPSTR          ; pop string of BASIC stack
    jsr STSTRE          ; assign it

FNARGW:
    dec zpCOEFP
    bne FNARGZ          ; loop for all parameters

    lda zpCOEFP+1       ; here we kept the unadjusted number of parameters
    pha                 ; push it to the stack

    jmp DOFN            ; jump to main PROC/FN code

; ----------------------------------------------------------------------------

; Push a value onto the stack (address, type, and value)
; ------------------------------------------------------

RETINF:
    ldy zpIACC+2            ; get the type of the variable
    cpy #$05
    bcs FNINFO          ; jump if it's a float

    ldx #zpWORK         ; point to WORK
    jsr ACCTOM          ; copy IACC to WORK     (address and type)

FNINFO:
    jsr VARIND      ; get the value of the variable

    php             ; save flags since it contains the type of the variable
    jsr PHTYPE      ; push value of the variable to the stack
    plp             ; restore flags

    beq FNSTRD      ; skip WORK stuff if the variable was a string
    bmi FNSTRD      ; or a floating point number

    ldx #zpWORK     ; point to WORK
    jsr MTOACC      ; copy WORK to IACC

FNSTRD:
    jmp PHACC       ; push IACC to the stack (address and type)

VARIND:
    ldy zpIACC+2    ; check type of variable
    bmi FACSTR      ; jump if it's a string
    beq VARONE      ; jump if it's a single byte

    cpy #$05
    beq VARFP       ; jump if it's a floating point value

    ldy #$03        ; four bytes to copy to IACC, pointed to by IACC (3..0)

    lda (zpIACC),Y  ; get fourth byte
    sta zpIACC+3    ; copy to top byte of IACC

    dey
    lda (zpIACC),Y  ; get third byte
    sta zpIACC+2    ; copy just below it

    dey
    lda (zpIACC),Y  ; get second byte
    tax             ; save in X as to not mess up our pointer

    dey
    lda (zpIACC),Y  ; get first byte
    sta zpIACC      ; save in LSB of IACC
    stx zpIACC+1    ; save 2nd byte just above it

    lda #$40        ; return type is integer
    rts

VARONE:
    lda (zpIACC),Y  ; get single byte
    jmp AYACC       ; return in IACC, padded with zeros

VARFP:
    dey
    lda (zpIACC),Y  ; get the mantissa of a floating point number, LSB first
    sta zpFACCMD

    dey
    lda (zpIACC),Y
    sta zpFACCMC

    dey
    lda (zpIACC),Y
    sta zpFACCMB

    dey
    lda (zpIACC),Y  ; store MSB of mantissa as sign first
    sta zpFACCS

    dey
    lda (zpIACC),Y  ; get the exponent
    sta zpFACCX

    sty zpFACCMG    ; zero rounding byte and under/overflow byte
    sty zpFACCXH

    ora zpFACCS
    ora zpFACCMB
    ora zpFACCMC
    ora zpFACCMD
    beq VARFPX      ; if mantissa is zero, don't insert true numeric bit

    lda zpFACCS     ; get sign byte
    ora #$80        ; add the true numeric bit

VARFPX:
    sta zpFACCMA    ; save as MSB of mantissa
    lda #$FF        ; indicate result is floating point
    rts

FACSTR:
    cpy #$80
    beq FACSTT      ; jump if string is not dynamic (e.g. BUFFER)

    ldy #$03
    lda (zpIACC),Y  ; get string length
    sta zpCLEN      ; and store
    beq STRRTS      ; exit if the string is empty

    ldy #$01        ; transfer address of string to WORK
    lda (zpIACC),Y
    sta zpWORK+1
    dey
    lda (zpIACC),Y
    sta zpWORK

    ldy zpCLEN      ; get string length as index

MOVTOS:
    dey
    lda (zpWORK),Y  ; copy string
    sta STRACC,Y    ; to string buffer
    tya             ; cheap check for zero
    bne MOVTOS      ; loop for all characters

STRRTS:
    rts

FACSTT:
    lda zpIACC+1    ; check MSB
    beq CHRF        ; if it's zero, treat address as ASCII code
                    ; is this ever used?

    ldy #$00

FACSTU:
    lda (zpIACC),Y  ; copy string
    sta STRACC,Y    ; to the string buffer
    eor #$0D
    beq FACSTV      ; exit loop if CR/EOL, jump with A=0

    iny
    bne FACSTU      ; or copy until buffer is full

    tya             ; set A=0

FACSTV:
    sty zpCLEN      ; store string length
                    ; A=0, indicate type is string
    rts

; ----------------------------------------------------------------------------

; =CHR$ numeric
; =============

CHRD:
    jsr INTFAC      ; evaluate integer expression

CHRF:
    lda zpIACC      ; load LSB of integer
    jmp SINSTR      ; construct string with this character and exit, tail call

; ----------------------------------------------------------------------------

; Find out at which line number the error occurred

FNLINO:
    ldy #$00        ; set ERL to zero
    sty zpERL
    sty zpERL+1

    ldx zpTXTP      ; set WORK pointer to PAGE
    stx zpWORK+1
    sty zpWORK      ; LSB is zero

    ldx zpLINE+1
    cpx #>BUFFER
    beq FNLINX      ; exit if LINE pointer points to BUFFER (immediate mode)

    ldx zpLINE

FIND:
    jsr GETWRK      ; get character and increment WORK pointer

    cmp #$0D
    bne CHKA        ; jump if line has not finished yet (no CR/EOL)

    cpx zpWORK
    lda zpLINE+1
    sbc zpWORK+1
    bcc FNLINX      ; exit of LINE pointer is less than the start address of
                    ; this line

    jsr GETWRK      ; get byte and increment WORK pointer

    ora #$00        ; set flags
    bmi FNLINX      ; exit if byte indicates the end of the program

    sta zpERL+1     ; store MSB of ERL

    jsr GETWRK      ; get byte and increment WORK pointer

    sta zpERL       ; store LSB of ERL

    jsr GETWRK      ; get byte and increment WORK pointer

CHKA:
    cpx zpWORK
    lda zpLINE+1
    sbc zpWORK+1
    bcs FIND        ; continue search if LINE pointer is greater than
                    ; address of current line

FNLINX:
    rts             ; returns with Y=0

; ----------------------------------------------------------------------------

; ERROR HANDLER
; =============

BREK:

    jsr FNLINO          ; find line number where error occurred

    sty zpTRFLAG        ; turn off trace (FNLINO returns with Y=0)

    lda (FAULT),Y       ; get error number
    bne BREKA           ; if ERR != 0, not fatal, skip past resetting default
                        ; program

    lda #<BASERR        ; set BASIC error message to its default
    sta zpERRORLH
    lda #>BASERR
    sta zpERRORLH+1

BREKA:
    lda zpERRORLH       ; set LINE to point to error program
    sta zpLINE
    lda zpERRORLH+1
    sta zpLINE+1

    jsr SETVAR          ; Clear DATA and stacks

    tax                 ; A=X=0
    stx zpCURSOR        ; zero the offset

    .ifdef MOS_BBC
        lda #$DA
        jsr OSBYTE      ; Clear VDU queue

        lda #$7E
        jsr OSBYTE      ; Acknowlege any Escape state
    .endif

    ldx #$FF
    stx zpBYTESM        ; set OPT to $ff

    txs                 ; clear machine stack

    jmp STMT            ; Jump to execution loop

; ----------------------------------------------------------------------------

; Default ERROR program
; ---------------------
; REPORT:IF ERL PRINT " at line ";ERL:END ELSE PRINT:END
; (the spaces are not encoded)

BASERR:
    dta tknREPORT           ; here is where the message is printed (!)
    dta ':'
    dta tknIF
    dta tknERL
    dta tknPRINT
    dta '"'
    dta ' at line '
    dta '"', ';'
    dta tknERL
    dta ':'
    dta tknEND
    dta tknELSE
    dta tknPRINT
    dta ':'
    dta tknEND
    dta 13

; ----------------------------------------------------------------------------

; SOUND numeric, numeric, numeric, numeric
; ========================================

BEEP:
    jsr ASEXPR        ; evaluate first expression

    ldx #$03          ; three more to evaluate

BEEPLP:
    .ifdef MOS_BBC
        lda zpIACC
        pha
        lda zpIACC+1
        pha           ; stack current 16-bit integer
    .endif

    txa               ; save our counter
    pha

    jsr INCMEX        ; Step past comma, evaluate next integer

    pla
    tax               ; restore our counter

    dex
    bne BEEPLP        ; Loop to stack this one

    .ifdef MOS_BBC
        jsr AEDONE    ; Check end of statement

        lda zpIACC
        sta zpWORK+6  ; Copy current 16-bit integer to end of control block
        lda zpIACC+1
        sta zpWORK+7

        ldy #$07      ; Prepare for OSWORD 7
        ldx #$05      ; and 6 more bytes
        bne ENVELL    ; Jump to pop to control block and call OSWORD
    .endif

; ----------------------------------------------------------------------------

; ENVELOPE a,b,c,d,e,f,g,h,i,j,k,l,m,n
; ====================================
ENVEL:
    jsr ASEXPR        ; Evaluate integer

    ldx #$0D          ; 13 more to evaluate

ENVELP:
    .ifdef MOS_BBC
        lda zpIACC
        pha            ; Stack current 8-bit integer
    .endif

    txa
    pha                ; save our counter

    jsr INCMEX         ; Step past comma, evaluate next integer

    pla
    tax                ; restore our counter

    dex
    bne ENVELP         ; Loop to stack this one

    jsr AEDONE         ; Check end of statement

    .ifdef MOS_BBC
        lda zpIACC
        sta zpWORK+13  ; Copy current 8-bit integer to end of control block
        ldx #$0C       ; Prepare for 12 more bytes
        ldy #$08       ; and OSWORD 8
    .endif

ENVELL:
    .ifdef MOS_BBC
        pla
        sta zpWORK,X   ; Pop bytes into control block
        dex
        bpl ENVELL

        tya            ; Y=OSWORD number
        ldx #zpWORK
        ldy #$00       ; YX => control block in zpWORK space
        jsr OSWORD
    .endif

    jmp NXT         ; Return to execution loop

; ----------------------------------------------------------------------------

; WIDTH numeric
; =============

WIDTH:
    jsr ASEXPR      ; evaluate width expression
    jsr AEDONE      ; check for the end of the statement

    ldy zpIACC
    dey             ; decrement the value
    sty zpWIDTHV    ; and save it as the current terminal width 

    jmp NXT         ; jump to main loop

; ----------------------------------------------------------------------------

STORER:
    jmp LETM          ; 'Type mismatch' error

; Store byte or word integer
; ==========================
; Assign to numeric variable

STEXPR:
    jsr EXPR          ; Evaluate expression

STORE:
    jsr POPWRK        ; Unstack integer (address of data)

STORF:
    lda zpWORK+2
    cmp #$05
    beq STORFP        ; Size=5, jump to store float

    lda zpTYPE
    beq STORER        ; if type is string, jump to error
    bpl STORIN        ; if type is integer, jump to store it

    jsr IFIX          ; Convert float to integer

STORIN:
    ldy #$00
    lda zpIACC
    sta (zpWORK),Y    ; Store byte 1
    lda zpWORK+2
    beq STORDN        ; Exit if size=0, single byte

    lda zpIACC+1
    iny
    sta (zpWORK),Y    ; Store byte 2

    lda zpIACC+2
    iny
    sta (zpWORK),Y    ; Store byte 3

    lda zpIACC+3
    iny
    sta (zpWORK),Y    ; Store byte 4

STORDN:
    rts

; ----------------------------------------------------------------------------

; Store float
; ===========

STORFP:
    lda zpTYPE
    beq STORER        ; 'Type mismatch' error if it's a string
    bmi STORPF        ; jump if it's a floating point value

    jsr IFLT          ; Convert integer to float

STORPF:
    ldy #$00          ; Store 5-byte float
    lda zpFACCX
    sta (zpWORK),Y

    iny               ; exponent
    lda zpFACCS
    and #$80
    sta zpFACCS       ; Unpack sign

    lda zpFACCMA
    and #$7F          ; Unpack mantissa A (MSB)
    ora zpFACCS
    sta (zpWORK),Y    ; sign + mantissa A

    iny
    lda zpFACCMB
    sta (zpWORK),Y    ; mantissa B

    iny
    lda zpFACCMC
    sta (zpWORK),Y    ; mantissa C

    iny
    lda zpFACCMD
    sta (zpWORK),Y    ; mantissa D (LSB)
    rts

; ----------------------------------------------------------------------------

; Print a token
; =============
; On entry, A contains a character or a token (value >127)

TOKOUT:
    sta zpWORK          ; store in WORK
    cmp #$80
    bcc CHOUT           ; output as character if it's not a token

    lda #<TOKENS
    sta zpWORK+1        ; point WORK+1/2 to token table
    lda #>TOKENS
    sta zpWORK+2

    sty zpWORK+3        ; save Y

FINTOK:
    ldy #$00

LOOTOK:
    iny
    lda (zpWORK+1),Y    ; get character from TOKENS table
    bpl LOOTOK          ; loop until it's the token

    cmp zpWORK
    beq GOTTOK          ; jump if it's the token we were looking for

    iny                 ; skip flags, point to start of next token in ASCII

    tya                 ; add to pointer
    sec
    adc zpWORK+1
    sta zpWORK+1
    bcc FINTOK          ; loop to check next token

    inc zpWORK+2
    bcs FINTOK          ; loop to check next token

GOTTOK:
    ldy #$00            ; point back to first character of the keyword

PRTTOK:
    lda (zpWORK+1),Y    ; get character from keyword
    bmi ENDTOK          ; exit if it's the token, marking the end of the word

    jsr CHOUT           ; print the character

    iny
    bne PRTTOK          ; continue printing

ENDTOK:
    ldy zpWORK+3        ; restore Y
    rts

; ----------------------------------------------------------------------------

; Print byte in A as %02X hexadecimal

HEXOUT:
    pha             ; save our byte
    lsr             ; shift upper nibble to the bottom
    lsr
    lsr
    lsr
    jsr DIG         ; print digit
    pla             ; restore out byte
    and #$0F        ; mask out lower nibble

DIG:
    cmp #$0A
    bcc DIGR        ; skip adding 7 if digit < 10

    adc #$06        ; carry is set, add 7 for digits A-F

DIGR:
    adc #'0'        ; add ASCII offset

; Print the ASCII character in A

CHOUT:
    cmp #$0D
    bne NCH         ; jump if it's not CR/EOL

    jsr OSWRCH
    jmp BUFEND      ; set COUNT to zero, and exit, tail call

; Print A in hex followed by a space

HEXSP:
    jsr HEXOUT

LISTPT:
    lda #' '        ; print a space

NCH:
    pha             ; save character

    lda zpWIDTHV
    cmp zpTALLY
    bcs NOCRLF      ; no new line if WIDTH > COUNT

    jsr NLINE       ; move to a new line

NOCRLF:
    pla             ; restore character

    inc zpTALLY     ; increment COUNT

    .if WRCHV != 0
        jmp (WRCHV)     ; print it, and exit, tail call
    .endif
    .if WRCHV == 0
        jmp OSWRCH      ; print it, and exit, tail call
    .endif

; ----------------------------------------------------------------------------

; Print the LISTO spaces
; ======================
; On entry, A contains the mask to hold against the LISTO byte
; X is level of indentation so far

LISTPS:
    and zpLISTOP
    beq LISTPX          ; exit if the selected option is not selected

    txa
    beq LISTPX          ; exit if level of indentation is zero
    bmi LISTPT          ; print a single space if it's negative

    asl             ; multiply by 2
    tax             ; this saves one byte (instead of jsr CHOUT)

LISTPL:
    jsr LISTPT          ; print space

    dex
    bne LISTPL          ; loop for the required number of times

LISTPX:
    rts

; ----------------------------------------------------------------------------

; LISTO command routine
; =====================

LISTO:
    inc zpCURSOR        ; skip past the O

    jsr AEEXPR          ; evaluate expression
    jsr FDONE           ; check for the end of the statement
    jsr INTEG           ; ensure it's an integer

    lda zpIACC
    sta zpLISTOP        ; store value as new LISTO value

    jmp CLRSTK          ; back to main loop

; ----------------------------------------------------------------------------

; LIST [linenum [,linenum]]
; =========================

LIST:
    iny
    lda (zpLINE),Y      ; get character following the LIST token
    cmp #'O'
    beq LISTO           ; if it's an 'O', jump to the LISTO command

    lda #$00
    sta zpWORK+4        ; indentation count of FOR loops
    sta zpWORK+5        ; indentation count of REPEAT loops

    jsr SINSTK          ; put A (=0) in IACC, and zero rest of IACC

    jsr SPTSTN          ; get line number after LIST

    php                 ; save flags that indicate whether it was found or not

    jsr PHACC           ; save the number on the stack

    lda #$FF            ; load default second line number 32767 ($7fff)
    sta zpIACC
    lda #$7F
    sta zpIACC+1

    plp                 ; get out flags back

    bcc NONUML          ; skip next code if first line number was not found

    jsr SPACES          ; skip spaces, and get next character
    cmp #','
    beq GOTCX           ; jump if it's a comma

    jsr POPACC          ; pull the first line number
    jsr PHACC           ; and push it again
                        ; this makes top of stack and IACC equal and it'll
                        ; print only one line

    dec zpCURSOR        ; decrement cursor to allow for not finding comma
    bpl GOTCFF          ; jump forwards to do the listing

NONUML:
    jsr SPACES          ; skip spaces and get next character
    cmp #','
    beq GOTCX           ; skip the comma if it's present

    dec zpCURSOR        ; allow for not finding comma again

GOTCX:
    jsr SPTSTN          ; get line number

GOTCFF:
    lda zpIACC          ; save the line number somewhere safe (FACC mantissa)
    sta zpFACCMA
    lda zpIACC+1
    sta zpFACCMB

    jsr DONE            ; check for the end of the statement
    jsr ENDER           ; check for 'Bad program'
    jsr POPACC          ; pull initial line number from the stack
    jsr FNDLNO          ; find the line number (return C=0 if not exist)

    lda zpWORK+6        ; save address in LINE pointer
    sta zpLINE
    lda zpWORK+7
    sta zpLINE+1
    bcc LIMTST          ; skip printing if line number does not exist (C=0)

    dey                 ; move back one character
    bcs GETNUM          ; branch always

ENDLN:
    jsr NLINE           ; move to a new line
    jsr CLYADP          ; update LINE pointer and check 'Escape'

GETNUM:
    lda (zpLINE),Y      ; get the line number of the line
    sta zpIACC+1        ; and save it in IACC
    iny
    lda (zpLINE),Y
    sta zpIACC

    iny                 ; increment to offset of text
    iny
    sty zpCURSOR        ; and store as LINE pointer offset

LIMTST:
    lda zpIACC          ; subtract limiting line from current line
    clc
    sbc zpFACCMA
    lda zpIACC+1
    sbc zpFACCMB
    bcc LISTLN          ; print if we are below the limit

    jmp CLRSTK          ; exit and join main loop

LISTLN:
    jsr NPRN            ; print the line number

    ldx #$FF
    stx zpCOEFP         ; set quotes mode to $ff (0 means tokens not expanded)

    lda #$01
    jsr LISTPS          ; print a single space between line number and rest

    ldx zpWORK+4
    lda #$02
    jsr LISTPS          ; print FOR indentation spaces

    ldx zpWORK+5
    lda #$04
    jsr LISTPS          ; print REPEAT indentation spaces

LPX:
    ldy zpCURSOR        ; get offset to next character of the text of the line

LP:
    lda (zpLINE),Y      ; get character/token
    cmp #$0D
    beq ENDLN           ; jump if EOL/CR

    cmp #'"'
    bne LPTOKS          ; jump if not "

    lda #$FF            ; invert quote status
    eor zpCOEFP
    sta zpCOEFP

    lda #'"'            ; restore the quote symbol in A

LPQUOT:
    jsr CHOUT           ; print character or token

    iny
    bne LP              ; loop back and get next character

LPTOKS:
    bit zpCOEFP         ; if quote mode is in effect
    bpl LPQUOT          ; simply print the character

    cmp #tknCONST
    bne LPSIMP          ; jump if it's not a constant / line number token

    jsr SPGETN          ; decode the line number

    sty zpCURSOR        ; save cursor position
    lda #$00
    sta zpPRINTS        ; set field width to zero
    jsr POSITE          ; print the line number

    jmp LPX             ; loop to next character / token

LPSIMP:
    cmp #tknFOR
    bne LPSIMQ          ; skip if not FOR token

    inc zpWORK+4        ; increment FOR indentation

LPSIMQ:
    cmp #tknNEXT
    bne LPSIMR          ; skip if not NEXT token

    ldx zpWORK+4
    beq LPSIMR          ; skip if FOR indentation already zero

    dec zpWORK+4        ; decrement FOR indentation

LPSIMR:
    cmp #tknREPEAT
    bne LPSIMS          ; skip if not REPEAT token

    inc zpWORK+5        ; increment REPEAT indentation

LPSIMS:
    cmp #tknUNTIL
    bne LPSIMT          ; skip if not UNTIL token

    ldx zpWORK+5
    beq LPSIMT          ; skip if REPEAT indentation already zero

    dec zpWORK+5        ; decrement REPEAT indentation

LPSIMT:
    jsr TOKOUT          ; print the token

    iny
    bne LP              ; loop and get next character / token

; ----------------------------------------------------------------------------

NEXER:
    brk
    dta $20, 'No ', tknFOR, 0

; NEXT [variable [,...]]
; ======================

NEXT:
    jsr AELV            ; get the name of the variable

    bne STRIPA          ; jump if variable is valid and defined

    ldx zpFORSTP        ; get FOR stack pointer
    beq NEXER           ; 'No FOR' error if the stack is empty
    bcs NOCHK           ; jump if variable name is invalid

NEXHOW:
    jmp STDED           ; 'Syntax error'

STRIPA:
    bcs NEXHOW          ; 'Syntax error' if the variable is a string

    ldx zpFORSTP        ; get the FOR stack pointer
    beq NEXER           ; 'No FOR' error if the stack is empty

    ; compare the variable information block of the variable with the
    ; variable information block stored on the FOR stack

STRIP:
    lda zpIACC
    cmp FORINL-$f,X
    bne NOTIT           ; jump if they are not equal

    lda zpIACC+1
    cmp FORINH-$f,X
    bne NOTIT           ; jump if they are not equal

    lda zpIACC+2
    cmp FORINT-$f,X
    beq NOCHK           ; jump if they are the same

NOTIT:
    txa                 ; drop the top record on the FOR stack
    sec
    sbc #$0F
    tax
    stx zpFORSTP
    bne STRIP           ; continue if stack is not empty

    brk
    dta $21
    dta 'Can', 0x27, 't Match ', tknFOR
    brk

NOCHK:
    lda FORINL-$f,X     ; retrieve the address of the variable
    sta zpIACC
    lda FORINH-$f,X
    sta zpIACC+1

    ldy FORINT-$f,X     ; retrieve type of the variable
    cpy #$05
    beq FNEXT           ; jump if the variable is floating point

    ; variable is integer

    ldy #$00
    lda (zpIACC),Y      ; get LSB of the current value of the loop variable
    adc FORSPL-$f,X     ; add step size
    sta (zpIACC),Y      ; save the result
    sta zpWORK          ; also in WORK

    iny
    lda (zpIACC),Y      ; same for the rest of the 32-bit value
    adc FORSPM-$f,X
    sta (zpIACC),Y
    sta zpWORK+1

    iny
    lda (zpIACC),Y
    adc FORSPN-$f,X
    sta (zpIACC),Y
    sta zpWORK+2

    iny
    lda (zpIACC),Y
    adc FORSPH-$f,X
    sta (zpIACC),Y      ; finally the MSB
    tay                 ; not stored in WORK+3 but in Y

    lda zpWORK          ; subtract terminating value, start with LSB from WORK
    sec
    sbc FORLML-$f,X
    sta zpWORK          ; and store in WORK

    lda zpWORK+1        ; 2nd byte
    sbc FORLMM-$f,X
    sta zpWORK+1

    lda zpWORK+2        ; 3rd byte
    sbc FORLMN-$f,X
    sta zpWORK+2

    tya                 ; 4th byte, MSB was stored in Y
    sbc FORLMH-$f,X
    ora zpWORK          ; check for zero
    ora zpWORK+1
    ora zpWORK+2
    beq NOTFIN          ; jump if the result is zero

    tya
    eor FORSPH-$f,X
    eor FORLMH-$f,X
    bpl FORDRN          ; jump if this is an upwards loop
    bcs NOTFIN          ; carry out another iteration
    bcc FINFOR          ; terminate loop

FORDRN:
    bcs FINFOR          ; terminate if the variable is greater than limit

NOTFIN:
    ldy FORADL-$f,X     ; set LINE pointer to address of the start of the loop
    lda FORADH-$f,X
    sty zpLINE
    sta zpLINE+1

    jsr SECUR           ; check the 'Escape' flag

    jmp STMT            ; execute body of the loop, tail call

FINFOR:
    lda zpFORSTP        ; drop top record of the FOR stack
    sec
    sbc #$0F
    sta zpFORSTP

    ldy zpAECUR
    sty zpCURSOR        ; update LINE pointer offset

    jsr SPACES          ; skip spaces, and get next character

    cmp #','
    bne NXTFIN          ; exit if it's not a comma

    jmp NEXT            ; deal with next variable name

FNEXT:
    jsr VARFP           ; get the current value of the loop variable in FACC

    lda zpFORSTP        ; create pointer in ARGP that points to record
    clc                 ; on top of the FOR stack
    adc #<(FORSPL-$f)
    sta zpARGP
    lda #>FORSPL
    sta zpARGP+1

    jsr FADD            ; add the step size to the variable

    lda zpIACC          ; make WORK point to the value of the variable
    sta zpWORK
    lda zpIACC+1
    sta zpWORK+1

    jsr STORPF          ; move FACC to the variable

    lda zpFORSTP
    sta zpTYPE          ; save the FOR stack pointer

    clc                 ; make ARGP point to terminating value in record
    adc #<(FORLML-$f)
    sta zpARGP
    lda #>FORLML
    sta zpARGP+1

    jsr FCMP            ; compare FACC with (ARGP)

    beq NOTFIN          ; end the loop if they are equal

    lda FORSPM-$f,X
    bmi FFORDR          ; jump if step is negative
    bcs NOTFIN          ; continue loop if the variable is less than limit
    bcc FINFOR          ; otherwise, terminate loop

FFORDR:
    bcc NOTFIN          ; continue loop if the variable is greater than limit
    bcs FINFOR          ; otherwise, terminate loop

NXTFIN:
    jmp SUNK            ; exit to main loop

; ----------------------------------------------------------------------------

FORCV:
    brk
    dta $22, tknFOR, ' variable'
    ; brk overlap
FORDP:
    brk
    dta $23, 'Too many ', tknFOR, 's'
    ; brk overlap
FORTO:
    brk
    dta $24, 'No ', tknTO, 0

; FOR numvar = numeric TO numeric [STEP numeric]
; ==============================================

FOR:
    jsr CRAELV      ; get the name of the FOR variable
    beq FORCV       ; 'FOR variable' error if it's a string
    bcs FORCV       ; or when it's invalid

    jsr PHACC       ; save the type and address of the variable
    jsr EQEAT       ; check for '='
    jsr STEXPR      ; evaluate expression, starting value of the variable

    ldy zpFORSTP    ; check FOR stack pointer
    cpy #cFORTOP
    bcs FORDP       ; 'Too many FORs' error, more than 10 loops are running

    lda zpWORK      ; save address and type on the FOR stack
    sta FORINL,Y
    lda zpWORK+1
    sta FORINH,Y
    lda zpWORK+2    ; type
    sta FORINT,Y
    tax             ; save type in X

    jsr AESPAC      ; skip spaces, and get next character

    cmp #tknTO
    bne FORTO       ; 'No TO' error if it's not TO token

    cpx #$05
    beq FFOR        ; jump if type of variable is floating point

    jsr INEXPR      ; evaluate upper limit of the loop and ensure it's integer

    ldy zpFORSTP    ; save terminating value on the FOR stack
    lda zpIACC
    sta FORLML,Y
    lda zpIACC+1
    sta FORLMM,Y
    lda zpIACC+2
    sta FORLMN,Y
    lda zpIACC+3
    sta FORLMH,Y

    lda #$01
    jsr SINSTK      ; set IACC to 1

    jsr AESPAC      ; skip spaces, and get the next character

    cmp #tknSTEP
    bne FORSTW      ; skip evaluating STEP size if it's not STEP token

    jsr INEXPR      ; evaluate step size, and ensure it's an integer

    ldy zpAECUR

FORSTW:
    sty zpCURSOR

    ldy zpFORSTP    ; save STEP value on the FOR stack
    lda zpIACC
    sta FORSPL,Y
    lda zpIACC+1
    sta FORSPM,Y
    lda zpIACC+2
    sta FORSPN,Y
    lda zpIACC+3
    sta FORSPH,Y

FORN:
    jsr FORR        ; check for end of statement and move LINE pointer to
                    ; the start of the next statement

    ldy zpFORSTP
    lda zpLINE      ; save LINE pointer to FOR stack, start of loop body
    sta FORADL,Y
    lda zpLINE+1
    sta FORADH,Y

    clc
    tya             ; stack pointer to A
    adc #$0F
    sta zpFORSTP    ; adjust stack pointer to permanently stack the record

    jmp STMT        ; exit, and start executing body of loop

FFOR:
    jsr EXPR        ; evaluate terminating value of loop
    jsr FLOATI      ; ensure it's floating point

    lda zpFORSTP    ; make ARGP point to terminating value in record on stack
    clc
    adc #<FORLML
    sta zpARGP
    lda #>FORLML
    sta zpARGP+1

    jsr FSTA        ; store FACC in (ARGP)
    jsr FONE        ; set FACC to 1.0
    jsr AESPAC      ; skip spaces, and get next character

    cmp #tknSTEP
    bne FFORST      ; skip evaluating step size if it's not a STEP token

    jsr EXPR        ; evaluate expression
    jsr FLOATI      ; ensure it's floating point

    ldy zpAECUR

FFORST:
    sty zpCURSOR

    lda zpFORSTP    ; make ARGP point to step size in record on stack
    clc
    adc #<FORSPL
    sta zpARGP
    lda #>FORSPL
    sta zpARGP+1

    jsr FSTA        ; store FACC in record on the stack

    jmp FORN        ; jump to common FOR code, same as for integer variables

; ----------------------------------------------------------------------------

; GOSUB numeric
; =============

GOSUB:
    jsr GOFACT      ; look for a line number after the GOSUB token

ONGOSB:
    jsr DONE        ; check for the end of the statement

    ldy zpSUBSTP
    cpy #cSUBTOP
    bcs GOSDP       ; 'Too many GOSUBs' error if stack is full

    lda zpLINE      ; save return address on GOSUB stack
    sta SUBADL,Y
    lda zpLINE+1
    sta SUBADH,Y
    inc zpSUBSTP    ; increment the stack pointer

    bcc GODONE      ; carry is clear, branch always to GOTO code

GOSDP:
    brk
    dta $25, 'Too many ', tknGOSUB, 's'
    ; brk overlap

; ----------------------------------------------------------------------------

RETNUN:
    brk
    dta $26, 'No ', tknGOSUB, 0

; RETURN
; ======

RETURN:
    jsr DONE          ; Check for end of statement
    ldx zpSUBSTP
    beq RETNUN        ; If GOSUB stack empty, error

    dec zpSUBSTP      ; Decrement GOSUB stack
    ldy SUBADL-1,X    ; Get stacked line pointer
    lda SUBADH-1,X
    sty zpLINE        ; Set line pointer
    sta zpLINE+1

    jmp NXT           ; Jump back to execution loop

; ----------------------------------------------------------------------------

; GOTO numeric
; ============

GOTO:
    jsr GOFACT       ; get line number after GOTO token
    jsr DONE         ; check for end of statement

GODONE:
    lda zpTRFLAG
    beq GONO         ; jump if TRACE is off

    jsr TRJOBA       ; If TRACE ON, print current line number

GONO:
    ldy zpWORK+6     ; Get destination line address
    lda zpWORK+7

JUMPAY:
    sty zpLINE       ; Set line pointer
    sta zpLINE+1

    jmp STMT         ; Jump back to execution loop

; ----------------------------------------------------------------------------

; ON ERROR OFF
; ------------

ONERGF:
    jsr DONE         ; Check end of statement

    lda #<BASERR     ; set default error program
    sta zpERRORLH
    lda #>BASERR
    sta zpERRORLH+1

    jmp NXT          ; Jump to execution loop

; ----------------------------------------------------------------------------

; ON ERROR [OFF | program ]
; -------------------------

ONERRG:
    jsr SPACES          ; skip spaces and get next character

    cmp #tknOFF
    beq ONERGF          ; jump if it's the OFF token

    ldy zpCURSOR
    dey
    jsr CLYADP          ; update program pointer

    lda zpLINE          ; point error handler address to _here_
    sta zpERRORLH
    lda zpLINE+1
    sta zpERRORLH+1

    jmp REM             ; Skip past end of line, and return to main loop

ONER:
    brk
    dta $27, tknON, ' syntax', 0

; ----------------------------------------------------------------------------

; ON [ERROR] [numeric]
; ====================

ON:
    jsr SPACES          ; skip spaces, and get next character

    cmp #tknERROR
    beq ONERRG          ; if it's ERROR token, jump to ON ERROR routine

    dec zpCURSOR        ; decrement cursor position to allow not finding ERROR

    jsr AEEXPR          ; evaluate expression
    jsr INTEGB          ; make sure it's an integer

    ldy zpAECUR         ; get AE cursor offset
    iny                 ; point after GOTO or GOSUB
    sty zpCURSOR        ; and update LINE cursor offset

    cpx #tknGOTO
    beq ONOK            ; jump if next token is GOTO

    cpx #tknGOSUB
    bne ONER            ; 'ON syntax' error if it's neither GOTO nor GOSUB

ONOK:
    txa
    pha                 ; Save GOTO/GOSUB token

    lda zpIACC+1        ; check all but the LSB of IACC
    ora zpIACC+2
    ora zpIACC+3
    bne ONRG            ; ON > 255 - out of range, look for an ELSE

    ldx zpIACC
    beq ONRG            ; ON zero - out of range, look for an ELSE

    dex                 ; decrement index
    beq ONGOT           ; if zero use first destination

; IACC+1..3 are 0

    ldy zpCURSOR        ; get line offset into Y

ONSRCH:
    lda (zpLINE),Y      ; get next character
    iny
    cmp #$0D
    beq ONRG            ; End of line - error

    cmp #':'
    beq ONRG            ; End of statement - error

    cmp #tknELSE
    beq ONRG            ; ELSE - drop everything else to here

    cmp #','
    bne ONSRCH          ; No comma, keep looking

    dex
    bne ONSRCH          ; Comma found, loop until count decremented to zero

    sty zpCURSOR        ; store LINE offset

ONGOT:
    jsr GOFACT          ; Read line number

    pla                 ; Get stacked token back
    cmp #tknGOSUB
    beq ONGOS           ; Jump to do GOSUB

    jsr SECUR           ; Update LINE offset and check Escape

    jmp GODONE          ; Jump to do GOTO

; Update line pointer so RETURN comes back to next statement
; ----------------------------------------------------------

; Find the colon or CR at the end of the statement

ONGOS:
    ldy zpCURSOR       ; Get line pointer

ONSKIP:
    lda (zpLINE),Y     ; Get character from line
    iny
    cmp #$0D
    beq SKIPED         ; End of line, RETURN to here

    cmp #':'
    bne ONSKIP         ; <colon>, return to here

SKIPED:
    dey                ; Update LINE offset to RETURN point
    sty zpCURSOR

    jmp ONGOSB         ; Jump to do the GOSUB

; ON num out of range - check for an ELSE clause
; ----------------------------------------------

ONRG:
    ldy zpCURSOR      ; get line offset
    pla               ; drop GOTO/GOSUB token

ONELSE:
    lda (zpLINE),Y    ; get next character from line
    iny
    cmp #tknELSE
    beq ONELS         ; found ELSE, jump to use it

    cmp #$0D
    bne ONELSE        ; loop until end of line

    brk
    dta $28, tknON, ' range', 0

ONELS:
    sty zpCURSOR        ; store LINE offset
    jmp THENLN          ; jump to THEN code

GOFACT:
    jsr SPTSTN          ; get line number
    bcs GOTGO           ; jump if line number was found

    jsr AEEXPR          ; evaluate expression
    jsr INTEGB          ; ensure it's an integer integer

    lda zpAECUR         ; copy AE offset
    sta zpCURSOR        ; to LINE offset

    lda zpIACC+1        ; make sure line number does not exceed 32767
    and #$7F
    sta zpIACC+1        ; Note - this makes goto $8000+10 the same as goto 10
                        ; try 10 PRINT "BBC"   20 GOTO 32768+10

GOTGO:
    jsr FNDLNO          ; search line number
    bcs NOLINE          ; 'No such line' error if it's not found

    rts

NOLINE:
    brk
    dta $29, 'No such line', 0

; ----------------------------------------------------------------------------

INPUHD:
    jmp LETM        ; 'Type mismatch' error

INPUHE:
    jmp STDED       ; 'Syntax error' error

INPUHX:
    sty zpCURSOR    ; store LINE cursor offset

    jmp DONEXT      ; jump to main loop

; INPUT#channel, ...
; ------------------

INPUTH:
    dec zpCURSOR

    jsr AECHAN      ; evaluate file handle expression, returns in Y and A

    lda zpAECUR
    sta zpCURSOR    ; update LINE offset from AE offset

    sty zpCOEFP     ; save the handle

INPUHL:
    jsr SPACES      ; skip spaces and get next character

    cmp #','
    bne INPUHX      ; exit if it's not a comma

    lda zpCOEFP     ; get file handle
    pha             ; save on machine stack

    jsr CRAELV      ; get the variable name

    beq INPUHE      ; 'Syntax error' if it's invalid

    lda zpAECUR
    sta zpCURSOR    ; update LINE cursor from AE cursor

    pla             ; retrieve file handle
    sta zpCOEFP     ; and store it again

    php             ; save status

    jsr PHACC       ; push IACC to the stack (variable address and type)

    ldy zpCOEFP     ; get file handle

    jsr OSBGET      ; call MOS, get byte indicating the type from media

    sta zpTYPE      ; save the type

    plp             ; restore status flags
    bcc INPUHN      ; jump if variable is numeric

    lda zpTYPE      ; get type of data on the media
    bne INPUHD      ; 'Type mismatch' error if the quantity is not a string

    jsr OSBGET      ; get byte from media (string length)

    sta zpCLEN      ; store as string length

    tax             ; length in X
    beq INPUHS      ; exit if string length is zero

INPUHT:
    jsr OSBGET      ; get byte from media

    sta STRACC-1,X  ; store in string buffer

    dex
    bne INPUHT      ; loop for string length number of bytes

INPUHS:
    jsr STSTOR      ; assign the string

    jmp INPUHL      ; go back for the next variable

INPUHN:
    lda zpTYPE      ; get type of data on the media
    beq INPUHD      ; 'Type mismatch' if it's a string
    bmi INPUHF      ; jump if it's a floating point

    ; it's an integer

    ldx #$03        ; loop 3..0

INPUHI:
    jsr OSBGET      ; get byte from media

    sta zpIACC,X    ; store in IACC
    dex
    bpl INPUHI      ; loop for all four bytes

    bmi INPUHJ      ; branch always, join the floating point code

INPUHF:
    ldx #$04        ; loop 4..0

INPUHR:
    jsr OSBGET      ; get byte from the media

    sta FWSA,X      ; store in Floating point WorkSpace area A
    dex
    bpl INPUHR      ; loop for all five bytes

    jsr LDARGA      ; unpack FWSA to FACC

INPUHJ:
    jsr STORE       ; assign to the variable

    jmp INPUHL      ; jump back for the next variable name

; ----------------------------------------------------------------------------

INOUT:
    pla             ; fix stack
    pla

    jmp DONEXT      ; jump to main execution loop

; INPUT [LINE] [print items][variables]
; =====================================

INPUT:
    jsr SPACES      ; skip spaces, and get next character

    cmp #'#'
    beq INPUTH      ; if '#' jump to do INPUT#

    cmp #tknLINE
    beq INLIN       ; if 'LINE', skip next with carry set

    dec zpCURSOR    ; one step back
    clc             ; clear carry

INLIN:
    ror zpCOEFP
    lsr zpCOEFP     ; bit7 = 0, bit6 = not LINE / LINE flag, can now be
                    ; tested with the overflow flag

    lda #$FF        ; set other flag to $ff
    sta zpCOEFP+1

INPLP:
    jsr PRTSTN      ; Process ' " TAB SPC
    bcs INPHP       ; jump if none found

INPLO:
    jsr PRTSTN
    bcc INPLO       ; Keep processing any print items

    ldx #$FF
    stx zpCOEFP+1
    clc             ; clear carry to indicate an item was found, no '?' needed

INPHP:
    php             ; save carry
    asl zpCOEFP     ; clear bit 7
    plp             ; restore carry
    ror zpCOEFP     ; rotate into bit 7 of flag register

    cmp #','
    beq INPLP       ; ',' - jump to do next item

    cmp #';'
    beq INPLP       ; ';' - jump to do next item

    dec zpCURSOR    ; not found comma, or semicolon

    lda zpCOEFP     ; save flags on machine stack
    pha
    lda zpCOEFP+1
    pha

    jsr CRAELV      ; get the name of the variable
    beq INOUT       ; exit if the variable is invalid

    pla             ; restore flags
    sta zpCOEFP+1
    pla
    sta zpCOEFP

    lda zpAECUR
    sta zpCURSOR    ; update CURSOR position

    php             ; save status of variable name

    bit zpCOEFP     ; check flags
    bvs INGET       ; jump if LINE option is used (bit 6)

    lda zpCOEFP+1
    cmp #$FF
    bne INGOT       ; jump if there are left-over characters from before

INGET:
    bit zpCOEFP     ; check flags
    bpl INGETA      ; skip printing '?' if bit 7 is clear

    lda #'?'
    jsr CHOUT       ; print '?'

INGETA:
    jsr INLINE      ; input string to string buffer

    sty zpCLEN      ; save the length of the string

    asl zpCOEFP     ; clear bit 7 of flags
    clc
    ror zpCOEFP     ; indicate that a prompt is not required for next variable

    bit zpCOEFP
    bvs INGETB      ; jump if LINE mode bit is set

INGOT:
    sta zpAECUR     ; store AE cursor position

    lda #<STRACC    ; point AELINE to string buffer
    sta zpAELINE
    lda #>STRACC
    sta zpAELINE+1

    jsr DATAST      ; move string down to beginning of string buffer

INTERM:
    jsr AESPAC      ; skip spaces and get next character

    cmp #','
    beq INGETC      ; jump if it's a comma

    cmp #$0D
    bne INTERM      ; loop if it's not CR/EOL

    ldy #$FE        ; prime Y with $fe

INGETC:
    iny
    sty zpCOEFP+1   ; store "offset" of next character

INGETB:
    plp             ; retrieve the status of the variable name
    bcs INPSTR      ; jump if it was a string

    jsr PHACC       ; push IACC, save address and type of variable to stack
    jsr VALSTR      ; convert string to a number
    jsr STORE       ; assign to the variable

    jmp INPLP       ; go back for next item

INPSTR:
    lda #$00
    sta zpTYPE      ; set type to string

    jsr STSTRE      ; assign string to variable

    jmp INPLP       ; go back for next item

; ----------------------------------------------------------------------------

; RESTORE [linenum]
; =================

RESTORE:
    ldy #$00
    sty zpWORK+6    ; Set DATA pointer to PAGE
    ldy zpTXTP
    sty zpWORK+7

    jsr SPACES      ; skip spaces, and get next character

    dec zpCURSOR    ; step back

    cmp #':'
    beq RESDON      ; skip searching for line number if next character is ':'

    cmp #$0D
    beq RESDON      ; or CR/EOL

    cmp #tknELSE
    beq RESDON      ; or token ELSE

    jsr GOFACT      ; get line number, address will be in WORK+6/7

    ldy #$01
    jsr CLYADW      ; add 1 to WORK+6/7 pointer, hopefully pointing to
                    ; DATA token

RESDON:
    jsr DONE        ; check for the end of the statement

    lda zpWORK+6    ; copy to DATA pointer
    sta zpDATAP
    lda zpWORK+7
    sta zpDATAP+1

    jmp NXT         ; jump to main loop

; ----------------------------------------------------------------------------

READS:
    jsr SPACES      ; skip spaces, and get next character

    cmp #','
    beq READ        ; READ the next item if it's a comma

    jmp SUNK        ; exit to main loop

; READ varname [,...]
; ===================

READ:
    jsr CRAELV      ; get the address and type of the variable name

    beq READS       ; if the variable is invalid, go back and check for comma
    bcs READST      ; jump if the variable is a string

    jsr DATAIT      ; point to the next DATA item
    jsr PHACC       ; push IACC, save address and type of variable
    jsr STEXPR      ; assign the value to the variable

    jmp READEN      ; jump to common end of READ

READST:
    jsr DATAIT      ; point to the next DATA item
    jsr PHACC       ; push IACC, save address and type of variable
    jsr DATAST      ; read string into string buffer

    sta zpTYPE      ; store zero to TYPE, indicating a string is in the buffer

    jsr STSTOR      ; assign the string to the variable

READEN:
    clc             ; updata DATA pointer
    lda zpAECUR
    adc zpAELINE
    sta zpDATAP
    lda zpAELINE+1
    adc #$00
    sta zpDATAP+1

    jmp READS       ; go back and searcg for another variable name

; Point to the next DATA item
; on exit, AELINE points to the comma or DATA token before the next item.

DATAIT:
    lda zpAECUR
    sta zpCURSOR    ; update LINE cursor

    lda zpDATAP     ; copy DATAP to AELINE pointer
    sta zpAELINE
    lda zpDATAP+1
    sta zpAELINE+1

    ldy #$00
    sty zpAECUR     ; reset AE cursor

    jsr AESPAC      ; skip spaces, and get next character

    cmp #','
    beq DATAOK      ; it's ok, we found a comma

    cmp #tknDATA
    beq DATAOK      ; or a DATA token

    cmp #$0D
    beq DATANX      ; jump if CR/EOL was found

DATALN:
    jsr AESPAC      ; skip spaces, and get the next character

    cmp #','
    beq DATAOK      ; jump if it's a comma

    cmp #$0D
    bne DATALN      ; repeat until EOL/CR is found

    ; CR was found

DATANX:
    ldy zpAECUR
    lda (zpAELINE),Y    ; get LSB of line number
    bmi DATAOT          ; 'Out of DATA' error if end of program is encountered

    iny                 ; skip
    iny
    lda (zpAELINE),Y    ; get length of the line
    tax                 ; into X

DATANS:
    iny
    lda (zpAELINE),Y    ; get next character
    cmp #' '
    beq DATANS          ; skip any spaces

    cmp #tknDATA
    beq DATAOL          ; DATA token found, exit

    txa                 ; add length of line, go to the next line
    clc
    adc zpAELINE
    sta zpAELINE
    bcc DATANX          ; keep searching for DATA

    inc zpAELINE+1
    bcs DATANX          ; keep searching for DATA

DATAOT:
    brk
    dta $2A, 'Out of ', tknDATA
    ; brk overlap
NODOS:
    brk
    dta $2B, 'No ', tknREPEAT, 0

DATAOL:
    iny             ; increment pointer to the token for the word DATA
    sty zpAECUR     ; store as AE cursor offset

DATAOK:
    rts

; ----------------------------------------------------------------------------

; UNTIL numeric
; =============

UNTIL:
    jsr AEEXPR      ; evaluate condition for loop end
    jsr FDONE       ; check for the end of the statement
    jsr INTEG       ; ensure condition is an integer

    ldx zpDOSTKP
    beq NODOS       ; 'No REPEAT' error if REPEAT stack is empty

    lda zpIACC
    ora zpIACC+1
    ora zpIACC+2
    ora zpIACC+3
    beq REDO        ; jump to repeat body if condition is zero

    dec zpDOSTKP    ; otherwise, decrement REPEAT stack pointer

    jmp NXT         ; jump to main loop

REDO:
    ldy DOADL-1,X   ; load YA with address from top of REPEAT stack
    lda DOADH-1,X

    jmp JUMPAY      ; copy YA to LINE pointer, and go back to main loop

; ----------------------------------------------------------------------------

DODP:
    brk
    dta $2C, 'Too many ', tknREPEAT, 's', 0

; ----------------------------------------------------------------------------

; REPEAT
; ======

REPEAT:
    ldx zpDOSTKP    ; check REPEAT stack pointer
    cpx #cDOTOP
    bcs DODP        ; 'Too many REPEATs' error if stack is full

    jsr CLYADP      ; update LINE pointer to point after REPEAT token and
                    ; check 'Escape' flag

    lda zpLINE      ; save current address at the repeat stack, beging of body
    sta DOADL,X
    lda zpLINE+1
    sta DOADH,X

    inc zpDOSTKP    ; increment stack pointer

    jmp STMT        ; go back to main execution loop

; ----------------------------------------------------------------------------

; Input string to string buffer
; -----------------------------

INLINE:
    ldy #<STRACC    ; address of string buffer in YA
    lda #>STRACC
    bne BUFFA

; Print character, read input line
; --------------------------------

BUFF:
    jsr CHOUT       ; Print character
    ldy #<BUFFER
    lda #>BUFFER

BUFFA:
    sty zpWORK      ; 0 for both STRACC and BUFFER, could save a load here
    sta zpWORK+1    ; zpWORK points to input buffer

; BBC - Call MOS to read a line
; -----------------------------
    .ifdef MOS_BBC
        lda #$EE
        sta zpWORK+2      ; Maximum length
        lda #$20
        sta zpWORK+3      ; Lowest acceptable character
        ldy #$FF
        sty zpWORK+4      ; Highest acceptable character
        iny               ; Y = 0
        ldx #zpWORK       ; YX points to control block at zpWORK
        tya               ; A = 0
        jsr OSWORD        ; Call OSWORD 0 to read line of text
        bcc BUFEND        ; CC, Escape not pressed, exit and set COUNT=0
    .endif
    jmp DOBRK         ; carry set, Escape pressed

; ----------------------------------------------------------------------------

; Move to a new line

NLINE:
    jsr OSNEWL

BUFEND:
    lda #$00
    sta zpTALLY          ; Set COUNT to zero
    rts

; ----------------------------------------------------------------------------

; Removes line whose number is in IACC
; Exit with carry set if it does not exist

REMOVE:
    jsr FNDLNO      ; search for the line
    bcs REMOVX      ; exit if it does not exist

    lda zpWORK+6    ; step WORK+6/7 back to line start
    sbc #$02
    sta zpWORK      ; also store in WORK
    sta zpWORK+6
    sta zpTOP       ; and TOP

    lda zpWORK+7    ; handle all MSBs
    sbc #$00
    sta zpWORK+1
    sta zpTOP+1
    sta zpWORK+7

    ldy #$03        ; get length of the line
    lda (zpWORK),Y
    clc
    adc zpWORK      ; and add it to the WORK pointer
    sta zpWORK
    bcc MOVEA

    inc zpWORK+1

MOVEA:
    ldy #$00        ; point to first character of the following line

MOVEB:
    lda (zpWORK),Y  ; get first character for next line
    sta (zpTOP),Y   ; copy to current line
    cmp #$0D
    beq MOVED       ; stop provessing when CR is encountered

MOVEC:
    iny
    bne MOVEB       ; loop copying next line to current

    ; increment MSBs if Y wraps to zero

    inc zpWORK+1
    inc zpTOP+1
    bne MOVEB       ; keep copying

MOVED:
    iny             ; increment past CR
    bne MOVEE

    inc zpWORK+1    ; MSBs again if Y wraps
    inc zpTOP+1

MOVEE:
    lda (zpWORK),Y  ; copy MSB of line number of next line
    sta (zpTOP),Y
    bmi MOVEF       ; or exit if it indicates end of program

    jsr MOVEG       ; update pointers and copy LSB of line number
    jsr MOVEG       ; update pointers and copy line length
    jmp MOVEC       ; loop to continue the process

MOVEF:
    jsr CLYADT      ; update TOP
    clc             ; clear carry means success

REMOVX:
    rts

MOVEG:
    iny             ; increment offset
    bne MOVEH

    inc zpTOP+1     ; and MSBs if required
    inc zpWORK+1

MOVEH:
    lda (zpWORK),Y  ; copy a single byte
    sta (zpTOP),Y
    rts

; ----------------------------------------------------------------------------

; Insert a line into the program
; ==============================
; On entry, IACC contains the line number, and Y must contain the offset
; into the keyboard buffer of the first textual character of the line,
; ignoring the line number.

INSRT:
    sty zpWORK+4        ; save the offset
    jsr REMOVE          ; find old line and remove it

                        ; WORK+6/7 has been set to the location where the
                        ; line was, or where it should go

    ldy #>BUFFER
    sty zpWORK+5        ; set MSB of pointer in WORK+4/5

    ldy #$00
    lda #$0D
    cmp (zpWORK+4),Y
    beq INSRTX          ; exit if first character is CR/EOL (only deletes line)

LENGTH:
    iny                 ; increment offset relative to start of text
    cmp (zpWORK+4),Y
    bne LENGTH          ; keep incrementing until CR is reached

    iny
    iny
    iny                 ; Y += 3, space for line number and line length

    sty zpWORK+8        ; store
    inc zpWORK+8        ; increment again (but not Y) to allow CR

    lda zpTOP           ; make WORK+2/3 point to TOP
    sta zpWORK+2
    lda zpTOP+1
    sta zpWORK+3

    jsr CLYADT          ; update TOP with Y

    sta zpWORK          ; get new value of TOP into WORK+0/1
    lda zpTOP+1
    sta zpWORK+1

    dey
    lda zpHIMEM         ; compare new TOP with HIMEM
    cmp zpTOP
    lda zpHIMEM+1
    sbc zpTOP+1
    bcs MOVEUP          ; jump if there's enough room

    jsr ENDER           ; check for 'Bad program'
    jsr SETFSA          ; carry out a CLEAR operation

    brk
    dta 0, tknLINE, ' space', 0

; ----------------------------------------------------------------------------

MOVEUP:
    lda (zpWORK+2),Y    ; move the top byte up to make room
    sta (zpWORK),Y
    tya                 ; check Y for zero
    bne LOW             ; jump if not

    dec zpWORK+3        ; decrement MSBs of the pointers
    dec zpWORK+1

LOW:
    dey                 ; decrement offset
    tya                 ; add offset to pointer
    adc zpWORK+2        ; LSB of addition in A
    ldx zpWORK+3        ; MSB of addition in X
    bcc LOWW

    inx                 ; increment MSB in X when A generated carry

LOWW:
    cmp zpWORK+6        ; compare with start address of the line
    txa
    sbc zpWORK+7
    bcs MOVEUP          ; if enough bytes have not been moved, continue moving

    sec
    ldy #$01
    lda zpIACC+1        ; copy line number
    sta (zpWORK+6),Y
    iny
    lda zpIACC
    sta (zpWORK+6),Y

    iny
    lda zpWORK+8        ; copy line length
    sta (zpWORK+6),Y

    jsr CLYADWP1        ; add Y to WORK+6/7 pointer

    ldy #$FF            ; initialize Y, taken first iny of loop into account

INSLOP:
    iny
    lda (zpWORK+4),Y    ; copy line from buffer to program
    sta (zpWORK+6),Y
    cmp #$0D
    bne INSLOP          ; loop until CR is reached

INSRTX:
    rts

; ----------------------------------------------------------------------------

; RUN
; ===

RUN:
    jsr DONE        ; check for the end of the statement

RUNNER:
    jsr SETFSA      ; clear variable catalogue and various stacks

    lda zpTXTP
    sta zpLINE+1    ; Point zpLINE to PAGE
    stx zpLINE

    jmp RUNTHG      ; execute from there onwards

; ----------------------------------------------------------------------------

; Clear variables and various stacks
; ==================================

SETFSA:
    lda zpTOP       ; set LOMEM and VARTOP to TOP
    sta zpLOMEM
    sta zpFSA
    lda zpTOP+1
    sta zpLOMEM+1
    sta zpFSA+1

    jsr SETVAR      ; Clear DATA pointer and stacks

SETVAL:
    ldx #$80        ; 128 bytes to be cleared
    lda #$00

SETVRL:
    sta VARPTR-1,X  ; Clear dynamic variables list
    dex
    bne SETVRL

    rts

; ----------------------------------------------------------------------------

; Clear DATA pointer and BASIC stacks

SETVAR:
    lda zpTXTP
    sta zpDATAP+1       ; set DATA pointer MSB to PAGE

    lda zpHIMEM         ; set Arithmetic Expression stack pointer to HIMEM
    sta zpAESTKP
    lda zpHIMEM+1
    sta zpAESTKP+1

    lda #$00
    sta zpDOSTKP        ; Clear REPEAT, FOR, GOSUB stacks
    sta zpFORSTP
    sta zpSUBSTP
    sta zpDATAP         ; clear DATA pointer MSB

    rts                 ; always return with A=0

; ----------------------------------------------------------------------------

; Push FACC onto the AE stack

PHFACC:
    lda zpAESTKP        ; lower the stack pointer five bytes
    sec
    sbc #$05
    jsr HIDEC           ; store new BASIC stack pointer, check for No Room

    ldy #$00
    lda zpFACCX
    sta (zpAESTKP),Y    ; save the exponent

    iny
    lda zpFACCS         ; tidy up sign
    and #$80
    sta zpFACCS

    lda zpFACCMA        ; combine MSB of mantissa with sign
    and #$7F
    ora zpFACCS
    sta (zpAESTKP),Y    ; and save

    iny
    lda zpFACCMB
    sta (zpAESTKP),Y    ; save rest of mantissa

    iny
    lda zpFACCMC
    sta (zpAESTKP),Y

    iny
    lda zpFACCMD
    sta (zpAESTKP),Y

    rts

; ----------------------------------------------------------------------------

; Pop the stack and set ARGP to point to the entry

POPSET:
    lda zpAESTKP
    clc
    sta zpARGP          ; save current stack pointer in ARGP
    adc #$05            ; add 5 to pop the floating point value
    sta zpAESTKP        ; and save the new stack pointer

    lda zpAESTKP+1
    sta zpARGP+1        ; save old MSB in ARGP+1
    adc #$00
    sta zpAESTKP+1      ; store new MSB

    rts

; ----------------------------------------------------------------------------

; Push integer, floating point or string to the AE stack
; ======================================================
; On entry, A contains the type
; It pushes either IACC, FACC, or the string in STRACC to the AE stack

PHTYPE:
    beq PHSTR           ; if type is zero, push string
    bmi PHFACC          ; if bit 7 is set, push FACC

; Push Integer ACC to stack

PHACC:
    lda zpAESTKP
    sec
    sbc #$04            ; subtract 4 from stack pointer to make room for int

    jsr HIDEC           ; store new BASIC stack pointer, check for No Room

    ldy #$03            ; bytes 3..0

    lda zpIACC+3
    sta (zpAESTKP),Y    ; copy integer onto the stack

    dey
    lda zpIACC+2
    sta (zpAESTKP),Y

    dey
    lda zpIACC+1
    sta (zpAESTKP),Y

    dey
    lda zpIACC
    sta (zpAESTKP),Y    ; and finally the LSB

    rts

; ----------------------------------------------------------------------------

; Push string in string buffer to AE stack

PHSTR:
    clc               ; extra -1
    lda zpAESTKP
    sbc zpCLEN        ; subtract string length + 1 from stack pointer
    jsr HIDEC         ; store new BASIC stack pointer, check for No Room

    ldy zpCLEN
    beq PHSTRX        ; Zero length, just stack length

PHSTRL:
    lda STRACC-1,Y
    sta (zpAESTKP),Y  ; Copy string to stack
    dey
    bne PHSTRL        ; Loop for all characters

PHSTRX:
    lda zpCLEN
    sta (zpAESTKP),Y  ; Copy string length

    rts

; ----------------------------------------------------------------------------

; Pop string from AE to string buffer

POPSTR:
    ldy #$00
    lda (zpAESTKP),Y    ; Get stacked string length
    sta zpCLEN
    beq POPSTX          ; If zero length, just unstack length

    tay

POPSTL:
    lda (zpAESTKP),Y
    sta STRACC-1,Y      ; Copy string to string buffer
    dey
    bne POPSTL          ; Loop for all characters

POPSTX:
    ldy #$00
    lda (zpAESTKP),Y    ; Get string length again
    sec

POPN:
    adc zpAESTKP
    sta zpAESTKP        ; Update stack pointer
    bcc POPACI          ; silly to jump to rts that far away ;)

    inc zpAESTKP+1
                        ; could just as well jump to here
    rts

; ----------------------------------------------------------------------------

; Pop integer from AE stack into Integer ACC (IACC)

POPACC:
    ldy #$03            ; copy four bytes (3..0)
    lda (zpAESTKP),Y
    sta zpIACC+3

    dey
    lda (zpAESTKP),Y
    sta zpIACC+2

    dey
    lda (zpAESTKP),Y
    sta zpIACC+1

    dey
    lda (zpAESTKP),Y
    sta zpIACC

POPINC:
    clc
    lda zpAESTKP          ; Adjust stack pointer, drop 4 bytes
    adc #$04
    sta zpAESTKP
    bcc POPACI

    inc zpAESTKP+1

POPACI:
    rts

; ----------------------------------------------------------------------------

; Pop an integer to zpWORK

POPWRK:
    ldx #zpWORK

; Use X as Index, jsr here to override X (i.e. ldx #zpWORK+8, jsr POPX)

POPX:
    ldy #$03            ; copy four bytes (3..0)
    lda (zpAESTKP),Y
    sta 0+3,X

    dey
    lda (zpAESTKP),Y
    sta 0+2,X

    dey
    lda (zpAESTKP),Y
    sta 0+1,X

    dey
    lda (zpAESTKP),Y
    sta 0+0,X

    clc
    lda zpAESTKP
    adc #$04
    sta zpAESTKP          ; Drop 4 bytes from stack
    bcc POPACI

    inc zpAESTKP+1

    rts

; ----------------------------------------------------------------------------

; Store new AE stack pointer and check for 'No room'

HIDEC:
    sta zpAESTKP
    bcs HIDECA

    dec zpAESTKP+1

HIDECA:
    ldy zpAESTKP+1
    cpy zpFSA+1
    bcc HIDECE          ; jump to 'No room'
    bne HIDECX

    cmp zpFSA
    bcc HIDECE          ; jump to 'No room'

HIDECX:
    rts

HIDECE:
    jmp ALLOCR          ; 'No room' error message

; ----------------------------------------------------------------------------

; Copy IACC to somewhere on page zero
; -----------------------------------
; On entry, X contains the offset of the destination address relative to
; the base of our zero page block of variables and pointers

ACCTOM:
    lda zpIACC
    sta 0+0,X
    lda zpIACC+1
    sta 0+1,X
    lda zpIACC+2
    sta 0+2,X
    lda zpIACC+3
    sta 0+3,X
    rts

; ----------------------------------------------------------------------------

; Add Y to WORK+6/7

CLYADW:
    clc

CLYADWP1:
    tya
    adc zpWORK+6
    sta zpWORK+6
    bcc CLYIDW

    inc zpWORK+7

CLYIDW:
    ldy #$01        ; always return 1 in Y
    rts

; ----------------------------------------------------------------------------

; Load a new program
; ==================
; Notice that this routine ends with 'rts'
; Parameter block is at WORK and onwards

LOADER:
    jsr OSTHIG          ; setup the parameter block, FILE.LOAD = PAGE

    tay
    lda #$FF

    .ifdef MOS_BBC
        sty F_EXEC+0    ; FILE.EXEC=0, load to specified address
        ldx #zpWORK
        jsr OSFILE
    .endif

; Scan program to check consistancy and find TOP
; ----------------------------------------------

ENDER:
    lda zpTXTP        ; TOP = PAGE
    sta zpTOP+1
    ldy #$00
    sty zpTOP

    iny               ; allow for first dey in loop below

; find new TOP

FNDTOP:
    dey
    lda (zpTOP),Y     ; Get byte preceding line
    cmp #$0D
    bne BADPRO        ; Not <cr>, jump to 'Bad program'

    iny               ; Step to line number/terminator
    lda (zpTOP),Y
    bmi SETTOP        ; bit 7 set, end of program

    ldy #$03          ; Point to line length
    lda (zpTOP),Y
    beq BADPRO        ; Zero length, jump to 'Bad program'

    clc
    jsr CLYADTP1      ; Update TOP to point to next line

    bne FNDTOP        ; Loop to check next line

; End of program found, set TOP

SETTOP:
    iny               ; step past end of program marker
    clc

CLYADT:
    tya

CLYADTP1:
    adc zpTOP        ; add final offset to TOP
    sta zpTOP        ; and store
    bcc ENDADT

    inc zpTOP+1     ; adjust MSB in case of carry

ENDADT:
    ldy #$01        ; return with Y=1, Z=0
    rts

; Report 'Bad program' and jump to immediate mode

BADPRO:
    jsr VSTRNG              ; Print inline text
    dta 13                  ; CR
    dta 'Bad program'
    dta 13                  ; CR

    nop                     ; $ea, has bit 7 set, end of string marker
                            ; the nop is executed

    jmp CLRSTK              ; Jump to immediate mode

; ----------------------------------------------------------------------------

; Point zpWORK to <cr>-terminated string in string buffer
; ------------------------------------------------------

OSSTRG:
    lda #<STRACC
    sta zpWORK
    lda #>STRACC
    sta zpWORK+1

; Place <CR> at end of string

OSSTRT:
    ldy zpCLEN
    lda #$0D
    sta STRACC,Y

    rts                 ; returns with A=$0d and Y=string length

; ----------------------------------------------------------------------------

; OSCLI string$ - Pass string to OSCLI to execute
; ===============================================

OSCL:
    jsr OSTHIF         ; evaluate string argument and add CR at the END

    .ifdef MOS_BBC
        ldx #$00
        ldy #>(STRACC)
        jsr OS_CLI
        jmp NXT           ; Call OSCLI and return to execution loop
    .endif

OSTHIE:
    jmp LETM            ; 'Type mismatch' error

; ----------------------------------------------------------------------------

; Evaluate string argument and add CR at the END

OSTHIF:
    jsr AEEXPR          ; evaluate expression
    bne OSTHIE          ; error if not string
    jsr OSSTRG          ; convert to CR terminated string
    jmp FDONE           ; check end of statement, exit, tail call

; ----------------------------------------------------------------------------

; Set FILE.LOAD to PAGE
; ---------------------

OSTHIG:
    jsr OSTHIF          ; evaluate string argument and add CR at the END

    dey
    sty F_LOAD+0        ; LOAD.lo = $00
    lda zpTXTP
    sta F_LOAD+1        ; LOAD.hi = PAGEhi

GETMAC:
    .ifdef MOS_BBC
        lda #$82
        jsr OSBYTE      ; Get memory base high word
        stx F_LOAD+2
        sty F_LOAD+3    ; Set LOAD high word
        lda #$00
    .endif
    rts

; BBC At/Sy
; 37   37   FNAME   zpWORK
; 38
; 39   39   LOAD
; 3A
; 3B
; 3C
; 3D   3B   EXEC
; 3E
; 3F
; 40
; 41   3D   START
; 42
; 43
; 44
; 45   3F   END
; 46
; 47
; 48

; ----------------------------------------------------------------------------

;  SAVE string$
; =============

SAVE:
    jsr ENDER               ; Check program, set TOP

    jsr OSTHIG           ; Set FILE.LOAD to PAGE
    .ifdef MOS_BBC
        stx F_EXEC+2
        sty F_EXEC+3     ; Set address high words
        stx F_START+2
        sty F_START+3
        stx F_END+2
        sty F_END+3
        sta F_START+0    ; Low byte of FILE.START
    .endif
    ldx zpTOP
    stx F_END+0       ; Set FILE.END to TOP
    ldx zpTOP+1
    stx F_END+1
    ldx #<ENTRY
    stx F_EXEC+0      ; Set FILE.EXEC to STARTUP
    ldx #>ENTRY
    stx F_EXEC+1
    ldx zpTXTP
    stx F_START+1     ; High byte of FILE.START=PAGE
    tay
    ldx #zpWORK           ; YX pointer
    .ifdef MOS_BBC
        jsr OSFILE
    .endif
    jmp NXT

; ----------------------------------------------------------------------------

; LOAD string$
; ============

LOAD:
    jsr LOADER          ; load the new program
    jmp FSASET          ; jump to immediate mode, warm start

; ----------------------------------------------------------------------------

; CHAIN string$
; =============

CHAIN:
    jsr LOADER         ; Do LOAD
    jmp RUNNER         ; jump to execution loop

; ----------------------------------------------------------------------------

; PTR#numeric=numeric
; ===================

LPTR:
    jsr AECHAN          ; Evaluate file handle, returns in Y and A

    pha                 ; save it on the stack

    jsr EQEXPR          ; check '=' sign, and evaluate expression
    jsr INTEG           ; ensure the result is an integer

    pla                 ; retrieve file handle

    tay
    ldx #zpIACC         ; X points to new PTR value in IACC

    .ifdef MOS_BBC
        lda #$01
        jsr OSARGS
    .endif

    jmp NXT         ; Jump to execution loop

; ----------------------------------------------------------------------------

; =EXT#numeric - Read file pointer via OSARGS
; ===========================================

EXT:
    sec               ; Flag to do =EXT

; =PTR#numeric - Read file pointer via OSARGS
; ===========================================

RPTR:
    lda #$00
    rol               ; A=0 or 1 for =PTR or =EXT
    .ifdef MOS_BBC
        rol           ; A=0 or 2 for =PTR or =EXT
    .endif

    pha               ; push command to stack, Atom - A=0/1, BBC - A=0/2

    jsr CHANN         ; Evaluate file handle, returns in Y and A

    ldx #zpIACC       ; point to IACC, where to receive PTR or EXT

    pla               ; retrieve command from stack

    .ifdef MOS_BBC
        jsr OSARGS
    .endif

    lda #$40          ; return type is an integer
    rts

; ----------------------------------------------------------------------------

; BPUT#numeric, numeric
; =====================

BPUT:
    jsr AECHAN      ; Evaluate file handle, returns in Y and A

    pha             ; save file handle

    jsr COMEAT      ; skip the comma
    jsr EXPRDN      ; evaluate expression and check for end of statement
    jsr INTEG       ; ensure it's an integer

    pla             ; restore file handle

    tay
    lda zpIACC      ; low byte of IACC

    jsr OSBPUT

    jmp NXT         ; jump to execution loop

; ----------------------------------------------------------------------------

; =BGET#numeric
; =============

BGET:
    jsr CHANN         ; Evaluate file handle, returns in Y and A
    jsr OSBGET        ; Y is file handle, call OSBGET
    jmp SINSTK        ; Jump to return 8-bit integer

; ----------------------------------------------------------------------------

; OPENIN f$ - Call OSFIND to open file for input
; ==============================================

OPENIN:
    .ifdef MOS_BBC
        lda #$40      ; $40=OPENUP
        bne F
    .endif

; ----------------------------------------------------------------------------

; OPENOUT f$ - Call OSFIND to open file for output
; ================================================
OPENO:
    .ifdef MOS_BBC
        lda #$80      ; 80=OPENOUT
        bne F
    .endif

; ----------------------------------------------------------------------------

; OPENUP f$ - Call OSFIND to open file for update
; ===============================================
OPENI:
    .ifdef MOS_BBC
        lda #$C0      ; C0=OPENUP
    .endif
F:
    .ifdef MOS_BBC
        pha           ; save action
    .endif

    jsr FACTOR        ; evaluate expression
    bne OPENE         ; if not string, jump to error

    .ifdef MOS_BBC
        jsr OSSTRT     ; Terminate string with <cr>
        ldx #<STRACC   ; point YX to string buffer
        ldy #>STRACC
        pla            ; get action back
    .endif

    jsr OSFIND         ; Pass to OSFIND
    jmp SINSTK         ; return integer from A, exit, tail call

OPENE:
    jmp LETM           ; 'Type mismatch' error

; ----------------------------------------------------------------------------

; CLOSE#numeric
; =============

CLOSE:
    jsr AECHAN         ; evaluate file handle, returns in Y and A
    jsr AEDONE         ; check end of statement, clobbers Y

    ldy zpIACC         ; get handle from IACC, which should still be valid

    .ifdef MOS_BBC
        lda #$00
        jsr OSFIND
    .endif

    jmp NXT            ; Jump back to execution loop

; ----------------------------------------------------------------------------

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
    brk
    dta $2D, 'Missing #', 0

  .if .def TARGET_BBC
    .if * > [romstart + $4000]
        .error "***WARNING: Code overrun"
    .endif

    .if [[*+3]&$ff] > 3
        dta '3', '.', '1'
    .endif

    .if * > [romstart + $4000]
        .error "***WARNING: Code overrun"
    .endif

    .align romstart + $4000, 0
  .endif
END_OF_ROM:

; vi:syntax=mads
