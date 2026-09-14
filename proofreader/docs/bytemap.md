# COMPUTE! New Automatic Proofreader -- Byte-Level Map

Source: DATA statements in new_proofreader.bas (lines 160-310)
Length: 167 bytes code image + fixup table

## Code Image

| Offset | Bytes | Meaning |
|--------|-------|---------|
| 0000 | 78 | SEI |
| 0001 | A9 49 | LDA #<handler (lo fixup) |
| 0003 | 8D 04 03 | STA $0304 (ICRNCH lo) |
| 0006 | A9 03 | LDA #>handler (hi fixup) |
| 0008 | 8D 05 03 | STA $0305 |
| 000B | 58 | CLI |
| 000C | 60 | RTS |
| 000D | A5 14 | LDA $14 ; line# lo |
| 000F | 85 A7 | STA chk_lo |
| 0011 | A5 15 | LDA $15 |
| 0013 | 85 A8 | STA chk_hi |
| 0015 | A9 00 | LDA #0 |
| 0017 | 8D 00 FF | STA $FF00 ; pad |
| 001A | A2 1F | LDX #31 |
| 001C | B5 C7 | LDA $C7,X |
| 001E | 9D E3 03 | STA $03E3,X ; save area |
| 0021 | CA | DEX |
| 0022 | 10 F8 | BPL save_lp |
| 0024 | A9 13 | LDA #19 ; HOME |
| 0026 | 20 D2 FF | JSR $FFD2 |
| 0029 | A9 12 | LDA #18 ; RVS ON |
| 002B | 20 D2 FF | JSR $FFD2 |
| 002E | A0 00 | LDY #0 |
| 0030 | 84 B4 | STY pos |
| 0032 | 84 B0 | STY qmode |
| 0034 | 88 | DEY |
| 0035 | E6 B4 | INC pos |
| 0037 | C8 | INY |
| 0038 | B9 00 02 | LDA $0200,Y ; BUF |
| 003B | F0 2E | BEQ done |
| 003D | C9 22 | CMP #34 |
| 003F | D0 08 | BNE not_q |
| 0041 | 48 | PHA |
| 0042 | A5 B0 | LDA qmode |
| 0044 | 49 FF | EOR #$FF |
| 0046 | 85 B0 | STA qmode |
| 0048 | 68 | PLA |
| 0049 | 48 | PHA |
| 004A | C9 20 | CMP #32 |
| 004C | D0 07 | BNE not_sp |
| 004E | A5 B0 | LDA qmode |
| 0050 | D0 03 | BNE not_sp |
| 0052 | 68 | PLA |
| 0053 | D0 E2 | BNE next ; skip space |
| 0055 | 68 | PLA |
| 0056 | A6 B4 | LDX pos |
| 0058 | 18 | CLC |
| 0059 | A5 A7 | LDA chk_lo |
| 005B | 79 00 02 | ADC $0200,Y |
| 005E | 85 A7 | STA chk_lo |
| 0060 | A5 A8 | LDA chk_hi |
| 0062 | 69 00 | ADC #0 |
| 0064 | 85 A8 | STA chk_hi |
| 0066 | CA | DEX |
| 0067 | D0 EF | BNE add_loop |
| 0069 | F0 CA | BEQ next |
| 006B | A5 A7 | LDA chk_lo |
| 006D | 45 A8 | EOR chk_hi |
| 006F | 48 | PHA |
| 0070 | 29 0F | AND #$0F |
| 0072 | A8 | TAY |
| 0073 | B9 D3 03 | LDA letters,Y |
| 0076 | 20 D2 FF | JSR CHROUT |
| 0079 | 68 | PLA |
| 007A | 4A 4A 4A 4A | LSR x4 |
| 007E | A8 | TAY |
| 007F | B9 D3 03 | LDA letters,Y |
| 0082 | 20 D2 FF | JSR CHROUT |
| 0085 | A2 1F | LDX #31 |
| 0087 | BD E3 03 | LDA $03E3,X |
| 008A | 95 C7 | STA $C7,X |
| 008C | CA | DEX |
| 008D | 10 F8 | BPL rest |
| 008F | A9 92 | LDA #146 ; RVS OFF |
| 0091 | 20 D2 FF | JSR CHROUT |
| 0094 | 4C 56 89 | JMP $8956 ; orig ICRNCH (fixup) |
| 0097 | 41..58 | "ABCDEFGHJKMPQRSX" |

## Fixup Table (DATA line 310)

5 triples: `13,2,7  167,31,32  151,116,117  151,128,129  167,136,137`

Each triple: (relative fixup offset, lo-byte offset, hi-byte offset).
The BASIC loader patches absolute addresses inside the image after POKEing.

## Notes

- `$8956` is a placeholder for the original ICRNCH destination on C64.
- VIC/128/Plus4 get different vectors via the loader patches in lines 120-130.
- ZP: `$A7/$A8` = checksum, `$B0` = quote mode, `$B4` = position, `$03E3` = save area.
