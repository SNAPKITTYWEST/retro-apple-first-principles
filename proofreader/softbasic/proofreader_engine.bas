10000 REM ################################################################
10010 REM SOFTBASIC PROOFREADER ENGINE -- expanded educational core
10020 REM ~ pure software reimplementation of COMPUTE! New Proofreader
10030 REM Target: classic BASIC dialects / SoftBASIC / teaching systems
10040 REM ################################################################

10100 REM --- CONFIG ---
10110 LETTERS$ = "ABCDEFGHJKMPQRSX"
10120 MAXLINES = 1000
10130 DIM SRCLINE$(MAXLINES)
10140 DIM CHKCODE$(MAXLINES)
10150 DIM LINENUM(MAXLINES)
10160 NLINES = 0

10200 REM --- MAIN MENU ---
10210 PRINT CHR$(12)
10220 PRINT "================================================"
10230 PRINT " SOFTBASIC AUTOMATIC PROOFREADER ENGINE"
10240 PRINT " COMPUTE! New Proofreader algorithm (1986)"
10250 PRINT " SoftBASIC + educational expansion"
10260 PRINT "================================================"
10270 PRINT
10280 PRINT " 1 Interactive entry"
10290 PRINT " 2 Load ASCII listing"
10300 PRINT " 3 List with checksums"
10310 PRINT " 4 Save magazine-style listing"
10320 PRINT " 5 Self-test / algorithm demo"
10330 PRINT " 6 Compare two lines (diff checksum)"
10340 PRINT " 7 Batch verify against known codes"
10350 PRINT " 8 Show algorithm explanation"
10360 PRINT " 9 Quit"
10370 PRINT
10380 INPUT "Choice"; CH
10390 IF CH = 1 THEN GOSUB 11000: GOTO 10210
10400 IF CH = 2 THEN GOSUB 12000: GOTO 10210
10410 IF CH = 3 THEN GOSUB 13000: GOTO 10210
10420 IF CH = 4 THEN GOSUB 14000: GOTO 10210
10430 IF CH = 5 THEN GOSUB 15000: GOTO 10210
10440 IF CH = 6 THEN GOSUB 16000: GOTO 10210
10450 IF CH = 7 THEN GOSUB 17000: GOTO 10210
10460 IF CH = 8 THEN GOSUB 18000: GOTO 10210
10470 IF CH = 9 THEN END
10480 GOTO 10210

11000 REM ========== INTERACTIVE ENTRY ==========
11010 PRINT "Enter lines (blank line finishes):"
11020 LINE INPUT A$
11030 IF A$ = "" THEN RETURN
11040 GOSUB 20000
11050 IF LN = 0 THEN PRINT " bad line number": GOTO 11020
11060 NLINES = NLINES + 1
11070 IF NLINES > MAXLINES THEN PRINT "full": RETURN
11080 SRCLINE$(NLINES) = A$
11090 LINENUM(NLINES) = LN
11100 CHKCODE$(NLINES) = CODE$
11110 PRINT " "; CODE$
11120 GOTO 11020

12000 REM ========== LOAD ==========
12010 INPUT "File"; F$
12020 IF F$ = "" THEN RETURN
12030 OPEN F$ FOR INPUT AS #1
12040 NLINES = 0
12050 IF EOF(1) THEN 12120
12060 LINE INPUT #1, A$
12070 GOSUB 20000
12080 IF LN = 0 THEN 12050
12090 NLINES = NLINES + 1
12100 SRCLINE$(NLINES) = A$: LINENUM(NLINES) = LN: CHKCODE$(NLINES) = CODE$
12110 GOTO 12050
12120 CLOSE #1
12130 PRINT NLINES; " lines loaded"
12140 RETURN

13000 REM ========== LIST ==========
13010 FOR I = 1 TO NLINES
13020 PRINT CHKCODE$(I); " "; SRCLINE$(I)
13030 NEXT I
13040 RETURN

14000 REM ========== SAVE ==========
14010 INPUT "Output file"; F$
14020 IF F$ = "" THEN RETURN
14030 OPEN F$ FOR OUTPUT AS #1
14040 FOR I = 1 TO NLINES
14050 PRINT #1, CHKCODE$(I); " "; SRCLINE$(I)
14060 NEXT I
14070 CLOSE #1
14080 PRINT "Wrote "; NLINES; " lines"
14090 RETURN

