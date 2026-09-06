;Space Duel (Atari, 1982) - hardware map and RAM variables.
;Names in the 'Hardware' sections are descriptive; the RAM variable names
;below are Atari's own identifiers, recovered from the .BLKB declarations
;in ASTRD2.MAC and the equates in AS2DEC.MAC (Atari's source archive).
;Note DEC MACRO-65 symbols are significant to 6 characters only, so a few
;arrive truncated: CMSBSE is CMSBSET, PL0ARE is PL0AREA.
;
;Descriptions come from Atari's own comments on those declarations, plus
;the sound channel arrays in AS2POK.MAC and the coin variables shared with
;COIN65.MAC; see var_docs.py, which is where they are edited.
;
;An address is named after whichever symbol resolves to it, and Atari's
;sources define constants whose value happens to equal a low RAM address.
;Where such a constant outranks the variable that really lives there, the
;comment opens with the cell's true identity, as in 'VGLIST+1 - ...'.

;----------------------------------[ Memory map ]----------------------------------
.alias ZeroPageRam      $0000    ;Through $00FF.
.alias StackRam         $0100    ;Through $01FF. The stack lives here.
.alias GameRam          $0200    ;Through $03FF. 1K of MCU RAM in total.
.alias VectorRam        $2000    ;Through $27FF. 2K of vector RAM.
.alias VectorRom        $2800    ;Through $3FFF. 6K of vector ROM.
.alias ProgramRom       $4000    ;Through $8FFF, mirrored to $FFFF.

;----------------------------------[ Inputs ]----------------------------------
.alias In0              $0800    ;d7 3kHz clock, d6 VG HALT, d5 diag step,
.alias SelfTestSw       $0800    ;  d4 self-test (0=on), d3 slam, d2-d0 coins.
.alias VgHalt           $0800    ;d6 = 1 when the AVG has finished its list.
.alias ThreeKhz         $0800    ;d7 = 3kHz frame timebase.
.alias In1              $0900    ;Through $0907. Controls, one switch per address.
.alias EaromRead        $0A00    ;EAROM data read.

;----------------------------------[ Outputs ]----------------------------------
.alias CoinCtrLamps     $0C00    ;Coin counters, start lamps, cabinet flip.
.alias VgGo             $0C80    ;Write starts the AVG on the display list.
.alias WdClear          $0D00    ;Write kicks the watchdog.
.alias VgReset          $0D80    ;Write holds the AVG in reset.
.alias IrqAck           $0E00    ;Write acknowledges the IRQ.
.alias EaromControl     $0E80    ;EAROM control latch.
.alias EaromWrite       $0F00    ;Through $0F3F. EAROM write.
.alias Pokey1           $1000    ;POKEY 1 - sound and pot inputs.
.alias Pokey2           $1400    ;POKEY 2 - sound and option switches.

;----------------------------------[ Zero page variables ]----------------------------------
.alias VGBRIT           $00      ;Vector brightness used by VGSTAT: 0 = off, $F0 = maximum, in steps of $20.
.alias VGLIST           $01      ;AVG display-list write pointer, 2 bytes; Add2WordsToVector stores through it with STA (VGLIST),Y.
.alias EAC2             $02      ;VGLIST+1, the high byte of the display-list write pointer. EAC2 is AS2DEC's EAROM C2 control bit.
.alias XCOMP            $03      ;X component scratch for the vector builders, 4 bytes ($03-$06).
.alias RED              $04      ;XCOMP+1. RED is the colour constant 4.
.alias CHAN3V           $05      ;XCOMP+2. CHAN3V is the POKEY channel 3 volume register offset.
.alias TWOPI            $06      ;XCOMP+3. TWOPI is the angle-table constant 6.
.alias TEMP1            $07      ;General scratch, 3 bytes ($07-$09); the self-test uses all three. TEMP1C is TEMP1+2.
.alias EACE             $08      ;TEMP1+1. EACE is the EAROM chip-enable bit, 8.
.alias TEMP2            $0A      ;General scratch, 2 bytes ($0A-$0B).
.alias POTGO            $0B      ;TEMP2+1. POTGO is the POKEY pot-scan register offset $0B.
.alias TEMP3            $0C      ;General scratch, 4 bytes ($0C-$0F); by convention TEMP3 holds X and TEMP3+1 holds Y. TEMP3C is +2, TEMP3D is +3.
.alias FOURPI           $0D      ;TEMP3+1. FOURPI is the angle-table constant 13 decimal.
.alias SKCTL            $0F      ;TEMP3+3. SKCTL is the POKEY serial-control register offset $0F.
.alias TEMP4            $10      ;General scratch, 3 bytes ($10-$12).
.alias NMROCK           $11      ;TEMP4+1. NMROCKS is the asteroid slot count, 17 decimal.
.alias TEMP5            $13      ;General scratch byte.
.alias TEMP6            $14      ;General scratch byte.
.alias TEMP7            $15      ;General scratch byte.
.alias TEMP7B           $16      ;General scratch byte, paired with TEMP7.
.alias TEMP8            $17      ;General scratch byte.
.alias TEMP9            $18      ;General scratch byte.
.alias TEMP10           $19      ;General scratch byte.
.alias TEMP11           $1A      ;General scratch byte.
.alias TEMP12           $1B      ;General scratch byte.
.alias TEMPA            $1C      ;General scratch byte.
.alias TEMPB            $1D      ;General scratch byte.
.alias TEMPC            $1E      ;General scratch byte.
.alias ZSAUCE           $1F      ;$TCMFLG, the two-coin-minimum flag (COIN65.MAC). ZSAUCER is the saucer's index in the object arrays.
.alias DIAGBI           $20      ;$$CRDT, the credit total (COIN65.MAC). DIAGBIT is the diagnostic-step bit $20 in In0.
.alias ZSHIP            $21      ;$INTCT, the coin routine's interrupt counter. ZSHIP is the first ship's object index.
.alias ZPAIR            $23      ;$BC, bonus coins earned. ZPAIR is the bound pair's object index.
.alias ZMINE            $24      ;$CMODE, the coin mode. ZMINES is the first mine's object index.
.alias ROTENG           $28      ;$CCTIM+1, the coin-counter timers (3 bytes from $27). ROTENG is the rotational-energy constant, 40 decimal.
.alias ZP1MIN           $2C      ;$PSTSL+2, the post-coin slam timers (3 bytes from $2A). ZP1MINES is player 1's first torpedo index.
.alias ZLAST            $2F      ;$CNSTT+2, the coin status and timers (3 bytes from $2D). ZLAST is the last object index.
.alias LANGBT           $30      ;$USE, positive while the coin routine is running. LANGBTS is the language bit mask $30 in OPTN1.
.alias INTRPT           $32      ;Coin-routine scratch. Beware: elsewhere the ROM reads INTRPT,X purely as SCORE+1,X - see NOTES_score.md.
.alias SYNC             $33      ;Coin-routine scratch. Beware: elsewhere the ROM reads SYNC,X purely as SCORE+2,X.
.alias GAME             $34      ;Selected game variation, 0-3 internally, one less than the number shown on screen. MAXGAME is 3, ALONEGAME 1 (one ship), TWINGAME 3 (space station, one player drives both).
.alias ATRACT           $35      ;Positive while a game is running, zero in attract mode. Also SAVTOP: RAM from here up need not survive between games.
.alias UPDINT           $36      ;Which initial, 0 1 or 2, is being selected; 2 bytes, one per player.
.alias UPDFLG           $38      ;Positive when this player has set a new high score; 2 bytes, one per player.
.alias SCORE            $3A      ;Player scores in BCD, 3 bytes each (low, middle, high) for players 0 and 1, so $3A-$3F.
.alias MAXSPE           $3F      ;SCORE+5, the high byte of player 1's score. MAXSPEED is the velocity clamp $3F.
.alias CMBSCORE         $40      ;Combined score for the cooperative games, 3 bytes BCD; the score block $3A-$42 is staged as a unit before UpdateHighScoreTable.
.alias GENDING          $43      ;Delay before the game ends when non-zero, counting up towards zero. IGENDING ($40) is the initial value.
.alias FRAME            $44      ;Free-running frame counter, 3 bytes.
.alias HITS             $47      ;Lives remaining, one byte per player; zero in attract mode.
.alias LASTSW           $49      ;Last control-switch reading, one byte per ship.
.alias XINCL            $4B      ;Low byte of each ship's X velocity, one per ship; the high byte is XINC+ZSHIP.
.alias YINCL            $4D      ;Low byte of each ship's Y velocity, one per ship.
.alias TOGGLE           $4F      ;Per-ship toggle flags; D7 (SHLDON, $80) means the shield is up.
.alias TOGDRONE         $51      ;D7 set when the second ship is a computer-flown drone.
.alias TOGCOMB          $52      ;D7 set when the two players draw on one shared pool of lives.
.alias SCRFUL           $53      ;D7 set when the screen already holds the maximum number of objects.
.alias KLMOFF           $54      ;D7 = killer mines are to leave the screen, D6 = comets are to leave.
.alias TSTBYTE          $55      ;Guard byte, there to catch ENMOFF being clobbered from above.
.alias POINT            $56      ;Sound engine: per-channel offset into the sound data tables, 16 channels; 0 means the channel is idle.
.alias MXSPKT           $60      ;POINT+10, sound channel 10's table pointer. MXSPKTIME is the spark-timer maximum $60.
.alias CURRENT          $66      ;Sound engine: the value currently being output on each of the 16 channels.
.alias COUNT            $76      ;Sound engine: changes remaining in the current step, 16 channels.
.alias COCKBI           $80      ;COUNT+10. COCKBIT is the cocktail-cabinet bit $80 read at CABERE ($0907).
.alias FRAMES           $86      ;Sound engine: frames until this channel's next change, 16 channels.
.alias SINDEX           $96      ;Sound engine: index of the channel INISOU and MODSND are currently servicing.
.alias OBJ              $97      ;Object table, 17 asteroid and explosion slots. 0 = slot free; otherwise bits 0-2 give the size (1 small, 2 medium, 4 large) and bits 3-6 the picture number.
.alias OBCOMETS         $A8      ;Object table continues: 8 comet and dwarf slots.
.alias OBKLMINES        $B0      ;Object table: 6 killer-mine slots.
.alias OBSAUCER         $B6      ;Object table: 2 saucer slots.
.alias OBSHIP           $B8      ;Object table: 2 player-ship slots; SHPALIVE (2) marks a live ship.
.alias OBPAIR           $BA      ;Object table: the single bound-pair slot, the rotating bar of the space-station games.
.alias OBMINES          $BB      ;Object table: shots start here, with 4 computer mines (OBCOMINES names the same cell).
.alias OBP0MINES        $BF      ;Object table: player 0's 4 torpedoes.
.alias OBP1MINES        $C3      ;Object table: player 1's 4 torpedoes.
.alias EASRCE           $C7      ;EAROM transfer source pointer, 2 bytes.
.alias KLMINC           $C9      ;Killer-mine colour, which is the number of shots absorbed so far minus one; 6 mines.
.alias DIFCTY           $CF      ;Difficulty value governing how soon saucers start.
.alias OPTN1            $D0      ;Option switches read from POKEY 1: D7-D6 bonus level, D5-D4 language, D3-D2 difficulty, D1-D0 lives.
.alias LANG             $D1      ;Selected language, taken from OPTN1 bits D5-D4.
.alias DIFF             $D2      ;Difficulty level, taken from the option switches.
.alias SAUMIN           $D3      ;Minimum velocity of each saucer, one byte per saucer. Note $D3-$D5 are also read as HSCORE-3 by the high-score shift-down.
.alias ROCKMIN          $D5      ;Minimum rock velocity, 2 bytes (plus and minus).
.alias ROCKMAX          $D7      ;Maximum rock velocity, 2 bytes. SAVZTOP, the end of the must-be-preserved block, follows at $D9.
.alias NXTBON           $D9      ;Score at which the next bonus life falls due, 2 bytes. Also SAVZTOP.
.alias BONLVA           $DB      ;Bonus level amount: the score step between bonus lives.
.alias ATSTG            $DC      ;Attract-mode stage flag.
.alias HSCORE           $DD      ;High score table: 3 BCD bytes x 5 entries x 4 game variants, 60 bytes ($DD-$118).
.alias BGSHEN           $F0      ;HSCORE+$13. BGSHENG is the full-shield energy value $F0.

;----------------------------------[ Stack page ]----------------------------------
.alias INITL            $0119    ;Initials for the high score table: 3 characters x 5 entries x 4 variants, 60 bytes ($119-$154).
.alias SPINT            $0155    ;Extra initials for the two-player space-station game, 3 x 5 = 15 bytes.
.alias EABUF            $0164    ;EAROM read and write staging buffer, 32 bytes ($164-$183).
.alias EAZFLG           $0184    ;Non-zero asks the EAROM handler to zero the whole device.
.alias EAREQU           $0185    ;EAROM access request bitmap, one bit per batch of data: D0 is batch 0 through D7 batch 7; a set bit requests that batch.
.alias EARWRQ           $0186    ;Access type for each bit of EAREQU: 0 = read, 1 = write.
.alias EABAD            $0187    ;Per-batch outcome, matching EAREQU bit for bit: 0 = success, 1 = failure.
.alias EAFLG            $0188    ;Control byte for one EAROM operation: D7 erase, D6 write, D5 read, D4 zero the device when D6 is also set.
.alias EABC             $0189    ;Byte index into the buffer addressed by EASRCE.
.alias EAX              $018A    ;Byte offset within the EAROM for the next access.
.alias EACNT            $018B    ;Byte offset within the EAROM for the last access.
.alias EASEL            $018C    ;Index code identifying the batch operation in progress.
.alias EACS             $018D    ;Running checksum over the batch.
.alias ONTIME           $018E    ;Bookkeeping: total time the cabinet has been powered on, 4 bytes.
.alias BONTIME          $0192    ;Bookkeeping: bonus time, 4 bytes; reused as scratch during EAROM transfers.
.alias PLAYTIME         $0196    ;Bookkeeping: play time, 4 bytes for each of the 4 one- and two-player variants.
.alias GAMES1           $01A6    ;Bookkeeping: games played, 3 bytes for each of the 4 variants.
.alias THRENG           $01E0    ;not a variable at all: THRENG is the constant $F0*2, the thrust energy of the rotating pair. Its value lands inside the 6502 stack.

;----------------------------------[ Game RAM ]----------------------------------
.alias XINC             $0200    ;X velocity of every object, 50 entries, Atari's S8999.BBB format (signed, 3 fractional bits).
.alias YINC             $0232    ;Y velocity of every object, 50 entries, S9999.BBB format.
.alias NROCKS           $0264    ;Number of rocks currently on screen.
.alias ENMDEL           $0265    ;Frames until this ship becomes a target again, one per ship.
.alias EDELAY           $0267    ;Delay before an enemy enters or fires, one per saucer.
.alias SENMDEL          $0269    ;Starting value loaded into ENMDEL, one per ship.
.alias RTIMER           $026B    ;Rock timer: at 0 a saucer is sent in regardless of how many rocks remain. One per ship.
.alias SDELAY           $026D    ;Delay before this ship is put back; $80 means the ship was just destroyed. One per ship.
.alias ETIMER           $026F    ;Counts down to 0, at which point the saucer may return. One per saucer.
.alias RDELAY           $0271    ;Delay before more rocks are added.
.alias THUMP3           $0272    ;Starting value for the THUMP2 heartbeat-sound counter.
.alias SHLDENG          $0273    ;Shield energy remaining, upper byte, one per ship; BGSHENG ($F0) is a full charge.
.alias LSHLDENG         $0275    ;Shield energy remaining, lower byte; MINSHENG ($18) is the minimum useful upper byte.
.alias CSPEED           $0277    ;Comet speed, 8 comets.
.alias KSPEED           $027F    ;Killer-mine speed, 6 mines.
.alias CANGCH           $0285    ;Per-frame change in comet heading, low byte, 8 comets.
.alias KANGCH           $028D    ;Per-frame change in killer-mine heading, low byte, 6 mines.
.alias CANGLH           $0293    ;Comet heading, high byte, 8 comets.
.alias KANGLH           $029B    ;Killer-mine heading, high byte, 6 mines.
.alias ANGLE            $02A1    ;Saucer rotation angle, 2 saucers.
.alias SANGLE           $02A3    ;Ship orientation angle, 2 ships.
.alias CANGLL           $02A5    ;Comet heading, low byte, 8 comets.
.alias KANGLL           $02AD    ;Killer-mine heading, low byte, 6 mines.
.alias BANGLE           $02B3    ;Rotating bar angle, high byte.
.alias BANGLL           $02B4    ;Rotating bar angle, low byte.
.alias OBJXH            $02B5    ;X position of every object, high byte, 50 entries.
.alias OBJYH            $02E7    ;Y position of every object, high byte, 50 entries.
.alias ISNSP2           $0319    ;Initial speed for the second sound circuit. Declared but never referenced by the shipped ROM.
.alias SNDBA2           $031A    ;Base value for the second sound circuit. Declared but never referenced by the shipped ROM.
.alias SNDSP2           $031B    ;Speed for the second sound circuit. Declared but never referenced by the shipped ROM.
.alias SPARKANGLE       $031C    ;Angle of each of the 4 spark rays arcing between the paired ships.
.alias OBJXL            $0320    ;X position of every object, low byte, 50 entries, 99999.BBB format.
.alias OBJYL            $0352    ;Y position of every object, low byte, 50 entries.
.alias UWBAR            $0384    ;Bar rotation speed, upper byte.
.alias LWBAR            $0385    ;Bar rotation speed, lower byte.
.alias BXINCL           $0386    ;Bar centre-of-mass X velocity, low byte; the high byte is BXINC, which is XINC+ZPAIR.
.alias BYINCL           $0387    ;Bar centre-of-mass Y velocity, low byte; the high byte is BYINC, which is YINC+ZPAIR.
.alias PRTDAMAGE        $0388    ;Partial damage taken when non-zero; MXPTDAMAGE ($80) is the maximum, counting negative. One per ship.
.alias COLLIS           $038A    ;Last object this ship collided with; COLBIT ($80) is shifted in each frame. One per ship.
.alias STRADDLE         $038C    ;D7 set when the object straddles the X wrap, D6 when it straddles Y.
.alias COMOFF           $038D    ;-1 while the comets are being sent off screen.
.alias OWNER            $038E    ;Who is credited for the current hit: 0 or 1, negative for nobody.
.alias COMTYP           $038F    ;Type occupying each comet slot: 0 = dwarf, $80 = comet. 8 slots.
.alias COMSTART         $0397    ;Where to start searching for a free comet slot, one per ship.
.alias PROBCOMET        $0399    ;Probability that a new object starts as a comet rather than a dwarf, one per ship.
.alias DWFRMP           $039B    ;Dwarf ramping speed, one per ship.
.alias SCSHSP           $039D    ;Saucer shooting speed; $80 means fast. One per ship.
.alias XINCROT          $039F    ;Scratch: X velocity after rotation.
.alias YINCROT          $03A0    ;Scratch: Y velocity after rotation.
.alias XPOSSAVE         $03A1    ;Scratch: saved X position.
.alias YPOSSAVE         $03A2    ;Scratch: saved Y position.
.alias SHHIGH           $03A3    ;Show the high score table when non-zero.
.alias FREXPLOSION      $03A4    ;Explosion sound request.
.alias MXRTIMER         $03A5    ;Value RTIMER is reloaded with, one per ship.
.alias NWCACH           $03A7    ;Heading change for a newly launched planet or comet, one per ship.
.alias NWCSPD           $03A9    ;Speed for a newly launched comet, one per ship.
.alias FCACH            $03AB    ;Heading change for the first comet of a wave, one per ship.
.alias FCSPD            $03AD    ;Speed for the first comet of a wave, one per ship.
.alias WAVE             $03AF    ;Wave number, used to scale bonus points.
.alias GTIME            $03B0    ;Game time accumulated from the 4 ms interrupt, 4 bytes.
.alias BCOMSTART        $03B4    ;Rolling comet-slot search cursor, incremented as comets are launched; one per ship. Atari's source leaves it uncommented.
.alias NCOMET           $03B6    ;Number of comets currently active.
.alias COMTIMER         $03B7    ;How much longer comets may stay active, for the rush at the end of a wave.
.alias COMLIMIT         $03B8    ;Ceiling on how many comets may be active at once.
.alias LNGTIMER         $03B9    ;Long timer, 2 bytes; once negative, saucers come out even with rocks on screen and shoot fast and often.
.alias WHOSHOT          $03BB    ;Who shot this ship: 0 = the opponent, $FF = the computer. One per ship.
.alias NENTCOMETS       $03BD    ;Number of comets to send in at the end of the wave.
.alias NENTDWARF        $03BE    ;Number of dwarfs to send in at the end of the wave.
.alias ETARGET          $03BF    ;Which ship each saucer is hunting; -1 means inactive. 2 saucers.
.alias CTARGET          $03C1    ;Which object each comet is hunting, 8 comets.
.alias KTARGET          $03C9    ;Which object each killer mine is hunting, 6 mines.
.alias SPARKTIME        $03CF    ;Countdown for the spark arcing between the paired ships; MXSPKTIME ($60) is the maximum and $80, being negative, means no spark.
.alias IANGLE           $03D0    ;Buffered copy of each ship's angle.
.alias LMONHITS         $03D2    ;Monsters this player has killed, low byte, one per ship.
.alias UMONHITS         $03D4    ;Monsters this player has killed, high byte, one per ship.
.alias ASTERS           $03D6    ;Rock rotation states, 8 rocks.
.alias HSCFLG           $03DE    ;Set while initials are being entered, so the sound routine can tell.
.alias RODSTATUS        $03DF    ;Positive when the connecting rod needs drawing or redrawing.
.alias SAVBOT           $03E0    ;LASTGAM, the previous game-select reading, used to debounce the select button. SAVBOT is the marker for the start of the RAM that must be preserved.
.alias PL0SCFLAG        $03E1    ;Negative when player 0's score has changed; with a V character it means the life count changed.
.alias PL1SCFLAG        $03E2    ;Negative when player 1's score has changed.
.alias CMBSCFLAG        $03E3    ;Negative when the combined score has changed.
.alias UPDOWN           $03E4    ;Negative to draw vectors and messages upside down, for the cocktail cabinet's second player.
.alias SECOND           $03E5    ;One-second tick counter.
.alias FLASHCOL         $03E6    ;Colour used for the flashing display elements.
.alias ENTER            $03E7    ;Entry-effect timers, 2 bytes.
.alias SFREQ            $03E9    ;Output frequency of the background hum.
.alias SPFLG            $03EA    ;Flag for special initials, encoded the same way as UPDFLG.
.alias FLSFLG           $03EB    ;Flash the initials just entered, 2 bytes.
.alias SAUCIX           $03ED    ;Saucer picture index, advanced modulo 4 every fourth frame by MoveSaucerPicColor.
.alias STRTLOK          $03EE    ;Start-button lockout: 0 = game in progress, $80 = no starts allowed, $40 = select was pushed and starts are allowed.
.alias EXPDEC           $03EF    ;Explosion selection, 2 bytes: negative shows the full explosion, positive shows only the flying pieces.
.alias SUPRSAC          $03F1    ;Super saucer flag; $80 means super.
.alias SUPRTIM          $03F2    ;Super saucer shot timer.
.alias SUPRDIS          $03F3    ;Super saucer distance.
.alias LASTG            $03F4    ;Last game played flag.
.alias NEXTEX           $03F5    ;Fanfare explosion counter.
.alias SPECEX           $03F6    ;Special fanfare flag.
.alias INTEN            $03F7    ;Intensity pulse byte: the top 4 bits of FRAME held in the low nibble.
.alias MODNUM           $03F8    ;Picture modulo counter; waves flagged $80 cycle it to vary the rock pictures.
.alias DIFSW            $03F9    ;Difficulty switch reading, kept for the self-test display.

;----------------------------------[ Hardware registers ]----------------------------------
.alias HALT             $0800    ;In0. D7 3 kHz clock, D6 AVG HALT, D5 diagnostic step, D4 self-test (0 = on), D3 slam, D2-D0 coin sense.
.alias HYPSW            $0900    ;D7 shield/hyperspace, D6 fire. One switch pair per address through $0907.
.alias ROTL             $0902    ;D7 rotate left, D6 rotate right.
.alias STRT1            $0904    ;D7 thrust, D6 one-player start.
.alias OPTNA1           $0905    ;D6 sell games/players option (SELLGAMES).
.alias GAMSEL           $0906    ;D7 game select, D6 two-coin-minimum option (TWOCMN).
.alias CABERE           $0907    ;D7 cabinet type (COCKBIT): 1 = cocktail, 0 = upright. AS2DEC.MAC's equate comment says the opposite, but the code settles it - $690C LDX CABERE / BMI, commented 'COCKTAIL?????' / 'YEP...NO ADITIONAL FLIP NEEDED', so minus is the cocktail. D6 caberet select.
.alias EAIN             $0A00    ;EAROM data read.
.alias OUT1             $0C00    ;Output latch: D7 Y invert, D6 X invert, D5 start lamp (0 = on), D4 select lamp, D3 coin lockout (1 = no coins), D2-D0 left/centre/right coin counters.
.alias GOADD            $0C80    ;Write restarts the AVG on the display list at $2000.
.alias WTCHDG           $0D00    ;Write kicks the watchdog.
.alias STOPAD           $0D80    ;Write holds the AVG in reset.
.alias INTACK           $0E00    ;Write acknowledges the 4 ms IRQ.
.alias EACTL            $0E80    ;EAROM control latch: D0 clock (EACK), D1 C2, D2 C1 inverted, D3 chip enable. C1,C2 = 0,0 read; 1,0 write; 1,1 erase.
.alias EADAL            $0F00    ;EAROM address and data latch, $0F00-$0F3F.
.alias POKEY            $1000    ;POKEY 1: sound channels plus the option-switch and pot inputs.
.alias POKEY2           $1400    ;POKEY 2: sound channels plus the coin-option switches.

;----------------------------------[ Vector RAM ]----------------------------------
.alias VECMEM           $2000    ;Base of the 2K vector RAM; the AVG fetches its display list from here.
.alias VROCK1           $2290    ;Rock 1: 2-byte JMPL to the chosen rock picture in vector ROM.
.alias CVR11            $2292    ;Rock 1's first COLOR instruction plus RTSL, 4 bytes, patched each frame.
.alias CVR12            $2296    ;Rock 1's second COLOR instruction plus RTSL.
.alias CVR13            $229A    ;Rock 1's third COLOR instruction plus RTSL.
.alias VROCK2           $229E    ;Rock 2: 2-byte JMPL to the chosen rock picture.
.alias CVR21            $22A0    ;Rock 2's first COLOR instruction plus RTSL.
.alias CVR22            $22A4    ;Rock 2's second COLOR instruction plus RTSL.
.alias CVR23            $22A8    ;Rock 2's third COLOR instruction plus RTSL.
.alias VROCK3           $22AC    ;Rock 3: 2-byte JMPL to the pyramid picture.
.alias PYR11            $22AE    ;Pyramid's first COLOR instruction plus RTSL.
.alias PYR12            $22B2    ;Pyramid's second COLOR instruction plus RTSL.
.alias PYR13            $22B6    ;Pyramid's third COLOR instruction plus RTSL.
.alias VROCK4           $22BA    ;Rock 4: 2-byte JMPL, originally the cube. Rocks 4 to 8 reuse the colour instructions above.
.alias VROCK5           $22BC    ;Rock 5: 2-byte JMPL to its picture.
.alias VROCK6           $22BE    ;Rock 6: 2-byte JMPL to its picture.
.alias VROCK7           $22C0    ;Rock 7: 2-byte JMPL to its picture.
.alias VROCK8           $22C2    ;Rock 8: 2-byte JMPL to its picture.
.alias SAU11            $22C4    ;Saucer's first COLOR instruction plus RTSL, 4 bytes, patched each frame.
.alias SAU12            $22C8    ;Saucer's second COLOR instruction plus RTSL.
.alias SAU13            $22CC    ;Saucer's third COLOR instruction plus RTSL.
.alias SPARKB           $22D0    ;Spark buffer: $20 bytes of vector code rebuilt each frame for the arc between the paired ships.
.alias PL0SET           $2300    ;Player 0's score display-list header, 10 bytes.
.alias PL1SET           $230A    ;Player 1's score display-list header, 10 bytes.
.alias CMBSET           $2314    ;Combined-score display-list header.
.alias CMSBSE           $2342    ;CMSBSET: the inverted combined-score header, for the cocktail cabinet's second player.
.alias PL0ARE           $2380    ;PL0AREA: player 0's score digits. HSAREA immediately precedes it, which is the one critical pairing in vector RAM.
.alias PL1ARE           $23C0    ;PL1AREA: player 1's score digits.
.alias SH0XPCOORD       $2700    ;Ship 0's explosion-piece coordinates, 4 bytes per piece (Y low, Y high, X low, X high) for 6 pieces.
.alias SH1XPCOORD       $2718    ;Ship 1's explosion-piece coordinates, same layout.
.alias CMSBAR           $2736    ;CMSBAREA: the inverted combined-score digits.
.alias CMBARE           $2780    ;CMBAREA: the combined-score digits.

;----------------------------------[ Vector ROM ]----------------------------------
.alias CKUM4            $2800    ;SHIPS, the 34-entry ship-picture pointer table; this alias holds the low bytes. CKUM4 is a checksum byte the linker placed elsewhere.
.alias ROCKA            $2801    ;SHIPS+1, the high bytes of the same table. Shpdisplays reads the pair into VGLIST with LDA CKUM4,Y / LDA ROCKA,Y.
.alias ROCKSA           $2811    ;unreferenced. ROCKSA and ROCPIC belong to a relocatable CSECT the linker placed elsewhere, so this address is an artifact of the ASECT walk.

