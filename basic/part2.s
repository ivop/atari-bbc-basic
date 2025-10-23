
; Decode parameters for RENUMBER and AUTO

GETTWO:
    lda #10             ; default value
    jsr SINSTK          ; store in IACC

    jsr SPTSTN          ; decode first line number
    jsr PHACC           ; push to stack

    lda #10             ; second default value
    jsr SINSTK          ; store in IACC

    jsr SPACES
    cmp #','
    bne NO              ; no comma, no second parameter

    jsr SPTSTN          ; get second line number
    lda zpIACC+1
    bne GETYUK          ; 'Silly' error if interval > 255

    lda zpIACC
    beq GETYUK          ; 'Silly' if interval = 0

    inc zpCURSOR        ; pre-increment for next decrement

NO:
    dec zpCURSOR
    jmp DONE            ; check for end of statement, and return (tail call)

; called by renumber

RENSET:
    lda zpTOP           ; copy TOP ptr to zpWORK+4/5
    sta zpWORK+4
    lda zpTOP+1
    sta zpWORK+5

RENSTR:
    lda zpTXTP          ; copy PAGE ptr to zpWORK+0/1
    sta zpWORK+1
    lda #$01            ; plus 1
    sta zpWORK
    rts

; RENUMBER [linenume [,linenum]]
; ==============================

RENUM:
    jsr GETTWO          ; decode the parameters
    ldx #zpWORK+2
    jsr POPX            ; pull starting line number to zpWORK+2..5

    jsr ENDER           ; check for 'Bad program'
    jsr RENSET          ; set zpWORK+4/5 to TOP ptr

; Build up table of line numbers

NUMBA:
    ldy #$00
    lda (zpWORK),Y      ; get line number of current line in the program
    bmi NUMBB           ; MSB > $7F, end of program

    sta (zpWORK+4),Y    ; save the MSB of the number in the pile at TOP
    iny
    lda (zpWORK),Y
    sta (zpWORK+4),Y    ; similar for LSB

    sec                 ; adjust pointer
    tya
    adc zpWORK+4
    sta zpWORK+4

    tax
    lda zpWORK+5
    adc #$00
    sta zpWORK+5

    cpx zpHIMEM         ; check if pointer colides with HIMEM
    sbc zpHIMEM+1
    bcs NUMBFL          ; if so, 'RENUMBER space' error

    jsr STEPON          ; Y=1, move pointer to the next line, returns with C=0
    bcc NUMBA           ; always loop back to the next line

NUMBFL:
    brk
    dta 0, tknRENUMBER, ' space'      ; Terminated by following BRK

GETYUK:
    brk
    dta 0, 'Silly', 0

; Look for renumber references

NUMBB:
    jsr RENSTR              ; set zpWORK+0/1 to PAGE+1

NUMBC:
    ldy #$00
    lda (zpWORK),Y          ; get MSB of line number
    bmi NUMBD               ; exit if the end of the program has been reached

    lda zpWORK+3            ; update the line number
    sta (zpWORK),Y
    lda zpWORK+2
    iny
    sta (zpWORK),Y

    clc                     ; add interval to line number
    lda zpIACC
    adc zpWORK+2
    sta zpWORK+2

    lda #$00
    adc zpWORK+3
    and #$7F                ; assure it doesn't exceed 32767
    sta zpWORK+3

    jsr STEPON              ; move to the next line, returns with C=0
    bcc NUMBC               ; always loop for handling next line

NUMBD:
    lda zpTXTP              ; copy PAGE to zpLINE
    sta zpLINE+1
    ldy #$00
    sty zpLINE

    iny
    lda (zpLINE),Y          ; get MSB of line number of current line
    bmi NUMBX               ; exit if the end of the program has been reached

NUMBE:
    ldy #$04                ; point to the first byte of the text of the line

NUMBF:
    lda (zpLINE),Y          ; get byte of text of the line
    cmp #tknCONST
    beq NUMBG               ; jump if tknCONST was found

    iny                     ; point to next byte (in case bne is taken)
    cmp #$0D
    bne NUMBF               ; loop as long as CR is not found

    lda (zpLINE),Y
    bmi NUMBX               ; exit if the end of the program has been reached

    ldy #$03
    lda (zpLINE),Y          ; add length of the line to zpLINE pointer
    clc
    adc zpLINE
    sta zpLINE
    bcc NUMBE               ; branch always, loop

    inc zpLINE+1
    bcs NUMBE               ; branch always, loop

NUMBG:
    jsr SPGETN              ; decode the line number
    jsr RENSET              ; set zpWORK+4/5 to TOP, and zpWORK+0/1 to PAGE+1

NUMBH:
    ldy #$00
    lda (zpWORK),Y          ; get MSB of line number of current line
    bmi NUMBJ               ; exit if the end of the program has been reached

    lda (zpWORK+4),Y        ; get MSB of next line number in the pile
    iny                     ; Y=1
    cmp zpIACC+1            ; check against line number being sought
    bne NUMBI               ; skip forwards if they do not match

    lda (zpWORK+4),Y        ; same for the LSB
    cmp zpIACC
    bne NUMBI               ; jump if no match

    lda (zpWORK),Y          ; get line number
    sta zpWORK+6            ; and store it in zpWORK+6/7
    dey                     ; Y=0
    lda (zpWORK),Y
    sta zpWORK+7

    ldy zpCURSOR
    dey
    lda zpLINE              ; copy LINE pointer to WORK
    sta zpWORK
    lda zpLINE+1
    sta zpWORK+1

    jsr CONSTI              ; encode the line number and store it

NUMBFA:
    ldy zpCURSOR
    bne NUMBF               ; go back and continue the search

NUMBI:
    clc

    jsr STEPON              ; move to the next line

    lda zpWORK+4            ; add two to zpWORK+4/5
    adc #$02
    sta zpWORK+4
    bcc NUMBH               ; go back and look for the line number

    inc zpWORK+5
    bcs NUMBH               ; go back and look for the line number

NUMBX:
    bmi ENDAUT          ; jump to warm start

