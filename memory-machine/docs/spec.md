# Memory Machine -- Formal Specification

Applesoft BASIC implementation of a deterministic state machine for Lisp world serialization on WOZ floppy disk images.

## Architecture (bottom-up)

```
BINARY DISK IMAGE (raw 143,360 bytes)
    |
WOZ DISK STRUCTURE (header, tracks, sectors)
    |
DISK PARSER & SERIALIZER (explicit binary I/O)
    |
VIRTUAL DISK CONTROLLER (mount, seek, read/write)
    |
MEMORY MACHINE STATE MACHINE (M_n -> SAVE -> D_n -> RESTORE -> M_n)
    |
LISP HEAP & OBJECTS (type-tagged binary encoding)
    |
VERIFICATION SUITE (determinism, round-trip, object identity)
```

## Core Invariant

```
Machine State M_n
    -> SAVE (state transition)
    -> Disk Image D_n (binary snapshot)
    -> RESTORE (inverse transition)
    -> Machine State M_n' where M_n = M_n'
```

## State Vector

| Field | Type | Description |
|-------|------|-------------|
| M_PC | uint16 | Program counter |
| M_ACC | uint8 | Accumulator |
| M_X | uint8 | X register |
| M_Y | uint8 | Y register |
| M_SP | uint8 | Stack pointer |
| M_STATUS | uint8 | Status register (N,V,-,B,D,I,Z,C) |
| DRIVE_MOUNTED | bool | Disk present |
| DRIVE_TRACK | uint8 | Current track (0-34) |
| DRIVE_PROTECTED | bool | Write-protected |
| DRIVE_MOTOR | bool | Motor running |
| HEAP_SIZE | uint32 | Lisp heap bytes allocated |
| HEAP_OBJECT_COUNT | uint32 | Objects allocated |
| DISK_GENERATION | uint32 | Monotonic save counter |

## Binary Serialization Layout (on disk from OFFSET)

| Byte(s) | Field | Encoding |
|---------|-------|---------|
| 0-1 | M_PC | big-endian uint16 |
| 2 | M_ACC | uint8 |
| 3 | M_X | uint8 |
| 4 | M_Y | uint8 |
| 5 | M_SP | uint8 |
| 6 | M_STATUS | uint8 |
| 7 | DRIVE_MOUNTED | boolean |
| 8 | DRIVE_TRACK | uint8 |
| 9 | DRIVE_PROTECTED | boolean |
| 10 | DRIVE_MOTOR | boolean |
| 11-14 | HEAP_SIZE | big-endian uint32 |
| 15-18 | HEAP_OBJECT_COUNT | big-endian uint32 |
| 19..19+N | Lisp heap | raw bytes (N = HEAP_SIZE) |
| 19+N..22+N | DISK_GENERATION | big-endian uint32 |

## Lisp Object Encoding

| Tag | Type | Payload |
|-----|------|---------|
| 0x00 | NIL | (none; 1 byte total) |
| 0x01 | INTEGER | 4 bytes big-endian signed int |
| 0x02 | CONS | 2 x 4-byte object IDs (car, cdr) |
| 0x03 | SYMBOL | 1 byte length + UTF-8 string |
| 0x04 | STRING | 4 byte length + UTF-8 data |
| 0x05 | BUILTIN | 1 byte opcode |
| 0x06 | CLOSURE | 1 byte arity + 4-byte env ID + 4-byte code ID |
| 0x07 | VECTOR | 4 byte length + N x 4-byte object IDs |

Object IDs are machine-relative heap offsets, never host pointers.

## WOZ Disk Header

| Offset | Width | Field | Invariant |
|--------|-------|-------|-----------|
| 0 | 4 | MAGIC "WOZ1" | Must be present |
| 4 | 1 | INFO_BLOCK_SIZE | 1..255 |
| 5 | 1 | VERSION | Must be 1 |
| 6-15 | 10 | RESERVED | Must be all zeros |
| 16-271 | 256 | INFO_BLOCK | Metadata |
| 272+ | 160 | TMAP (track map) | Logical->physical |
| 432+ | ... | TRKS (tracks) | Track data |

## Reverse Engineering Classification

| Category | Meaning |
|----------|---------|
| VERIFIED | Tested against known behavior |
| INFERRED | Deduced from binary analysis, not yet tested |
| UNKNOWN | Explicitly unspecified gap |

Never silently convert INFERRED to VERIFIED.

## Verification Tests

1. **DETERMINISM**: Same input + same ops -> same state
2. **SERIALIZATION**: serialize -> parse -> serialize = identity
3. **RESTORE**: M_n -> save -> restore -> M_n (state equiv)
4. **CORRUPTION**: Invalid disk image is rejected, not repaired
5. **OBJECT_IDENTITY**: References survive serialization
