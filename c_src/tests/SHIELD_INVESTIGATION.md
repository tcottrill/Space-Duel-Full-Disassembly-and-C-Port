# Shield audio comparison (2026-09-11)

The reported symptom is a shield oscillation several times too fast in AAE
and this port with c012294, while this port's pokey.c sounds correct against
a real PCB. No recorded WAV samples are involved, per the user.

## Before the fix

Run `tests\build_shield.bat` for the isolated real sound-script test, or
`tests\build_shield_app.bat` for the real app loop with the headless backend.
Both build old and new cores with their matching headers and `/O2`, then
compare the raw mono signed 16-bit, 44100 Hz PCM using `fc /b`. These are
comparison diagnostics, not tests requiring the two cores to match after fixes.

* Isolated: retrigger each player's shield every four IRQ ticks for 500 ticks.
  Both players, both cores: 89,600 samples, FNV-style sample hash `8692EA41`.
  Both core outputs match byte for byte; output is nonzero.
* Full loop: boot, 120 attract frames, coin, select, start, then hold shield
  for 180 frames. Both runs end at 454 frames and 2,208 IRQs, game flag `$80`.
  Captured PCM SHA256 for both:
  `BF96469BEECDA44A5AA3C29509495986342B9E4305EECBD60C348E623261F988`.

The user listened to the full-loop WAV and identified the fast oscillation.
The bug is thus present in the captured samples, independent of playback or
optimization, and shared by both current legacy renderers. This does not
resolve which previously used old-core binary sounded correct.

## Confirmed review findings

* `build_all.bat` still builds `probe_pokey.c` with `pokey.c`. Its passing
  results do not establish correctness of c012294. Do not simply link the
  existing probe with c012294: the probe must also use its matching header,
  and some hardware-timing expectations intentionally differ.
* The app self-test checks sample rate, frame count, and a nonzero peak;
  it does not assert shield waveform or modulation rate.
* `c012294` walks every machine clock through `advance_clock`, including
  timers, IRQ pipeline, serial, pot and pin state. `pokey.c` aggregates
  advances and jumps the RANDOM chain with GF(2) matrices. The replacement
  is therefore substantially more expensive independently of audio pitch.
  One optimized isolated run measured about 0.18 s versus 0.03 s (6.35x);
  these short wall-clock measurements are indicative, not a stable benchmark.
* The active legacy renderer, polynomial tables and channel-period formulas
  are equivalent on the tested shield path. Cycle audio is not enabled here.

## Confirmed mute-phase defect; incomplete sound fix

`update_render_channel()` treated zero volume as a reason to freeze a channel's
divider and seed its output latch. The shield script repeatedly starts AUDC at
`$C0` before increasing volume. Freezing/restarting the oscillator at each
retrigger changes the audible modulation. Zero volume must mute the DAC without
stopping the oscillator. MAME's `step_one_clock()` / `process_channel()` continue
clocking channel outputs irrespective of volume:
https://github.com/mamedev/mame/blob/master/src/devices/sound/pokey.cpp

Removed only the zero-volume freeze condition in `c012294.c`. RANDOM, timers,
clock rates, and the cycle-audio path are unchanged. The current `pokey.c` remains
as the comparison baseline. The user initially accepted `obj\shield_fixed.wav`,
then clarified that it is improved but still has one or two audible hitches;
the held shield should sound like a steady, smooth sine. This is NOT a complete
fix or a confirmed match to the PCB. The original 500-tick isolated sample hash
is `3AAD8AF1`, versus `8692EA41` before the mute-phase patch.

`tests\build_mute_phase.bat` runs a new regression: an otherwise identical
oscillator must produce identical samples after a silent interval followed by
unmuting. It failed before the fix and passes afterward. It also builds the
existing tone, silence, polynomial period, and SKCTL audio-reset checks with
the replacement's matching header; these pass with zero failures.

The Windows game was rebuilt with the mute-phase patch and original compiler flags.
The full headless self-test (900 attract frames followed by its scripted checks)
passed with zero failures. It generated 1,612,083 audio frames across 8,996 IRQs,
within 0.20 frames of the expected total.