NUMBJ:
    jsr VSTRNG              ; Print inline text after this JSR
                            ; up to the first character with bit 7 set
    dta 'Failed at '

    iny                     ; opcode 0xc8 has bit 7 set, end of string marker

    lda (zpLINE),Y          ; get line number that couldn't be found
    sta zpIACC+1            ; into IACC
    iny
    lda (zpLINE),Y
    sta zpIACC

    jsr POSITE        ; Print in decimal
    jsr NLINE         ; Print newline
    beq NUMBFA        ; join the original code

STEPON:
    iny               ; make Y point to the byte giving the length of the line
    lda (zpWORK),Y    ; get the length
    adc zpWORK        ; add it to the pointer
    sta zpWORK        ; and store
    bcc STEPX

    inc zpWORK+1      ; adjust MSB if necessary
    clc

    ; always return with C=0

STEPX:
    rts

; ----------------------------------------------------------------------------

; AUTO [numeric [, numeric ]]
; ===========================
AUTO:
    jsr GETTWO      ; decode parameters

    lda zpIACC      ; save interval on machine stack
    pha
    jsr POPACC      ; get starting line number back

AUTOLP:
    jsr PHACC       ; save on AE stack
    jsr NPRN        ; print IACC using field width of five characters

    lda #' '
    jsr BUFF        ; get line of text with ' ' as the prompt

    jsr POPACC      ; pull lline number back
    jsr MATCH       ; tokenise the line
    jsr INSRT       ; insert the line into program
    jsr SETFSA      ; clear variable area and stacks

    pla             ; get interval back
    pha             ; and save for next loop
    clc
    adc zpIACC      ; add interval to current line number
    sta zpIACC
    bcc AUTOLP      ; loop to next line number

    inc zpIACC+1
    bpl AUTOLP      ; loop to next line number

    ; fallthrough if line number becomes >= 32768

ENDAUT:
    jmp FSASET      ; jump to warm start

; ----------------------------------------------------------------------------

; Code related to DIM, reserve space, and if necessary, create the
; variable indicated and adjust VARTOP

DIMSPR:
    jmp DIMRAM      ; jump to 'DIM space' error message

DIMSP:
    dec zpCURSOR
    jsr CRAELV      ; get the name of the variable
    beq NOTGO       ; give 'Bad DIM' error
    bcs NOTGO       ; if name is a string or invalid

    jsr PHACC       ; save the address of the variable
    jsr INEXPR      ; evaluate integer expression (number of bytes to reserve)
    jsr INCACC      ; increment by 1 for "zeroth" elementh

    lda zpIACC+3
    ora zpIACC+2
    bne NOTGO       ; 'Bad DIM' if attempting to reserve too much

    clc
    lda zpIACC      ; add LSB of reserved size to
    adc zpFSA       ; VARTOP's LSB
    tay             ; save in Y

    lda zpIACC+1    ; add MSB of reserved size to
    adc zpFSA+1     ; VARTOP's MSB
    tax             ; save in X

    cpy zpAESTKP    ; compare
    sbc zpAESTKP+1  ; with top of AE stack
    bcs DIMSPR      ; if there's not enough space, error with 'DIM space'

    lda zpFSA       ; save current VARTOP in IACC
    sta zpIACC
    lda zpFSA+1
    sta zpIACC+1

    sty zpFSA       ; store new VARTOP values
    stx zpFSA+1

    lda #$00        ; clear top 16-bits of 32-bit IACC
    sta zpIACC+2
    sta zpIACC+3

    lda #$40        ; set type to integer
    sta zpTYPE

    jsr STORE       ; assigne the variable
    jsr ASCUR       ; move CURSOR to AECUR
    jmp DIMNXT      ; join main DIM code

NOTGO:
    brk
    dta 10, 'Bad ', tknDIM, 0

; DIM numvar [numeric] [(arraydef)]
; =================================

DIM:
    jsr SPACES      ; skip any spaces after DIM keyword

    tya             ; get zpLINE offset (zpCURSOR) in A

    clc
    adc zpLINE      ; add offset to LINE pointer
    ldx zpLINE+1    ; MSB in X
    bcc DIMNNO

    inx             ; handle carry overflow, final MSB in X
    clc

DIMNNO:
    sbc #$00        ; we arrive here with C=0, so subtract 1
    sta zpWORK      ; store LSB in zpWORK
    txa             ; MSB to A
    sbc #$00        ; adjust for underflow
    sta zpWORK+1    ; store MSB in zpWORK+1

    ldx #$05        ; we start of with sizeof each element = 5 = floating point
    stx zpWORK+8

    ldx zpCURSOR
    jsr WORD        ; get the name of the array being defined

    cpy #$01        ; if Y still points to the first position
    beq NOTGO       ; jump to 'Bad DIM' error

    cmp #'('        ; first character after variable name
    beq DIMVAR      ; jump to dim floats

    cmp #'$'
    beq DIMINT      ; jump to dim int or string

    cmp #'%'
    bne DIMSPA      ; not ints, no '(', jump to dim space

DIMINT:
    dec zpWORK+8    ; decrement size of element to correspond to int and string
    iny             ; point to character after '%' or '$'
    inx
    lda (zpWORK),Y
    cmp #'('
    beq DIMVAR      ; jump to dim variable

DIMSPA:
    jmp DIMSP

DIMVAR:
    sty zpWORK+2    ; save length of the name
    stx zpCURSOR    ; set CURSOR to character after the name
    jsr LOOKUP      ; find the address of the variable
    bne NOTGO       ; error if variable is found (redimensioning not supported)

    jsr CREATE      ; create catalogue entry fo the array name

    ldx #$01        ; clear the single byte after the name, and make VARTOP
    jsr CREAX       ; to point after the zero byte terminating the name

    lda zpWORK+8    ; get number of bytes in each element
    pha             ; save on machine stack
    lda #$01        ; save the current offset into the subscript area
    pha             ; on the machine stack

    jsr SINSTK      ; set IACC to 1

