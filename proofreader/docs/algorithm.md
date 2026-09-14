# New Automatic Proofreader -- Algorithm

**Origin:** Philip I. Nelson, COMPUTE! / COMPUTE!'s Gazette, February 1986 onward.
**Purpose:** Detect typing errors in BASIC type-in listings by displaying a two-letter checksum after each line is entered.

## Why a new version?

The 1983-1985 Proofreader used a simple sum (mod 256). Swapping two characters often produced the same checksum. The 1986 redesign:

- Uses a **16-bit weighted sum** (character x position)
- **Ignores spaces outside quotes**, counts them inside quotes
- Seeds with the **line number**
- Displays **two letters** (not a decimal 0-255)

## Checksum steps

1. Let `sum` be a 16-bit unsigned integer, initial value = line number.
2. Let `pos = 0`, `quote_mode = false`.
3. For each character `c` in the raw input buffer (before tokenization):
   - `pos <- pos + 1`
   - If `c` is `"` then toggle `quote_mode`
   - If `c` is space and not `quote_mode`, skip
   - Else `sum <- (sum + c * pos) mod 65536`
4. `byte <- (sum & 0xFF) XOR ((sum >> 8) & 0xFF)`
5. Low nibble of `byte` -> letter from `ABCDEFGHJKMPQRSX`
6. High nibble of `byte` -> letter from same table
7. Print the two letters in reverse video at the top of the screen

## Alphabet

```
Nibble: 0 1 2 3 4 5 6 7 8 9 A B C D E F
Letter: A B C D E F G H J K M P Q R S X
```

(Note: I, L, N, O, T, U, V, W, Y, Z are omitted to reduce visual confusion.)

## Machine integration (Commodore)

- Installs by writing the handler address into the **ICRNCH** vector at `$0304/$0305`
- Runs **before** BASIC tokenizes the line (so abbreviations change the checksum -- type keywords in full)
- Lives in memory just above the BASIC program; loader raises the top-of-BASIC pointer and executes `NEW`

## SoftBASIC recreation

`softbasic/proofreader_engine.bas` and `proofreader_soft.bas` implement the identical math with no ML, suitable for:

- Verification of magazine listings on a modern host
- Teaching the algorithm
- Cross-checking OCR of type-in programs (e.g. Miami Ice)

## References

- COMPUTE! Issue 70 (March 1986) -- first magazine appearance of the New Proofreader text
- COMPUTE!'s Gazette, February 1986
- atariarchives / atarimagazines HTML transcriptions
- Community reverse-engineering notes (comp.sys.cbm, Bumbershoot Software)
