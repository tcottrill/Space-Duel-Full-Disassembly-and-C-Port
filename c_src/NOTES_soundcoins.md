# Sound (AS2SAC/AS2POK) + coins (COIN65) translation notes

Modules: `sound.c`/`sound.h` ($703C-$7419), `coins.c`/`coins.h` ($741A-$7528).
ROM data: `sound_data.c`/`sound_data.h` = `sd_sndrom[]`, the whole $703C-$7419
byte range extracted from the 64K image (`../disasm/build/spacduel_64k.bin`,
built by `disasm/gen_from_roms.py`) by `tools/gen_sound_data.py`
(rationale in the script header: the driver's indexed reads are open-ended,
so the contiguous module region is extracted instead of hand-cut tables;
known bytes are spot-checked against the annotated listing at generate time).

## The sound-channel model

16 script channels, updated once per IRQ by `continue_sounds`
(ContinuesPreviouslyStartedSound $731D, called from Irq $8703 when not in
self-test). Channel X (15..0) owns four RAM cells:

| cells | role |
|---|---|
| `$56+X` | script pointer, 0 = idle. This is POINT, 16 channels at `$56-$65`. Under the old RAM map these cells carried the names TOGGLE/TOGDRONE/TOGCOMB/SCRFUL/KLMOFF/TSTBYTE, which made the array look like it was overlapping unrelated flags; it is not, they are just channels 2 and 4-9 (e.g. ForceFieldUp tests POINT+4 = channel 4 = AUDF3's script). The one name still landing inside the array is the constant MXSPKT, whose value $60 is POINT+10 |
| `$66+X` | current register value (AUDF for even X, AUDC for odd X) |
| `$76+X` | steps left in the current script entry |
| `$86+X` | IRQ ticks left in the current step |

`$96` is a channel-under-construction interlock: Badhab sets it to the
channel number while seeding, `$FF` when done; continue_sounds skips the
matching channel (`CPX $96`). Single-threaded C never sees it mid-build, but
the stores are reproduced (oracle-diffed cell).

Register mapping: channel 0-7 -> POKEY1 reg 0-7 (`STA POKEY,X`), channel
8-15 -> POKEY2 reg 0-7 (`STA $13F8,X`). Even/odd = AUDF/AUDC pairs, so a
sound uses channel pairs; pair (2k, 2k+1) = POKEY voice. All writes go
through `sd_hw_pokey_write(which, reg, val)`.

Script format: entry = 4 bytes at `$719B + pointer*2`; the ROM's `ASL`
carry selects base $719B or $729B, i.e. one seamless 9-bit address space
(bank1 base = bank0 base + $100), which is how the C code indexes it.
Bytes: +0 value, +1 tick count, +2 per-step delta, +3 step count. Pointer
advances by 2 per entry (`INC POINT,X` twice). Tick count 0 terminates;
then value byte != 0 is a restart pointer (looping) — but **no shipped
script uses it**: every terminator in $71A0-$72B8 is $00,$00 (checked
2026-08-30; see SOUNDS.md). Continuous sounds (thrust/shield/fuse) are
short one-shots the game re-triggers instead.
Within an entry, each expiry of the tick counter decrements the step count
and adds the delta to the value; **odd channels (AUDC) keep their old high
nibble** (distortion bits) and take only the new low nibble (volume fade) -
the `((old^new)&$F0)^new` EOR trick at $7389.

Trigger path: stubs ($72B9-$72EF) load a code $0F..$DF and fall into
HighScoreTune ($72F1): play only if HSCFLG bit 7 (high-score tune, works in
attract) or `$35` bit 7 (game in progress), else return with **no RAM
writes**. Badhab ($72FA) scans the code->channel map at `$70C1 + code`
downward, 16 rows (Y=code..code-15 vs X=15..0); nonzero bytes are script
pointers, and the channel gets pointer + `$86=$76=1` so the next IRQ tick
performs the real first fetch ("dummy start"). Decoded map (channel: initial
pointer):

| trigger | code | channels seeded |
|---|---|---|
| SaucerFire | $0F | ch3 $04, ch2 $01 |
| Player0Fire | $1F | ch1 $0A, ch0 $07 |
| Player1Fire | $2F | ch7 $0A, ch6 $15 |
| Reenter2 | $3F | ch1 $10, ch0 $0D |
| Reenter | $4F | ch7 $10, ch6 $18 |
| ExtraLife2 | $5F | ch5 $26, ch4 $21 |
| Explosion | $6F | ch15 $62, ch14 $5F, ch13 $50, ch12 $49 |
| ThrustSound | $7F | ch9 $68, ch8 $65 |
| FusePlyr0 | $8F | ch1 $45, ch0 $3E |
| FusePlyr1 | $9F | ch7 $45, ch6 $3E |
| Gates (high-score tune) | $AF | ch1 $70, ch0 $6B |
| Sh0sn | $BF | ch1 $1E, ch0 $1B |
| Sh1sn | $CF | ch7 $1E, ch6 $1B |
| Popsn | $DF | ch3 $86, ch2 $81 |

So: player 0 owns POKEY1 voice 0 (ch0/1), player 1 POKEY1 voice 3 (ch6/7),
saucer/pop POKEY1 voice 1 (ch2/3), extra-life POKEY1 voice 2 (ch4/5, shared
with the force-field echo), thrust POKEY2 voice 0 (ch8/9), explosions POKEY2
voices 2+3 (ch12-15).

## Register protocols (sound)

- **Trigger stubs / high_score_tune / badhab**: A = code (parameter). The
  ROM parks the caller's live X/Y in TEMPA/TEMPB (`$1C/$1D`) and restores
  them; registers survive but the RAM stores are oracle-visible, so the C
  signatures take `(x_in, y_in)` = the caller's live 6502 X/Y and callers
  must pass them. In plain attract (no HSCFLG) nothing is stored at all.
- **continue_sounds**: no inputs, clobbers A/X/Y. `sub_731f` ($731F) and
  `sub_73a1` ($73A1) are only reached by the routine's own `JMP`s
  (L73A4/L739B) - translated as the loop, not separate C entries (checked:
  no external JSR/JMP in the listing). Same for YesStartValue ($732F,
  internal `BNE` only) - static helper `yes_start_value()`.
- **inisou**: no inputs, clobbers A/X. SKCTL both POKEYs 0 then 7, regs
  0-7 and AUDCTL of both POKEYs cleared. Quirk kept: only channels 0-7's
  `$56`/`$66` cells are cleared (`LDX #$07` loop), so POKEY2 scripts
  (thrust/explosion, ch8-15) survive an Inisou and keep re-writing POKEY2
  registers on later IRQs.
- **force_field_up**: no inputs, clobbers A/X/Y. COMTIMER != 0 = field up:
  POKEY2 AUDCTL=1, hum divider SFREQ steps down (pitch up) to $30 every 8th
  frame (`$44 & 7`), AUDF2/AUDC2 = SFREQ/$A3; else AUDF2/AUDC2/AUDCTL2/SFREQ
  cleared. Both paths echo on POKEY1 AUDF3/AUDC3 (value+1, tone; off path
  writes 0/0 via the $FF+1 wrap) unless channel 4 (POINT+4) is scripted.
- **always_remains_same_both**: called from Pictur ($5D71) with X = object
  index $1F; X stack-preserved (register only), A/Y clobbered. No-op unless
  SUPRSAC bit 7. Copies saucer object $1F -> $20 (OBJXL/OBJXH/OBJYL/OBJYH/
  XINC pairs, YH offset by SUPRDIS) and X into the 4 shells ($24-$27), sets
  SUPRTIM from the Time table (`$707F + SUPRDIS`, real entries at $7083,
  distances >= 4). `$B7` (unnamed) = saucer-1 active flag, set to $41.
- **l2_saucers**: no inputs, clobbers A/X. For each active saucer
  (`$B6+X` != 0) steps velocity `$21F+X` one count toward signed minimum
  `$D3+X` using the 6502 SEC/SBC + BVC/EOR#$80 signed compare - the V flag
  is computed exactly (`(m^vel)&(m^r)&$80`).

## Coin routine state machine (coin_routine, $741A)

Per-IRQ (from Irq $8660, unless LANGBT bit 7 or self-test). Loop mechs
X=2,1,0; IN0 is re-read from the seam for **every** mech and again for the
slam check, matching the ROM's read count. Coin bit for mech X = IN0 bit
(2-X) (X=0 left mech = d2, X=1 center = d1, X=2 right = d0), 1 = absent;
slam = d3, 1 = off. **Oracle polarity trap** (NOTES_oracle.md): idle-low
IN0 makes the slam look active, so $0025 is reloaded $F0 every IRQ and
`$2D-$2F`/`$2A-$2C` are cleared every pass - reproduced, do not "fix".

Per-mech debounce on `$2D+X` (InstructionsBracketsAreIllustration $7428):

1. Coin present (bit low): the d0-d4 down-counter runs from $1F - fast
   (every IRQ) for the first five samples ($1F..$1B), then once per 8 IRQs
   (`ZSHIP & 7 == 7`); sticks at 0 (validated).
2. Coin absent: status >= $1B means the coin was on < 5 samples - reset to
   $1F. Otherwise the d5-d7 coin-off up-counter is bumped (+$20); when it
   wraps: result 0 = coin held too long, reset; nonzero = **valid coin** -
   status reset to $1F and post-coin slam timer `$2A+X` = $78. If `$2A+X`
   was already running, credit is granted immediately ("Howie's
   assumption"); otherwise the credit lands when the $78 timer expires in
   step 4 (slam protection window after the coin).
3. Slam: d3 low reloads pre-coin timer $0025=$F0; while $0025 runs it is
   decremented and coin status + post-coin timers are zeroed (coins during
   slam ignored).
4. Post-coin timer `$2A+X` decrement; hitting 0 = the coin counts.
5. A counted coin adds units+1 to $0022 (bonus accumulator) and $0026
   (CNCT): left mech 1 unit, center 1/2 (ZMINE d4), right 1/4/5/6
   (ZMINE d2-d3), and `INC $27+X` queues an EM coin-counter pulse.

Then fall-through chain (all internal, no external callers - verified by
grep, so static functions in C): GetBonusAdderMode ($74B3, bonus coins per
NumberUnitCoinsRequired[$74CF], mode 3 pays 2) -> Extb ($74D7, unit-coins ->
credits DIAGBI: price 1/1/2 for modes 1/2/3, mode 1 pays 2 credits, ZPAIR
bonus coins cover shortfalls; mode 0 free play stores 0 to $0026) -> Ext
($74FA: INC ZSHIP; every second call runs the EM pulse cells `$27-$29`,
low nibble = pulses pending, high nibble = on-time, at most one pulse
running at a time). The `$741C` entry is only the ROM's own mech-loop
re-entry (`L74B0 JMP L741C`) - no separate C function (`sub_741c` not
needed; irq.c's `coin_routine` extern is the $741A entry).

## Extern list (what these modules import)

- `sd_state.h`: `g`, macros SUPRSAC, SUPRTIM, SUPRDIS, TEMP9, COMTIMER,
  SFREQ, HSCFLG, ZP_35, ZP_44, TEMPA, TEMPB, DIAGBI, ZSHIP, ZPAIR, ZMINE,
  LANGBT, and the coin cells the defines cannot name because Atari spelled
  them with a `$` sigil: $0022 ($BCCNT), $0025 ($LMTIM), $0026 ($CNCT),
  $0027 ($CCTIM) (caller side).
- `sd_hw.h`: `sd_hw_pokey_write(which, reg, val)` (reg $0-$F: 0/2/4/6
  AUDF1-4, 1/3/5/7 AUDC1-4, 8 AUDCTL, $F SKCTL), `sd_hw_in0()`.
- `sound_data.h`: `sd_sndrom[]` / `SNDROM(addr)`.
- No POKEY RANDOM reads anywhere in these modules ($100A/$140A untouched -
  LFSR read-count parity unaffected).
- Exports consumed elsewhere: `continue_sounds`, `coin_routine` (irq.c),
  `inisou` ($4184/$4FF1/$68E0/$85C0/$8A20), `force_field_up` ($4107),
  `always_remains_same_both` ($5D71), `l2_saucers` ($6A4E), and the 14
  trigger stubs (call sites across mainline/objects modules).

## Unnamed RAM cells used (g.ram[..] + inline comments in code)

`$56-$65` script pointers (only $56 has an Atari name), `$66-$75` channel
values, `$76-$85` step counters, `$86-$95` tick counters, `$96` interlock;
`$B6/$B7` saucer active flags, `$D3/$D4` saucer minimum velocities;
`$2A-$2C` post-coin slam timers, `$2D-$2F` coin status (aliases ZP1MIN
$2C / ZLAST $2F in the defines are unrelated names for the same bytes);
object-array cells `$21F/$220, $2D4/$2D5, $2D9-$2DC, $306/$307, $33F/$340,
$344-$347, $371/$372` ($00A0* + $1F/$20/$24-$27).

## Open questions

1. **Trigger-stub X/Y parameters**: the `(x_in, y_in)` protocol is the
   faithful reading of Badhab's TEMPA/TEMPB parks, but it forces every
   caller module to know its live X/Y at the call site. If oracle diffs
   show TEMPA/$1C-TEMPB/$1D always overwritten again before a frame
   snapshot, the orchestrator may prefer to drop the parameters and mask
   the cells instead.
2. `LDA $707F,X` (AlwaysRemainsSameBoth) is byte-exact for any
   SUPRDIS <= $FF via the blob; the Time table proper is 14 entries at
   $7083, implying SUPRDIS in 4..17. Not yet confirmed against the
   saucer-logic module that sets SUPRDIS.
3. Extb's mode-0 path stores 0 to $0026 despite the "DO NOTHING" comment
   (free play clears CNCT every IRQ) - translated as coded.
4. GetBonusAdderMode's closing `BNE Extb` is a BRA that assumes
   `INC ZPAIR` left A/flags nonzero; if ZPAIR ever wrapped to 0 the 6502
   would fall into the NumberUnitCoinsRequired data. C just proceeds to
   extb() - divergence only possible after 256 un-consumed bonus coins.
5. Inisou leaves channels 8-15 scripts running (LDX #$07 loop) - looks
   like a bug that became behavior (thrust/explosion tails survive a
   game-over Inisou). Kept.