RDLOOP:
    jsr PHACC       ; save IACC on BASIC stack
    jsr ASEXPR      ; evaluate the expression giving the (next) dimension

    lda zpIACC+1    ; check if subscript is greater than 16383
    and #$C0
    ora zpIACC+2
    ora zpIACC+3
    bne NOTGO       ; if so, jump to error

    jsr INCACC      ; increment IACC to allow for element zero

    pla             ; retrieve offset into subscript area
    tay
    lda zpIACC      ; save size in subscript area, LSB
    sta (zpFSA),Y
    iny
    lda zpIACC+1    ; idem, MSB
    sta (zpFSA),Y
    iny

    tya             ; save the pointer on the machine stack
    pha

    jsr SMUL        ; 16-bit multiply top of AE stack with IACC

    jsr SPACES      ; get the next character

    cmp #','
    beq RDLOOP      ; go back for the next subscript if it's a comma

    cmp #')'
    beq DIMGON      ; continue on closing bracket

    jmp NOTGO       ; 'Bad DIM' error

DIMGON:
    pla             ; offset into subscript storage area
    sta zpPRINTF
    pla             ; number of bytes per element
    sta zpWORK+8
    lda #$00
    sta zpWORK+9

    jsr WMUL        ; IACC = zpWORK+8/9 * IACC, total number of bytes required

    ldy #$00
    lda zpPRINTF    ; offset into subscript storage area
    sta (zpFSA),Y   ; store immediately after the zero following the name
    adc zpIACC      ; add this to the total number of bytes required
    sta zpIACC
    bcc NOHINC

    inc zpIACC+1

NOHINC:
    lda zpFSA+1     ; VARTOP to WORK
    sta zpWORK+1
    lda zpFSA
    sta zpWORK

    clc             ; add length of array to VARTOP
    adc zpIACC
    tay
    lda zpIACC+1
    adc zpFSA+1
    bcs DIMRAM      ; jump to 'DIM space' error

    tax             ; compare with AE stack pointer
    cpy zpAESTKP
    sbc zpAESTKP+1
    bcs DIMRAM      ; jump to 'DIM space' error

    sty zpFSA       ; store new VARTOP value
    stx zpFSA+1

    ; clear the just allocated area

    lda zpWORK
    adc zpPRINTF    ; add offset to first element
    tay
    lda #$00        ; A=0
    sta zpWORK
    bcc ZELOOP

    inc zpWORK+1

ZELOOP:
    sta (zpWORK),Y  ; A=0, clear
    iny
    bne ZELPA
    inc zpWORK+1

ZELPA:
    cpy zpFSA
    bne ZELOOP      ; clear loop
    cpx zpWORK+1
    bne ZELOOP      ; clear until VARTOP is reached

DIMNXT:
    jsr SPACES
    cmp #','
    beq DIMJ        ; skip exit

    jmp SUNK        ; exit

DIMJ:
    jmp DIM         ; go back and get the next array

DIMRAM:
    brk
    dta 11, tknDIM, ' space', 0

; ----------------------------------------------------------------------------

; TIME=numeric
; ============

LTIME:
    jsr INEQEX         ; Step past '=', evaluate integer
    .ifdef MOS_BBC
        ldx #zpIACC    ; YX = address of value, IACC
        ldy #$00       ; MSB always zero
        sty zpFACCS    ; set 5th byte to 0 (zpFACCS == zpIACC+4)
        lda #$02
        jsr OSWORD     ; Call OSWORD $02 to do TIME=
    .endif
    jmp NXT            ; Jump to execution loop

; ----------------------------------------------------------------------------

; Evaluate <comma><numeric>
; =========================

INCMEX:
    jsr COMEAT         ; Check for and step past comma

INEXPR:
    jsr EXPR           ; evaluate expression
    jmp INTEGB         ; check it is integer, tail call

; ----------------------------------------------------------------------------

; Evaluate <equals><integer>
; ==========================
INTFAC:
    jsr FACTOR         ; evaluate expression
    beq INTEGE         ; jump to 'Type mismatch' error
    bmi INTEGF         ; convert to int if it's a float

INTEGX:
    rts

INEQEX:
    jsr AEEQEX         ; Check for equals, evaluate numeric

INTEG:
    lda zpTYPE         ; Get result type

INTEGB:
    beq INTEGE         ; String, jump to 'Type mismatch'
    bpl INTEGX         ; Integer, return

INTEGF:
    jmp IFIX           ; Float, jump to convert to integer, tail call

INTEGE:
    jmp LETM           ; Jump to 'Type mismatch' error

; Evaluate <real>
; ===============

FLTFAC:
    jsr FACTOR         ; Evaluate expression

; Ensure value is float
; ---------------------

FLOATI:
    beq INTEGE         ; String, jump to 'Type mismatch'
    bmi INTEGX         ; float, return
    jmp IFLT           ; Integer, jump to convert to real

; ----------------------------------------------------------------------------

; PROCname [(parameters)]
; =======================
PROC:
    lda zpLINE
    sta zpAELINE      ; AELINE=LINE=>after 'PROC' token
    lda zpLINE+1
    sta zpAELINE+1
    lda zpCURSOR
    sta zpAECUR
    lda #tknPROC
    jsr FNBODY     ; Call PROC/FN dispatcher
                       ; Will return here after ENDPROC
    jsr AEDONE     ; Check for end of statement
    jmp NXT        ; Return to execution loop

; ----------------------------------------------------------------------------

; LOCAL routine(s)

LOCSTR:
    ldy #$03
    lda #$00           ; Set length to zero
    sta (zpIACC),Y
    beq LOCVAR         ; Jump to look for next LOCAL item

; LOCAL variable [,variable ...]
; ==============================
LOCAL:
    tsx
    cpx #$FC          ; at least four bytes should be on the machine stack
    bcs NLOCAL        ; Not inside subroutine, error

    jsr CRAELV        ; get next variable name
    beq LOCEND        ; jump if bad variable name

    jsr RETINF        ; Push value on stack, push variable info on stack

    ldy zpIACC+2      ; get type of variable
    bmi LOCSTR        ; If a string, jump to make zero length

    jsr PHACC         ; save descriptor on stack

    lda #$00          ; Set IACC to zero
    jsr SINSTK        ; returns with A=$40

    sta zpTYPE        ; set type to integer

    jsr STORE         ; Set current variable to IACC (zero)

