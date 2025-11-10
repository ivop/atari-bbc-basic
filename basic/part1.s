
START_OF_ROM:

; ----------------------------------------------------------------------------

.ifdef TARGET_BBC
    cmp #$01          ; Language Entry
    beq ENTRY
    rts
    nop
    dta $60                             ; ROM type = Lang+Tube+6502 BASIC
    dta copyright_string - romstart     ; Offset to copyright string
    dta 3                               ; Version 2 = $01, Version 3 = $03
    dta 'BASIC'
copyright_string:
    dta 0
    dta '(C)1983 Acorn', 10, 13, 0
    dta a(romstart), a(0)
.endif

; LANGUAGE STARTUP
; ================

ENTRY:
    .if memtop == 0
        lda #$84      ; Read top of memory
        jsr OSBYTE
    .elseif memtop > 0
        ldx #0
        ldy #>memtop
    .elseif memtop < 0
        ldx memtop+0
        ldy memtop+1
    .endif
    stx zpHIMEM
    sty zpHIMEM+1

    .if membot == 0
        lda #$83      ; Read bottom of memory
        jsr OSBYTE
    .elseif membot > 0
        ldy #>membot
    .elseif membot < 0
        ldy membot+1
    .endif
    sty zpTXTP        ; PAGE

    ldx #$00
    stx zpLISTOP          ; Set LISTO to 0
    stx VARL_AT+2
    stx VARL_AT+3         ; Set @% to $0000xxxx
    dex
    stx zpWIDTHV          ; Set WIDTH to $FF

    ldx #$0A
    stx VARL_AT
    dex
    stx VARL_AT+1      ; Set @% to $0000090A        9.10

    lda #$01
    and zpSEED+4
    ora zpSEED         ; Check RND seed
    ora zpSEED+1
    ora zpSEED+2
    ora zpSEED+3
    bne RNDOK          ; If nonzero, skip past

    lda #'A'           ; Set RND seed to $575241
    sta zpSEED
    lda #'R'
    sta zpSEED+1
    lda #'W'
    sta zpSEED+2       ; "ARW" - Acorn Roger Wilson?

RNDOK:
;    lda #<BREK
;    sta BRKV+0         ; Set up error handler
;    lda #>BREK
;    sta BRKV+1
    cli
warmstart_here = *+1
    jmp FORMAT         ; Enable IRQs, jump to immediate loop

; ----------------------------------------------------------------------------

; TOKEN TABLE
; ===========
; string, token, flags
;
; Token flags:
; Bit 0 - Conditional tokenisation (don't tokenise if followed by an
;                                                   alphabetic character).
; Bit 1 - Go into "middle of Statement" mode.
; Bit 2 - Go into "Start of Statement" mode.
; Bit 3 - FN/PROC keyword - don't tokenise the name of the subroutine.
; Bit 4 - Start tokenising a line number now (after a GOTO, etc...).
; Bit 5 - Don't tokenise rest of line (REM, DATA, etc...)
; Bit 6 - Pseudo variable flag - add &40 to token if at the start of a
;                                                       statement/hex number
; Bit 7 - Unused - used externally for quote toggle.

TOKENS:
    dta 'AND'     , tknAND,         $00      ; 00000000
    dta 'ABS'     , tknABS,         $00      ; 00000000
    dta 'ACS'     , tknACS,         $00      ; 00000000
    dta 'ADVAL'   , tknADVAL,       $00      ; 00000000
    dta 'ASC'     , tknASC,         $00      ; 00000000
    dta 'ASN'     , tknASN,         $00      ; 00000000
    dta 'ATN'     , tknATN,         $00      ; 00000000
    dta 'AUTO'    , tknAUTO,        $10      ; 00010000
    dta 'BGET'    , tknBGET,        $01      ; 00000001
    dta 'BPUT'    , tknBPUT,        $03      ; 00000011
    dta 'COLOUR'  , tknCOLOR,       $02      ; 00000010
    dta 'CALL'    , tknCALL,        $02      ; 00000010
    dta 'CHAIN'   , tknCHAIN,       $02      ; 00000010
    dta 'CHR$'    , tknCHRD,        $00      ; 00000000
    dta 'CLEAR'   , tknCLEAR,       $01      ; 00000001
    dta 'CLOSE'   , tknCLOSE,       $03      ; 00000011
    dta 'CLG'     , tknCLG,         $01      ; 00000001
    dta 'CLS'     , tknCLS,         $01      ; 00000001
    dta 'COS'     , tknCOS,         $00      ; 00000000
    dta 'COUNT'   , tknCOUNT,       $01      ; 00000001
    dta 'COLOR'   , tknCOLOR,       $02      ; 00000010
    dta 'DATA'    , tknDATA,        $20      ; 00100000
    dta 'DEG'     , tknDEG,         $00      ; 00000000
    dta 'DEF'     , tknDEF,         $00      ; 00000000
    dta 'DELETE'  , tknDELETE,      $10      ; 00010000
    dta 'DIV'     , tknDIV,         $00      ; 00000000
    dta 'DIM'     , tknDIM,         $02      ; 00000010
    dta 'DRAW'    , tknDRAW,        $02      ; 00000010
    dta 'ENDPROC' , tknENDPROC,     $01      ; 00000001
    dta 'END'     , tknEND,         $01      ; 00000001
    dta 'ENVELOPE', tknENVELOPE,    $02      ; 00000010
    dta 'ELSE'    , tknELSE,        $14      ; 00010100
    dta 'EVAL'    , tknEVAL,        $00      ; 00000000
    dta 'ERL'     , tknERL,         $01      ; 00000001
    dta 'ERROR'   , tknERROR,       $04      ; 00000100
    dta 'EOF'     , tknEOF,         $01      ; 00000001
    dta 'EOR'     , tknEOR,         $00      ; 00000000
    dta 'ERR'     , tknERR,         $01      ; 00000001
    dta 'EXP'     , tknEXP,         $00      ; 00000000
    dta 'EXT'     , tknEXT,         $01      ; 00000001
    dta 'FOR'     , tknFOR,         $02      ; 00000010
    dta 'FALSE'   , tknFALSE,       $01      ; 00000001
    dta 'FN'      , tknFN,          $08      ; 00001000
    dta 'GOTO'    , tknGOTO,        $12      ; 00010010
    dta 'GET$'    , tknGETD,        $00      ; 00000000
    dta 'GET'     , tknGET,         $00      ; 00000000
    dta 'GOSUB'   , tknGOSUB,       $12      ; 00010010
    dta 'GCOL'    , tknGCOL,        $02      ; 00000010
    dta 'HIMEM'   , tknHIMEM,       $43      ; 01000011
    dta 'INPUT'   , tknINPUT,       $02      ; 00000010
    dta 'IF'      , tknIF,          $02      ; 00000010
    dta 'INKEY$'  , tknINKEYD,      $00      ; 00000000
    dta 'INKEY'   , tknINKEY,       $00      ; 00000000
    dta 'INT'     , tknINT,         $00      ; 00000000
    dta 'INSTR('  , tknINSTR,       $00      ; 00000000
    dta 'LIST'    , tknLIST,        $10      ; 00010000
    dta 'LINE'    , tknLINE,        $00      ; 00000000
    dta 'LOAD'    , tknLOAD,        $02      ; 00000010
    dta 'LOMEM'   , tknLOMEM,       $43      ; 01000011
    dta 'LOCAL'   , tknLOCAL,       $02      ; 00000010
    dta 'LEFT$('  , tknLEFTD,       $00      ; 00000000
    dta 'LEN'     , tknLEN,         $00      ; 00000000
    dta 'LET'     , tknLET,         $04      ; 00000100
    dta 'LOG'     , tknLOG,         $00      ; 00000000
    dta 'LN'      , tknLN,          $00      ; 00000000
    dta 'MID$('   , tknMIDD,        $00      ; 00000000
    dta 'MODE'    , tknMODE,        $02      ; 00000010
    dta 'MOD'     , tknMOD,         $00      ; 00000000
    dta 'MOVE'    , tknMOVE,        $02      ; 00000010
    dta 'NEXT'    , tknNEXT,        $02      ; 00000010
    dta 'NEW'     , tknNEW,         $01      ; 00000001
    dta 'NOT'     , tknNOT,         $00      ; 00000000
    dta 'OLD'     , tknOLD,         $01      ; 00000001
    dta 'ON'      , tknON,          $02      ; 00000010
    dta 'OFF'     , tknOFF,         $00      ; 00000000
    dta 'OR'      , tknOR,          $00      ; 00000000
    dta 'OPENIN'  , tknOPENIN,      $00      ; 00000000
    dta 'OPENOUT' , tknOPENOUT,     $00      ; 00000000
    dta 'OPENUP'  , tknOPENUP,      $00      ; 00000000
    dta 'OSCLI'   , tknOSCLI,       $02      ; 00000010
    dta 'PRINT'   , tknPRINT,       $02      ; 00000010
    dta 'PAGE'    , tknPAGE,        $43      ; 01000011
    dta 'PTR'     , tknPTR,         $43      ; 01000011
    dta 'PI'      , tknPI,          $01      ; 00000001
    dta 'PLOT'    , tknPLOT,        $02      ; 00000010
    dta 'POINT('  , tknPOINT,       $00      ; 00000000
    dta 'PROC'    , tknPROC,        $0A      ; 00001010
    dta 'POS'     , tknPOS,         $01      ; 00000001
    dta 'RETURN'  , tknRETURN,      $01      ; 00000001
    dta 'REPEAT'  , tknREPEAT,      $00      ; 00000000
    dta 'REPORT'  , tknREPORT,      $01      ; 00000001
    dta 'READ'    , tknREAD,        $02      ; 00000010
    dta 'REM'     , tknREM,         $20      ; 00100000
    dta 'RUN'     , tknRUN,         $01      ; 00000001
    dta 'RAD'     , tknRAD,         $00      ; 00000000
    dta 'RESTORE' , tknRESTORE,     $12      ; 00010010
    dta 'RIGHT$(' , tknRIGHTD,      $00      ; 00000000
    dta 'RND'     , tknRND,         $01      ; 00000001
    dta 'RENUMBER', tknRENUMBER,    $10      ; 00010000
    dta 'STEP'    , tknSTEP,        $00      ; 00000000
    dta 'SAVE'    , tknSAVE,        $02      ; 00000010
    dta 'SGN'     , tknSGN,         $00      ; 00000000
    dta 'SIN'     , tknSIN,         $00      ; 00000000
    dta 'SQR'     , tknSQR,         $00      ; 00000000
    dta 'SPC'     , tknSPC,         $00      ; 00000000
    dta 'STR$'    , tknSTRD,        $00      ; 00000000
    dta 'STRING$(', tknSTRINGD,     $00      ; 00000000
    dta 'SOUND'   , tknSOUND,       $02      ; 00000010
    dta 'STOP'    , tknSTOP,        $01      ; 00000001
    dta 'TAN'     , tknTAN,         $00      ; 00000000
    dta 'THEN'    , tknTHEN,        $14      ; 00010100
    dta 'TO'      , tknTO,          $00      ; 00000000
    dta 'TAB('    , tknTAB,         $00      ; 00000000
    dta 'TRACE'   , tknTRACE,       $12      ; 00010010
    dta 'TIME'    , tknTIME,        $43      ; 01000011
    dta 'TRUE'    , tknTRUE,        $01      ; 00000001
    dta 'UNTIL'   , tknUNTIL,       $02      ; 00000010
    dta 'USR'     , tknUSR,         $00      ; 00000000
    dta 'VDU'     , tknVDU,         $02      ; 00000010
    dta 'VAL'     , tknVAL,         $00      ; 00000000
    dta 'VPOS'    , tknVPOS,        $01      ; 00000001
    dta 'WIDTH'   , tknWIDTH,       $02      ; 00000010
    dta 'PAGE'    , tknPAGE2,       $00      ; 00000000
    dta 'PTR'     , tknPTR2,        $00      ; 00000000
    dta 'TIME'    , tknTIME2,       $00      ; 00000000
    dta 'LOMEM'   , tknLOMEM2,      $00      ; 00000000
    dta 'HIMEM'   , tknHIMEM2,      $00      ; 00000000