15000 REM ========== SELF-TEST ==========
15010 PRINT "Algorithm self-test"
15020 PRINT "-------------------"
15030 T$ = "10 PRINT ""HELLO"""
15040 GOSUB 21000
15050 PRINT T$; " => "; CODE$
15060 T$ = "10 PRINT ""HELLO "" "
15070 GOSUB 21000
15080 PRINT T$; " => "; CODE$; " (trailing space outside quotes ignored)"
15090 T$ = "10 PRINT ""HELLO """
15100 GOSUB 21000
15110 PRINT T$; " => "; CODE$; " (space inside quotes counts)"
15120 T$ = "10 A=1:B=2"
15130 GOSUB 21000
15140 C1$ = CODE$
15150 T$ = "10 B=1:A=2"
15160 GOSUB 21000
15170 PRINT "Transposition test: "; C1$; " vs "; CODE$;
15180 IF C1$ <> CODE$ THEN PRINT " [PASS - different]" ELSE PRINT " [FAIL]"
15190 T$ = "100 X=0"
15200 GOSUB 21000
15210 PRINT "Line 100: "; CODE$
15220 T$ = "200 X=0"
15230 GOSUB 21000
15240 PRINT "Line 200: "; CODE$; " (line number seeds checksum)"
15250 RETURN

16000 REM ========== COMPARE ==========
16010 LINE INPUT "Line A: "; A$
16020 LINE INPUT "Line B: "; B$
16030 T$ = A$: GOSUB 21000: CA$ = CODE$
16040 T$ = B$: GOSUB 21000: CB$ = CODE$
16050 PRINT "A => "; CA$
16060 PRINT "B => "; CB$
16070 IF CA$ = CB$ THEN PRINT "MATCH" ELSE PRINT "DIFFER"
16080 RETURN

17000 REM ========== BATCH PLACEHOLDER ==========
17010 PRINT "Batch verify: load a magazine listing with leading codes"
17020 PRINT "then compare recomputed codes (feature stub for expansion)"
17030 RETURN

18000 REM ========== EXPLAIN ==========
18010 PRINT
18020 PRINT "HOW THE NEW AUTOMATIC PROOFREADER WORKS"
18030 PRINT "---------------------------------------"
18040 PRINT "1. Wedge into BASIC's line-crunch vector (ICRNCH)."
18050 PRINT "2. Before tokenization, scan the raw input buffer."
18060 PRINT "3. Checksum starts as the 16-bit line number."
18070 PRINT "4. Position counter starts at 1 and increments per char."
18080 PRINT "5. Quote mode toggles on each CHR$(34)."
18090 PRINT "6. Spaces are skipped when quote mode is off."
18100 PRINT "7. For every kept character C at position P:"
18110 PRINT "   sum = sum + (C * P) (16-bit unsigned)"
18120 PRINT "8. Display byte = (sum AND 255) XOR (sum / 256)"
18130 PRINT "9. Low nibble and high nibble index into:"
18140 PRINT "   ABCDEFGHJKMPQRSX"
18150 PRINT "10. Two letters appear in reverse at top of screen."
18160 PRINT
18170 PRINT "This catches almost all single-key and transposition errors."
18180 PRINT "Original author: Philip I. Nelson, COMPUTE! 1986."
18190 PRINT
18200 RETURN

20000 REM ========== PARSE LINE NUMBER FROM A$ ==========
20010 LN = 0: P = 1
20020 IF P > LEN(A$) THEN CODE$ = "??": RETURN
20030 C$ = MID$(A$, P, 1)
20040 IF C$ < "0" OR C$ > "9" THEN 20080
20050 LN = LN * 10 + VAL(C$)
20060 P = P + 1
20070 GOTO 20020
20080 T$ = A$
20090 GOSUB 21000
20100 RETURN

21000 REM ========== COMPUTE CODE$ FROM T$ AND LN ==========
21010 REM If LN not set, extract from T$
21020 IF LN = 0 THEN GOSUB 22000
21030 SUM = LN
21040 IF SUM < 0 THEN SUM = SUM + 65536
21050 QMODE = 0
21060 POSN = 0
21070 FOR I = 1 TO LEN(T$)
21080 C$ = MID$(T$, I, 1)
21090 C = ASC(C$)
21100 POSN = POSN + 1
21110 IF C = 34 THEN QMODE = 1 - QMODE
21120 IF C = 32 AND QMODE = 0 THEN GOTO 21160
21130 ADD = C * POSN
21140 SUM = SUM + ADD
21150 IF SUM >= 65536 THEN SUM = SUM - 65536 * INT(SUM / 65536)
21160 NEXT I
21170 LO = SUM - 256 * INT(SUM / 256)
21180 HI = INT(SUM / 256)
21190 HI = HI - 256 * INT(HI / 256)
21200 B = LO XOR HI
21210 IF B < 0 THEN B = B + 256
21220 N1 = B - 16 * INT(B / 16)
21230 N2 = INT(B / 16)
21240 CODE$ = MID$(LETTERS$, N1 + 1, 1) + MID$(LETTERS$, N2 + 1, 1)
21250 RETURN

22000 REM extract LN from T$
22010 LN = 0: P = 1
22020 IF P > LEN(T$) THEN RETURN
22030 C$ = MID$(T$, P, 1)
22040 IF C$ < "0" OR C$ > "9" THEN RETURN
22050 LN = LN * 10 + VAL(C$)
22060 P = P + 1
22070 GOTO 22020
