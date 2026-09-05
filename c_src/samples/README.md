# Space Duel sample set

No wavs are included; the two POKEYs synthesise every sound, and any wav
dropped here plays on top.

Drop wav files here (or the same names inside `spacduel.zip` in this
directory) and `sd_win.exe` plays them over the synthesized output
(`[sound] samples=0` in `sd_win.ini` mutes the wavs,
`[sound] pokey_volume=0` mutes the synth).
8- or 16-bit PCM, mono or stereo, any sample rate. A missing file is
simply silent. Full catalogue and authoring notes: `../SOUNDS.md`.

    saucerfire.wav   saucer shot
    fire1.wav        player 1 fire        (fire2.wav for player 2)
    respawn1.wav     ship materialize     (respawn2.wav)
    extralife.wav    bonus-life jingle
    explosion.wav    every explosion
    thrust.wav       thrust               seamless loop
    fuse1.wav        fuse crackle         seamless loop (fuse2.wav)
    hightune.wav     high-score tune
    shield1.wav      shield up            seamless loop (shield2.wav)
    pop.wav          rock pop
    forcefield.wav   challenge-stage hum  seamless loop; record at the
                     end-of-challenge (highest) pitch - the game shifts
                     it down 5.2x at challenge start and sweeps it up

A `*2.wav` that is absent falls back to its `*1.wav`, so one recording
per sound is enough.
