; ----------------------------------------------------------------------------
;
; BBC BASIC 3.10 -- NMOS 6502
;
; Conversion to mads, labelling, bug fixes, and more comments by
; Ivo van Poorten, September 2025
;
; Based on source reconstruction and commentary © 2018 J.G. Harston
; https://mdfs.net/Software/BBCBasic/BBC/
;
; BBC BASIC Copyright © 1982/1983 Acorn Computer and Sophie Wilson
;
; References used:
;   Advanced BASIC ROM User Guide
;   AcornCmosBasic (https://github.com/stardot/AcornCmosBasic)
;   AcornDmosBasic (https://github.com/stardot/AcornDmosBasic)
;   AcornBasic128  (https://github.com/stardot/AcornBasic128)
;   BBC Micro Compendium
;
; ----------------------------------------------------------------------------

    membot    = 0           ; Use OSBYTE to find memory limits
    memtop    = 0           ; ...

    F_LOAD  = zpWORK+2      ; LOAD/SAVE control block
    F_EXEC  = F_LOAD+4
    F_START = F_LOAD+8
    F_END   = F_LOAD+12

    .if .def TARGET_BBC

        opt h-                     ; No Atari header(s)

        MOS_BBC    = 1
        romstart  = $b800          ; Code start address
        workspace = $0400
        zp        = $00            ; Start of ZP addresses
        FAULT     = $fd            ; Pointer to error block
        ESCFLG    = $ff            ; Escape pending flag
        BRKV      = $0202
        WRCHV     = $020E

    .elseif .def TARGET_ATARI

        MOS_BBC   = 1
        workspace = $3800
        zp        = $80            ; Start of ZP addresses
        FAULT     = $fd            ; Pointer to error block
        ESCFLG    = $ff            ; Escape pending flag
        BRKV      = VBREAK
        WRCHV     = 0

    .else
        .error "Please specify your build (i.e. -d:TARGET_ATARI=1)"
    .endif

    .if .def MOS_BBC && .not .def NO_MOS_VECTORS

        OSFIND = $FFCE
        OSBPUT = $FFD4
        OSBGET = $FFD7
        OSFILE = $FFDD
        OSARGS = $FFDA
        OSRDCH = $FFE0
        OSASCI = $FFE3
        OSWRCH = $FFEE
        OSNEWL = $FFE7
        OSWORD = $FFF1
        OSBYTE = $FFF4
        OS_CLI = $FFF7

    .elseif .def NO_MOS_VECTORS

    .else
        .error "No MOS API specified"
    .endif

    .if <workspace != 0
        .error "workspace must be page aligned"
    .endif

; ----------------------------------------------------------------------------

; Include ZP definitions of 00-4f, relative to 'zp', and Workspace Variables

    icl 'vars.s'

; ----------------------------------------------------------------------------

; BASIC Token Values

tknAND      = $80
tknDIV      = $81
tknEOR      = $82
tknMOD      = $83
tknOR       = $84
tknERROR    = $85
tknLINE     = $86
tknOFF      = $87
tknSTEP     = $88
tknSPC      = $89
tknTAB      = $8A
tknELSE     = $8B
tknTHEN     = $8C
tknCONST    = $8D
tknOPENIN   = $8E
tknPTR      = $8F
tknPAGE     = $90
tknTIME     = $91
tknLOMEM    = $92
tknHIMEM    = $93
tknABS      = $94
tknACS      = $95
tknADVAL    = $96
tknASC      = $97
tknASN      = $98
tknATN      = $99
tknBGET     = $9A
tknCOS      = $9B
tknCOUNT    = $9C
tknDEG      = $9D
tknERL      = $9E
tknERR      = $9F
tknEVAL     = $A0
tknEXP      = $A1
tknEXT      = $A2
tknFALSE    = $A3
tknFN       = $A4
tknGET      = $A5
tknINKEY    = $A6
tknINSTR    = $A7
tknINT      = $A8
tknLEN      = $A9
tknLN       = $AA
tknLOG      = $AB
tknNOT      = $AC
tknOPENUP   = $AD
tknOPENOUT  = $AE
tknPI       = $AF
tknPOINT    = $B0
tknPOS      = $B1
tknRAD      = $B2
tknRND      = $B3
tknSGN      = $B4
tknSIN      = $B5
tknSQR      = $B6
tknTAN      = $B7
tknTO       = $B8
tknTRUE     = $B9
tknUSR      = $BA
tknVAL      = $BB
tknVPOS     = $BC
tknCHRD     = $BD
tknGETD     = $BE
tknINKEYD   = $BF
tknLEFTD    = $C0
tknMIDD     = $C1
tknRIGHTD   = $C2
tknSTRD     = $C3
tknSTRINGD  = $C4
tknEOF      = $C5
tknAUTO     = $C6   ; first "command" token
tknDELETE   = $C7
tknLOAD     = $C8
tknLIST     = $C9
tknNEW      = $CA
tknOLD      = $CB
tknRENUMBER = $CC
tknSAVE     = $CD
tknPTR2     = $CF   ; tknPTR   + $40, see bit 6 of token table flags
tknPAGE2    = $D0   ; tknPAGE  + $40
tknTIME2    = $D1   ; tknTIME  + $40
tknLOMEM2   = $D2   ; tknLOMEM + $40
tknHIMEM2   = $D3   ; tknHIMEM + $40
tknSOUND    = $D4
tknBPUT     = $D5
tknCALL     = $D6
tknCHAIN    = $D7
tknCLEAR    = $D8
tknCLOSE    = $D9
tknCLG      = $DA
tknCLS      = $DB
tknDATA     = $DC
tknDEF      = $DD
tknDIM      = $DE
tknDRAW     = $DF
tknEND      = $E0
tknENDPROC  = $E1
tknENVELOPE = $E2
tknFOR      = $E3
tknGOSUB    = $E4
tknGOTO     = $E5
tknGCOL     = $E6
tknIF       = $E7
tknINPUT    = $E8
tknLET      = $E9
tknLOCAL    = $EA
tknMODE     = $EB
tknMOVE     = $EC
tknNEXT     = $ED
tknON       = $EE
tknVDU      = $EF
tknPLOT     = $F0
tknPRINT    = $F1
tknPROC     = $F2
tknREAD     = $F3
tknREM      = $F4
tknREPEAT   = $F5
tknREPORT   = $F6
tknRESTORE  = $F7
tknRETURN   = $F8
tknRUN      = $F9
tknSTOP     = $FA
tknCOLOR    = $FB
tknTRACE    = $FC
tknUNTIL    = $FD
tknWIDTH    = $FE
tknOSCLI    = $FF

; ----------------------------------------------------------------------------

    .if .def TARGET_BBC
        org romstart
        icl 'part1.s'
        icl 'part2.s'
        icl 'part3.s'
    .endif

    .if .def TARGET_ATARI
        org $3000
        icl 'part2.s'

        .if .not .def SKIP_INI_LOADER
            ini under_rom_loader
        .endif

        org $c000
        icl 'part1.s'

        org $d800
        icl 'part3.s'
    .endif

; vi:syntax=mads