; Next LOCAL item
; ---------------
LOCVAR:
    tsx
    inc $0106,X       ; Increment number of LOCAL items
                      ; machine will crash with too many
                      ; local variables and/or parameters

    ldy zpAECUR
    sty zpCURSOR      ; Update line pointer offset
    jsr SPACES        ; Get next character
    cmp #','
    beq LOCAL         ; Comma, loop back to do another item

    jmp SUNK          ; Jump to main execution loop

LOCEND:
    jmp DONEXT        ; jump to main loop

; ----------------------------------------------------------------------------

; ENDPROC
; =======
; Stack needs to contain these items:
;
; (top) ($01ff)
;   tknFN
;   zpCURSOR
;   zpLINE
;   zpLINE+1
;   number of parameters
;   zpAECUR
;   zpAELINE
;   zpAELINE+1
;   return address MSB
;   return address LSB
; (bottom)

ENDPR:
    tsx
    cpx #$FC        ; should be at least four bytes
    bcs NOPROC      ; If stack empty, jump to print error

    lda $01FF
    cmp #tknPROC
    bne NOPROC      ; If pushed token != 'PROC', print error

    jmp DONE        ; Check end of statement and return to pop from subroutine

NOPROC:
    brk
    dta 13, 'No ', tknPROC       ; Terminated by following BRK

NLOCAL:
    brk
    dta 12, 'Not ', tknLOCAL      ; Terminated by following BRK

MODESX:
    brk
    dta $19, 'Bad ', tknMODE, 0

; ----------------------------------------------------------------------------

; GCOL numeric, numeric
; =====================

GRAPH:
    jsr ASEXPR         ; evaluate modifier

    lda zpIACC
    pha                ; save result on stack

    jsr INCMEX         ; Step past comma, evaluate integer
    jsr AEDONE         ; Update program pointer, check for end of statement

    lda #$12
    jsr OSWRCH         ; Send VDU 18 for GCOL
    jmp SENTWO         ; Jump to send two bytes to OSWRCH

; ----------------------------------------------------------------------------

; COLOUR numeric
; ==============

COLOUR:
    lda #$11
    pha                ; Stack VDU 17 for COLOUR
    jsr ASEXPR         ; evaluate integer expression
    jsr DONE           ; check end of statement
    jmp SENTWO         ; Jump to send two bytes to OSWRCH

; ----------------------------------------------------------------------------

; MODE numeric
; ============

MODES:
    lda #$16
    pha               ; Stack VDU 22 for MODE
    jsr ASEXPR        ; evaluate integer expression
    jsr DONE          ; check end of statement

; BBC - Check if changing MODE will move screen into stack
; --------------------------------------------------------
    .ifdef MOS_BBC
        jsr GETMAC    ; Get machine address high word
        cpx #$FF      ; later BASICs use inx
        bne MODEGO    ; Not $xxFFxxxx, skip memory test
        cpy #$FF      ; later BASICs use iny
        bne MODEGO    ; Not $FFFFxxxx, skip memory test

                      ; MODE change in I/O processor, must check memory limits
        lda zpAESTKP
        cmp zpHIMEM
        bne MODESX    ; STACK<>HIMEM, stack not empty, give 'Bad MODE' error

        lda zpAESTKP+1
        cmp zpHIMEM+1
        bne MODESX

        ldx zpIACC
        lda #$85
        jsr OSBYTE    ; Get top of memory if we used this MODE

        cpx zpFSA
        tya
        sbc zpFSA+1
        bcc MODESX    ; Would be below VAREND, give error

        cpx zpTOP
        tya
        sbc zpTOP+1
        bcc MODESX    ; Would be below TOP, give error

        ; BASIC stack is empty, screen would not hit heap or program

        stx zpHIMEM
        stx zpAESTKP   ; Set STACK and HIMEM to new address
        sty zpHIMEM+1
        sty zpAESTKP+1
    .endif

; Change MODE
MODEGO:
    jsr BUFEND         ; Set COUNT to zero

; Send two bytes to OSWRCH, stacked byte, then IACC
; -------------------------------------------------
SENTWO:
    pla
    jsr OSWRCH        ; Send stacked byte to OSWRCH
    jsr WRIACC        ; Print byte in IACC
    jmp NXT           ; jump to execution loop

; ----------------------------------------------------------------------------

; MOVE numeric, numeric
; =====================
MOVE:
    lda #$04
    bne DRAWER         ; Jump forward to do PLOT 4 for MOVE

; ----------------------------------------------------------------------------

; DRAW numeric, numeric
; =====================
DRAW:
    lda #$05          ; Do PLOT 5 for DRAW
DRAWER:
    pha
    jsr AEEXPR        ; Evaluate first expression
    jmp PLOTER        ; Jump to evaluate second expression and send to OSWRCH

; ----------------------------------------------------------------------------

; PLOT numeric, numeric, numeric
; ==============================
PLOT:
    jsr ASEXPR        ; evaluate integer expression

    lda zpIACC
    pha               ; save on stack

    jsr COMEAT        ; eat comma
    jsr EXPR          ; evaluate expression

PLOTER:
    jsr INTEG         ; Confirm numeric and ensure is integer
    jsr PHACC         ; Push IACC
    jsr INCMEX        ; Step past command and evaluate integer
    jsr AEDONE        ; Update program pointer, check for end of statement

    lda #$19
    jsr OSWRCH        ; Send VDU 25 for PLOT

    pla
    jsr OSWRCH        ; Send PLOT action
    jsr POPWRK        ; Pop integer to temporary store at $37/8

    lda zpWORK
    jsr OSWRCH        ; Send first coordinate to OSWRCH LSB

    lda zpWORK+1
    jsr OSWRCH        ; MSB

    jsr WRIACC        ; Send IACC to OSWRCH, second coordinate

    lda zpIACC+1
    jsr OSWRCH        ; Send IACC high byte to OSWRCH

    jmp NXT           ; Jump to execution loop

