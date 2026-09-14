# Usage

## Commodore 64 / 128 / VIC-20 / Plus4 (original)

1. Type or load `c64/new_proofreader.bas` carefully.
2. `RUN`
3. Machine is identified; ML is POKEd; "PROOFREADER ACTIVE"
4. Loader erases itself (`NEW`); wedge remains in memory.
5. Type your program lines as usual. After each RETURN, two reverse letters appear at the top of the screen.
6. Match them to the magazine listing (e.g. `EF 10 OPEN2,...`).
7. RUN/STOP-RESTORE disables the wedge.

## SoftBASIC (host / teaching)

```
RUN softbasic/proofreader_engine.bas
```

or the smaller interactive shell:

```
RUN softbasic/proofreader_soft.bas
```

Enter numbered lines; checksums print immediately.
`DEMO` / menu option 5 runs built-in algorithm checks.

## Assembly

`asm/new_proofreader.asm` is a readable reconstruction of the ML image for study.
It is not a drop-in assembler source for every tool chain; offsets match the DATA statements in the BASIC loader.

## Verifying Miami Ice (C128) lines

From Compute! Issue 73, Program 1 lines begin with two-letter codes such as:

```
EF 10 OPEN2,8,2,"HI-SCORE,S,W":...
EM 20 COLOR0,16:COLOR4,11
BR 30 PRINT"{CLR}{RED}{7 DOWN}...
```

Paste a line (without the leading code) into the SoftBASIC engine and confirm the computed code matches.
