# Space Duel C conversion — conventions

Goal: a faithful C translation of the 6502 game program, proven byte-for-byte
against the real ROMs running under `tools/oracle.py`. Read `DESIGN.md` first.

Sources of truth (read before translating a module):
- `../disasm/spaceduel_program_rom.asm` — annotated disassembly,
  byte-verified against the ROM set (0 mismatches, ca65 cross-check)
- `../disasm/spaceduel_defines.asm` — hardware map + RAM symbols
- `../disasm/NOTES.md` — everything learned (AVG semantics, ship-picture draw
  model, naming provenance); `../disasm/README.md` — hardware and memory
  map; `NOTES_mainline.md` — the boot sequence

Rules:

1. One C function per named routine, name lowercased with underscores
   (`CheckForStartEnd` -> `check_for_start_end()`). Every function carries a
   comment with the original label and ROM address. Local branch labels
   (`Start2_14`) become control flow, not functions, unless they are entered
   from elsewhere (check the listing for external references first). An
   anonymous entry point `Lxxxx` becomes `sub_xxxx()` (lowercase hex) until
   its role earns it a name.
1b. Reproduce EVERY store the ROM makes to RAM — scratch cells included
   (TEMP4, NMROCK, TEMP2, ...). Full-RAM oracle diffs see them. Derive each
   routine's register protocol (what arrives in A/X/Y/C, what it returns)
   from ALL its call sites and document it above the function.
1c. Multi-agent hygiene: a module owns only its listed files; shared headers
   (sd_state.h, sd_hw.h, vgutil.h) are edited only by the orchestrator. An
   unnamed RAM cell is accessed as `g.ram[0xXX]` with an inline comment.
   Cross-module calls: declare an extern in your .c with the label+address
   in a comment; the orchestrator consolidates headers afterwards. Const
   data tables are EXTRACTED from the 64K image
   (`../disasm/build/spacduel_64k.bin`, built by `disasm/gen_from_roms.py`) by
   a generator script (tools/gen_<module>_data.py), never hand-transcribed.
2. All state lives in `sd_state g` (sd_state.h): the real `ram[0x400]` and
   `vram[0x800]` arrays. Access named cells through the macro aliases
   (`SDELAY`, `OBJXH(i)`, ...) generated from spaceduel_defines.asm. For a
   cell with no Atari name yet, add a `ZP_xx` / `RAM_xxx` macro to the
   "unnamed cells" section of sd_state.h with a comment on what it seems to
   be; upgrade the name when the meaning is proven. Never invent parallel
   state; if the ROM kept it in RAM, we keep it in `g.ram`/`g.vram`.
3. Byte semantics are the contract. 8-bit wraparound, carry chains, BCD
   (`SED` sections use the bcd helpers), the N/V/Z/C-driven branches — all
   must be reproduced exactly. When a routine communicates through the carry
   flag (e.g. CheckForStartEnd returns C set = new game), return an int and
   document `/* C flag */`.
4. Vector list building is real: the translated VGUTR2 routines append real
   AVG bytes to `g.vram` through the real list pointer (zp $01 lo / $02 hi,
   aliases VGLIST_LO/VGLIST_HI). Do not abstract shapes; the JSRL words the
   ROM wrote are the JSRL words we write.
5. Hardware I/O only through the `sd_hw_*` seam (sd_hw.h): IN0/IN1 switches,
   POKEY registers (including RANDOM — the PROBES' seam must match the
   oracle's LFSR read for read; the game's seam stands two real chips,
   `pokey.c`, behind the same calls), EAROM (`er2055.c` in the game), coin
   counters/lamps, VGGO/VGRST, watchdog (no-op), IRQ ack.
   The seam is implemented by app_loop.c (game) or the headless harness
   (probes, with injectable bytes).
5b. `pokey.c/.h` and `er2055.c/.h` are verbatim copies from the
   [Asteroids Deluxe port](https://github.com/tcottrill/Asteroids-Deluxe-Full-Disassembly-and-C-Port),
   `ad_` prefix and all: that tree is where they are developed and probed. Fix
   them there and re-copy; never let the two diverge. `tests\probe_pokey.c`
   and checks 1-5 of `tests\probe_er2055.c` are copies too.
   Include them BEFORE sd_state.h: the generated aliases `SKCTL`/`POTGO`
   (the ROM reused the register names for zero-page scratch) would
   otherwise rewrite the struct's field names.
6. Timing: machine time is 246.09 Hz IRQ ticks (1.512 MHz / 6144). The
   mainline's wait loops (`BIT HALT/BVC` at $401F, `LSR $33/BCC` at $4027)
   translate to `sd_wait_vghalt()` / `sd_wait_frame_gate()` seam calls that
   run pending IRQs; probe builds replay the oracle's exact IRQ-per-frame
   schedule.
7. Preserve quirks that affect behavior; drop pure hardware artifacts
   (watchdog kicks, IRQ ack) but note each drop in a comment.
8. Plain C11 (VS2022 cl, /W4 clean). No dynamic allocation. No globals
   besides `g` and const tables; const ROM tables keep their ROM address in
   a comment.
9. Before claiming a module done: its probe must byte-diff clean against the
   oracle scenario that exercises it, and `build_all.bat` must pass /W4.

Translation style example:

```c
/* CenterBeamInMiddle ($8EA1): CNTR word, beam to screen center. */
void center_beam_in_middle(void)
{
    vg_add2(0x40, 0x80);            /* L8EA1: timer+scale, CNTR opcode */
}
```