; ----------------------------------------------------------------------------

VDUP:
    lda zpIACC+1
    jsr OSWRCH        ; Send IACC byte 2 to OSWRCH

; ----------------------------------------

; VDU num[,][;][...]
; ==================

VDU:
    jsr SPACES         ; Get next character

VDUL:
    cmp #':'
    beq VDUX           ; If end of statement, jump to exit

    cmp #$0D
    beq VDUX           ; exit if CR

    cmp #tknELSE
    beq VDUX           ; exit if ELSE token

    dec zpCURSOR       ; Step back to current character
    jsr ASEXPR         ; evaluate integer expression
    jsr WRIACC         ; and output low byte
    jsr SPACES         ; Get next character

    cmp #','
    beq VDU            ; Comma, loop to read another number

    cmp #';'
    bne VDUL           ; Not semicolon, loop to check for end of statement
    beq VDUP           ; Loop to output high byte and read another

VDUX:
    jmp SUNK           ; Jump to execution loop

; ----------------------------------------------------------------------------

; Send IACC to OSWRCH via WRCHV
; =============================
WRIACC:
    lda zpIACC
    .if WRCHV != 0
        jmp (WRCHV)
    .elseif WRCHV == 0
        jmp OSWRCH
    .endif

; ----------------------------------------------------------------------------

; VARIABLE PROCESSING
; ===================
; Look for a FN/PROC in heap
; --------------------------
; On entry, (zpWORK)+1=>FN/PROC token (ie, first character of name)
;

CREAFN:
    ldy #$01
    lda (zpWORK),Y      ; Get PROC/FN character
    ldy #$F6            ; Point to PROC list start
    cmp #tknPROC
    beq CREATF          ; If PROC, jump to scan list

    ldy #$F8            ; cataloge offset for functions
    bne CREATF          ; Point to FN list start and scan list

; ----------------------------------------------------------------------------

; Look for a variable in the heap
; -------------------------------
; LOOKUP is given a base address-1 in WORK,WORK+1, length+1 in WORK+2
; It returns with Z flag set if it can't find the thing, else with
; IACC,IACC+1 pointing to the data item and Z cleared
;
; The routine uses two slightly different search routines, which are used
; alternately. This is done to reduce the amount of swapping of pointers

LOOKUP:
    ldy #$01
    lda (zpWORK),Y      ; Get first character of variable
    asl                 ; Double it to index into index list
    tay

; Scan though linked lists in heap
; --------------------------------
CREATF:
    lda VARL,Y
    sta zpWORK+3          ; Get start of linked list
    lda VARL+1,Y
    sta zpWORK+4

CREATLP:
    lda zpWORK+4
    beq CREAEOLST         ; End of list reached

    ldy #$00              ; store link address of the next entry in zpWORK+5/6
    lda (zpWORK+3),Y
    sta zpWORK+5

    iny
    lda (zpWORK+3),Y
    sta zpWORK+6

    iny
    lda (zpWORK+3),Y       ; get first character of name
    bne CREATG             ; Jump if not null name

    dey
    cpy zpWORK+2           ; compare length
    bne CREATH             ; no match, continue with next entry

    iny
    bcs CREATI             ; branch always, carry is set by cpy before

CREATL:
    iny
    lda (zpWORK+3),Y       ; next character from the catalogue entry
    beq CREATH             ; jump if zero marking end is found

CREATG:
    cmp (zpWORK),Y         ; compare with name being sought
    bne CREATH             ; jump if no match

    cpy zpWORK+2
    bne CREATL             ; end of sought variable name has not been reached

    iny
    lda (zpWORK+3),Y       ; next character from the catalogue entry
    bne CREATH             ; jump if not end yet

CREATI:
    tya                    ; make IACC point to the zero byte after the name
    adc zpWORK+3
    sta zpIACC
    lda zpWORK+4
    adc #$00
    sta zpIACC+1

CREAEOLST:
    rts

CREATH:
    lda zpWORK+6
    beq CREAEOLST           ; no more entries for the same initial letter

    ldy #$00                ; get new link bytes from the new catalogue entry
    lda (zpWORK+5),Y
    sta zpWORK+3

    iny
    lda (zpWORK+5),Y
    sta zpWORK+4

    iny
    lda (zpWORK+5),Y        ; next character from catalogue entry
    bne CREATK              ; jump if not zero marking the end of the name

    dey
    cpy zpWORK+2            ; check against length of sought variable
    bne CREATLP             ; jump if not the same

    iny                     ; point to zero after the name
    bcs CREATM              ; carry always set, jump to exit

CREATJ:
    iny
    lda (zpWORK+5),Y        ; get next information block character
    beq CREATLP             ; move to the next block if the character is zero

CREATK:
    cmp (zpWORK),Y          ; check against character of sought variable
    bne CREATLP             ; jump if no match

    cpy zpWORK+2
    bne CREATJ              ; end of sought variable name has not been reached

    iny
    lda (zpWORK+5),Y
    bne CREATLP             ; jump to next info block if not zero marking

CREATM:
    tya                     ; make IACC point to the zero byte after the name
    adc zpWORK+5
    sta zpIACC
    lda zpWORK+6
    adc #$00
    sta zpIACC+1
    rts

LOOKFN:
    ldy #$01
    lda (zpWORK),Y
    tax
    lda #$F6                ; catalogue offset for procedures
    cpx #tknPROC
    beq LOOKMN
    lda #$F8                ; catalogue offset for functions
    bne LOOKMN

; ----------------------------------------------------------------------------

;  CREATE takes the same parameters as LOOKUP and adds the
;  data item to the linked list. It is not optimised.

CREATE:
    ldy #$01
    lda (zpWORK),Y      ; get the first letter of the variable
    asl                 ; multiply by 2

LOOKMN:
    sta zpWORK+3        ; use it to create pointer into variable catalogue
    lda #>VARL
    sta zpWORK+4

