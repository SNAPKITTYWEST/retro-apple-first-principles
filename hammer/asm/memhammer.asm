;==============================================================================
; C64 MEMORY HAMMER -- 6502 RAM stress worker
; Patterns: walking-1, walking-0, 0xAA, 0x55, checkerboard, LFSR stream
; Entry (simple): set $FB/$FC = start, $FD/$FE = end+1, JSR HAMMER
;==============================================================================

CHROUT = $FFD2
BORDER = $D020

        * = $C000

;------------------------------------------------------------------------------
; HAMMER -- full sequence
;------------------------------------------------------------------------------
HAMMER:
        JSR WALK1_WRITE
        JSR WALK1_VERIFY
        BCS FAIL
        JSR FILL_AA
        JSR VERIFY_AA
        BCS FAIL
        JSR FILL_55
        JSR VERIFY_55
        BCS FAIL
        JSR CHECKER_WRITE
        JSR CHECKER_VERIFY
        BCS FAIL
        JSR LFSR_WRITE
        JSR LFSR_VERIFY
        BCS FAIL
        RTS ; success

FAIL:
        LDA #2 ; red border
        STA BORDER
LOCK: JMP LOCK ; hang so user notices

;------------------------------------------------------------------------------
; Walking 1 -- write
;------------------------------------------------------------------------------
WALK1_WRITE:
        LDA #$01
        STA PAT
        LDA $FB
        STA CUR_LO
        LDA $FC
        STA CUR_HI
W1W_ROW:
        LDY #0
W1W_COL:
        LDA PAT
        STA (CUR_LO),Y
        INY
        BNE W1W_COL
        INC CUR_HI
        LDA CUR_HI
        CMP $FE
        BCC W1W_SHIFT
        LDA CUR_LO
        CMP $FD
        BCS W1W_DONE
W1W_SHIFT:
        ASL PAT
        BCC W1W_ROW
        LDA #$01
        STA PAT
        BNE W1W_ROW
W1W_DONE:
        RTS

;------------------------------------------------------------------------------
; Walking 1 -- verify (sets C on error)
;------------------------------------------------------------------------------
WALK1_VERIFY:
        LDA #$01
        STA PAT
        LDA $FB
        STA CUR_LO
        LDA $FC
        STA CUR_HI
W1V_ROW:
        LDY #0
W1V_COL:
        LDA (CUR_LO),Y
        CMP PAT
        BNE VFAIL
        INY
        BNE W1V_COL
        INC CUR_HI
        LDA CUR_HI
        CMP $FE
        BCC W1V_SHIFT
        LDA CUR_LO
        CMP $FD
        BCS W1V_OK
W1V_SHIFT:
        ASL PAT
        BCC W1V_ROW
        LDA #$01
        STA PAT
        BNE W1V_ROW
W1V_OK:
        CLC
        RTS
VFAIL:
        SEC
        RTS

;------------------------------------------------------------------------------
; Fill / verify constants
;------------------------------------------------------------------------------
FILL_AA:
        LDA #$AA
        BNE FILL_COMMON
FILL_55:
        LDA #$55
FILL_COMMON:
        STA PAT
        LDA $FB
        STA CUR_LO
        LDA $FC
        STA CUR_HI
        LDY #0
FC_LP:
        LDA PAT
        STA (CUR_LO),Y
        INY
        BNE FC_LP
        INC CUR_HI
        LDA CUR_HI
        CMP $FE
        BCC FC_LP
        RTS

VERIFY_AA:
        LDA #$AA
        BNE VER_COMMON
VERIFY_55:
        LDA #$55
VER_COMMON:
        STA PAT
        LDA $FB
        STA CUR_LO
        LDA $FC
        STA CUR_HI
        LDY #0
VC_LP:
        LDA (CUR_LO),Y
        CMP PAT
        BNE VFAIL
        INY
        BNE VC_LP
        INC CUR_HI
        LDA CUR_HI
        CMP $FE
        BCC VC_LP
        CLC
        RTS

;------------------------------------------------------------------------------
; Checkerboard $AA / $55 alternating per page
;------------------------------------------------------------------------------
CHECKER_WRITE:
        LDA $FB
        STA CUR_LO
        LDA $FC
        STA CUR_HI
        LDA #$AA
        STA PAT
CHW_LP:
        LDY #0
CHW_COL:
        LDA PAT
        STA (CUR_LO),Y
        INY
        BNE CHW_COL
        LDA PAT
        EOR #$FF
        STA PAT
        INC CUR_HI
        LDA CUR_HI
        CMP $FE
        BCC CHW_LP
        RTS

CHECKER_VERIFY:
        LDA $FB
        STA CUR_LO
        LDA $FC
        STA CUR_HI
        LDA #$AA
        STA PAT
CHV_LP:
        LDY #0
CHV_COL:
        LDA (CUR_LO),Y
        CMP PAT
        BNE VFAIL
        INY
        BNE CHV_COL
        LDA PAT
        EOR #$FF
        STA PAT
        INC CUR_HI
        LDA CUR_HI
        CMP $FE
        BCC CHV_LP
        CLC
        RTS

;------------------------------------------------------------------------------
; 16-bit LFSR stream
;------------------------------------------------------------------------------
LFSR_WRITE:
        LDA #$E1
        STA LFSR_LO
        LDA #$AC
        STA LFSR_HI
        LDA $FB
        STA CUR_LO
        LDA $FC
        STA CUR_HI
        LDY #0
LFW_LP:
        JSR LFSR_STEP
        LDA LFSR_LO
        STA (CUR_LO),Y
        INY
        BNE LFW_LP
        INC CUR_HI
        LDA CUR_HI
        CMP $FE
        BCC LFW_LP
        RTS

LFSR_VERIFY:
        LDA #$E1
        STA LFSR_LO
        LDA #$AC
        STA LFSR_HI
        LDA $FB
        STA CUR_LO
        LDA $FC
        STA CUR_HI
        LDY #0
LFV_LP:
        JSR LFSR_STEP
        LDA (CUR_LO),Y
        CMP LFSR_LO
        BNE VFAIL
        INY
        BNE LFV_LP
        INC CUR_HI
        LDA CUR_HI
        CMP $FE
        BCC LFV_LP
        CLC
        RTS

LFSR_STEP:
        ; 16-bit Galois LFSR
        LDA LFSR_HI
        LSR A
        ROR LFSR_LO
        ROR LFSR_HI
        BCC LFS_OUT
        LDA LFSR_LO
        EOR #$34
        STA LFSR_LO
        LDA LFSR_HI
        EOR #$10
        STA LFSR_HI
LFS_OUT:
        RTS

;------------------------------------------------------------------------------
; ZP temps
;------------------------------------------------------------------------------
PAT = $02
CUR_LO = $03
CUR_HI = $04
LFSR_LO = $05
LFSR_HI = $06