The temporary `/O2` change to the game build script was reverted. Optimization
was not the root cause. The replacement's performance cost is a separate issue.
The AAE source copy was read and confirmed byte-identical to the original
replacement but was not edited. The requested AAE edit was canceled; do not
treat that copy as patched or the overall sound issue as resolved.

## Gameplay integration correction

The isolated harness now runs for 1,500 ticks (268,800 samples, about six seconds).
With the replacement build, an optional fourth argument beginning with `c`
enables its existing cycle-audio path for comparison:

    tests\shield_new.exe obj\shield_cycle_comparison.pcm 0 cycle

Current legacy hash: `FC525559`; cycle-audio hash: `31D84E9B`.
Both use the same register script. WAVs for listening are `obj\shield_new.wav`
and `obj\shield_cycle_comparison.wav`. The user ultimately identified the
cycle-based capture as correct, but heard stuttering/restarts in gameplay.
The isolated recordings did not reproduce those gameplay interruptions.

The game had still been using the legacy renderer. It now enables cycle audio
for both chips. Audio is generated by advance() before new IRQ register writes
and consumed with audio_read(), using the same counters as the hardware model.
The shield script and its intentional retriggers are unchanged.

Two host timing changes are required for this integration:

* The sample clock follows fps_lock: 1,512,000 Hz natively, 1,474,560 Hz at
  60 fps. Integer sample fractions use that same denominator. The former
  host demanded 183.75 samples/IRQ at 60 fps while an unscaled cycle core
  could only produce 179.2, which would repeatedly underrun if just enabled.
* The 64-cycle RANDOM-read costs are deducted from the next 6,144-cycle IRQ
  budget. Previously they were added on top, harmless to a separate renderer
  but a source of extra samples/drift in cycle audio. The RANDOM chain itself
  is unchanged, but absolute read timing and resulting game randomness can
  change because this removes the host's double-counted time.

Fast-boot audio is drained and discarded, with a clean sample boundary before
live playback. The extra eight-block startup priming/re-priming was removed
at the user's request; the Windows mixer is back to its original immediate
startup behavior. The user reported stuttering gone before this removal, so
the no-extra-buffering build still needs a live listening check. The game and
self-test builds use /O2 to keep the cycle renderer within the real-time budget;
optimization is not being presented as the original chip sound defect.

## What the shield sound actually is (2026-09-12)

AUDC $C0 samples the poly-4 sequence at each channel-0 borrow. With AUDF $B0
the borrow period is 4956 clocks, which is 6 mod 15, so the sampled pattern is
one high borrow in five (24780 clocks, 61.02 Hz). The script's C0/C2/C4/C6
staircase runs once per frame (24576 clocks, 61.52 Hz). The pulse slides
through the staircase once every ~121 frames: that is the slow 2 s swell, and
it depends on sub-millisecond phase. Anything that drops, delays or re-orders
a few milliseconds of audio in the host is heard as a hitch or a restart.

## Live-host evidence (2026-09-12)

The full-loop headless capture (c012294, cycle audio, real game loop, shield
held 360 frames) has the swell with its expected hard steps and no hitches;
the register log shows only AUDF1 $B0 and AUDC1 C0/C2/C4/C6 on POKEY1 voice 0
and nothing touching AUDCTL, STIMER or SKCTL during play. The user confirmed
that capture sounds right. So the remaining difference was the real-time host.

`mixer.c` now counts, per second, pushes that found the XAudio2 voice drained
("starved"), forced flushes, and the queue depth, and `app_loop.c`'s status
line adds the core queue depth/underrun/overrun; both go to `sd_win.log`. A
live session showed depth 1..3 blocks and one starvation at a single 33 ms
frame hitch; the voice holds only ~4-12 ms, so any host hiccup longer than
that is a gap, and one longer than 60 ms flushes the backlog and restarts the
sound. That is the stutter, and why the earlier 8-block priming hid it.
`stream_push` now primes 3 blocks (~12 ms) at voice start and after a flush.

