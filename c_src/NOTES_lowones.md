# lowones module notes (AST2RT: math pack $6831-$68C9, star service $6EE5-$703B)

Files: `lowones.c`, `lowones.h`, `lowones_data.c` (generated - run
`py c_src/tools/gen_lowones_data.py` to regenerate from the 64K image,
`../disasm/build/spacduel_64k.bin`, built by `disasm/gen_from_roms.py`).

## The trig/multiply pack - register contract (derived from ALL call sites)

Angles are 256 units per full circle ($40 = 90 degrees). Sine values are
signed, full scale +/-$7F.

| routine | in | out | clobbers |
|---|---|---|---|
| `Sin1` $683E | A = angle **$00-$7F only** (half circle; only PiAngle0 calls it) | A = sin, $00-$7F | X (TAX table index) |
| `PiAngle0` $6834 | A = angle $00-$FF | A = sin(A), signed | X |
| `CosSinPi2` $6831 | A = angle | A = cos(A) = sin(A+$40), signed | X |
| `Comp` $684D | A | A = -A (two's complement; callers branch on result N) | - |
| `Comp1` $6852 | bare RTS (BPL target of $684B) | - | - |
| `EntryInputExitAbsolute` $684B | A signed | A = \|A\| ($80 stays $80) | - |
| `OutputTemp2Temp21` $686D | A = **signed** multiplicand, WHITE ($07) = **unsigned** multiplier | A = POTGO ($0B) = product high byte (= A*WHITE/256); POKRAN ($0A) = low byte | TEMP1 ($10), X, Y; WHITE preserved |
| `SignedBySignedMult` $6853 | A, WHITE both **signed** | as OutputTemp2Temp21 | additionally **rewrites WHITE = \|WHITE\|** (clamped $80->$7F) when it was negative; A clamped -128->$7F |
| `L_90_68C7` $68C7 | shared STA POTGO / RTS tail | no outside callers - folded in | - |

Details that matter downstream:

- **X is destroyed by every sine call** (Sin1 does TAX). The ROM's own
  comment at $49E4: "IS THIS NEEDED? YES, SIN USES X" - C callers keep
  their own locals, but any translated caller must reload its X-derived
  state (usually `LDX XCOMP`) after a sine, exactly as the ROM does.
- The dominant idiom (Ok1 $49CB, Spark2 $63BC, Fire3 $4CCA, ThrustTwoShips,
  WillAssumeRadiusBar...): preload WHITE with a speed/length, then
  `pi_angle0(angle)` / `cos_sin_pi2(angle)` straight into
  `output_temp2_temp21(...)` -> A = component = sin*speed/256.
- OutputTemp2Temp21 works via the 256-byte nibble-product table $6D5C
  (`nibmul[(h<<4)|l] = h*l`) - four partial products; the entry N flag is
  PHP-saved and selects the signed fixup `high -= WHITE`. Verified
  **exhaustively** (65536/65536): result == high/low byte of
  (int8)A * (uint8)WHITE.
- SignedBySignedMult's WHITE rewrite is a real, observable RAM side
  effect (WHITE $07); reproduced.
- RAM stores inside OutputTemp2Temp21, in ROM order: TEMP1=A,
  POTGO=Ahi*Whi, POKRAN=Alo*Wlo, TEMP1=cross>>4, POKRAN=product lo,
  POTGO=product hi. All reproduced for the oracle diff.
- Sanity: Sin07 == round(127*sin(i*pi/128)) within 0.5 over all 65
  entries, monotonic 0..127; full-circle pi_angle0/cos_sin_pi2 track
  127*sin/cos within +/-0.5 for all 256 angles; sin^2+cos^2 within 0.5%
  of 127^2 everywhere.

## DoLowOnesEvery ($6EE5) - what happens each frame

Called once at the top of every mainline frame ($4024). It maintains the
eight persistent picture stubs in vector RAM that the per-frame display
lists JSRL into, then falls through Toppic ($6F6E) and
MoveSaucerPicColor ($6F92). In C, `do_low_ones_every()` calls `toppic()`
which calls `move_saucer_pic_color()` - one call does the whole $6EE5 pass.

1. **Rotation/color counters** ($3D6-$3DD, ASTERS block):
   - fast pair every frame: INC $3D6 (CW), DEC $3D7 (CCW);
     slow pair only when ($44 & 3) == 0: INC $3D8, DEC $3D9.
   - every 4th CW step, color counters $3DA/$3DC count up, reloading to
     $FD (3 colors, fast) / $FC (4 colors, slow) on going non-negative.
   - when a CCW counter "leaves its first pic" ((val&3)==3 after DEC),
     pic-select countdowns $3DB/$3DD decrement, reloading to 2 / 3.
     $3DB/$3DD low bits double as color codes for stubs 1 and 3.
2. **Rock stubs** VROCK1-4 ($2290/$229E/$22AC/$22BA): for star X=3..0,
   point BLUE/EAC2 at the stub and write a 2-byte AVG **JMPL word from
   RSOURC** ($6E8D: 4 rows of 8 words, row = rotation counter & 3), then
   for X=0..2 three {COLOR lo, $64; RTSL $C0,$C0} 4-byte groups
   (CVR11..PYR13); X==2 uses ColorTable+6 (Barco2, 4-color). X==3 gets
   the bare word.
3. **Toppic**: same recopy for the single-word stubs VROCK5-8
   ($22BC-$22C2), XCOMP biased +8 into the RSOURC rows, and X forced to
   (X&1)+2 so only the **slow** counters $3D8/$3D9 rotate them.
4. **MoveSaucerPicColor**: every 4th frame INC SAUCIX ($3ED, mod 4);
   every 16th frame rotate the saucer color bytes SAU11/12/13
   ($22C4/$22C8/$22CC, vector RAM) one step.

**BLUE/EAC2 ($01/$02) - the VG display-list pointer - is clobbered** (left
pointing into the last top stub). The ROM relies on the mainline resetting
the pointer before list building; the C port reproduces the clobber.
All `(BLUE),Y` stores go through `vg_poke_list()` (no pointer advance).

## Other entry points

- `SaveLater` $7017: in X = star 0-3; POKRAN=X, XCOMP=A=Y=X*2; returns Y.
- `GetRotationColorCode` $701F: in X = counter index 0-3, XCOMP = slot
  offset, BLUE/EAC2 = stub; writes the 2-byte RSOURC word, returns Y=2
  (callers continue writing at (BLUE),2). `GetRotationColorCode_11`
  ($702B) is local only.
- `L80RandomWave0` $6FDD: `l80_random_wave0(x, y)` - caller passes its
  live X/Y because the ROM stashes them to **$17** (unnamed zp scratch)
  and **NOBJ** ($15) - real stores the oracle diff sees - then restores
  them. Returns A = picture code from $6EDD ({00,08,10,18,28,30,20,38}),
  chosen by WAVE (clamped to 18) through Mod/$6FB9 and
  TableRandomPictureSelect/$6FCB; waves flagged $80 cycle MODNUM ($3F8)
  down with reload. Callers: Newast $5A6A (X=rock slot, Y=0), $5B57.

## Const tables (lowones_data.c, all extracted + listing-cross-checked)

| array | ROM | bytes | contents |
|---|---|---|---|
| `lowones_sin07` | $6D1B | 65 | quarter-wave sine table |
| `lowones_nibmul` | $6D5C | 256 | nibble products h*l |
| `lowones_stardest` | $6E7D | 16 | stub addresses: VROCK1-4 (lo,hi) then VROCK5-8 |
| `lowones_rsourc` | $6E8D | 64 | 4x8 little-endian AVG JMPL words |
| `lowones_piccode` | $6EDD | 8 | L80RandomWave0 picture codes |
| `lowones_mod_m1` | $6FB8 | 19 | Mod, base-1 ([0] = the $60 RTS ending MoveSaucerPicColor - a code byte the base-1 idiom can reach; generator takes it from the binary, unchecked) |
| `lowones_randsel_m1` | $6FCA | 19 | TableRandomPictureSelect, base-1 |
| `lowones_colortab` | $7009 | 14 | ColorTable(6)+Barco2(8), indexed across both |

## Externs / dependencies

- `vg_poke_list()` from vgutil.h (raw `STA (BLUE),Y`). Nothing else; the
  module reads no hardware (no POKEY RANDOM in this range - Spark2's
  `LDA $100A` at $63B6 is a *caller*, not this module).
- Unnamed cells used: `g.ram[0x17]` (L80RandomWave0 X stash),
  `g.ram[0x3D7..0x3DD]` (ASTERS+1..+7 star state), `ZP_44` (frame
  counter, already in sd_state.h). Candidate names for the orchestrator:
  $3D7/$3D9 "CCW rotation counters", $3DA/$3DC "star color counters",
  $3DB/$3DD "CCW pic-select/color".

## Open questions

1. **WAVE = 0 in L80RandomWave0** would read the $6FB8 code byte ($60)
   and then index $6EDD+$60 into code. Assumed unreachable (rocks spawn
   after WAVE increments); if an oracle scenario ever hits it, the C
   version reads `lowones_mod_m1[0]` = $60 correctly but
   `lowones_piccode[0x60]` would be out of bounds - guard/extend then.
2. `$6E5D-$6E7C` (16 JSRL words $AC04/$AB89/...) sit between the nibble
   table and stardest but are referenced from *outside* this module's
   range - left to whichever module indexes them.
3. Whether any caller depends on SaveLater's A==Y return distinction:
   none found (both are X*2); C returns the single value.