; ----------------------------------------------------------------------------

; FUNCTION/COMMAND DISPATCH TABLE, MACRO
; ======================================

FIRST_TOKEN = tknOPENIN

func_table .macro operator
    dta :1OPENIN      ; $8E - OPENIN
    dta :1RPTR        ; $8F - PTR
    dta :1RPAGE       ; $90 - PAGE
    dta :1RTIME       ; $91 - TIME
    dta :1RLOMEM      ; $92 - LOMEM
    dta :1RHIMEM      ; $93 - HIMEM
    dta :1ABS         ; $94 - ABS
    dta :1ACS         ; $95 - ACS
    dta :1ADVAL       ; $96 - ADVAL
    dta :1ASC         ; $97 - ASC
    dta :1ASN         ; $98 - ASN
    dta :1ATN         ; $99 - ATN
    dta :1BGET        ; $9A - BGET
    dta :1COS         ; $9B - COS
    dta :1COUNT       ; $9C - COUNT
    dta :1DEG         ; $9D - DEG
    dta :1ERL         ; $9E - ERL
    dta :1ERR         ; $9F - ERR
    dta :1EVAL        ; $A0 - EVAL
    dta :1EXP         ; $A1 - EXP
    dta :1EXT         ; $A2 - EXT
    dta :1FALSE       ; $A3 - FALSE
    dta :1FN          ; $A4 - FN
    dta :1GET         ; $A5 - GET
    dta :1INKEY       ; $A6 - INKEY
    dta :1INSTR       ; $A7 - INSTR(
    dta :1INT         ; $A8 - INT
    dta :1LEN         ; $A9 - LEN
    dta :1LN          ; $AA - LN
    dta :1LOG         ; $AB - LOG
    dta :1NOT         ; $AC - NOT
    dta :1OPENI       ; $AD - OPENUP
    dta :1OPENO       ; $AE - OPENOUT
    dta :1PI          ; $AF - PI
    dta :1POINT       ; $B0 - POINT(
    dta :1POS         ; $B1 - POS
    dta :1RAD         ; $B2 - RAD
    dta :1RND         ; $B3 - RND
    dta :1SGN         ; $B4 - SGN
    dta :1SIN         ; $B5 - SIN
    dta :1SQR         ; $B6 - SQR
    dta :1TAN         ; $B7 - TAN
    dta :1TO          ; $B8 - TO
    dta :1TRUE        ; $B9 - TRUE
    dta :1USR         ; $BA - USR
    dta :1VAL         ; $BB - VAL
    dta :1VPOS        ; $BC - VPOS
    dta :1CHRD        ; $BD - CHR$
    dta :1GETD        ; $BE - GET$
    dta :1INKED       ; $BF - INKEY$
    dta :1LEFTD       ; $C0 - LEFT$(
    dta :1MIDD        ; $C1 - MID$(
    dta :1RIGHTD      ; $C2 - RIGHT$(
    dta :1STRD        ; $C3 - STR$(
    dta :1STRND       ; $C4 - STRING$(
    dta :1EOF         ; $C5 - EOF
    dta :1AUTO        ; $C6 - AUTO
    dta :1DELETE      ; $C7 - DELETE
    dta :1LOAD        ; $C8 - LOAD
    dta :1LIST        ; $C9 - LIST
    dta :1NEW         ; $CA - NEW
    dta :1OLD         ; $CB - OLD
    dta :1RENUM       ; $CC - RENUMBER
    dta :1SAVE        ; $CD - SAVE
    dta :1STDED       ; $CE - unused
    dta :1LPTR        ; $CF - PTR
    dta :1LPAGE       ; $D0 - PAGE
    dta :1LTIME       ; $D1 - TIME
    dta :1LLOMM       ; $D2 - LOMEM
    dta :1LHIMM       ; $D3 - HIMEM
    dta :1BEEP        ; $D4 - SOUND
    dta :1BPUT        ; $D5 - BPUT
    dta :1CALL        ; $D6 - CALL
    dta :1CHAIN       ; $D7 - CHAIN
    dta :1CLEAR       ; $D8 - CLEAR
    dta :1CLOSE       ; $D9 - CLOSE
    dta :1CLG         ; $DA - CLG
    dta :1CLS         ; $DB - CLS
    dta :1DATA        ; $DC - DATA
    dta :1DEF         ; $DD - DEF
    dta :1DIM         ; $DE - DIM
    dta :1DRAW        ; $DF - DRAW
    dta :1END         ; $E0 - END
    dta :1ENDPR       ; $E1 - ENDPROC
    dta :1ENVEL       ; $E2 - ENVELOPE
    dta :1FOR         ; $E3 - FOR
    dta :1GOSUB       ; $E4 - GOSUB
    dta :1GOTO        ; $E5 - GOTO
    dta :1GRAPH       ; $E6 - GCOL
    dta :1IF          ; $E7 - IF
    dta :1INPUT       ; $E8 - INPUT
    dta :1LET         ; $E9 - LET
    dta :1LOCAL       ; $EA - LOCAL
    dta :1MODES       ; $EB - MODE
    dta :1MOVE        ; $EC - MOVE
    dta :1NEXT        ; $ED - NEXT
    dta :1ON          ; $EE - ON
    dta :1VDU         ; $EF - VDU
    dta :1PLOT        ; $F0 - PLOT
    dta :1PRINT       ; $F1 - PRINT
    dta :1PROC        ; $F2 - PROC
    dta :1READ        ; $F3 - READ
    dta :1REM         ; $F4 - REM
    dta :1REPEAT      ; $F5 - REPEAT
    dta :1REPORT      ; $F6 - REPORT
    dta :1RESTORE     ; $F7 - RESTORE
    dta :1RETURN      ; $F8 - RETURN
    dta :1RUN         ; $F9 - RUN
    dta :1STOP        ; $FA - STOP
    dta :1COLOUR      ; $FB - COLOUR
    dta :1TRACE       ; $FC - TRACE
    dta :1UNTIL       ; $FD - UNTIL
    dta :1WIDTH       ; $FE - WIDTH
    dta :1OSCL        ; $FF - OSCLI
.endm

; FUNCTION/COMMAND DISPATCH TABLE, ADDRESS LOW AND HIGH BYTES
; ===========================================================

ADTABL:
    func_table <
ADTABH:
    func_table >

; ----------------------------------------------------------------------------

; ASSEMBLER
; =========

    .macro packmnemL a b c
        dta [[:b<<5] + [:c&0x1f]] & 0xff
    .endm
    .macro packmnemH a b c
        dta [[:a&0x1f]<<2] + [[:b&0x1f]>>3]
    .endm
    .macro mnemonics
        :1 'B' 'R' 'K'
        :1 'C' 'L' 'C'
        :1 'C' 'L' 'D'
        :1 'C' 'L' 'I'
        :1 'C' 'L' 'V'
        :1 'D' 'E' 'X'
        :1 'D' 'E' 'Y'
        :1 'I' 'N' 'X'
        :1 'I' 'N' 'Y'
        :1 'N' 'O' 'P'
        :1 'P' 'H' 'A'
        :1 'P' 'H' 'P'
        :1 'P' 'L' 'A'
        :1 'P' 'L' 'P'
        :1 'R' 'T' 'I'
        :1 'R' 'T' 'S'
        :1 'S' 'E' 'C'
        :1 'S' 'E' 'D'
        :1 'S' 'E' 'I'
        :1 'T' 'A' 'X'
        :1 'T' 'A' 'Y'
        :1 'T' 'S' 'X'
        :1 'T' 'X' 'A'
        :1 'T' 'X' 'S'
        :1 'T' 'Y' 'A'
        :1 'B' 'C' 'C'
        :1 'B' 'C' 'S'
        :1 'B' 'E' 'Q'
        :1 'B' 'M' 'I'
        :1 'B' 'N' 'E'
        :1 'B' 'P' 'L'
        :1 'B' 'V' 'C'
        :1 'B' 'V' 'S'
        :1 'A' 'N' 'D'
        :1 'E' 'O' 'R'
        :1 'O' 'R' 'A'
        :1 'A' 'D' 'C'
        :1 'C' 'M' 'P'
        :1 'L' 'D' 'A'
        :1 'S' 'B' 'C'
        :1 'A' 'S' 'L'
        :1 'L' 'S' 'R'
        :1 'R' 'O' 'L'
        :1 'R' 'O' 'R'
        :1 'D' 'E' 'C'
        :1 'I' 'N' 'C'
        :1 'C' 'P' 'X'
        :1 'C' 'P' 'Y'
        :1 'B' 'I' 'T'
        :1 'J' 'M' 'P'
        :1 'J' 'S' 'R'
        :1 'L' 'D' 'X'
        :1 'L' 'D' 'Y'
        :1 'S' 'T' 'A'
        :1 'S' 'T' 'X'
        :1 'S' 'T' 'Y'
        :1 'O' 'P' 'T'
        :1 'E' 'Q' 'U'
    .endm

; Packed mnemonic table, low/high bytes
; -------------------------------------

MNEML:
    mnemonics packmnemL
MNEMH:
    mnemonics packmnemH

ALLOPS = * -MNEMH

; Opcode base table
; -----------------
STCODE:

    brk:clc:cld:cli:clv:dex:dey:inx
    iny:nop:pha:php:pla:plp:rti:rts
    sec:sed:sei:tax:tay:tsx:txa:txs:tya

IMPLIED = * - STCODE

    dta $90, $B0, $F0, $30    ; BMI, BCC, BCS, BEQ
    dta $D0, $10, $50, $70    ; BNE, BPL, BVC, BVS

BRANCH = * - STCODE

    dta $21, $41, $01, $61    ; AND, EOR, ORA, ADC
    dta $C1, $A1, $E1         ; CMP, LDA, SBC

GROUP1 = * - STCODE

    dta $06, $46, $26, $66    ; ASL, LSR, ROL, ROR

ASLROR = * - STCODE

    dta $C6, $E6              ; DEC, INC

DECINC = * - STCODE

    dta $E0, $C0              ; CPX, CPY

CPXCPY = * - STCODE

    dta $20, $4C, $20         ; BIT, JMP, JSR

JSRJMP = * - STCODE

    dta $A2, $A0              ; LDX, LDY

COPSTA = * - STCODE

    dta $81, $86, $84         ; STA, STX, STY

PSEUDO = * - STCODE

; ----------------------------------------------------------------------------

; Assembler
; =========

STOPASM:              ; Exit Assembler
    lda #$FF          ; Set OPT to 'BASIC'
    sta zpBYTESM
    jmp STMT          ; return to execution loop

ASS:
    lda #$03
    sta zpBYTESM      ; Set OPT 3, default on entry to '['

CASM:
    jsr SPACES        ; Skip spaces, and get next character
    cmp #']'
    beq STOPASM       ; ']' - exit assembler

    jsr CLYADP        ; add Y to zpLINE, set Y and zpCURSOR to 1

    dec zpCURSOR
    jsr MNEENT        ; assemble a single instruction

    dec zpCURSOR      ; point to last character that could not assemble
    lda zpBYTESM      ; top bit determines whether to list or not
    lsr
    bcc NOLIST

    ; generate listing

    lda zpTALLY
    adc #$04          ; carry is set, add 5 for reasonable output
    sta zpWORK+8      ; save as indentation
    lda zpWORK+1      ; P% as it was before assembling instruction
    jsr HEXOUT        ; print MSB

    lda zpWORK
    jsr HEXSP         ; print LSB and space

    ldx #-4           ; counter, max. 3 bytes per line, X=0 after 4th increment
    ldy zpWORK+2
    bpl WRTLOP

    ldy zpCLEN
WRTLOP:
    sty zpWORK+1
    beq RMOVE         ; hex of instructions done

    ldy #$00
WRTLPY:
    inx
    bne WRTLPA        ; fourth increment, print newline first

    jsr NLINE         ; Print newline

    ldx zpWORK+8      ; retrieve indentation

    jsr LISTPL     ; Print multiple spaces

    ldx #-3    ; one more than -4 because first loop through inx is not done

WRTLPA:
    lda (zpWORK+3),Y
    jsr HEXSP

    iny
    dec zpWORK+1
    bne WRTLPY

RMOVE:
    txa
    tay
RMOVEL:
    iny
    beq LLLLL5
    ldx #3
    jsr LISTPL
    beq RMOVEL

LLLLL5:
    ldx #$0A
    lda (zpLINE),Y
    cmp #'.'
    bne NOLABL

LTLABL:
    jsr TOKOUT     ; Print char or token
    dex
    bne MALABL
    ldx #1

MALABL:
    iny             ; Y was 0
    lda (zpLINE),Y
    cpy zpNEWVAR
    bne LTLABL

NOLABL:
    jsr LISTPL
    dey

LABLSP:
    iny
    cmp (zpLINE),Y
    beq LABLSP

LLLL4:
    lda (zpLINE),Y
    cmp #':'           ; possible end of statement?
    beq NOCODA

    cmp #$0D
    beq NOCOD

LLLLLL6:
    jsr TOKOUT         ; Print character or token
    iny
    bne LLLL4          ; branch always, as line length of 256+ is impossible

NOCODA:
    cpy zpCURSOR
    bcc LLLLLL6        ; not end of statement yet, continue processing

NOCOD:
    jsr NLINE         ; Print newline

NOLIST:
    ldy zpCURSOR
    dey

NOLA:
    iny
    lda (zpLINE),Y
    cmp #':'
    beq NOLB

    cmp #$0D           ; CR, EOL
    bne NOLA

NOLB:
    jsr DONE_WITH_Y    ; check statement has ended, add Y to zpLINE, Y=1

    dey
    lda (zpLINE),Y      ; get previous character
    cmp #':'            ; check if statement ended with :
    beq CASMJ           ; assemble next instruction

    lda zpLINE+1        ; check for immediate mode if LINE points to BUFFER
    cmp #>BUFFER
    bne INTXT           ; jump if not immediate mode

    jmp CLRSTK          ; done

INTXT:
    jsr LINO

CASMJ:
    jmp CASM            ; assemble next instruction

; ----------------------------------------------------------------------------

SETL:                 ; set label
    jsr CRAELV        ; get variable name, check if it exists, or create
    beq ASSDED        ; badly formed
    bcs ASSDED        ; or string

    jsr PHACC         ; push to AE stack
    jsr GETPC         ; put P% in IACC

    sta zpTYPE        ; A contains $40, type is integer

    jsr STORE         ; assign value to variable
    jsr ASCUR         ; update cursor offset

    sty zpNEWVAR

; Assemble a single instruction

MNEENT:
    ldx #$03          ; mnemonics are three characters
    jsr SPACES        ; skip spaces, and get next character

    ldy #$00         ; number of bytes
    sty zpWORK+6     ; make sure temp location is zero for packing mnemonic

    cmp #':'
    beq MMMM         ; End of statement

    cmp #$0D
    beq MMMM         ; End of line

    cmp #'\'
    beq MMMM         ; Comment

    cmp #'.'
    beq SETL         ; Label

    dec zpCURSOR

RDLUP:
    ldy zpCURSOR      ; current character position
    inc zpCURSOR      ; increment index
    lda (zpLINE),Y
    bmi RDSLPT        ; Token, check for tokenised AND, EOR, OR
                      ; (they are tokenised because they match BASIC keywords)

    cmp #' '
    beq RDOUT         ; premature space, step past

    ; pack mnemonic

    ldy #$05          ; 5 bottom bits, fun fact: you can use lower case, too
                      ;                          or even $ for D etc...
    asl               ; skip top 3 bits
    asl
    asl

INLUP:
    asl
    rol zpWORK+6      ; was cleared before, so there are not random top bits
    rol zpWORK+7
    dey
    bne INLUP         ; shift 5 times

    dex
    bne RDLUP         ; Loop to fetch three characters

; The current opcode has now been compressed into two bytes
; ---------------------------------------------------------

RDOUT:
    ldx #ALLOPS       ; Point to end of opcode lookup table
    lda zpWORK+6      ; Get low byte of compacted mnemonic

SRCHM:
    cmp MNEML-1,X
    bne NOTGOT        ; Low half doesn't match

    ldy MNEMH-1,X     ; Check high half
    cpy zpWORK+7
    beq RDOPGT        ; Mnemonic matches

NOTGOT:
    dex
    bne SRCHM         ; Loop through opcode lookup table

ASSDED:
    jmp STDED         ; Mnemonic not matched, Mistake

; The check-for-tokens routine called earlier

RDSLPT:
    ldx #BRANCH+1     ; opcode number for 'AND'
    cmp #tknAND
    beq RDOPGT        ; Tokenised 'AND'

    inx               ; opcode number for 'EOR'
    cmp #tknEOR
    beq RDOPGT        ; Tokenised 'EOR'

    inx               ; opcode number for 'ORA'
    cmp #tknOR
    bne ASSDED        ; Not tokenised 'OR'

    inc zpCURSOR
    iny
    lda (zpLINE),Y    ; Get next character
    cmp #'A'
    bne ASSDED        ; Ensure 'OR' followed by 'A'

; Continue here when mnemonic is found in table

RDOPGT:
    lda STCODE-1,X
    sta zpOPCODE      ; Get base opcode
    ldy #$01          ; code length is 1
    cpx #IMPLIED+1    ; compare with implied group border
    bcs NGPONE        ; Opcode in next group(s)

; Implied instruction group

MMMM:
    lda PC
    sta zpWORK        ; Get P% low byte

    sty zpWORK+2
    ldx zpBYTESM
    cpx #$04          ; Offset assembly (opt>3), set flags for next bcc

    ldx PC+1
    stx zpWORK+1      ; Get P% high byte
    bcc MMMMLR        ; No offset assembly

    lda VARL_O        ; Get O%, origin
    ldx VARL_O+1

MMMMLR:
    sta zpWORK+3
    stx zpWORK+4      ; Store destination pointer
    tya               ; code length to A
    beq MMMMRT        ; exit, no more bytes
    bpl MMMMLP        ; it's an opcode

    ldy zpCLEN        ; it's a string, length of string in STRACC buffer
    beq MMMMRT        ; exit if string has zero length

MMMMLP:
    dey
    lda zpOPCODE,Y    ; Get opcode byte   (lda abs,y (!))
    bit zpWORK+2
    bpl MMMMCL        ; Opcode - jump to store it

    lda STRACC,Y      ; Get EQUS byte

MMMMCL:
    sta (zpWORK+3),Y  ; Store byte
    inc PC            ; Increment P%
    bne MMMMLQ

    inc PC+1

MMMMLQ:
    bcc MMMMPP

    inc VARL_O        ; increment O%
    bne MMMMPP

    inc VARL_O+1

MMMMPP:
    tya
    bne MMMMLP        ; continue until counter reaches zero

MMMMRT:
    rts

; Branch instruction group

NGPONE:
    cpx #BRANCH+1      ; index for 'AND' opcode
    bcs NGPTWO         ; opcode in next group(s)

    ; it's a branch

    jsr ASEXPR         ; evaluate integer expression to IACC

    ; calculate branching distance

    clc
    lda zpIACC
    sbc PC
    tay
    lda zpIACC+1
    sbc PC+1
    cpy #$01
    dey
    sbc #$00
    beq FWD         ; branch forwards, MSB is zero, probably not out of range

    cmp #$FF        ; MSB of branching distance is $ff, so negative
    beq BACKWARDS   ; branch backwards

BOR:
    lda zpBYTESM            ; check OPT
    and #$02
    beq BRSTOR              ; error not trapped

    jsr fake_brk
    dta 1, 'Out of range', 0

BRSTOR:
    tay             ; Y=A=0

BRSTO:
    sty zpIACC

BRST:
    ldy #$02        ; set code length to 2 bytes
    jmp MMMM        ; join the original code

BACKWARDS:
    tya             ; set flags by copying displacement to A
    bmi BRSTO       ; use displacement, not out of range
    bpl BOR         ; positive for backwards is out of range

FWD:
    tya             ; set flags
    bpl BRSTO       ; positive is good for forward branch
    bmi BOR         ; negative is out of range

; Group 1 instruction group

NGPTWO:
    cpx #GROUP1+1   ; compare with group1 border
    bcs NGPTHR

    jsr SPACES      ; Skip spaces, and get next character

    cmp #'#'
    bne NOTHSH      ; not immediate, skip to next addressing mode

    jsr PLUS8       ; add 8 to the base opcode to correct for immediate

IMMED:
    jsr ASEXPR      ; evaluate integer expression

INDINX:
    lda zpIACC+1    ; check that MSB is zero, i.e. we got an 8-bit value
    beq BRST        ; ok, jump to set code length to 2, and store

    ; immediate argument > 255

BYTE:
    jsr fake_brk
    dta 2, 'Byte', 0

; ----------------------------------------------------------------------------

; Parse (zp),Y addressing mode
; ----------------------------
NGPTHR:
    cpx #COPSTA+1      ; compare with next instruction group border
    bne NOPSTA

    jsr SPACES         ; Skip spaces, and get next character

NOTHSH:
    cmp #'('
    bne NOTIND         ; not indirect

    jsr ASEXPR         ; evaluate integer expression

    jsr SPACES         ; Skip spaces, and get next character
    cmp #')'
    bne ININX          ; branch if possible (zp,x)

    jsr SPACES         ; Skip spaces, and get next character
    cmp #','
    bne BADIND         ; No comma, (zp),y error

    jsr PLUS10         ; add $10 to base opcode

    jsr SPACES         ; Skip spaces, get next character

    cmp #'Y'
    bne BADIND         ; (zp),Y missing Y, jump to Index error
    beq INDINX         ; jump to check operand is a byte, and store/error

; Parse (zp,X) addressing mode
; ----------------------------
ININX:
    cmp #','
    bne BADIND         ; No comma, jump to Index error

    jsr SPACES         ; Skip spaces, and get next character
    cmp #'X'
    bne BADIND         ; zp,X missing X, jump to Index error

    jsr SPACES         ; Skip spaces, and get next character
    cmp #')'
    beq INDINX         ; zp,X) jump to check operand is abyte, and store/error

    ; the error message

BADIND:
    jsr fake_brk
    dta 3, 'Index', 0

    ; check abs,x and abs,y

NOTIND:
    dec zpCURSOR       ; one position back
    jsr ASEXPR         ; evaluate integer expression
    jsr SPACES         ; Skip spaces, and get next character

    cmp #','
    bne OPTIM          ; No comma - jump to process as abs,X

    jsr PLUS10         ; add $10 (16) to opcode
    jsr SPACES         ; Skip spaces, and get next character
    cmp #'X'
    beq OPTIM          ; abs,X - jump to process

    cmp #'Y'
    bne BADIND         ; Not abs,Y - jump to Index error

UNOPT:
    jsr PLUS8          ; add 8 to the opcode
    jmp JSRB           ; go on to indicate instruction length of 3 and continue

    ; abs and abs,X get here

OPTIM:
    jsr PLUS4          ; add 4 to the opcode

OPTIMA:
    lda zpIACC+1
    bne UNOPT          ; check if MSB !=0 (16-bit operand)
    jmp BRST           ; jump to instruction length 2, and store

NOPSTA:
    cpx #DECINC+1      ; check for DECINC group
    bcs NGPFR

    cpx #ASLROR+1      ; check for ASLROR group
    bcs NOTACC         ; skip check for 'A' if INC or DEC

    jsr SPACES         ; Skip spaces, and get next character
    cmp #'A'
    beq ACCUMS         ; brnach if ins A, e.g. ASL A

    dec zpCURSOR       ; one character back

NOTACC:
    jsr ASEXPR         ; evaluate integer expression
    jsr SPACES         ; Skip spaces, and get next character
    cmp #','
    bne OPTIMA         ; No comma, jump to ...

    jsr PLUS10         ; add $10 to opcode
    jsr SPACES         ; Skip spaces, and get next character
    cmp #'X'
    beq OPTIMA         ; handle as address,X

    jmp BADIND         ; Otherwise, jump to Index error

    ; ins A, e.g. ROR A

ACCUMS:
    jsr PLUS4          ; add $04 to opcode

    ldy #$01           ; set instruction length to 1
    bne JSRC           ; and exit

NGPFR:
    cpx #JSRJMP-1      ; check JSRJMP group
    bcs NGPFV

    cpx #CPXCPY+1      ; compare next group border
    beq BIT_           ; BIT does not support immediate addressing mode

    jsr SPACES         ; Skip spaces, and get next character
    cmp #'#'
    bne NHASH          ; Not #, jump to handle address

    jmp IMMED          ; handle immediate mode

NHASH:
    dec zpCURSOR       ; one character back

BIT_:
    jsr ASEXPR         ; evaluate integer expression
    jmp OPTIM          ; handle as abs before

NGPFV:
    cpx #JSRJMP      ; next instruction group
    beq JSR_         ; it's JSR

    bcs NGPSX        ; it's not JMP

    ; it's JMP

    jsr SPACES       ; Skip spaces, and get next character

    cmp #'('
    beq JSRA         ; Jump with (... addressing mode

    dec zpCURSOR

JSR_:
    jsr ASEXPR       ; evaluate integer expression

JSRB:
    ldy #$03         ; set instruction length to 3

JSRC:
    jmp MMMM         ; continue with store

    ; jmp (abs)

JSRA:
    jsr PLUS10
    jsr PLUS10       ; opcode plus $20

    jsr ASEXPR       ; evaluate integer expression
    jsr SPACES       ; Skip spaces, and get next character

    cmp #')'
    beq JSRB         ; jump to instruction length is 3, and continue

    jmp BADIND       ; No ) - jump to Index error

NGPSX:
    cpx #PSEUDO+1    ; check next instruction group
    bcs OPTION

    lda zpWORK+6     ; still contains encoded mnemonic
    eor #$01         ; invert bit 0
    and #$1F         ; ignore all but the bottom 5 bits
    pha              ; save last "letter" for later, source or dest. register

    cpx #PSEUDO-1
    bcs STXY         ; if STX/STY, jump, as they don't allow immediate addr.

    jsr SPACES       ; Skip spaces, and get next character
    cmp #'#'
    bne LDXY         ; jump if not immediate

    pla              ; we don't need it, but we need to fix the stack
    jmp IMMED

LDXY:
    dec zpCURSOR     ; one step back
    jsr ASEXPR       ; evaluate integer expression
    pla              ; destination register back from stack
    sta zpWORK       ; and save

    jsr SPACES       ; Skip spaces, and get next character

    cmp #','
    beq LDIND        ; comma means indexed

    jmp OPTIM        ; jump back to zp or abs code

LDIND:
    jsr SPACES       ; Skip spaces, and get next character
    and #$1F         ; ignore top 3 bits
    cmp zpWORK
    bne LDINDB       ; index error

    jsr PLUS10       ; add $10
    jmp OPTIM        ; same code as before for

LDINDB:
    jmp BADIND       ; Jump to Index error

STXY:
    jsr ASEXPR       ; evaluate integer expression following STX or STY

    pla              ; source register back from stack
    sta zpWORK       ; save

    jsr SPACES       ; Skip spaces, and get next character
    cmp #','
    bne GOOP         ; not indexed

    jsr SPACES       ; Skip spaces, and get next character

    and #$1F         ; bottom 5 bits
    cmp zpWORK
    bne LDINDB       ; index error

    jsr PLUS10       ; add $10 to opcode

    lda zpIACC+1
    beq GOOP         ; High byte=0, continue

    jmp BYTE         ; value>255, jump to Byte error

GOOP:
    jmp OPTIMA       ; 8- or 16-bit operand, and continue

OPTION:
    bne EQUBWS

    ; this is OPT

    jsr ASEXPR       ; evaluate integer expression

    lda zpIACC
    sta zpBYTESM     ; set OPT

    ldy #$00         ; instruction length is 0
    jmp MMMM         ; continue

; ----------------------------------------------------------------------------

EQUBWS:
    ldx #$01          ; Prepare for one byte
    ldy zpCURSOR
    inc zpCURSOR      ; Increment index
    lda (zpLINE),Y    ; Get next character
    cmp #'B'
    beq EQUB

    inx               ; Prepare for two bytes
    cmp #'W'
    beq EQUB

    ldx #$04          ; Prepare for four bytes
    cmp #'D'
    beq EQUB

    cmp #'S'
    beq EQUS
    jmp STDED         ; Syntax error

; enter with X= 1 (bytes), 2 (words), or 4 (dwords),

EQUB:
    txa
    pha                ; save number of bytes per expression on stack

    jsr ASEXPR         ; evaluate the expression

    ldx #zpOPCODE      ; copy IACC to OPCODE and next three bytes
    jsr ACCTOM         ; basically shift one byte up (see vars.s)

    pla
    tay                ; set code length

EQUSX:
    jmp MMMM           ; and continue

EQUSE:
    jmp LETM           ; type mismatch error

EQUS:
    lda zpBYTESM
    pha                ; save current OPT value

    jsr AEEXPR         ; evaluate expression

    bne EQUSE          ; error if not a string

    pla
    sta zpBYTESM       ; restore OPT

    jsr ASCUR          ; move CURSOR to AECUR

    ldy #$FF           ; signal string with code length set to $ff
    bne EQUSX          ; exit

; ----------------------------------------------------------------------------

; Replace of string by a single byte token.
; zpWORK points to the string of characters that are replaced by this token.
; On etry, A contains the token, and Y the string length
; The whole string can be longer than Y, and is terminated by CR ($0d)

INTOK:
    pha                 ; save token
    clc
    tya                 ; number of bytes to remove in A
    adc zpWORK          ; add to pointer
    sta zpWORK+2        ; save in another pointer
    ldy #$00            ; handle MSB, set Y=0 in the process
    tya
    adc zpWORK+1
    sta zpWORK+3
    pla                 ; retrieve token
    sta (zpWORK),Y      ; store

INTOKA:
    iny
    lda (zpWORK+2),Y    ; copy rest of string directly after token
    sta (zpWORK),Y
    cmp #$0D
    bne INTOKA          ; copy until EOL/CR

    ; carry is always set

    rts

; ----------------------------------------------------------------------------

; Convert ASCII number to 16-bit binary and insert as tknCONST
; Y is set to the length of the number. This routine is used to encode
; line numbers. On entry, A contains the first digit, and Y is 0.

CONSTQ:
    and #$0F            ; bottom nibble (top was $3x)
    sta zpWORK+6        ; save as LSB of result
    sty zpWORK+7        ; MSB is 0

CONSTR:
    iny
    lda (zpWORK),Y
    jsr NUMBCP
    bcc CONSTX              ; not a digit

    and #$0F                ; convert to binary digit again (0-9)
    pha                     ; save

    ; multiply 16-bit int by 10
    ;
    ldx zpWORK+7            ; remember original MSB in X
    lda zpWORK+6
    asl                     ; multiply by 2
    rol zpWORK+7
    bmi CONSTY              ; result >= 32768, error

    asl                     ; multiply by 2 (total is *4)
    rol zpWORK+7
    bmi CONSTY              ; result >= 32768, error

    adc zpWORK+6            ; LSB*4 was kept in A, add original
    sta zpWORK+6
    txa                     ; retrieve remembered original MSB
    adc zpWORK+7            ; add new MSB, we now have 4*n+n = 5n

    asl zpWORK+6            ; multiple by 2
    rol
    bmi CONSTY              ; result >= 32768, error
    bcs CONSTY              ; result >= 32768, error

    sta zpWORK+7            ; MSB was in A, save, we now have (4*n+n)*2 = 10n

    pla                     ; finally add our new digit
    adc zpWORK+6
    sta zpWORK+6            ; store
    bcc CONSTR              ; next digit

    inc zpWORK+7            ; adjust MSB
    bpl CONSTR              ; next digit

    pha  ; dummy push because we fallthrough to error condition with pla

CONSTY:
    pla                     ; drop top of stack
    ldy #$00                ; length 0
    sec                     ; C=1 means error/overflow
    rts

; Insert line number into buffer
; zpWORK+0/1 points to ASCII string
; binary representation is in zpWORK+6/7

CONSTX:
    dey                 ; make Y reflect length of line number (string)
    lda #tknCONST
    jsr INTOK           ; insert token, return with carry set(!)
                        ; Y points to CR ($0d)

    lda zpWORK          ; reserve space for binary number
    adc #$02            ; add 3 (!) and save as source pointer
    sta zpWORK+2
    lda zpWORK+1
    adc #$00
    sta zpWORK+3

CONSTL:
    lda (zpWORK),Y      ; copy backwards from $0d location to zero
    sta (zpWORK+2),Y    ; hence creating a gap for the binary number
    dey
    bne CONSTL

    ldy #$03            ; start at 3rd position

; Encode line number constant, see SPGETN for decoder and format
; number is in zpWORK+6/7

CONSTI:                 ; insert constant
    lda zpWORK+7
    ora #$40            ; always 1 bit at bit6
    sta (zpWORK),Y
    dey                 ; 2nd position
    lda zpWORK+6
    and #~$C0
    ora #$40            ; always 1 bit at bit6
    sta (zpWORK),Y
    dey                 ; 1st position
    lda zpWORK+6
    and #$C0
    sta zpWORK+6
    lda zpWORK+7
    and #$C0
    lsr
    lsr
    ora zpWORK+6
    lsr
    lsr
    eor #$54            ; inverse of original bit6 and bit14, and always 1 bit
    sta (zpWORK),Y

    jsr NEXTCH          ; add 3 to the pointer to point to the last byte
    jsr NEXTCH          ; of the integer constant
    jsr NEXTCH

    ldy #$00            ; offset zero

WORDCN:
    clc                 ; success and return
    rts

; Check alphabet and _

WORDCQ:
    cmp #'z'+1
    bcs WORDCN      ; fail > 'z'
    cmp #'_'
    bcs WORDCY      ; succeed >= '_' (0x60 pound sign, ASCII backtick allowed)
    cmp #'Z'+1
    bcs WORDCN      ; fail > 'Z'
    cmp #'A'
    bcs WORDCY      ; succeed >= 'A'

; Check numeric

NUMBCP:
    cmp #'9'+1
    bcs WORDCN          ; fail > '9'
    cmp #'0'
WORDCY:                 ; succeed
    rts

; Check dot

NUMBCQ:
    cmp #'.'
    bne NUMBCP
    rts

; Get character and increment WORK pointer

GETWRK:
    lda (zpWORK),Y

; Only increment pointer

NEXTCH:
    inc zpWORK
    bne RELRTS
    inc zpWORK+1

RELRTS:
    rts

; Increment first, then get character

GETWK2:
    jsr NEXTCH
    lda (zpWORK),Y
    rts

; ----------------------------------------------------------------------------

; Tokenise line at (zpWORK)
; =========================

; Set default values to zero

MATCH:
    ldy #$00
    sty zpWORK+4        ; flags if at the start of a statement or not
                        ; zero, start of statement, otherwise, not

MATCEV:
    sty zpWORK+5        ; flag if numbers are line numbers
                        ; zero, don't tokenise number, otherwise, do

; Usual entry point with flags in zpWORK+4/5 already set

MATCHA:
    lda (zpWORK),Y     ; Get current character
    cmp #$0D
    beq RELRTS         ; Exit with <cr>

    cmp #' '
    bne BMATCH         ; jump if not space

MATCHB:
    jsr NEXTCH         ; skip character, increment WORK pointer
    bne MATCHA         ; and loop

BMATCH:
    cmp #'&'
    bne CMATCH         ; Jump if not '&'

MATCHC:
    jsr GETWK2         ; increment WORK pointer, and get next character
    jsr NUMBCP         ; check if it's a digit
    bcs MATCHC         ; Jump if numeric character

    cmp #'A'
    bcc MATCHA         ; Loop back if <'A'

    cmp #'F'+1
    bcc MATCHC         ; Step to next if 'A'..'F'
    bcs MATCHA         ; Loop back for next character

CMATCH:
    cmp #'"'
    bne DMATCH         ; skip if not '"'

MATCHD:
    jsr GETWK2         ; Increment WORK pointer and get next character
    cmp #'"'
    beq MATCHB         ; Not quote, jump to process next character

    cmp #$0D
    bne MATCHD         ; continue until EOL/CR

    rts

DMATCH:
    cmp #':'
    bne MATCHE         ; skip if not a colon

    sty zpWORK+4       ; mode := left of statement
    sty zpWORK+5       ; constant := tokenise numbers
    beq MATCHB

MATCHE:
    cmp #','
    beq MATCHB          ; return to start if ','

    cmp #'*'
    bne FMATCH          ; skip if not '*'

    lda zpWORK+4
    bne YMATCH          ; test '*' and mode=left

    rts                 ; abort, rest is OSCLI command

FMATCH:
    cmp #'.'
    beq MATCHZ          ; skip if '.'

    jsr NUMBCP          ; check if number
    bcc GMATCH          ; if not, skip

    ldx zpWORK+5        ; tokenize constant?
    beq MATCHZ          ; zero, don't tokenize

    jsr CONSTQ          ; tokenize constant
    bcc MATCHF          ; return to start of tokenisation was successful

MATCHZ:
    lda (zpWORK),Y      ; get current character
    jsr NUMBCQ          ; check for number or period
    bcc MATCHY          ; end found

    jsr NEXTCH          ; increment pointer
    jmp MATCHZ          ; continue scanning to the end of the number

MATCHY:
    ldx #$FF            ; set both flags to $ff
    stx zpWORK+4
    sty zpWORK+5
    jmp MATCHA          ; and jump to start

MATCHW:
    jsr WORDCQ          ; check alphanum
    bcc YMATCH          ; jump if not

MATCHV:
    ldy #$00

MATCHG:
    lda (zpWORK),Y      ; get current character
    jsr WORDCQ          ; check alphanum
    bcc MATCHY          ; jump if not

    jsr NEXTCH
    jmp MATCHG

GMATCH:                ; lookup word (optimised for none present words)
    cmp #'A'
    bcs HMATCH         ; Jump if letter

YMATCH:
    ldx #$FF            ; set both flags
    stx zpWORK+4
    sty zpWORK+5

MATCHF:
    jmp MATCHB          ; loop

    ; lookup keywords, table is in alphabetical order

HMATCH:
    cmp #'X'
    bcs MATCHW         ; Jump if >='X', nothing starts with X,Y,Z

    ldx #<TOKENS
    stx zpWORK+2       ; Point to token table
    ldx #>TOKENS
    stx zpWORK+3

IMATCH:
    cmp (zpWORK+2),Y   ; Special check on first character
    bcc MATCHG         ; lower than 1st character, jump back, variable name
    bne JMATCH         ; no match, skip to next table entry

KMATCH:
    iny
    lda (zpWORK+2),Y
    bmi LMATCH         ; compating with token, end of keyword reached

    cmp (zpWORK),Y
    beq KMATCH          ; match, continue matching

    lda (zpWORK),Y
    cmp #'.'
    beq ABBREV          ; matched '.', deal with abbreviation

    ; move to next table entry

JMATCH:
    iny
    lda (zpWORK+2),Y
    bpl JMATCH          ; keep skipping bytes, until byte >= 0x80, token

    cmp #tknWIDTH       ; last token in list
    bne MMATCH          ; not end of list yet, continue
    bcs MATCHV          ; end of list, skip rest of variable name

ABBREV:
    iny

ABBREA:
    lda (zpWORK+2),Y    ; next character from ROM
    bmi LMATCH          ; jump if token

    inc zpWORK+2        ; add 1 to pointer
    bne ABBREA
    inc zpWORK+3
    bne ABBREA

MMATCH:
    sec                 ; add Y+1 to pointer
    iny
    tya
    adc zpWORK+2
    sta zpWORK+2
    bcc NMATCH

    inc zpWORK+3

NMATCH:                 ; points to next keyword in table
    ldy #$00
    lda (zpWORK),Y
    jmp IMATCH          ; try again

LMATCH:
    tax                 ; token held in x for now
    iny
    lda (zpWORK+2),Y    ; get token flags
    sta zpWORK+6        ; store for later
    dey
    lsr
    bcc OMATCH          ; skip if bit 0 of flags is 0

    lda (zpWORK),Y      ; check last character
    jsr WORDCQ          ; alphanum
    bcs MATCHV          ; stop tokenising

OMATCH:
    txa                 ; token back to A
    bit zpWORK+6
    bvc WMATCH          ; skip if bit 6 of flags is set

    ldx zpWORK+4        ; mode = left of statement?
    bne WMATCH          ; skip if not start of statement

        clc             ; Superflous as all paths to here have CLC

    adc #tknPTR2-tknPTR ; add $40 to the token

WMATCH:
    dey
    jsr INTOK           ; insert token

    ldy #$00            ; future new flags
    ldx #$FF

    lda zpWORK+6
    lsr
    lsr
    bcc QMATCH          ; skip to QMATCH if bit 1 of token flags not set

    stx zpWORK+4        ; mode=right, not start of statement
    sty zpWORK+5        ; constant=false, do not tokenise numbers

QMATCH:
    lsr
    bcc RMATCH          ; skip if bit 2 of token flags is not set

    sty zpWORK+4        ; mode=left, start of statement
    sty zpWORK+5        ; constant=false, do not tokenise

RMATCH:
    lsr
    bcc TMATCH          ; skip following section if bit 3 of flags is not set

    pha                 ; save shifted flags
    iny                 ; make Y=1

SMATCH:
    lda (zpWORK),Y      ; get character
    jsr WORDCQ          ; check alphanum
    bcc XMATCH          ; stop if not

    jsr NEXTCH
    jmp SMATCH          ; loop

XMATCH:
    dey
    pla                 ; restore tokenise flags

TMATCH:
    lsr
    bcc UMATCH          ; skip if bit 4 of tokenise flags is set

    stx zpWORK+5        ; constant=true, tokenise line numbers

UMATCH:
    lsr
    bcs AESPAR          ; return immediately if bit of tokenise flags is set
    jmp MATCHB          ; otherwise, go back to the start

; ----------------------------------------------------------------------------

; Skip Spaces, get next character from AELINE at AECUR
; ----------------------------------------------------
AESPAC:
    ldy zpAECUR        ; Get offset
    inc zpAECUR        ; increment it
    lda (zpAELINE),Y   ; Get current character
    cmp #' '
    beq AESPAC         ; Loop until not space
AESPAR:
    rts

; ----------------------------------------------------------------------------

; Skip spaces, get next character from the LINE at CURSOR
; -------------------------------------------------------
SPACES:
    ldy zpCURSOR
    inc zpCURSOR
    lda (zpLINE),Y
    cmp #' '
    beq SPACES

    ; return with zpCURSOR position in Y

COMRTS:
    rts

; ----------------------------------------------------------------------------

; Check for comma at AELINE

COMEAT:
    jsr AESPAC              ; get character
    cmp #','
    beq COMRTS          ; equal, ok

COMERR:
    jsr fake_brk
    dta 5, 'Missing ,', 0

; ----------------------------------------------------------------------------

; OLD - Attempt to restore program
; ================================
; OLD command does ?&3001=0, finds new end of text and frees

OLD:
    jsr DONE          ; Check end of statement
    lda zpTXTP
    sta zpWORK+1      ; Point zpWORK to PAGE
    lda #$00
    sta zpWORK
    sta (zpWORK),Y    ; Remove end marker
    jsr ENDER         ; Check program and set TOP
    bne FSASET        ; Jump to clear heap and go to immediate mode

; ----------------------------------------------------------------------------

; END - Return to immediate mode
; ==============================
; END statement finds end of text and stops

END:
    jsr DONE          ; Check end of statement
    jsr ENDER         ; Check program and set TOP
    bne CLRSTK        ; Jump to immediate mode, keeping variables, etc

; ----------------------------------------------------------------------------

; STOP - Abort program with an error
; ==================================
; STOP statement prints that it has stopped

STOP:
    jsr DONE         ; Check end of statement
    jsr fake_brk
    dta 0, tknSTOP, 0

; ----------------------------------------------------------------------------

; NEW - Clear program, enter immediate mode
; =========================================
; NEW comand clears text and frees

; Cold start

NEW:
    jsr DONE          ; Check end of statement

; Start up with NEW program
; -------------------------
FORMAT:
    lda #$0D       ; EOL/CR
    ldy zpTXTP
    sty zpTOP+1    ; TOP hi=PAGE hi
    ldy #$00
    sty zpTOP      ; TOP lo=0
    sty zpTRFLAG   ; TRACE OFF
    sta (zpTOP),Y  ; place CR at PAGE/TOP
    lda #$FF
    iny
    sta (zpTOP),Y  ; place $ff after that
    iny
    sty zpTOP      ; TOP=PAGE+2

    mwa #FSASET warmstart_here

; Warm start

FSASET:
    jsr SETFSA         ; Clear variables, heap, stack

; IMMEDIATE LOOP
; ==============

CLRSTK:
    ldy #>BUFFER       ; point zpLINE to keyboard buffer
    sty zpLINE+1
    ldy #<BUFFER
    sty zpLINE
    lda #<BASERR       ; default error message
    sta zpERRORLH
    lda #>BASERR
    sta zpERRORLH+1
    lda #'>'
    jsr BUFF           ; Print '>' prompt, read input to buffer at (zpWORK)

; Execute line at program pointer in zpLINE
; -----------------------------------------

RUNTHG:
    lda #<BASERR       ; default error message
    sta zpERRORLH
    lda #>BASERR
    sta zpERRORLH+1

    ldx #$FF
    stx zpBYTESM       ; OPT=$FF - not within assembler
    stx zpWORK+5       ; constant, enable tokenising line number
    txs                ; Clear machine stack

    jsr SETVAR         ; Clear DATA and stacks, returns with A=0

    tay                ; Y=0
    lda zpLINE         ; Point zpWORK to program line
    sta zpWORK
    lda zpLINE+1
    sta zpWORK+1
    sty zpWORK+4       ; mode is start/left of statement
    sty zpCURSOR       ; reset CURSOR position

    jsr MATCHA         ; tokenise keyboard buffer
    jsr SPTSTN         ; see if it started with a line number
    bcc DC             ; jump forward if no line number

    jsr INSRT          ; Insert into program
    jmp FSASET         ; Jump back to immediate loop

; Command entered at immediate prompt
; -----------------------------------

DC:                    ; Direct Command
    jsr SPACES         ; Skip spaces at (zpLINE)
    cmp #tknAUTO       ; first command token
    bcs DISPATCH       ; if command token, jump to execute command
    jcc LETST          ; not command token, try variable assignment
                       ; jcc because after fake_brk patch it is out of range

LEAVE:                 ; trampoline for branches below
    jmp CLRSTK         ; Jump back to immediate mode

; [ - enter assembler
; ===================

JUMPASS:
    jmp ASS         ; Jump to assembler

; =<value> - return from FN
; =========================
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

FNRET:
    tsx
    cpx #$FC
    bcs FNERR     ; If stack is empty, jump to give error

    lda $01FF
    cmp #tknFN
    bne FNERR     ; If pushed token != 'FN', give error

    jsr AEEXPR    ; Evaluate expression
    jmp FDONE     ; Check for end of statement and return to pop from function

FNERR:
    jsr fake_brk
    dta 7, 'No ', tknFN, 0

; ----------------------------------------------------------------------------

; Check for =, *, [ commands
; ==========================

OTSTMT:
    ldy zpCURSOR
    dey               ; step program pointer back
    lda (zpLINE),Y    ; get the character
    cmp #'='
    beq FNRET         ; Jump for '=', return from FN

    cmp #'*'
    beq DOS           ; Jump for '*', embedded *command

    cmp #'['
    beq JUMPASS       ; Jump for '[', start assembler
    bne SUNK          ; Otherwise, see if end of statement

; ----------------------------------------------------------------------------

; Embedded *command
; =================

DOS:
    jsr CLYADP         ; Update zpLINE to current address

    ldx zpLINE
    ldy zpLINE+1       ; XY => command string

    .ifdef MOS_BBC
        jsr OS_CLI     ; Pass command at (zpLINE) to OSCLI
    .endif

; DATA, DEF, REM, ELSE
; ====================
; Skip to end of line
; -------------------

DATA:
DEF:
REM:
    lda #$0D         ; EOL/CR to match to
    ldy zpCURSOR     ; get program pointer
    dey              ; pre-decrement because loops start with iny

ILP:
    iny
    cmp (zpLINE),Y
    bne ILP          ; Loop until <cr> found

ENDEDL:
    cmp #tknELSE
    beq REM          ; If 'ELSE', jump to skip to end of line

    lda zpLINE+1
    cmp #>BUFFER     ; Program in command buffer?
    beq LEAVE        ; if so, jump back to immediate loop

    jsr LINO

    bne STMT         ; Check for end of program, step past <cr>

; Main execution loop
; -------------------

SUNK:
    dec zpCURSOR

DONEXT:
    jsr DONE          ; check for end of statement

NXT:
    ldy #$00
    lda (zpLINE),Y    ; Get current character
    cmp #':'
    bne ENDEDL        ; Not <colon>, check for ELSE

STMT:
    ldy zpCURSOR      ; Get program pointer
    inc zpCURSOR      ; increment for next time
    lda (zpLINE),Y    ; Get current character
    cmp #' '
    beq STMT          ; Skip spaces, and get next character

    cmp #tknPTR2
    bcc LETST         ; Not program command, jump to try variable assignment

; Dispatch function/command
; -------------------------

DISPATCH:
    tax                         ; Index into dispatch table
    lda ADTABL-FIRST_TOKEN,X    ; Get routine address from table
    sta zpWORK
    lda ADTABH-FIRST_TOKEN,X
    sta zpWORK+1
    jmp (zpWORK)        ; Jump to routine

; ----------------------------------------------------------------------------

; Not a command byte, try variable assignment, or =, *, [
; -------------------------------------------------------

LETST:
    ldx zpLINE
    stx zpAELINE    ; Copy LINE to AELINE
    ldx zpLINE+1
    stx zpAELINE+1
    sty zpAECUR

    jsr LVCONT      ; Check if variable or indirection
    bne GOTLT       ; NE - jump for existing variable or indirection assignment
    bcs OTSTMT      ; CS - not variable assignment, try =, *, [ commands

; Variable not found, create a new one
; ------------------------------------
    stx zpAECUR
    jsr EQEAT         ; Check (zpAELINE) for '=' and step past
    jsr CREATE        ; Create new variable

    ldx #$05          ; X=$05 = float
    cpx zpIACC+2
    bne LETSZ         ; Jump if dest. not a float

    inx               ; X=$06

LETSZ:
    jsr CREAX
    dec zpCURSOR

; LET variable = expression
; =========================

LET:
    jsr CRAELV
    beq NOLET

GOTLT:
    bcc LETED
    jsr PHACC         ; Stack integer (address of data)
    jsr EQEXPR        ; Check for end of statement

    lda zpTYPE        ; Get evaluation type
    bne LETM          ; If not string, error

    jsr STSTOR        ; Assign the string
    jmp NXT           ; Return to execution loop

LETED:
    jsr PHACC         ; Stack integer (address of data)
    jsr EQEXPR        ; Check for end of statement
    lda zpTYPE        ; Get evaluation type
    beq LETM          ; If not number, error

    jsr STORE         ; Assign the number
    jmp NXT           ; Return to execution loop

NOLET:
    jmp STDED         ; syntax error

LETM:
    jsr fake_brk
    dta 6, 'Type mismatch', 0

; String Assignments

STSTOR:
    jsr POPACC       ; Unstack integer (address of data)

STSTRE:
    lda zpIACC+2
    cmp #$80
    beq NSTR         ; Jump if absolute string $addr

    ldy #$02
    lda (zpIACC),Y
    cmp zpCLEN
    bcs ALLOCX       ; old mlen >= to new len, enough room

    lda zpFSA        ; save current setting of VARTOP/FSA
    sta zpIACC+2
    lda zpFSA+1
    sta zpIACC+3

    lda zpCLEN
    cmp #$08         ; if <8 characters then use this as mlen
    bcc ALLOCU

    adc #$07         ; add 8 because carry is set, some room for growth
    bcc ALLOCU       ; jump if no (unsigned) overflow

    lda #$FF         ; give the string a length of $ff

ALLOCU:
    clc
    pha              ; save (new) length on stack
    tax              ; and in X
    lda (zpIACC),Y
    ldy #$00
    adc (zpIACC),Y
    eor zpFSA
    bne ALLJIM       ; is new space contiguous to old?

    iny
    adc (zpIACC),Y
    eor zpFSA+1
    bne ALLJIM      ; is new space contiguous to old?

    sta zpIACC+3    ; new space is, so reduce amount needed
    txa
    iny
    sec
    sbc (zpIACC),Y
    tax

ALLJIM:
    txa             ; get length to be allocated from X
    clc
    adc zpFSA       ; add VARTOP
    tay             ; store in Y

    lda zpFSA+1     ; MSB of VARTOP
    adc #$00        ; add possible carry

    cpy zpAESTKP    ; are we hitting our heads on the roof?
    tax             ; resulting MSB in X
    sbc zpAESTKP+1
    bcs ALLOCR      ; jump to No room error

    sty zpFSA       ; store LSB
    stx zpFSA+1     ; store MSB

    pla             ; get back the allocated length of the new string
    ldy #$02
    sta (zpIACC),Y  ; save new mlen
    dey
    lda zpIACC+3
    beq ALLOCX      ; we have expanded the same starting location

    sta (zpIACC),Y  ; change the start address of the string, save MSB
    dey
    lda zpIACC+2
    sta (zpIACC),Y  ; save LSB

ALLOCX:
    ldy #$03
    lda zpCLEN      ; get the length of the string
    sta (zpIACC),Y  ; store it in the block
    beq STDONE      ; return if length is zero

    dey
    dey
    lda (zpIACC),Y  ; copy MSB and LSB of start address and store it
    sta zpIACC+3
    dey
    lda (zpIACC),Y
    sta zpIACC+2

LTCVRM:
    lda STRACC,Y        ; get character from string buffer
    sta (zpIACC+2),Y    ; save it in the variable area
    iny
    cpy zpCLEN
    bne LTCVRM          ; continue until the end of the string is met

STDONE:
    rts

; ----------------------------------------------------------------------------

; Assignments for defined address strings

NSTR:
    jsr OSSTRT      ; place CR at end of string, returns w/ A=$0d and Y=length
    cpy #$00
    beq NSTRX       ; zero length string, jump to end

NSLOOP:
    lda STRACC,Y    ; copy from string buffer
    sta (zpIACC),Y  ; to variable
    dey
    bne NSLOOP      ; untile Y becomes zero

    lda STRACC      ; last byte

NSTRX:
    sta (zpIACC),Y  ; store and exit
    rts

; ----------------------------------------------------------------------------

ALLOCR:
    jsr fake_brk
    dta 0, 'No room', 0

; ----------------------------------------------------------------------------

; Unstack a parameter

STORST:
    lda zpWORK+2        ; get type of item
    cmp #$80
    beq STORSX          ; jump if it's a string at a defined address
    bcc STORIT          ; jump if it's numeric

    ldy #$00            ; it's a dynamic string
    lda (zpAESTKP),Y    ; get length from top of stack
    tax                 ; save in X
    beq STORSY          ; skip copy if length is 0

    lda (zpWORK),Y      ; subtract 1 because of length byte
    sbc #$01
    sta zpWORK+2        ; store as new pointer
    iny
    lda (zpWORK),Y
    sbc #$00
    sta zpWORK+3

STORSL:
    lda (zpAESTKP),Y    ; get character from stacked string
    sta (zpWORK+2),Y    ; save in variable area
    iny
    dex
    bne STORSL          ; continue until length is zero

STORSY:
    lda (zpAESTKP,X)    ; get length of string again (X=0)
    ldy #$03
STORSW:
    sta (zpWORK),Y      ; save in string information block
    jmp POPSTX          ; discard string on top of stack

    ; strings at fixed address

STORSX:
    ldy #$00
    lda (zpAESTKP),Y    ; get length of string
    tax                 ; save in X
    beq STORSZ          ; jump if length is 0

STORSV:
    iny
    lda (zpAESTKP),Y    ; get character
    dey                 ; adjust for different indeces, double iny in loop
    sta (zpWORK),Y      ; store in variable
    iny
    dex
    bne STORSV          ; loop until length is zero

STORSZ:
    lda #$0D            ; place CR at end of string
    bne STORSW

    ; numeric entries

STORIT:
    ldy #$00
    lda (zpAESTKP),Y    ; get first byte
    sta (zpWORK),Y      ; and save it

    ldy #4
    lda zpWORK+2
    beq STORIY          ; exit, it's an 8-bit value, but leave with Y=4 (why?)

    ldy #$01            ; continue with Y=1 again
    lda (zpAESTKP),Y    ; second byte
    sta (zpWORK),Y

    iny
    lda (zpAESTKP),Y    ; third byte
    sta (zpWORK),Y

    iny
    lda (zpAESTKP),Y    ; fourth byte
    sta (zpWORK),Y

    iny
    cpy zpWORK+2        ; check if it's float
    bcs STORIY

    lda (zpAESTKP),Y    ; fifth byte
    sta (zpWORK),Y
    iny

STORIY:
    tya                 ; transfer number of bytes to A
    clc
    jmp POPN            ; pop A number of bytes

; ----------------------------------------------------------------------------

; PRINT#, called indirect via PRINT routine when # is detected

PRINTH:
    dec zpCURSOR        ; correct cursor position
    jsr AECHAN          ; find out file handle number, returns in Y and A

PRINHL:
    tya                 ; file handle to A
    pha                 ; and save
    jsr AESPAC          ; get next character
    cmp #','
    bne PRINHX          ; exit if not a comma

    jsr EXPR            ; evaluate expression
    jsr STARGA          ; store FACC in workspace temporary FWSA

    pla                 ; get file handle
    tay                 ; transfer back to Y
    lda zpTYPE
    jsr OSBPUT          ; write type of item to file

    tax                 ; type of item to X
    beq PRINHS          ; jump if item is a string
    bmi PRINHF          ; jump if item is floating point

    ; item is integer

    ldx #$03            ; 4 bytes (3-0), MSB first
PRINHQ:
    lda zpIACC,X
    jsr OSBPUT          ; write integer to file
    dex
    bpl PRINHQ
    bmi PRINHL          ; loop back to check for comma

PRINHF:
    ldx #$04            ; float is 5 bytes (4-0)

PRINHP:
    lda FWSA,X
    jsr OSBPUT          ; write float from workspace temporary FWSA
    dex
    bpl PRINHP
    bmi PRINHL          ; loop back to check for comma

PRINHS:
    lda zpCLEN
    jsr OSBPUT          ; write string length
    tax
    beq PRINHL          ; loop back to check for comma if length is 0

PRINHO:
    lda STRACC-1,X
    jsr OSBPUT          ; write string backwards
    dex
    bne PRINHO
    beq PRINHL          ; loop back to check for comma

PRINHX:
    pla                 ; get handle from stack
    sty zpCURSOR        ; save current offset
    jmp DONEXT

; end of PRINT statement

DEDPRC:
    jsr NLINE         ; Output new line and set COUNT to zero
DEDPR:
    jmp SUNK          ; Check end of statement, return to execution loop

; semi-colon encountered

PRFUNY:
    lda #$00
    sta zpPRINTS      ; Set current field to zero
    sta zpPRINTF      ; hex/dec flag to decimal

    jsr SPACES        ; Get next non-space character
    cmp #':'
    beq DEDPR         ; <colon> found, finish printing

    cmp #$0D
    beq DEDPR         ; <cr> found, finish printing

    cmp #tknELSE
    beq DEDPR         ; 'ELSE' found, finish printing
    bne CONTPR        ; Otherwise, continue into main loop

; PRINT [~][print items]['][,][;]
; ===============================

PRINT:
    jsr SPACES         ; Get next non-space char
    cmp #'#'
    beq PRINTH         ; If '#' jump to do PRINT#

    dec zpCURSOR
    jmp STRTPR         ; Jump into PRINT loop

; Print a comma

PRCOMM:
    lda VARL_AT
    beq STRTPR       ; If field width zero, no padding needed
                     ; jump back into main loop

    ; padding

    lda zpTALLY      ; Get COUNT

PRCOML:
    beq STRTPR       ; Zero, just started a new line, no padding
                     ; jump back into main print loop

    sbc VARL_AT      ; Get COUNT-field width
    bcs PRCOML       ; Loop to reduce until (COUNT MOD fieldwidth)<0

    tay              ; Y=number of spaces to get back to (COUNT MOD width)=zero
                     ; Y is a negative number

PRCOMO:
    jsr LISTPT
    iny
    bne PRCOMO       ; Loop to print required spaces until Y=0

STRTPR:
    clc              ; Prepare to print decimal
    lda VARL_AT
    sta zpPRINTS     ; Set current field width from @%

AMPER:
    ror zpPRINTF     ; Set hex/dec flag from Carry

ENDPRI:
    jsr SPACES       ; Get next non-space character

    cmp #':'
    beq DEDPRC       ; End of statement if <colon> found

    cmp #$0D
    beq DEDPRC       ; End if statement if <cr> found

    cmp #tknELSE
    beq DEDPRC       ; End of statement if 'ELSE' found

CONTPR:
    cmp #'~'
    beq AMPER        ; Jump back to set hex/dec flag from Carry, C=1

    cmp #','
    beq PRCOMM       ; Jump to pad to next print field

    cmp #';'
    beq PRFUNY       ; Jump to check for end of print statement

    jsr PRSPEC       ; Check for ' TAB SPC
    bcc ENDPRI       ; if print token found return to outer main loop

; All print formatting have been checked, so it now must be an expression

    lda zpPRINTS
    pha               ; save field width
    lda zpPRINTF
    pha               ; save hex flags, as evaluator might call PRINT
                      ; for example if a FN call uses PRINT
    dec zpAECUR       ; account for not finding anything so far
    jsr EXPR          ; Evaluate expression

    pla
    sta zpPRINTF      ; restore width
    pla
    sta zpPRINTS      ; restore hex flag

    lda zpAECUR
    sta zpCURSOR      ; Update program pointer
    tya
    beq PSTR          ; If type=0, jump to print string

    jsr FCON          ; Convert numeric value to string

    lda zpPRINTS      ; Get current field width
    sec
    sbc zpCLEN        ; A=width-stringlength
    bcc PSTR          ; length>width - print it
    beq PSTR          ; length=width - print it

    tay               ; Otherwise, Y=number of spaces to pad with
FPRNL:
    jsr LISTPT        ; print a space
    dey
    bne FPRNL         ; Loop to print required spaces to pad the number

; Print string in string buffer

PSTR:
    lda zpCLEN
    beq ENDPRI        ; Null string, jump back to main loop

    ldy #$00          ; Point to start of string
LOOP:
    lda STRACC,Y
    jsr CHOUT         ; Print character from string buffer
    iny
    cpy zpCLEN
    bne LOOP          ; Increment pointer, loop for full string

    beq ENDPRI        ; Jump back for next print item, branch always

TABCOM:
    jmp COMERR        ; 'Missing,' error

; TAB(X,Y) routine

TAB2:
    cmp #','
    bne TABCOM        ; No comma, jump to COMERR

    lda zpIACC
    pha               ; Save X coordinate of destination

    jsr BRA           ; evaluate expression and check for closing bracket
    jsr INTEGB        ; ensure result was an integer

; BBC - send VDU 31,x,y sequence
; ------------------------------
    .ifdef MOS_BBC
        lda #$1F
        jsr OSWRCH    ; TAB()
        pla
        jsr OSWRCH    ; X coord
        jsr WRIACC    ; Y coord
    .endif

    jmp PRTSTM        ; Continue to next PRINT item

; TAB(X) routine

TAB:
    jsr INEXPR         ; get integer expression
    jsr AESPAC         ; get next character
    cmp #')'
    bne TAB2           ; jump if not ')', try TAB(X,Y)

    ; carry is set

    lda zpIACC         ; destination column
    sbc zpTALLY        ; minus current column
    beq PRTSTM         ; jump if equal

    tax
    bcs SPCLOP         ; jump if difference is positive

    jsr NLINE          ; new line
    beq SPCT           ; jump to SPC routine, w/o getting integer expression

; SPC routine

SPC:
    jsr INTFAC         ; evaluate argument

SPCT:
    ldx zpIACC
    beq PRTSTM          ; jump if number of space is 0

SPCLOP:
    jsr LISTPL      ; print spaces, counter in X
    beq PRTSTM          ; skip jsr NLINE

PRCR:
    jsr NLINE

PRTSTM:
    clc                 ; clear carry to indicate item was dealt with
    ldy zpAECUR
    sty zpCURSOR        ; update cursor
    rts

PRSPEC:
    ldx zpLINE          ; set zpAELINE to zpLINE
    stx zpAELINE
    ldx zpLINE+1
    stx zpAELINE+1
    ldx zpCURSOR        ; also copy cursor offset
    stx zpAECUR

    cmp #$27            ; '
    beq PRCR

    cmp #tknTAB
    beq TAB

    cmp #tknSPC
    beq SPC

    sec                 ; indicate nothing was found

PRTSTO:
    rts

PRTSTN:
    jsr SPACES         ; Skip spaces, and get next character
    jsr PRSPEC
    bcc PRTSTO

    cmp #'"'
    beq PRSTRN

    sec
    rts

NSTNG:
    jsr fake_brk
    dta 9, 'Missing ', '"', 0

; print quoted string

PCH:
    jsr CHOUT           ; print character

PRSTRN:
    iny
    lda (zpAELINE),Y
    cmp #$0D
    beq NSTNG           ; print 'Missing "' if next character is CR

    cmp #'"'
    bne PCH             ; not '"', so print character

    iny
    sty zpAECUR
    lda (zpAELINE),Y
    cmp #'"'
    bne PRTSTM          ; check for another " to handle "", jump if not
    beq PCH             ; branch always, print "

; ----------------------------------------------------------------------------

.if .def TARGET_ATARI

CLG:
    jsr clg_intercept
    jmp NXT
CLS:
    jsr cls_intercept
    jmp NXT

.else
; CLG
; ===
CLG:
    jsr DONE         ; Check end of statement
    lda #$10
    bne DOCL         ; Jump to do VDU 16, branch always

; CLS
; ===
CLS:
    jsr DONE         ; Check end of statement
    jsr BUFEND       ; Set COUNT to zero
    lda #$0C         ; Do VDU 12

DOCL:
    jsr OSWRCH
    jmp NXT          ; jump to execution loop
.endif

; ----------------------------------------------------------------------------

; CALL numeric [,items ... ]
; ==========================
CALL:
    jsr AEEXPR          ; evaluate expression, address of routine
    jsr INTEG           ; ensure it's an integer
    jsr PHACC           ; save on stack

    ldy #$00
    sty STRACC          ; zero number of parameters

CALLLP:
    sty ws+$06FF        ; pointer into parameter area
    jsr AESPAC          ; get next character

    cmp #','
    bne CALLDN          ; jump out of loop if no comma

    ldy zpAECUR
    jsr LVBLNKplus1     ; get variable name
    beq CALLFL          ; No such variable error

    ldy ws+$06FF
    iny
    lda zpIACC
    sta STRACC,Y        ; LSB of parameter address

    iny
    lda zpIACC+1
    sta STRACC,Y        ; MSB of parameter address

    iny
    lda zpIACC+2
    sta STRACC,Y        ; type of parameter

    inc STRACC          ; increment number of parameters

    jmp CALLLP

CALLDN:
    dec zpAECUR
    jsr AEDONE      ; check for end of statement
    jsr POPACC      ; pull address of the stack
    jsr USER        ; Set up registers and call code at IACC

    cld             ; ensure Binary mode on return
    jmp NXT         ; jump back to program loop

CALLFL:
    jmp FACERR

; Call code
; ---------
USER:
    lda VARL_C          ; get carry from C%
    lsr
    lda VARL_A          ; get A from A%
    ldx VARL_X          ; get X from X%
    ldy VARL_Y          ; get Y from Y%
    .if .def TARGET_C64
        jmp $ff9b
    .else
        jmp (zpIACC)    ; Jump to address in IACC
    .endif

; ----------------------------------------------------------------------------

DELDED:
    jmp STDED           ; Syntax error

; DELETE linenum, linenum
; =======================

DELETE:
    jsr SPTSTN          ; decode line number after the word DELETE
    bcc DELDED          ; syntax error

    jsr PHACC           ; push line number to the stack
    jsr SPACES
    cmp #','
    bne DELDED          ; no comma, syntax error

    jsr SPTSTN          ; decode next line number
    bcc DELDED          ; syntax error

    jsr DONE            ; check end of statement

    lda zpIACC          ; second line number to work pointer (zpWORK+2)
    sta zpWORK+2
    lda zpIACC+1
    sta zpWORK+3

    jsr POPACC          ; pop first line number into IACC

DODELS:
    jsr REMOVE          ; delete line number in IACC
    jsr TSTBRK          ; check escape key
    jsr INCACC          ; increment line number in IACC

    lda zpWORK+2        ; compare with second line number in zpWORK+2/3
    cmp zpIACC
    lda zpWORK+3
    sbc zpIACC+1
    bcs DODELS          ; continue removing if <

    jmp FSASET          ; jump to warm start

;  ----------------------------------------------------------------------------

; Increment IACC by 1

INCACC:
    inc zpIACC
    bne INCDON
    inc zpIACC+1
    bne INCDON
    inc zpIACC+2
    bne INCDON
    inc zpIACC+3
INCDON:
    rts

; ----------------------------------------------------------------------------

; Integer Multiply, 16-bit, top of stack * IACC, result in IACC

SMUL:
    ldx #zpWORK+8
    jsr POPX            ; pop 32-bit int from AE stack

; multiply as 16-bit int with IACC as 16-bit int

WMUL:
    ldx #$00        ; X and Y are used as accumulators where the answer
    ldy #$00        ; is built up. Clear on entry

SMULA:
    lsr zpWORK+9    ; get least significant bit of multiplicand
    ror zpWORK+8
    bcc SMULB       ; do not add the multiplier to the YX accu if clear

    clc             ; add multiplier (zpIACC) to YX accu
    tya
    adc zpIACC
    tay
    txa
    adc zpIACC+1
    tax
    bcs SMULXE      ; 'Bad DIM' error on overflow

SMULB:
    asl zpIACC      ; multiply multiplier by 2 (one left shift)
    rol zpIACC+1

    lda zpWORK+8    ; check multiplicand
    ora zpWORK+9
    bne SMULA       ; continue until it's zero

    .if .hi(SMULA) != .hi(*)
        .error "ASSERT: SMUL loop crosses page"
    .endif

    sty zpIACC      ; store final answer
    stx zpIACC+1
    rts

SMULXE:
    jmp NOTGO

; ----------------------------------------------------------------------------

; HIMEM=numeric
; =============

LHIMM:
    jsr INEQEX          ; Set past '=', evaluate integer

    lda zpIACC
    sta zpHIMEM
    sta zpAESTKP        ; Set HIMEM and AE STACK pointer
    lda zpIACC+1
    sta zpHIMEM+1
    sta zpAESTKP+1

    jmp NXT             ; Jump back to execution loop

; ----------------------------------------------------------------------------

; LOMEM=numeric
; =============

LLOMM:
    jsr INEQEX         ; Step past '=', evaluate integer

    lda zpIACC
    sta zpLOMEM
    sta zpFSA          ; Set LOMEM and VARTOP
    lda zpIACC+1
    sta zpLOMEM+1
    sta zpFSA+1
    jsr SETVAL         ; Clear the dynamic variables catalogue

    beq LPAGEX         ; branch always, jump to execution loop

; ----------------------------------------------------------------------------

; PAGE=numeric
; ============

LPAGE:
    jsr INEQEX         ; Step past '=', evaluate integer
    lda zpIACC+1
    sta zpTXTP         ; Set PAGE
LPAGEX:
    jmp NXT            ; Jump to execution loop

; ----------------------------------------------------------------------------

; CLEAR
; =====

CLEAR:
    jsr DONE           ; Check end of statement
    jsr SETFSA         ; Clear heap, stack, data, variables
    beq LPAGEX         ; Jump to execution loop

; ----------------------------------------------------------------------------

; TRACE ON | OFF | numeric
; ========================

TRACE:
    jsr SPTSTN         ; check for line number
    bcs TRACNM         ; If line number, jump for TRACE linenum

    cmp #tknON
    beq TRACON         ; Jump for TRACE ON

    cmp #tknOFF
    beq TOFF           ; Jump for TRACE OFF

    jsr ASEXPR         ; Evaluate integer

; TRACE numeric
; -------------

TRACNM:
    jsr DONE           ; Check end of statement
    lda zpIACC
    sta zpTRNUM        ; Set trace limit low byte
    lda zpIACC+1
TRACNO:
    sta zpTRNUM+1      ; Set trace limit high byte
    lda #$FF           ; set TRACE ON
TRACNN:
    sta zpTRFLAG       ; Set TRACE flag
    jmp NXT            ; return to execution loop

; ----------------------------------------------------------------------------

; TRACE ON
; --------

TRACON:
    inc zpCURSOR       ; Step past
    jsr DONE           ; check end of statement
    lda #$FF
    bne TRACNO         ; Jump to set TRACE $FFxx

; ----------------------------------------------------------------------------

; TRACE OFF
; ---------

TOFF:
    inc zpCURSOR       ; Step past
    jsr DONE           ; check end of statement
    lda #$00
    beq TRACNN         ; Jump to set TRACE OFF

; ----------------------------------------------------------------------------

; vi:syntax=mads
