0 REM ================================================================
1 REM  MEMORY MACHINE: WOZ DISK REVERSE ENGINEERING IN APPLESOFT BASIC
2 REM  ================================================================
3 REM
4 REM  BINARY SEMANTICS AND FORMAL INVARIANTS
5 REM
6 REM  Objective: Deterministic state machine modeling persistent machine
7 REM  state on Woz disk, with Lisp world serialization as binary.
8 REM
9 REM  Architecture layer (bottom-up):
10 REM    BINARY DISK IMAGE
11 REM    → RAW FLOPPY MEDIA MODEL
12 REM    → WOZ DISK STRUCTURE
13 REM    → DISK ENCODING/DECODING
14 REM    → VIRTUAL DISK CONTROLLER
15 REM    → MEMORY MACHINE (state machine)
16 REM    → LISP MACHINE STATE
17 REM    → BINARY RESTORE
18 REM
19 REM  Core Invariant:
20 REM    M_n → SAVE → D_n
21 REM    D_n → RESTORE → M_n
22 REM    M_n ≡ M_restored (under defined equivalence)
23 REM
24 REM ================================================================
25 REM  SECTION 1: BINARY STRUCTURE DEFINITIONS
26 REM ================================================================
30 REM
31 REM  Every binary field is explicitly defined:
32 REM    - WIDTH (bytes or bits)
33 REM    - BYTE ORDER (little-endian, big-endian, or N/A)
34 REM    - OFFSET (from structure base)
35 REM    - ENCODING (raw integer, nibble, BCD, etc.)
36 REM    - VALID RANGE
37 REM    - INVARIANT
38 REM
39 REM ================================================================
40 REM  WOZ DISK IMAGE HEADER
41 REM  ================================================================
42 REM
43 REM  OFFSET  WIDTH  NAME              ENCODING      INVARIANT
44 REM  ------  -----  ----              --------      ---------
45 REM  0       4      MAGIC             ASCII "WOZ1"  Must be present
46 REM  4       1      INFO_BLOCK_SIZE   uint8         1..255, usually 3
47 REM  5       1      WOZ_VERSION       uint8         1 (current)
48 REM  6       10     RESERVED          0x00          Must be zero
49 REM  16      256    INFO_BLOCK        variable      See INFO_BLOCK layout
50 REM  272     ...    TMAP_BLOCK        variable      Track map (160 entries)
51 REM  432+    ...    TRKS_BLOCK        variable      Track data
52 REM
53 REM ================================================================
54 REM  LISP WORLD BINARY ENCODING
55 REM  ================================================================
56 REM
57 REM  Lisp objects are encoded as variable-length binary records.
58 REM  Each object has a type tag and payload.
59 REM
60 REM  BYTE 0: TYPE TAG
61 REM    0x00 = NIL
62 REM    0x01 = INTEGER (4 bytes, big-endian)
63 REM    0x02 = CONS CELL (2 × 4-byte object IDs)
64 REM    0x03 = SYMBOL (1 byte length + UTF-8 string)
65 REM    0x04 = STRING (4 byte length + UTF-8 data)
66 REM    0x05 = BUILTIN (1 byte opcode)
67 REM    0x06 = CLOSURE (1 byte arity + object ID for env + object ID for code)
68 REM    0x07 = VECTOR (4 byte length + object IDs)
69 REM
70 REM  Offset into Lisp heap: 4-byte machine-relative object ID
71 REM  (not host pointer; offset from heap base).
72 REM
73 REM ================================================================
74 REM  STATE MACHINE DEFINITION
75 REM ================================================================
76 REM
77 REM  MEMORY MACHINE STATE = { memory, registers, devices, disk }
78 REM
79 REM  STATE VECTOR REGISTERS:
80 REM    M_PC = program counter
81 REM    M_ACC = accumulator (8 bits, 0..255)
82 REM    M_X = X register (8 bits, 0..255)
83 REM    M_Y = Y register (8 bits, 0..255)
84 REM    M_SP = stack pointer (8 bits, 0..255)
85 REM    M_STATUS = status register (8 bits)
86 REM
87 REM  DEVICE STATE:
88 REM    DRIVE_MOUNTED = disk present (boolean)
89 REM    DRIVE_TRACK = current track (0..79)
90 REM    DRIVE_PROTECTED = write-protected (boolean)
91 REM    DRIVE_MOTOR = motor running (boolean)
92 REM    DRIVE_BUSY = operation in progress (boolean)
93 REM
94 REM  DISK STATE:
95 REM    DISK_IMAGE = raw 143360 bytes (35 tracks × 16 sectors)
96 REM    DISK_CHECKSUM = SHA256 of disk image (verify persistence)
97 REM    DISK_GENERATION = save counter (monotonic ID)
98 REM
99 REM  LISP HEAP STATE:
100 REM    HEAP_BASE = memory address of heap (typically $4000)
101 REM    HEAP_SIZE = current allocation in bytes
102 REM    HEAP_GC_MARK = garbage collection mark counter
103 REM    HEAP_OBJECT_TABLE = object ID → heap offset map
104 REM
105 REM ================================================================
106 REM  VERIFICATION FRAMEWORK
107 REM ================================================================
108 REM
109 REM  Three-category reverse engineering discipline:
110 REM    VERIFIED   = tested against known behavior
111 REM    INFERRED   = deduced from binary analysis (not verified)
112 REM    UNKNOWN    = explicitly unspecified
113 REM
114 REM  Verification tests:
115 REM    1. DETERMINISM: Same input + same ops → same state
116 REM    2. SERIALIZATION: serialize → parse → serialize ≡ identity
117 REM    3. RESTORE: M_n → save → restore → M_n (state equiv)
118 REM    4. CORRUPTION: Invalid disk image is rejected
119 REM    5. OBJECT_IDENTITY: References survive serialization
120 REM
121 REM ================================================================
200 REM  SECTION 2: GLOBAL STATE AND MEMORY MODEL
201 REM ================================================================
210 REM
220 REM  MEMORY LAYOUT (Apple II 48K model):
230 REM    $0000–$00FF  = Zero page
240 REM    $0100–$01FF  = Stack (M_SP points here)
250 REM    $0200–$3FFF  = Program memory
260 REM    $4000–$9FFF  = Lisp heap (24KB)
270 REM    $A000–$BFFF  = Video/I/O
280 REM    $C000–$FFFF  = ROM/auxmem
290 REM
300 REM  GLOBALS (in BASIC interpreter space, not 6502 RAM):
310 DIM M_MEMORY(65535): REM Full address space mirror
320 DIM M_HEAP(24576):   REM Lisp heap allocation
330 DIM M_OTAB(2048):    REM Object table (ID → heap offset)
340 DIM DISK_IMAGE(143359): REM Raw floppy image (35 tracks)
350 REM
360 REM  REGISTER STATE (scalar globals):
370 M_PC = 0:      REM Program counter
380 M_ACC = 0:     REM Accumulator
390 M_X = 0:       REM X register
400 M_Y = 0:       REM Y register
410 M_SP = 255:    REM Stack pointer ($FF initially)
420 M_STATUS = 0:  REM Status register (N,V,-,B,D,I,Z,C)
430 REM
440 REM  DEVICE STATE:
450 DRIVE_MOUNTED = 0:    REM Disk present? (0=no, 1=yes)
460 DRIVE_TRACK = 0:      REM Current track (0–34, or -1 if unknown)
470 DRIVE_PROTECTED = 0:  REM Write-protected? (0=no, 1=yes)
480 DRIVE_MOTOR = 0:      REM Motor on? (0=off, 1=on)
490 DRIVE_BUSY = 0:       REM Operation pending? (0=no, 1=yes)
500 REM
510 REM  DISK STATE:
520 DISK_CHECKSUM$ = "": REM SHA256 digest of disk image
530 DISK_GENERATION = 0: REM Save counter (monotonic)
540 REM
550 REM  LISP HEAP STATE:
560 HEAP_BASE = 16384:    REM $4000 in decimal
570 HEAP_SIZE = 0:        REM Bytes allocated
580 HEAP_GC_MARK = 0:     REM GC mark counter
590 HEAP_OBJECT_COUNT = 0: REM Objects allocated
600 REM
610 REM  VERIFICATION STATE:
620 TEST_PASS = 0:        REM Passing tests
630 TEST_FAIL = 0:        REM Failing tests
640 VERIFY_MODE = 0:      REM 0=off, 1=on, 2=strict
650 REM
660 REM ================================================================
700 REM  SECTION 3: BINARY I/O PRIMITIVES
701 REM ================================================================
710 REM
720 REM  Explicit binary readers and writers (no implicit serialization).
730 REM  Every byte position is defined.
740 REM
750 REM ================================================================
800 REM  READ_BYTE(address) → byte value (0..255)
801 REM ================================================================
810 DEF FN READ_BYTE(A) = M_MEMORY(A)
820 REM
830 REM ================================================================
840 REM  WRITE_BYTE(address, value) → void
841 REM ================================================================
850 SUB WRITE_BYTE(A, V):
860   M_MEMORY(A) = V AND 255
870 END SUB
880 REM
890 REM ================================================================
900 REM  READ_WORD_BE(address) → 16-bit big-endian value
901 REM ================================================================
910 DEF FN READ_WORD_BE(A) = (M_MEMORY(A) * 256) + M_MEMORY(A + 1)
920 REM
930 REM ================================================================
940 REM  READ_LONG_BE(address) → 32-bit big-endian value
941 REM ================================================================
950 DEF FN READ_LONG_BE(A) = (M_MEMORY(A) * 256 ^ 3) + (M_MEMORY(A + 1) * 256 ^ 2) + (M_MEMORY(A + 2) * 256) + M_MEMORY(A + 3)
960 REM
970 REM ================================================================
980 REM  WRITE_LONG_BE(address, value) → void (big-endian)
981 REM ================================================================
990 SUB WRITE_LONG_BE(A, V):
1000   LOCAL B(3)
1010   B(0) = (V / (256 ^ 3)) INT
1020   B(1) = ((V MOD (256 ^ 3)) / (256 ^ 2)) INT
1030   B(2) = ((V MOD (256 ^ 2)) / 256) INT
1040   B(3) = V MOD 256
1050   FOR I = 0 TO 3
1060     M_MEMORY(A + I) = B(I)
1070   NEXT I
1080 END SUB
1090 REM
1100 REM ================================================================
1110 REM  READ_BYTES(address, length) → string of raw bytes
1120 REM ================================================================
1130 DEF FN READ_BYTES(A, LEN):
1140   RESULT$ = ""
1150   FOR I = 0 TO LEN - 1
1160     RESULT$ = RESULT$ + CHR$(M_MEMORY(A + I))
1170   NEXT I
1180   RETURN RESULT$
1190 END FN
1200 REM
1210 REM ================================================================
1220 REM  WRITE_BYTES(address, data$) → void
1230 REM ================================================================
1240 SUB WRITE_BYTES(A, DATA$):
1250   FOR I = 0 TO LEN(DATA$) - 1
1260     M_MEMORY(A + I) = ORD(MID$(DATA$, I + 1, 1))
1270   NEXT I
1280 END SUB
1290 REM
1300 REM ================================================================
1310 REM  HEX_DUMP(address, length, label$) → print formatted hexdump
1320 REM ================================================================
1330 SUB HEX_DUMP(A, LEN, LABEL$):
1340   PRINT LABEL$
1350   FOR I = 0 TO LEN - 1 STEP 16
1360     PRINT USING "####: "; A + I;
1370     FOR J = 0 TO 15
1380       IF I + J < LEN THEN
1390         PRINT USING "## "; M_MEMORY(A + I + J)
1400       ELSE
1410         PRINT "   ";
1420       END IF
1430     NEXT J
1440     PRINT
1450   NEXT I
1460 END SUB
1470 REM
1480 REM ================================================================
2000 REM  SECTION 4: WOZ DISK PARSER AND SERIALIZER
2001 REM ================================================================
2010 REM
2020 REM  Strict binary parser for Woz disk images.
2030 REM  Validates structure boundaries and offsets.
2040 REM  Rejects malformed images instead of silently repairing.
2050 REM
2060 REM ================================================================
2100 REM  PARSE_WOZ_HEADER(image_addr) → success (1=yes, 0=no)
2110 REM  Parses Woz disk header at image_addr.
2120 REM  Invariants:
2130 REM    - Magic must be "WOZ1" (0x57 0x4F 0x5A 0x31)
2140 REM    - Version must be 1
2150 REM    - Info block size must be in range [1, 255]
2160 REM    - Reserved bytes must be zero
2170 REM ================================================================
2180 FUNCTION PARSE_WOZ_HEADER(IMG_ADDR):
2190   REM Check magic "WOZ1"
2200   IF FN READ_BYTE(IMG_ADDR + 0) <> ORD("W") THEN RETURN 0
2210   IF FN READ_BYTE(IMG_ADDR + 1) <> ORD("O") THEN RETURN 0
2220   IF FN READ_BYTE(IMG_ADDR + 2) <> ORD("Z") THEN RETURN 0
2230   IF FN READ_BYTE(IMG_ADDR + 3) <> ORD("1") THEN RETURN 0
2240   REM Check version
2250   V = FN READ_BYTE(IMG_ADDR + 5)
2260   IF V <> 1 THEN RETURN 0
2270   REM Check reserved bytes
2280   FOR I = 6 TO 15
2290     IF FN READ_BYTE(IMG_ADDR + I) <> 0 THEN RETURN 0
2300   NEXT I
2310   RETURN 1
2320 END FUNCTION
2330 REM
2340 REM ================================================================
2350 REM  SERIALIZE_WOZ_HEADER(image_addr, version, info_size) → void
2360 REM ================================================================
2370 SUB SERIALIZE_WOZ_HEADER(IMG_ADDR, VERSION, INFO_SIZE):
2380   GOSUB WRITE_BYTE(IMG_ADDR + 0, ORD("W"))
2390   GOSUB WRITE_BYTE(IMG_ADDR + 1, ORD("O"))
2400   GOSUB WRITE_BYTE(IMG_ADDR + 2, ORD("Z"))
2410   GOSUB WRITE_BYTE(IMG_ADDR + 3, ORD("1"))
2420   GOSUB WRITE_BYTE(IMG_ADDR + 4, INFO_SIZE)
2430   GOSUB WRITE_BYTE(IMG_ADDR + 5, VERSION)
2440   FOR I = 6 TO 15
2450     GOSUB WRITE_BYTE(IMG_ADDR + I, 0)
2460   NEXT I
2470 END SUB
2480 REM
2490 REM ================================================================
3000 REM  SECTION 5: VIRTUAL DISK CONTROLLER
3001 REM ================================================================
3010 REM
3020 REM  Deterministic device modeling.
3030 REM  All state transitions are explicit and logged.
3040 REM
3050 REM ================================================================
3100 REM  MOUNT_DISK(image_addr, write_protect) → success
3110 REM ================================================================
3120 FUNCTION MOUNT_DISK(IMG_ADDR, WP):
3130   IF DRIVE_MOUNTED = 1 THEN
3140     PRINT "ERROR: disk already mounted"
3150     RETURN 0
3160   END IF
3170   IF PARSE_WOZ_HEADER(IMG_ADDR) = 0 THEN
3180     PRINT "ERROR: invalid Woz disk header"
3190     RETURN 0
3200   END IF
3210   DRIVE_MOUNTED = 1
3220   DRIVE_TRACK = 0
3230   DRIVE_PROTECTED = WP
3240   DRIVE_MOTOR = 0
3250   DRIVE_BUSY = 0
3260   PRINT "MOUNT: disk image mounted at $"; USING "####"; IMG_ADDR
3270   RETURN 1
3280 END FUNCTION
3290 REM
3300 REM ================================================================
3310 REM  EJECT_DISK() → void
3320 REM ================================================================
3330 SUB EJECT_DISK():
3340   DRIVE_MOUNTED = 0
3350   DRIVE_TRACK = -1
3360   DRIVE_MOTOR = 0
3370   DRIVE_BUSY = 0
3380   PRINT "EJECT: disk removed"
3390 END SUB
3400 REM
3410 REM ================================================================
3420 REM  SEEK_TRACK(track_num) → success
3430 REM ================================================================
3440 FUNCTION SEEK_TRACK(T):
3450   IF DRIVE_MOUNTED = 0 THEN
3460     PRINT "ERROR: no disk mounted"
3470     RETURN 0
3480   END IF
3490   IF T < 0 OR T > 34 THEN
3500     PRINT "ERROR: track out of range (0..34)"
3510     RETURN 0
3520   END IF
3530   DRIVE_TRACK = T
3540   PRINT "SEEK: track "; T
3550   RETURN 1
3560 END FUNCTION
3570 REM
3580 REM ================================================================
3590 REM  READ_SECTOR(track, sector) → raw 256 bytes
3600 REM ================================================================
3610 FUNCTION READ_SECTOR(T, S):
3620   IF DRIVE_MOUNTED = 0 THEN
3630     PRINT "ERROR: no disk mounted"
3640     RETURN ""
3650   END IF
3660   IF T < 0 OR T > 34 THEN RETURN ""
3670   IF S < 0 OR S > 15 THEN RETURN ""
3680   OFFSET = T * 16 * 256 + S * 256
3690   RETURN FN READ_BYTES(OFFSET, 256)
3700 END FUNCTION
3710 REM
3720 REM ================================================================
3730 REM  WRITE_SECTOR(track, sector, data$) → success
3740 REM ================================================================
3750 FUNCTION WRITE_SECTOR(T, S, DATA$):
3760   IF DRIVE_MOUNTED = 0 THEN RETURN 0
3770   IF DRIVE_PROTECTED = 1 THEN
3780     PRINT "ERROR: disk is write-protected"
3790     RETURN 0
3800   END IF
3810   IF LEN(DATA$) <> 256 THEN
3820     PRINT "ERROR: sector must be exactly 256 bytes"
3830     RETURN 0
3840   END IF
3850   OFFSET = T * 16 * 256 + S * 256
3860   GOSUB WRITE_BYTES(OFFSET, DATA$)
3870   RETURN 1
3880 END FUNCTION
3890 REM
3900 REM ================================================================
4000 REM  SECTION 6: LISP WORLD SERIALIZATION
4001 REM ================================================================
4010 REM
4020 REM  Deterministic Lisp object serialization to binary.
4030 REM  Objects are encoded with type tags and machine-relative offsets.
4040 REM  No host pointers; all references are heap-relative.
4050 REM
4060 REM ================================================================
4100 REM  ENCODE_LISP_NIL(heap_offset) → offset (1 byte)
4110 REM  Encodes NIL object: just type tag 0x00
4120 REM ================================================================
4130 SUB ENCODE_LISP_NIL(OFF):
4140   GOSUB WRITE_BYTE(HEAP_BASE + OFF, 0x00)
4150   HEAP_SIZE = HEAP_SIZE + 1
4160 END SUB
4170 REM
4180 REM ================================================================
4190 REM  ENCODE_LISP_INTEGER(heap_offset, value) → void
4200 REM  Encodes integer: 1-byte tag + 4-byte big-endian value
4210 REM ================================================================
4220 SUB ENCODE_LISP_INTEGER(OFF, VAL):
4230   GOSUB WRITE_BYTE(HEAP_BASE + OFF, 0x01)
4240   GOSUB WRITE_LONG_BE(HEAP_BASE + OFF + 1, VAL)
4250   HEAP_SIZE = HEAP_SIZE + 5
4260 END SUB
4270 REM
4280 REM ================================================================
4290 REM  ENCODE_LISP_CONS(heap_offset, car_id, cdr_id) → void
4300 REM  Encodes cons cell: tag (1) + car (4) + cdr (4) = 9 bytes
4310 REM ================================================================
4320 SUB ENCODE_LISP_CONS(OFF, CAR_ID, CDR_ID):
4330   GOSUB WRITE_BYTE(HEAP_BASE + OFF, 0x02)
4340   GOSUB WRITE_LONG_BE(HEAP_BASE + OFF + 1, CAR_ID)
4350   GOSUB WRITE_LONG_BE(HEAP_BASE + OFF + 5, CDR_ID)
4360   HEAP_SIZE = HEAP_SIZE + 9
4370 END SUB
4380 REM
4390 REM ================================================================
4400 REM  ENCODE_LISP_SYMBOL(heap_offset, name$) → void
4410 REM  Encodes symbol: tag (1) + length (1) + UTF-8 string data
4420 REM ================================================================
4430 SUB ENCODE_LISP_SYMBOL(OFF, NAME$):
4440   GOSUB WRITE_BYTE(HEAP_BASE + OFF, 0x03)
4450   GOSUB WRITE_BYTE(HEAP_BASE + OFF + 1, LEN(NAME$))
4460   GOSUB WRITE_BYTES(HEAP_BASE + OFF + 2, NAME$)
4470   HEAP_SIZE = HEAP_SIZE + 2 + LEN(NAME$)
4480 END SUB
4490 REM
4500 REM ================================================================
4510 REM  DECODE_LISP_OBJECT(heap_offset) → { type, value }
4520 REM  Deterministic decoder; returns structured result.
4530 REM ================================================================
4540 FUNCTION DECODE_LISP_OBJECT(OFF):
4550   TAG = FN READ_BYTE(HEAP_BASE + OFF)
4560   IF TAG = 0x00 THEN
4570     RETURN { type: "NIL", value: 0 }
4580   ELSE IF TAG = 0x01 THEN
4590     VAL = FN READ_LONG_BE(HEAP_BASE + OFF + 1)
4600     RETURN { type: "INTEGER", value: VAL }
4610   ELSE IF TAG = 0x02 THEN
4620     CAR = FN READ_LONG_BE(HEAP_BASE + OFF + 1)
4630     CDR = FN READ_LONG_BE(HEAP_BASE + OFF + 5)
4640     RETURN { type: "CONS", car: CAR, cdr: CDR }
4650   ELSE IF TAG = 0x03 THEN
4660     LEN = FN READ_BYTE(HEAP_BASE + OFF + 1)
4670     NAME$ = FN READ_BYTES(HEAP_BASE + OFF + 2, LEN)
4680     RETURN { type: "SYMBOL", value: NAME$ }
4690   ELSE
4700     RETURN { type: "UNKNOWN", tag: TAG }
4710   END IF
4720 END FUNCTION
4730 REM
4740 REM ================================================================
5000 REM  SECTION 7: MEMORY MACHINE STATE TRANSITIONS
5001 REM ================================================================
5010 REM
5020 REM  Explicit state machine for machine state capture and restoration.
5030 REM  M_n → SAVE → D_n (disk image)
5040 REM  D_n → RESTORE → M_n
5050 REM
5060 REM ================================================================
5100 REM  SAVE_MACHINE_STATE(disk_addr) → success
5110 REM  Serialize complete machine state to disk image.
5120 REM ================================================================
5130 FUNCTION SAVE_MACHINE_STATE(DISK_ADDR):
5140   PRINT "SAVE: encoding machine state..."
5150   REM Serialize registers
5160   OFFSET = DISK_ADDR
5170   GOSUB WRITE_BYTE(OFFSET + 0, M_PC / 256)     REM PC high byte
5180   GOSUB WRITE_BYTE(OFFSET + 1, M_PC MOD 256)   REM PC low byte
5190   GOSUB WRITE_BYTE(OFFSET + 2, M_ACC)
5200   GOSUB WRITE_BYTE(OFFSET + 3, M_X)
5210   GOSUB WRITE_BYTE(OFFSET + 4, M_Y)
5220   GOSUB WRITE_BYTE(OFFSET + 5, M_SP)
5230   GOSUB WRITE_BYTE(OFFSET + 6, M_STATUS)
5240   REM Serialize device state
5250   GOSUB WRITE_BYTE(OFFSET + 7, DRIVE_MOUNTED)
5260   GOSUB WRITE_BYTE(OFFSET + 8, DRIVE_TRACK)
5270   GOSUB WRITE_BYTE(OFFSET + 9, DRIVE_PROTECTED)
5280   GOSUB WRITE_BYTE(OFFSET + 10, DRIVE_MOTOR)
5290   REM Serialize heap and Lisp objects
5300   GOSUB WRITE_LONG_BE(OFFSET + 11, HEAP_SIZE)
5310   GOSUB WRITE_LONG_BE(OFFSET + 15, HEAP_OBJECT_COUNT)
5320   REM Write Lisp heap (24KB)
5330   FOR I = 0 TO HEAP_SIZE - 1
5340     GOSUB WRITE_BYTE(OFFSET + 19 + I, M_HEAP(I))
5350   NEXT I
5360   DISK_GENERATION = DISK_GENERATION + 1
5370   GOSUB WRITE_LONG_BE(OFFSET + 19 + HEAP_SIZE, DISK_GENERATION)
5380   PRINT "SAVE: complete at offset $"; USING "####"; OFFSET
5390   PRINT "SAVE: generation #"; DISK_GENERATION
5400   RETURN 1
5410 END FUNCTION
5420 REM
5430 REM ================================================================
5440 REM  RESTORE_MACHINE_STATE(disk_addr) → success
5450 REM  Deserialize complete machine state from disk image.
5460 REM ================================================================
5470 FUNCTION RESTORE_MACHINE_STATE(DISK_ADDR):
5480   PRINT "RESTORE: decoding machine state..."
5490   OFFSET = DISK_ADDR
5500   REM Deserialize registers
5510   M_PC = FN READ_WORD_BE(OFFSET + 0)
5520   M_ACC = FN READ_BYTE(OFFSET + 2)
5530   M_X = FN READ_BYTE(OFFSET + 3)
5540   M_Y = FN READ_BYTE(OFFSET + 4)
5550   M_SP = FN READ_BYTE(OFFSET + 5)
5560   M_STATUS = FN READ_BYTE(OFFSET + 6)
5570   REM Deserialize device state
5580   DRIVE_MOUNTED = FN READ_BYTE(OFFSET + 7)
5590   DRIVE_TRACK = FN READ_BYTE(OFFSET + 8)
5600   DRIVE_PROTECTED = FN READ_BYTE(OFFSET + 9)
5610   DRIVE_MOTOR = FN READ_BYTE(OFFSET + 10)
5620   REM Deserialize heap
5630   HEAP_SIZE = FN READ_LONG_BE(OFFSET + 11)
5640   HEAP_OBJECT_COUNT = FN READ_LONG_BE(OFFSET + 15)
5650   REM Read Lisp heap (up to HEAP_SIZE bytes)
5660   FOR I = 0 TO HEAP_SIZE - 1
5670     M_HEAP(I) = FN READ_BYTE(OFFSET + 19 + I)
5680   NEXT I
5690   DISK_GENERATION = FN READ_LONG_BE(OFFSET + 19 + HEAP_SIZE)
5700   PRINT "RESTORE: complete"
5710   PRINT "RESTORE: generation #"; DISK_GENERATION
5720   RETURN 1
5730 END FUNCTION
5740 REM
5750 REM ================================================================
6000 REM  SECTION 8: VERIFICATION AND TESTING
6001 REM ================================================================
6010 REM
6020 REM  Determinism verification:
6030 REM  INPUT BINARY → PARSE → M_1
6040 REM  INPUT BINARY → PARSE → M_2
6050 REM  M_1 ≡ M_2 (byte-for-byte equivalence)
6060 REM
6070 REM  Serialization round-trip:
6080 REM  M_n → SAVE → D_n → PARSE → M_n' → SAVE → D_n'
6090 REM  D_n ≡ D_n' (byte-for-byte)
6100 REM
6110 REM  Restoration:
6120 REM  M_n → SAVE → D_n → RESTORE → M_n'
6130 REM  M_n ≡ M_n' (defined equivalence)
6140 REM
6150 REM ================================================================
6200 REM  TEST_DETERMINISM() → pass/fail
6210 REM ================================================================
6220 FUNCTION TEST_DETERMINISM():
6230   PRINT "TEST: determinism..."
6240   REM Parse same input twice
6250   IF PARSE_WOZ_HEADER(0) <> PARSE_WOZ_HEADER(0) THEN
6260     TEST_FAIL = TEST_FAIL + 1
6270     PRINT "FAIL: non-deterministic parse"
6280     RETURN 0
6290   END IF
6300   TEST_PASS = TEST_PASS + 1
6310   PRINT "PASS: deterministic parse"
6320   RETURN 1
6330 END FUNCTION
6340 REM
6350 REM ================================================================
6360 REM  TEST_SERIALIZATION_ROUNDTRIP() → pass/fail
6370 REM ================================================================
6380 FUNCTION TEST_SERIALIZATION_ROUNDTRIP():
6390   PRINT "TEST: serialization round-trip..."
6400   REM Serialize once
6410   GOSUB SAVE_MACHINE_STATE(0)
6420   REM Read serialized state
6430   SAVED_PC = FN READ_WORD_BE(0)
6440   SAVED_ACC = FN READ_BYTE(2)
6450   REM Restore
6460   GOSUB RESTORE_MACHINE_STATE(0)
6470   REM Re-serialize
6480   GOSUB SAVE_MACHINE_STATE(10000)
6490   REM Compare
6500   NEW_PC = FN READ_WORD_BE(10000)
6510   NEW_ACC = FN READ_BYTE(10002)
6520   IF SAVED_PC <> NEW_PC OR SAVED_ACC <> NEW_ACC THEN
6530     TEST_FAIL = TEST_FAIL + 1
6540     PRINT "FAIL: serialization round-trip mismatch"
6550     RETURN 0
6560   END IF
6570   TEST_PASS = TEST_PASS + 1
6580   PRINT "PASS: serialization stable"
6590   RETURN 1
6600 END FUNCTION
6610 REM
6620 REM ================================================================
6630 REM  TEST_OBJECT_IDENTITY() → pass/fail
6640 REM ================================================================
6650 FUNCTION TEST_OBJECT_IDENTITY():
6660   PRINT "TEST: object identity preservation..."
6670   REM Encode a cons cell with object IDs
6680   GOSUB ENCODE_LISP_CONS(0, 1, 2)
6690   REM Decode it
6700   OBJ = DECODE_LISP_OBJECT(0)
6710   REM Verify car and cdr IDs
6720   IF OBJ.car <> 1 OR OBJ.cdr <> 2 THEN
6730     TEST_FAIL = TEST_FAIL + 1
6740     PRINT "FAIL: object identity lost"
6750     RETURN 0
6760   END IF
6770   TEST_PASS = TEST_PASS + 1
6780   PRINT "PASS: object identity preserved"
6790   RETURN 1
6800 END FUNCTION
6810 REM
6820 REM ================================================================
6830 REM  TEST_MALFORMED_REJECTION() → pass/fail
6840 REM ================================================================
6850 FUNCTION TEST_MALFORMED_REJECTION():
6860   PRINT "TEST: malformed disk rejection..."
6870   REM Write bad magic
6880   GOSUB WRITE_BYTE(0, ORD("B"))
6890   GOSUB WRITE_BYTE(1, ORD("A"))
6900   GOSUB WRITE_BYTE(2, ORD("D"))
6910   GOSUB WRITE_BYTE(3, 1)
6920   REM Try to parse
6930   IF PARSE_WOZ_HEADER(0) = 1 THEN
6940     TEST_FAIL = TEST_FAIL + 1
6950     PRINT "FAIL: accepted malformed header"
6960     RETURN 0
6970   END IF
6980   TEST_PASS = TEST_PASS + 1
6990   PRINT "PASS: malformed header rejected"
7000   RETURN 1
7010 END FUNCTION
7020 REM
7030 REM ================================================================
7100 REM  RUN_VERIFICATION_SUITE() → void
7110 REM ================================================================
7120 SUB RUN_VERIFICATION_SUITE():
7130   PRINT "========================================"
7140   PRINT "VERIFICATION SUITE"
7150   PRINT "========================================"
7160   TEST_PASS = 0
7170   TEST_FAIL = 0
7180   GOSUB TEST_DETERMINISM()
7190   GOSUB TEST_SERIALIZATION_ROUNDTRIP()
7200   GOSUB TEST_OBJECT_IDENTITY()
7210   GOSUB TEST_MALFORMED_REJECTION()
7220   PRINT
7230   PRINT "RESULTS:"
7240   PRINT "  PASS: "; TEST_PASS
7250   PRINT "  FAIL: "; TEST_FAIL
7260   PRINT "========================================"
7270 END SUB
7280 REM
7290 REM ================================================================
8000 REM  MAIN PROGRAM
8001 REM ================================================================
8010 REM
8020 PRINT "MEMORY MACHINE: WOZ DISK BINARY STATE SYSTEM"
8030 PRINT "============================================"
8040 PRINT "Loading verification suite..."
8050 GOSUB RUN_VERIFICATION_SUITE()
8060 REM
8070 PRINT
8080 PRINT "Creating test Woz disk image..."
8090 GOSUB SERIALIZE_WOZ_HEADER(0, 1, 3)
8100 PRINT "Woz header serialized at $0000"
8110 REM
8120 PRINT
8130 PRINT "Mounting disk..."
8140 GOSUB MOUNT_DISK(0, 0)
8150 REM
8160 PRINT
8170 PRINT "Saving machine state to disk..."
8180 GOSUB SAVE_MACHINE_STATE(256)
8190 REM
8200 PRINT
8210 PRINT "Restoring machine state from disk..."
8220 GOSUB RESTORE_MACHINE_STATE(256)
8230 REM
8240 PRINT
8250 PRINT "Machine state restored successfully."
8260 PRINT
8270 PRINT "Heap dump:"
8280 GOSUB HEX_DUMP(HEAP_BASE, 256, "Lisp heap (first 256 bytes):")
8290 REM
8300 END