LOOPLB:
    lda (zpWORK+3),Y    ; get MSB of linked list
    beq LOOKK           ; jump if at the end of list sharing the same inital
                        ; letter as the one being created

    tax                 ; save MSB in X
    dey
    lda (zpWORK+3),Y    ; get LSB of linked list item
    sta zpWORK+3        ; store as new pointer
    stx zpWORK+4
    iny
    bpl LOOPLB          ; loop until we reach the end of the linked list

LOOKK:
    lda zpFSA+1         ; use VARTOP as location for new entry
    sta (zpWORK+3),Y
    lda zpFSA
    dey
    sta (zpWORK+3),Y

    tya                 ; A=Y=0
    iny
    sta (zpFSA),Y       ; save zero as the MSB, indicating end of list
    cpy zpWORK+2        ; compare length
    beq CREATX          ; exit if the name has only one letter

LOOPRA:
    iny
    lda (zpWORK),Y      ; copy next character
    sta (zpFSA),Y
    cpy zpWORK+2
    bne LOOPRA          ; loop until end of the name has been reached

    rts

; ----------------------------------------------------------------------------
;  CREAX updates FSA on the assumption that x-1 bytes are to be used
;  Y contains next address offset, four bytes are zeroed
;  If we run out of ram it resets the list end with the old
;  pointer in WORK+3/4

CREAX:
    lda #$00
CREZER:
    iny
    sta (zpFSA),Y       ; clear
    dex
    bne CREZER

FSAPY:
    sec                 ; set carry to add +1
    tya
    adc zpFSA           ; add Y+1 to VARTOP (LSB), keep in A
    bcc CREATY

    inc zpFSA+1         ; adjust MSB, never restored on 'No room' error?

CREATY:
    ldy zpFSA+1
    cpy zpAESTKP+1      ; compare against AE stack pointer
    bcc CREATZ          ; VARTOP MSB is lower, ok, exit
    bne CREATD          ; skip LSB check if MSB is different

    cmp zpAESTKP        ; check VARTOP LSB against AE stack pointer
    bcc CREATZ          ; jump to exit if lower

CREATD:
    lda #$00            ; zero MSB of link byte to stop block from existing
    ldy #$01
    sta (zpWORK+3),Y

                        ; BUG? MSB of VARTOP is not decremented if it was
                        ; increased before the test.
                        ; Possible fix: pair inc zpFSA+1 with inx,
                        ; here: dex:bne .skip:dec zpFSA+1:.skip

    jmp ALLOCR          ; 'No room' error

CREATZ:
    sta zpFSA           ; store LSB of VARTOP

CREATX:
    rts

; ----------------------------------------------------------------------------

; Get an array name
; Search for an array name starting at (zpWORK) + 1
; On exit, (zpWORK),Y point to the first character that could not be
; interpreted as part of the array name, and A contains this character.
; X is incremented for each character that is scanned.

WORD:
    ldy #$01        ; point to first character of name

WORDLP:
    lda (zpWORK),Y
    cmp #'0'
    bcc WORDDN      ; exit if < '0'

    cmp #'@'
    bcs WORDNA      ; continue if  >= '@'

    cmp #'9'+1
    bcs WORDDN      ; exit if > '9'

    ; it's a number

    cpy #$01
    beq WORDDN      ; exit if it's the first character

WORDNC:
    inx
    iny             ; point to next character
    bne WORDLP      ; and loop

WORDNA:
    cmp #'_'
    bcs WORDNB      ; jump if >= '_' (0x60, pound sign, ASCII backtick allowed)

    cmp #'Z'+1
    bcc WORDNC      ; continue if <= 'Z'

WORDDN:
    ; return value in C, C=0 is OK, C=1 is FAIL
    rts

WORDNB:
    cmp #'z'+1
    bcc WORDNC      ; continue if <= 'z'
    rts

; ----------------------------------------------------------------------------

CRAELT:
    jsr CREAX       ; clear the variable

; Get a variable, creating it if needed

CRAELV:
    jsr AELV        ; search for the variable name
    bne LVRTS       ; exit if variable exists
    bcs LVRTS       ; exit if variable is invalid

    jsr CREATE      ; create the variable

    ldx #$05        ; for ints and strings
    cpx zpIACC+2
    bne CRAELT      ; clear
    inx             ; for floats
    bne CRAELT      ; jump always, clear

LVFD:
    cmp #'!'
    beq UNPLIN      ; unary '!'

    cmp #'$'
    beq DOLL        ; $<address>

    eor #'?'
    beq UNIND       ; unary '?'

    lda #$00        ; variable not found, invalid
    sec

LVRTS:
    rts

; Unary '!'

UNPLIN:
    lda #$04        ; four bytes

; Unary '?'

UNIND:
    pha             ; save number of bytes
    inc zpAECUR     ; move cursor past '!' or '?'
    jsr INTFAC      ; get integer expression
    jmp INSET       ; join the code that deals with binary operators

; $<address>

DOLL:
    inc zpAECUR     ; move cursor past '$'
    jsr INTFAC      ; get integer expression

    lda zpIACC+1
    beq DOLLER      ; error if < 256

    lda #$80        ; string
    sta zpIACC+2
    sec
    rts

DOLLER:
    brk
    dta 8, '$ range', 0

; Copy LINE pointer to AE pointer, and skip spaces before searching for
; a variable name

AELV:
    lda zpLINE
    sta zpAELINE
    lda zpLINE+1
    sta zpAELINE+1
    ldy zpCURSOR
    dey             ; one position back to allow for loop to start with iny

LVBLNK:
    iny

LVBLNKplus1:
    sty zpAECUR         ; save AE offset
    lda (zpAELINE),Y
    cmp #' '
    beq LVBLNK          ; loop to skip spaces

; enter here to search for a variable. A contains the first character
; of the alleged variable. This routine is optimized towards identifying
; resident integer variables as fast as it can.
; On exit, the address of the value of the variable is stored in IACC.
; If Z is set, the variable does not exist.
; If C is set, the variable is invalid
; If Z is clear, a valid, defined variable was found, and the carry flag
; will be set if the variable is a string variable
;
; Z=0, C=0 --> a defined numeric variable was found
; Z=0, C=1 --> a defined string variable was found
; Z=1, C=0 --> a valid but undefined variable was found
; Z=1, C=1 --> an invalid variable was found

