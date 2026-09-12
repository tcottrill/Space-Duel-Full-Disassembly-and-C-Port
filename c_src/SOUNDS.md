# Space Duel sound inventory — for sample replacement

Purpose: identify every distinct sound the game can make, the trigger code
each one sends into the POKEY script engine, where the game fires it, and
what it sounds like — so each can be replaced with a recorded sample.
Engine internals are in `NOTES_soundcoins.md`; this doc is the catalogue
plus the recommended hook design.

All timings below use the IRQ rate 246.09 Hz (frame = 4 IRQs ≈ 61.5 Hz).

## How a sound starts (30-second recap)

Game code calls a trigger stub (`player0_fire()`, `explosion()`, ... in
`sound.c`, ROM $72B9-$72EF). Each stub is one line: load a **trigger code**
and fall into `high_score_tune(code, ...)` → `badhab(code, ...)`. Badhab
looks the code up in the map at $70C1 and seeds 1-4 of the 16 script
channels with script pointers; `continue_sounds()` (every IRQ) then plays
the scripts into the POKEY registers. **The trigger code is the sound's
identity** — 14 codes, one per distinct sound effect.

Gate: in plain attract mode (`ZP_35` bit 7 clear, `HSCFLG` bit 7 clear)
every trigger is a no-op. The only sound that plays outside a game is the
high-score tune ($AF), which sets HSCFLG.

## The 14 scripted sounds

Voice notation: P1v0 = POKEY1 voice 0 (script channels 0/1 = AUDF1/AUDC1),
P2v2 = POKEY2 voice 2 (channels 12/13), etc.

| code | ROM stub | event | fired from | voices | scripts (ROM) | audible length | character |
|---|---|---|---|---|---|---|---|
| $0F | SaucerFire | a saucer shoots | fire_ships_torpedos [objects.c:1446](objects.c) | P1v1 | $71A1 + Sf2a $71A7 | 0.52 s | buzzy descending zap: AUDF climbs +2/step, poly-4 dist, volume 7→1 |
| $1F | Player0Fire | player 1 ship fires | fire_ships_torpedos [objects.c:1448](objects.c) | P1v0 | ShipFirePlayer0 $71AD + P0f1a $71B3 | 0.26 s | classic "pew": AUDF $24 +3/tick ×64 (fast falling pitch), tone vol 4→1 |
| $2F | Player1Fire | player 2 ship fires | fire_ships_torpedos [objects.c:1450](objects.c) | P1v3 | ShipFirePlayer1 $71C9 + P0f1a (shared) | 0.26 s | same "pew", other voice |
| $3F | Reenter2 | **player 1** ship materializes/respawns | [objects.c:2079](objects.c), pair-respawn [objects.c:2757](objects.c) | P1v0 | P0e1f $71B9 + P0e1a $71BF | ~1.7 s | steady tone (AUDF $0A) swelling from silence to full volume, then cut |
| $4F | Reenter | **player 2** ship materializes/respawns | [objects.c:2076](objects.c), pair-respawn [objects.c:2758](objects.c) | P1v3 | P1e4f $71CF + P0e1a (shared) | ~1.7 s | same swell, one divider higher in pitch (AUDF $09) |
| $5F | ExtraLife2 | bonus-life score threshold crossed | [score.c:173](score.c) | P1v2 | ExtraLife $71E1 + El3a $71EB | ~1.8 s | two long high dings (AUDF 6 then 5, ~0.9 s each) over a 0.8 s on/off trill |
| $6F | Explosion | anything explodes: rock split/vaporized, ship, saucer killed, killer mine dies, burning rod ends | [objects.c:344](objects.c), [446](objects.c), [1837](objects.c), [1870](objects.c), [2980](objects.c), [display.c:1041](display.c) | P2v2+P2v3 | ExplosionSound $7231, Xp7a $723F, Xp8f $725D, Xp8a $7263 | ~1.1 s | big two-voice noise burst with downward sweep and long rumble decay |
| $7F | ThrustSound | ship thrusting — **re-triggered every other frame while held** | move_ship [objects.c:2105](objects.c), [2431](objects.c) | P2v0 | Th5f $7269 + Th5a $726F | 28 ms/trigger (continuous while held) | low poly-4 rumble (AUDF 2, dist 8 vol 4) |
| $8F | FusePlyr0 | fuse crackle, player 1 (burning rod) — re-triggered randomly (1-in-8 per frame) by `random_fuzz()` | [display.c:1034](display.c) via random_fuzz | P1v0 | FuseSound $721B + F01a $7229 | ~0.2 s bursts | sputtering crackle; explicitly killed by `stop_fuse_sound()` |
| $9F | FusePlyr1 | fuse crackle, player 2 | same path | P1v3 | shared with $8F | same | same |
| $AF | Gates | high-score tune (game over with a new high score; plays in attract) | [mainline.c:298](mainline.c) | P1v0 | Gk1f $7275 + Gk1a $727F | ~2.1 s | 8-note fanfare (¼ s/note, full volume) over a slow AUDF sweep |
| $BF | Sh0sn | player 1 shield up — **re-triggered every frame while held** | process_shields [objects.c:3011](objects.c) | P1v0 | ShieldSound $71D5 + S01a $71DB | 0.12 s/trigger (continuous) | force-field warble: fixed AUDF $B0, volume ramps 0→F every retrigger |
| $CF | Sh1sn | player 2 shield up | [objects.c:3009](objects.c) | P1v3 | shared with $BF | same | same |
| $DF | Popsn | rock vaporized with no free slot to split into ("pop" instead of split) | explode path [objects.c:2962](objects.c) | P1v1 | Pp2f $72A1 + Pp2a $72AB | ~40 ms | tiny pop/blip |

