1000 REM ============================================================
1010 REM SOFTBASIC AUTOMATIC PROOFREADER (pure software)
1020 REM Recreates COMPUTE! New Automatic Proofreader checksum
1030 REM Philip I. Nelson algorithm, 1986
1040 REM No machine language -- runs on any classic BASIC
1050 REM Compatible with: QBASIC, GW-BASIC, FreeBASIC, CBASIC-ish
1060 REM ============================================================
1070 REM
1080 REM Algorithm:
1090 REM 1. Seed 16-bit checksum with the line number
1100 REM 2. Walk each character of the source line
1110 REM 3. Toggle quote-mode on each "
1120 REM 4. Ignore spaces unless inside quotes
1130 REM 5. For each kept char, add (PETSCII * position) to sum
1140 REM 6. Final display byte = (sum_lo XOR sum_hi)
1150 REM 7. Map each nibble to letter from "ABCDEFGHJKMPQRSX"
1160 REM
1170 REM ============================================================

1200 DEFINT A-Z
1210 LETTERS$ = "ABCDEFGHJKMPQRSX"
1220 DIM LINE$(500), CK$(500)

1300 PRINT "SOFTBASIC AUTOMATIC PROOFREADER"
1310 PRINT "-------------------------------"
1320 PRINT "Enter BASIC lines (or LOAD from file)."
1330 PRINT "Empty line ends input. Commands:"
1340 PRINT " LIST - show lines + checksums"
1350 PRINT " CHECK - recompute all"
1360 PRINT " SAVE - write listing with checksums"
1370 PRINT " QUIT - exit"
1380 PRINT

1400 N = 0
1410 PRINT "READY."
1420 LINE INPUT "> "; A$
1430 IF A$ = "" THEN 1600
1440 U$ = UCASE$(LEFT$(A$,4))
1450 IF U$ = "QUIT" OR U$ = "EXIT" THEN END
1460 IF U$ = "LIST" THEN GOSUB 3000: GOTO 1410
1470 IF U$ = "CHEC" THEN GOSUB 2000: GOTO 1410
1480 IF U$ = "SAVE" THEN GOSUB 4000: GOTO 1410
1490 IF U$ = "HELP" THEN GOSUB 5000: GOTO 1410
1500 IF U$ = "DEMO" THEN GOSUB 6000: GOTO 1410
1510 IF U$ = "LOAD" THEN GOSUB 7000: GOTO 1410

1520 REM --- parse line number ---
1530 LN = 0: P = 1
1540 WHILE P <= LEN(A$) AND MID$(A$,P,1) >= "0" AND MID$(A$,P,1) <= "9"
1550 LN = LN * 10 + VAL(MID$(A$,P,1))
1560 P = P + 1
1570 WEND
1580 IF LN = 0 THEN PRINT " ? missing line number": GOTO 1410
1590 N = N + 1
1600 LINE$(N) = A$
1610 CK$(N) = FNCHECK$(A$, LN)
1620 PRINT " "; CK$(N)
1630 GOTO 1410

2000 REM ========== RECOMPUTE ALL CHECKSUMS ==========
2010 PRINT "Recomputing..."
2020 FOR I = 1 TO N
2030 A$ = LINE$(I)
2040 LN = 0: P = 1
2050 WHILE P <= LEN(A$) AND MID$(A$,P,1) >= "0" AND MID$(A$,P,1) <= "9"
2060 LN = LN * 10 + VAL(MID$(A$,P,1))
2070 P = P + 1
2080 WEND
2090 CK$(I) = FNCHECK$(A$, LN)
2100 NEXT I
2110 PRINT "Done. "; N; " lines."
2120 RETURN

3000 REM ========== LIST ==========
3010 FOR I = 1 TO N
3020 PRINT CK$(I); " "; LINE$(I)
3030 NEXT I
3040 RETURN