LVCONT:
    cmp #'@'
    bcc LVFD        ; probably not an lv but check for unary things
                    ; this test also removes numeric first characters

    cmp #'['
    bcs MULTI       ; jump if >=

    ; upper case letter

    asl             ; multiply by four, makes it an index into VARL page
    asl
    sta zpIACC      ; store as LSB
    lda #>VARL
    sta zpIACC+1    ; store MSB

    iny
    lda (zpAELINE),Y
    iny
    cmp #'%'
    bne MULTI       ; jump if next character is not '%'

    ldx #$04        ; integer type/size
    stx zpIACC+2
    lda (zpAELINE),Y
    cmp #'('
    bne CHKQUE      ; jump if not '('

MULTI:
    ldx #$05        ; set type/size to float
    stx zpIACC+2

    lda zpAECUR     ; add offset to AELINE, result in XA
    clc
    adc zpAELINE
    ldx zpAELINE+1
    bcc BKTVNO

    inx
    clc

BKTVNO:
    sbc #$00        ; subtract 1 and save as WORK pointer
    sta zpWORK      ; pointing one position before the first character
    bcs BKTVNP

    dex

BKTVNP:
    stx zpWORK+1    ; MSB of pointer

    ldx zpAECUR     ; keep track of offset
    ldy #$01        ; offset to WORK pointer, start at 1

BKTVD:
    lda (zpWORK),Y
    cmp #'A'
    bcs BKTVA       ; jump if >= 'A'

    cmp #'0'
    bcc BKTVE       ; jump if < '0'

    cmp #'9'+1
    bcs BKTVE       ; jump if > '9'

    inx
    iny
    bne BKTVD       ; loop and get the next character

BKTVA:
    cmp #'Z'+1
    bcs BKTVDD      ; jump if > 'Z'

    inx
    iny
    bne BKTVD       ; loop and get the next character

BKTVDD:
    cmp #'_'
    bcc BKTVE       ; jump if < '_'

    cmp #'z'+1
    bcs BKTVE       ; jump if > 'z'

    inx
    iny
    bne BKTVD       ; loop and get the next character

BKTVE:
    dey
    beq BKTVFL      ; if Y is still 1, no character was valid, error

    cmp #'$'
    beq LVSTR       ; jump if it's a string

    cmp #'%'
    bne BKTVF       ; jump if it's not an integer but a float

    ; it's an integer

    dec zpIACC+2    ; decrement 5 to 4
    iny             ; compensate for dey at BKTVE
    inx             ; next character
    iny             ; next character
    lda (zpWORK),Y
    dey             ; Y must be maintained at 1 position to the left

BKTVF:
    sty zpWORK+2    ; save the length of the name
    cmp #'('
    beq BKTVAR      ; jump if we have an array

    jsr LOOKUP      ; find address of the variable
    beq BKTVFC      ; exit with Z=1,C=0 if the variable is undefined

    stx zpAECUR     ; update AELINE offset

CHKPLI:
    ldy zpAECUR
    lda (zpAELINE),Y

CHKQUE:
    cmp #'!'
    beq BIPLIN      ; jump to binary '!'

    cmp #'?'
    beq BIQUER      ; jump to binary '?'

    clc             ; indicate numeric, C=0
    sty zpAECUR     ; update cursor position
    lda #$FF        ; indicate valid, Z=0
    rts

BKTVFL:
    lda #$00    ; Z=1
    sec         ; C=1
    rts

BKTVFC:
    lda #$00    ; Z=1
    clc         ; C=0
    rts

; Binary '?'

BIQUER:
    lda #$00
    beq BIPLIN+2    ; skip lda #4 (could save byte with dta 0x2c (BIT abs))

; Binary '!'

BIPLIN:
    lda #$04        ; set type to 4
    pha             ; save on stack
    iny
    sty zpAECUR     ; increment past '?' or '!' and store cursor

    jsr VARIND      ; get the value of the variable scanned so far
    jsr INTEGB      ; make sure it's an integer

    lda zpIACC+1    ; save address on stack
    pha
    lda zpIACC
    pha

    jsr INTFAC      ; get the integer operand following '?' or '!'

    clc             ; add the address on the stack to the value of the operand
    pla
    adc zpIACC
    sta zpIACC
    pla
    adc zpIACC+1
    sta zpIACC+1

INSET:
    pla             ; restore type from stack
    sta zpIACC+2
    clc             ; C=0
    lda #$FF        ; Z=0
    rts

    ; Prepare for array

BKTVAR:
    inx             ; increment past the '('
    inc zpWORK+2

    jsr ARRAY       ; deal with the array

    jmp CHKPLI      ; check for indirection operators, tail call

    ; String

LVSTR:
    inx             ; increment past the '$' at the end of the name
    iny
    sty zpWORK+2    ; save the length of the name
    iny             ; point to next character
    dec zpIACC+2    ; decrement type to 4
    lda (zpWORK),Y
    cmp #'('
    beq LVSTRA      ; jump if string array

    jsr LOOKUP      ; find the address of the variable
    beq BKTVFC      ; error if undefined

    stx zpAECUR     ; update AE offset
    lda #$81        ; set type to $81, and Z=0
    sta zpIACC+2
    sec             ; C=1
    rts

    ; String array

LVSTRA:
    inx             ; increment past '('
    sty zpWORK+2
    dec zpIACC+2    ; decrement type to 3

    jsr ARRAY       ; handle array

    lda #$81        ; set type to $81, and Z=0
    sta zpIACC+2
    sec             ; C=1
    rts

UNARRY:
    brk
    dta 14, 'Array', 0

    ; Array

ARRAY:
    jsr LOOKUP      ; find address of the variable
    beq UNARRY      ; error if not found

    stx zpAECUR     ; update AE offset

    lda zpIACC+2    ; save type and address of the base of the array
    pha
    lda zpIACC
    pha
    lda zpIACC+1
    pha

    ldy #$00
    lda (zpIACC),Y  ; get number of elements of the array (stored as 2n+1)
    cmp #$04
    bcc AQUICK      ; jump if array is one dimensional

    tya
    jsr SINSTK      ; zero IACC

    lda #$01        ; save the pointer to the current subscript index
    sta zpIACC+3

