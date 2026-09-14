;==============================================================================
; COMPUTE! NEW AUTOMATIC PROOFREADER (Philip I. Nelson, 1986)
; 6502 assembly reconstruction -- ICRNCH vector wedge
; Checksum: 16-bit weighted sum, spaces ignored outside quotes,
; final display = two letters from (HI EOR LO) nibbles
;==============================================================================

; Zero-page / system
LINNUM_LO = $14 ; current BASIC line number (lo)
LINNUM_HI = $15
BUF = $0200 ; BASIC input buffer
ICRNCH = $0304 ; vector: tokenize / crunch line
CHROUT = $FFD2

; Relocatable workspace (installed just above BASIC program)
; SA = (TXTTAB)+6 after loader runs

        * = $0000 ; relative offsets from SA

;------------------------------------------------------------------------------
; INSTALL: wedge ICRNCH
;------------------------------------------------------------------------------
INSTALL:
        SEI
        LDA #<HANDLER
        STA ICRNCH
        LDA #>HANDLER
        STA ICRNCH+1
        CLI
        RTS

;------------------------------------------------------------------------------
; HANDLER -- called before BASIC crunches the line
;------------------------------------------------------------------------------
HANDLER:
        LDA LINNUM_LO
        STA CHK_LO ; seed checksum with line number
        LDA LINNUM_HI
        STA CHK_HI

        LDA #0
        STA $FF00 ; (platform pad / unused)

        ; save $C7-$E6 (screen line link / color temp) -- 32 bytes
        LDX #31
SAVE_LP:
        LDA $C7,X
        STA SAVE_AREA,X
        DEX
        BPL SAVE_LP

        ; home cursor + reverse on
        LDA #19 ; CHR$(19) HOME
        JSR CHROUT
        LDA #18 ; CHR$(18) RVS ON
        JSR CHROUT

        LDY #0
        STY POS ; position counter (1-based after first INC)
        STY QMODE ; quote-mode flag = 0

        DEY ; Y = $FF
NEXT_CHAR:
        INC POS
        INY
        LDA BUF,Y
        BEQ DONE_LINE ; end of buffer (0)

        CMP #34 ; quote?
        BNE NOT_QUOTE
        PHA
        LDA QMODE
        EOR #$FF ; toggle quote mode
        STA QMODE
        PLA
NOT_QUOTE:
        PHA
        CMP #32 ; space?
        BNE NOT_SPACE
        LDA QMODE
        BNE NOT_SPACE ; count space only inside quotes
        PLA
        BNE NEXT_CHAR ; skip space
NOT_SPACE:
        PLA
        ; add (char * POS) to 16-bit checksum via repeated addition
        LDX POS
ADD_LOOP:
        CLC
        LDA CHK_LO
        ADC BUF,Y ; note: uses original char still in BUF,Y
        STA CHK_LO
        LDA CHK_HI
        ADC #0
        STA CHK_HI
        DEX
        BNE ADD_LOOP
        BEQ NEXT_CHAR

DONE_LINE:
        ; final byte = CHK_LO EOR CHK_HI
        LDA CHK_LO
        EOR CHK_HI
        PHA
        AND #$0F
        TAY
        LDA LETTERS,Y
        JSR CHROUT ; low nibble letter
        PLA
        LSR A
        LSR A
        LSR A
        LSR A
        TAY
        LDA LETTERS,Y
        JSR CHROUT ; high nibble letter

        ; restore saved ZP
        LDX #31
REST_LP:
        LDA SAVE_AREA,X
        STA $C7,X
        DEX
        BPL REST_LP

        LDA #146 ; RVS OFF
        JSR CHROUT
        JMP $8956 ; continue into original ICRNCH (relocated)

;------------------------------------------------------------------------------
; Tables
;------------------------------------------------------------------------------
LETTERS:
        .BYTE "ABCDEFGHJKMPQRSX" ; 16 glyphs for nibble 0-15

CHK_LO = $A7
CHK_HI = $A8
POS = $B4
QMODE = $B0
SAVE_AREA = $03E3 ; 32 bytes

;------------------------------------------------------------------------------
; END OF MACHINE CODE IMAGE (~167 bytes)
;------------------------------------------------------------------------------
