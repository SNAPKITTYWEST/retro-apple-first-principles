# Retro Apple -- First Principles

Retro computing suite built from first principles. C64/C128 BASIC programs, 6502 assembly, and an Applesoft BASIC formal state machine, all with explicit binary semantics.

## Contents

### Miami Ice (`c64/miami_ice.bas`)
C128 BASIC game from COMPUTE! magazine Issue 73. Complete listing with Philip I. Nelson two-letter checksums.

### COMPUTE! New Automatic Proofreader (`proofreader/`)

Philip I. Nelson's 1986 proofreader, fully reverse-engineered:

| Directory | Contents |
|-----------|---------|
| `c64/` | Original BASIC loaders (ML image in DATA statements) |
| `softbasic/` | Pure-software reimplementation (QBASIC/GW-BASIC compatible) |
| `asm/` | Annotated 6502 assembly reconstruction + optimized variants |
| `docs/` | Algorithm, usage, byte-level map |

**Algorithm:** 16-bit weighted checksum (char x position), spaces ignored outside quotes, seeded with line number. Two-letter display from `ABCDEFGHJKMPQRSX`.

### Memory Hammer (`hammer/`)

C64 RAM stress tester. Five patterns: walking-1, AA fill, 55 fill, checkerboard, 16-bit LFSR. Red border + CPU lock on failure.

| File | Contents |
|------|---------|
| `bas/memhammer.bas` | BASIC menu + DATA loader |
| `asm/memhammer.asm` | Annotated 6502 source |

### Memory Machine (`memory-machine/`)

Applesoft BASIC implementation of a deterministic state machine for Lisp world serialization on WOZ floppy disk images.

**Core invariant:** `M_n -> SAVE -> D_n -> RESTORE -> M_n` (state equivalence).

Implements:
- WOZ disk header parser (rejects malformed, never silently repairs)
- Virtual disk controller (MOUNT / EJECT / SEEK / READ / WRITE)
- Lisp heap with type-tagged objects (NIL, INTEGER, CONS, SYMBOL, STRING, BUILTIN, CLOSURE, VECTOR)
- Complete machine state serialization (registers, device state, heap)
- Four-test verification suite (determinism, round-trip, object identity, malformed rejection)

| File | Contents |
|------|---------|
| `bas/memory_machine.bas` | Full Applesoft BASIC implementation (684 lines) |
| `docs/spec.md` | Formal specification, binary layouts, classification table |

## Classification Discipline

All binary claims are tagged:
- **VERIFIED** -- tested against known behavior
- **INFERRED** -- deduced from analysis, not yet verified
- **UNKNOWN** -- explicitly unspecified

## Running

### Miami Ice / Proofreader (original)
Load on a C64/C128 emulator (VICE) or real hardware. Type `LOAD "filename",8` then `RUN`.

### SoftBASIC Proofreader
Any modern BASIC dialect:
```
RUN proofreader/softbasic/proofreader_engine.bas
```

### Memory Machine
Applesoft BASIC on Apple II hardware or emulator (AppleWin, Virtual II). Load and `RUN memory_machine.bas`.

## License

FSL-1.1. Converts to Apache 2.0 after two years. See LICENSE.