4000 REM ========== SAVE ==========
4010 INPUT "Filename"; F$
4020 IF F$ = "" THEN RETURN
4030 OPEN F$ FOR OUTPUT AS #1
4040 FOR I = 1 TO N
4050 PRINT #1, CK$(I); " "; LINE$(I)
4060 NEXT I
4070 CLOSE #1
4080 PRINT "Saved "; N; " lines to "; F$
4090 RETURN

5000 REM ========== HELP ==========
5010 PRINT
5020 PRINT "SOFTBASIC PROOFREADER HELP"
5030 PRINT " Type numbered BASIC lines; checksum prints after each."
5040 PRINT " Spaces outside quotes are ignored (magazine style)."
5050 PRINT " Spaces inside quotes count."
5060 PRINT " Transpositions change the checksum (weighted by position)."
5070 PRINT " Two-letter code uses alphabet: ABCDEFGHJKMPQRSX"
5080 PRINT " (matches COMPUTE! New Automatic Proofreader 1986+)"
5090 PRINT
5100 RETURN

6000 REM ========== DEMO ==========
6010 PRINT "Demo lines (from classic examples):"
6020 D1$ = "10 A=1:B=72:PRINT""SCORE="";SC"
6030 D2$ = "20 FOR I=1 TO 10:PRINT I:NEXT"
6040 D3$ = "30 IF X=0 THEN PRINT ""HELLO WORLD"""
6050 PRINT D1$; " -> "; FNCHECK$(D1$, 10)
6060 PRINT D2$; " -> "; FNCHECK$(D2$, 20)
6070 PRINT D3$; " -> "; FNCHECK$(D3$, 30)
6080 RETURN

7000 REM ========== LOAD FILE ==========
7010 INPUT "Filename to load"; F$
7020 IF F$ = "" THEN RETURN
7030 OPEN F$ FOR INPUT AS #1
7040 N = 0
7050 WHILE NOT EOF(1)
7060 LINE INPUT #1, A$
7070 IF A$ = "" THEN GOTO 7120
7080 LN = 0: P = 1
7090 WHILE P <= LEN(A$) AND MID$(A$,P,1) >= "0" AND MID$(A$,P,1) <= "9"
7100 LN = LN * 10 + VAL(MID$(A$,P,1)): P = P + 1
7110 WEND
7120 IF LN = 0 THEN GOTO 7150
7130 N = N + 1: LINE$(N) = A$: CK$(N) = FNCHECK$(A$, LN)
7140 PRINT CK$(N); " "; LEFT$(A$,60)
7150 WEND
7160 CLOSE #1
7170 PRINT "Loaded "; N; " lines."
7180 RETURN

8000 REM ============================================================
8010 REM CORE CHECKSUM FUNCTION FNCHECK$(line$, linenum)
8020 REM Returns two-letter string
8030 REM ============================================================
8040 DEF FNCHECK$(L$, LN)
8050 REM seed with line number (16-bit)
8060 SUM = LN
8070 IF SUM < 0 THEN SUM = SUM + 65536
8080 QMODE = 0
8090 POSN = 0
8100 FOR I = 1 TO LEN(L$)
8110 C$ = MID$(L$, I, 1)
8120 C = ASC(C$)
8130 POSN = POSN + 1
8140 IF C$ = CHR$(34) THEN QMODE = 1 - QMODE
8150 IF C$ = " " AND QMODE = 0 THEN GOTO 8200
8160 REM add C * POSN to SUM (mod 65536)
8170 ADD = C * POSN
8180 SUM = SUM + ADD
8190 WHILE SUM >= 65536: SUM = SUM - 65536: WEND
8200 NEXT I
8210 REM final byte = lo XOR hi
8220 LO = SUM AND 255
8230 HI = INT(SUM / 256) AND 255
8240 B = LO XOR HI
8250 N1 = B AND 15
8260 N2 = INT(B / 16) AND 15
8270 FNCHECK$ = MID$(LETTERS$, N1 + 1, 1) + MID$(LETTERS$, N2 + 1, 1)
8280 END DEF
