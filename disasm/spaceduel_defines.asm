;Space Duel (Atari, 1982) - hardware map and RAM variables.
;Names in the 'Hardware' sections are descriptive; the RAM variable names
;below are Atari's own identifiers, recovered from the .BLKB declarations
;in ASTRD2.MAC and the equates in AS2DEC.MAC (Atari's source archive).
;Note DEC MACRO-65 symbols are significant to 6 characters only.

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
.alias BLACK            $00
.alias BLUE             $01
.alias EAC2             $02
.alias CHAN2V           $03
.alias RED              $04
.alias CHAN3V           $05
.alias TWOPI            $06
.alias WHITE            $07
.alias EACE             $08
.alias VGBRIT           $09
.alias POKRAN           $0A
.alias POTGO            $0B
.alias XCOMP            $0C
.alias FOURPI           $0D
.alias SKCTL            $0F
.alias TEMP1            $10
.alias NMROCK           $11
.alias TEMP2            $13
.alias NOBJ             $15
.alias YTOP             $18
.alias TEMP4            $19
.alias TEMP5            $1C
.alias TEMP6            $1D
.alias TEMP7            $1E
.alias TEMP7B           $1F
.alias TEMP8            $20
.alias TEMP9            $21
.alias TEMP10           $22
.alias ZPAIR            $23
.alias ZMINE            $24
.alias TEMPA            $25
.alias TEMPB            $26
.alias TEMPC            $27
.alias ROTENG           $28
.alias ZP1MIN           $2C
.alias ZLAST            $2F
.alias LANGBT           $30
.alias TOTOBJ           $32
.alias INTRPT           $3B
.alias SYNC             $3C
.alias GAME             $3D
.alias ATRACT           $3E
.alias MAXSPE           $3F
.alias EAWRIT           $40
.alias UPDFLG           $41
.alias SCORE            $43
.alias CMBSCORE         $49
.alias GENDING          $4C
.alias FRAME            $4D
.alias HITS             $50
.alias LASTSW           $52
.alias XINCL            $54
.alias YINCL            $56
.alias TOGGLE           $58
.alias TOGDRONE         $5A
.alias TOGCOMB          $5B
.alias SCRFUL           $5C
.alias KLMOFF           $5D
.alias TSTBYTE          $5E
.alias POINT            $5F
.alias MXSPKT           $60
.alias CURRENT          $6F
.alias COUNT            $7F
.alias COCKBI           $80
.alias FRAMES           $8F
.alias SINDEX           $9F
.alias OBJ              $A0
.alias OBCOMETS         $B1
.alias OBKLMINES        $B9
.alias OBSAUCER         $BF
.alias OBSHIP           $C1
.alias OBPAIR           $C3
.alias OBMINES          $C4
.alias OBP0MINES        $C8
.alias OBP1MINES        $CC
.alias EASRCE           $D0
.alias KLMINC           $D2
.alias DIFCTY           $D8
.alias OPTN1            $D9
.alias LANG             $DA
.alias DIFF             $DB
.alias SAUMIN           $DC
.alias ROCKMIN          $DE
.alias ROCKMAX          $E0
.alias NXTBON           $E2
.alias BONLVA           $E4
.alias ATSTG            $E5
.alias HSCORE           $E6
.alias BGSHEN           $F0

;----------------------------------[ Stack page ]----------------------------------
.alias INITL            $0122
.alias SPINT            $015E
.alias EABUF            $016D
.alias EAZFLG           $018D
.alias EAREQU           $018E
.alias EARWRQ           $018F
.alias EABAD            $0190
.alias EAFLG            $0191
.alias EABC             $0192
.alias EAX              $0193
.alias EACNT            $0194
.alias EASEL            $0195
.alias EACS             $0196
.alias ONTIME           $0197
.alias BONTIME          $019B
.alias PLAYTIME         $019F
.alias GAMES1           $01AF
.alias THRENG           $01E0

;----------------------------------[ Game RAM ]----------------------------------
.alias XINC             $0200
.alias YINC             $0232
.alias NROCKS           $0264
.alias ENMDEL           $0265
.alias EDELAY           $0267
.alias SENMDEL          $0269
.alias RTIMER           $026B
.alias SDELAY           $026D
.alias ETIMER           $026F
.alias RDELAY           $0271
.alias THUMP3           $0272
.alias SHLDENG          $0273
.alias LSHLDENG         $0275
.alias CSPEED           $0277
.alias KSPEED           $027F
.alias CANGCH           $0285
.alias KANGCH           $028D
.alias CANGLH           $0293
.alias KANGLH           $029B
.alias ANGLE            $02A1
.alias SANGLE           $02A3
.alias CANGLL           $02A5
.alias KANGLL           $02AD
.alias BANGLE           $02B3
.alias BANGLL           $02B4
.alias OBJXH            $02B5
.alias OBJYH            $02E7
.alias ISNSP2           $0319
.alias SNDBA2           $031A
.alias SNDSP2           $031B
.alias SPARKANGLE       $031C
.alias OBJXL            $0320
.alias OBJYL            $0352
.alias UWBAR            $0384
.alias LWBAR            $0385
.alias BXINCL           $0386
.alias BYINCL           $0387
.alias PRTDAMAGE        $0388
.alias COLLIS           $038A
.alias STRADDLE         $038C
.alias COMOFF           $038D
.alias OWNER            $038E
.alias COMTYP           $038F
.alias COMSTART         $0397
.alias PROBCOMET        $0399
.alias DWFRMP           $039B
.alias SCSHSP           $039D
.alias XINCROT          $039F
.alias YINCROT          $03A0
.alias XPOSSAVE         $03A1
.alias YPOSSAVE         $03A2
.alias SHHIGH           $03A3
.alias FREXPLOSION      $03A4
.alias MXRTIMER         $03A5
.alias NWCACH           $03A7
.alias NWCSPD           $03A9
.alias FCACH            $03AB
.alias FCSPD            $03AD
.alias WAVE             $03AF
.alias GTIME            $03B0
.alias BCOMSTART        $03B4
.alias NCOMET           $03B6
.alias COMTIMER         $03B7
.alias COMLIMIT         $03B8
.alias LNGTIMER         $03B9
.alias WHOSHOT          $03BB
.alias NENTCOMETS       $03BD
.alias NENTDWARF        $03BE
.alias ETARGET          $03BF
.alias CTARGET          $03C1
.alias KTARGET          $03C9
.alias SPARKTIME        $03CF
.alias IANGLE           $03D0
.alias LMONHITS         $03D2
.alias UMONHITS         $03D4
.alias ASTERS           $03D6
.alias HSCFLG           $03DE
.alias RODSTATUS        $03DF
.alias SAVBOT           $03E0
.alias PL0SCFLAG        $03E1
.alias PL1SCFLAG        $03E2
.alias CMBSCFLAG        $03E3
.alias UPDOWN           $03E4
.alias SECOND           $03E5
.alias FLASHCOL         $03E6
.alias ENTER            $03E7
.alias SFREQ            $03E9
.alias SPFLG            $03EA
.alias FLSFLG           $03EB
.alias SAUCIX           $03ED
.alias STRTLOK          $03EE
.alias EXPDEC           $03EF
.alias SUPRSAC          $03F1
.alias SUPRTIM          $03F2
.alias SUPRDIS          $03F3
.alias LASTG            $03F4
.alias NEXTEX           $03F5
.alias SPECEX           $03F6
.alias INTEN            $03F7
.alias MODNUM           $03F8
.alias DIFSW            $03F9

;----------------------------------[ Hardware registers ]----------------------------------
.alias HALT             $0800
.alias HYPSW            $0900
.alias ROTL             $0902
.alias STRT1            $0904
.alias OPTNA1           $0905
.alias GAMSEL           $0906
.alias CABERE           $0907
.alias EAIN             $0A00
.alias OUT1             $0C00
.alias GOADD            $0C80
.alias WTCHDG           $0D00
.alias STOPAD           $0D80
.alias INTACK           $0E00
.alias EACTL            $0E80
.alias EADAL            $0F00
.alias POKEY            $1000
.alias POKEY2           $1400

;----------------------------------[ Vector RAM ]----------------------------------
.alias VECMEM           $2000
.alias VROCK1           $2290
.alias CVR11            $2292
.alias CVR12            $2296
.alias CVR13            $229A
.alias VROCK2           $229E
.alias CVR21            $22A0
.alias CVR22            $22A4
.alias CVR23            $22A8
.alias VROCK3           $22AC
.alias PYR11            $22AE
.alias PYR12            $22B2
.alias PYR13            $22B6
.alias VROCK4           $22BA
.alias VROCK5           $22BC
.alias VROCK6           $22BE
.alias VROCK7           $22C0
.alias VROCK8           $22C2
.alias SAU11            $22C4
.alias SAU12            $22C8
.alias SAU13            $22CC
.alias SPARKB           $22D0
.alias PL0SET           $2300
.alias PL1SET           $230A
.alias CMBSET           $2314
.alias CMSBSE           $2342
.alias PL0ARE           $2380
.alias PL1ARE           $23C0
.alias SH0XPCOORD       $2700
.alias SH1XPCOORD       $2718
.alias CMSBAR           $2736
.alias CMBARE           $2780

;----------------------------------[ Vector ROM ]----------------------------------
.alias CKUM4            $2800
.alias ROCKA            $2801
.alias ROCKSA           $2811