ARLOP:
    jsr PHACC       ; save IACC on BASIC stack
    jsr INEXPR      ; evaluate next array index, ensure it's an integer
    inc zpAECUR
    cpx #','
    bne UNARRY      ; error if no ',' is present

    ldx #zpWORK+2
    jsr POPX        ; pop IACC to zpWORK+2 onwards

    ldy zpWORK+5    ; get offset of current index

    pla             ; retrieve base address of the array to zpWORK
    sta zpWORK+1
    pla
    sta zpWORK

    pha             ; and stack it again
    lda zpWORK+1
    pha

    jsr TSTRNG      ; check current index against its limit

    sty zpIACC+3    ; save pointer to current element

    lda (zpWORK),Y  ; save next subscript limit
    sta zpWORK+8
    iny
    lda (zpWORK),Y
    sta zpWORK+9

    lda zpIACC      ; add preset subscript to total subscript
    adc zpWORK+2    ; (subscript into array as if it was one long array)
    sta zpIACC
    lda zpIACC+1
    adc zpWORK+3
    sta zpIACC+1

    jsr WMUL        ; multiply subscript bye the next subscript limit

    ldy #$00
    sec
    lda (zpWORK),Y  ; get offset of the last subscript
    sbc zpIACC+3    ; subtract offset of the current subscript
    cmp #$03
    bcs ARLOP       ; continue if more than one subscript is left

    jsr PHACC       ; save IACC
    jsr BRA         ; get expression and check for right hand bracket
    jsr INTEGB      ; ensure expression is integer

    pla             ; get base address of array
    sta zpWORK+1
    pla
    sta zpWORK

    ldx #zpWORK+2
    jsr POPX        ; POP to zpWORK+2 onwards

    ldy zpWORK+5    ; get the offset of the current subscript
    jsr TSTRNG      ; check against limit

    clc             ; add new subscript to toal subscript
    lda zpWORK+2
    adc zpIACC
    sta zpIACC
    lda zpWORK+3
    adc zpIACC+1
    sta zpIACC+1
    bcc ARFOUR

    ; single dimension arrays

AQUICK:
    jsr BRA         ; get expression and check for ')'
    jsr INTEGB      ; ensure it's integer

    pla             ; retrieve base address of the array
    sta zpWORK+1
    pla
    sta zpWORK

    ldy #$01
    jsr TSTRNG      ; check subscript limit

ARFOUR:
    pla             ; get type of array
    sta zpIACC+2    ; and save it

    cmp #$05
    bne ARFO        ; jump if it's not a floating point array

    ; multiply total subscript by 5

    ldx zpIACC+1    ; save MSB in X so we can add it later

    lda zpIACC
    asl zpIACC      ; *2
    rol zpIACC+1
    asl zpIACC      ; *2 (total is *4)
    rol zpIACC+1

    adc zpIACC      ; add original
    sta zpIACC
    txa
    adc zpIACC+1
    sta zpIACC+1    ; total is 4n+n = 5n
    bcc ARFI        ; skip code for integer and string arrays

    ; multiply total subscript by 4 for integer and string arrays
ARFO:
    asl zpIACC
    rol zpIACC+1
    asl zpIACC
    rol zpIACC+1

ARFI:
    tya             ; add length of the preamble
    adc zpIACC
    sta zpIACC
    bcc NNINC

    inc zpIACC+1
    clc

NNINC:
    lda zpWORK      ; add base addres to get the actual address of the element
    adc zpIACC
    sta zpIACC
    lda zpWORK+1
    adc zpIACC+1
    sta zpIACC+1    ; result in IACC
    rts

; check the array subscript

TSTRNG:
    lda zpIACC+1    ; ensure subscript is less than 16384
    and #$C0
    ora zpIACC+2
    ora zpIACC+3
    bne SUBSCP      ; error if it's not

    lda zpIACC      ; check against the limit
    cmp (zpWORK),Y
    iny
    lda zpIACC+1
    sbc (zpWORK),Y
    bcs SUBSCP      ; error if it's too big

    iny             ; return with Y past limit
    rts

SUBSCP:
    brk
    dta 15, 'Subscript', 0

; ----------------------------------------------------------------------------

; Line number routines

SPTSTM:
    inc zpCURSOR

SPTSTN:
    ldy zpCURSOR
    lda (zpLINE),Y
    cmp #' '
    beq SPTSTM          ; loop to skip spaces

    cmp #tknCONST
    bne FDA             ; exit if not CONST token


; Decode line number constant. bit 0-14 are encoded as:
;
;    Byte 1: | 0 | 1 |  bit7 |  bit6 |     0 | bit14 |    0 |   0
;    Byte 2: | 0 | 1 |  bit5 |  bit4 |  bit3 |  bit2 | bit1 | bit0
;    Byte 3: | 0 | 1 | bit13 | bit12 | bit11 | bit10 | bit9 | bit8
;
; bit6 and bit14 are stored inverted

SPGETN:
    iny
    lda (zpLINE),Y  ; get byte 1
    asl             ; shift bit7 and bit6 to the top
    asl
    tax             ; save in X for bit14
    and #$C0        ; mask top two bits
    iny
    eor (zpLINE),Y  ; XOR byte 2, the bottom 6 bits and invert bit6
    sta zpIACC      ; and store in IACC
    txa             ; retrieve shifted first byte
    asl             ; shift bit14 (already at bit4 position) to bit6 position
    asl
    iny
    eor (zpLINE),Y  ; XOR byte3, bottom 6 bits (bit8-bit13), invert bit6
    sta zpIACC+1    ; and store as high byte of IACC
    iny
    sty zpCURSOR    ; update cursor position
    sec             ; indicate line number was found
    rts

FDA:
    clc             ; indicate line number was not found
    rts

; ----------------------------------------------------------------------------

; vi:syntax=mads