The other lever was cost: the pokey.c self-test ran 36.5 s of machine time in
0.79 s, the one-clock c012294 needed 8.19 s. `ad_pokey_advance` now takes runs
of quiet clocks (no borrow, no reload/IRQ/two-tone/high-pass deadline, pot
counter idle, serial unclocked) in one step; only event clocks walk the full
one-clock path. `tests\build_c012294_ab.bat` hashes samples, register reads
and every host callback across twelve scenarios (both audio modes, all AUDCTL
modes, init in/out, two-tone/async/serial/external clock, pots, keyboard,
reset) against a saved golden copy and runs the two-chip cost benchmark: all
twelve hashes identical, 10.9% -> 1.9% CPU, self-test 8.19 s -> 2.53 s, the
three full-loop captures byte-identical to the pre-change ones.

## The run-to-run difference: three poly-4 interleavings (2026-09-12)

Two live captures (`[sound] capture=1` writes the pushed stream to
`sd_live.pcm`; `pokey_skip=0/1` selects the one-clock or quiet-clock path)
both had a clean stream (no starvation, no flush) and both had the divider
borrowing every 4956 clocks (142.3 samples), yet the sampled poly-4 bits
differed: one run 0,0,0,0,1 per five borrows (the approved sound), the other
1,1,0,1,0. 4956 is a multiple of 3 and the poly-4 period is 15, so the
divider only ever sees one of three interleavings of the sequence
000011101100101 (Altirra HRM 5.5): {0,0,0,1,0}, {0,1,1,0,1}, {0,1,1,1,0}.
Which one is locked in by the phase between the poly counter (zeroed at
init release) and the first $B0 borrow, i.e. by the machine time between
the game's SKCTL release in Inisou and the IRQ of the first shield trigger,
at 28-clock (64 kHz pulse) granularity. In the port that time includes the
64-cycle RANDOM-read charges before Inisou and the player's press timing
(6144 mod 28 = 12, so the IRQ count matters mod 7), hence a different class
on different runs. HRM 5.3 "Noise sampling artifacts" describes this
mechanism for the hardware (channel period sharing a factor with the noise
period), and every fire sound period ((37+3n)*28 clocks, 1 mod 3) shifts the
class again after a voice steal. The quiet-clock path is not involved: the
skip=0 and skip=1 captures differed only in this class.

`tests\build_shield_class.bat` builds `probe_shield_class.c`, which runs the
real loop headless and prints the class the shield locks into for a given
attract length, press frame and number of shots before the press. Sweeping
those shows the class flipping with each of them, about half the runs
landing in the one-pulse class - the "correct most of the time" the user
hears. Every sound that precedes the shield on that voice leaves a period of
1 or 2 mod 3 pulses (fire 226, respawn 11, fuse 1, tune 248), so nothing in
the game's own register stream pins the phase either.

Decision (2026-09-12): the user reports the PCB always plays the same shield
texture regardless of when it is triggered. The Altirra reference (5.3,
"Noise sampling artifacts") describes the timbre as phase-dependent and
"tend[ing] to change whenever a sound is played", and MAME's core behaves the
same way, so no mechanism that would pin it on the board is known here. A
core-level phase lock was proposed and declined as a one-game change; the
core stays faithful to the reference. If the board can be checked: fire a
shot, then hold the shield, several times in one game - under the documented
behaviour each shot reshuffles the shield texture. The faster core was copied
to the AAE tree's sndhrdwr on 2026-09-12 after passing that tree's POKEY
conformance suite.

The updated full-loop regression failed before the renderer switch. It passes
at native and 60 fps after integration: over 360 held-shield frames it receives
exactly 258,048 / 264,600 samples respectively, with zero core audio underruns,
overruns or accumulated clock drift. The full 900-frame self-test also passes.
The Windows device's actual gameplay playback still needs the user's listening
check; headless tests cannot establish its subjective sound or device scheduling.
