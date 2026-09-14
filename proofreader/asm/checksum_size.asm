;==============================================================================
; SIZE-OPTIMIZED 6502 CHECKSUM -- smallest footprint variant
; Same New Proofreader math; prioritizes bytes over cycles
; ~90 bytes core (vs ~120 original magazine image body)
;==============================================================================

CHROUT = $FFD2
BUF = $0200

        * = $C200

SIZE_CHECKSUM:
        LDA $14
        STA $A7
        LDA $15
        STA $A8
        LDY #0
        STY $B0 ; qmode
        STY $B4 ; pos
S_NEXT:
        INC $B4
        LDA BUF,Y
        BEQ S_DONE
        INY
        CMP #34
        BNE S_SP
        LDA $B0
        EOR #$FF
        STA $B0
        LDA #34
S_SP: CMP #32
        BNE S_KEEP
        BIT $B0
        BPL S_NEXT
S_KEEP:
        TAX ; A = char -> X
        LDA $B4 ; pos
        STA $B5
S_MUL: CLC
        LDA $A7
        STX $B6
        ADC $B6 ; +char
        STA $A7
        BCC S_NC
        INC $A8
S_NC: DEC $B5
        BNE S_MUL
        BEQ S_NEXT
S_DONE:
        LDA $A7
        EOR $A8
        PHA
        AND #15
        TAX
        LDA S_LET,X
        JSR CHROUT
        PLA
        LSR A
        LSR A
        LSR A
        LSR A
        TAX
        LDA S_LET,X
        JMP CHROUT
S_LET: .BYTE "ABCDEFGHJKMPQRSX"