**No script loops.** The engine supports a restart pointer (terminator with
a nonzero value byte) but every shipped script ends `$00,$00` — verified
against the full table region $71A0-$72B8. Continuous sounds (thrust,
shield, fuse) are short one-shots that the game re-triggers.

## Sounds that bypass the script engine

- **Force-field hum** — `force_field_up()` (sound.c, $73D4), called once
  per frame from the mainline. While `COMTIMER != 0` it drives POKEY2
  voice 1 directly: tone $A3, divider `SFREQ` stepping down (pitch rising)
  to a ceiling every 8th frame; echoed on POKEY1 voice 2. When COMTIMER
  hits 0 it silences those registers. Not a trigger — level-driven.
- **`stop_fuse_sound()`** ($6B57) — kills the fuse scripts on P1v0/P1v3
  and silences AUDC1/AUDC4 directly. Fired when the rod burn ends
  ([display.c:1039](display.c), [mainline.c:754](mainline.c)).
- **`inisou()`** ($73A8) — global silence (game start/end, self-test
  entry): SKCTL reset, all registers cleared, channels 0-7's scripts
  killed. ROM quirk: channels 8-15 (thrust/explosion) scripts survive.
- The coin "EM counter" pulses in coins.c drive the cabinet's mechanical
  counter, not audio.

## Voice sharing / cut-off rules (matter for sample behavior)

A new trigger **overwrites** the script pointers of the channels it seeds,
cutting whatever those channels were playing:

- P1v0 is shared by: P1 fire, P1 respawn, P1 shield, fuse-P1, and the
  high-score tune. E.g. firing while shielding steals the voice.
- P1v3: the same set for player 2.
- P1v1: saucer fire and pop.
- P1v2: extra-life jingle; also the force-field echo writes here whenever
  channel 4 is not scripted.
- P2v0 thrust, P2v2+P2v3 explosion, P2v1 force-field hum: uncontended.

A faithful sample player would mimic "new sound on a voice cuts the old
one"; letting samples overlap instead is a legitimate aesthetic choice —
except fire-vs-shield on the same player, where the cut is audible in the
original.

## The sample hooks

The script engine and every POKEY write are untouched (RAM cells $56-$96
are oracle-diffed; attract parity re-verified 33/34 after the change).
Four passive one-line hooks in `sound.c` feed a policy module:

- `badhab()` → `sd_sample_trigger(code)` — every accepted sound start,
  already behind the attract gate.
- `stop_fuse_sound()` → `sd_sample_fuse_stop()`.
- `inisou()` → `sd_sample_stop_all()`.
- `force_field_up()` → `sd_sample_hum(COMTIMER != 0, SFREQ)` per frame.

`samples.c`/`samples.h` (core policy, no g.ram access) map triggers to
mixer channels that mirror the hardware voices (so voice stealing behaves
like the ROM), run the held-loop timeouts (`sd_sample_frame()`, called
once per displayed frame from app_loop.c), and drive the hum's pitch.
The platform seam grew `plat_sample_freq(channel, ratio)`; the Windows
backend resolves wav files lazily and plays them through the XAudio2
mixer. Headless/probe builds get no-op stubs — byte parity is unaffected.

### Dropping in wav files

Put files in `samples\` next to `sd_win.exe` (loose `.wav`, or the same
names inside `samples\spacduel.zip`). 8/16-bit PCM, mono or stereo, any
rate. Missing files are silent; each is probed once per run (see
`sd_win.log`). Names (1/2 = player 1/2; a missing `*2` file falls back to
the `*1` file):

| file | sound | authoring notes |
|---|---|---|
| `saucerfire.wav` | saucer shot | one-shot, ~0.5 s |
| `fire1.wav` / `fire2.wav` | ship fire | one-shot, ~0.26 s |
| `respawn1.wav` / `respawn2.wav` | ship materialize | one-shot, ~1.7 s |
| `extralife.wav` | bonus-life jingle | one-shot, ~1.8 s |
| `explosion.wav` | every explosion | one-shot, ~1.1 s |
| `thrust.wav` | thrust | **seamless loop**; stops ~0.1 s after release |
| `fuse1.wav` / `fuse2.wav` | fuse crackle | **seamless loop**; stopped by the game |
| `hightune.wav` | high-score tune | one-shot, ~2.1 s |
| `shield1.wav` / `shield2.wav` | shield up | **seamless loop**; stops ~0.1 s after release |
| `pop.wav` | rock pop | one-shot, ~40 ms |
| `forcefield.wav` | challenge-stage hum | **seamless loop**; record at the END-of-challenge (highest) pitch — playback starts 5.2× down-shifted and rises to native as SFREQ walks $FF→$30 |

**The POKEY synth.** `app_loop.c` drives two real POKEY models
(`c012294.c`, the cycle-stepped core shared with AAE and the Atari 800
project) with every register write the engine above makes; the chips
generate audio from their own counters as machine time advances, and each
IRQ tick's worth is drained and streamed to the window (`plat_audio_*`,
`mixer.c`'s XAudio2 stream voice, primed three blocks deep). The samples
and the synth coexist: `[sound] pokey_volume` (percent, 0 = synth off)
and `[sound] samples` (0 = wavs muted) in `sd_win.ini` pick either or
both — the trigger stream and the register stream are independent seams,
as planned. Diagnostics: `[sound] pokey_skip=0` forces the cores through
their one-clock path, and `sd_win.log` carries per-second stream health
(starved pushes, flushes, queue depth). See `tests/SHIELD_INVESTIGATION.md`
for the shield sound's three poly-4 interleavings.
