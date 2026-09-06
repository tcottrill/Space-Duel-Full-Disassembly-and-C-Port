;Space Duel (Atari, 1982) - annotated disassembly of the program ROMs.
;Reconstructed against the MAME 'spacduel' set (rev 2) and cross-checked line
;by line against Atari's own source archive (project 'ASTERIODS 2').
;Every instruction below was re-encoded and byte-compared with the ROM.
;Assembles with Ophis; disasm/gen_from_roms.py --check round-trips it with ca65.

.org $4000

.include "spaceduel_defines.asm"


Checksum4000:
L4000:  .byte $42

Atari:
L4001:  .byte $02, $BB, $5A, $30, $5F, $EE, $7D, $A8
L4009:  JMP  Poweron

InitializePlayer1Start:
L400C:  JSR  Initialization         ;INITIALIZE PLAYER 1 FOR START OF GAME

StartUpNewAsteroids:
L400F:  JSR  NewastStartNewAsteroids ;START UP NEW ASTEROIDS

Start2:
L4012:  JSR  Gtoptn
L4015:  LDA  HALT                   ;CHECK FOR SELF TEST
L4018:  AND  #$10
L401A:  BNE  Start2_6
L401C:  JMP  AllStopPlease          ;GO DO SELF TEST

Start2_6:
L401F:  BIT  HALT
L4022:  BVC  Start2_6
L4024:  JSR  DoLowOnesEvery

Start2_8:
L4027:  LSR  SYNC
L4029:  BCC  Start2_8               ;NOT 1/60 SEC YET
L402B:  STA  WTCHDG
L402E:  LDA  FRAME                  ;MOVE FLASH COLOR POINTER
L4030:  AND  #$0F
L4032:  ORA  #$E0                   ;FULL BRIGHT ON FLASH
L4034:  STA  FLASHCOL
L4037:  LDX  #$01

Start2_9:
L4039:  LDA  ENTER,X
L403C:  BEQ  Start2_10              ;NO TOUCH
L403E:  CLC
L403F:  ADC  #$02
L4041:  STA  ENTER,X
L4044:  BNE  Start2_10              ;NOT FULLY BACK
L4046:  LDA  #$40                   ;GIVE AN 8 SECOND BONUS...
L4048:  JSR  AmountAddRoutineLimits

Start2_10:
L404B:  DEX
L404C:  BPL  Start2_9
L404E:  LDA  $2001                  ;SWAP BUFFERS AND...
L4051:  EOR  #$02
L4053:  STA  $2001
L4056:  STA  GOADD                  ;GO

Start2_11:
L4059:  LDA  $2001                  ;PICK BUFFER TO BUILD IN
L405C:  LDX  #$20
L405E:  AND  #$02
L4060:  BNE  Start2_12              ;USE LOWER BUFFER
L4062:  LDX  #$24                   ;USE UPPER BUFFER

Start2_12:
L4064:  LDA  #$02
L4066:  STA  VGLIST
L4068:  STX  EAC2                   ;RESET VECTOR LIST POINTER
L406A:  LDA  #$94
L406C:  LDX  #$AA
L406E:  JSR  Add2WordsToVector
L4071:  LDA  ATRACT                 ;0=ATTRACT
L4073:  ORA  DIAGBI                 ;OR ANY CREDIT
L4075:  ORA  $26                    ;OR ANY COINS
L4077:  BNE  Start2_14
L4079:  LDA  UPDFLG
L407B:  AND  $39                    ;NOT DURING INITIAL ENTRY EITHER
L407D:  BPL  Start2_14
L407F:  LDA  #$64
L4081:  LDX  #$AF
L4083:  JSR  Add2WordsToVector
L4086:  LDA  BONLVA                 ;BONUS LEVEL OBTAINED IN 'GTOPTN'
L4088:  BEQ  Start2_14
L408A:  PHA
L408B:  LDA  #$CA
L408D:  LDX  #$C2                   ;POSITION FOR MESSAGE
L408F:  JSR  Mesgpos
L4092:  LDY  #$0E
L4094:  LDA  #$E1
L4096:  JSR  PassColor
L4099:  PLA
L409A:  STA  EACE                   ;SAVE BONUS AMOUNT
L409C:  LDA  #$00
L409E:  STA  TEMP1                  ;FOR DISPLAY
L40A0:  SEC                         ;ZERO SUPRESSION
L40A1:  LDA  #$07                   ;PAGE 0 POINTER
L40A3:  LDY  #$02                   ;2 ZERO PAGE LOCATIONS
L40A5:  JSR  SaveInpuParameers      ;DISPLAY LEVEL
L40A8:  LDA  #$00
L40AA:  JSR  DisplayDigit           ;ADD ANOTHER 0

Start2_14:
L40AD:  JSR  CheckForStartEnd       ;CHECK FOR START
L40B0:  BCC  Start2_15
L40B2:  JMP  InitializePlayer1Start ;BUTTON PUSHED-START OVER

Start2_15:
L40B5:  LDA  ATRACT
L40B7:  BNE  Start2_20
L40B9:  JSR  GetPlayersInitials     ;GET INITIALS FOR ANY NEW HIGH SCORE
L40BC:  BCC  Start2_55              ;NOT DONE YET
L40BE:  JMP  Start2                 ;DONE---RESTART EVERYTHING

Start2_55:
L40C1:  LDA  UPDFLG
L40C3:  AND  $39
L40C5:  BPL  Start2_60
L40C7:  LDA  SHHIGH                 ;FORCE DISPLAY OF HIGH SCORES
L40CA:  BNE  Start2_13
L40CC:  LDA  DIAGBI
L40CE:  ORA  $26                    ;ANY COINS OR CREDITS?
L40D0:  BNE  Start2_60              ;IF YES...NO TABLE NEEDED

Start2_13:
L40D2:  JSR  Scores                 ;DO SCORE TABLE
L40D5:  BCS  Start2_60              ;DOING SCORE TABLE

Start2_20:
L40D7:  BIT  TOGDRONE
L40D9:  BMI  Start2_30              ;NOT DO SHIP 1
L40DB:  LDX  #$01
L40DD:  JSR  FireShipsTorpedos      ;FIRE SHIPS TORPEDOES

Start2_30:
L40E0:  LDX  #$00
L40E2:  JSR  FireShipsTorpedos

Start2_31:
L40E5:  LDX  #$01
L40E7:  JSR  MoveShip               ;MOVE SHIP BY CONTROLS
L40EA:  LDX  #$00
L40EC:  JSR  MoveShip
L40EF:  JSR  CometCalculations
L40F2:  JSR  Onslaught
L40F5:  JSR  QuickEndEndOnslaught   ;QUICK RESTART
L40F8:  JSR  KillerMines            ;DO KILLER MINES - FALL INTO "ENEMY" ROUTINE
L40FB:  JSR  MotionUpdateRoutine    ;MOVE OBJECTS
L40FE:  JSR  ProcessShields
L4101:  JSR  CollisionDetector      ;CHECK FOR COLLISIONS

Start2_60:
L4104:  JSR  Entparams              ;DISPLAY SCORE AND OTHER PARAMETERS
L4107:  JSR  ForceFieldUp           ;HUM?
L410A:  JSR  CenterBeamInMiddle     ;POSITION BEAM FOR MINIMUM CURRENT
L410D:  JSR  AddHaltToVector        ;ADD HALT TO VECTOR LIST
L4110:  JSR  Spark2                 ;MOVE THE SPARKS
L4113:  JSR  UsesTemp1Temp11
L4116:  LDA  RDELAY
L4119:  BEQ  Start2_70              ;NO DELAY TO DECREMENT
L411B:  DEC  RDELAY
L411E:  BNE  Start2_80

Start2_70:
L4120:  LDA  ATRACT
L4122:  BPL  L413F
L4124:  LDA  ZMINE
L4126:  AND  #$03                   ;FREE PLAY??
L4128:  BNE  L413F
L412A:  BIT  GAMSEL                 ;FREE PLAY AND 2 COIN MIN?
L412D:  BVC  L413F
L412F:  LDA  GAMSEL
L4132:  ASL
L4133:  ROR  SAVBOT                 ;DEBOUNCE SWITCH
L4136:  BCC  L413F
L4138:  BNE  L413F
L413A:  LDA  #$F0
L413C:  STA  NROCKS                 ;FORCE TO NEXT WAVE
L413F:  LDA  NROCKS
L4142:  BMI  Start2_75              ;INCASE IT GOES PAST 0
L4144:  BNE  Start2_80              ;LOOP FOR NEXT PASS

Start2_75:
L4146:  BIT  ATRACT                 ;ATTRACT PLAY?
L4148:  BMI  Start2_76              ;NO
L414A:  LDA  $45
L414C:  AND  #$03
L414E:  CMP  #$03                   ;ONLY BUMP IF HELD AT 3
L4150:  BNE  Start2_80
L4152:  INC  $45                    ;FORCE TO NEXT STAGE

Start2_76:
L4154:  JMP  StartUpNewAsteroids    ;START NEW SET OF ASTEROIDS

Start2_80:
L4157:  JMP  Start2

CheckForStartEnd:
L415A:  LDA  ATRACT
L415C:  BEQ  CheckForStartEnd_10    ;GAME NOT IN PROGRESS
L415E:  LDA  GENDING
L4160:  BNE  CheckForStartEnd_6     ;STILL ENDING
L4162:  JMP  Chkst1                 ;GAME IN PROGRESS

CheckForStartEnd_6:
L4165:  INC  GENDING
L4167:  BEQ  CheckForStartEnd_7     ;NOT OVER YET
L4169:  LDA  #$E4
L416B:  LDX  #$04
L416D:  JSR  Mesgpos                ;POSITION MESSAGE
L4170:  LDY  #$07                   ;GAME OVER MESSAGE
L4172:  STY  UPDOWN                 ;NORMAL MESSAGE ALWAYS
L4175:  JSR  VectorGeneratorMessageProcessor
L4178:  LDA  #$00
L417A:  STA  COMTIMER               ;END ONSLAUGHT
L417D:  LDA  #$FF                   ;SHOW HIGH SCORES ONCE
L417F:  STA  SHHIGH
L4182:  CLC                         ;NO NEW GAME
L4183:  RTS                         ;(EXIT)

CheckForStartEnd_7:
L4184:  JSR  Inisou                 ;TURN OFF SOUNDS
L4187:  JSR  Bigbang                ;REMOVE ALL
L418A:  LDA  UPDFLG
L418C:  AND  $39
L418E:  BMI  CheckForStartEnd_65
L4190:  JSR  Gates                  ;HIGH SCORE SOUND
L4193:  LDA  #$00
L4195:  STA  SPECEX

CheckForStartEnd_65:
L4198:  LDA  #$00
L419A:  STA  ATRACT
L419C:  STA  RDELAY
L419F:  STA  SCRFUL                 ;ALLOW ROCKS BACK
L41A1:  STA  SDELAY
L41A4:  STA  $026E
L41A7:  STA  OBSHIP
L41A9:  STA  $B9
L41AB:  CLC
L41AC:  RTS

CheckForStartEnd_10:
L41AD:  LDA  DIAGBI
L41AF:  ORA  $26                    ;NOT IF CREDIT OR COINS
L41B1:  ORA  FRAME                  ;THIS MUST BE 0 TOO
L41B3:  BNE  CheckForStartEnd_3
L41B5:  LDA  $45
L41B7:  AND  #$07
L41B9:  EOR  #$02
L41BB:  BNE  CheckForStartEnd_3     ;MUST ALSO BE 0
L41BD:  LDY  #$00
L41BF:  JSR  Nxtstep                ;STEP TO NEXT GAME
L41C2:  BEQ  CheckForStartEnd_4
L41C4:  CMP  #$02
L41C6:  BCC  CheckForStartEnd_4
L41C8:  LDY  #$80

CheckForStartEnd_4:
L41CA:  STY  TOGCOMB
L41CC:  JSR  Gtoptn                 ;READ OPTION SWITCHES AND GET LIVES
L41CF:  LDA  #$20                   ;MAKE SHIP APPEAR
L41D1:  STA  SDELAY
L41D4:  STA  $026E
L41D7:  LDA  #$80
L41D9:  STA  SCSHSP                 ;WANT SAUCERS MAD
L41DC:  STA  $039E
L41DF:  LDA  #$00
L41E1:  STA  OBSHIP                 ;TURN OFF OLD SHIP
L41E3:  STA  $B9
L41E5:  STA  IANGLE                 ;POINT STRAIGHT UP
L41E8:  STA  $03D1

CheckForStartEnd_3:
L41EB:  LDY  LANGBT                 ;STILL DOING COINR ROUTINE?
L41ED:  BMI  CheckForStartEnd_11    ;NOPE--NOT IF MINUS
L41EF:  LDA  #$08
L41F1:  LDY  DIAGBI
L41F3:  CPY  #$12
L41F5:  BCC  CheckForStartEnd_1     ;NOT LIMITED YET
L41F7:  LDY  #$12
L41F9:  STY  DIAGBI

CheckForStartEnd_11:
L41FB:  LDA  #$00

CheckForStartEnd_1:
L41FD:  STA  $31
L41FF:  LDA  SHHIGH
L4202:  BEQ  CheckForStartEnd_8
L4204:  DEC  SHHIGH                 ;FORCE DISPLAY OF HIGH SCORES

CheckForStartEnd_8:
L4207:  LDA  #$00                   ;DEFAULT TO SELL PLAYERS
L4209:  STA  TEMP5
L420B:  STA  KLMOFF                 ;FOR ATRACT
L420D:  LDY  #$08
L420F:  BIT  OPTNA1
L4212:  BVC  CheckForStartEnd_12    ;SELLING GAMES????
L4214:  DEC  TEMP5                  ;IF POSITIVE

CheckForStartEnd_12:
L4216:  INY                         ;CHARGE BY THE PLAYER
L4217:  SEI
L4218:  STA  $140B
L421B:  LDA  $1408
L421E:  CLI                         ;INTERRUPTS OK NOW
L421F:  EOR  #$02                   ;CORRECT FOR ALL OFF
L4221:  STA  ZMINE
L4223:  AND  #$03
L4225:  BNE  CheckForStartEnd_35
L4227:  LDA  #$02                   ;FREE PLAY
L4229:  STA  DIAGBI
L422B:  STA  ZSAUCE                 ;NO 2 COIN MIN
L422D:  BNE  CheckForStartEnd_15

CheckForStartEnd_35:
L422F:  CLC
L4230:  ADC  #$07
L4232:  BIT  TEMP5
L4234:  BPL  CheckForStartEnd_9
L4236:  ADC  #$0D                   ;COIN MODE MESSAGE

CheckForStartEnd_9:
L4238:  TAY
L4239:  LDA  #$C6
L423B:  STA  TEMP9

CheckForStartEnd_80:
L423D:  BIT  GAMSEL                 ;2 COIN MINIUM
L4240:  BVC  CheckForStartEnd_82
L4242:  LDA  DIAGBI
L4244:  BNE  L424D
L4246:  LDA  #$80
L4248:  STA  ZSAUCE
L424A:  JMP  L4251
L424D:  CMP  #$01
L424F:  BNE  CheckForStartEnd_82    ;EASY WAY OUT
L4251:  BIT  ZSAUCE
L4253:  BPL  CheckForStartEnd_83    ;1 CREDIT, MIMIMUN SATIFIED
L4255:  LDA  FRAME
L4257:  AND  #$20
L4259:  BNE  L4261
L425B:  LDY  #$12                   ;ALT MESSAGE
L425D:  LDA  #$C4
L425F:  STA  TEMP9
L4261:  JMP  CheckForStartEnd_81

CheckForStartEnd_82:
L4264:  LDA  #$00
L4266:  STA  ZSAUCE                 ;DON'T ALLOW THIS TO HAPPEN

CheckForStartEnd_83:
L4268:  LDA  FRAME
L426A:  AND  #$20
L426C:  BNE  CheckForStartEnd_15    ;HERE WE FLASH THE MESSAGE

CheckForStartEnd_81:
L426E:  LDA  UPDFLG
L4270:  AND  $39
L4272:  BPL  CheckForStartEnd_15    ;IF UPDATING INITIALS
L4274:  LDA  SHHIGH                 ;SKIP WHILE HIGH SCORE TBL
L4277:  BNE  CheckForStartEnd_15
L4279:  TYA
L427A:  PHA                         ;SAVE Y FOR LATER
L427B:  LDA  #$D3
L427D:  LDX  #$49
L427F:  JSR  Mesgpos
L4282:  LDX  #$00                   ;OFFSET FOR LANGUAGES
L4284:  JSR  AuxRoutineAddOffset
L4287:  LDX  TEMP9
L4289:  PLA
L428A:  TAY                         ;RESTORE Y
L428B:  JSR  Brightness

CheckForStartEnd_15:
L428E:  LDY  DIAGBI
L4290:  BNE  CheckForStartEnd_16    ;NO CREDIT-NO PLAY
L4292:  LDY  $26                    ;ANY COINS???
L4294:  BEQ  CheckForStartEnd_14    ;NOPE--END
L4296:  JMP  CheckForStartEnd_47    ;GO DO GAME DISPLAY

CheckForStartEnd_14:
L4299:  LDA  $31
L429B:  ORA  #$30                   ;TURN OF LIGHTS
L429D:  STA  $31
L429F:  CLC
L42A0:  RTS

CheckForStartEnd_16:
L42A1:  LDA  GAMSEL
L42A4:  ASL
L42A5:  ROR  SAVBOT                 ;DEBOUNCE GAME SELECT SWITCH

CheckForStartEnd_17:
L42A8:  BIT  STRTLOK                ;LOCKED OUT (NO SELECT YET)?
L42AB:  BMI  CheckForStartEnd_40    ;YEP
L42AD:  BIT  ZSAUCE
L42AF:  BMI  CheckForStartEnd_40    ;STARTS LOCKED OUT
L42B1:  BIT  STRT1                  ;START PUSHED
L42B4:  BVC  CheckForStartEnd_40    ;NO START
L42B6:  BIT  TEMP5                  ;THIS IS MINUS IF SELLING GAMES
L42B8:  BMI  CheckForStartEnd_20
L42BA:  LDA  GAME                   ;SELLING PLAYERS......HOW MUCH THIS COST?
L42BC:  LSR                         ;ODD GAMES ARE 1 PLAYER GAMES
L42BD:  BCS  CheckForStartEnd_20
L42BF:  DEC  DIAGBI                 ;COST 2 CREDITS...THIS IS 2

CheckForStartEnd_20:
L42C1:  DEC  DIAGBI                 ;AND THIS IS ONE!!!!!!
L42C3:  LDA  $31                    ;TURN ON START LAMP
L42C5:  AND  #$DF
L42C7:  STA  $31
L42C9:  LDA  #$00
L42CB:  STA  STRTLOK                ;RESET START LOCKOUT FLAG
L42CE:  STA  SPECEX                 ;IN CASE THIS WAS ON
L42D1:  LDA  #$FF
L42D3:  STA  FLSFLG                 ;NO NEW HIGH SCORES
L42D6:  STA  $03EC
L42D9:  LDA  GAME
L42DB:  STA  LASTG                  ;SAVE LAST GAME
L42DE:  JSR  Gtoptn                 ;SET DIFF LEVEL FOR THIS GAME
L42E1:  SEC                         ;SIGNIFY STARTING OF NEW GAME
L42E2:  RTS

CheckForStartEnd_40:
L42E3:  LDA  FRAME
L42E5:  AND  #$18
L42E7:  ASL                         ;FLASH RATE
L42E8:  BIT  SAVBOT
L42EB:  BPL  CheckForStartEnd_43    ;NOT PRESSED
L42ED:  BVS  CheckForStartEnd_43    ;WAS PRESSED LAST TIME
L42EF:  BIT  ZSAUCE                 ;HOLDING BECAUSE OF THIS NONSENSE???
L42F1:  BMI  CheckForStartEnd_43
L42F3:  BIT  STRTLOK                ;WAS THIS FIRST PRESS OF PUTTON????
L42F6:  BPL  CheckForStartEnd_41    ;NOPE
L42F8:  LDA  LASTG
L42FB:  AND  #$03                   ;JUST IN CASE NOT INITIALIZED
L42FD:  STA  GAME
L42FF:  JMP  CheckForStartEnd_42

CheckForStartEnd_41:
L4302:  LDX  #$00
L4304:  STX  SHHIGH                 ;NO HIGH SCORE

CheckForStartEnd_44:
L4307:  JSR  Nxtstep                ;NEXT GAME

CheckForStartEnd_42:
L430A:  LDX  #$40
L430C:  STX  STRTLOK                ;SET PUSHED FLAG
L430F:  LDX  #$FF
L4311:  STX  UPDFLG
L4313:  STX  $39                    ;ABORT ANT INITIALS
L4315:  LDX  #$00
L4317:  STX  SHHIGH                 ;ABORT TABLE

CheckForStartEnd_43:
L431A:  BIT  STRTLOK                ;STARTS??
L431D:  BPL  CheckForStartEnd_46    ;OK TO START
L431F:  ORA  #$20                   ;NO START LAMP FLASH

CheckForStartEnd_46:
L4321:  EOR  $31
L4323:  AND  #$30                   ;1'S MEAN REPLACE WITH ACC
L4325:  EOR  $31
L4327:  STA  $31
L4329:  LDX  GAME
L432B:  LDA  Ttplayr,X              ;NUMBER OF CREDITS REQUIRED FOR THIS GAME (1,2)
L432E:  BIT  TEMP5
L4330:  BMI  CheckForStartEnd_45    ;BY THE GAME
L4332:  CMP  DIAGBI
L4334:  BEQ  CheckForStartEnd_45    ;EXACTLY ENOUGH
L4336:  BCC  CheckForStartEnd_45    ;ENOUGH CREDIT
L4338:  JSR  Nxtstep                ;NEXT GAME
L433B:  BCS  CheckForStartEnd_46    ;*********ALWAYS*************

CheckForStartEnd_45:
L433D:  LDY  #$0B                   ;ONE PLAYER
L433F:  LSR                         ;ACC 0 FOR 1 PLAYER
L4340:  BEQ  CheckForStartEnd_47
L4342:  INY

CheckForStartEnd_47:
L4343:  LDA  SHHIGH
L4346:  BNE  CheckForStartEnd_59    ;SHOWING HIGH SCORE
L4348:  LDA  UPDFLG
L434A:  AND  $39
L434C:  BPL  CheckForStartEnd_59    ;NO DISPLAY IF INITIALS
L434E:  JSR  Display4Names          ;DISPLAY GAME SELECT

CheckForStartEnd_59:
L4351:  CLC
L4352:  RTS                         ;(EXIT)

OneTwoPlayer:
L4353:  .byte $11, $11, $12, $12

Chkst1:
L4357:  LDA  $48
L4359:  ORA  HITS                   ;ANY HITS LEFT???
L435B:  ORA  OBSHIP                 ;STILL LIVING????
L435D:  ORA  $B9
L435F:  BNE  Chkst1_90
L4361:  LDA  GAME                   ;COMPETITIVE?
L4363:  BNE  Chkst1_20              ;NOPE
L4365:  LDA  PRTDAMAGE
L4368:  AND  $0389
L436B:  BPL  Chkst1_90              ;ONE NOT DAMAGED

Chkst1_20:
L436D:  LDA  GENDING
L436F:  BNE  Chkst1_90              ;GAME ALREADY ENDING
L4371:  LDX  #$07

Chkst1_10:
L4373:  LDA  OBP0MINES,X
L4375:  BNE  Chkst1_90              ;GAME STILL GOING
L4377:  DEX
L4378:  BPL  Chkst1_10
L437A:  JSR  ScoreColorBasedAbove   ;SLOW DOWN ROCKS
L437D:  LDA  #$01
L437F:  STA  WAVE                   ;BACK TO WAVE 1
L4382:  LDA  #$00
L4384:  STA  SCRFUL                 ;LET ROCKS COME BACK
L4386:  LDX  #$40
L4388:  LDA  UPDFLG
L438A:  AND  #$39                   ;INITIALS??
L438C:  BMI  Chkst1_17              ;NO
L438E:  LDX  #$10                   ;LONGER STILL

Chkst1_17:
L4390:  STX  GENDING                ;NO MORE SHOTS BUT COUNT THOSE THAT ARE STILL GOING
L4392:  LDA  #$80                   ;NO STARTS
L4394:  STA  STRTLOK                ;SET NO STARTS ALLOWED
L4397:  JSR  UpdateInfoAtEnd
L439A:  JSR  UpdateHighScoreTable   ;CHECK FOR NEW HIGH SCORE
L439D:  LDA  #$00
L439F:  STA  LANGBT                 ;START COIN ROUTINE

Chkst1_90:
L43A1:  CLC
L43A2:  RTS

Nxtstep:
L43A3:  LDX  GAME
L43A5:  LDA  TableGameOrder,X       ;WHICH GAME IS NEXT??
L43A8:  STA  GAME                   ;NEXT
L43AA:  BIT  CABERE
L43AD:  BVC  Nxtstep_10
L43AF:  LSR                         ;CABERET -- GAMES 1 AND 3 ONLY
L43B0:  BCC  Nxtstep

Nxtstep_10:
L43B2:  RTS

TableGameOrder:
L43B3:  .byte $01, $03, $00, $02

CollisionDetector:
L43B7:  LDX  #$2F

CollisionDetector_10:
L43B9:  LDA  OBJ,X
L43BB:  BEQ  CollisionDetector_13   ;IF INACTIVE TORPEDO
L43BD:  BPL  CollisionDetector_16   ;NOT CHECK IF MINUS (EXPLODING)

CollisionDetector_13:
L43BF:  DEX
L43C0:  CPX  #$20                   ;STOP X AT SHIP0
L43C2:  BNE  CollisionDetector_10

CollisionDetector_14:
L43C4:  RTS                         ;(EXIT)

CollisionDetector_16:
L43C5:  LDY  $448F,X
L43C8:  LDA  GAME
L43CA:  BNE  CollisionDetector_19
L43CC:  LDY  $44A0,X                ;FOR COMPETITIVE, USE DIFFERENT STARTS

CollisionDetector_19:
L43CF:  DEY
L43D0:  BMI  CollisionDetector_13
L43D2:  LDA  OBJ,Y
L43D5:  BEQ  CollisionDetector_19   ;IF INACTIVE
L43D7:  BMI  CollisionDetector_19   ;IF AN EXPLOSION
L43D9:  LDA  OBJXH,Y
L43DC:  SEC
L43DD:  SBC  OBJXH,X
L43E0:  SBC  #$03
L43E2:  CMP  #$FA
L43E4:  BCC  CollisionDetector_19   ;TOO FAR
L43E6:  LDA  OBJYH,Y
L43E9:  SBC  OBJYH,X
L43EC:  SBC  #$03
L43EE:  CMP  #$FA
L43F0:  BCC  CollisionDetector_19
L43F2:  LDA  OBJXL,Y                ;TEST X DIRECTION
L43F5:  SBC  OBJXL,X
L43F8:  STA  TEMP1                  ;STORE LOW X DIFFERENCE
L43FA:  LDA  OBJXH,Y
L43FD:  SBC  OBJXH,X
L4400:  LSR
L4401:  ROR  TEMP1                  ;DIVIDED BY 2
L4403:  ASL                         ;RESET ZERO CONDITION
L4404:  BEQ  CollisionDetector_32   ;IF WITHIN 64.
L4406:  EOR  #$FE
L4408:  BNE  CollisionDetector_19   ;TOO FAR AWAY
L440A:  LDA  TEMP1
L440C:  EOR  #$FF
L440E:  STA  TEMP1                  ;DISTANCE FROM TORPEDO

CollisionDetector_32:
L4410:  LDA  OBJYL,Y
L4413:  SEC
L4414:  SBC  OBJYL,X
L4417:  STA  EACE
L4419:  LDA  OBJYH,Y
L441C:  SBC  OBJYH,X
L441F:  LSR
L4420:  ROR  EACE
L4422:  ASL                         ;SET ZERO
L4423:  BEQ  CollisionDetector_35   ;IF WITHIN 64.
L4425:  EOR  #$FE
L4427:  BNE  CollisionDetector_19   ;TOO FAR AWAY
L4429:  LDA  EACE
L442B:  EOR  #$FF
L442D:  STA  EACE                   ;DISTANCE-1 FROM TORPEDO

CollisionDetector_35:
L442F:  CPY  #$11
L4431:  BCS  CollisionDetector_45   ;NOT A ROCK
L4433:  STY  FOURPI
L4435:  LDA  OBJ,Y
L4438:  AND  #$07
L443A:  TAY
L443B:  LDA  $44A9,Y
L443E:  LDY  FOURPI
L4440:  BPL  CollisionDetector_65   ;ALWAYS

CollisionDetector_45:
L4442:  LDA  $447A,Y

CollisionDetector_65:
L4445:  CLC
L4446:  ADC  $447A,X

CollisionDetector_70:
L4449:  CMP  TEMP1
L444B:  BCC  CollisionDetector_80   ;NO HIT
L444D:  CMP  EACE
L444F:  BCC  CollisionDetector_80   ;NO HIT
L4451:  STA  TEMP2
L4453:  LSR
L4454:  CLC
L4455:  ADC  TEMP2
L4457:  STA  TEMP2                  ;3/2 DISTANCE (NO CARRY IF LESS THAN 172.)
L4459:  LDA  #$00                   ;UPPER BYTE OF SUM OF RADII
L445B:  ADC  #$00                   ;CARRY IS IMPORTANT THING
L445D:  STA  POTGO

CollisionDetector_72:
L445F:  LDA  EACE                   ;CARRY IS CLEAR
L4461:  ADC  TEMP1
L4463:  STA  TEMP1                  ;LOWER BYTE OF SUM OF X,Y ( MEASURED)
L4465:  LDA  #$00
L4467:  ADC  #$00                   ;ACC IS UPPER SUM
L4469:  STA  EACE                   ;UPPER SUM OF X,Y (MEASURED)
L446B:  LDA  TEMP2                  ;LOWER SUM OF 3/2 DISTANCE ALLOWED
L446D:  CMP  TEMP1                  ;SETS CARRY FOR 16 BIT COMPARE
L446F:  LDA  POTGO
L4471:  SBC  EACE
L4473:  BCC  CollisionDetector_80   ;CHOP OFF CORNERS-A MISS ON OBJECT
L4475:  STX  TEMP3
L4477:  STY  FOURPI
L4479:  JSR  DestructionDuringCollision
L447C:  LDY  FOURPI
L447E:  LDX  TEMP3
L4480:  LDA  OBJ,X                  ;SEE IF OBJECT STILL ACTIVE (BECAUSE OF SHIELDS)
L4482:  BEQ  CollisionDetector_78
L4484:  BPL  CollisionDetector_80

CollisionDetector_78:
L4486:  LDY  #$00                   ;BESURE START WITH NEW X

CollisionDetector_80:
L4488:  JMP  CollisionDetector_19

CollisionDetector_110:
L448B:  .byte $38, $38, $38, $38, $38, $38, $38, $38
L4493:  .byte $18, $18, $18, $18, $18, $18, $20, $20

CollisionDetector_112:
L449B:  .byte $30, $30, $00, $00, $00, $00, $00, $00
L44A3:  .byte $00, $00, $00, $00, $00, $00, $00

CollisionDetector_115:
L44AA:  .byte $2A, $48, $00, $84

CollisionDetector_125:
L44AE:  .byte $1F, $1F, $21, $21, $00, $23, $23, $23
L44B6:  .byte $23, $21, $21, $21, $21, $21, $21, $21
L44BE:  .byte $21

CollisionDetector_126:
L44BF:  .byte $1F, $1F, $21, $22, $00, $23, $23, $23
L44C7:  .byte $23, $23, $23, $23, $23, $22, $22, $22
L44CF:  .byte $22

DestructionDuringCollision:
L44D0:  LDA  $4571,X
L44D3:  STA  OWNER
L44D6:  CPX  #$24
L44D8:  BCS  DestructionDuringCollision_15 ;X WAS A MINE
L44DA:  JMP  Dstr60                 ;NOT A MINE(SHOT)

DestructionDuringCollision_15:
L44DD:  LDA  #$00
L44DF:  STA  OBJ,X                  ;CLEAR SHOT
L44E1:  CPY  #$19
L44E3:  BCS  DestructionDuringCollision_30 ;Y NOT A ROCK OR COMET
L44E5:  JMP  SplitRockIntoFragments ;(EXIT POINT)

DestructionDuringCollision_30:
L44E8:  CPY  #$1F
L44EA:  BCS  DestructionDuringCollision_60 ;NOT KILLER MINE
L44EC:  LDA  #$00                   ;CAN BE 0
L44EE:  STA  $0266,Y                ;CURRENT SPEED
L44F1:  STA  XINC,Y                 ;IDLE MOVE
L44F4:  STA  YINC,Y                 ;IDLE MINE
L44F7:  LDA  OBKLMINES,Y
L44FA:  ADC  #$01                   ;ADD ANOTHE SHOT
L44FC:  STA  OBKLMINES,Y
L44FF:  CMP  #$08                   ;READY TO DIE?
L4501:  BCC  DestructionDuringCollision_35 ;NOPE
L4503:  LDA  #$00
L4505:  STA  OBJ,Y
L4508:  LDA  #$10                   ;100 POINTS
L450A:  JSR  AddPointsToScore
L450D:  JSR  Explosion
L4510:  JSR  InitiateKillerMine     ;RESTART ANOTHER
L4513:  LDX  TEMP3
L4515:  LDY  FOURPI                 ;RESTORE X & Y

DestructionDuringCollision_35:
L4517:  LDA  XINC,X
L451A:  LDX  #$00                   ;FOR SIGN EXTENSION
L451C:  ORA  #$00                   ;SET STATUS
L451E:  BPL  DestructionDuringCollision_47
L4520:  DEX

DestructionDuringCollision_47:
L4521:  CLC                         ;CARRY MAY ALREADY BE CLEAR
L4522:  ADC  OBJXL,Y
L4525:  STA  OBJXL,Y
L4528:  TXA
L4529:  ADC  OBJXH,Y
L452C:  STA  OBJXH,Y
L452F:  LDX  TEMP3
L4531:  LDA  YINC,X
L4534:  LDX  #$00
L4536:  ORA  #$00                   ;SET STATUS
L4538:  BPL  DestructionDuringCollision_49
L453A:  DEX

DestructionDuringCollision_49:
L453B:  CLC
L453C:  ADC  OBJYL,Y
L453F:  STA  OBJYL,Y
L4542:  TXA
L4543:  ADC  OBJYH,Y
L4546:  STA  OBJYH,Y

DestructionDuringCollision_55:
L4549:  RTS                         ;(EXIT POINT)

DestructionDuringCollision_60:
L454A:  CPY  #$21
L454C:  BCC  DestructionDuringCollision_65 ;NOT A SHIP, WAS SAUCER

DestructionDuringCollision_63:
L454E:  TYA
L454F:  SEC
L4550:  SBC  #$21
L4552:  CMP  OWNER
L4555:  BEQ  DestructionDuringCollision_55
L4557:  LDX  FOURPI                 ;TRANSFER COLLISION Y TO X
L4559:  JMP  CheckShieldConditionPossibly ;EXIT
L455C:  LDA  $456A,X                ;WHO'S SHOT WAS THIS??
L455F:  STA  OWNER
L4562:  CPY  OWNER                  ;MY SHOT??
L4565:  BEQ  DestructionDuringCollision_67

DestructionDuringCollision_65:
L4567:  CPX  #$28
L4569:  BCS  DestructionDuringCollision_66
L456B:  CPX  #$24                   ;DID ONE SHOO THE OTHER?
L456D:  BCC  DestructionDuringCollision_66 ;NOPE

DestructionDuringCollision_67:
L456F:  RTS

DestructionDuringCollision_66:
L4570:  LDA  #$00
L4572:  STA  SUPRSAC                ;CLEAR SUPER SAUCER

DestructionDuringCollision_70:
L4575:  JSR  UpTheDifficulty
L4578:  LDX  FOURPI
L457A:  JMP  KillXSaucer            ;(EXIT POINT)

Dstr60:
L457D:  CPY  #$21
L457F:  BCC  CheckShieldConditionPossibly ;WAS A ROCK OR KILLER MINE OR SAUCER
L4581:  JSR  BackAwayFromCollision
L4584:  LDX  FOURPI                 ;Y COLLISION OBJECT
L4586:  JSR  BackAwayFromCollision
L4589:  LDY  TEMP3
L458B:  JMP  SwitchVelocities       ;BOUNCE THE TWO SHIPS (EXIT POINT)

BelowTableNotUsed:
L458E:  .byte $20, $20, $21, $21

ValueOwnershipNegativeNobody:
L4592:  .byte $00, $01, $FF, $FF, $FF, $FF, $FF, $00
L459A:  .byte $00, $00, $00, $01, $01, $01, $01

CheckShieldConditionPossibly:
L45A1:  LDA  $03C6,X                ;ENTERING?
L45A4:  BNE  CheckShieldConditionPossibly_51 ;IF YES, PRETEND SHIELDS
L45A6:  LDA  $2E,X
L45A8:  AND  #$80
L45AA:  BEQ  DestroyXShip           ;SHIELDS WERE NOT ON
L45AC:  LDA  GAME
L45AE:  CMP  #$02                   ;GAME 2&3, SHIELDS LAST LONGER
L45B0:  BCC  CheckShieldConditionPossibly_10
L45B2:  LDA  $0252,X
L45B5:  SEC
L45B6:  SBC  #$0C
L45B8:  JMP  CheckShieldConditionPossibly_20

CheckShieldConditionPossibly_10:
L45BB:  LDA  $0252,X
L45BE:  SEC
L45BF:  SBC  #$18

CheckShieldConditionPossibly_20:
L45C1:  CMP  #$18
L45C3:  BCS  CheckShieldConditionPossibly_50
L45C5:  LDA  #$00

CheckShieldConditionPossibly_50:
L45C7:  STA  $0252,X

CheckShieldConditionPossibly_51:
L45CA:  LDY  FOURPI                 ;COLLISION Y
L45CC:  LDA  $0369,X
L45CF:  AND  #$7F
L45D1:  STA  TEMPA                  ;OLD COLLISION OBJECT
L45D3:  TYA
L45D4:  STA  $0369,X                ;NEW COLLISION OBJECT
L45D7:  CPY  TEMPA                  ;COMPARE OLD AND NEW
L45D9:  BEQ  CheckShieldConditionPossibly_90 ;DO NOT BOUNCE AGAIN
L45DB:  BIT  TOGCOMB
L45DD:  BPL  CheckShieldConditionPossibly_60 ;NOT THE PAIR
L45DF:  LDX  #$23
L45E1:  JSR  ReverseAngularMomentum

CheckShieldConditionPossibly_60:
L45E4:  JSR  CollisionBounce

CheckShieldConditionPossibly_90:
L45E7:  RTS

DestroyXShip:
L45E8:  STX  TEMP1                  ;FOR COMOWAY
L45EA:  JSR  Explosion              ;EXPLOSION SOUND
L45ED:  LDA  #$A0                   ;SET FULL EXPLOSION LENGTH
L45EF:  STA  OBJ,X
L45F1:  BIT  TOGCOMB                ;COMBINED LIVES??
L45F3:  BPL  DestroyXShip_60        ;NOT COMBINED LIVES
L45F5:  LDA  $0367,X
L45F8:  BMI  DestroyXShip_98        ;DAMAGED ALREADY????
L45FA:  LDY  $4D51,X                ;GET INDEX FOR OTHER SHIP
L45FD:  LDA  $0367,Y                ;DAMAGED
L4600:  BMI  DestroyXShip_98        ;YEP
L4602:  DEC  $0367,X                ;DAMAGE IT
L4605:  LDA  #$B8                   ;PARTIAL DAMAGE COUNT
L4607:  STA  $03CE,X                ;BOTH EXPLOSIONS
L460A:  STA  OBJ,X
L460C:  JSR  Expset                 ;INIT EXPLOSION PIECES
L460F:  JMP  DestroyXShip_62

DestroyXShip_98:
L4612:  LDA  #$00
L4614:  STA  $03CE,X                ;ONLY PIC_ECES
L4617:  LDA  SPARKTIME
L461A:  BPL  DestroyXShip_80        ;ALREADY STARTED DEATH
L461C:  DEC  SPARKTIME              ;START SPARKLE
L461F:  BNE  DestroyXShip_61        ;ALWAYS

DestroyXShip_60:
L4621:  LDA  GAME
L4623:  CMP  #$02
L4625:  BCC  DestroyXShip_62        ;GAMES 0 & 1 DON'T NEED THIS

DestroyXShip_61:
L4627:  BIT  ATSTG
L4629:  BMI  DestroyXShip_62        ;SKIP IF BLOCKS TOO
L462B:  LDX  #$20

DestroyXShip_66:
L462D:  LDA  OBJ,X
L462F:  BEQ  DestroyXShip_68
L4631:  LDA  XINC,X
L4634:  JSR  MinVelocity
L4637:  STA  XINC,X
L463A:  LDA  YINC,X
L463D:  JSR  MinVelocity
L4640:  STA  YINC,X

DestroyXShip_68:
L4643:  DEX
L4644:  BPL  DestroyXShip_66
L4646:  LDX  TEMP1
L4648:  LDA  #$FF                   ;MAY BE A DEC
L464A:  STA  SCRFUL                 ;GET ROCKS OFF SCREEN
L464C:  BNE  DestroyXShip_80        ;ALWAYS

DestroyXShip_62:
L464E:  LDY  TEMP3                  ;TEMP3 HOLDS ORIGINAL COLLISION X	;OR ELSE SHIP
L4650:  CPY  #$28
L4652:  LDA  #$00                   ;DEFAULT FOR WHOSHOT
L4654:  BCC  DestroyXShip_65
L4656:  LDA  #$E0                   ;START FLASHING TIME
L4658:  STA  OBJ,X
L465A:  STA  $03CE,X                ;ONLY FLASH'
L465D:  JSR  Expset
L4660:  LDX  TEMP1
L4662:  LDA  #$50                   ;FULL SHIP VALUE
L4664:  LDY  $0367,X
L4667:  BPL  DestroyXShip_63
L4669:  LDA  #$25                   ;CRIPPLED SHIP VALUE

DestroyXShip_63:
L466B:  JSR  AddPointsToScore
L466E:  LDX  TEMP1
L4670:  LDA  #$FF
L4672:  BNE  DestroyXShip_75        ;ALWAYS

DestroyXShip_65:
L4674:  DEC  $0367,X
L4677:  BMI  DestroyXShip_75        ;NOT AT LIMIT
L4679:  INC  $0367,X

DestroyXShip_75:
L467C:  STA  $039A,X

DestroyXShip_80:
L467F:  LDA  #$A0
L4681:  STA  $024C,X

DestroyXShip_90:
L4684:  JSR  RetargetComets         ;POINT ALL OF HIS AT THE OTHER GUY
L4687:  LDY  FOURPI
L4689:  JMP  SplitRockIntoFragments ;(EXIT)

GetCometToGo:
L468C:  LDY  #$07

GetCometToGo_10:
L468E:  LDA  COMTYP,Y
L4691:  ORA  #$01                   ;DIE AT EDGE OF SCREEN BIT
L4693:  STA  COMTYP,Y

GetCometToGo_30:
L4696:  DEY
L4697:  BPL  GetCometToGo_10
L4699:  LDA  GAME
L469B:  BEQ  GetCometToGo_40        ;NOT FOR TWO FIGHTERS
L469D:  LDA  #$FF
L469F:  STA  COMOFF                 ;SIGNIFY ONE SHIP HAS DIED.

GetCometToGo_40:
L46A2:  RTS

RetargetComets:
L46A3:  LDY  #$07
L46A5:  TXA
L46A6:  EOR  #$01                   ;POINT AT OTHER
L46A8:  TAX

RetargetComets_10:
L46A9:  LDA  CTARGET,Y
L46AC:  BEQ  RetargetComets_30      ;NOT ACTIVE
L46AE:  TXA                         ;RECALL NEW
L46AF:  STA  CTARGET,Y

RetargetComets_30:
L46B2:  DEY
L46B3:  BPL  RetargetComets_10
L46B5:  RTS

DifficultyTableLo:
L46B6:  .byte $E7, $2D, $7B, $B7

DifficultyTableHi:
L46BA:  .byte $46, $47, $47, $47

UpTheDifficulty:
L46BE:  LDX  OWNER
L46C1:  BPL  UpTheDifficulty_10
L46C3:  RTS                         ;(EXIT)

UpTheDifficulty_10:
L46C4:  INC  LMONHITS,X
L46C7:  BNE  UpTheDifficulty_20
L46C9:  INC  UMONHITS,X

UpTheDifficulty_20:
L46CC:  LDA  LMONHITS
L46CF:  CLC
L46D0:  ADC  $03D3
L46D3:  STA  TEMP1
L46D5:  LDA  UMONHITS
L46D8:  ADC  $03D5
L46DB:  STA  EACE
L46DD:  LDY  GAME                   ;GET GAME NUMBER
L46DF:  LDA  DifficultyTableHi,Y    ;LOW BYTE OF ADDRESS
L46E2:  PHA
L46E3:  LDA  DifficultyTableLo,Y    ;AND HIGH BYTE
L46E6:  PHA
L46E7:  RTS                         ;*********"JUMP" TO PROPER ROUTINE

Updif3:
L46E8:  LDA  UMONHITS,X
L46EB:  BNE  Updif3_20
L46ED:  LDA  LMONHITS,X
L46F0:  CMP  #$20
L46F2:  BCC  Updif3_30

Updif3_20:
L46F4:  INC  PROBCOMET,X
L46F7:  BPL  Updif3_30
L46F9:  DEC  PROBCOMET,X            ;HOLD AT 7F

Updif3_30:
L46FC:  LDA  UMONHITS,X
L46FF:  BNE  Updif3_50
L4701:  LDA  LMONHITS,X
L4704:  AND  #$07
L4706:  BNE  Updif3_50

Updif3_35:
L4708:  INC  DWFRMP,X
L470B:  BPL  Updif3_50              ;MAX IS 80
L470D:  DEC  DWFRMP,X

Updif3_50:
L4710:  LDA  LMONHITS,X
L4713:  CMP  #$03
L4715:  BNE  Updif3_60
L4717:  LDA  CometTable,X
L471A:  STA  COMSTART,X

Updif3_60:
L471D:  CLC
L471E:  LDA  LMONHITS
L4721:  ADC  LMONHITS               ;TOTAL HITS BETWEEN THEM
L4724:  AND  #$07                   ;EVERY 8 HITS....
L4726:  BNE  Updif3_80
L4728:  INC  COMLIMIT               ;...GET HARDER

Updif3_80:
L472B:  RTS

CometTable:
L472C:  .byte $14, $18

AloneGame1Player:
L472E:  LDA  UMONHITS,X
L4731:  BNE  AloneGame1Player_20
L4733:  LDA  LMONHITS,X
L4736:  CMP  #$20
L4738:  BCC  AloneGame1Player_30
L473A:  AND  #$01                   ;1 OF 2 AFTER 20
L473C:  BNE  AloneGame1Player_30

AloneGame1Player_20:
L473E:  INC  PROBCOMET,X
L4741:  BPL  AloneGame1Player_30
L4743:  DEC  PROBCOMET,X

AloneGame1Player_30:
L4746:  LDA  UMONHITS,X
L4749:  BNE  AloneGame1Player_50
L474B:  LDA  LMONHITS,X
L474E:  AND  #$07
L4750:  BNE  AloneGame1Player_50
L4752:  INC  DWFRMP,X
L4755:  BPL  AloneGame1Player_50
L4757:  DEC  DWFRMP,X               ;DON'T LET PAST 80

AloneGame1Player_50:
L475A:  LDA  LMONHITS,X
L475D:  CMP  #$04
L475F:  BEQ  AloneGame1Player_58
L4761:  CMP  #$0F
L4763:  BEQ  AloneGame1Player_58
L4765:  CMP  #$19
L4767:  BNE  AloneGame1Player_60

AloneGame1Player_58:
L4769:  INC  COMSTART
L476C:  INC  COMLIMIT

AloneGame1Player_60:
L476F:  LDA  UMONHITS,X
L4772:  BNE  AloneGame1Player_65
L4774:  LDA  LMONHITS,X
L4777:  CMP  #$28
L4779:  BCC  AloneGame1Player_65    ;NOT ENOUGHT

AloneGame1Player_65:
L477B:  RTS

Updif5:
L477C:  LDA  EACE
L477E:  BNE  Updif5_20
L4780:  LDA  TEMP1
L4782:  CMP  #$20
L4784:  BCC  Updif5_30

Updif5_20:
L4786:  INC  PROBCOMET,X
L4789:  BPL  Updif5_30
L478B:  DEC  PROBCOMET,X

Updif5_30:
L478E:  LDA  EACE
L4790:  BNE  Updif5_35
L4792:  LDA  TEMP1
L4794:  CMP  #$10
L4796:  BCC  Updif5_50              ;NOT ENOUGH
L4798:  AND  #$0F
L479A:  BNE  Updif5_50

Updif5_35:
L479C:  INC  DWFRMP,X
L479F:  BPL  Updif5_50              ;DON'T LET PAST 80
L47A1:  DEC  DWFRMP,X

Updif5_50:
L47A4:  LDA  EACE
L47A6:  BNE  Updif5_70              ;ALREADY UPPED
L47A8:  LDA  TEMP1
L47AA:  AND  #$0F                   ;EVERY 16 HITS...
L47AC:  BNE  Updif5_70
L47AE:  INC  COMLIMIT               ;...GET HARDER
L47B1:  INC  $03B5
L47B4:  INC  BCOMSTART

Updif5_70:
L47B7:  RTS

TwinGame1Player:
L47B8:  LDA  EACE
L47BA:  BNE  TwinGame1Player_20
L47BC:  LDA  TEMP1
L47BE:  CMP  #$20
L47C0:  BCC  TwinGame1Player_30

TwinGame1Player_20:
L47C2:  INC  PROBCOMET,X
L47C5:  BPL  TwinGame1Player_30
L47C7:  DEC  PROBCOMET,X

TwinGame1Player_30:
L47CA:  LDA  EACE
L47CC:  BNE  TwinGame1Player_35
L47CE:  LDA  TEMP1
L47D0:  CMP  #$10
L47D2:  BCC  TwinGame1Player_50     ;NOT ENOUGH
L47D4:  AND  #$0F
L47D6:  BNE  TwinGame1Player_50

TwinGame1Player_35:
L47D8:  INC  DWFRMP,X
L47DB:  BPL  TwinGame1Player_50     ;DON'T LET PAST 80
L47DD:  DEC  DWFRMP,X

TwinGame1Player_50:
L47E0:  LDA  EACE
L47E2:  BNE  TwinGame1Player_60     ;ALREADY UPPED
L47E4:  LDA  TEMP1
L47E6:  CMP  #$07
L47E8:  BNE  TwinGame1Player_54
L47EA:  INC  $03B5
L47ED:  INC  COMLIMIT

TwinGame1Player_54:
L47F0:  CMP  #$0F
L47F2:  BNE  TwinGame1Player_58
L47F4:  INC  BCOMSTART
L47F7:  INC  COMLIMIT

TwinGame1Player_58:
L47FA:  CMP  #$25
L47FC:  BNE  TwinGame1Player_60

TwinGame1Player_59:
L47FE:  INC  $03B5
L4801:  INC  COMLIMIT

TwinGame1Player_60:
L4804:  LDA  TEMP1
L4806:  BCC  TwinGame1Player_70     ;NOT ABOVE LAST LIMIT
L4808:  AND  #$07
L480A:  BNE  TwinGame1Player_70
L480C:  INC  COMLIMIT
L480F:  INC  $03B5
L4812:  INC  BCOMSTART

TwinGame1Player_70:
L4815:  RTS

BackAwayFromCollision:
L4816:  LDY  #$00                   ;SIGN EXTENSION
L4818:  LDA  XINC,X
L481B:  JSR  Comp
L481E:  BPL  BackAwayFromCollision_10
L4820:  DEY

BackAwayFromCollision_10:
L4821:  CLC
L4822:  ADC  OBJXL,X
L4825:  STA  OBJXL,X
L4828:  TYA
L4829:  ADC  OBJXH,X
L482C:  AND  #$1F                   ;SCREEN LIMIT
L482E:  STA  OBJXH,X
L4831:  LDY  #$00                   ;SIGN EXTENSION
L4833:  LDA  YINC,X
L4836:  JSR  Comp
L4839:  BPL  BackAwayFromCollision_20
L483B:  DEY
L483C:  CLC

BackAwayFromCollision_20:
L483D:  ADC  OBJYL,X
L4840:  STA  OBJYL,X
L4843:  TYA
L4844:  ADC  OBJYH,X
L4847:  BMI  BackAwayFromCollision_50 ;WENT BELOW BOTTOM
L4849:  CMP  #$18
L484B:  BCC  BackAwayFromCollision_60 ;STAYED ON SCREEN
L484D:  LDA  #$00
L484F:  BEQ  BackAwayFromCollision_60 ;ALWAYS

BackAwayFromCollision_50:
L4851:  LDA  #$17

BackAwayFromCollision_60:
L4853:  STA  OBJYH,X
L4856:  RTS

CollisionBounce:
L4857:  CPY  #$21
L4859:  BCS  CollisionBounce_91     ;NO BOUNCE
L485B:  BIT  SUPRSAC                ;SUPER SAUCER??
L485E:  BPL  CollisionBounce_10     ;NOPE
L4860:  CPY  #$20                   ;COTROLL SAUCER??
L4862:  BNE  CollisionBounce_10     ;NOPE!
L4864:  DEY                         ;PRETEND CONTROLL SAUCER!

CollisionBounce_10:
L4865:  JSR  SwitchVelocities
L4868:  LDA  XINC,Y
L486B:  CMP  #$04
L486D:  BCC  CollisionBounce_20
L486F:  CMP  #$FD
L4871:  BCC  CollisionBounce_50

CollisionBounce_20:
L4873:  LDA  OBJXL,X
L4876:  CMP  OBJXL,Y
L4879:  LDA  OBJXH,X
L487C:  SBC  OBJXH,Y
L487F:  LDA  #$FD
L4881:  BCS  CollisionBounce_30
L4883:  LDA  #$03

CollisionBounce_30:
L4885:  STA  XINC,Y

CollisionBounce_50:
L4888:  LDA  YINC,Y
L488B:  CMP  #$04
L488D:  BCC  CollisionBounce_55
L488F:  CMP  #$FD
L4891:  BCC  CollisionBounce_80

CollisionBounce_55:
L4893:  LDA  OBJYL,X
L4896:  CMP  OBJYL,Y
L4899:  LDA  OBJYH,X
L489C:  SBC  OBJYH,Y
L489F:  LDA  #$FD
L48A1:  BCS  CollisionBounce_60
L48A3:  LDA  #$03

CollisionBounce_60:
L48A5:  STA  YINC,Y

CollisionBounce_80:
L48A8:  CPY  #$1F
L48AA:  BCS  CollisionBounce_91     ;SAME OLD ANGLE FOR SAUCER
L48AC:  CPY  #$11
L48AE:  BCC  CollisionBounce_91
L48B0:  STX  TEMP5                  ;REMEMBER ENTERING X
L48B2:  LDX  XINC,Y
L48B5:  LDA  YINC,Y
L48B8:  TAY
L48B9:  JSR  PartSignedNumberExit
L48BC:  LDX  TEMP5
L48BE:  LDY  FOURPI
L48C0:  STA  $0282,Y
L48C3:  CPY  #$19
L48C5:  BCS  CollisionBounce_91
L48C7:  LDA  $0274,Y
L48CA:  LSR
L48CB:  LSR
L48CC:  STA  $0274,Y

CollisionBounce_91:
L48CF:  RTS

SwitchVelocities:
L48D0:  LDA  XINC,X
L48D3:  PHA
L48D4:  LDA  XINC,Y
L48D7:  STA  XINC,X
L48DA:  PLA
L48DB:  STA  XINC,Y
L48DE:  LDA  YINC,X
L48E1:  PHA
L48E2:  LDA  YINC,Y
L48E5:  STA  YINC,X
L48E8:  PLA
L48E9:  STA  YINC,Y
L48EC:  RTS

GetWrapAroundAngle:
L48ED:  LDA  OBJXH,Y
L48F0:  SEC
L48F1:  SBC  OBJXH,X
L48F4:  BMI  GetWrapAroundAngle_30  ;NEGATIVE
L48F6:  CMP  #$13                   ;3 FOR HYSTERRIS
L48F8:  BCC  GetWrapAroundAngle_50
L48FA:  SBC  #$20                   ;WRAP AROUND
L48FC:  BNE  GetWrapAroundAngle_50  ;ALWAYS

GetWrapAroundAngle_30:
L48FE:  CMP  #$ED
L4900:  BCS  GetWrapAroundAngle_50  ;OK AS IS
L4902:  ADC  #$20                   ;CARRY WAS CLEAR, WRAP AROUND

GetWrapAroundAngle_50:
L4904:  PHA                         ;PUT X DIFFERENCE ON STACK
L4905:  LDA  OBJYH,Y
L4908:  SEC
L4909:  SBC  OBJYH,X
L490C:  BMI  GetWrapAroundAngle_70  ;WAS NEGATIVE
L490E:  CMP  #$0E                   ;2 FOR HYSTERESIS
L4910:  BCC  GetWrapAroundAngle_80  ;ACCEPTABLE POSTIVE MOUNT
L4912:  SBC  #$17                   ;-1 SINCE CARRY CLEAR
L4914:  BNE  GetWrapAroundAngle_80

GetWrapAroundAngle_70:
L4916:  CMP  #$F2
L4918:  BCS  GetWrapAroundAngle_80
L491A:  ADC  #$18

GetWrapAroundAngle_80:
L491C:  JMP  NumeratorAtan

FindDifferenceCoordinates:
L491F:  LDA  OBJXH,Y
L4922:  SEC
L4923:  SBC  OBJXH,X
L4926:  PHA                         ;SAVE X DIFFERENCE ON STACK
L4927:  LDA  OBJYH,Y
L492A:  SEC
L492B:  SBC  OBJYH,X

NumeratorAtan:
L492E:  TAY                         ;NUMERATOR FOR ATAN
L492F:  PLA
L4930:  TAX                         ;DENOMINATOR FOR ATAN
L4931:  JMP  PartSignedNumberExit   ;(EXIT)

DoEnemy:
L4934:  JMP  CompetitiveWantWaitOther ;DO ENEMY

KillerMines:
L4937:  LDA  FRAME
L4939:  AND  #$3F                   ;1 OF 7 MINES MAX
L493B:  LSR                         ;DO ONLY ON EVEN FRAMES
L493C:  BCS  DoEnemy
L493E:  LSR
L493F:  BCS  DoEnemy                ;BOTTOM 2 BITS
L4941:  LSR
L4942:  BCC  DoEnemy                ;AND THIS BIT 1
L4944:  CMP  #$06
L4946:  BCS  DoEnemy
L4948:  ADC  #$19
L494A:  TAX
L494B:  LDA  OBJ,X
L494D:  BEQ  DoEnemy
L494F:  BMI  DoEnemy                ;EXPLODING COMET
L4951:  STX  TEMP3
L4953:  LDY  GTIME,X                ;SHIP TO TRACK REL TO OBJ

AccHoldsAngleObject:
L4956:  JSR  FindDifferenceCoordinates ;ACC HOLDS ANGLE TO OBJECT Y TO TRAM OBJECT X

Klmi7:
L4959:  LDX  TEMP3
L495B:  CPX  #$19
L495D:  BCS  Klmi7_20               ;WAS KILLERMINE
L495F:  TAY                         ;STORE ANGLE
L4960:  LDA  $037E,X                ;LOW BIT ON SAYS GO STRAIGHT
L4963:  LSR
L4964:  TYA                         ;RESTORE ANGLE FROM STACK
L4965:  BCC  Klmi7_25               ;NORMAL
L4967:  BCS  Klmi7_35               ;HEADED OFF

Klmi7_20:
L4969:  BIT  KLMOFF
L496B:  BMI  Klmi7_35               ;MINES GOING OFF SCREEN

Klmi7_25:
L496D:  SEC
L496E:  SBC  $0282,X
L4971:  ASL                         ;CARRY SET IF SHIP ON RIGHT
L4972:  LDA  $0274,X                ;ANGLE INCREMENT ALLOWED
L4975:  BCC  Klmi7_30
L4977:  EOR  #$FF
L4979:  ADC  #$00                   ;CARRY SET

Klmi7_30:
L497B:  CMP  #$80
L497D:  ROR
L497E:  ROR  TEMPA
L4980:  CMP  #$80
L4982:  ROR
L4983:  ROR  TEMPA
L4985:  TAY                         ;STORE UPPER BYTE ON STACK
L4986:  LDA  TEMPA
L4988:  CLC
L4989:  ADC  $0294,X
L498C:  STA  $0294,X
L498F:  TYA                         ;RECALL UPPER BYTE FROM STACK
L4990:  ADC  $0282,X
L4993:  STA  $0282,X

Klmi7_35:
L4996:  LDA  $0266,X
L4999:  CPX  #$19
L499B:  BCC  L49B5
L499D:  SBC  OBJ,X                  ;DIFFERENCE BETWEEN NOW & THEN
L499F:  BCS  L49AF
L49A1:  JSR  Comp
L49A4:  LSR
L49A5:  BNE  L49A9
L49A7:  LDA  #$01                   ;AT LEAST 1
L49A9:  ADC  $0266,X
L49AC:  JMP  L49B2
L49AF:  LDA  $0266,X                ;HOLD AT PRESENT
L49B2:  JMP  L49C8
L49B5:  CMP  OBJ,X
L49B7:  BCS  Ok1                    ;AT SPEED
L49B9:  ADC  #$04                   ;ELSE ADD 4 ALWAYS
L49BB:  CPX  #$15
L49BD:  BCC  L49C5
L49BF:  ADC  $039C                  ;SECOND PLAYER TARGETS
L49C2:  JMP  L49C8
L49C5:  ADC  DWFRMP
L49C8:  STA  $0266,X

Ok1:
L49CB:  STA  TEMP1                  ;MULTIPLIER IN MULTIPLY
L49CD:  LDA  $0282,X
L49D0:  JSR  CosSinPi2              ;RESULT IS X COMPONENT
L49D3:  JSR  OutputTemp2Temp21      ;MULTIPLY BY KSPEED
L49D6:  LDX  TEMP3
L49D8:  STA  XINC,X
L49DB:  LDA  $0282,X
L49DE:  JSR  PiAngle0               ;RESULT IS Y COMPONENT
L49E1:  JSR  OutputTemp2Temp21      ;MULTIPLYBY KSPEED
L49E4:  LDX  TEMP3                  ;IS THIS NEEDED?YES, SIN USES X
L49E6:  STA  YINC,X

CompetitiveWantWaitOther:
L49E9:  LDA  UPDFLG
L49EB:  AND  $39                    ;ATTRACT INITIALS?
L49ED:  BPL  CompetitiveWantWaitOther_90
L49EF:  LDA  FRAME
L49F1:  AND  #$03
L49F3:  BEQ  CompetitiveWantWaitOther_10
L49F5:  CMP  #$01
L49F7:  BEQ  CompetitiveWantWaitOther_90 ;NO ACTION
L49F9:  JMP  EnemyFireControl

CompetitiveWantWaitOther_90:
L49FC:  RTS

CompetitiveWantWaitOther_10:
L49FD:  LDA  FRAME                  ;MULTIPLE OF 4
L49FF:  AND  #$04
L4A01:  LSR
L4A02:  LSR
L4A03:  TAX                         ;X=0 OR 1
L4A04:  STA  TEMP1                  ;WHO OWNS THE ENEMY
L4A06:  BEQ  CompetitiveWantWaitOther_11 ;SAUCER 0 ALWAYS OK
L4A08:  BIT  SUPRSAC                ;SUPER SAUCER?
L4A0B:  BMI  CompetitiveWantWaitOther_90 ;SKIP #1 IF SUPER SAUCER

CompetitiveWantWaitOther_11:
L4A0D:  ADC  #$21                   ;CARRY CLEAR
L4A0F:  TAY                         ;MAYBE TEMP1+1 NOT NEEDED
L4A10:  LDA  GAME
L4A12:  CMP  #$01
L4A14:  BNE  CompetitiveWantWaitOther_12 ;NOT ALONE GAME
L4A16:  TXA
L4A17:  BEQ  CompetitiveWantWaitOther_12 ;IF X=0, THIS IS NORMAL
L4A19:  LDA  $45
L4A1B:  AND  #$E0
L4A1D:  BEQ  CompetitiveWantWaitOther_90 ;TOO EARLY (FOR THIS EXTRA TROUBLE)
L4A1F:  DEY                         ;AGAINST SINGLE PLAYER

CompetitiveWantWaitOther_12:
L4A20:  STY  EACE
L4A22:  LDA  OBSAUCER,X
L4A24:  BNE  CompetitiveWantWaitOther_18 ;SAUCER ENGAGED
L4A26:  LDA  ATRACT
L4A28:  BEQ  Scent5                 ;ACC=0, MEANS TARGET A ROCK
L4A2A:  LDA  RDELAY
L4A2D:  BNE  CompetitiveWantWaitOther_92

CompetitiveWantWaitOther_18:
L4A2F:  LDA  PRTDAMAGE,X
L4A32:  BPL  CompetitiveWantWaitOther_30 ;THIS SHIP IS WHOLE

CompetitiveWantWaitOther_22:
L4A34:  LDA  $4D51,Y
L4A37:  TAY
L4A38:  LDA  OBJ,Y                  ;OTHER SHIP.
L4A3B:  BEQ  CompetitiveWantWaitOther_30
L4A3D:  BMI  CompetitiveWantWaitOther_30
L4A3F:  STY  EACE                   ;OTHER SHIP ALIVE, GIVE HIM THE PROBLEMS

CompetitiveWantWaitOther_30:
L4A41:  LDY  EACE
L4A43:  LDA  OBJ,Y
L4A46:  BMI  CompetitiveWantWaitOther_90
L4A48:  BEQ  CompetitiveWantWaitOther_90
L4A4A:  BIT  TOGCOMB
L4A4C:  BPL  CompetitiveWantWaitOther_40 ;NOT THE PAIR
L4A4E:  LDA  RTIMER
L4A51:  ORA  $026C
L4A54:  BEQ  CompetitiveWantWaitOther_60 ;TIME
L4A56:  LDA  ENMDEL
L4A59:  ORA  $0266
L4A5C:  BEQ  CompetitiveWantWaitOther_60
L4A5E:  BNE  CompetitiveWantWaitOther_80

CompetitiveWantWaitOther_40:
L4A60:  LDA  GAME
L4A62:  BEQ  CompetitiveWantWaitOther_50 ;COMPET. GAME
L4A64:  LDA  RTIMER
L4A67:  BEQ  CompetitiveWantWaitOther_60
L4A69:  LDA  ENMDEL
L4A6C:  BEQ  CompetitiveWantWaitOther_60
L4A6E:  BNE  CompetitiveWantWaitOther_80

CompetitiveWantWaitOther_50:
L4A70:  LDA  RTIMER,X
L4A73:  BEQ  CompetitiveWantWaitOther_60
L4A75:  LDA  ENMDEL,X
L4A78:  BEQ  CompetitiveWantWaitOther_60

CompetitiveWantWaitOther_80:
L4A7A:  LDA  DIFCTY
L4A7C:  BEQ  CompetitiveWantWaitOther_92
L4A7E:  CMP  NROCKS
L4A81:  BCS  CompetitiveWantWaitOther_60

CompetitiveWantWaitOther_92:
L4A83:  RTS

CompetitiveWantWaitOther_60:
L4A84:  LDA  WAVE                   ;WAVE 1?
L4A87:  LSR
L4A88:  BEQ  Scent5                 ;ROCK DIRECTED SAUCER ALWAYS
L4A8A:  LDA  $100A
L4A8D:  AND  #$07
L4A8F:  CMP  #$01
L4A91:  BCC  Scent5                 ;ROCK DIRECTED SAUCER
L4A93:  CMP  #$03
L4A95:  BCS  SaucerEntry            ;NORMAL SAUCER
L4A97:  LDA  NROCKS
L4A9A:  BEQ  CompetitiveWantWaitOther_92
L4A9C:  JMP  InitializeComet

SaucerEntry:
L4A9F:  LDA  EACE

Scent5:
L4AA1:  LDY  OBSAUCER,X
L4AA3:  BEQ  Scent5_1

Scent5_100:
L4AA5:  RTS

Scent5_1:
L4AA6:  STA  ETARGET,X              ;OVERRIDES EXISTING TARGET
L4AA9:  LDA  ETIMER,X
L4AAC:  BNE  Scent5_100
L4AAE:  LDA  $03BA
L4AB1:  BMI  Scent5_6               ;HE DAWDLED, ENTER SAUCER DESPITE ROCKS
L4AB3:  LDY  NROCKS
L4AB6:  CPY  #$08
L4AB8:  BCS  Scent5_100
L4ABA:  LDA  GAME
L4ABC:  BEQ  Scent5_6
L4ABE:  LDA  OBSAUCER
L4AC0:  ORA  $B7
L4AC2:  BEQ  Scent5_6
L4AC4:  LDA  UMONHITS,X
L4AC7:  BNE  Scent5_6
L4AC9:  LDA  LMONHITS,X
L4ACC:  CMP  #$3C
L4ACE:  BCC  Scent5_100

Scent5_6:
L4AD0:  LDA  $140A                  ;RANDOM NUMBER
L4AD3:  AND  #$40                   ;SELECT PIC
L4AD5:  ORA  #$01                   ;ACTIVATE OBJECT
L4AD7:  STA  OBSAUCER,X
L4AD9:  CPX  #$00                   ;ONLY FOR SAUCER 0
L4ADB:  BNE  Scent5_7
L4ADD:  LDY  #$00                   ;GUESS REGULAR SAUCER
L4ADF:  LDA  $B7                    ;SAUCER 1 ACTIVE??
L4AE1:  BNE  Scent5_3               ;IF YES, NO SUPERSAUCER
L4AE3:  LDA  $140A                  ;*****TEMP DEC MAKER *****
L4AE6:  AND  #$01
L4AE8:  BNE  Scent5_3
L4AEA:  LDA  COMTIMER               ;ONSLAUGHT??
L4AED:  BNE  Scent5_3               ;NO SUPER DURING ONSLAUGHT
L4AEF:  LDA  DIFCTY                 ;DIFCTY AT 3??
L4AF1:  CMP  #$03
L4AF3:  BCC  Scent5_3               ;DON'T ALLOW TILL WAVE 3 AT LEAST
L4AF5:  LDA  #$41
L4AF7:  STA  OBSAUCER               ;ALWAYS THIS PIC
L4AF9:  LDY  #$80                   ;SET TO SUPER SAUCER

Scent5_3:
L4AFB:  STY  SUPRSAC

Scent5_7:
L4AFE:  LDA  #$00
L4B00:  STA  $033F,X
L4B03:  STA  $02D4,X
L4B06:  STA  $0371,X
L4B09:  LDA  $100A                  ;RANDOM NUMBER
L4B0C:  STA  TEMPA
L4B0E:  AND  #$1F                   ;APPROX 1 SCREEN
L4B10:  CMP  #$18
L4B12:  BCC  Scent5_10              ;MUST BE 0 TO 767
L4B14:  AND  #$17

Scent5_10:
L4B16:  BIT  SUPRSAC
L4B19:  BPL  Scent5_15              ;NOT SUPRESAUCER
L4B1B:  AND  #$03                   ;PREVENT WRAP ON START

Scent5_15:
L4B1D:  STA  $0306,X                ;STARTING VERTICAL POSITION
L4B20:  INC  $0306,X                ;1TO 3 MINIUM START
L4B23:  LDA  WAVE
L4B26:  LSR
L4B27:  LSR                         ;WAVE #/4
L4B28:  TAY
L4B29:  CPY  #$04
L4B2B:  BCC  Scent5_16
L4B2D:  LDY  #$04

Scent5_16:
L4B2F:  LDA  Sspos,Y                ;GET MIN POS SAUCER SPEED
L4B32:  BIT  TEMPA                  ;ORIGINAL RANDOM NUMBER
L4B34:  BVS  Scent5_20              ;PICK DIRECTION
L4B36:  LDA  #$1F
L4B38:  STA  $02D4,X
L4B3B:  DEC  $033F,X                ;START ON RIGHT SIDE
L4B3E:  LDA  Ssminus,Y              ;MIN NEG SPEED

Scent5_20:
L4B41:  LDY  SCSHSP,X               ;THIS GUY SHOOTING FAST?
L4B44:  STA  SAUMIN,X
L4B46:  BIT  SUPRSAC                ;SUPER SAUCER?
L4B49:  BPL  Scent5_25              ;NOPE
L4B4B:  ASL                         ;MOVE 2 TIMES SPEED

Scent5_25:
L4B4C:  STA  $021F,X
L4B4F:  CLC
L4B50:  LDA  DIFCTY                 ;GET STARTING DISTANCE
L4B52:  ADC  #$04                   ;MIN DISTANCE (THIS MAXES AT 9)
L4B54:  STA  SUPRDIS
L4B57:  LDA  #$3C                   ;SHOULD BE ONE SCREEN WIDTHS DELAY
L4B59:  STA  ETIMER,X

ResetTimers:
L4B5C:  LDX  TEMP1

Hasent:
L4B5E:  LDA  SENMDEL,X
L4B61:  STA  ENMDEL,X
L4B64:  LDA  MXRTIMER,X
L4B67:  LSR
L4B68:  LSR
L4B69:  CMP  RTIMER,X
L4B6C:  BCC  Efirex
L4B6E:  STA  RTIMER,X

Efirex:
L4B71:  RTS

AngleShoot:
L4B72:  .byte $40, $C0

EnemyFireControl:
L4B74:  SBC  #$02                   ;CARRY WAS SET
L4B76:  TAX                         ;X NOW 0 OR 1
L4B77:  STX  TEMP3
L4B79:  LDA  FRAME
L4B7B:  AND  #$F0                   ;LAST TWO BITS SORT OF KNOW
L4B7D:  ASL
L4B7E:  BNE  EnemyFireControl_10    ;NOT TIME TO CHANGE DIRECTION
L4B80:  LDA  $100A
L4B83:  AND  #$03
L4B85:  TAY
L4B86:  LDA  DifferentSaucerVelocities,Y ;VERTICAL SAUCER VELOCITIES
L4B89:  STA  $0251,X

EnemyFireControl_10:
L4B8C:  BIT  $03BA
L4B8F:  BMI  EnemyFireControl_30    ;HE DAWDLED, NOT CARE ABOUT ROCKS
L4B91:  LDA  NROCKS
L4B94:  CMP  #$0A
L4B96:  BCS  Efirex                 ;NOT ENOUGH TIME FOR COLLISIONS

EnemyFireControl_30:
L4B98:  DEC  EDELAY,X
L4B9B:  BEQ  EnemyFireControl_50    ;NOT TIME TO SHOOT

EnemyFireControl_40:
L4B9D:  RTS                         ;EXIT

EnemyFireControl_50:
L4B9E:  BIT  SUPRSAC                ;SUPER SAUCER??
L4BA1:  BPL  EnemyFireControl_51    ;NOPE
L4BA3:  LDA  AngleShoot,X
L4BA6:  STA  ANGLE,X                ;FORCE ANGLE
L4BA9:  LDA  SUPRTIM                ;AND SET SHOOT DELAY TIMER BASED ON DISTANCE
L4BAC:  STA  EDELAY,X
L4BAF:  JMP  StartLookingHere

EnemyFireControl_51:
L4BB2:  LDA  #$10                   ;WAS 10. CHEAP WAY TO LIMIT SOTS
L4BB4:  LDY  SCSHSP,X               ;FAST SHOTS??
L4BB7:  BPL  EnemyFireControl_55    ;NO DAWDLE
L4BB9:  LDA  #$09                   ;CAN SHOOT TWO

EnemyFireControl_55:
L4BBB:  STA  EDELAY,X               ;DELAY BEFORE NEXT SHOT

Efire3:
L4BBE:  LDY  ETARGET,X
L4BC1:  CPY  #$10
L4BC3:  BCS  Efire3_50
L4BC5:  LDY  #$11

Efire3_10:
L4BC7:  LDA  OBJ,Y
L4BCA:  BEQ  Efire3_20
L4BCC:  BPL  Efire3_40

Efire3_20:
L4BCE:  DEY
L4BCF:  BNE  Efire3_10

Efire3_40:
L4BD1:  TYA
L4BD2:  STA  ETARGET,X

Efire3_50:
L4BD5:  LDA  OBSAUCER,X
L4BD7:  BMI  Efirex                 ;DEAD
L4BD9:  BEQ  Efirex                 ;GONE
L4BDB:  LDA  OBJ,Y
L4BDE:  BEQ  Efirex                 ;TARGET DEAD
L4BE0:  BMI  Efirex                 ;TARGET GONE
L4BE2:  LDA  $021F,X                ;BEGIN SIGNED DIVIDE BY TWO
L4BE5:  CMP  #$80
L4BE7:  ROR
L4BE8:  STA  POTGO                  ;(XINC/2)
L4BEA:  LDA  OBJXL,Y                ;GET X DISTANCE TO SAUCER
L4BED:  SEC
L4BEE:  SBC  $033F,X
L4BF1:  STA  TEMP2
L4BF3:  LDA  OBJXH,Y
L4BF6:  SBC  $02D4,X
L4BF9:  ASL  TEMP2
L4BFB:  ROL
L4BFC:  ASL  TEMP2
L4BFE:  ROL                         ;-7F TO +7F
L4BFF:  SEC                         ;REMEMBER TORPEDO VELOCITY DEPENDS ON
L4C00:  SBC  POTGO                  ;SAUCER SPEED
L4C02:  PHA                         ;SAVE DENOMINATOR FOR ARC TANGENT
L4C03:  LDA  $0251,X
L4C06:  CMP  #$80
L4C08:  ROR
L4C09:  STA  POTGO
L4C0B:  LDA  OBJYL,Y
L4C0E:  SEC
L4C0F:  SBC  $0371,X
L4C12:  STA  TEMP2
L4C14:  LDA  OBJYH,Y
L4C17:  SBC  $0306,X
L4C1A:  ASL  TEMP2
L4C1C:  ROL
L4C1D:  ASL  TEMP2
L4C1F:  ROL                         ;-5F TO +5F
L4C20:  SEC
L4C21:  SBC  POTGO                  ;REMEMBER TO ACCOUNT FOR OUR MOTION
L4C23:  TAY                         ;-60 TO +60
L4C24:  PLA
L4C25:  TAX                         ;RESTORED DENOMINATOR FOR ATAN
L4C26:  JSR  PartSignedNumberExit   ;ARCTAN (Y/X)
L4C29:  LDX  TEMP3
L4C2B:  STA  ANGLE,X
L4C2E:  LDY  $45
L4C30:  CPY  #$30                   ;UNITS OF ABOUT 4 SECONDS
L4C32:  LDA  $100A                  ;RANDOM WCOMBER
L4C35:  AND  #$0F
L4C37:  BCC  Efire3_90              ;IF NOT TO LIMIT YET
L4C39:  LSR                         ;MORE ACCURRACY

Efire3_90:
L4C3A:  BIT  $140A
L4C3D:  BPL  Efire3_95
L4C3F:  EOR  #$FF                   ;INVERT

Efire3_95:
L4C41:  ADC  ANGLE,X                ;DONT BE TOO GOOD-JUST CLOSE

Efire3_96:
L4C44:  STA  ANGLE,X                ;ANGLE TO AIM

StartLookingHere:
L4C47:  LDY  StartingValues,X       ;START LOOKING HERE
L4C4A:  LDA  StoppingValues,X       ;FIRE FOR SAUCER
L4C4D:  STA  FOURPI                 ;2 SAUCER TORPEDOS FOR EACH SAUCER
L4C4F:  LDA  SCSHSP,X
L4C52:  ORA  SUPRSAC                ;OR SUPERSAUCER
L4C55:  BPL  FastSlow               ;NO DAWDLE
L4C57:  LDA  #$80                   ;FAST FOR DWADLED

FastSlow:
L4C59:  STA  TEMP2                  ;FAST OR SLOW
L4C5B:  JMP  Temp280Fast0           ;FIRE A TORPEDO

StartingValues:
L4C5E:  .byte $25, $27

StoppingValues:
L4C60:  .byte $23, $25

DifferentSaucerVelocities:
L4C62:  .byte $F0, $F8, $08, $10

Sspos:
L4C66:  .byte $10, $18, $20, $28, $30

Ssminus:
L4C6B:  .byte $F0, $E8, $E0, $D8, $D0

FireShipsTorpedos:
L4C70:  BIT  ATRACT
L4C72:  BMI  FireShipsTorpedos_10
L4C74:  LDA  $100A
L4C77:  JMP  FireShipsTorpedos_11

FireShipsTorpedos_10:
L4C7A:  LDA  HYPSW,X                ;BIT 6 ON WHEN PUSHED

FireShipsTorpedos_11:
L4C7D:  ASL
L4C7E:  ASL
L4C7F:  ROR  LASTSW,X               ;??? CONFLICT
L4C81:  BPL  Fire2                  ;IF NOT ON
L4C83:  LDA  LASTSW,X
L4C85:  ASL
L4C86:  BMI  Fire2                  ;WAS ON LAST TIME
L4C88:  BIT  TOGDRONE
L4C8A:  BPL  FireShipsTorpedos_20   ;NOT DRONE GAME
L4C8C:  JSR  FireShipsTorpedos_20
L4C8F:  LDX  #$01

FireShipsTorpedos_20:
L4C91:  LDA  OBSHIP,X
L4C93:  BEQ  Fire2                  ;DEAD
L4C95:  BMI  Fire2                  ;EXPLODING
L4C97:  LDA  TOGGLE,X
L4C99:  AND  #$80
L4C9B:  BNE  Fire2                  ;SHIELDS ON

FireShipsTorpedos_50:
L4C9D:  INX                         ;X=1 OR 2
L4C9E:  INX
L4C9F:  STX  TEMP3                  ;X= 2 OR 3 FOR 'FIRE3' ROUTINE
L4CA1:  LDA  #$80
L4CA3:  STA  TEMP2
L4CA5:  LDA  StartingSearchEmptyMine,X
L4CA8:  STA  FOURPI                 ;STOPPING INDEX FOR SHIP
L4CAA:  LDY  $4D69,X                ;STARTING INDEX
L4CAD:  LDA  BXINCL,X
L4CB0:  BEQ  Temp280Fast0           ;STARTING VALUE WHEN DAMAGED
L4CB2:  LDY  EndingSearchEmptyMine,X

Temp280Fast0:
L4CB5:  LDA  OBJ,Y
L4CB8:  BEQ  Fire3                  ;WE FOUND INACTIVE ONE
L4CBA:  DEY
L4CBB:  CPY  FOURPI
L4CBD:  BNE  Temp280Fast0           ;TRY NEXT ONE

Fire2:
L4CBF:  RTS

Fire3:
L4CC0:  LDA  #$12
L4CC2:  BIT  TEMP2
L4CC4:  BMI  Fire3_10               ;FAST SOT
L4CC6:  ASL

Fire3_10:
L4CC7:  STA  OBJ,Y                  ;SET TIMER FOR LENGTH OF LIFE
L4CCA:  LDA  ANGLE,X
L4CCD:  JSR  CosSinPi2              ;COS(ANGLE)-SHIPS SPEED=X CHANGE TO TORPEDO
L4CD0:  CMP  #$80                   ;DIVIDE BY 2
L4CD2:  ROR                         ;SS999.BBB
L4CD3:  BIT  TEMP2
L4CD5:  BMI  Fire3_15               ;FAST SHOT
L4CD7:  CMP  #$80
L4CD9:  ROR                         ;DIVIDE AGAIN

Fire3_15:
L4CDA:  STA  EACE
L4CDC:  CLC
L4CDD:  LDX  TEMP3
L4CDF:  ADC  $021F,X
L4CE2:  BMI  Fire3_23               ;IF NEGATVE
L4CE4:  CMP  #$70
L4CE6:  BCC  Fire3_30               ;IF MAX NOT EXCEEDED
L4CE8:  LDA  #$6F
L4CEA:  BNE  Fire3_30               ;ALWAYS

Fire3_23:
L4CEC:  CMP  #$91
L4CEE:  BCS  Fire3_30               ;IF MIN NOT EXCEEDED
L4CF0:  LDA  #$91

Fire3_30:
L4CF2:  STA  XINC,Y                 ;SET X SPEED
L4CF5:  LDA  ANGLE,X                ;SHIP'S ANGLE FOLLOWS SAUCER'S
L4CF8:  JSR  PiAngle0               ;SIN (ANGLE)
L4CFB:  CMP  #$80                   ;DIVIDE BY 2
L4CFD:  ROR                         ;SSAAA.BBB
L4CFE:  BIT  TEMP2
L4D00:  BMI  Fire3_32               ;FAST SOT
L4D02:  CMP  #$80
L4D04:  ROR

Fire3_32:
L4D05:  STA  POTGO
L4D07:  LDX  TEMP3
L4D09:  CLC
L4D0A:  ADC  $0251,X
L4D0D:  BMI  Fire3_33               ;IF NEGATIVE
L4D0F:  CMP  #$70
L4D11:  BCC  Fire3_40               ;IF IN RANGE
L4D13:  LDA  #$6F                   ;SET MAX
L4D15:  BNE  Fire3_40               ;ALWAYS

Fire3_33:
L4D17:  CMP  #$91
L4D19:  BCS  Fire3_40               ;IF IN RANGE
L4D1B:  LDA  #$91

Fire3_40:
L4D1D:  STA  YINC,Y
L4D20:  LDA  EACE                   ;SCALE TO PUT TORP AT NOSE OF SHIP
L4D22:  CMP  #$80
L4D24:  ROR
L4D25:  CLC
L4D26:  ADC  EACE                   ;MULTIPLY BY 3/2
L4D28:  CLC
L4D29:  ADC  $033F,X                ;ADD SHIPS POSITION TO GET STARTING POSITION
L4D2C:  STA  OBJXL,Y
L4D2F:  LDA  #$00
L4D31:  ADC  $02D4,X
L4D34:  BIT  EACE                   ;TEST SIGN
L4D36:  BPL  Fire3_45               ;WAS POSITIVE
L4D38:  CLC
L4D39:  ADC  #$FF                   ;CARRY CLEAR UNLESS ALLOW NEGATIVE

Fire3_45:
L4D3B:  STA  OBJXH,Y
L4D3E:  LDA  POTGO                  ;SCALE AGAIN TO PUT AT NOSE
L4D40:  CMP  #$80
L4D42:  ROR
L4D43:  CLC
L4D44:  ADC  POTGO                  ;MULTIPLY BY 3/2
L4D46:  CLC
L4D47:  ADC  $0371,X                ;ADD SHIPS POSITION TO GET STARTING POSITION
L4D4A:  STA  OBJYL,Y
L4D4D:  LDA  #$00
L4D4F:  ADC  $0306,X
L4D52:  BIT  POTGO                  ;TEST SIGN
L4D54:  BPL  Fire3_50               ;WAS POSITIVE
L4D56:  CLC
L4D57:  ADC  #$FF                   ;PERHAPS NOT NEEDED

Fire3_50:
L4D59:  STA  OBJYH,Y
L4D5C:  CPX  #$02
L4D5E:  BCS  Fire3_60
L4D60:  JMP  SaucerFire             ;JSR & RETURN

Fire3_60:
L4D63:  BNE  Fire3_65               ;WHICH SHIP?
L4D65:  JMP  Player0Fire            ;PLAYER 0

Fire3_65:
L4D68:  JMP  Player1Fire            ;PLAYER 1

StartingSearchEmptyMine:
L4D6B:  .byte $2B, $2F

EndingSearchEmptyMine:
L4D6D:  .byte $27, $2B

EndingDamaged:
L4D6F:  .byte $28, $2C

L01ZshipZship:
L4D71:  .byte $21

Revship:
L4D72:  .byte $22, $21

Getin4:
L4D74:  LDA  #$E0
L4D76:  LDX  #$48
L4D78:  JSR  Mesgpos
L4D7B:  LDX  #$01
L4D7D:  JSR  AuxRoutineAddOffset
L4D80:  LDY  #$02
L4D82:  JSR  VectorGeneratorMessageProcessor ;DISPLAY MESSAGE 2 - INSTRUCTIONS
L4D85:  LDA  #$B3
L4D87:  LDX  #$38
L4D89:  JSR  Mesgpos
L4D8C:  LDX  #$02
L4D8E:  JSR  AuxRoutineAddOffset
L4D91:  LDY  #$03
L4D93:  JSR  VectorGeneratorMessageProcessor
L4D96:  LDA  #$AA
L4D98:  LDX  #$2E
L4D9A:  JSR  Mesgpos
L4D9D:  LDX  #$03
L4D9F:  JSR  AuxRoutineAddOffset
L4DA2:  LDY  #$04
L4DA4:  JSR  VectorGeneratorMessageProcessor
L4DA7:  LDA  #$96
L4DA9:  LDX  #$24
L4DAB:  JSR  Mesgpos
L4DAE:  LDX  #$04
L4DB0:  JSR  AuxRoutineAddOffset
L4DB3:  LDY  #$05
L4DB5:  JSR  VectorGeneratorMessageProcessor ;(END MESSAGE)
L4DB8:  LDA  #$C2
L4DBA:  LDX  #$80                   ;BALANCE DISPLAY
L4DBC:  JSR  UpdownVectorUpsideDown
L4DBF:  LDA  #$96
L4DC1:  LDX  #$00
L4DC3:  JSR  UpdownVectorUpsideDown
L4DC6:  LDA  #$6A
L4DC8:  LDX  #$00
L4DCA:  JMP  UpdownVectorUpsideDown ;FULL BALANCE

GetPlayersInitials:
L4DCD:  LDA  UPDFLG
L4DCF:  AND  $39
L4DD1:  BPL  PutMessageUpOnce       ;GET PLAYERS INITIALS
L4DD3:  LDA  #$00
L4DD5:  STA  HSCFLG

Getin2:
L4DD8:  RTS

PutMessageUpOnce:
L4DD9:  LDA  $45
L4DDB:  BMI  PutMessageUpOnce_5     ;CONTINUE
L4DDD:  BNE  Getin2                 ;NOT DOING THIS
L4DDF:  LDA  #$FF
L4DE1:  STA  UPDFLG
L4DE3:  STA  $39                    ;DONE DOING THIS TOO
L4DE5:  JMP  PreventTimeoutBothPlayers ;FINISH EXIT PROCEDURE

PutMessageUpOnce_5:
L4DE8:  LDA  CABERE
L4DEB:  BMI  L4DF0
L4DED:  JSR  Getin4
L4DF0:  LDX  #$01
L4DF2:  STX  TEMP5
L4DF4:  JSR  Getin6
L4DF7:  LDX  #$00
L4DF9:  STX  TEMP5

Getin6:
L4DFB:  LDA  UPDFLG,X
L4DFD:  BMI  Getin2                 ;TO RTS
L4DFF:  LDA  CABERE
L4E02:  BPL  L4E0D
L4E04:  LDA  Updowtable,X
L4E07:  STA  UPDOWN
L4E0A:  JSR  Getin4
L4E0D:  JSR  CenterBeamInMiddle
L4E10:  LDA  #$00                   ;DOUBLE SIZE
L4E12:  JSR  UseFullSize
L4E15:  BIT  CABERE                 ;CABERET CAB?
L4E18:  BVS  Getin6_21              ;YEP
L4E1A:  LDA  CABERE                 ;COCKTAIL TABLE?
L4E1D:  BPL  Getin6_25              ;IF NO, SKIP THIS

Getin6_21:
L4E1F:  LDA  #$F0                   ;C  POSITION FOR FLIPPED DISPLAY
L4E21:  LDX  #$08
L4E23:  LDY  TEMP5                  ;D WHICH PLAYER?
L4E25:  BEQ  Getin6_30
L4E27:  LDA  #$00                   ;C SET FOR PLAYER 1
L4E29:  BEQ  Getin6_30              ;*******ALWAYS********

Getin6_25:
L4E2B:  LDA  #$14
L4E2D:  LDX  #$04
L4E2F:  LDY  TEMP5
L4E31:  BEQ  Getin6_30
L4E33:  LDA  #$D8                   ;SECOND PLAYER

Getin6_30:
L4E35:  JSR  UpdownVectorUpsideDown ;POSITION BEAM
L4E38:  LDX  TEMP5
L4E3A:  LDY  UPDFLG,X
L4E3C:  STY  TEMP2
L4E3E:  TYA
L4E3F:  CLC
L4E40:  ADC  UPDINT,X
L4E42:  STA  POTGO                  ;INDEX FOR THE INITIAL WE ARE WORKING ON
L4E44:  JSR  DisplayAnInitial       ;DISPLAY INITIAL
L4E47:  LDY  TEMP2
L4E49:  INY
L4E4A:  JSR  DisplayAnInitial       ;DISPLAY INITIAL
L4E4D:  LDY  TEMP2
L4E4F:  INY
L4E50:  INY
L4E51:  JSR  DisplayAnInitial       ;DISPLAY THIRD INITIAL

Getin6_50:
L4E54:  LDX  TEMP5                  ;ONLY
L4E56:  LDA  HYPSW,X                ;BIT 6 HERE
L4E59:  ROL                         ;INTO BIT 7....
L4E5A:  ORA  HYPSW,X
L4E5D:  ORA  STRT1,X                ;WANT ANY BUTTON TO ENTER
L4E60:  ROL                         ;GET SWITCH INTO CARRY SPOT
L4E61:  ROL  LASTSW,X               ;SWITCH DEBOUNCE
L4E63:  LDA  LASTSW,X
L4E65:  AND  #$1F
L4E67:  CMP  #$07                   ;ON EXACTLY THE LAST THREE OF LAST FIVE
L4E69:  BNE  Getstp                 ;NOT A VALID SWITCH
L4E6B:  INC  UPDINT,X               ;ADVANCE TO NEXT LETTER
L4E6D:  LDA  UPDINT,X
L4E6F:  CMP  #$03
L4E71:  BCC  Gotit                  ;IF WE ARE NOT DONE
L4E73:  LDA  #$FF
L4E75:  STA  UPDFLG,X               ;CLEAR UPDATING FLAG
L4E77:  CPX  #$01
L4E79:  BNE  PreventTimeoutBothPlayers
L4E7B:  STA  SPFLG                  ;CLEAR THIS ONE ALSO

PreventTimeoutBothPlayers:
L4E7E:  LDX  #$F1                   ;PREVENT TIMEOUT IF BOTH PLAYERS SET HIGH SCORE
L4E80:  STX  $45                    ;BRING UP HIGH SCORE TABLE NEXT
L4E82:  LDA  UPDFLG
L4E84:  AND  $39
L4E86:  BPL  L4E9C
L4E88:  STX  SHHIGH                 ;SET SHOW SCORE FLAGS
L4E8B:  STA  HALT                   ;FORCE HALT FOR NEXT
L4E8E:  JSR  InitializeScoreHeadings ;REINIT AREAS
L4E91:  JSR  TransferHighScoresBuffer ;MOVE SCORES TO BUFFER
L4E94:  JSR  WriteHighScoresInitials ;START UPDATE OF EA ROM
L4E97:  JSR  Bigbang                ;REMOVE ALL OLD EXPLOSIONS
L4E9A:  SEC                         ;DONE FLAG
L4E9B:  RTS
L4E9C:  CLC
L4E9D:  RTS                         ;(EXIT)

Gotit:
L4E9E:  LDX  POTGO
L4EA0:  LDA  #$F4                   ;ABOUT 64 SECONDS
L4EA2:  STA  $45                    ;RESET TIMEOUT
L4EA4:  LDA  TEMP5                  ;PLAYER 2?
L4EA6:  BEQ  Gotit_58               ;NO
L4EA8:  BIT  SPFLG                  ;DOING SPECIAL INITIALS
L4EAB:  BMI  Gotit_58               ;NO
L4EAD:  LDA  #$0B
L4EAF:  STA  $0138,X                ;INIT NEXT TO A
L4EB2:  RTS

Gotit_58:
L4EB3:  LDA  #$0B
L4EB5:  STA  $011A,X                ;SET INITIAL TO A
L4EB8:  RTS

Getstp:
L4EB9:  LDA  FRAME
L4EBB:  AND  #$07
L4EBD:  BNE  Getstp_90              ;EVERY 8TH FRAME
L4EBF:  LDY  #$FF                   ;ASSUME LETTERS GO DOWN
L4EC1:  LDA  ROTL,X
L4EC4:  BMI  Getstp_75              ;ROTATING LEFT

Getstp_70:
L4EC6:  LDA  ROTL,X
L4EC9:  ASL
L4ECA:  BPL  Getstp_90              ;NOT ROTATING RIGHT
L4ECC:  LDY  #$01

Getstp_75:
L4ECE:  TYA
L4ECF:  LDX  TEMP5
L4ED1:  BEQ  Getstp_76              ;NOT PLAYER 2
L4ED3:  BIT  SPFLG                  ;SPECIAL PLAYER 2?
L4ED6:  BMI  Getstp_76              ;NO
L4ED8:  LDX  POTGO                  ;COPY BELOW PROCEDUR
L4EDA:  CLC
L4EDB:  ADC  $0137,X
L4EDE:  BMI  Getstp_88
L4EE0:  CMP  #$0B
L4EE2:  BCS  Getstp_10
L4EE4:  LSR
L4EE5:  BNE  Getstp_13
L4EE7:  LDA  #$0B
L4EE9:  BNE  Getstp_15

Getstp_88:
L4EEB:  LDA  #$24

Getstp_10:
L4EED:  CMP  #$25
L4EEF:  BCC  Getstp_15

Getstp_13:
L4EF1:  LDA  #$00

Getstp_15:
L4EF3:  STA  $0137,X
L4EF6:  LDA  #$00
L4EF8:  RTS

Getstp_76:
L4EF9:  LDX  POTGO
L4EFB:  CLC
L4EFC:  ADC  INITL,X                ;CHANGE INITIAL
L4EFF:  BMI  Getstp_78              ;BEFORE A BLANK MUST BE Z
L4F01:  CMP  #$0B
L4F03:  BCS  Getstp_80              ;IF GREATER THAN A
L4F05:  LSR
L4F06:  BNE  Getstp_83
L4F08:  LDA  #$0B                   ;A
L4F0A:  BNE  Getstp_85              ;ALWAYS

Getstp_78:
L4F0C:  LDA  #$24                   ;MAKE IT A Z

Getstp_80:
L4F0E:  CMP  #$25
L4F10:  BCC  Getstp_85              ;LESS THAN Z

Getstp_83:
L4F12:  LDA  #$00                   ;BACK TO BLANK

Getstp_85:
L4F14:  STA  INITL,X

Getstp_90:
L4F17:  LDA  #$00                   ;MUST BE POSITIVE ON RETURN IS THIS NEEDED?
L4F19:  RTS

Updowtable:
L4F1A:  .byte $00, $80

Shpplace:
L4F1C:  LDA  $100A
L4F1F:  AND  #$0F
L4F21:  CPX  #$00
L4F23:  BNE  Shpplace_1
L4F25:  ORA  #$10

Shpplace_1:
L4F27:  CMP  #$1B                   ;STAY AWAY FROM THE EDGE
L4F29:  BCC  Shpplace_2
L4F2B:  LDA  #$1A

Shpplace_2:
L4F2D:  CMP  #$05
L4F2F:  BCS  Shpplace_4             ;STAY AWAY FROM THE EDGE
L4F31:  LDA  #$05

Shpplace_4:
L4F33:  STA  $02D6,X
L4F36:  LDA  $100A
L4F39:  AND  #$1F

Shpplace_10:
L4F3B:  CMP  #$13
L4F3D:  BCC  Shpplace_12            ;STAY AWAY FROM TOP
L4F3F:  LDA  #$12

Shpplace_12:
L4F41:  CMP  #$05
L4F43:  BCS  Shpplace_20            ;STAY AWAY FROM BOTTOM
L4F45:  LDA  #$05

Shpplace_20:
L4F47:  STA  $0308,X                ;NEW Y POSITION
L4F4A:  RTS

ZeroAllRamPast:
L4F4B:  LDX  #$35
L4F4D:  LDA  #$00

ZeroAllRamPast_10:
L4F4F:  STA  VGBRIT,X
L4F51:  INX
L4F52:  CPX  #$D9
L4F54:  BNE  ZeroAllRamPast_10
L4F56:  TAX                         ;X=0

ZeroAllRamPast_20:
L4F57:  STA  XINC,X
L4F5A:  INX
L4F5B:  BNE  ZeroAllRamPast_20
L4F5D:  LDX  #$E0

ZeroAllRamPast_30:
L4F5F:  STA  $0300,X
L4F62:  DEX
L4F63:  BNE  ZeroAllRamPast_30
L4F65:  RTS

Initialization:
L4F66:  JSR  ZeroAllRamPast
L4F69:  STA  $31                    ;NO MORE COINS
L4F6B:  LDX  #$08

Initialization_30:
L4F6D:  STA  SCORE,X                ;CLEAR SCORE
L4F6F:  DEX
L4F70:  BPL  Initialization_30
L4F72:  STA  NROCKS                 ;CLEAR NUMBER OF ROCKS
L4F75:  STA  RDELAY
L4F78:  STA  SUPRSAC                ;CLEAR ANY OLD SAUCER
L4F7B:  LDX  #$02
L4F7D:  LDA  #$BF                   ;BIT 7 ON(SCORE), BIT 6 OFF (LIVES)

Initialization_35:
L4F7F:  STA  PL0SCFLAG,X
L4F82:  DEX
L4F83:  BPL  Initialization_35
L4F85:  JSR  Gtoptn                 ;READ OPTIONS AND SET LIVES AND BONUS
L4F88:  LDA  #$80
L4F8A:  STA  ATRACT
L4F8C:  DEC  UPDFLG
L4F8E:  DEC  $39                    ;STOP HIGH SCORE ENTRY
L4F90:  LDA  #$01
L4F92:  STA  $03BA
L4F95:  TAX                         ;X=1*****************************

Initialization_36:
L4F96:  LDA  #$A0
L4F98:  STA  SENMDEL,X              ;STARTING ENEMY DELAY
L4F9B:  LDA  #$01
L4F9D:  STA  SDELAY,X
L4FA0:  LDA  #$02
L4FA2:  STA  DWFRMP,X
L4FA5:  LDA  #$00
L4FA7:  STA  FCACH,X
L4FAA:  LDA  #$20                   ;A=20 (IT BETTER)
L4FAC:  STA  NWCACH,X
L4FAF:  STA  NWCSPD,X
L4FB2:  STA  FCSPD,X
L4FB5:  ASL                         ;A=40
L4FB6:  ASL                         ;A=80
L4FB7:  STA  IANGLE,X
L4FBA:  STA  MXRTIMER,X
L4FBD:  DEX
L4FBE:  BPL  Initialization_36
L4FC0:  LDA  #$11
L4FC2:  STA  COMSTART
L4FC5:  LDA  #$15
L4FC7:  STA  $0398
L4FCA:  LDA  #$FF
L4FCC:  STA  $03B5
L4FCF:  LDX  GAME
L4FD1:  LDA  Ttogdrone,X
L4FD4:  STA  TOGDRONE
L4FD6:  LDA  TableInitialValuesToggles,X
L4FD9:  STA  TOGCOMB
L4FDB:  CPX  #$01
L4FDD:  BNE  Initialization_38
L4FDF:  LDA  #$00
L4FE1:  STA  $026E                  ;CAN BE DEC
L4FE4:  STA  $48
L4FE6:  DEC  $0389                  ;ASSUME WAS 0

Initialization_38:
L4FE9:  LDA  #$01                   ;ALWAYS START WITH 1 COMET
L4FEB:  STA  COMLIMIT

Inset2:
L4FEE:  JSR  ScoreColorBasedAbove
L4FF1:  JSR  Inisou                 ;INITIALIZE SOUNDS,PROB NOT NEEDED

InitializeScoreHeadings:
L4FF4:  LDX  #$50
L4FF6:  LDA  #$C0                   ;AN RTSL

InitializeScoreHeadings_5:
L4FF8:  STA  PL0SET,X               ;FILL SCORE AREAS WITH RTSL'S
L4FFB:  DEX
L4FFC:  BPL  InitializeScoreHeadings_5
L4FFE:  LDX  #$02
L5000:  LDA  CABERE
L5003:  BPL  InitializeScoreHeadings_10 ;NOT COCKTAIL
L5005:  LDA  GAME                   ;NOT ON GAME 3 PLEASE
L5007:  CMP  #$03
L5009:  BEQ  InitializeScoreHeadings_10
L500B:  LDX  #$03                   ;NEED EXTRA MESSAGE IF COCKTAIL

InitializeScoreHeadings_10:
L500D:  STX  FOURPI                 ;COUNTER FOR WHICH AREA
L500F:  LDA  InitializeScoreHeadings_115,X
L5012:  STA  VGLIST
L5014:  LDA  InitializeScoreHeadings_110,X
L5017:  STA  EAC2                   ;VGLIST INITIALIZED
L5019:  LDX  FOURPI
L501B:  BEQ  InitializeScoreHeadings_20 ;THIS SCORE FOR SURE
L501D:  CPX  #$02
L501F:  BCC  InitializeScoreHeadings_14 ;NOT THE COMBINED SCORE
L5021:  BIT  TOGCOMB
L5023:  BPL  InitializeScoreHeadings_16

InitializeScoreHeadings_14:
L5025:  LDY  GAME
L5027:  CPY  #$01
L5029:  BNE  InitializeScoreHeadings_20 ;ONE SCORE ONLY

InitializeScoreHeadings_16:
L502B:  JSR  AddRtslToVector
L502E:  BNE  InitializeScoreHeadings_90 ;ALWAYS$

InitializeScoreHeadings_20:
L5030:  LDA  #$61
L5032:  LDX  #$AF
L5034:  JSR  Add2WordsToVector
L5037:  LDA  CABERE                 ;FLIP?
L503A:  BPL  InitializeScoreHeadings_25 ;NOPE
L503C:  LDA  GAME                   ;NO FLIP ON GAME 3 (1 PLAYER, 2 SCORES)
L503E:  CMP  #$03
L5040:  BEQ  InitializeScoreHeadings_25
L5042:  LDY  FOURPI                 ;GET Y POINTER
L5044:  LDA  InitializeScoreHeadings_130,Y ;ELSE GET FLIP INFO

InitializeScoreHeadings_25:
L5047:  STA  UPDOWN
L504A:  LDX  FOURPI                 ;GET COLOR OF SCORES
L504C:  LDA  Scrclr,X
L504F:  TAY                         ;PUT IN Y FOR VGSTAT INST
L5050:  JSR  SetVectorGeneratorStatus
L5053:  LDY  FOURPI
L5055:  LDA  InitializeScoreHeadings_100,Y ;X/4
L5058:  LDX  #$5B                   ;THIS IS ALWAYS 05B, NO TABLE NEEDED HERE
L505A:  JSR  UpdownVectorUpsideDown
L505D:  LDA  FOURPI
L505F:  CMP  #$02                   ;ONLY MEGGASE FOR 'COMBINATION'
L5061:  BCC  InitializeScoreHeadings_26
L5063:  LDA  #$02
L5065:  JSR  UseFullSize
L5068:  LDY  #$0F                   ;GET CORRECT MESSAGE
L506A:  LDA  $50C4,Y                ;GET COLOR
L506D:  JSR  PassColor              ;COMBINED SCORE
L5070:  LDA  #$E0                   ;X DIRECTION
L5072:  LDX  #$FA                   ;Y DIRECTION
L5074:  JSR  UpdownVectorUpsideDown

InitializeScoreHeadings_26:
L5077:  LDY  FOURPI
L5079:  LDA  InitializeScoreHeadings_120,Y
L507C:  LDX  InitializeScoreHeadings_125,Y
L507F:  JSR  AddJmplToVector
L5082:  LDY  FOURPI
L5084:  LDA  InitializeScoreHeadings_120,Y
L5087:  STA  EAC2                   ;PUT VGLIST AT THAT NEW AREA
L5089:  LDA  InitializeScoreHeadings_125,Y
L508C:  STA  VGLIST
L508E:  LDA  #$01                   ;FULL SIZE

InitializeScoreHeadings_30:
L5090:  JSR  UseFullSize            ;SET SCALE
L5093:  LDA  #$E4
L5095:  LDX  #$FA                   ;CHARACTERS ARE 24. TALL
L5097:  JSR  UpdownVectorUpsideDown ;DOWN & TO LEFT

InitializeScoreHeadings_90:
L509A:  LDX  FOURPI
L509C:  LDA  GAME
L509E:  CMP  #$03                   ;IF GAME 3 (1 PLR S.S.) NO OTHER SCORES
L50A0:  BEQ  Inselo
L50A2:  DEX
L50A3:  BMI  Inselo
L50A5:  JMP  InitializeScoreHeadings_10

InitializeScoreHeadings_100:
L50A8:  .byte $50, $9C, $D0, $F0

InitializeScoreHeadings_110:
L50AC:  .byte $23, $23, $23, $23

InitializeScoreHeadings_115:
L50B0:  .byte $00, $0A, $14, $42

InitializeScoreHeadings_120:
L50B4:  .byte $23, $23, $27, $27

InitializeScoreHeadings_125:
L50B8:  .byte $7A, $BA, $7A, $30

InitializeScoreHeadings_130:
L50BC:  .byte $00, $80, $00, $80

ScoreColorBasedAbove:
L50C0:  LDA  #$05
L50C2:  STA  ROCKMAX
L50C4:  LDA  #$FB
L50C6:  STA  $D8
L50C8:  LDA  #$03
L50CA:  STA  ROCKMIN
L50CC:  LDA  #$FD
L50CE:  STA  $D6
L50D0:  RTS

Scrclr:
L50D1:  .byte $E4, $E2, $E6, $E6

Inselo:
L50D5:  LDY  #$6F
L50D7:  LDA  #$C0

Inselo_20:
L50D9:  STA  VROCK1,Y
L50DC:  DEY
L50DD:  BPL  Inselo_20
L50DF:  LDA  #$F4
L50E1:  STA  SAU11                  ;INIT SAUCER COLORS
L50E4:  LDA  #$E7
L50E6:  STA  SAU12
L50E9:  LDA  #$F1
L50EB:  STA  SAU13
L50EE:  LDA  #$64                   ;AND ADD COLOR INSTRUCTION
L50F0:  STA  $22C5
L50F3:  STA  $22C9
L50F6:  STA  $22CD
L50F9:  RTS

Inita3:
L50FA:  LDY  SKCTL

DisplayAnInitial:
L50FC:  INC  SKCTL                  ;FOR USE IN SCORES
L50FE:  LDA  TEMP5
L5100:  BEQ  DisplayAnInitial_10    ;NOT PLAYER 2
L5102:  BIT  SPFLG                  ;SPECIAL INITIALS?
L5105:  BMI  DisplayAnInitial_10
L5107:  LDA  $0137,Y                ;GET SPECIAL
L510A:  JMP  DisplayAnInitial_11

DisplayAnInitial_10:
L510D:  LDA  INITL,Y                ;INITIAL

DisplayAnInitial_11:
L5110:  CMP  #$25                   ;DONT LET PAST Z
L5112:  BCS  DisplayAnInitial_14    ;BAD--SET TO BLANK
L5114:  CMP  #$0B                   ;OR UNDER AN A
L5116:  BCS  DisplayAnInitial_15    ;WERE OK HERE

DisplayAnInitial_14:
L5118:  LDA  #$00

DisplayAnInitial_15:
L511A:  ASL
L511B:  TAY
L511C:  BNE  EntryIndexCharacter0   ;IF NOT A BLANK
L511E:  LDA  UPDFLG
L5120:  AND  $39
L5122:  BMI  EntryIndexCharacter0   ;NOT UPDATING INITIALS
L5124:  LDA  #$A8                   ;ASSUMES .BRITE=7
L5126:  BIT  UPDOWN                 ;D UPSIDE DOWN CHAR?
L5129:  BPL  DisplayAnInitial_12
L512B:  LDA  #$1C                   ;C UNDERLINE UPSIDEDOWN

DisplayAnInitial_12:
L512D:  LDX  #$40                   ;VCTR 8,0,7
L512F:  JSR  Add2WordsToVector      ;UNDERLINE
L5132:  LDA  #$04                   ;ACC WAS DESTROYED
L5134:  BIT  UPDOWN                 ;D UPSIDE DOWN UNDERLINE?
L5137:  BPL  DisplayAnInitial_13
L5139:  LDA  #$38                   ;C UPSIDEDOWN SPACEING

DisplayAnInitial_13:
L513B:  LDX  #$40                   ;VCTR 4,0,0
L513D:  JMP  Add2WordsToVector

EntryIndexCharacter0:
L5140:  LDX  $324B,Y
L5143:  LDA  $324A,Y
L5146:  BIT  UPDOWN
L5149:  BPL  EntryIndexCharacter0_10
L514B:  LDX  $3459,Y
L514E:  LDA  $3458,Y

EntryIndexCharacter0_10:
L5151:  JMP  Add2WordsToVector      ;ADD TO VECTOR LIST

EnteringDwarfAmoutns:
L5154:  .byte $02, $03, $04, $05, $06, $07, $08, $08
L515C:  .byte $08, $08, $08, $08, $08, $08, $08, $08

Entdwtable:
L5164:  .byte $03, $04, $05, $06, $07, $08, $09, $0A
L516C:  .byte $0B, $0C, $0C, $0C, $0C, $0C, $0C, $0C

MotionUpdateRoutine:
L5174:  LDA  COMTIMER
L5177:  BEQ  Moti20
L5179:  BIT  TOGCOMB
L517B:  BPL  Moti20
L517D:  LDA  $0308,X
L5180:  SEC
L5181:  SBC  $0309
L5184:  JSR  EntryInputExitAbsolute
L5187:  CMP  #$0C
L5189:  BCS  MotionUpdateRoutine_30
L518B:  LDA  STRADDLE
L518E:  AND  #$BF                   ;NO LONGER STR ADDLING INY
L5190:  STA  STRADDLE

MotionUpdateRoutine_30:
L5193:  LDA  $02D6,X
L5196:  SEC
L5197:  SBC  $02D7
L519A:  JSR  EntryInputExitAbsolute
L519D:  CMP  #$10
L519F:  BCS  Moti20
L51A1:  LDA  STRADDLE
L51A4:  AND  #$7F                   ;NO LONGER STRADDLING X
L51A6:  STA  STRADDLE

Moti20:
L51A9:  LDA  #$00                   ;NO RODS DRAWN
L51AB:  STA  RODSTATUS
L51AE:  LDX  #$2F                   ;NUMBER OF OBJECTS TO MOVE

Moti20_11:
L51B0:  STX  TEMP3                  ;SAVE FOR LATER USE
L51B2:  LDA  OBJ,X
L51B4:  BNE  Moti20_15              ;ACTIVE OBJECT

Moti20_13:
L51B6:  DEX
L51B7:  BPL  Moti20_11              ;MORE OBJECTS
L51B9:  RTS

Moti20_15:
L51BA:  BPL  Moti20_60              ;IF OBJECT ACTIVE
L51BC:  JSR  Comp                   ;TIME REMAINING (0 TO 60)
L51BF:  LSR
L51C0:  LSR
L51C1:  LSR
L51C2:  LSR
L51C3:  CPX  #$21
L51C5:  BCC  Moti20_30
L51C7:  CPX  #$23
L51C9:  BCS  Moti20_32
L51CB:  LDA  FRAME
L51CD:  AND  #$01                   ;ADD 1 EVERYOTHER FRAME
L51CF:  LSR
L51D0:  BEQ  Moti20_32              ;ALWAYS

Moti20_30:
L51D2:  SEC                         ;1+ VALUE /16

Moti20_32:
L51D3:  ADC  OBJ,X                  ;NEW EXPLOSION PICTURE
L51D5:  BMI  Moti20_45              ;STILL INACTIVE

Moti20_36:
L51D7:  CPX  #$19
L51D9:  BCS  Moti20_40              ;NOT ROCK OR COMET
L51DB:  CPX  #$11
L51DD:  BCC  Moti20_37              ;WAS ROCK
L51DF:  DEC  NCOMET
L51E2:  BPL  Moti20_40              ;ALWAYS (I HOPE)

Moti20_37:
L51E4:  DEC  NROCKS
L51E7:  BNE  Moti20_40              ;IF MORE ROCKS REMAIN
L51E9:  LDA  #$00
L51EB:  STA  SCRFUL
L51ED:  LDY  #$7F                   ;DELAY BEFORE STARTING
L51EF:  STY  RDELAY
L51F2:  LDA  ATRACT
L51F4:  BEQ  Moti20_40              ;IN ATRACT
L51F6:  LDA  #$FF
L51F8:  STA  KLMOFF                 ;MINES OFF
L51FA:  CLC
L51FB:  LDA  WAVE                   ;ONSLAUGHT AMOUNT
L51FE:  ADC  DIFCTY
L5200:  LSR                         ;SO IT MOVES ALONG WITH DIFF LEVEL
L5201:  LSR

Moti20_39:
L5202:  TAY
L5203:  CPY  #$0F
L5205:  BCC  Moti20_38
L5207:  LDY  #$0F

Moti20_38:
L5209:  BIT  COMOFF
L520C:  BMI  Moti20_40              ;JUST DIED
L520E:  LDA  EnteringDwarfAmoutns,Y ;ENTERING COMET AMOUNTS
L5211:  STA  NENTCOMETS
L5214:  LDA  Entdwtable,Y           ;ENTERING DWARF A MOUNTS
L5217:  STA  NENTDWARF
L521A:  BIT  TOGCOMB
L521C:  BPL  Moti20_35
L521E:  LDA  #$FF                   ;ASSUME ARE STRADDLING
L5220:  STA  STRADDLE

Moti20_35:
L5223:  LDA  #$60
L5225:  STA  COMTIMER               ;START ONSLAUGHT
L5228:  LDA  #$FF
L522A:  STA  SFREQ                  ;RESET HUM FREQ

Moti20_40:
L522D:  LDA  #$00

Moti20_42:
L522F:  STA  OBJ,X                  ;RESET PICTURE
L5231:  JMP  Moti20_13

Moti20_45:
L5234:  STA  OBJ,X

Moti20_60:
L5236:  CLC
L5237:  LDY  #$00
L5239:  LDA  XINC,X
L523C:  BPL  Moti20_62              ;SIGN EXTENSION
L523E:  DEY

Moti20_62:
L523F:  ADC  OBJXL,X
L5242:  STA  XCOMP
L5244:  TYA
L5245:  ADC  OBJXH,X
L5248:  CMP  #$20
L524A:  BCC  Moti20_27              ;IF 0 TO 1023(SHORTCUT TO 85$)
L524C:  STA  RED

Moti20_70:
L524E:  CPX  #$11
L5250:  BCC  Moti20_75              ;WAS ROCK
L5252:  CPX  #$24
L5254:  BCS  Moti20_79              ;A SHOT
L5256:  CPX  #$1F
L5258:  BCC  Moti20_76              ;COMET OR KILLERMINE
L525A:  CPX  #$21
L525C:  BCS  Moti20_71              ;NOT SAUCER OR BELOW
L525E:  BIT  SUPRSAC                ;A SUPER SAUCER HIT EDGE?
L5261:  BPL  Moti20_77              ;IF NO, REMOVE
L5263:  PHA
L5264:  LDA  SUPRDIS                ;DISTANCE
L5267:  ADC  #$01                   ;WIDER NEXT PASS
L5269:  CMP  #$12
L526B:  BCS  Moti20_72
L526D:  STA  SUPRDIS

Moti20_72:
L5270:  PLA
L5271:  BIT  SCRFUL
L5273:  BMI  Moti20_77
L5275:  LDY  COMTIMER
L5278:  BEQ  Moti20_75

Moti20_77:
L527A:  JSR  ResetSaucerValues
L527D:  JMP  Moti20_13

Moti20_71:
L5280:  INC  RODSTATUS
L5283:  LDA  COMTIMER
L5286:  BEQ  Moti20_79              ;NOT THE CAGE
L5288:  BIT  STRADDLE
L528B:  BMI  Moti20_79              ;STILL STRADDLING
L528D:  CPX  #$23
L528F:  BEQ  Moti20_74              ;WAS PAIR
L5291:  JSR  Revxship

Moti20_74:
L5294:  JSR  ReverseAngularMomentum
L5297:  JSR  PossibleReverseXVelocity
L529A:  BIT  RED
L529C:  BMI  Moti20_24
L529E:  LDA  #$1F
L52A0:  LDY  #$FF
L52A2:  BNE  Moti20_26

Moti20_24:
L52A4:  LDA  #$00
L52A6:  TAY

Moti20_26:
L52A7:  STY  XCOMP

Moti20_27:
L52A9:  JMP  Moti20_85

Moti20_76:
L52AC:  CPX  #$19
L52AE:  BCC  Moti20_73              ;WAS COMET OR DWARF
L52B0:  BIT  KLMOFF
L52B2:  BPL  Moti20_80              ;STAY
L52B4:  BMI  Moti20_81              ;LEAVE

Moti20_73:
L52B6:  LDA  $037E,X
L52B9:  ROR
L52BA:  BCS  Moti20_83              ;TAKE AWAY
L52BC:  ROL
L52BD:  BMI  Moti20_79              ;ALREADY COMET
L52BF:  JSR  SbttlStcomet
L52C2:  BPL  Moti20_79              ;ALWAYS

Moti20_75:
L52C4:  BIT  SCRFUL
L52C6:  BPL  Moti20_80              ;ROCK WRAPS AROUND
L52C8:  JMP  Moti20_13              ;NOT SHOW THIS ROCK

Moti20_83:
L52CB:  DEC  NCOMET

Moti20_81:
L52CE:  LDA  #$00
L52D0:  STA  OBJ,X

Moti20_102:
L52D2:  JMP  Moti20_13

Moti20_79:
L52D5:  LDA  RED

Moti20_80:
L52D7:  AND  #$1F

Moti20_85:
L52D9:  STA  RED
L52DB:  CLC
L52DC:  LDY  #$00
L52DE:  LDA  YINC,X
L52E1:  BPL  Moti20_88              ;SIGN EXTENSION
L52E3:  DEY

Moti20_88:
L52E4:  ADC  OBJYL,X
L52E7:  STA  CHAN3V
L52E9:  TYA
L52EA:  ADC  OBJYH,X                ;0 TO 767 PLEASE
L52ED:  CMP  #$18
L52EF:  BCC  Moti20_92              ;ALREADY 0 TO 767
L52F1:  STA  TWOPI
L52F3:  CPX  #$11
L52F5:  BCC  Moti20_84
L52F7:  CPX  #$1F
L52F9:  BCC  Moti20_58
L52FB:  INC  RODSTATUS
L52FE:  LDA  COMTIMER
L5301:  BEQ  Moti20_89              ;TIME IS GONE
L5303:  BIT  STRADDLE
L5306:  BVS  Moti20_89              ;STILL STRADDLING
L5308:  CPX  #$23
L530A:  BEQ  Moti20_54              ;WAS THE ROD
L530C:  CPX  #$23
L530E:  BCS  Moti20_89              ;NOT A SHIP
L5310:  CPX  #$21
L5312:  BCC  Moti20_89              ;NOT A SHIP
L5314:  JSR  ReverseTravelVelocity
L5317:  JSR  ReverseAngularMomentum

Moti20_54:
L531A:  JSR  Prevybar
L531D:  BIT  TWOPI
L531F:  BMI  Moti20_52
L5321:  LDA  #$17
L5323:  LDY  #$FF
L5325:  BNE  Moti20_53

Moti20_52:
L5327:  LDA  #$00
L5329:  TAY

Moti20_53:
L532A:  STA  TWOPI
L532C:  STY  CHAN3V
L532E:  JMP  Moti20_92

Moti20_58:
L5331:  CPX  #$19
L5333:  BCC  Moti20_82              ;WAS COMET
L5335:  BIT  KLMOFF
L5337:  BPL  Moti20_89              ;STAY
L5339:  BMI  Moti20_81              ;LEAVE

Moti20_82:
L533B:  LDA  $037E,X
L533E:  ROR
L533F:  BCS  Moti20_83              ;GET OFF SCREEN
L5341:  ROL
L5342:  BMI  Moti20_89              ;ALREADY COMET
L5344:  JSR  SbttlStcomet
L5347:  BPL  Moti20_89              ;ALWAYS

Moti20_84:
L5349:  BIT  SCRFUL
L534B:  BMI  Moti20_102             ;LEAVE IT AT EDGE

Moti20_89:
L534D:  LDA  TWOPI
L534F:  BPL  Moti20_90              ;IF 768 UP
L5351:  LDA  #$17                   ;WRAP TO TOP OF SCREEN
L5353:  BNE  Moti20_92              ;ALWAYS

Moti20_90:
L5355:  LDA  #$00

Moti20_92:
L5357:  BIT  SUPRSAC
L535A:  BPL  Moti20_95              ;NOT SUPER SAUCER
L535C:  CPX  #$1F                   ;CONTROLL SAUCER
L535E:  BNE  Moti20_95              ;NOPE
L5360:  CMP  #$01                   ;LIMIT ON BOTTOM TRAVEL
L5362:  BEQ  Moti20_93              ;IF SAME, HOLD THERE ON UP
L5364:  BCC  Moti20_100             ;DON'T ALLOW CHANGE
L5366:  STA  TEMP5
L5368:  CLC
L5369:  ADC  SUPRDIS                ;CHECK TOP DISTANCE
L536C:  CMP  #$17                   ;AT TOP??
L536E:  BEQ  Moti20_93              ;IF SAME, LEAVE THERE
L5370:  BCC  Moti20_94
L5372:  DEC  OBJYH,X                ;FORCE OFF TOP

Moti20_93:
L5375:  LDA  OBJYL,X                ;STORE POSTIONS
L5378:  STA  CHAN3V
L537A:  LDA  OBJYH,X
L537D:  STA  TWOPI                  ;FOR PICTURE ROUTINE
L537F:  BNE  Moti20_96              ;WE KNOW THIS WILL NEVER BE 0

Moti20_94:
L5381:  LDA  TEMP5

Moti20_95:
L5383:  STA  OBJYH,X
L5386:  STA  TWOPI
L5388:  LDA  CHAN3V
L538A:  STA  OBJYL,X

Moti20_96:
L538D:  LDA  XCOMP
L538F:  STA  OBJXL,X
L5392:  LDA  RED
L5394:  STA  OBJXH,X
L5397:  CPX  #$23
L5399:  BEQ  Moti20_99              ;NO PICTURE FOR BAR IT COMES WITH SHIPS
L539B:  BIT  SPECEX                 ;SPECIAL EXPLOSIONS?
L539E:  BPL  Moti20_121             ;NO
L53A0:  LDA  OBJYH,X
L53A3:  CMP  OBJ,X                  ;OBJ HOLDS DEST Y
L53A5:  BCC  Moti20_121             ;NOT THERE YET
L53A7:  LDA  #$00
L53A9:  STA  YINC,X                 ;STOP MOTION
L53AC:  LDA  #$A0
L53AE:  STA  OBJ,X                  ;EXPLODE
L53B0:  JSR  Explosion              ;SOUND
L53B3:  LDX  TEMP3                  ;RECALL X

Moti20_121:
L53B5:  JSR  Pictur                 ;DISPLAY PICTURE
L53B8:  LDX  TEMP3

Moti20_99:
L53BA:  JMP  Moti20_13

Moti20_100:
L53BD:  INC  OBJYH,X                ;FORCE OFF BOTTOM
L53C0:  JMP  Moti20_93

Moti20_120:
L53C3:  .byte $40, $40, $80, $80

SbttlStcomet:
L53C7:  LDY  GTIME,X
L53CA:  LDA  #$80
L53CC:  STA  $037E,X                ;NOW A COMET
L53CF:  LDA  BXINCL,Y
L53D2:  STA  $0274,X
L53D5:  LDA  PRTDAMAGE,Y
L53D8:  STA  OBJ,X
L53DA:  RTS

KillXSaucer:
L53DB:  STX  TEMP1
L53DD:  LDA  #$30
L53DF:  JSR  AddPointsToScore
L53E2:  LDX  TEMP1
L53E4:  JSR  Explosion              ;EXPLOSION SOUND
L53E7:  LDA  #$A0
L53E9:  BNE  ClearSaucer            ;ALWAYS

ResetSaucerValues:
L53EB:  LDA  #$00

ClearSaucer:
L53ED:  STA  OBJ,X                  ;CLEAR SAUCER
L53EF:  LDA  #$00
L53F1:  STA  SUPRSAC                ;GOODBYE SUPER SAUCER
L53F4:  LDA  $53DC,X
L53F7:  TAX
L53F8:  JMP  Hasent                 ;DELAY BEFORE NEXT

ClearSaucer_100:
L53FB:  .byte $00, $01

WaitForDirectedEnemies:
L53FD:  STY  TEMPA
L53FF:  LDX  #$02

WaitForDirectedEnemies_20:
L5401:  LDA  NENTDWARF,X
L5404:  CMP  TEMPA
L5406:  BNE  WaitForDirectedEnemies_30
L5408:  LDA  $B5,X
L540A:  BNE  WaitForDirectedEnemies_80

WaitForDirectedEnemies_30:
L540C:  DEX
L540D:  BNE  WaitForDirectedEnemies_20
L540F:  LDX  #$08

WaitForDirectedEnemies_55:
L5411:  LDA  $03C0,X
L5414:  CMP  TEMPA
L5416:  BNE  WaitForDirectedEnemies_70
L5418:  LDA  $A7,X
L541A:  BNE  WaitForDirectedEnemies_80

WaitForDirectedEnemies_70:
L541C:  DEX
L541D:  BNE  WaitForDirectedEnemies_55

WaitForDirectedEnemies_80:
L541F:  RTS

EntryNoRequirementsExit:
L5420:  LDA  #$00
L5422:  LDY  #$07

EntryNoRequirementsExit_10:
L5424:  ORA  OBCOMETS,Y
L5427:  DEY
L5428:  BPL  EntryNoRequirementsExit_10
L542A:  TAY                         ;SET CONDITION CODES
L542B:  RTS

ReverseTravelVelocity:
L542C:  LDA  #$00
L542E:  SEC
L542F:  SBC  ZP1MIN,X
L5431:  STA  ZP1MIN,X
L5433:  LDA  #$00
L5435:  SBC  YINC,X
L5438:  STA  YINC,X
L543B:  RTS

Revxship:
L543C:  LDA  #$00
L543E:  SEC
L543F:  SBC  $2A,X
L5441:  STA  $2A,X
L5443:  LDA  #$00
L5445:  SBC  XINC,X
L5448:  STA  XINC,X

ReverseAngularMomentum:
L544B:  LDA  #$00
L544D:  SEC
L544E:  SBC  LWBAR
L5451:  STA  LWBAR
L5454:  LDA  #$00
L5456:  SBC  UWBAR
L5459:  STA  UWBAR
L545C:  RTS

PossibleReverseXVelocity:
L545D:  LDA  RED
L545F:  EOR  $0223
L5462:  BMI  PossibleReverseXVelocity_90
L5464:  LDA  #$00
L5466:  SEC
L5467:  SBC  BXINCL
L546A:  STA  BXINCL
L546D:  LDA  #$00
L546F:  SBC  $0223
L5472:  STA  $0223

PossibleReverseXVelocity_90:
L5475:  JMP  DropShieldsWallHit

Prevybar:
L5478:  LDA  TWOPI
L547A:  EOR  $0255
L547D:  BMI  DropShieldsWallHit
L547F:  LDA  #$00
L5481:  SEC
L5482:  SBC  BYINCL
L5485:  STA  BYINCL
L5488:  LDA  #$00
L548A:  SBC  $0255
L548D:  STA  $0255

DropShieldsWallHit:
L5490:  LDX  #$01

DropShieldsWallHit_10:
L5492:  JSR  TwinGameBothShields    ;SWITCH PUSHED??
L5495:  BPL  DropShieldsWallHit_20  ;NOPE
L5497:  JSR  Game23Shields          ;YEP..TAKE AWAY ENERGY

DropShieldsWallHit_20:
L549A:  DEX
L549B:  BPL  DropShieldsWallHit_10
L549D:  LDX  TEMP3                  ;RESTORE X
L549F:  RTS

Checksum5000:
L54A0:  .byte $68

MoveShip:
L54A1:  STX  TEMP3
L54A3:  BIT  TOGCOMB
L54A5:  BMI  MoveShip_30
L54A7:  LDA  OBSHIP,X
L54A9:  BPL  MoveShip_2
L54AB:  JMP  Shipfriction           ;IF EXPLODING

MoveShip_2:
L54AE:  BEQ  MoveShip_7             ;NOT VISIBLE
L54B0:  JMP  MoveShip_5             ;ACTIVE

MoveShip_7:
L54B3:  LDA  SDELAY,X
L54B6:  BEQ  MoveShip_91            ;SHIP NOT TO APPEAR
L54B8:  DEC  SDELAY,X               ;DECREMENT COUNT
L54BB:  BNE  MoveShip_91            ;NOT DONE YET
L54BD:  LDA  COMTIMER               ;ONSLAUGHT GOING?
L54C0:  BNE  MoveShip_94            ;IF YES, DONT RE-ENTER A SHIP (BONUS)
L54C2:  JSR  Shpplace
L54C5:  JSR  CheckForRocksNearby    ;CHECK FOR AREA FREE OF ROCKS
L54C8:  BNE  MoveShip_94            ;IF SOMETHING CLOSE BY
L54CA:  LDY  L01ZshipZship,X
L54CD:  JSR  WaitForDirectedEnemies
L54D0:  BEQ  MoveShip_92            ;NO SUCH

MoveShip_94:
L54D2:  LDX  TEMP3

MoveShip_8:
L54D4:  INC  SDELAY,X

MoveShip_91:
L54D7:  RTS                         ;(EXIT)

MoveShip_30:
L54D8:  CPX  #$00                   ;LAST PASS THROUGH?
L54DA:  BEQ  MoveShip_91

MoveShip_31:
L54DC:  JMP  Dorigid                ;MOVE PAIR

MoveShip_92:
L54DF:  LDX  TEMP3
L54E1:  LDA  #$00
L54E3:  STA  $0221,X
L54E6:  STA  $0253,X
L54E9:  LDA  GAME
L54EB:  CMP  #$01
L54ED:  BNE  MoveShip_93            ;NOT ALONE GAME
L54EF:  LDA  HITS,X
L54F1:  BEQ  MoveShip_8             ;GAME IS OVER
L54F3:  LDA  #$00
L54F5:  STA  COMOFF                 ;ALL ACTIVE
L54F8:  BEQ  MoveShip_95            ;ALWAYS

MoveShip_93:
L54FA:  LDA  WHOSHOT,X
L54FD:  BPL  MoveShip_99            ;LOST A LITE
L54FF:  LDA  PRTDAMAGE,X
L5502:  BPL  MoveShip_97            ;REINCARNATE

MoveShip_99:
L5504:  LDA  HITS,X
L5506:  BNE  MoveShip_95
L5508:  LDY  Revship,X
L550B:  LDA  $0367,Y
L550E:  BMI  MoveShip_94            ;OTHER IS DEAD WAIT
L5510:  BPL  MoveShip_97

MoveShip_95:
L5512:  BIT  ATRACT                 ;ATTRACT?
L5514:  BPL  MoveShip_1             ;IF YES, DON'T LOSE LIFE
L5516:  DEC  HITS,X

MoveShip_1:
L5518:  LDA  #$BF                   ;LIVES & SCORES
L551A:  STA  PL0SCFLAG,X

MoveShip_96:
L551D:  LDA  #$00
L551F:  STA  PRTDAMAGE,X            ;NO PARTIAL DARMAGE

MoveShip_97:
L5522:  LDA  #$F0                   ;BEGINNING SHIELD ENERGY
L5524:  STA  SHLDENG,X              ;RESTORE SHIELDS
L5527:  LDA  #$02
L5529:  STA  OBSHIP,X               ;USE 1/2 SIZE PICTURE
L552B:  LDA  #$00
L552D:  STA  SCRFUL                 ;LET ROCKS COME BACK
L552F:  STA  NENTCOMETS
L5532:  STA  NENTDWARF
L5535:  LDA  MXRTIMER,X
L5538:  CLC
L5539:  ADC  #$10
L553B:  BCS  MoveShip_98            ;OVER FLOW
L553D:  STA  MXRTIMER,X             ;GIVE A LITTLE MORE ROCK TIME
L5540:  STA  RTIMER,X

MoveShip_98:
L5543:  LDA  #$7F                   ;GIVE MAX DELAY HERE
L5545:  STA  ENMDEL,X
L5548:  LDA  #$10                   ;EFFECT TIMER
L554A:  CPX  #$01
L554C:  BEQ  MoveShip_10
L554E:  STA  ENTER
L5551:  JMP  Reenter2               ;REENTER SOUND & EXIT

MoveShip_10:
L5554:  STA  $03E8                  ;REENTER SOUND & EXIT
L5557:  JMP  Reenter

MoveShip_5:
L555A:  TXA
L555B:  EOR  FRAME
L555D:  LSR                         ;SET CARRY
L555E:  BCS  MoveShip_70            ;CHECK THRUST ON ALTERNATE FRAMES ONLY
L5560:  BIT  ATRACT                 ;DON'T READ IN ATRACT
L5562:  BMI  MoveShip_11
L5564:  LDA  FRAME
L5566:  ASL                         ;USE OTHER THAN 7
L5567:  ASL
L5568:  JMP  MoveShip_12

MoveShip_11:
L556B:  LDA  STRT1,X

MoveShip_12:
L556E:  BPL  Shipfriction           ;NO THRUST
L5570:  JSR  ThrustSound            ;THRUST SOUND
L5573:  LDA  #$00
L5575:  STA  TEMP1                  ;SIGN EXTENSION
L5577:  LDA  SANGLE,X
L557A:  JSR  CosSinPi2              ;COS(ANGLE)=(CHANGE IN XINC)*4
L557D:  ASL
L557E:  BCC  MoveShip_20
L5580:  DEC  TEMP1

MoveShip_20:
L5582:  LDX  TEMP3
L5584:  LDY  PRTDAMAGE,X
L5587:  BNE  MoveShip_25
L5589:  ASL
L558A:  ROL  TEMP1

MoveShip_25:
L558C:  CLC
L558D:  ADC  XINCL,X                ;ADD TO SHIPS VELOCITY
L558F:  STA  XINCL,X
L5591:  LDA  TEMP1
L5593:  ADC  $0221,X
L5596:  JSR  OutRange               ;CHECK FOR RANGE
L5599:  STA  $0221,X
L559C:  LDA  #$00
L559E:  STA  TEMP1
L55A0:  LDA  SANGLE,X
L55A3:  JSR  PiAngle0               ;SIN(ANGLE)

MoveShip_50:
L55A6:  ASL
L55A7:  BCC  MoveShip_60
L55A9:  DEC  TEMP1

MoveShip_60:
L55AB:  LDX  TEMP3
L55AD:  LDY  PRTDAMAGE,X
L55B0:  BNE  MoveShip_65
L55B2:  ASL
L55B3:  ROL  TEMP1

MoveShip_65:
L55B5:  CLC
L55B6:  ADC  YINCL,X
L55B8:  STA  YINCL,X
L55BA:  LDA  TEMP1
L55BC:  ADC  $0253,X
L55BF:  JSR  OutRange               ;CHECK FOR RANGE
L55C2:  STA  $0253,X

MoveShip_70:
L55C5:  RTS                         ;(EXIT)

Shipfriction:
L55C6:  LDY  #$00
L55C8:  LDA  XINCL,X
L55CA:  STA  TEMPA
L55CC:  ORA  $0221,X
L55CF:  BEQ  Shipfriction_87        ;IF XMOTION IS NULL
L55D1:  LDA  $0221,X
L55D4:  ROL  TEMPA
L55D6:  ROL
L55D7:  EOR  #$FF
L55D9:  SEC                         ;FORMS THE +1
L55DA:  BPL  Shipfriction_86        ;IF IT WAS POSITIVE
L55DC:  DEY                         ;SIGN EXTEASION
L55DD:  CLC

Shipfriction_86:
L55DE:  ADC  XINCL,X
L55E0:  STA  XINCL,X
L55E2:  TYA
L55E3:  ADC  $0221,X
L55E6:  STA  $0221,X

Shipfriction_87:
L55E9:  LDY  #$00
L55EB:  LDA  YINCL,X
L55ED:  STA  TEMPA
L55EF:  ORA  $0253,X
L55F2:  BEQ  Shipfriction_89        ;IF Y=0
L55F4:  LDA  $0253,X
L55F7:  ROL  TEMPA
L55F9:  ROL
L55FA:  SEC
L55FB:  EOR  #$FF
L55FD:  BPL  Shipfriction_88        ;IF WAS POSITIVE
L55FF:  DEY                         ;SIGN EXTENSION
L5600:  CLC

Shipfriction_88:
L5601:  ADC  YINCL,X
L5603:  STA  YINCL,X
L5605:  TYA
L5606:  ADC  $0253,X
L5609:  STA  $0253,X

Shipfriction_89:
L560C:  RTS

OutRange:
L560D:  BMI  OutRange_30            ;IF OUT OF RANGE
L560F:  CMP  #$40
L5611:  BCC  OutRange_35            ;IF IN RANGE
L5613:  LDA  #$3F                   ;SET MAX POSITIVE
L5615:  RTS

OutRange_30:
L5616:  CMP  #$C0
L5618:  BCS  OutRange_35            ;IF IN RANGE
L561A:  LDA  #$C0                   ;SET MAX NEGATIVE

OutRange_35:
L561C:  RTS

WillAssumeRadiusBar:
L561D:  TXA
L561E:  BNE  WillAssumeRadiusBar_15 ;VALUES NOT CALCULATED
L5620:  LDA  $026E
L5623:  BNE  WillAssumeRadiusBar_15
L5625:  LDY  #$00
L5627:  TYA                         ;A=0
L5628:  SEC
L5629:  SBC  XPOSSAVE               ;RECALL SAVED X POSITION RELATIVE TO BAR
L562C:  ASL
L562D:  BCC  WillAssumeRadiusBar_72
L562F:  DEY

WillAssumeRadiusBar_72:
L5630:  CLC
L5631:  ADC  $0343
L5634:  STA  $0341
L5637:  TYA
L5638:  ADC  $02D8
L563B:  STA  $02D6
L563E:  LDY  #$00
L5640:  TYA                         ;A=0
L5641:  SEC
L5642:  SBC  YPOSSAVE
L5645:  ASL
L5646:  BCC  WillAssumeRadiusBar_73
L5648:  DEY

WillAssumeRadiusBar_73:
L5649:  CLC
L564A:  ADC  $0375
L564D:  STA  $0373
L5650:  TYA
L5651:  ADC  $030A

WillAssumeRadiusBar_76:
L5654:  STA  $0308
L5657:  LDA  $0223
L565A:  SEC
L565B:  SBC  XINCROT
L565E:  STA  $0221
L5661:  LDA  $0255
L5664:  SEC
L5665:  SBC  YINCROT
L5668:  STA  $0253
L566B:  RTS                         ;(EXIT)

WillAssumeRadiusBar_15:
L566C:  LDA  BANGLE
L566F:  CPX  #$00
L5671:  BEQ  WillAssumeRadiusBar_12
L5673:  EOR  #$80

WillAssumeRadiusBar_12:
L5675:  STA  TEMP7B                 ;HAVE ANGLE

WillAssumeRadiusBar_20:
L5677:  JSR  CosSinPi2
L567A:  STA  XPOSSAVE
L567D:  LDY  #$00
L567F:  ASL
L5680:  BCC  WillAssumeRadiusBar_25
L5682:  DEY

WillAssumeRadiusBar_25:
L5683:  LDX  TEMP3
L5685:  CLC
L5686:  ADC  $0343                  ;LOW BYTE OF X COORD OF CENTER OF MASS
L5689:  STA  $0341,X
L568C:  TYA
L568D:  ADC  $02D8
L5690:  STA  $02D6,X
L5693:  LDA  XPOSSAVE
L5696:  STA  TEMP1
L5698:  LDA  UWBAR
L569B:  JSR  SignedBySignedMult
L569E:  ASL
L569F:  STA  TEMPA
L56A1:  ASL
L56A2:  CLC
L56A3:  ADC  TEMPA
L56A5:  LDX  TEMP3
L56A7:  STA  YINCROT
L56AA:  CLC
L56AB:  ADC  $0255
L56AE:  STA  $0253,X

WillAssumeRadiusBar_30:
L56B1:  LDA  TEMP7B
L56B3:  JSR  PiAngle0
L56B6:  LDX  TEMP3
L56B8:  STA  YPOSSAVE
L56BB:  LDY  #$00
L56BD:  ASL
L56BE:  BCC  WillAssumeRadiusBar_35
L56C0:  DEY

WillAssumeRadiusBar_35:
L56C1:  CLC
L56C2:  ADC  $0375
L56C5:  STA  $0373,X
L56C8:  TYA
L56C9:  ADC  $030A
L56CC:  STA  $0308,X
L56CF:  LDA  YPOSSAVE
L56D2:  JSR  Comp
L56D5:  STA  TEMP1
L56D7:  LDA  UWBAR
L56DA:  JSR  SignedBySignedMult
L56DD:  ASL
L56DE:  STA  TEMPA
L56E0:  ASL
L56E1:  CLC
L56E2:  ADC  TEMPA
L56E4:  LDX  TEMP3
L56E6:  CLC
L56E7:  STA  XINCROT
L56EA:  ADC  $0223
L56ED:  STA  $0221,X
L56F0:  RTS

ThrustTwoShips:
L56F1:  LDA  BANGLE
L56F4:  CPX  #$00
L56F6:  BEQ  ThrustTwoShips_5
L56F8:  EOR  #$80

ThrustTwoShips_5:
L56FA:  STA  TEMP7B
L56FC:  LDA  #$28
L56FE:  STA  TEMP1
L5700:  LDA  SANGLE,X
L5703:  SEC
L5704:  SBC  TEMP7B
L5706:  STA  TEMP5                  ;RELATIVE ANGLE
L5708:  JSR  PiAngle0
L570B:  STA  TEMP7                  ;SIN OF RELATIVE ANGLE
L570D:  JSR  OutputTemp2Temp21
L5710:  LDY  #$00
L5712:  TAX                         ;SET STATUS
L5713:  BPL  ThrustTwoShips_10
L5715:  DEY                         ;SIGN EXTENSION

ThrustTwoShips_10:
L5716:  CLC
L5717:  ADC  LWBAR
L571A:  STA  LWBAR
L571D:  TYA
L571E:  ADC  UWBAR
L5721:  STA  UWBAR
L5724:  LDA  #$F0
L5726:  STA  TEMP1
L5728:  LDA  TEMP7                  ;SIN OF RELATIVE ANGLE
L572A:  JSR  OutputTemp2Temp21
L572D:  STA  TEMP6
L572F:  STA  TEMP1                  ;PREPARE FOR NEXT MULTIPLY
L5731:  LDA  TEMP7B                 ;ANGLE OF BAR
L5733:  JSR  CosSinPi2
L5736:  JSR  SignedBySignedMult     ;INTRINSIC DIVISION BY 2 OCCURRED
L5739:  LDY  #$00                   ;SIGN EXTENSION
L573B:  ASL                         ;SET STATUS
L573C:  BPL  ThrustTwoShips_20
L573E:  DEY

ThrustTwoShips_20:
L573F:  CLC
L5740:  ADC  BYINCL
L5743:  STA  BYINCL
L5746:  TYA
L5747:  ADC  $0255
L574A:  JSR  OutRange
L574D:  STA  $0255
L5750:  LDA  TEMP6
L5752:  STA  TEMP1
L5754:  LDA  TEMP7B                 ;ANGLE OF BAR
L5756:  CLC
L5757:  ADC  #$40
L5759:  JSR  CosSinPi2
L575C:  JSR  SignedBySignedMult
L575F:  LDY  #$00                   ;SIGN EXTENSION
L5761:  ASL                         ;SET STATUS
L5762:  BPL  ThrustTwoShips_30
L5764:  DEY

ThrustTwoShips_30:
L5765:  CLC
L5766:  ADC  BXINCL
L5769:  STA  BXINCL
L576C:  TYA
L576D:  ADC  $0223
L5770:  JSR  OutRange
L5773:  STA  $0223
L5776:  LDA  #$F0
L5778:  STA  TEMP1                  ;MULTIPLIER
L577A:  LDA  TEMP5                  ;RELATIVE ANGLE
L577C:  JSR  CosSinPi2
L577F:  JSR  OutputTemp2Temp21
L5782:  STA  TEMP6                  ;STORE TRANSLATION AMOUNT
L5784:  STA  TEMP1                  ;FOR MULTIPLY
L5786:  LDA  TEMP7B
L5788:  JSR  CosSinPi2
L578B:  JSR  SignedBySignedMult
L578E:  LDY  #$00                   ;SIGN EXTENSION
L5790:  ASL  TEMP2                  ;BEGIN MULTIPLY BY TWO
L5792:  ROL
L5793:  BPL  ThrustTwoShips_40
L5795:  DEY                         ;NEGATIVE

ThrustTwoShips_40:
L5796:  CLC
L5797:  ADC  BXINCL
L579A:  STA  BXINCL
L579D:  TYA
L579E:  ADC  $0223
L57A1:  JSR  OutRange
L57A4:  STA  $0223
L57A7:  LDA  TEMP6
L57A9:  STA  TEMP1                  ;FOR MULTIPLY
L57AB:  LDA  TEMP7B
L57AD:  JSR  PiAngle0
L57B0:  JSR  SignedBySignedMult
L57B3:  LDY  #$00                   ;SIGN EXTENSION
L57B5:  ASL  TEMP2
L57B7:  ROL
L57B8:  BPL  ThrustTwoShips_50
L57BA:  DEY                         ;NEGATIVE

ThrustTwoShips_50:
L57BB:  CLC
L57BC:  ADC  BYINCL
L57BF:  STA  BYINCL
L57C2:  TYA
L57C3:  ADC  $0255
L57C6:  JSR  OutRange
L57C9:  STA  $0255
L57CC:  RTS

Dorigex:
L57CD:  RTS

Dorigid:
L57CE:  LDA  OBSHIP
L57D0:  ORA  $B9
L57D2:  BNE  Dorig3                 ;AT LEAST ONE SHIP ON SCREEN

Dorig2:
L57D4:  LDA  HITS
L57D6:  BEQ  Dorigex
L57D8:  LDA  SDELAY
L57DB:  ORA  $026E
L57DE:  BEQ  Dorigex                ;THEY WERE NOT WAITING
L57E0:  LDA  SDELAY
L57E3:  BEQ  Dorig2_10
L57E5:  DEC  SDELAY

Dorig2_10:
L57E8:  LDA  $026E
L57EB:  BEQ  Dorig2_20
L57ED:  DEC  $026E

Dorig2_20:
L57F0:  LDA  SDELAY
L57F3:  ORA  $026E
L57F6:  BNE  Dorig4
L57F8:  JSR  InitiaizePair
L57FB:  LDX  #$02
L57FD:  LDY  #$20
L57FF:  JSR  ShipDeadSoWill         ;CHECK FOR NEARBY OBJECTS
L5802:  BNE  Dorig2_25              ;TRAFFIC
L5804:  JSR  EntryNoRequirementsExit
L5807:  BEQ  Attract                ;NO ENEMIES

Dorig2_25:
L5809:  INC  SDELAY
L580C:  INC  $026E                  ;IF NEEDED

Dorig4:
L580F:  RTS

Attract:
L5810:  BIT  ATRACT                 ;ATTRACT?
L5812:  BPL  Attract_1              ;IF YES, DONT LOSE LIVES
L5814:  DEC  HITS
L5816:  DEC  $48

Attract_1:
L5818:  LDA  #$BF                   ;SCORE AND LIVES
L581A:  STA  CMBSCFLAG
L581D:  LDA  #$02
L581F:  STA  OBSHIP
L5821:  STA  $B9
L5823:  STA  OBPAIR
L5825:  LDA  #$00
L5827:  STA  SCRFUL
L5829:  STA  COMOFF                 ;ALLOW ENEMIES
L582C:  STA  COMTIMER               ;END THE ONSLAUGHT
L582F:  STA  NENTDWARF
L5832:  STA  NENTCOMETS
L5835:  JSR  ResetEnemyTimers

Dorig3:
L5838:  LDA  SPARKTIME              ;FUSE GOING???
L583B:  BPL  Dorig3_16
L583D:  LDX  #$01

Dorig3_10:
L583F:  LDA  OBSHIP,X               ;THIS ONE HERE???
L5841:  BNE  Dorig3_15              ;YEP...SO SKIP IT
L5843:  LDA  PRTDAMAGE,X            ;NOT HERE...WAS DAMAGED??
L5846:  BEQ  Dorig3_15              ;IF NOT....NOT THIS ROUTINE PROBLEM
L5848:  LDA  #$02
L584A:  STA  OBSHIP,X               ;RETURN SHIP
L584C:  STA  ENTER,X                ;GIVE SHIELDS ON ENTRY

Dorig3_15:
L584F:  DEX
L5850:  BPL  Dorig3_10              ;DO BOTH

Dorig3_16:
L5852:  LDX  #$01

Dorig3_20:
L5854:  STX  TEMP3
L5856:  LDA  SDELAY,X
L5859:  BNE  Dorig3_71
L585B:  BIT  TOGDRONE
L585D:  BPL  Dorig3_50              ;NOT DRONE
L585F:  CLC                         ;YES, WANT TO THRUST THIS FRAME
L5860:  LDX  #$00
L5862:  BEQ  Dorig3_55              ;(ALWAYS)

Dorig3_50:
L5864:  TXA
L5865:  EOR  FRAME
L5867:  LSR                         ;SET CARRY

Dorig3_55:
L5868:  BIT  ATRACT
L586A:  BMI  Dorig3_56
L586C:  LDA  $140A
L586F:  JMP  Dorig3_57

Dorig3_56:
L5872:  LDA  STRT1,X

Dorig3_57:
L5875:  BCS  Dorig3_70              ;NOT CHECK THRUST THIS FRAME
L5877:  BPL  Dorig3_70              ;NO THRUST
L5879:  JSR  ThrustTwoShips
L587C:  LDX  TEMP3
L587E:  JSR  ThrustSound            ;THRUST ON

Dorig3_70:
L5881:  LDX  TEMP3

Dorig3_75:
L5883:  JSR  WillAssumeRadiusBar

Dorig3_71:
L5886:  LDX  TEMP3
L5888:  DEX
L5889:  BPL  Dorig3_20
L588B:  LDA  LWBAR
L588E:  CLC
L588F:  ADC  BANGLL
L5892:  STA  BANGLL
L5895:  LDA  UWBAR
L5898:  ADC  BANGLE
L589B:  STA  BANGLE
L589E:  LDA  STRT1
L58A1:  BIT  TOGDRONE
L58A3:  BMI  Dorig3_80              ;PLAYER 1 THRUST NOT COUNT
L58A5:  ORA  OPTNA1

Dorig3_80:
L58A8:  ASL
L58A9:  BCC  Dorig3_82              ;NO ACTIVE THRUST IS ON
L58AB:  RTS                         ;(EXIT)

Dorig3_82:
L58AC:  LDY  #$00
L58AE:  LDA  BXINCL
L58B1:  STA  TEMPA                  ;NOT NEEDED
L58B3:  ORA  $0223
L58B6:  BEQ  Dorig3_27              ;IF X=0
L58B8:  LDA  $0223
L58BB:  EOR  #$FF
L58BD:  SEC
L58BE:  BPL  Dorig3_26              ;IF IT WAS POSITIVE
L58C0:  DEY                         ;SIGN EXTEASION
L58C1:  CLC

Dorig3_26:
L58C2:  ADC  BXINCL
L58C5:  STA  BXINCL
L58C8:  TYA
L58C9:  ADC  $0223
L58CC:  STA  $0223

Dorig3_27:
L58CF:  LDY  #$00
L58D1:  LDA  BYINCL
L58D4:  STA  TEMPA                  ;NOT NEEDED
L58D6:  ORA  $0255
L58D9:  BEQ  Dorig3_29              ;IF Y=0
L58DB:  LDA  $0255
L58DE:  SEC
L58DF:  EOR  #$FF
L58E1:  BPL  Dorig3_28              ;IF WAS POSITIVE
L58E3:  DEY
L58E4:  CLC

Dorig3_28:
L58E5:  ADC  BYINCL
L58E8:  STA  BYINCL
L58EB:  TYA
L58EC:  ADC  $0255
L58EF:  STA  $0255

Dorig3_29:
L58F2:  LDY  #$00
L58F4:  LDA  LWBAR
L58F7:  STA  TEMPA                  ;NOT NEEDED
L58F9:  ORA  UWBAR
L58FC:  BEQ  Dorig3_90              ;IF X=0
L58FE:  LDA  UWBAR
L5901:  EOR  #$FF
L5903:  SEC
L5904:  BPL  Dorig3_36              ;IF IT WAS POSITIVE
L5906:  DEY                         ;SIGN EXTEASION
L5907:  CLC

Dorig3_36:
L5908:  ADC  LWBAR
L590B:  STA  LWBAR
L590E:  TYA
L590F:  ADC  UWBAR
L5912:  STA  UWBAR

Dorig3_90:
L5915:  RTS

CheckForRocksNearby:
L5916:  LDY  #$22

ShipDeadSoWill:
L5918:  LDA  OBJ,Y
L591B:  BEQ  L_80                   ;OBJECT NOT ALIVE
L591D:  LDA  OBJXH,Y
L5920:  SEC
L5921:  SBC  $02D6,X
L5924:  CMP  #$08
L5926:  BCC  L_20                   ;IF CLOSE ENOUGH
L5928:  CMP  #$F9
L592A:  BCC  L_80
L592C:  CMP  #$FD
L592E:  BCS  L_40                   ;CLOSE IN X
L5930:  LDA  XINC,Y
L5933:  BMI  L_80                   ;GOING OUT OF THE WAY
L5935:  BPL  L_40

L_20:
L5937:  CMP  #$04
L5939:  BCC  L_40                   ;VERY CLOSE IN X
L593B:  LDA  XINC,Y
L593E:  BPL  L_80                   ;; GOING OUT OF WAY

L_40:
L5940:  LDA  OBJYH,Y
L5943:  SEC
L5944:  SBC  $0308,X
L5947:  CMP  #$08
L5949:  BCC  L_50
L594B:  CMP  #$F9
L594D:  BCC  L_80                   ;FAR AWAY
L594F:  CMP  #$FD
L5951:  BCS  L_90                   ;TOO CLOSE
L5953:  LDA  YINC,Y
L5956:  BMI  L_80                   ;GOING OUT OF WAY
L5958:  BPL  L_90                   ;CLOSE, AND COMING IN

L_50:
L595A:  CMP  #$04
L595C:  BCC  L_90                   ;TOO CLOSE
L595E:  LDA  YINC,Y
L5961:  BMI  L_90

L_80:
L5963:  DEY
L5964:  BPL  ShipDeadSoWill         ;LOOP THRU ALL OBJECTS

L_90:
L5966:  INY                         ;ADJUST ZERO FLAG ON EXIT
L5967:  RTS

InitialPositionSpaceDuel:
L5968:  .byte $03, $06, $09, $0C, $0F, $15, $18, $1B
L5970:  .byte $1E, $00, $00, $00, $00, $00, $00

Newp2:
L5977:  BIT  ATSTG
L5979:  BPL  GetNewVelocity         ;NORMAL
L597B:  TXA
L597C:  AND  #$0F
L597E:  TAY                         ;POSITION INDEX
L597F:  LDA  $5967,Y
L5982:  STA  OBJXH,X
L5985:  LDA  #$10
L5987:  STA  OBJYH,X                ;ALL SAME Y POSITION
L598A:  LDA  #$00
L598C:  STA  XINC,X
L598F:  STA  YINC,X                 ;NO MOTION
L5992:  STA  OBJXL,X
L5995:  BEQ  Newout

GetNewVelocity:
L5997:  JSR  NewRandomVelocityUsing ;GET NEW VELOCITY
L599A:  LDA  $100A                  ;RANDOM NUMBER
L599D:  LSR
L599E:  AND  #$1F
L59A0:  BCC  GetNewVelocity_50      ;START ON X AXIS
L59A2:  CMP  #$18                   ;START ON Y AXIS
L59A4:  BCC  GetNewVelocity_35      ;IF 0 TO 767
L59A6:  AND  #$17

GetNewVelocity_35:
L59A8:  STA  OBJYH,X
L59AB:  LDA  #$00
L59AD:  STA  OBJXH,X
L59B0:  STA  OBJXL,X
L59B3:  RTS                         ;(EXIT)

GetNewVelocity_50:
L59B4:  STA  OBJXH,X
L59B7:  LDA  #$00
L59B9:  STA  OBJYH,X

Newout:
L59BC:  STA  OBJYL,X

Newaex:
L59BF:  RTS

NewastStartNewAsteroids:
L59C0:  LDA  GENDING
L59C2:  BNE  Newaex                 ;NOT IF IN GAME ENDING
L59C4:  LDA  ATRACT
L59C6:  BMI  NewastStartNewAsteroids_29 ;NOT ATTRACT
L59C8:  LDA  $45
L59CA:  AND  #$07                   ;WAIT TO START ROCKS
L59CC:  ORA  SHHIGH                 ;WAIT FOR END OF INITIALS
L59CF:  BNE  Newaex                 ;ELSE WAIT
L59D1:  JMP  NewastStartNewAsteroids_1

NewastStartNewAsteroids_29:
L59D4:  JSR  EntryNoRequirementsExit
L59D7:  BNE  Newaex
L59D9:  LDA  NENTCOMETS
L59DC:  ORA  NENTDWARF
L59DF:  BEQ  NewastStartNewAsteroids_71 ;NONE LEFT
L59E1:  LDA  COMTIMER               ;ANY TIME LEFT?
L59E4:  BNE  Newaex                 ;WILL WAIT

NewastStartNewAsteroids_71:
L59E6:  LDA  #$03
L59E8:  CMP  COMTIMER
L59EB:  BCS  NewastStartNewAsteroids_8
L59ED:  STA  COMTIMER

NewastStartNewAsteroids_8:
L59F0:  LDA  COMTIMER               ;JUST IN CASE WE FELL THROUGH
L59F3:  BNE  Newaex
L59F5:  LDA  GAME                   ;WHICH GAME?
L59F7:  BEQ  NewastStartNewAsteroids_1 ;START ANYTIME ON GAME 0 (2PLR FIGHTERS)
L59F9:  LDA  SDELAY
L59FC:  ORA  $026E
L59FF:  BNE  Newaex

NewastStartNewAsteroids_1:
L5A01:  LDA  #$00                   ;MIGHT WANT TO TURN THIS OFF
L5A03:  BIT  ATRACT
L5A05:  BMI  NewastStartNewAsteroids_42 ;NOT ATRACT
L5A07:  LDA  ATSTG
L5A09:  EOR  #$80                   ;ALT SPECIAL FLAG

NewastStartNewAsteroids_42:
L5A0B:  STA  ATSTG
L5A0D:  BIT  ATSTG                  ;SPECIAL ATRACT?????HUH?
L5A0F:  BPL  NewastStartNewAsteroids_44 ;NOT THIS TIME CHARLIE!
L5A11:  LDA  #$00
L5A13:  LDX  #$10                   ;CLEAR ALL SHOTS TOO

NewastStartNewAsteroids_43:
L5A15:  STA  OBSAUCER,X             ;CLR SAUCERS, SHIPS, AND SHOTS
L5A17:  DEX
L5A18:  BPL  NewastStartNewAsteroids_43

NewastStartNewAsteroids_44:
L5A1A:  LDA  #$FF
L5A1C:  STA  TEMP8                  ;USED FOR RANDOM SPINNER DIRECTION
L5A1E:  INC  WAVE                   ;NEXT WAVE
L5A21:  CLC
L5A22:  LDA  DIFCTY                 ;CURRENT DIFF LEVEL (GAME PLAY)
L5A24:  LDX  DIFF                   ;OPTION SETTING FOR INCREASE DIFF
L5A26:  ADC  DifctyIncreaseBasedDiff,X
L5A29:  CMP  #$09                   ;WANT TO MAX OUT AT 9
L5A2B:  BCC  NewastStartNewAsteroids_2
L5A2D:  LDA  #$09

NewastStartNewAsteroids_2:
L5A2F:  STA  DIFCTY
L5A31:  LDA  ATRACT
L5A33:  BNE  NewastStartNewAsteroids_4
L5A35:  LDA  #$07
L5A37:  BIT  ATSTG                  ;SPECIAL ATRACT?
L5A39:  BMI  NewastStartNewAsteroids_22 ;YEP...DO 9 SHAPES
L5A3B:  LDA  #$01

NewastStartNewAsteroids_22:
L5A3D:  STA  DIFCTY
L5A3F:  STA  WAVE
L5A42:  LDX  #$05
L5A44:  LDA  #$00

NewastStartNewAsteroids_3:
L5A46:  STA  OBKLMINES,X
L5A48:  DEX
L5A49:  BPL  NewastStartNewAsteroids_3

NewastStartNewAsteroids_4:
L5A4B:  LDA  DIFCTY

NewastStartNewAsteroids_6:
L5A4D:  CLC
L5A4E:  ADC  #$02
L5A50:  TAX                         ;COUNTER FOR NUMBER OF ROCKS TO INITIATE
L5A51:  STA  NROCKS
L5A54:  LDY  #$00
L5A56:  TYA
L5A57:  LDX  #$10

NewastStartNewAsteroids_7:
L5A59:  STA  OBJ,X
L5A5B:  DEX                         ;REMOVE ALL ROCKS
L5A5C:  BPL  NewastStartNewAsteroids_7 ;BEFORE STARTING
L5A5E:  STA  MODNUM                 ;SO IT WILL START OVER FIRST TIME
L5A61:  LDX  NROCKS
L5A64:  STY  XINC                   ;LOWEST ROCK
L5A67:  STY  YINC

NewastStartNewAsteroids_10:
L5A6A:  JSR  L80RandomWave0
L5A6D:  ORA  #$04                   ;ADD SIZE
L5A6F:  STA  OBJ,X                  ;SET PICTURE
L5A71:  JSR  Newp2
L5A74:  DEX
L5A75:  BNE  NewastStartNewAsteroids_10 ;LOOP FOR EACH NEW ROCK

NewastStartNewAsteroids_75:
L5A77:  LDA  #$00
L5A79:  STA  SCRFUL                 ;SCREEN NOT FULL
L5A7B:  STA  COMOFF
L5A7E:  LDA  DIFCTY
L5A80:  SEC
L5A81:  SBC  #$01                   ;#=WAVE-1
L5A83:  BEQ  NewastStartNewAsteroids_80
L5A85:  STA  TEMP1                  ;COUNTER
L5A87:  LDA  #$00
L5A89:  STA  KLMOFF                 ;MINES TO STAY

NewastStartNewAsteroids_76:
L5A8B:  JSR  InitiateKillerMine
L5A8E:  DEC  TEMP1
L5A90:  BNE  NewastStartNewAsteroids_76

NewastStartNewAsteroids_80:
L5A92:  LDA  WAVE
L5A95:  TAY                         ;SAVE EXTRA COPY OF A
L5A96:  LDX  DIFF                   ;WILL USE THIS TO MAKE ROCKS FASTER
L5A98:  AND  RockSpeedUpEvery,X     ;EVERY N'TH FRAME, SPEED UP ROCKS HIGH END
L5A9B:  BNE  ResetEnemyTimers
L5A9D:  CLC
L5A9E:  LDA  ROCKMAX                ;UP MAX VELOCITY EVERY NEW WAVE
L5AA0:  ADC  RockSpeedUpAmount,X    ;AMOUNT TO ADD
L5AA3:  CMP  #$3F                   ;DONT LET GO TO FAST
L5AA5:  BCS  NewastStartNewAsteroids_81
L5AA7:  STA  ROCKMAX
L5AA9:  EOR  #$FF                   ;DO THE MAX NEG ALSO
L5AAB:  ADC  #$01                   ;CARRY WAS CLEAR
L5AAD:  STA  $D8

NewastStartNewAsteroids_81:
L5AAF:  TYA
L5AB0:  AND  MimVelocitySpeedUp,X   ;EVERY X'TH FRAME SPEED UP ROCKS MIM ALLOWED VEL
L5AB3:  BNE  ResetEnemyTimers       ;MOVE UP BOTTOM EVERY EIGHT FRAMES
L5AB5:  LDA  ROCKMIN
L5AB7:  ADC  MinVelocityAddAmount,X ;AMOUNT TO MOVE BOTTOM
L5ABA:  CMP  #$30                   ;MAX MIN WILL BE 30
L5ABC:  BCS  ResetEnemyTimers
L5ABE:  STA  ROCKMIN
L5AC0:  EOR  #$FF
L5AC2:  ADC  #$01                   ;NEG
L5AC4:  STA  $D6

ResetEnemyTimers:
L5AC6:  LDX  #$01

ResetEnemyTimers_85:
L5AC8:  LDA  MXRTIMER,X
L5ACB:  STA  RTIMER,X
L5ACE:  LDA  #$7F                   ;MAX DELAY ON NEW ASTEROIDS
L5AD0:  STA  ENMDEL,X
L5AD3:  DEX
L5AD4:  BPL  ResetEnemyTimers_85
L5AD6:  RTS

InitiaizePair:
L5AD7:  LDA  #$00
L5AD9:  STA  BANGLE                 ;HORIZONTAL
L5ADC:  STA  LWBAR
L5ADF:  STA  UWBAR                  ;NO ANGUBR ACCELARATION
L5AE2:  STA  $0223                  ;NO VELOCITY
L5AE5:  STA  $0255
L5AE8:  LDA  #$80
L5AEA:  STA  BANGLL
L5AED:  STA  BXINCL
L5AF0:  STA  BYINCL
L5AF3:  STA  SPARKTIME
L5AF6:  LDA  #$F0
L5AF8:  STA  SHLDENG
L5AFB:  STA  $0274
L5AFE:  LDX  #$02

Newship:
L5B00:  LDA  #$00
L5B02:  STA  $0341,X
L5B05:  STA  $0373,X
L5B08:  STA  PRTDAMAGE              ;RESET DAMAGE
L5B0B:  STA  $0389
L5B0E:  LDA  #$10
L5B10:  STA  $02D6,X
L5B13:  LDA  #$0C
L5B15:  STA  $0308,X
L5B18:  CPX  #$02                   ;PAIR BACK?
L5B1A:  BNE  Newship_10             ;NO
L5B1C:  LDA  #$50                   ;SOUND & EFFECT
L5B1E:  STA  ENTER
L5B21:  STA  $03E8
L5B24:  JSR  Reenter2
L5B27:  JMP  Reenter

Newship_10:
L5B2A:  RTS

CopyAttributesOfRock:
L5B2B:  LDA  OBJXL,Y                ;COPY POSITION
L5B2E:  STA  OBJXL,X
L5B31:  LDA  OBJXH,Y
L5B34:  STA  OBJXH,X
L5B37:  LDA  OBJYL,Y
L5B3A:  STA  OBJYL,X
L5B3D:  LDA  OBJYH,Y
L5B40:  STA  OBJYH,X
L5B43:  LDA  XINC,Y                 ;COPY VELOCITY
L5B46:  STA  YINC,X
L5B49:  STA  YINC,X
L5B4C:  LDA  OBJ,Y                  ;COPY PICTURE
L5B4F:  BIT  ATSTG                  ;RANDOM ROCKS?
L5B51:  BMI  L5B5C
L5B53:  AND  #$07
L5B55:  STA  TEMP1                  ;SAVE SIZE
L5B57:  JSR  L80RandomWave0         ;NEW PIC
L5B5A:  ORA  TEMP1                  ;ADD SIZE
L5B5C:  STA  OBJ,X

NewRandomVelocityUsing:
L5B5E:  LDA  $100A                  ;RANDOM NUMBER
L5B61:  AND  #$BF
L5B63:  BPL  NewRandomVelocityUsing_10 ;IF POSITIVE NUMBER 0 TO 3
L5B65:  ORA  #$F0                   ;-1 TO -4

NewRandomVelocityUsing_10:
L5B67:  CLC
L5B68:  ADC  XINC,Y
L5B6B:  JSR  PositiveResulults      ;CHECK RANGE OF VELOCITIES
L5B6E:  STA  XINC,X
L5B71:  LDA  $100A
L5B74:  AND  #$BF
L5B76:  BPL  NewRandomVelocityUsing_40 ;POSITIVE NUMBER 0 TO 3
L5B78:  ORA  #$F0                   ;NEGATIVE -1 TO -4

NewRandomVelocityUsing_40:
L5B7A:  CLC
L5B7B:  ADC  YINC,Y
L5B7E:  JSR  PositiveResulults      ;CHECK RANGE OF VELOCITY
L5B81:  STA  YINC,X
L5B84:  RTS

PositiveResulults:
L5B85:  BPL  Newve5                 ;POSITIVE RESULULTS
L5B87:  CMP  $D8
L5B89:  BCS  Newve3                 ;WITHIN RANGE
L5B8B:  LDA  $D8

Newve3:
L5B8D:  CMP  $D6
L5B8F:  BCC  Newve3_20              ;NOT TOO CLOSE TO ZERO
L5B91:  LDA  $D6                    ;AT LEAST 1/2

Newve3_20:
L5B93:  RTS

Newve5:
L5B94:  CMP  ROCKMAX
L5B96:  BCC  Newve7                 ;WITHIN RANGE
L5B98:  LDA  ROCKMAX

Newve7:
L5B9A:  CMP  ROCKMIN
L5B9C:  BCS  Newve7_30              ;NOT TOO CLOSE TO ZERO
L5B9E:  LDA  ROCKMIN

Newve7_30:
L5BA0:  RTS

MinVelocity:
L5BA1:  BPL  Newve7
L5BA3:  BMI  Newve3

RockSpeedUpAmount:
L5BA5:  .byte $02, $04, $05, $06

MinVelocityAddAmount:
L5BA9:  .byte $01, $03, $04, $05

DifctyIncreaseBasedDiff:
L5BAD:  .byte $01, $01, $02, $02

RockSpeedUpEvery:
L5BB1:  .byte $03, $01, $01, $00

MimVelocitySpeedUp:
L5BB5:  .byte $07, $03, $01, $00

ProcessShields:
L5BB9:  LDX  #$01

ProcessShields_20:
L5BBB:  LDA  TOGGLE,X
L5BBD:  AND  #$7F
L5BBF:  STA  TOGGLE,X
L5BC1:  JSR  TwinGameBothShields    ;READ SHIELD SWITCH
L5BC4:  BPL  ProcessShields_80
L5BC6:  LDY  OBSHIP,X
L5BC8:  BEQ  ProcessShields_80      ;HE IS ALIVE, BUT NOT SHOWING NOW
L5BCA:  BMI  ProcessShields_80      ;NO SHIELDS WHEN IN SUSPENDED ANIMATION
L5BCC:  LDY  SHLDENG,X
L5BCF:  BEQ  ProcessShields_80
L5BD1:  ORA  #$80
L5BD3:  STA  TOGGLE,X
L5BD5:  CPX  #$01
L5BD7:  BEQ  ProcessShields_41
L5BD9:  JSR  Sh0sn                  ;SHIELD SOUND
L5BDC:  JMP  ProcessShields_43

ProcessShields_41:
L5BDF:  JSR  Sh1sn

ProcessShields_43:
L5BE2:  JSR  Game23Shields          ;TAKE OUT SHIELD ENERGY

ProcessShields_80:
L5BE5:  DEX
L5BE6:  BPL  ProcessShields_20

ProcessShields_90:
L5BE8:  RTS

TwinGameBothShields:
L5BE9:  BIT  ATRACT
L5BEB:  BPL  TwinGameBothShields_40 ;SKIP THIS DURING ATTRACT
L5BED:  LDY  GAME
L5BEF:  CPY  #$03
L5BF1:  BNE  TwinGameBothShields_30 ;NORMAL
L5BF3:  LDY  HYPSW                  ;ONE PLAYER
L5BF6:  JMP  TwinGameBothShields_40

TwinGameBothShields_30:
L5BF9:  LDY  HYPSW,X                ;HYPERSPACE SWITCH

TwinGameBothShields_40:
L5BFC:  RTS

Game23Shields:
L5BFD:  LDA  GAME                   ;GAME 2&3, SHIELDS DROP HALF SPEED
L5BFF:  CMP  #$02
L5C01:  BCC  Game23Shields_45
L5C03:  LDA  LSHLDENG,X
L5C06:  SEC
L5C07:  SBC  #$18
L5C09:  JMP  Game23Shields_46

Game23Shields_45:
L5C0C:  LDA  LSHLDENG,X
L5C0F:  SEC
L5C10:  SBC  #$30

Game23Shields_46:
L5C12:  STA  LSHLDENG,X
L5C15:  LDA  SHLDENG,X
L5C18:  SBC  #$00                   ;SBC 1 IF BORROW
L5C1A:  CMP  #$18
L5C1C:  BCS  Game23Shields_70
L5C1E:  LDA  #$00

Game23Shields_70:
L5C20:  STA  SHLDENG,X
L5C23:  RTS

Temp3WhichPlayer0:
L5C24:  LDY  #$03                   ;3 DIGIT PAIRS
L5C26:  SEC                         ;ZERO SUPPRESSION ON
L5C27:  JSR  SaveInpuParameers
L5C2A:  LDA  #$00
L5C2C:  JSR  DisplayDigit           ;ADD PHANTOM 0 TO SCORE
L5C2F:  LDX  TEMP3
L5C31:  LDA  PL0SCFLAG,X
L5C34:  ASL
L5C35:  BMI  Temp3WhichPlayer0_80   ;GOOD, DONT NEED TO CHANGE HUES
L5C37:  BIT  TOGCOMB
L5C39:  BPL  Temp3WhichPlayer0_30   ;NOT COMBINED LIVES
L5C3B:  CPX  #$02                   ;FOR COMBINED LIVES
L5C3D:  BNE  Temp3WhichPlayer0_70   ;NOT SHOW INDIVIDUAL LIVES
L5C3F:  LDX  #$00                   ;CHECK PLAYER 0'S LIVES

Temp3WhichPlayer0_30:
L5C41:  LDA  HITS,X

Temp3WhichPlayer0_40:
L5C43:  BEQ  Temp3WhichPlayer0_70
L5C45:  BMI  Temp3WhichPlayer0_70   ;MAY NOT BE NEEDED

Temp3WhichPlayer0_50:
L5C47:  STA  TEMP1
L5C49:  LDA  GAME                   ;IF GAME 3, DON'T FLIP PLAYER 1
L5C4B:  CMP  #$03
L5C4D:  BNE  Temp3WhichPlayer0_51
L5C4F:  STA  UPDOWN                 ;CLEAR 'UPDOWN' FOR REST OF ROUTINE AS WELL

Temp3WhichPlayer0_51:
L5C52:  LDX  #$A8
L5C54:  LDA  #$4E
L5C56:  BIT  UPDOWN
L5C59:  BPL  Temp3WhichPlayer0_55   ;NORMAL
L5C5B:  LDX  #$A8
L5C5D:  LDA  #$52

Temp3WhichPlayer0_55:
L5C5F:  JSR  Add2WordsToVector

Temp3WhichPlayer0_60:
L5C62:  LDY  TEMP3
L5C64:  LDA  $30AC,Y
L5C67:  LDX  $30AF,Y
L5C6A:  BIT  UPDOWN
L5C6D:  BPL  Temp3WhichPlayer0_65   ;NORMAL
L5C6F:  LDA  $30B1,Y
L5C72:  LDX  $30B3,Y

Temp3WhichPlayer0_65:
L5C75:  JSR  Add2WordsToVector
L5C78:  DEC  TEMP1
L5C7A:  BNE  Temp3WhichPlayer0_60

Temp3WhichPlayer0_70:
L5C7C:  JSR  AddRtslToVector

Temp3WhichPlayer0_80:
L5C7F:  RTS

Entparams:
L5C80:  LDA  RDELAY
L5C83:  BEQ  Entparams_80
L5C85:  BIT  ATRACT                 ;ATTRACT?
L5C87:  BPL  Entparams_80
L5C89:  LDA  FRAME
L5C8B:  AND  #$04
L5C8D:  BEQ  Entparams_80
L5C8F:  LDA  #$00                   ;UP MESSAGE
L5C91:  STA  UPDOWN

Entparams_20:
L5C94:  LDA  #$E0
L5C96:  LDX  #$10
L5C98:  JSR  Mesgpos
L5C9B:  LDX  #$01                   ;USE OFFSET 1 HERE
L5C9D:  JSR  AuxRoutineAddOffset
L5CA0:  LDY  #$14                   ;DISPLAY 'BONUS LEVEL'
L5CA2:  LDX  #$A7
L5CA4:  JSR  Brightness
L5CA7:  LDY  #$01
L5CA9:  LDA  #$CF                   ;DISPLAY BONUS AMOUNT
L5CAB:  SEC                         ;ZERO SUPPRESSION
L5CAC:  JSR  SaveInpuParameers
L5CAF:  LDA  #$00
L5CB1:  JSR  DisplayDigit           ;PHANTOM ZERO
L5CB4:  LDA  UPDOWN
L5CB7:  BMI  Entparams_80           ;ALREADY DID EXTRA
L5CB9:  LDA  CABERE                 ;EXTRA MESSAGE NOT NEEDED
L5CBC:  BPL  Entparams_80           ;NO
L5CBE:  STA  UPDOWN                 ;NEED UPSIDE DOWN MSG?
L5CC1:  LDA  GAME                   ;BUT...
L5CC3:  CMP  #$03                   ;NOT FOR GAME 3
L5CC5:  BNE  Entparams_20           ;DO EXTRA MESSAGE

Entparams_80:
L5CC7:  LDA  COMTIMER
L5CCA:  BEQ  Entparams_85
L5CCC:  LDA  FRAME                  ;USE FRAME FOR COLORS
L5CCE:  LSR
L5CCF:  LSR
L5CD0:  LSR
L5CD1:  LSR
L5CD2:  BNE  Entparams_81           ;NO BLACK
L5CD4:  LDA  #$01

Entparams_81:
L5CD6:  ORA  INTEN
L5CD9:  TAY
L5CDA:  JSR  SetVectorGeneratorStatus
L5CDD:  LDA  #$62
L5CDF:  LDX  #$A8
L5CE1:  JSR  Add2WordsToVector

Entparams_85:
L5CE4:  LDA  #$5E
L5CE6:  LDX  #$A8
L5CE8:  JSR  Add2WordsToVector
L5CEB:  LDA  #$8A
L5CED:  LDX  #$A1
L5CEF:  JMP  Add2WordsToVector      ;TO COVER HARDWARS ASS.....

DisplayParameters:
L5CF2:  LDA  #$00
L5CF4:  STA  TEMP3                  ;USED TO KEEP TRACK OF PLAYER IN DIGLIV
L5CF6:  BIT  PL0SCFLAG
L5CF9:  BPL  DisplayParameters_10   ;SCORE NOT CHANGED
L5CFB:  LDA  #$80
L5CFD:  STA  VGLIST
L5CFF:  LDA  #$23
L5D01:  STA  EAC2
L5D03:  LDA  #$00                   ;RESET FLAG
L5D05:  STA  PL0SCFLAG
L5D08:  STA  UPDOWN                 ;NO FLIP FOR COCKTAIL HERE
L5D0B:  LDA  #$3A                   ;PLAYER 0 SCORE
L5D0D:  JSR  Temp3WhichPlayer0

DisplayParameters_10:
L5D10:  INC  TEMP3
L5D12:  BIT  PL1SCFLAG
L5D15:  BPL  DisplayParameters_20   ;SCORE NOT CHANGED
L5D17:  LDA  #$00
L5D19:  STA  PL1SCFLAG              ;RESET FLAG
L5D1C:  LDA  #$C0
L5D1E:  STA  VGLIST
L5D20:  LDA  #$23
L5D22:  STA  EAC2                   ;ABNORMAL VGLIST
L5D24:  LDA  CABERE                 ;(80 OR 0 DEPENDING ON CABINET)
L5D27:  STA  UPDOWN                 ;SET UP FOR POSSIBLE FLIP
L5D2A:  LDA  GAME
L5D2C:  CMP  #$03                   ;GAME 3 (1 PLYR STATIONS)?
L5D2E:  BNE  DisplayParameters_15   ;IF NOT, NEVER MIND.....
L5D30:  STA  UPDOWN                 ;ELSE, NO FLIP HERE

DisplayParameters_15:
L5D33:  LDA  #$3D
L5D35:  JSR  Temp3WhichPlayer0

DisplayParameters_20:
L5D38:  BIT  CMBSCFLAG
L5D3B:  BPL  DisplayParameters_40
L5D3D:  LDA  #$00
L5D3F:  STA  UPDOWN                 ;THIS ONE ALWAYS UPRIGHT
L5D42:  STA  CMBSCFLAG              ;RESTORE FLAG
L5D45:  LDA  #$80
L5D47:  STA  VGLIST
L5D49:  LDA  #$27
L5D4B:  STA  EAC2
L5D4D:  INC  TEMP3                  ;TEMP3 =2 SIGNIFIES COMBINED LIVES
L5D4F:  LDA  #$40
L5D51:  JSR  Temp3WhichPlayer0
L5D54:  LDA  #$80
L5D56:  STA  UPDOWN                 ;FLIP EXTRA COMBINED SCORE FOR COCKTAIL
L5D59:  LDA  #$36
L5D5B:  STA  VGLIST
L5D5D:  LDA  #$27
L5D5F:  STA  EAC2
L5D61:  LDA  #$40
L5D63:  JSR  Temp3WhichPlayer0

DisplayParameters_40:
L5D66:  LDA  #$00                   ;RESTORE UPDOWN FOR 'LATER' POSSIBLE CHANGE
L5D68:  STA  UPDOWN

DisplayParameters_50:
L5D6B:  RTS

EntryObjectBeingDisplayed:
L5D6C:  RTS

Pictur:
L5D6D:  CPX  #$1F                   ;JUST IN CASE SUPER SAUCER
L5D6F:  BNE  Pictur_1
L5D71:  JSR  AlwaysRemainsSameBoth

Pictur_1:
L5D74:  LDY  #$05
L5D76:  LDA  RED                    ;PUT VALUES INTO RIGHT FORMAT
L5D78:  SEC
L5D79:  SBC  #$10                   ;CONVERT TO 2'S COMPLEMENT
L5D7B:  LSR
L5D7C:  ROR  XCOMP
L5D7E:  AND  #$1F                   ;BRIGHTNESS OF 0
L5D80:  STA  (VGLIST),Y
L5D82:  DEY
L5D83:  LDA  XCOMP
L5D85:  STA  (VGLIST),Y
L5D87:  DEY
L5D88:  LDA  TWOPI
L5D8A:  SEC
L5D8B:  SBC  #$0C                   ;CORRECT TO 2'S COMPLEMENT
L5D8D:  LSR
L5D8E:  ROR  CHAN3V
L5D90:  AND  #$1F                   ;INSTRUCTION OF 0
L5D92:  STA  (VGLIST),Y
L5D94:  DEY
L5D95:  LDA  CHAN3V
L5D97:  STA  (VGLIST),Y
L5D99:  DEY
L5D9A:  LDA  #$A8
L5D9C:  STA  (VGLIST),Y
L5D9E:  DEY
L5D9F:  LDA  #$5B
L5DA1:  STA  (VGLIST),Y
L5DA3:  LDA  VGLIST
L5DA5:  CLC
L5DA6:  ADC  #$06
L5DA8:  STA  VGLIST
L5DAA:  BCC  Pictur_20
L5DAC:  INC  EAC2

Pictur_20:
L5DAE:  LDA  OBJ,X
L5DB0:  BPL  Pictur_35              ;IF NOT EXPLODING
L5DB2:  CPX  #$21
L5DB4:  BCC  Pictur_32              ;NOT THE SHIP
L5DB6:  CPX  #$23
L5DB8:  BCS  Pictur_32              ;NOT THE SHIP
L5DBA:  JMP  ShipExplodingPictures  ;EXPLODE SHIP

Pictur_32:
L5DBD:  LDA  OBJ,X
L5DBF:  EOR  #$F0
L5DC1:  BIT  SPECEX                 ;BIG ONES?
L5DC4:  BMI  L5DC9
L5DC6:  CLC
L5DC7:  ADC  #$10
L5DC9:  LSR                         ;THIS IS A TEST
L5DCA:  LSR
L5DCB:  LSR
L5DCC:  LSR
L5DCD:  ORA  #$70
L5DCF:  TAX
L5DD0:  LDA  #$00
L5DD2:  JSR  Add2WordsToVector
L5DD5:  LDX  TEMP3
L5DD7:  LDA  OBJ,X
L5DD9:  AND  #$0E
L5DDB:  PHA
L5DDC:  BIT  SPECEX                 ;SPECIAL EXPLOSIONS?
L5DDF:  BPL  L5DFA
L5DE1:  TXA
L5DE2:  AND  #$07
L5DE4:  BNE  L5DE8
L5DE6:  LDA  #$04                   ;DEFAULT RED
L5DE8:  ORA  #$F0
L5DEA:  LDX  #$64
L5DEC:  JSR  Add2WordsToVector
L5DEF:  PLA
L5DF0:  TAY
L5DF1:  LDA  $6E6C,Y
L5DF4:  LDX  $6E6D,Y
L5DF7:  JMP  L5E02
L5DFA:  PLA
L5DFB:  TAY
L5DFC:  LDA  $6E5C,Y
L5DFF:  LDX  $6E5D,Y
L5E02:  JMP  Add2WordsToVector      ;ADD 2 BYTES TO VGLIST

Pictur_35:
L5E05:  CPX  #$11
L5E07:  BCS  Pictur_40
L5E09:  BIT  SPECEX                 ;SPECIAL EXPLOSION?
L5E0C:  BPL  Pictur_8               ;NO
L5E0E:  LDX  #$72
L5E10:  LDA  #$00
L5E12:  JSR  Add2WordsToVector
L5E15:  LDA  #$88
L5E17:  LDX  #$AF
L5E19:  JMP  Add2WordsToVector

Pictur_8:
L5E1C:  LDY  #$00
L5E1E:  TYA
L5E1F:  STA  (VGLIST),Y             ;FULL LINEAR SCALE
L5E21:  LDA  OBJ,X
L5E23:  AND  #$07
L5E25:  TAY
L5E26:  LDA  $5F46,Y
L5E29:  STA  TEMP8                  ;SAVE FOR POSSIBLE LATER USE
L5E2B:  LDY  #$01
L5E2D:  STA  (VGLIST),Y
L5E2F:  INY
L5E30:  TXA
L5E31:  AND  #$07                   ;ONLY 7 COLORS
L5E33:  BNE  Pictur_5
L5E35:  LDA  #$03

Pictur_5:
L5E37:  ORA  #$E0                   ;ADD INTENSITY
L5E39:  STA  (VGLIST),Y
L5E3B:  INY
L5E3C:  LDA  #$64
L5E3E:  STA  (VGLIST),Y
L5E40:  INY
L5E41:  BIT  ATSTG                  ;WANT LETTERS
L5E43:  BPL  Pictur_7
L5E45:  LDA  #$C1
L5E47:  LDX  #$AC
L5E49:  STA  (VGLIST),Y
L5E4B:  INY
L5E4C:  TXA
L5E4D:  STA  (VGLIST),Y
L5E4F:  JMP  Pictur_15              ;CONTINUE

Pictur_7:
L5E52:  LDA  OBJ,X
L5E54:  AND  #$38                   ;ONE OF 4 PICTURES
L5E56:  LSR
L5E57:  LSR
L5E58:  TAX

Pictur_10:
L5E59:  LDA  $6ECD,X
L5E5C:  STA  (VGLIST),Y
L5E5E:  LDA  $6ECE,X
L5E61:  INY
L5E62:  STA  (VGLIST),Y

Pictur_15:
L5E64:  SEC
L5E65:  TYA
L5E66:  ADC  VGLIST
L5E68:  STA  VGLIST
L5E6A:  BCC  Pictur_37

Pictur_36:
L5E6C:  INC  EAC2

Pictur_37:
L5E6E:  BIT  ATSTG                  ;ATTRACT SPECIAL?
L5E70:  BPL  Pictur_39
L5E72:  INC  TEMP8                  ;NEXT SCALE SIZE
L5E74:  LDA  TEMP8
L5E76:  JSR  UseFullSize            ;ADD SCALE
L5E79:  LDA  TEMP3                  ;INDEX
L5E7B:  AND  #$0F
L5E7D:  TAX
L5E7E:  LDA  Cubltr,X
L5E81:  JMP  SaveCFlag

Pictur_39:
L5E84:  RTS                         ;(EXIT)

Pictur_40:
L5E85:  LDY  #$00
L5E87:  CPX  #$24
L5E89:  BCC  Pictur_74              ;NOT SHOT
L5E8B:  LDA  FRAME
L5E8D:  AND  #$03
L5E8F:  BNE  Pictur_85
L5E91:  DEC  OBJ,X

Pictur_85:
L5E93:  LDA  OBJ,X                  ;SHELL LIFE COUNTER
L5E95:  ASL
L5E96:  ASL
L5E97:  ASL
L5E98:  AND  #$F0
L5E9A:  CLC
L5E9B:  ADC  $5F27,X                ;ADD COLOR
L5E9E:  STA  (VGLIST),Y             ;CREATE A STAT INSTRUCTION
L5EA0:  LDA  #$64
L5EA2:  INY
L5EA3:  STA  (VGLIST),Y             ;FINISH INSTRUCTION
L5EA5:  INY
L5EA6:  CPX  #$28                   ;SAUCER SHOT?
L5EA8:  BCS  Pictur_86              ;NO
L5EAA:  LDA  #$00
L5EAC:  LDX  #$73                   ;SCALE FACTOR
L5EAE:  JSR  LsbByte
L5EB1:  LDA  #$C7
L5EB3:  LDX  #$64
L5EB5:  JSR  Add2WordsToVector      ;SET COLOR TO WHITE
L5EB8:  LDA  #$68
L5EBA:  LDX  #$A1
L5EBC:  JMP  Add2WordsToVector

Pictur_86:
L5EBF:  LDA  #$42
L5EC1:  LDX  #$AF
L5EC3:  BNE  Pictur_79              ;GO ADD TO LIST(******ALWAYS******)

Pictur_70:
L5EC5:  CPX  #$1F
L5EC7:  BCC  Pictur_80              ;NOT KILLER MINE
L5EC9:  LDA  OBJ,X                  ;WHICH PIC?
L5ECB:  AND  #$40
L5ECD:  BNE  Pictur_71
L5ECF:  LDA  #$00
L5ED1:  STA  (VGLIST),Y
L5ED3:  INY
L5ED4:  LDA  #$72
L5ED6:  STA  (VGLIST),Y             ;SET SCALE
L5ED8:  INY
L5ED9:  LDA  SAUCIX                 ;GET PIC CODE
L5EDC:  ASL
L5EDD:  TAX
L5EDE:  LDA  $3E46,X                ;ADD THE JSRL TO LIST
L5EE1:  STA  (VGLIST),Y
L5EE3:  INY
L5EE4:  LDA  $3E47,X
L5EE7:  JMP  MsbByte

Pictur_71:
L5EEA:  LDA  #$D2
L5EEC:  CPX  #$1F
L5EEE:  BNE  Pictur_73              ;******ALWAYS********
L5EF0:  LDA  #$D4

Pictur_73:
L5EF2:  LDX  #$64                   ;REST OF COLOR INSTRUCTION
L5EF4:  JSR  LsbByte
L5EF7:  LDA  #$02
L5EF9:  JSR  UseFullSize            ;SET SCALE
L5EFC:  LDA  #$27
L5EFE:  LDX  #$AF
L5F00:  JSR  Add2WordsToVector
L5F03:  LDA  #$68
L5F05:  LDX  #$A1
L5F07:  JMP  Add2WordsToVector

Pictur_74:
L5F0A:  CPX  #$21
L5F0C:  BCC  Pictur_70              ;NOT A SHIP
L5F0E:  JMP  DisplayShipPicture

Pictur_80:
L5F11:  CPX  #$19
L5F13:  BCC  Pictur_90              ;NOT KILLER MINES
L5F15:  LDA  INTEN                  ;PULSE INTENSITY OF KILLERMINE
L5F18:  ORA  OBKLMINES,X
L5F1A:  STA  (VGLIST),Y
L5F1C:  INY
L5F1D:  LDA  #$64                   ;FINISH INSTRUCTION
L5F1F:  STA  (VGLIST),Y
L5F21:  INY
L5F22:  LDA  #$34
L5F24:  LDX  #$AF

Pictur_79:
L5F26:  JMP  LsbByte

Pictur_90:
L5F29:  LDA  $037E,X
L5F2C:  BMI  Pictur_95              ;GROWN UP
L5F2E:  LDA  #$E1
L5F30:  LDX  #$AE
L5F32:  BNE  Pictur_79              ;ALWAYS

Pictur_95:
L5F34:  LDY  #$00
L5F36:  LDA  FLASHCOL
L5F39:  STA  (VGLIST),Y
L5F3B:  LDA  #$64
L5F3D:  INY
L5F3E:  STA  (VGLIST),Y
L5F40:  INY
L5F41:  LDA  #$B6
L5F43:  LDX  #$AE
L5F45:  BNE  Pictur_79              ;ALWAYS

Pictur_110:
L5F47:  .byte $72, $71, $70, $70

WhiteSaucers:
L5F4B:  .byte $67, $67, $67, $67, $64, $64, $64, $64
L5F53:  .byte $62, $62, $62, $62

Cubltr:
L5F57:  .byte $16, $1D, $1A, $0B, $0D, $0F, $0E, $1F
L5F5F:  .byte $0F, $16, $1D, $1A, $0B, $0D, $0F, $0E
L5F67:  .byte $1F

AddPointsToScore:
L5F68:  BIT  ATRACT                 ;NO SCORE IN ATTRACT
L5F6A:  BMI  AddPointsToScore_5

AddPointsToScore_1:
L5F6C:  RTS

AddPointsToScore_5:
L5F6D:  LDX  OWNER
L5F70:  BMI  AddPointsToScore_1
L5F72:  SED
L5F73:  CLC
L5F74:  ADC  DIFCTY
L5F76:  SEC
L5F77:  SBC  #$01                   ;BONUS DISPLAY=DIFCTY LEVEL -1
L5F79:  STA  TEMPA                  ;FOR COMBINED SCORE
L5F7B:  DEC  PL0SCFLAG,X            ;SIGNIFY TO INTERRUPT ROUTINE THIS SCORE HAS BEEN CHANGED
L5F7E:  CPX  #$00
L5F80:  BEQ  AddPointsToScore_10
L5F82:  LDX  #$03                   ;MULTIPLY X BY NUMBER OF BYTES IN SCORE

AddPointsToScore_10:
L5F84:  CLC                         ;MAY NOT BE NEEDED
L5F85:  ADC  SCORE,X
L5F87:  STA  SCORE,X
L5F89:  BCC  AddPointsToScore_60    ;NO EXTRA 1000
L5F8B:  LDA  #$00
L5F8D:  ADC  $3B,X                  ;CANNOT INCREMENT WHILE IN DECIMAL
L5F8F:  STA  $3B,X
L5F91:  STA  TEMP9                  ;SAVE FOR HIGH SCORE COMPARE
L5F93:  LDA  #$00
L5F95:  ADC  $3C,X
L5F97:  STA  $3C,X
L5F99:  BIT  TOGCOMB
L5F9B:  BMI  AddPointsToScore_65    ;WAS COMBINED
L5F9D:  LDA  BONLVA                 ;BONUS ALLOWED
L5F9F:  BEQ  AddPointsToScore_90    ;NO
L5FA1:  LDX  OWNER
L5FA4:  LDA  NXTBON,X
L5FA6:  CMP  TEMP9                  ;CANNOT PASS ON ONE HIT
L5FA8:  BNE  AddPointsToScore_90    ;NOT ACHIEVED
L5FAA:  CLC
L5FAB:  ADC  BONLVA                 ;STEP TO NEXT BONUS LEVEL
L5FAD:  STA  NXTBON,X
L5FAF:  LDA  #$BF
L5FB1:  STA  PL0SCFLAG,X
L5FB4:  LDA  HITS,X
L5FB6:  CMP  #$0A                   ;LIMIT LIVES
L5FB8:  BCS  AddPointsToScore_80    ;ONE MORE LIFE
L5FBA:  INC  HITS,X                 ;ONE MORE LIFE
L5FBC:  BNE  AddPointsToScore_80    ;ALWAYS

AddPointsToScore_60:
L5FBE:  BIT  TOGCOMB
L5FC0:  BPL  AddPointsToScore_90    ;NOT COMBINED SCORES

AddPointsToScore_65:
L5FC2:  DEC  CMBSCFLAG              ;SIGNIFY TO INTERRUPT ROUTINE THAT THIS SCORE WAS CHANGED
L5FC5:  LDA  TEMPA
L5FC7:  CLC
L5FC8:  ADC  CMBSCORE
L5FCA:  STA  CMBSCORE
L5FCC:  BCC  AddPointsToScore_90
L5FCE:  LDA  #$00
L5FD0:  ADC  $41
L5FD2:  STA  $41
L5FD4:  LDA  #$00
L5FD6:  ADC  $42
L5FD8:  STA  $42
L5FDA:  LDA  BONLVA
L5FDC:  BEQ  AddPointsToScore_90    ;NO BONUS ALLOWED
L5FDE:  LDA  NXTBON                 ;WILL USE PLAYER 0'S FOR COMBINED
L5FE0:  CMP  $41                    ;ACHIEVED
L5FE2:  BNE  AddPointsToScore_90    ;NO
L5FE4:  CLC
L5FE5:  ADC  BONLVA                 ;STEP TO NEXT LEVEL
L5FE7:  STA  NXTBON
L5FE9:  LDA  HITS
L5FEB:  CMP  #$0A
L5FED:  BCS  AddPointsToScore_75
L5FEF:  INC  HITS                   ;GIVE NEW LIVES
L5FF1:  INC  $48

AddPointsToScore_75:
L5FF3:  LDA  #$BF
L5FF5:  STA  CMBSCFLAG              ;CHANGE LIVES AND SCORE

AddPointsToScore_80:
L5FF8:  CLD
L5FF9:  JMP  ExtraLife2             ;EXTRA LIFE SOUND

AddPointsToScore_90:
L5FFC:  CLD

AddPointsToScore_95:
L5FFD:  RTS

PositionsTables:
L5FFE:  .byte $88, $10

MessagePositions:
L6000:  .byte $98, $22

CcCarrySetDisplaying:
L6002:  CLC
L6003:  RTS                         ;NOT DOING ANYTHING HERE

Scores:
L6004:  LDA  #$FF
L6006:  STA  TEMP9                  ;NO NEED TO STAT GREEN YET
L6008:  LDA  #$01                   ;SHOW 2 TABLES
L600A:  STA  TEMP6

Scores_13:
L600C:  LDA  LASTG
L600F:  AND  #$02                   ;0 OR 2
L6011:  LDX  SHHIGH
L6014:  BNE  Scores_17              ;SHOW HIGH SCORE EVEN IF CREDITS

Scores_12:
L6016:  LDA  $45
L6018:  AND  #$04
L601A:  BEQ  CcCarrySetDisplaying
L601C:  LDA  $45
L601E:  LSR                         ;SHOW BOTH TABLES

Scores_15:
L601F:  AND  #$01
L6021:  ASL                         ;0 OR 2

Scores_17:
L6022:  CLC                         ;IN CASE YOUR FROM ABOVE
L6023:  ADC  TEMP6                  ;0,1,2, OR 3

Scores_16:
L6025:  TAX
L6026:  LDA  FifthValueUpdateCheck,X
L6029:  STA  $0E                    ;INDEX FOR SCORES
L602B:  STA  SKCTL                  ;INDEX FOR INITIALS
L602D:  LDA  #$01
L602F:  STA  TEMP3                  ;PLACE INDICATOR
L6031:  STX  TEMP5
L6033:  LDA  #$DC
L6035:  LDX  #$3C
L6037:  JSR  Mesgpos
L603A:  LDX  #$05
L603C:  JSR  AuxRoutineAddOffset
L603F:  LDX  #$C2
L6041:  LDY  #$00
L6043:  JSR  Brightness             ;DISPLAY "HIGH SCORE" MESSAGE
L6046:  LDA  #$DD
L6048:  LDX  #$F0
L604A:  JSR  UpdownVectorUpsideDown
L604D:  LDX  #$06                   ;USE OFFSET 6
L604F:  JSR  AuxRoutineAddOffset    ;TO MOVE SHIP PICS
L6052:  LDA  TEMP5
L6054:  AND  #$02
L6056:  TAY
L6057:  BIT  CABERE
L605A:  BVC  L605D
L605C:  INY
L605D:  LDX  $764E,Y                ;GET PICTURE ROM ADDRESS
L6060:  LDA  $7652,Y
L6063:  JSR  Add2WordsToVector
L6066:  BIT  CABERE
L6069:  BVS  Scores_19              ;NO PLAYER MESSAGE NEEDED
L606B:  LDX  TEMP6                  ;1,2 PLYR POSITION
L606D:  LDA  MessagePositions,X
L6070:  LDX  #$1C
L6072:  JSR  Mesgpos
L6075:  LDX  TEMP5
L6077:  LDY  Scores_110,X           ;ONE OR A TWO PLAYER
L607A:  STY  UPDOWN                 ;ALWAYS NORMAL
L607D:  JSR  VectorMessage5

Scores_19:
L6080:  LDA  #$00
L6082:  STA  FOURPI                 ;STARTING Y FOR EACH LINE

Scores_20:
L6084:  LDX  $0E
L6086:  .byte $BD, $DD, $00    ;LDA HSCORE,X (forced absolute)
L6089:  .byte $1D, $DE, $00    ;ORA $00DE,X (forced absolute)
L608C:  .byte $1D, $DF, $00    ;ORA $00DF,X (forced absolute)
L608F:  BNE  Scores_21
L6091:  JMP  Scores_80

Scores_21:
L6094:  JSR  CenterBeamInMiddle
L6097:  LDX  TEMP6                  ;START POSITION
L6099:  LDA  PositionsTables,X
L609C:  BIT  CABERE
L609F:  BVC  L60A3
L60A1:  LDA  #$DA
L60A3:  LDX  FOURPI
L60A5:  JSR  UpdownVectorUpsideDown ;POSITION FOR START OF LINE
L60A8:  LDA  SKCTL                  ;INITIAL INDEX
L60AA:  CMP  FLSFLG                 ;LAST ENETRED?
L60AD:  BEQ  Scores_23
L60AF:  CMP  $03EC                  ;OTHER POSSIBILITY
L60B2:  BEQ  Scores_23
L60B4:  BIT  TEMP9                  ;D ALREADY SET BACK TO GREEN?
L60B6:  BMI  Scores_24
L60B8:  LDY  #$C2                   ;C SET COLOR BACK TO YELLOW
L60BA:  BIT  CABERE
L60BD:  BVC  L60C1
L60BF:  LDY  #$C4
L60C1:  STY  TEMP9                  ;SET ALREADY GREEN FLAG
L60C3:  JSR  SetVectorGeneratorStatus
L60C6:  JMP  Scores_24

Scores_23:
L60C9:  LDA  FLASHCOL               ;A GOOD SLOW FLASH COLOR
L60CC:  TAY
L60CD:  JSR  SetVectorGeneratorStatus
L60D0:  LDA  #$00
L60D2:  STA  TEMP9                  ;SET 'NEED GREEN' FLAG

Scores_24:
L60D4:  LDA  TEMP5                  ;WHICH GAME?
L60D6:  CMP  #$02
L60D8:  BNE  Scores_22              ;IF NOT GAME 2, SKIP IT
L60DA:  LDY  #$00
L60DC:  STY  SPFLG                  ;SET SPECIAL FLAG FOR 'INITA3'
L60DF:  JSR  Inita3                 ;1ST INITIAL
L60E2:  JSR  Inita3                 ;2ND INITIAL
L60E5:  JSR  Inita3                 ;3RD INITIAL
L60E8:  LDA  #$FF
L60EA:  STA  SPFLG                  ;RESTORE FLAG TO NORMAL
L60ED:  LDY  #$00
L60EF:  JSR  EntryIndexCharacter0   ;ADD A SPACE
L60F2:  DEC  SKCTL
L60F4:  DEC  SKCTL                  ;CORRECT FOR OTHER SET OF INITIALS
L60F6:  DEC  SKCTL

Scores_22:
L60F8:  LDY  $0E
L60FA:  LDX  #$FD                   ;USE ZERO PAGE WRAP AROUND

Scores_30:
L60FC:  LDA  HSCORE,Y
L60FF:  STA  TWOPI,X
L6101:  INY
L6102:  INX
L6103:  BMI  Scores_30
L6105:  LDA  #$03                   ;ADDRESS OF SCORE
L6107:  SEC
L6108:  LDY  #$03
L610A:  JSR  SaveInpuParameers      ;DISPLAY SCORE
L610D:  LDA  #$00
L610F:  JSR  DisplayDigit           ;ADD A ZERO TO SCORE
L6112:  LDY  #$00
L6114:  JSR  EntryIndexCharacter0   ;ADD A BLANK AFTER SCORE
L6117:  JSR  Inita3                 ;FIRST INITIAL
L611A:  JSR  Inita3                 ;SECOND INITIAL
L611D:  JSR  Inita3                 ;THIRD INITIAL
L6120:  LDA  FOURPI
L6122:  SEC
L6123:  SBC  #$08
L6125:  STA  FOURPI                 ;STARTING Y FOR NEXT LINE
L6127:  INC  $0E
L6129:  INC  $0E
L612B:  INC  $0E
L612D:  LDA  TEMP3
L612F:  CLC
L6130:  SED
L6131:  ADC  #$01
L6133:  CLD
L6134:  STA  TEMP3
L6136:  CMP  #$06
L6138:  BCS  Scores_80
L613A:  JMP  Scores_20

Scores_80:
L613D:  BIT  CABERE
L6140:  BVC  L6149
L6142:  DEC  TEMP6
L6144:  DEC  TEMP6
L6146:  JMP  L614B
L6149:  DEC  TEMP6
L614B:  BMI  Scores_81
L614D:  JMP  Scores_13

Scores_81:
L6150:  SEC
L6151:  RTS

Scores_110:
L6152:  .byte $0C, $0B, $0C, $0B

FifthValueUpdateCheck:
L6156:  .byte $00, $0F, $1E, $2D, $3C

Hscend:
L615B:  .byte $0C, $1B, $2A, $39

SearchForFreeRock:
L615F:  LDX  #$10

Searc1:
L6161:  LDA  OBJ,X
L6163:  BEQ  Searc1_20              ;FOUND ONE
L6165:  DEX
L6166:  BPL  Searc1                 ;LOOP TIL EXHAUSTED

Searc1_20:
L6168:  RTS

ShipExplodingPictures:
L6169:  LDA  GAME                   ;FIGHTERS????
L616B:  BEQ  ShipExplodingPictures_2
L616D:  CMP  #$01
L616F:  BEQ  ShipExplodingPictures_5 ;THIS GAME ALWAYS PIECES
L6171:  BNE  ShipExplodingPictures_1 ;NOT FIGHTERS

ShipExplodingPictures_2:
L6173:  LDA  $039A,X
L6176:  BPL  ShipExplodingPictures_5 ;KILLED BY ROCK ON OTHER NON SHIP

ShipExplodingPictures_1:
L6178:  LDA  $03CE,X                ;DO WE WANT ONLY PIECES??
L617B:  BPL  ShipExplodingPictures_5
L617D:  LDA  FRAME                  ;GET FLASH RATE
L617F:  AND  #$04
L6181:  BEQ  ShipExplodingPictures_3 ;NOTHING SHOWN
L6183:  JSR  DisplayShipPicture

ShipExplodingPictures_3:
L6186:  LDA  GAME                   ;SPACE STATION??
L6188:  BNE  ShipExplodingPictures_5 ;IF YES, SHO PIECE FLOATING AWAY
L618A:  RTS                         ;ELSE JUST FLASH!

ShipExplodingPictures_5:
L618B:  LDA  #$01                   ;FULL SCALE
L618D:  JSR  UseFullSize
L6190:  LDX  TEMP3
L6192:  LDA  #$F4
L6194:  CPX  #$21
L6196:  BEQ  ShipExplodingPictures_6
L6198:  LDA  #$F2

ShipExplodingPictures_6:
L619A:  LDX  #$64
L619C:  JSR  Add2WordsToVector
L619F:  LDX  TEMP3
L61A1:  LDA  OBJ,X
L61A3:  CMP  #$A2
L61A5:  BCS  ShipExplodingPictures_20 ;IF NOT THE FIRST EXPLOSION
L61A7:  JSR  Expset                 ;INIT PIECES

ShipExplodingPictures_20:
L61AA:  LDX  TEMP3                  ;STILL VALID FROM PICTUR
L61AC:  LDA  OBJ,X
L61AE:  EOR  #$FF
L61B0:  AND  #$70
L61B2:  LSR
L61B3:  LSR
L61B4:  LSR
L61B5:  AND  #$FE                   ;MAKE EVEN
L61B7:  STA  TEMP4                  ;2*NUMBER OF PIECES-2 (0 TO A)
L61B9:  LDA  $6236,X
L61BC:  STA  TEMP1
L61BE:  LDA  #$27
L61C0:  STA  EACE
L61C2:  LDA  #$00
L61C4:  STA  NMROCK

ShipExplodingPictures_25:
L61C6:  LDA  VGLIST
L61C8:  STA  TEMP2
L61CA:  LDA  EAC2
L61CC:  STA  POTGO
L61CE:  LDX  NMROCK
L61D0:  LDY  #$00
L61D2:  LDA  ChangeDirection,X      ;Y DIRECTION
L61D5:  LDX  #$00
L61D7:  ASL
L61D8:  BCC  ShipExplodingPictures_40
L61DA:  DEX                         ;SIGN EXTENSION

ShipExplodingPictures_40:
L61DB:  ROR
L61DC:  CLC
L61DD:  ADC  (TEMP1),Y
L61DF:  STA  (TEMP1),Y              ;STORE BACK Y LOWER
L61E1:  INY
L61E2:  TXA
L61E3:  ADC  (TEMP1),Y
L61E5:  STA  (TEMP1),Y              ;STORE BACK Y UPPER
L61E7:  DEY
L61E8:  STA  (VGLIST),Y             ;STORE UPPER BYTE OF POSITION IN LOW BYTE OF VECTOR RAM
L61EA:  INY
L61EB:  TXA
L61EC:  AND  #$1F
L61EE:  STA  (VGLIST),Y             ;UPPER Y OF LONG VECTOR
L61F0:  INY
L61F1:  LDX  NMROCK
L61F3:  LDA  $6CB6,X                ;X DIRECTION
L61F6:  LDX  #$00
L61F8:  ASL
L61F9:  BCC  ShipExplodingPictures_50
L61FB:  DEX                         ;SIGN EXTENSION

ShipExplodingPictures_50:
L61FC:  ROR
L61FD:  CLC
L61FE:  ADC  (TEMP1),Y
L6200:  STA  (TEMP1),Y
L6202:  INY
L6203:  TXA
L6204:  ADC  (TEMP1),Y
L6206:  STA  (TEMP1),Y
L6208:  DEY
L6209:  STA  (VGLIST),Y
L620B:  INY
L620C:  TXA
L620D:  AND  #$1F
L620F:  STA  (VGLIST),Y
L6211:  JSR  AddY1ToVector
L6214:  LDA  NMROCK
L6216:  ASL                         ;A HOLDS 4*NUMBER OF PIECES
L6217:  TAX
L6218:  LDY  #$FF

ShipExplodingPictures_60:
L621A:  INY
L621B:  LDA  $3668,X
L621E:  STA  (VGLIST),Y
L6220:  INX
L6221:  CPY  #$03
L6223:  BCC  ShipExplodingPictures_60
L6225:  JSR  AddY1ToVector
L6228:  JSR  NegateALongVector
L622B:  LDA  TEMP1
L622D:  CLC
L622E:  ADC  #$04
L6230:  STA  TEMP1                  ;NEXT EXPLOSION PIECE
L6232:  LDA  NMROCK
L6234:  CLC
L6235:  ADC  #$02
L6237:  STA  NMROCK
L6239:  CMP  TEMP4
L623B:  BCC  ShipExplodingPictures_25
L623D:  RTS

Expset:
L623E:  LDY  $6236,X
L6241:  LDX  #$00

Expset_10:
L6243:  LDA  ChangeDirection,X      ;INITIALIZE POSITIONS OF PIECES
L6246:  STA  SH0XPCOORD,Y           ;LOWER BYTE
L6249:  INY
L624A:  LDA  HoldsSign2Byte,X
L624D:  STA  SH0XPCOORD,Y           ;UPPER BYTE
L6250:  INY
L6251:  INX
L6252:  CPX  #$0C
L6254:  BCC  Expset_10
L6256:  RTS

Shpcor:
L6257:  .byte $00, $18

DisplayShipPicture:
L6259:  LDY  #$00                   ;PREPARE FOR VGLIST
L625B:  LDA  $2E,X
L625D:  AND  #$80
L625F:  BEQ  DisplayShipPicture_40  ;0 IS IN ACC ON BRANCH
L6261:  LDA  $0252,X
L6264:  AND  #$F0
L6266:  ORA  #$07                   ;SIELSD IN WHITE

DisplayShipPicture_40:
L6268:  STA  (VGLIST),Y             ;INTENSITY REGISTER
L626A:  INY
L626B:  LDA  #$64                   ;REST OF STAT INSTRUCTION
L626D:  STA  (VGLIST),Y
L626F:  INY
L6270:  LDA  #$50
L6272:  LDX  #$AF
L6274:  JSR  LsbByte
L6277:  LDX  TEMP3
L6279:  LDA  FRAME                  ;BRING IN PLAYER COLOR 1/4
L627B:  AND  #$04
L627D:  BNE  DisplayShipPicture_45
L627F:  LDA  $03C6,X
L6282:  BEQ  DisplayShipPicture_45
L6284:  EOR  #$F0
L6286:  AND  #$F0
L6288:  ORA  #$07                   ;WHITE
L628A:  BNE  DisplayShipPicture_50

DisplayShipPicture_45:
L628C:  LDA  #$D4                   ;SKIP COLOR
L628E:  CPX  #$21
L6290:  BEQ  DisplayShipPicture_50
L6292:  LDA  #$D2

DisplayShipPicture_50:
L6294:  LDX  #$64                   ;REST OF STAT
L6296:  JSR  Add2WordsToVector
L6299:  LDX  TEMP3

DisplayShipPicture_90:
L629B:  LDA  $0282,X
L629E:  CLC                         ;REFLECT Y OFF
L629F:  BPL  DisplayShipPicture_10  ;IF IN SECTORS 0,1
L62A1:  LDA  #$00
L62A3:  SEC
L62A4:  SBC  $0282,X                ;256.-ANGLE=NEW ANGLE
L62A7:  SEC                         ;REFLECT Y OFF

DisplayShipPicture_10:
L62A8:  STA  TEMPA                  ;0 TO 80
L62AA:  ROR  $12                    ;REFLECT NOW (Y--------)
L62AC:  CLC                         ;REFLECT X OFF
L62AD:  BIT  TEMPA
L62AF:  BMI  DisplayShipPicture_15  ;IF ANGLE=80
L62B1:  BVC  DisplayShipPicture_20  ;IF IN SECTORS 1 OR 4

DisplayShipPicture_15:
L62B3:  LDA  #$80
L62B5:  SEC
L62B6:  SBC  TEMPA                  ;128.-ANGLE=NEW ANGLE
L62B8:  SEC                         ;REFLECT ON

DisplayShipPicture_20:
L62B9:  ROR  $12                    ;REFLECT NOW (XY-------)
L62BB:  AND  #$FC                   ;ROTATION/2=PICTURE NUMBER*2
L62BD:  LSR
L62BE:  CLC                         ;MAX OF 32.
L62BF:  ADC  $63D3,X                ;OFFSET INTO TABLE OF ADDRESSES FOR SHIPS
L62C2:  TAY
L62C3:  JSR  Shpdisplays

Drawrod:
L62C6:  BIT  TOGCOMB
L62C8:  BMI  Drawrod_10             ;RIGID PAIR

Drawrod_5:
L62CA:  RTS                         ;(EXIT POINT)

Drawrod_10:
L62CB:  LDA  RODSTATUS
L62CE:  BMI  Drawrod_5              ;ALREADY DREW A ROD

Drawrod_12:
L62D0:  LDA  #$F6                   ;YELLOW ROD
L62D2:  LDX  #$64
L62D4:  JSR  Add2WordsToVector
L62D7:  LDX  TEMP3
L62D9:  LDA  OBJ,X                  ;STATUS
L62DB:  BMI  Drawrod_5              ;SKIP IF EXPLODING
L62DD:  DEC  RODSTATUS              ;WILL HAVE DRAWN THE ROD
L62E0:  LDA  SPARKTIME
L62E3:  BMI  Drawrod_20             ;NOBODY DIED YET
L62E5:  JSR  RandomFuzz             ;CRACKLE
L62E8:  DEC  SPARKTIME
L62EB:  BNE  Drawrod_20             ;NOT DEAD YET
L62ED:  JSR  StopFuseSound          ;STOP FUSE
L62F0:  LDA  #$A0
L62F2:  STA  OBJ,X
L62F4:  JSR  Explosion              ;EXPLOSION SOUND
L62F7:  LDA  #$20
L62F9:  STA  $024C,X
L62FC:  STA  $03CE,X                ;PIECES ONLY
L62FF:  JMP  GetCometToGo           ;(EXIT)

Drawrod_20:
L6302:  LDA  $0343
L6305:  SEC
L6306:  SBC  OBJXL,X
L6309:  STA  XCOMP
L630B:  LDA  $02D8
L630E:  SBC  OBJXH,X
L6311:  CMP  #$10
L6313:  BMI  Drawrod_30
L6315:  SBC  #$20                   ;CARRY WAS SET

Drawrod_30:
L6317:  CMP  #$F0
L6319:  BPL  Drawrod_40
L631B:  ADC  #$20                   ;CARRY WAS CLEAR

Drawrod_40:
L631D:  LSR
L631E:  STA  RED
L6320:  ROR  XCOMP
L6322:  LDA  $0375
L6325:  SEC
L6326:  SBC  OBJYL,X
L6329:  STA  CHAN3V
L632B:  LDA  $030A
L632E:  SBC  OBJYH,X
L6331:  CMP  #$0C
L6333:  BMI  Drawrod_50
L6335:  SBC  #$18

Drawrod_50:
L6337:  CMP  #$F4
L6339:  BPL  Drawrod_60
L633B:  ADC  #$18

Drawrod_60:
L633D:  LSR
L633E:  STA  TWOPI
L6340:  ROR  CHAN3V
L6342:  LDY  #$AF
L6344:  STY  VGBRIT
L6346:  LDA  SPARKTIME
L6349:  BPL  Drawrod_70             ;ROD SHRINKING
L634B:  LDX  #$03
L634D:  JMP  AddVectorToVector      ;(EXIT)

Drawrod_70:
L6350:  ASL
L6351:  STA  TEMP1                  ;PREPARE FOR MULTIPLY
L6353:  LDX  #$02                   ;START WITH Y COMPONET

Drawrod_75:
L6355:  STX  NMROCK
L6357:  LDA  XCOMP,X
L6359:  LSR  RED,X
L635B:  ROR
L635C:  JSR  OutputTemp2Temp21
L635F:  LDA  #$00
L6361:  LDX  NMROCK
L6363:  STA  RED,X
L6365:  LDA  POTGO
L6367:  ASL
L6368:  BCC  Drawrod_77
L636A:  DEC  RED,X

Drawrod_77:
L636C:  LDA  POTGO
L636E:  ASL
L636F:  ROL  RED,X
L6371:  STA  XCOMP,X
L6373:  DEX
L6374:  DEX
L6375:  BPL  Drawrod_75
L6377:  LDX  #$03
L6379:  JSR  AddVectorToVector

WhiteSparkles:
L637C:  LDA  #$F7                   ;WHITE SPARKLES
L637E:  LDX  #$64
L6380:  JSR  Add2WordsToVector
L6383:  LDA  #$01                   ;MAKE FUSE SPARKS LARGE
L6385:  JSR  UseFullSize
L6388:  LDA  #$68
L638A:  LDX  #$A1
L638C:  JMP  Add2WordsToVector

Spark2:
L638F:  LDA  HALT
L6392:  AND  #$10                   ;IF IN SELF TEST, DONT RUN THIS
L6394:  BEQ  Spark2_90
L6396:  LDA  FRAME
L6398:  LSR
L6399:  BCC  Spark2_90              ;EVERY OTHER FRAME
L639B:  LDA  #$D0
L639D:  STA  VGLIST
L639F:  LDA  #$22
L63A1:  STA  EAC2

Spark2_5:
L63A3:  LDY  #$03                   ;NUMBER OF SPARK SPOKES
L63A5:  STY  FOURPI

Spark2_10:
L63A7:  LDY  FOURPI
L63A9:  LDA  FRAME
L63AB:  LSR                         ;CORRECT FOR EVERY OTHER FRAME
L63AC:  CLC
L63AD:  ADC  Spark2_110,Y           ;GROUP OFFSET, SO SPARKLETS START AT DIFFERENT TIMES
L63B0:  AND  #$0F
L63B2:  STA  TEMP1
L63B4:  BNE  Spark2_50
L63B6:  LDA  $100A
L63B9:  STA  SPARKANGLE,Y

Spark2_50:
L63BC:  LDA  SPARKANGLE,Y
L63BF:  JSR  PiAngle0
L63C2:  JSR  OutputTemp2Temp21
L63C5:  STA  TEMP6                  ;X RESULT
L63C7:  LDY  FOURPI
L63C9:  LDA  SPARKANGLE,Y
L63CC:  JSR  CosSinPi2
L63CF:  JSR  OutputTemp2Temp21
L63D2:  STA  TEMP5                  ;Y RESULT
L63D4:  LDX  TEMP6
L63D6:  LDY  #$20                   ;BRIGHTNESS
L63D8:  JSR  ShortFormVgvctrCall
L63DB:  LDA  #$00
L63DD:  SEC
L63DE:  SBC  TEMP6
L63E0:  TAX
L63E1:  LDA  #$00
L63E3:  SEC
L63E4:  SBC  TEMP5
L63E6:  LDY  #$20
L63E8:  JSR  ShortFormVgvctrCall
L63EB:  DEC  FOURPI
L63ED:  BPL  Spark2_10

Spark2_90:
L63EF:  RTS

Spark2_110:
L63F0:  .byte $00, $08, $10, $18

ShipAddressOffsets:
L63F4:  .byte $00, $22

WhereFirstByteBlank:
L63F6:  .byte $5B, $53

CountWholeShipVectors:
L63F8:  .byte $16, $14

CountShipWithThrust:
L63FA:  .byte $1A, $18

Shpd4table:
L63FC:  .byte $07, $06

Shpdisplays:
L63FE:  STX  TEMP3                  ;SAVE X
L6400:  LDA  CKUM4,Y
L6403:  STA  TEMP2
L6405:  LDA  ROCKA,Y
L6408:  STA  POTGO
L640A:  LDY  $63D7,X                ;SET UP FOR COLOR THRUST
L640D:  STY  TEMPA
L640F:  LDY  $63D5,X
L6412:  STY  TEMPB

Shpdisplays_20:
L6414:  LDY  $63D7,X
L6417:  STY  TEMPA                  ;SAVE FOR COLOR THRUST LATER

Shpdisplays_40:
L6419:  BIT  ATRACT
L641B:  BPL  Fall                   ;NO PICTURE OF THRUST DURING ATTRACT
L641D:  LDA  $08E3,X
L6420:  BPL  Fall                   ;THATS ALL, NO THRUST PICTUR
L6422:  LDA  OBJ,X
L6424:  BMI  Fall                   ;NO THRUST IN SUSPENDED ANIMATION
L6426:  LDA  FRAME
L6428:  AND  #$04
L642A:  BEQ  Fall
L642C:  CPX  #$22
L642E:  BNE  Shpdisplays_50         ;MUST BE REGULAR SHIP
L6430:  BIT  TOGDRONE
L6432:  BMI  Fall                   ;WAS DRONE

Shpdisplays_50:
L6434:  LDY  $63D9,X

Fall:
L6437:  STY  TEMP1
L6439:  LDY  #$FF
L643B:  BIT  $12
L643D:  BMI  Fall_5                 ;X REFLECT ON
L643F:  JMP  Shpdi5                 ;NO X REFLECT

Fall_5:
L6442:  BVS  BothReflects88Cycle    ;Y REFLECT ON

Fall_10:
L6444:  INY
L6445:  LDX  #$00
L6447:  LDA  (TEMP2,X)
L6449:  STA  (VGLIST),Y
L644B:  ASL                         ;SIGN INTO CARRY
L644C:  LDA  #$1F                   ;NEGATIVE UPPER BYTE
L644E:  BCS  Fall_30
L6450:  LDA  #$00

Fall_30:
L6452:  INY
L6453:  STA  (VGLIST),Y
L6455:  INY
L6456:  INC  TEMP2
L6458:  LDA  #$00
L645A:  SEC
L645B:  SBC  (TEMP2,X)
L645D:  STA  (VGLIST),Y
L645F:  ASL                         ;SIGN INTO CARRY
L6460:  LDA  #$3F
L6462:  BCS  Fall_70
L6464:  LDA  #$20

Fall_70:
L6466:  INY
L6467:  STA  (VGLIST),Y
L6469:  INC  TEMP2
L646B:  JSR  RoutineAlsoDoesBlanking ;COLOR THRUST CHECK
L646E:  DEC  TEMP1
L6470:  BPL  Fall_10
L6472:  BMI  ThenPartiallyDamagedOtherwise ;******ALWAYS**********

BothReflects88Cycle:
L6474:  INY
L6475:  LDA  #$00
L6477:  TAX
L6478:  SEC
L6479:  SBC  (TEMP2,X)
L647B:  STA  (VGLIST),Y
L647D:  ASL                         ;SIGN INTO CARRY
L647E:  LDA  #$1F
L6480:  BCS  BothReflects88Cycle_30
L6482:  LDA  #$00

BothReflects88Cycle_30:
L6484:  INY
L6485:  STA  (VGLIST),Y
L6487:  INY
L6488:  INC  TEMP2
L648A:  LDA  #$00
L648C:  SEC
L648D:  SBC  (TEMP2,X)
L648F:  STA  (VGLIST),Y
L6491:  ASL                         ;SIGN INTO CARRY
L6492:  LDA  #$3F
L6494:  BCS  BothReflects88Cycle_70
L6496:  LDA  #$20

BothReflects88Cycle_70:
L6498:  INY
L6499:  STA  (VGLIST),Y
L649B:  INC  TEMP2
L649D:  JSR  RoutineAlsoDoesBlanking ;COLOR THRUST CHECK
L64A0:  DEC  TEMP1
L64A2:  BPL  BothReflects88Cycle

ThenPartiallyDamagedOtherwise:
L64A4:  CPY  #$1E
L64A6:  BCC  ThenPartiallyDamagedOtherwise_60
L64A8:  LDA  (VGLIST),Y
L64AA:  AND  #$1F
L64AC:  STA  (VGLIST),Y
L64AE:  STY  TEMP2
L64B0:  LDY  TEMPB
L64B2:  LDA  (VGLIST),Y
L64B4:  AND  #$1F
L64B6:  STA  (VGLIST),Y
L64B8:  INY
L64B9:  INY
L64BA:  INY
L64BB:  INY
L64BC:  LDA  (VGLIST),Y
L64BE:  AND  #$1F
L64C0:  STA  (VGLIST),Y

ThenPartiallyDamagedOtherwise_60:
L64C2:  LDY  #$03
L64C4:  LDA  (VGLIST),Y
L64C6:  AND  #$1F
L64C8:  STA  (VGLIST),Y
L64CA:  LDY  TEMP2
L64CC:  JMP  AddY1ToVector          ;EXIT

Shpdi5:
L64CF:  BVC  NoReflects76Cycle

Shpdi5_10:
L64D1:  INY
L64D2:  LDA  #$00
L64D4:  TAX
L64D5:  SEC
L64D6:  SBC  (TEMP2,X)
L64D8:  STA  (VGLIST),Y
L64DA:  ASL                         ;SIGN INTO CARRY
L64DB:  LDA  #$1F
L64DD:  BCS  Shpdi5_30
L64DF:  LDA  #$00

Shpdi5_30:
L64E1:  INY
L64E2:  STA  (VGLIST),Y
L64E4:  INC  TEMP2
L64E6:  INY
L64E7:  LDA  (TEMP2,X)
L64E9:  STA  (VGLIST),Y
L64EB:  ASL                         ;SING INTO CARRY
L64EC:  LDA  #$3F
L64EE:  BCS  Shpdi5_70
L64F0:  LDA  #$20

Shpdi5_70:
L64F2:  INY
L64F3:  STA  (VGLIST),Y
L64F5:  INC  TEMP2
L64F7:  JSR  RoutineAlsoDoesBlanking ;COLOR THRUST CHECK
L64FA:  DEC  TEMP1
L64FC:  BPL  Shpdi5_10
L64FE:  JMP  ThenPartiallyDamagedOtherwise

NoReflects76Cycle:
L6501:  INY
L6502:  LDX  #$00
L6504:  LDA  (TEMP2,X)
L6506:  STA  (VGLIST),Y
L6508:  ASL                         ;SIGN INTO CARRY
L6509:  LDA  #$1F
L650B:  BCS  NoReflects76Cycle_30
L650D:  LDA  #$00

NoReflects76Cycle_30:
L650F:  INY
L6510:  STA  (VGLIST),Y
L6512:  INC  TEMP2
L6514:  INY
L6515:  LDA  (TEMP2,X)
L6517:  STA  (VGLIST),Y
L6519:  ASL                         ;SIGN INTO CARRY
L651A:  LDA  #$3F
L651C:  BCS  NoReflects76Cycle_70

NoReflects76Cycle_60:
L651E:  LDA  #$20

NoReflects76Cycle_70:
L6520:  INY
L6521:  STA  (VGLIST),Y
L6523:  INC  TEMP2
L6525:  JSR  RoutineAlsoDoesBlanking ;COLOR THRUST CHECK
L6528:  DEC  TEMP1
L652A:  BPL  NoReflects76Cycle
L652C:  JMP  ThenPartiallyDamagedOtherwise

RoutineAlsoDoesBlanking:
L652F:  LDX  TEMP3
L6531:  DEC  TEMPA                  ;ANOTHER VECTOR
L6533:  LDA  TEMPA
L6535:  CMP  $63DB,X                ;DAMAGE COUNT
L6538:  BNE  RoutineAlsoDoesBlanking_10 ;NOT DAMAGE CHECK SPOT
L653A:  LDA  $0367,X                ;DAMMAGED??
L653D:  BPL  RoutineAlsoDoesBlanking_10 ;NOPE
L653F:  LDA  #$00                   ;YES...SO ADD BLACK STAT INSTRU.
L6541:  BEQ  RoutineAlsoDoesBlanking_15 ;********ALWAYS**********

RoutineAlsoDoesBlanking_10:
L6543:  LDA  TEMPA
L6545:  CMP  #$FE                   ;TIME FOR WHITE THRUST??
L6547:  BNE  AlsoUsedFromBelow
L6549:  LDA  #$F7                   ;WHITE THRUST

RoutineAlsoDoesBlanking_15:
L654B:  INY
L654C:  STA  (VGLIST),Y
L654E:  INY
L654F:  LDA  #$64                   ;REST OF STAT
L6551:  STA  (VGLIST),Y

AlsoUsedFromBelow:
L6553:  RTS                         ;ALSO USED FROM BELOW

SplitRockIntoFragments:
L6554:  LDY  FOURPI
L6556:  CPY  #$21
L6558:  BCS  AlsoUsedFromBelow
L655A:  CPY  #$1F
L655C:  BCC  SplitRockIntoFragments_3
L655E:  TYA
L655F:  TAX
L6560:  JMP  KillXSaucer            ;(EXIT)

SplitRockIntoFragments_3:
L6563:  CPY  #$19
L6565:  BCS  AlsoUsedFromBelow      ;NO ACTION
L6567:  CPY  #$11
L6569:  BCC  SplitRockIntoFragments_5 ;WAS A ROCK
L656B:  JSR  UpTheDifficulty
L656E:  LDY  FOURPI
L6570:  LDA  #$20
L6572:  JSR  AddPointsToScore
L6575:  JMP  SplitRockIntoFragments_90 ;EXPLOSION SOUND (EXIT)

SplitRockIntoFragments_5:
L6578:  STY  TEMP1
L657A:  LDX  OWNER
L657D:  BMI  SplitRockIntoFragments_7 ;NOT DUE TO A SHIP
L657F:  LDA  #$10                   ;2 SECONDS PER ROCK
L6581:  JSR  AmountAddRoutineLimits
L6584:  LDA  RTIMER,X
L6587:  CLC
L6588:  ADC  #$10                   ;INCREASE ROCK TIMER
L658A:  CMP  MXRTIMER,X
L658D:  BCC  SplitRockIntoFragments_6 ;BUT LESS THAN A DECREASNG CEILING
L658F:  LDA  MXRTIMER,X

SplitRockIntoFragments_6:
L6592:  STA  RTIMER,X

SplitRockIntoFragments_7:
L6595:  LDA  OBJ,Y
L6598:  TAX                         ;SAVE A
L6599:  AND  #$38                   ;SAVE PIC CODE
L659B:  STA  TEMP9
L659D:  TXA                         ;RECALL A
L659E:  AND  #$07                   ;OLD SIZE
L65A0:  LSR                         ;NEW SIZE
L65A1:  TAX                         ;SAVE FOR SCORE INDEX
L65A2:  ORA  TEMP9                  ;RESTORE PIC

SplitRockIntoFragments_10:
L65A4:  STA  OBJ,Y                  ;NEW SOLD PICTURE OR ELSE EMPTY SIZE
L65A7:  LDA  SplitRockIntoFragments_110,X
L65AA:  JSR  AddPointsToScore       ;ADD POINTS AND CHECK FOR 10K
L65AD:  LDY  TEMP1

SplitRockIntoFragments_20:
L65AF:  LDA  OBJ,Y
L65B2:  AND  #$07                   ;ONLY WANT SIZE HERE
L65B4:  BEQ  SplitRockIntoFragments_90 ;ROCK DISAPEARRED
L65B6:  BIT  ATSTG                  ;SPECIAL ATTRACT?
L65B8:  BPL  SplitRockIntoFragments_21
L65BA:  LSR                         ;LITTLE ONE?
L65BB:  BEQ  SplitRockIntoFragments_90 ;SKIP IT!
L65BD:  JSR  SearchForFreeRock
L65C0:  BMI  SplitRockIntoFragments_90 ;NO ROOM
L65C2:  JSR  CopyAttributesOfRock   ;COPY IT THERE
L65C5:  LDA  #$A0
L65C7:  STA  OBJ,X                  ;AND EXPLODE IT
L65C9:  INC  NROCKS                 ;ANOTHER "ROCK"
L65CC:  TYA
L65CD:  TAX                         ;WANT TO ADD VELOCITY TO OLD ROCK
L65CE:  LDY  #$00                   ;BASE ON STILL ROCK
L65D0:  JMP  NewRandomVelocityUsing

SplitRockIntoFragments_21:
L65D3:  JSR  SearchForFreeRock      ;SEARCH FOR NEW ENTRY
L65D6:  BMI  SplitRockIntoFragments_93 ;NO MORE ENTRIES
L65D8:  INC  NROCKS
L65DB:  JSR  CopyAttributesOfRock   ;COPY POSITION FOR NEW ENTRY
L65DE:  LDA  XINC,X
L65E1:  AND  #$1F
L65E3:  ASL
L65E4:  EOR  OBJXL,X
L65E7:  STA  OBJXL,X                ;PREVENT OVERLAPING ROCKS
L65EA:  JSR  Searc1                 ;LOOK FOR NEW ENTRY
L65ED:  BMI  SplitRockIntoFragments_90 ;NO MORE ROOM
L65EF:  INC  NROCKS
L65F2:  JSR  CopyAttributesOfRock   ;COPY POSITION & PICTURE + VELOCITY
L65F5:  LDA  YINC,X
L65F8:  AND  #$1F
L65FA:  ASL
L65FB:  EOR  OBJYL,X
L65FE:  STA  OBJYL,X

SplitRockIntoFragments_90:
L6601:  LDA  #$A0
L6603:  STA  OBJ,Y                  ;EXPLODE OLD ROCK
L6606:  JMP  Explosion              ;EXPLOSION SOUND

SplitRockIntoFragments_93:
L6609:  LDA  #$A0
L660B:  STA  OBJ,Y
L660E:  JMP  Popsn

SplitRockIntoFragments_110:
L6611:  .byte $10, $05, $02

UpdateHighScoreTable:
L6614:  LDA  #$FF
L6616:  STA  $45                    ;PUT UP HIGH SCORE TABLE NEXT
L6618:  STA  UPDFLG
L661A:  STA  $39                    ;CLEAR FLAGS
L661C:  STA  SPFLG                  ;GUESS NO SPECIAL
L661F:  LDX  GAME
L6621:  BNE  UpdateHighScoreTable_30

UpdateHighScoreTable_15:
L6623:  LDA  #$01
L6625:  STA  TEMP4
L6627:  LDX  #$03                   ;LEFT PLAYERS SCORE
L6629:  JSR  JmpUpda20

UpdateHighScoreTable_20:
L662C:  LDX  #$00                   ;RIGHT SCORE
L662E:  STX  TEMP4
L6630:  JMP  JmpUpda20

UpdateHighScoreTable_30:
L6633:  DEX
L6634:  BEQ  UpdateHighScoreTable_20 ;GAME 1
L6636:  DEX
L6637:  BNE  UpdateHighScoreTable_35
L6639:  LDA  #$00
L663B:  STA  SPFLG                  ;THIS IS SPECIAL CASE

UpdateHighScoreTable_35:
L663E:  LDX  #$00

UpdateHighScoreTable_40:
L6640:  STX  TEMP4
L6642:  LDX  #$06

JmpUpda20:
L6644:  LDY  GAME
L6646:  LDA  $6157,Y
L6649:  STA  TEMP5                  ;THE END OF HIGH SCORES+1 FOR THIS GME
L664B:  LDA  FifthValueUpdateCheck,Y
L664E:  TAY

UpdateUpdateHighScore:
L664F:  LDA  HSCORE,Y
L6652:  CMP  SCORE,X                ;SETS CARRY
L6654:  LDA  $00DE,Y
L6657:  SBC  $3B,X
L6659:  LDA  $00DF,Y
L665C:  SBC  $3C,X
L665E:  BCC  UpdateUpdateHighScore_30 ;NEW HIGH SCORE

UpdateUpdateHighScore_25:
L6660:  INY
L6661:  INY
L6662:  INY                         ;NEXT ENTRY IN HIGH SCORE TABLE
L6663:  CPY  TEMP5
L6665:  BCC  UpdateUpdateHighScore  ;LOOP TILL PAST END OF THIS TABLE
L6667:  RTS                         ;(EXIT)

UpdateUpdateHighScore_30:
L6668:  STX  TEMP2                  ;SAVE CURRENT SCORE INDEX
L666A:  STY  POTGO                  ;SAVE WHICH HIGH SCORE ENTRY WE ARE ON
L666C:  LDX  TEMP4
L666E:  TYA
L666F:  STA  UPDFLG,X               ;FLAG TO GET PLAYERS INITIALS
L6671:  STA  FLSFLG,X               ;SET LAST ENTERED
L6674:  BIT  SPFLG                  ;SPECIAL INITIALS?
L6677:  BMI  UpdateUpdateHighScore_35
L6679:  STA  $39                    ;WE WILL DO BOTH

UpdateUpdateHighScore_35:
L667B:  LDY  GAME
L667D:  LDX  Hscend,Y
L6680:  TXA
L6681:  TAY

UpdateUpdateHighScore_40:
L6682:  CPX  POTGO
L6684:  BEQ  UpdateUpdateHighScore_45 ;IF END OF COPY
L6686:  LDA  $0116,X                ;COPY INITIALS DOWN
L6689:  STA  INITL,X
L668C:  LDA  $0117,X
L668F:  STA  $011A,X
L6692:  LDA  $0118,X
L6695:  STA  $011B,X
L6698:  LDA  $00DA,Y                ;COPY HIGH SCORES
L669B:  STA  HSCORE,Y
L669E:  LDA  BONLVA,Y
L66A1:  STA  $00DE,Y
L66A4:  LDA  ATSTG,Y
L66A7:  STA  $00DF,Y
L66AA:  BIT  SPFLG                  ;SPECIAL CASE?
L66AD:  BMI  UpdateUpdateHighScore_44 ;NOPE
L66AF:  LDA  $0134,X                ;MOVE INITIALS DOWN
L66B2:  STA  $0137,X
L66B5:  LDA  $0135,X
L66B8:  STA  $0138,X
L66BB:  LDA  $0136,X
L66BE:  STA  $0139,X

UpdateUpdateHighScore_44:
L66C1:  DEY
L66C2:  DEY
L66C3:  DEY
L66C4:  DEX
L66C5:  DEX
L66C6:  DEX
L66C7:  BNE  UpdateUpdateHighScore_40 ;LOOP UNTIL X=0 OR DONE

UpdateUpdateHighScore_45:
L66C9:  LDA  #$0B
L66CB:  STA  INITL,X                ;START LETTERS AT A
L66CE:  LDA  #$00                   ;CLEARS SECOND AND THIRD INITIALS
L66D0:  STA  $011A,X
L66D3:  STA  $011B,X
L66D6:  BIT  SPFLG                  ;DOING SPECIAL?
L66D9:  BMI  UpdateUpdateHighScore_46 ;NOPE
L66DB:  STA  $0138,X
L66DE:  STA  $0139,X
L66E1:  LDA  #$0B
L66E3:  STA  $0137,X                ;INIT INITIALS

UpdateUpdateHighScore_46:
L66E6:  LDA  #$ED                   ;1 MINUTE AT 60HZ
L66E8:  STA  $45                    ;PREPARE TO TIMEOUT GETTING INITIALS
L66EA:  LDX  TEMP2                  ;X POINTS TO START OF CURRENT SCORE
L66EC:  LDY  POTGO                  ;MOVE HIGH SCORE IN
L66EE:  LDA  $3C,X
L66F0:  STA  $00DF,Y
L66F3:  LDA  $3B,X
L66F5:  STA  $00DE,Y
L66F8:  LDA  SCORE,X
L66FA:  STA  HSCORE,Y

UpdateUpdateHighScore_28:
L66FD:  LDX  TEMP4
L66FF:  BNE  UpdateUpdateHighScore_29
L6701:  BIT  SPFLG                  ;SPECIAL CASE?
L6704:  BPL  UpdateUpdateHighScore_29 ;YEP!
L6706:  LDA  $39
L6708:  BMI  UpdateUpdateHighScore_29 ;NO PLAYER 2 HIGH SCORE
L670A:  CMP  UPDFLG
L670C:  BCC  UpdateUpdateHighScore_29 ;IF PLAYER 2 SCORE IS BETTER THAN PLAYER 1
L670E:  ADC  #$02                   ;ADD 3 (ADJUST HIS PLACE IN THE TABLE OF INITIALS)
L6710:  CMP  TEMP5
L6712:  BCC  UpdateUpdateHighScore_27 ;IF NOT OUT OF TABLE NOW
L6714:  LDA  #$FF                   ;PLAYER 2 DID NOT REALLY MAKE THE TABLE

UpdateUpdateHighScore_27:
L6716:  STA  $39
L6718:  STA  $03EC                  ;FORGET IT

UpdateUpdateHighScore_29:
L671B:  LDA  #$00
L671D:  STA  UPDINT                 ;STARTING WITH FIRST INITIAL
L671F:  STA  $37
L6721:  LDA  #$FF
L6723:  STA  HSCFLG                 ;ALLOW SOUND ROUTINE TO MAKE NOISE
L6726:  STA  SPECEX
L6729:  JMP  Bigbang                ;REMOVE ALL OBJECTS

Inexit:
L672C:  RTS

InitiateKillerMine:
L672D:  BIT  ATRACT
L672F:  BPL  Inexit                 ;NOT IN ATRACT
L6731:  LDX  #$05

InitiateKillerMine_20:
L6733:  LDA  OBKLMINES,X
L6735:  BEQ  InitiateKillerMine_25
L6737:  DEX
L6738:  BPL  InitiateKillerMine_20
L673A:  BMI  InitiateKillerMine_90  ;NONE LEFT

InitiateKillerMine_25:
L673C:  LDY  #$21                   ;DEFAULT FOR ALONE GAME
L673E:  LDA  GAME
L6740:  CMP  #$01
L6742:  BEQ  InitiateKillerMine_29
L6744:  TXA
L6745:  LSR
L6746:  BCS  InitiateKillerMine_29
L6748:  INY                         ;EVEN MINES TARGETED ON ZSHIP+1

InitiateKillerMine_29:
L6749:  TYA
L674A:  STA  KTARGET,X
L674D:  STX  TEMP10                 ;SAVE X
L674F:  LDA  DIFF
L6751:  EOR  #$FF
L6753:  AND  #$03                   ;WILL USE AS OFFSET INTO TABLE
L6755:  CLC
L6756:  ADC  TEMP10                 ;ADD MINE OFFSET
L6758:  TAY                         ;Y AS AN INDEX
L6759:  LDA  #$01                   ;START COLOR (BLUE)
L675B:  STA  KLMINC,X
L675D:  LDA  $100A                  ;GIVE RANDOM START POINT
L6760:  STA  $02CE,X
L6763:  LDA  $140A
L6766:  STA  $0300,X
L6769:  LDA  #$00                   ;NOW PUT ON ONE EDGE
L676B:  BIT  FRAME
L676D:  BPL  InitiateKillerMine_31
L676F:  STA  $02CE,X
L6772:  BEQ  InitiateKillerMine_32  ;*******ALWAYS*********

InitiateKillerMine_31:
L6774:  STA  $0300,X

InitiateKillerMine_32:
L6777:  BIT  TOGCOMB                ;COMBINED LIVES??
L6779:  BPL  InitiateKillerMine_30  ;NOPE
L677B:  LDA  SpeedTableSpaceStation,Y ;YES -- GAMES 2 & 3 HERE
L677E:  STA  OBKLMINES,X
L6780:  LDA  AngleChangeSpeedSpace,Y
L6783:  JMP  InitiateKillerMine_35

InitiateKillerMine_30:
L6786:  LDA  GAME
L6788:  BEQ  InitiateKillerMine_50
L678A:  LDA  SpeedTableGame1,Y      ;GAME 1 ONLY HERE
L678D:  STA  OBKLMINES,X
L678F:  LDA  AngleChangeSpeedGame,Y

InitiateKillerMine_35:
L6792:  STA  KANGCH,X

InitiateKillerMine_40:
L6795:  LDA  #$00
L6797:  STA  KSPEED,X
L679A:  LDA  GAME
L679C:  BEQ  InitiateKillerMine_90  ;NO ADJUSTMENT FOR TWO PLAYER FIGHTERS
L679E:  LDA  WAVE
L67A1:  ASL
L67A2:  BMI  InitiateKillerMine_90  ;NOT GO NEGATIVE
L67A4:  ADC  OBKLMINES,X
L67A6:  BMI  InitiateKillerMine_90
L67A8:  STA  OBKLMINES,X

InitiateKillerMine_90:
L67AA:  RTS                         ;(EXIT)

InitiateKillerMine_50:
L67AB:  LDA  SpeedTableGame0,Y
L67AE:  STA  OBKLMINES,X
L67B0:  LDA  AngleChangeSpeedGame2,Y
L67B3:  JMP  InitiateKillerMine_35

AmountAddRoutineLimits:
L67B6:  CLC
L67B7:  ADC  LNGTIMER               ;UP TIMER
L67BA:  STA  LNGTIMER
L67BD:  LDA  $03BA
L67C0:  ADC  #$00                   ;PROP CARRY
L67C2:  CMP  #$04
L67C4:  BCS  AmountAddRoutineLimits_10
L67C6:  STA  $03BA
L67C9:  RTS

AmountAddRoutineLimits_10:
L67CA:  LDA  #$FF                   ;SET TO MAX
L67CC:  STA  LNGTIMER
L67CF:  RTS

PartSignedNumberExit:
L67D0:  TYA
L67D1:  BPL  Divisor                ;IF Y>-0
L67D3:  JSR  Comp                   ;+Y=-Y
L67D6:  JSR  Divisor                ;ATAN (-Y/X)
L67D9:  JMP  Comp                   ;ARCTAN(Y/X)=-ARCTAN(-Y/X)

Divisor:
L67DC:  TAY                         ;DIVISOR
L67DD:  TXA
L67DE:  BPL  Divisor2               ;IF X=-0
L67E0:  JSR  Comp                   ;X=-X
L67E3:  JSR  Divisor2               ;ATAN(Y/-X)
L67E6:  EOR  #$80                   ;ARCTAN(Y/X)=80-ARTCAN(Y/-X)
L67E8:  JMP  Comp

Divisor2:
L67EB:  STA  POTGO                  ;DIVISOR (X)
L67ED:  TYA                         ;DIVIDEND (Y)
L67EE:  CMP  POTGO
L67F0:  BEQ  Divisor2_10            ;IF Y=X
L67F2:  BCC  L4BitDivide            ;IF Y<X USE ARCTAN ON 45 DEGREE SECTOR
L67F4:  LDY  POTGO
L67F6:  STA  POTGO
L67F8:  TYA
L67F9:  JSR  L4BitDivide            ;ARCTAN (X/Y)
L67FC:  SEC
L67FD:  SBC  #$40
L67FF:  JMP  Comp                   ;ARCTAN (Y/X)=40-ARCTAN(X/Y)

Divisor2_10:
L6802:  LDA  #$20                   ;45 DEGRESS
L6804:  RTS

L4BitDivide:
L6805:  JSR  Temp21DivisorUnsigned  ;4 BIT DIVIDE
L6808:  AND  #$0F
L680A:  TAX
L680B:  LDA  L03,X                  ;TABLE LOOKUP
L680E:  RTS

L03:
L680F:  .byte $00, $02, $05, $07, $0A, $0C, $0F, $11
L6817:  .byte $13, $15, $17, $19, $1A, $1C, $1D, $1F

Temp21DivisorUnsigned:
L681F:  LDY  #$04                   ;4 BITS OF RESOLUTION

Divi20:
L6821:  ROL  TEMP2                  ;SHIFT IN BIT OF ANSWER
L6823:  ROL
L6824:  CMP  POTGO
L6826:  BCC  Divi20_20              ;NOT LARGE ENOUGH
L6828:  SBC  POTGO                  ;LEAVES CARRY SET

Divi20_20:
L682A:  DEY
L682B:  BNE  Divi20
L682D:  LDA  TEMP2
L682F:  ROL                         ;SHIFT IN LAST BIT
L6830:  RTS

CosSinPi2:
L6831:  CLC                         ;COS(A)=SIN(A+PI/2)
L6832:  ADC  #$40

PiAngle0:
L6834:  BPL  Sin1                   ;IF PI > ANGLE >-0
L6836:  AND  #$7F
L6838:  JSR  Sin1                   ;SIN(A) WHEN PI > A >= 0
L683B:  JMP  Comp                   ;SIN(PI+A)=-SIN(A)

Sin1:
L683E:  CMP  #$41
L6840:  BCC  Sin1_10                ;PI/2 >- ANGLE >- 0
L6842:  EOR  #$7F                   ;SIN(PI/2+A)=SIN(PI/2-A)
L6844:  ADC  #$00                   ;ADD 1

Sin1_10:
L6846:  TAX
L6847:  LDA  Sin07,X
L684A:  RTS

EntryInputExitAbsolute:
L684B:  BPL  Comp1

Comp:
L684D:  EOR  #$FF
L684F:  CLC
L6850:  ADC  #$01

Comp1:
L6852:  RTS

SignedBySignedMult:
L6853:  BIT  TEMP1
L6855:  BPL  OutputTemp2Temp21
L6857:  PHA                         ;STACK ACC
L6858:  LDA  TEMP1
L685A:  JSR  Comp
L685D:  BPL  SignedBySignedMult_10
L685F:  LDA  #$7F

SignedBySignedMult_10:
L6861:  STA  TEMP1
L6863:  PLA                         ;RECALL ACC
L6864:  JSR  Comp
L6867:  CMP  #$80
L6869:  BNE  OutputTemp2Temp21
L686B:  LDA  #$7F

OutputTemp2Temp21:
L686D:  TAX                         ;RESET STATUS
L686E:  PHP
L686F:  STA  TEMP4
L6871:  LSR
L6872:  LSR
L6873:  LSR
L6874:  LSR
L6875:  EOR  TEMP1
L6877:  AND  #$0F
L6879:  EOR  TEMP1
L687B:  TAX
L687C:  LDA  $6D5C,X
L687F:  STA  POTGO
L6881:  LDA  TEMP4
L6883:  ASL
L6884:  ASL
L6885:  ASL
L6886:  ASL
L6887:  EOR  TEMP1
L6889:  AND  #$F0
L688B:  EOR  TEMP1
L688D:  TAX
L688E:  LDA  $6D5C,X
L6891:  STA  TEMP2
L6893:  LDA  TEMP4
L6895:  EOR  TEMP1
L6897:  AND  #$0F
L6899:  EOR  TEMP1
L689B:  TAY
L689C:  LDA  TEMP4
L689E:  EOR  TEMP1
L68A0:  AND  #$F0
L68A2:  EOR  TEMP1
L68A4:  TAX
L68A5:  LDA  $6D5C,X
L68A8:  CLC
L68A9:  ADC  $6D5C,Y
L68AC:  TAX
L68AD:  ROR
L68AE:  LSR
L68AF:  LSR
L68B0:  LSR
L68B1:  STA  TEMP4
L68B3:  TXA
L68B4:  ASL
L68B5:  ASL
L68B6:  ASL
L68B7:  ASL
L68B8:  CLC
L68B9:  ADC  TEMP2
L68BB:  STA  TEMP2
L68BD:  LDA  POTGO
L68BF:  ADC  TEMP4
L68C1:  PLP
L68C2:  BPL  L_90_68C7              ;OKAY AS IT WAS
L68C4:  SEC
L68C5:  SBC  TEMP1

L_90_68C7:
L68C7:  STA  POTGO
L68C9:  RTS

Pwron:
L68CA:  LDA  #$00
L68CC:  LDX  #$FE
L68CE:  TXS
L68CF:  CLD
L68D0:  JSR  LswVectorAddress
L68D3:  JSR  Inset2
L68D6:  LDA  #$BF
L68D8:  LDX  #$02

Pwron_30:
L68DA:  STA  PL0SCFLAG,X
L68DD:  DEX
L68DE:  BPL  Pwron_30
L68E0:  JSR  Inisou
L68E3:  LDA  #$01
L68E5:  STA  LASTG                  ;IN CASE CABERET
L68E8:  LDA  #$FF
L68EA:  STA  UPDFLG
L68EC:  STA  $39                    ;NO NEW HIGH SCORE
L68EE:  STA  SPFLG
L68F1:  LDA  #$80                   ;INIT TO NO STARTS ALLOWED
L68F3:  STA  STRTLOK
L68F6:  CLI                         ;ALLOW INTERRUPTS
L68F7:  JSR  DisplayParameters      ;PUT UP SCORES AT FIRST
L68FA:  JMP  StartUpNewAsteroids

UsesTemp1Temp11:
L68FD:  INC  FRAME
L68FF:  LDA  FRAME
L6901:  ASL
L6902:  ASL                         ;PULSE INTENSITY
L6903:  ASL
L6904:  ASL
L6905:  ORA  #$80                   ;MIN BRIGHTNESS
L6907:  STA  INTEN                  ;SAVE INTENSITY
L690A:  LDA  $31                    ;LOCKOUT STATUS FROM MAIN LINE
L690C:  LDX  CABERE                 ;COCKTAIL?????
L690F:  BMI  UsesTemp1Temp11_4      ;YEP...NO ADITIONAL FLIP NEEDED
L6911:  ORA  #$C0                   ;ELSE FLIP FOR COCKTAIL NORMAL

UsesTemp1Temp11_4:
L6913:  LDX  LANGBT                 ;GAME PLAYING? (COIN ROUTINE OFF)
L6915:  BMI  UsesTemp1Temp11_3      ;IF YES,SKIP COUNTER STUFF
L6917:  LDX  $29                    ;1ST COUNTER?
L6919:  BPL  UsesTemp1Temp11_1      ;NOPE
L691B:  ORA  #$01                   ;TURN IT ON

UsesTemp1Temp11_1:
L691D:  LDX  ROTENG                 ;NEXT
L691F:  BPL  UsesTemp1Temp11_3
L6921:  ORA  #$02                   ;ITS ON

UsesTemp1Temp11_3:
L6923:  LDX  ATRACT
L6925:  BPL  UsesTemp1Temp11_5
L6927:  LDX  $45                    ;WAIT SHORT TIME BEFORE STOPPING COIN ROUTINE
L6929:  BEQ  UsesTemp1Temp11_5
L692B:  LDX  GENDING
L692D:  BNE  UsesTemp1Temp11_5
L692F:  LDX  #$80
L6931:  STX  LANGBT                 ;NO MORE COIN ROUTINE

UsesTemp1Temp11_5:
L6933:  STA  OUT1
L6936:  LDA  FRAME
L6938:  BEQ  Frame0FrameOff         ;FRAME IS 0, DO ALL
L693A:  AND  #$7F
L693C:  BNE  UsesTemp1Temp11_10
L693E:  JMP  Frame07f               ;FRAME &7F=0

UsesTemp1Temp11_10:
L6941:  AND  #$0F
L6943:  BNE  UsesTemp1Temp11_20
L6945:  JMP  Frame0f                ;FRAME &0F=0

UsesTemp1Temp11_20:
L6948:  AND  #$07
L694A:  BNE  UsesTemp1Temp11_30
L694C:  JMP  Frame07                ;FRAME & 07 =0

UsesTemp1Temp11_30:
L694F:  JMP  DoneAbove              ;NONE THIS TIME

Frame0FrameOff:
L6952:  BIT  ATRACT
L6954:  BMI  Frame0FrameOff_6       ;NOT ATTRACT, ALWAYS UP FRAME NUMBER
L6956:  LDA  UPDFLG
L6958:  AND  $39                    ;INITIALS?
L695A:  BPL  Frame0FrameOff_6
L695C:  LDA  $45                    ;LOADED ABOVE SO CAN TEST OLD VALUE
L695E:  AND  #$04                   ;INITIALS?
L6960:  BNE  Frame0FrameOff_2       ;YES..DOING INITIALS (OR TABLE)
L6962:  LDA  $45
L6964:  AND  #$03                   ;LOOKING FOR 3 IN BOTTOM BITS
L6966:  CMP  #$03
L6968:  BEQ  Frame0FrameOff_7       ;HOLD TILL WAVE OVER

Frame0FrameOff_2:
L696A:  LDA  STRT1                  ;NOT SPECIAL, DO NORMAL
L696D:  ORA  OPTNA1                 ;ONLY WANT BIT 7 HERE
L6970:  AND  #$80
L6972:  LDX  #$03

Frame0FrameOff_5:
L6974:  ORA  HYPSW,X                ;ANY BUTTON WILL HOLD INITIAL DISPLAY
L6977:  DEX
L6978:  BPL  Frame0FrameOff_5
L697A:  AND  #$C0
L697C:  BNE  Frame0FrameOff_7       ;PUSHED....SKIP UPDATE

Frame0FrameOff_6:
L697E:  INC  $45                    ;TIS OK TO STEP UP FRAME

Frame0FrameOff_7:
L6980:  LDX  #$01

Frame0FrameOff_12:
L6982:  LDA  MXRTIMER,X
L6985:  BEQ  Frame0FrameOff_15
L6987:  DEC  MXRTIMER,X

Frame0FrameOff_15:
L698A:  DEX
L698B:  BPL  Frame0FrameOff_12

Frame0FrameOff_30:
L698D:  LDA  $45
L698F:  AND  #$03
L6991:  BNE  Frame0FrameOff_80
L6993:  LDX  #$05

Frame0FrameOff_35:
L6995:  LDA  KLMINC,X               ;DROP COLOR OF KILLER MINES
L6997:  CMP  #$01
L6999:  BEQ  Frame0FrameOff_36
L699B:  DEC  KLMINC,X

Frame0FrameOff_36:
L699D:  LDA  KSPEED,X
L69A0:  BEQ  Frame0FrameOff_45      ;NOT ACTIVE
L69A2:  CMP  EndingValueKillerMine,X ;CHECK FOR TOP SPEED
L69A5:  BCS  Frame0FrameOff_40
L69A7:  ADC  #$02
L69A9:  STA  KSPEED,X

Frame0FrameOff_40:
L69AC:  LDA  KANGCH,X
L69AF:  CMP  Kchend,X
L69B2:  BCS  Frame0FrameOff_45
L69B4:  ADC  #$01
L69B6:  STA  KANGCH,X

Frame0FrameOff_45:
L69B9:  DEX
L69BA:  BPL  Frame0FrameOff_35
L69BC:  JSR  SinceCannotGetMust

Frame0FrameOff_80:
L69BF:  LDX  #$07

Frame0FrameOff_83:
L69C1:  LDA  OBCOMETS,X
L69C3:  BEQ  Frame0FrameOff_85
L69C5:  LDA  COMTYP,X
L69C8:  BPL  Frame0FrameOff_85      ;NASCENT
L69CA:  LDA  CSPEED,X
L69CD:  CMP  #$10
L69CF:  BCS  Frame0FrameOff_84
L69D1:  INC  CSPEED,X

Frame0FrameOff_84:
L69D4:  LDA  CANGCH,X
L69D7:  CMP  #$70
L69D9:  BCS  Frame0FrameOff_85
L69DB:  INC  CANGCH,X
L69DE:  INC  CANGCH,X

Frame0FrameOff_85:
L69E1:  DEX
L69E2:  BPL  Frame0FrameOff_83

Frca30:
L69E4:  LDA  GAME
L69E6:  BNE  Frca30_20
L69E8:  LDA  $45
L69EA:  AND  #$0F
L69EC:  BNE  Frca30_20
L69EE:  JSR  InitiateKillerMine

Frca30_20:
L69F1:  BIT  TOGCOMB
L69F3:  BPL  Frame07f
L69F5:  LDA  $45
L69F7:  LSR
L69F8:  BCS  Frca30_30
L69FA:  LDA  BCOMSTART
L69FD:  ADC  #$11
L69FF:  STA  COMSTART
L6A02:  LDA  $03B5
L6A05:  CLC
L6A06:  ADC  #$15
L6A08:  STA  $0398
L6A0B:  BPL  Frame07f               ;ALWAYS

Frca30_30:
L6A0D:  LDA  $03B5
L6A10:  CLC
L6A11:  ADC  #$11
L6A13:  STA  COMSTART
L6A16:  LDA  BCOMSTART
L6A19:  CLC
L6A1A:  ADC  #$15
L6A1C:  STA  $0398

Frame07f:
L6A1F:  LDX  #$01

Frame07f_7:
L6A21:  LDA  SENMDEL,X
L6A24:  CMP  #$09
L6A26:  BCC  Frame07f_8
L6A28:  DEC  SENMDEL,X

Frame07f_8:
L6A2B:  DEX
L6A2C:  BPL  Frame07f_7

Frame0f:
L6A2E:  JSR  DisplayParameters      ;DISPLAY PARAMETERS HERE
L6A31:  LDA  COMTIMER
L6A34:  BEQ  Frame07
L6A36:  DEC  COMTIMER
L6A39:  BNE  Frame07
L6A3B:  LDA  #$00
L6A3D:  STA  NENTCOMETS
L6A40:  STA  NENTDWARF
L6A43:  JSR  GetCometToGo

Frame07:
L6A46:  BIT  SPECEX                 ;WANT SPECIAL EXPLOSION?
L6A49:  BPL  Frame07_9
L6A4B:  JSR  BellsWistles

Frame07_9:
L6A4E:  JSR  L2Saucers              ;KEEP SAUCERS MOVING
L6A51:  LDA  NROCKS
L6A54:  BEQ  DoneAbove              ;NO ROCKS
L6A56:  LDX  #$01

Frame07_10:
L6A58:  LDA  RTIMER,X
L6A5B:  BEQ  Frame07_20
L6A5D:  DEC  RTIMER,X

Frame07_20:
L6A60:  LDA  ETIMER,X
L6A63:  BEQ  Frame07_25
L6A65:  DEC  ETIMER,X

Frame07_25:
L6A68:  LDA  ENMDEL,X
L6A6B:  BEQ  Frame07_30
L6A6D:  DEC  ENMDEL,X

Frame07_30:
L6A70:  DEX
L6A71:  BPL  Frame07_10
L6A73:  LDA  SCSHSP
L6A76:  AND  $039E                  ;BOTH SHOTTING FAST?
L6A79:  BMI  DoneAbove
L6A7B:  LDA  LNGTIMER
L6A7E:  SEC
L6A7F:  SBC  #$01
L6A81:  STA  LNGTIMER
L6A84:  BCS  DoneAbove
L6A86:  DEC  $03BA

DoneAbove:
L6A89:  LDX  #$01

DoneAbove_22:
L6A8B:  LDA  COLLIS,X               ;MSB WAS NOT ON
L6A8E:  BMI  DoneAbove_23           ;NO COLLISION LAST TIME
L6A90:  ASL  COLLIS,X               ;PUT MSB

DoneAbove_23:
L6A93:  SEC
L6A94:  ROR  COLLIS,X
L6A97:  DEX
L6A98:  BPL  DoneAbove_22
L6A9A:  RTS

EndingValueKillerMine:
L6A9B:  .byte $70, $60, $60, $50, $40

Kchend:
L6AA0:  .byte $18, $10, $10, $0C, $08

SinceCannotGetMust:
L6AA5:  LDX  #$01
L6AA7:  LDY  DIFF                   ;USE DIFF SETTING

L_10:
L6AA9:  LDA  NWCACH,X
L6AAC:  CMP  #$40
L6AAE:  BCS  L_30
L6AB0:  ADC  NewCometAngleChange,Y  ;ADD AMOUNT BASED ON DIFF

L_30:
L6AB3:  LDA  NWCSPD,X
L6AB6:  ADC  NewCometTopSpeed,Y
L6AB9:  BMI  L_40_6ABE
L6ABB:  STA  NWCSPD,X

L_40_6ABE:
L6ABE:  LDA  FCSPD,X
L6AC1:  CMP  #$40
L6AC3:  BCS  L_60
L6AC5:  ADC  FirstCometSTop,Y
L6AC8:  STA  FCSPD,X

L_60:
L6ACB:  DEX
L6ACC:  BPL  L_10
L6ACE:  RTS

Comentable:
L6ACF:  .byte $11, $15

Onslaught:
L6AD1:  LDA  NROCKS
L6AD4:  ORA  GENDING                ;ENDING?
L6AD6:  BNE  Onslaught_90
L6AD8:  LDA  GAME
L6ADA:  CMP  #$02
L6ADC:  BCC  Onslaught_10           ;DON'T CARE ABOUT 1 DEAD
L6ADE:  BIT  COMOFF
L6AE1:  BPL  Onslaught_10

Onslaught_90:
L6AE3:  RTS

Onslaught_10:
L6AE4:  LDA  NENTCOMETS
L6AE7:  ORA  NENTDWARF
L6AEA:  BNE  Onslaught_12           ;STILL SOME LEFT

Onslaught_11:
L6AEC:  RTS

Onslaught_12:
L6AED:  BMI  Onslaught_90
L6AEF:  LDA  COMTIMER
L6AF2:  BEQ  Onslaught_90           ;OUT OF TIME
L6AF4:  LDA  FRAME
L6AF6:  AND  #$0F
L6AF8:  BNE  Onslaught_90
L6AFA:  LDY  #$00                   ;WHOSE COMETS TO USE
L6AFC:  LDA  #$21
L6AFE:  STA  EACE                   ;THE TARGET
L6B00:  LDX  #$14
L6B02:  LDA  GAME
L6B04:  CMP  #$01
L6B06:  BNE  Onslaught_50
L6B08:  LDX  #$18
L6B0A:  BNE  Onslaught_95

Onslaught_50:
L6B0C:  LDA  FRAME
L6B0E:  AND  #$20
L6B10:  BNE  Onslaught_95
L6B12:  INY
L6B13:  INC  EACE
L6B15:  LDX  #$18

Onslaught_95:
L6B17:  STY  TEMP1                  ;FOR EHASENTERED
L6B19:  JMP  Inco10                 ;ALWAYS

QuickEndEndOnslaught:
L6B1C:  LDA  ATRACT
L6B1E:  BEQ  QuickEndEndOnslaught_20 ;NOT DURING ATTRACT
L6B20:  LDA  OBSHIP                 ;BOTH EXPLODING
L6B22:  AND  $B9
L6B24:  BPL  QuickEndEndOnslaught_1 ;NO
L6B26:  JSR  StopFuseSound          ;STOP FUSE

QuickEndEndOnslaught_1:
L6B29:  LDA  OBSHIP                 ;SEE IF BOTH DEAD
L6B2B:  ORA  $B9                    ;THIS IS 0 IF NOT ACTIVE
L6B2D:  BEQ  QuickEndEndOnslaught_5
L6B2F:  RTS

QuickEndEndOnslaught_5:
L6B30:  LDX  #$07                   ;REMOVE COMETS

QuickEndEndOnslaught_10:
L6B32:  STA  OBCOMETS,X
L6B34:  DEX
L6B35:  BPL  QuickEndEndOnslaught_10
L6B37:  STA  OBSAUCER               ;REMOVE SAUCERS
L6B39:  STA  $B7
L6B3B:  STA  NENTCOMETS
L6B3E:  STA  NENTDWARF
L6B41:  STA  SUPRSAC                ;RESET SUPERSAUCER

QuickEndEndOnslaught_20:
L6B44:  RTS

RandomFuzz:
L6B45:  LDA  $100A                  ;RANDOM "FUZZ"
L6B48:  AND  #$07
L6B4A:  BEQ  RandomFuzz_10
L6B4C:  RTS                         ;NOT TIME

RandomFuzz_10:
L6B4D:  LDA  OBSHIP                 ;IS THIS ONE DEAD
L6B4F:  BMI  RandomFuzz_15          ;YES
L6B51:  JMP  FusePlyr1              ;SOUND & RETURN

RandomFuzz_15:
L6B54:  JMP  FusePlyr0              ;SOUND & RETURN

StopFuseSound:
L6B57:  LDA  #$00
L6B59:  STA  POINT                  ;STOP POINTERS
L6B5B:  STA  $57
L6B5D:  STA  $5C
L6B5F:  STA  $5D
L6B61:  STA  $1001                  ;STOP POKEY
L6B64:  STA  $1007
L6B67:  RTS

InitializeComet:
L6B68:  LDY  TEMP1                  ;WHO GETS IT (0:1)
L6B6A:  LDX  COMSTART,Y

Inco10:
L6B6D:  LDA  Comentable,Y

UsesTemp2Temp21:
L6B70:  BIT  ATRACT
L6B72:  BPL  UsesTemp2Temp21_99     ;NOT DURING ATTRACT
L6B74:  CPX  #$19                   ;TO MANY TO START??
L6B76:  BCC  UsesTemp2Temp21_4      ;OK TO START
L6B78:  LDX  #$18                   ;SET TO MAX

UsesTemp2Temp21_4:
L6B7A:  STA  TEMPA

UsesTemp2Temp21_5:
L6B7C:  CPX  TEMPA
L6B7E:  BCC  UsesTemp2Temp21_99
L6B80:  LDA  OBJ,X
L6B82:  BMI  UsesTemp2Temp21_7
L6B84:  BEQ  UsesTemp2Temp21_10

UsesTemp2Temp21_7:
L6B86:  DEX
L6B87:  JMP  UsesTemp2Temp21_5

UsesTemp2Temp21_99:
L6B8A:  RTS                         ;(EXIT)

UsesTemp2Temp21_10:
L6B8B:  LDA  COMTIMER
L6B8E:  BNE  UsesTemp2Temp21_12     ;ONSLAUGHT
L6B90:  LDA  NCOMET
L6B93:  CMP  COMLIMIT
L6B96:  BCS  UsesTemp2Temp21_99     ;FULL ALREADY

UsesTemp2Temp21_12:
L6B98:  INC  NCOMET
L6B9B:  LDA  EACE
L6B9D:  STA  GTIME,X
L6BA0:  TAY
L6BA1:  LDA  $100A

UsesTemp2Temp21_15:
L6BA4:  PHA                         ;SAVE IT(MORE STACK:1)
L6BA5:  LDA  #$00
L6BA7:  STA  OBJXL,X
L6BAA:  STA  OBJYL,X
L6BAD:  PLA                         ;(LESS STACK:0)
L6BAE:  PHA                         ;(MORE STACK:1)
L6BAF:  LSR
L6BB0:  BCS  UsesTemp2Temp21_50     ;VARY Y INSTEAD OF X
L6BB2:  LSR
L6BB3:  PHA                         ;SAVE RANDOME VALUE (0-3F) (STACK:2)
L6BB4:  LDA  #$00                   ;BOTTOM
L6BB6:  BCS  UsesTemp2Temp21_20
L6BB8:  LDA  #$17                   ;TOP
L6BBA:  DEC  OBJYL,X

UsesTemp2Temp21_20:
L6BBD:  STA  OBJYH,X                ;UPPER BYTE OF Y
L6BC0:  SEC
L6BC1:  SBC  OBJYH,Y
L6BC4:  JSR  EntryInputExitAbsolute
L6BC7:  STA  TEMP2                  ;DIFFERENCE IN Y
L6BC9:  CMP  #$02                   ;MINIMU, DIFFERENCE
L6BCB:  PLA                         ;RECALL RANDOM VALUE (STACK:1)
L6BCC:  BCC  UsesTemp2Temp21_83     ;TWO CLOSE
L6BCE:  LSR                         ;(0-1F)
L6BCF:  STA  OBJXH,X                ;UPPER BYTE OF X
L6BD2:  SEC
L6BD3:  SBC  OBJXH,Y
L6BD6:  JMP  UsesTemp2Temp21_80

UsesTemp2Temp21_50:
L6BD9:  LSR
L6BDA:  PHA                         ;(MORE STACK:2)
L6BDB:  LDA  #$00
L6BDD:  BCS  UsesTemp2Temp21_60
L6BDF:  LDA  #$1F
L6BE1:  DEC  OBJXL,X

UsesTemp2Temp21_60:
L6BE4:  STA  OBJXH,X
L6BE7:  SEC
L6BE8:  SBC  OBJXH,Y
L6BEB:  JSR  EntryInputExitAbsolute
L6BEE:  STA  TEMP2                  ;(LESS STACK:1)
L6BF0:  PLA
L6BF1:  LSR                         ;(0-1F)
L6BF2:  CMP  #$18
L6BF4:  BCC  UsesTemp2Temp21_70
L6BF6:  SBC  #$18                   ;(0:7)
L6BF8:  STA  TEMPA
L6BFA:  ASL
L6BFB:  ADC  TEMPA                  ;(0:21)

UsesTemp2Temp21_70:
L6BFD:  STA  OBJYH,X
L6C00:  SEC
L6C01:  SBC  OBJYH,Y

UsesTemp2Temp21_80:
L6C04:  JSR  EntryInputExitAbsolute
L6C07:  CMP  #$02
L6C09:  BCS  UsesTemp2Temp21_85     ;WAS MINIMUM DISTANCE AT LEAST

UsesTemp2Temp21_83:
L6C0B:  PLA                         ;(STACK:0)
L6C0C:  ADC  #$21                   ;VARY RANDOM NUMBER SLIGHTLY
L6C0E:  JMP  UsesTemp2Temp21_15

UsesTemp2Temp21_85:
L6C11:  ADC  TEMP2
L6C13:  CMP  #$04                   ;MIN DISTANCE TO START OBJECT
L6C15:  PLA                         ;(GET STACK CORRECT)
L6C16:  BCS  Inco30
L6C18:  ADC  #$81                   ;VARY RANDOM NUMBER TO OTHER SIDE
L6C1A:  JMP  UsesTemp2Temp21_15

Inco30:
L6C1D:  LDY  GTIME,X
L6C20:  LDA  COLLIS,Y
L6C23:  STA  $0274,X
L6C26:  LDA  STRADDLE,Y
L6C29:  STA  OBJ,X
L6C2B:  LDA  #$00                   ;DWARF
L6C2D:  STA  $0266,X
L6C30:  STA  XINC,X
L6C33:  STA  YINC,X
L6C36:  STA  $037E,X
L6C39:  LDA  NENTCOMETS
L6C3C:  BEQ  Inco30_30
L6C3E:  DEC  NENTCOMETS
L6C41:  BPL  Inco30_50              ;ALWAYS

Inco30_30:
L6C43:  LDA  NENTDWARF
L6C46:  BEQ  Inco30_40
L6C48:  DEC  NENTDWARF
L6C4B:  BPL  Inco30_70              ;ALWAYS

Inco30_40:
L6C4D:  LDA  $100A
L6C50:  CMP  $0378,Y
L6C53:  BCS  Inco30_70

Inco30_50:
L6C55:  JSR  SbttlStcomet

Inco30_70:
L6C58:  STX  TEMP3
L6C5A:  JSR  FindDifferenceCoordinates ;FIRST ANGLE
L6C5D:  LDX  TEMP3
L6C5F:  STA  $0282,X
L6C62:  JMP  ResetTimers            ;(EXIT)

CometCalculations:
L6C65:  LDA  FRAME
L6C67:  BIT  COMTIMER               ;ONSLAUGHT?
L6C6A:  BPL  L6C71
L6C6C:  AND  #$07
L6C6E:  JMP  L6C79
L6C71:  AND  #$1F                   ;ASSUME 8 NCOMETS=8
L6C73:  LSR                         ;WILL DO COMETS ON ODD FRAMES ONLY
L6C74:  BCS  Docoex
L6C76:  LSR
L6C77:  BCS  Docoex
L6C79:  CLC
L6C7A:  ADC  #$11
L6C7C:  TAX
L6C7D:  STX  TEMP3
L6C7F:  LDY  GTIME,X
L6C82:  LDA  OBJ,X
L6C84:  BMI  Docoex
L6C86:  BEQ  Docoex
L6C88:  LDA  $037E,X
L6C8B:  BMI  CometCalculations_20
L6C8D:  JMP  AccHoldsAngleObject

CometCalculations_20:
L6C90:  JSR  GetWrapAroundAngle
L6C93:  JMP  Klmi7

LswVectorAddress:
L6C96:  LDA  #$01                   ;LSW OF VECTOR ADDRESS
L6C98:  STA  VECMEM
L6C9B:  LDA  #$E0                   ;JUMP INSTRUCTION
L6C9D:  STA  $2001
L6CA0:  LDA  #$20                   ;HALT INSTRUCTION
L6CA2:  STA  $2003
L6CA5:  STA  $2403

Docoex:
L6CA8:  RTS

Xplini:
L6CA9:  .byte $FC, $03, $05, $FE, $00, $FA, $06, $02
L6CB1:  .byte $01, $07, $FC, $FC

ChangeDirection:
L6CB5:  .byte $C0, $30, $50, $E0, $00, $A0, $60, $20
L6CBD:  .byte $10, $70, $C0, $C0

HoldsSign2Byte:
L6CC1:  .byte $FF, $00, $00, $FF, $00, $FF, $00, $00
L6CC9:  .byte $00, $00, $FF, $FF

TableInitialValuesToggles:
L6CCD:  .byte $00, $00, $80, $80

Ttogdrone:
L6CD1:  .byte $00, $00, $00, $80

Ttplayr:
L6CD5:  .byte $02, $01, $02, $01

SpeedTableGame1:
L6CD9:  .byte $58, $50, $40, $38, $30, $28, $20, $10
L6CE1:  .byte $08

AngleChangeSpeedGame:
L6CE2:  .byte $09, $07, $06, $06, $06, $06, $06, $03
L6CEA:  .byte $02

SpeedTableSpaceStation:
L6CEB:  .byte $7F, $6F, $5F, $4F, $3F, $2F, $1F, $0F
L6CF3:  .byte $07

AngleChangeSpeedSpace:
L6CF4:  .byte $1F, $17, $10, $0C, $09, $07, $06, $05
L6CFC:  .byte $03

SpeedTableGame0:
L6CFD:  .byte $60, $60, $40, $40, $30, $30, $28, $28
L6D05:  .byte $18

AngleChangeSpeedGame2:
L6D06:  .byte $0C, $0C, $0A, $0A, $06, $06, $05, $05
L6D0E:  .byte $03

NewCometAngleChange:
L6D0F:  .byte $01, $01, $02, $03

NewCometTopSpeed:
L6D13:  .byte $01, $02, $03, $04

FirstCometSTop:
L6D17:  .byte $02, $03, $04, $05

Sin07:
L6D1B:  .byte $00, $03, $06, $09, $0C, $10, $13, $16
L6D23:  .byte $19, $1C, $1F, $22, $25, $28, $2B, $2E
L6D2B:  .byte $31, $33, $36, $39, $3C, $3F, $41, $44
L6D33:  .byte $47, $49, $4C, $4E, $51, $53, $55, $58
L6D3B:  .byte $5A, $5C, $5E, $60, $62, $64, $66, $68
L6D43:  .byte $6A, $6B, $6D, $6F, $70, $71, $73, $74
L6D4B:  .byte $75, $76, $78, $79, $7A, $7A, $7B, $7C
L6D53:  .byte $7D, $7D, $7E, $7E, $7E, $7F, $7F, $7F
L6D5B:  .byte $7F, $00, $00, $00, $00, $00, $00, $00
L6D63:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L6D6B:  .byte $00, $00, $01, $02, $03, $04, $05, $06
L6D73:  .byte $07, $08, $09, $0A, $0B, $0C, $0D, $0E
L6D7B:  .byte $0F, $00, $02, $04, $06, $08, $0A, $0C
L6D83:  .byte $0E, $10, $12, $14, $16, $18, $1A, $1C
L6D8B:  .byte $1E, $00, $03, $06, $09, $0C, $0F, $12
L6D93:  .byte $15, $18, $1B, $1E, $21, $24, $27, $2A
L6D9B:  .byte $2D, $00, $04, $08, $0C, $10, $14, $18
L6DA3:  .byte $1C, $20, $24, $28, $2C, $30, $34, $38
L6DAB:  .byte $3C, $00, $05, $0A, $0F, $14, $19, $1E
L6DB3:  .byte $23, $28, $2D, $32, $37, $3C, $41, $46
L6DBB:  .byte $4B, $00, $06, $0C, $12, $18, $1E, $24
L6DC3:  .byte $2A, $30, $36, $3C, $42, $48, $4E, $54
L6DCB:  .byte $5A, $00, $07, $0E, $15, $1C, $23, $2A
L6DD3:  .byte $31, $38, $3F, $46, $4D, $54, $5B, $62
L6DDB:  .byte $69, $00, $08, $10, $18, $20, $28, $30
L6DE3:  .byte $38, $40, $48, $50, $58, $60, $68, $70
L6DEB:  .byte $78, $00, $09, $12, $1B, $24, $2D, $36
L6DF3:  .byte $3F, $48, $51, $5A, $63, $6C, $75, $7E
L6DFB:  .byte $87, $00, $0A, $14, $1E, $28, $32, $3C
L6E03:  .byte $46, $50, $5A, $64, $6E, $78, $82, $8C
L6E0B:  .byte $96, $00, $0B, $16, $21, $2C, $37, $42
L6E13:  .byte $4D, $58, $63, $6E, $79, $84, $8F, $9A
L6E1B:  .byte $A5, $00, $0C, $18, $24, $30, $3C, $48
L6E23:  .byte $54, $60, $6C, $78, $84, $90, $9C, $A8
L6E2B:  .byte $B4, $00, $0D, $1A, $27, $34, $41, $4E
L6E33:  .byte $5B, $68, $75, $82, $8F, $9C, $A9, $B6
L6E3B:  .byte $C3, $00, $0E, $1C, $2A, $38, $46, $54
L6E43:  .byte $62, $70, $7E, $8C, $9A, $A8, $B6, $C4
L6E4B:  .byte $D2, $00, $0F, $1E, $2D, $3C, $4B, $5A
L6E53:  .byte $69, $78, $87, $96, $A5, $B4, $C3, $D2
L6E5B:  .byte $E1, $04, $AC, $89, $AB, $E4, $AB, $73
L6E63:  .byte $AB, $C5, $AB, $57, $AB, $A5, $AB, $40
L6E6B:  .byte $AB, $05, $AC, $8A, $AB, $E5, $AB, $74
L6E73:  .byte $AB, $C6, $AB, $58, $AB, $A6, $AB, $41
L6E7B:  .byte $AB, $89, $90, $22, $9E, $22, $AC, $22
L6E83:  .byte $BA, $22, $BC, $22, $BE, $22, $C0, $22
L6E8B:  .byte $C2, $22, $73, $ED, $8F, $ED, $16, $ED
L6E93:  .byte $D6, $EC, $11, $EE, $24, $EC, $88, $EC
L6E9B:  .byte $59, $EE, $9A, $ED, $B7, $ED, $29, $ED
L6EA3:  .byte $E9, $EC, $1F, $EE, $40, $EC, $93, $EC
L6EAB:  .byte $70, $EE, $C3, $ED, $DD, $ED, $40, $ED
L6EB3:  .byte $F5, $EC, $32, $EE, $58, $EC, $A5, $EC
L6EBB:  .byte $87, $EE, $E8, $ED, $05, $EE, $5A, $ED
L6EC3:  .byte $01, $ED, $46, $EE, $70, $EC, $AF, $EC
L6ECB:  .byte $9F, $EE, $48, $A1, $4F, $A1, $56, $A1
L6ED3:  .byte $5D, $A1, $5E, $A1, $5F, $A1, $60, $A1
L6EDB:  .byte $61, $A1, $00, $08, $10, $18, $28, $30
L6EE3:  .byte $20, $38

DoLowOnesEvery:
L6EE5:  LDX  #$00                   ;DO LOW ONES EVERY FRAME
L6EE7:  LDA  FRAME
L6EE9:  AND  #$03
L6EEB:  BNE  DoLowOnesEvery_1       ;ONLY LOW ONES THIS TIME
L6EED:  LDX  #$02                   ;WILL DO BOTH

DoLowOnesEvery_1:
L6EEF:  INC  ASTERS,X
L6EF2:  LDA  ASTERS,X
L6EF5:  AND  #$03
L6EF7:  BNE  DoLowOnesEvery_5
L6EF9:  INC  $03DA,X
L6EFC:  BMI  DoLowOnesEvery_5
L6EFE:  LDA  #$FD
L6F00:  CPX  #$02
L6F02:  BNE  DoLowOnesEvery_2
L6F04:  LDA  #$FC                   ;4 COLORS HERE

DoLowOnesEvery_2:
L6F06:  STA  $03DA,X

DoLowOnesEvery_5:
L6F09:  DEC  $03D7,X
L6F0C:  LDA  $03D7,X
L6F0F:  AND  #$03
L6F11:  CMP  #$03                   ;DID IT JUST LEAVE FIRST PIC?
L6F13:  BNE  DoLowOnesEvery_6
L6F15:  DEC  $03DB,X
L6F18:  BPL  DoLowOnesEvery_6
L6F1A:  LDA  #$02
L6F1C:  CPX  #$02
L6F1E:  BNE  DoLowOnesEvery_7
L6F20:  LDA  #$03

DoLowOnesEvery_7:
L6F22:  STA  $03DB,X

DoLowOnesEvery_6:
L6F25:  DEX
L6F26:  DEX
L6F27:  BPL  DoLowOnesEvery_1       ;NEED TO DO OTHERS??

DoLowOnesEvery_8:
L6F29:  LDX  #$03                   ;ROTATE AND RECOPY ALL 4

DoLowOnesEvery_10:
L6F2B:  JSR  SaveLater
L6F2E:  LDA  $6E7D,Y                ;GET LSB OF VGRAM AREA FOR THIS STAR
L6F31:  STA  VGLIST
L6F33:  LDA  $6E7E,Y                ;MSB
L6F36:  STA  EAC2
L6F38:  JSR  GetRotationColorCode
L6F3B:  LDX  TEMP2                  ;RECALL X
L6F3D:  LDA  #$02                   ;3 COLOR INSTRUCTIONS
L6F3F:  STA  POTGO                  ;A REG TO COUNT DOWN BY
L6F41:  LDA  $03DA,X
L6F44:  AND  #$03                   ;GET COLOR CODE
L6F46:  CPX  #$03
L6F48:  BCS  DoLowOnesEvery_20
L6F4A:  CPX  #$02                   ;4 COLOR TABLE
L6F4C:  BCC  DoLowOnesEvery_12      ;NO
L6F4E:  ADC  #$05

DoLowOnesEvery_12:
L6F50:  TAX

DoLowOnesEvery_15:
L6F51:  LDA  ColorTable,X           ;GET PROPER COLOR
L6F54:  STA  (VGLIST),Y
L6F56:  INY
L6F57:  INX
L6F58:  LDA  #$64                   ;FINISH COLOR (STAT) INSTRUCTION
L6F5A:  STA  (VGLIST),Y
L6F5C:  INY
L6F5D:  LDA  #$C0                   ;NOW ADD AN RTSL
L6F5F:  STA  (VGLIST),Y
L6F61:  INY
L6F62:  STA  (VGLIST),Y             ;2 BYTES
L6F64:  INY
L6F65:  DEC  POTGO
L6F67:  BPL  DoLowOnesEvery_15

DoLowOnesEvery_20:
L6F69:  LDX  TEMP2                  ;RESTORE X
L6F6B:  DEX
L6F6C:  BPL  DoLowOnesEvery_10

Toppic:
L6F6E:  LDX  #$03

Toppic_10:
L6F70:  JSR  SaveLater
L6F73:  LDA  $6E85,Y                ;GET ADDRESS FROM TOP 4 WORDS
L6F76:  STA  VGLIST
L6F78:  LDA  $6E86,Y
L6F7B:  STA  EAC2                   ;WHERE TO BUILD PICTURE
L6F7D:  LDA  #$08
L6F7F:  CLC
L6F80:  ADC  TEMP3                  ;ADJUST TEMP 3 TO POINT AT TOP 4
L6F82:  STA  TEMP3
L6F84:  TXA
L6F85:  AND  #$01                   ;ONLY WANT TO USE SLOW ROTATIONS
L6F87:  TAX
L6F88:  INX
L6F89:  INX                         ;POINT AT SLOW ROTATIONS
L6F8A:  JSR  GetRotationColorCode   ;TEMP 3 ADJUSTED FOR THIS ROUTINE
L6F8D:  LDX  TEMP2
L6F8F:  DEX
L6F90:  BPL  Toppic_10              ;DO ALL 4

MoveSaucerPicColor:
L6F92:  LDA  FRAME
L6F94:  AND  #$03
L6F96:  BEQ  MoveSaucerPicColor_10

MoveSaucerPicColor_5:
L6F98:  RTS

MoveSaucerPicColor_10:
L6F99:  INC  SAUCIX
L6F9C:  LDA  SAUCIX
L6F9F:  AND  #$03
L6FA1:  STA  SAUCIX
L6FA4:  BNE  MoveSaucerPicColor_5
L6FA6:  LDA  SAU11
L6FA9:  LDX  SAU12
L6FAC:  LDY  SAU13                  ;MOVE COLOR
L6FAF:  STA  SAU13
L6FB2:  STX  SAU11
L6FB5:  STY  SAU12
L6FB8:  RTS

Mod:
L6FB9:  .byte $01, $02, $02, $03, $02, $03, $04, $03
L6FC1:  .byte $04, $05, $04, $05, $06, $05, $06, $07
L6FC9:  .byte $06, $07

TableRandomPictureSelect:
L6FCB:  .byte $80, $00, $80, $00, $00, $80, $00, $00
L6FD3:  .byte $80, $00, $00, $80, $00, $00, $80, $00
L6FDB:  .byte $00, $80

L80RandomWave0:
L6FDD:  STX  TEMP8
L6FDF:  STY  TEMP7
L6FE1:  LDX  WAVE
L6FE4:  CPX  #$12
L6FE6:  BCC  L6FEA
L6FE8:  LDX  #$12
L6FEA:  LDA  $6FB8,X                ;GET MODULO
L6FED:  LDY  $6FCA,X                ;RANDOM?
L6FF0:  BPL  L7000
L6FF2:  DEC  MODNUM                 ;NEXT PIC
L6FF5:  BPL  L6FFD
L6FF7:  LDA  $6FB8,X                ;RESTORE
L6FFA:  STA  MODNUM
L6FFD:  LDA  MODNUM
L7000:  TAX                         ;LEAVE INDEX IN X
L7001:  LDA  $6EDD,X
L7004:  LDX  TEMP8
L7006:  LDY  TEMP7
L7008:  RTS

ColorTable:
L7009:  .byte $E1, $E2, $E4, $E1, $E2, $E4

Barco2:
L700F:  .byte $E4, $E6, $E1, $E2, $E4, $E6, $E1, $E2

SaveLater:
L7017:  STX  TEMP2                  ;SAVE X (FOR LATER)
L7019:  TXA                         ;X+0 TO 1 (STAR SELECT)
L701A:  ASL                         ;TO A WORD POINTER
L701B:  STA  TEMP3                  ;SAVE FOR OFFSET INTO RSOURC
L701D:  TAY
L701E:  RTS

GetRotationColorCode:
L701F:  LDA  ASTERS,X               ;GET ROTATION/COLOR CODE
L7022:  AND  #$03                   ;BOTTOM 2 BITS SELECT PROPER PICTURE
L7024:  ASL                         ;2 WORDS EACH (1 COUNTER CLOCKWISE)
L7025:  ASL
L7026:  ASL                         ;* 4 CHOICES (2 SPINNERS, PYRM, AND CUBE)
L7027:  ASL                         ;* 8 (HEXAGON.......)
L7028:  CLC
L7029:  ADC  TEMP3                  ;ADD IX OFFSET

GetRotationColorCode_11:
L702B:  TAX
L702C:  LDY  #$00                   ;SET UP OUTPUT VGLIST POINTER
L702E:  LDA  $6E8D,X                ;GET LSB OF SOURCE PICTURE POINTER
L7031:  STA  (VGLIST),Y
L7033:  INY
L7034:  INX
L7035:  LDA  $6E8D,X                ;GET OTHER BYTE
L7038:  STA  (VGLIST),Y
L703A:  INY
L703B:  RTS

AlwaysRemainsSameBoth:
L703C:  BIT  SUPRSAC
L703F:  BPL  AlwaysRemainsSameBoth_90 ;NOT ACTIVE
L7041:  LDA  #$41
L7043:  STA  $B7                    ;ACTIVATE OTHER SAUCER
L7045:  LDA  $033F
L7048:  STA  $0340
L704B:  STA  TEMP9                  ;SAVE A
L704D:  LDY  $02D4
L7050:  STY  $02D5
L7053:  TXA
L7054:  PHA                         ;SAVE X
L7055:  LDX  #$03                   ;WILL FORCE SHELLS TO HAVE..5$:	STA X,OBJXL+ZCOMINES	;SAME X POSITION

AlwaysRemainsSameBoth_5:
L7057:  LDA  TEMP9
L7059:  STA  $0344,X
L705C:  TYA
L705D:  STA  $02D9,X
L7060:  DEX
L7061:  BPL  AlwaysRemainsSameBoth_5
L7063:  CLC
L7064:  LDA  SUPRDIS                ;GET DISTANCE
L7067:  TAX
L7068:  ADC  $0306
L706B:  STA  $0307
L706E:  LDA  $0371
L7071:  STA  $0372
L7074:  LDA  $021F
L7077:  STA  $0220
L707A:  LDA  $707F,X
L707D:  STA  SUPRTIM                ;STORE SHOT TIME
L7080:  PLA
L7081:  TAX                         ;RECALL OLD X

AlwaysRemainsSameBoth_90:
L7082:  RTS

Time:
L7083:  .byte $02, $02, $03, $04, $04, $05, $05, $06
L708B:  .byte $06, $07, $07, $07, $08, $08

L2Saucers:
L7091:  LDX  #$01                   ;2 SAUCERS

L2Saucers_10:
L7093:  LDA  OBSAUCER,X
L7095:  BNE  L2Saucers_20           ;ACTIVE

L2Saucers_15:
L7097:  DEX                         ;DO NEXT
L7098:  BPL  L2Saucers_10
L709A:  RTS

L2Saucers_20:
L709B:  SEC
L709C:  LDA  SAUMIN,X               ;MINIUM VEL, + OR -?
L709E:  BPL  L2Saucers_30           ;GO DO + TERM
L70A0:  SBC  $021F,X                ;CHECK VELOCITY
L70A3:  BVC  L2Saucers_25
L70A5:  EOR  #$80

L2Saucers_25:
L70A7:  BPL  L2Saucers_15
L70A9:  DEC  $021F,X
L70AC:  JMP  L2Saucers_15           ;JUST IN CASE CROSSED 0

L2Saucers_30:
L70AF:  SBC  $021F,X
L70B2:  BEQ  L2Saucers_15           ;EQUAL CONDITION
L70B4:  BVC  L2Saucers_35
L70B6:  EOR  #$80                   ;EOR IN V=1 WITH MINUS FLAG

L2Saucers_35:
L70B8:  BMI  L2Saucers_15
L70BA:  INC  $021F,X
L70BD:  JMP  L2Saucers_15           ;DO NEXT
L70C0:  .byte $90, $00, $00, $01, $04, $00, $00, $00
L70C8:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L70D0:  .byte $00, $07, $0A, $00, $00, $00, $00, $00
L70D8:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L70E0:  .byte $00, $00, $00, $00, $00, $00, $00, $15
L70E8:  .byte $0A, $00, $00, $00, $00, $00, $00, $00
L70F0:  .byte $00, $0D, $10, $00, $00, $00, $00, $00
L70F8:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7100:  .byte $00, $00, $00, $00, $00, $00, $00, $18
L7108:  .byte $10, $00, $00, $00, $00, $00, $00, $00
L7110:  .byte $00, $00, $00, $00, $00, $21, $26, $00
L7118:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7120:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7128:  .byte $00, $00, $00, $00, $00, $49, $50, $5F
L7130:  .byte $62, $00, $00, $00, $00, $00, $00, $00
L7138:  .byte $00, $65, $68, $00, $00, $00, $00, $00
L7140:  .byte $00, $3E, $45, $00, $00, $00, $00, $00
L7148:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7150:  .byte $00, $00, $00, $00, $00, $00, $00, $3E
L7158:  .byte $45, $00, $00, $00, $00, $00, $00, $00
L7160:  .byte $00, $6B, $70, $00, $00, $00, $00, $00
L7168:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7170:  .byte $00, $1B, $1E, $00, $00, $00, $00, $00
L7178:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7180:  .byte $00, $00, $00, $00, $00, $00, $00, $1B
L7188:  .byte $1E, $00, $00, $00, $00, $00, $00, $00
L7190:  .byte $00, $00, $00, $81, $86, $00, $00, $00
L7198:  .byte $00, $00, $00, $00, $00, $00, $00, $00

TablesOffsetPointerSounds:
L71A0:  .byte $00

Pntrs:
L71A1:  .byte $01, $08, $02, $10, $00, $00

Sf2a:
L71A7:  .byte $87, $20, $FE, $04, $00, $00

ShipFirePlayer0:
L71AD:  .byte $24, $01, $03, $40, $00, $00

P0f1a:
L71B3:  .byte $A4, $10, $FF, $04, $00, $00

P0e1f:
L71B9:  .byte $0A, $FF, $00, $10, $00, $00

P0e1a:
L71BF:  .byte $40, $20, $01, $0A, $4A, $10, $01, $06
L71C7:  .byte $00, $00

ShipFirePlayer1:
L71C9:  .byte $24, $01, $03, $40, $00, $00

P1e4f:
L71CF:  .byte $09, $FF, $00, $10, $00, $00

ShieldSound:
L71D5:  .byte $B0, $02, $00, $0F, $00, $00

S01a:
L71DB:  .byte $C0, $01, $02, $0F, $00, $00

ExtraLife:
L71E1:  .byte $06, $E0, $00, $01, $05, $E0, $00, $01
L71E9:  .byte $00, $00

El3a:
L71EB:  .byte $AF, $10, $00, $01, $A0, $10, $00, $01
L71F3:  .byte $AF, $10, $00, $01, $A0, $10, $00, $01
L71FB:  .byte $AF, $10, $00, $01, $A0, $10, $00, $01
L7203:  .byte $AF, $10, $00, $01, $A0, $10, $00, $01
L720B:  .byte $AF, $10, $00, $01, $A0, $10, $00, $01
L7213:  .byte $AF, $10, $00, $01, $A0, $10, $00, $01

FuseSound:
L721B:  .byte $00, $02, $00, $0A, $FF, $01, $00, $04
L7223:  .byte $00, $02, $00, $10, $00, $00

F01a:
L7229:  .byte $07, $10, $01, $20, $00, $00, $00, $00

ExplosionSound:
L7231:  .byte $A0, $01, $FE, $08, $A0, $01, $FE, $04
L7239:  .byte $98, $10, $04, $10, $00, $00

Xp7a:
L723F:  .byte $82, $02, $01, $04, $8C, $08, $FF, $03
L7247:  .byte $80, $04, $00, $01, $8C, $20, $FF, $01
L724F:  .byte $86, $40, $FF, $01, $82, $40, $FF, $01
L7257:  .byte $81, $40, $FF, $01, $00, $00

Xp8f:
L725D:  .byte $C0, $10, $04, $10, $00, $00

Xp8a:
L7263:  .byte $86, $50, $FE, $03, $00, $00

Th5f:
L7269:  .byte $02, $07, $00, $01, $00, $00

Th5a:
L726F:  .byte $84, $07, $00, $01, $00, $00

Gk1f:
L7275:  .byte $00, $01, $04, $FF, $FF, $01, $04, $FF
L727D:  .byte $00, $00

Gk1a:
L727F:  .byte $AF, $01, $00, $40, $A3, $01, $00, $40
L7287:  .byte $AD, $01, $00, $40, $A7, $01, $00, $40
L728F:  .byte $A5, $01, $00, $40, $A3, $01, $00, $40
L7297:  .byte $A4, $01, $00, $40, $A1, $01, $00, $40
L729F:  .byte $00, $00

Pp2f:
L72A1:  .byte $20, $01, $00, $03, $80, $01, $10, $06
L72A9:  .byte $00, $00

Pp2a:
L72AB:  .byte $AF, $01, $FE, $02, $A0, $01, $00, $01
L72B3:  .byte $A3, $02, $FF, $03, $00, $00

Popsn:
L72B9:  LDA  #$DF
L72BB:  BNE  HighScoreTune

FusePlyr1:
L72BD:  LDA  #$9F                   ;FUSE, PLYR 1
L72BF:  BNE  HighScoreTune

FusePlyr0:
L72C1:  LDA  #$8F                   ;FUSE, PLYR 0
L72C3:  BNE  HighScoreTune

Reenter:
L72C5:  LDA  #$4F                   ;REENTER
L72C7:  BNE  HighScoreTune

Reenter2:
L72C9:  LDA  #$3F                   ;REENTER
L72CB:  BNE  HighScoreTune

Sh0sn:
L72CD:  LDA  #$BF
L72CF:  BNE  HighScoreTune          ;SHIELD PLAYER 0

Sh1sn:
L72D1:  LDA  #$CF
L72D3:  BNE  HighScoreTune          ;SHIELD, PLAYER 1

SaucerFire:
L72D5:  LDA  #$0F                   ;SAUCER FIRE
L72D7:  BNE  HighScoreTune

Player0Fire:
L72D9:  LDA  #$1F                   ;PLAYER 0 FIRE
L72DB:  BNE  HighScoreTune

Player1Fire:
L72DD:  LDA  #$2F                   ;PLAYER 1 FIRE
L72DF:  BNE  HighScoreTune

ExtraLife2:
L72E1:  LDA  #$5F                   ;EXTRA LIFE
L72E3:  BNE  HighScoreTune

Explosion:
L72E5:  LDA  #$6F                   ;EXPLOSION
L72E7:  BNE  HighScoreTune

ThrustSound:
L72E9:  LDA  #$7F                   ;THRUST SOUND
L72EB:  BNE  HighScoreTune

Gates:
L72ED:  LDA  #$AF
L72EF:  BNE  HighScoreTune

HighScoreTune:
L72F1:  BIT  HSCFLG                 ;HIGH SCORE TUNE?
L72F4:  BMI  Badhab                 ;DAVE T. DID THIS!!!!!
L72F6:  BIT  ATRACT                 ;ATTRACT MODE?
L72F8:  BPL  L731C

Badhab:
L72FA:  STX  TEMPA
L72FC:  STY  TEMPB
L72FE:  TAY                         ;USE AS INDEX
L72FF:  LDX  #$0F                   ;NO.
L7301:  LDA  $70C1,Y
L7304:  BEQ  L7314
L7306:  STX  SINDEX
L7308:  STA  POINT,X                ;IF NOT SET UP POINTER
L730A:  LDA  #$01
L730C:  STA  FRAMES,X               ;DUMMY START, NO SOUND
L730E:  STA  COUNT,X                ;TILL MODSND STORES TO POKEY
L7310:  LDA  #$FF
L7312:  STA  SINDEX
L7314:  DEY
L7315:  DEX
L7316:  BPL  L7301
L7318:  LDX  TEMPA                  ;RESTORE X & Y UPON RETURN
L731A:  LDY  TEMPB
L731C:  RTS

ContinuesPreviouslyStartedSound:
L731D:  LDX  #$0F                   ;8 CHANNELS
L731F:  LDA  POINT,X
L7321:  BEQ  L73A1
L7323:  CPX  SINDEX
L7325:  BEQ  L73A1
L7327:  DEC  FRAMES,X               ;YES
L7329:  BNE  L73A1
L732B:  DEC  COUNT,X                ;YES.
L732D:  BNE  L7367

YesStartValue:
L732F:  INC  POINT,X                ;YES. START VALUE
L7331:  INC  POINT,X
L7333:  LDA  POINT,X
L7335:  ASL
L7336:  TAY
L7337:  BCS  L7349
L7339:  LDA  $719B,Y
L733C:  STA  CURRENT,X
L733E:  LDA  $719E,Y
L7341:  STA  COUNT,X
L7343:  LDA  $719C,Y
L7346:  JMP  L7356
L7349:  LDA  $729B,Y
L734C:  STA  CURRENT,X
L734E:  LDA  $729E,Y
L7351:  STA  COUNT,X
L7353:  LDA  $729C,Y
L7356:  STA  FRAMES,X
L7358:  BNE  L7364
L735A:  STA  POINT,X                ;NO. KILL IT
L735C:  LDA  CURRENT,X
L735E:  BEQ  L7364
L7360:  STA  POINT,X                ;YES. UPDATE PTR. WITH RESTART LOC
L7362:  BNE  YesStartValue
L7364:  JMP  L7392
L7367:  ASL
L7368:  TAY
L7369:  BCS  L7376
L736B:  LDA  $719C,Y
L736E:  STA  FRAMES,X
L7370:  LDA  $719D,Y
L7373:  JMP  L737E
L7376:  LDA  $729C,Y
L7379:  STA  FRAMES,X
L737B:  LDA  $729D,Y
L737E:  LDY  CURRENT,X
L7380:  CLC
L7381:  ADC  CURRENT,X
L7383:  STA  CURRENT,X
L7385:  TXA
L7386:  LSR
L7387:  BCC  L7392
L7389:  TYA
L738A:  EOR  CURRENT,X
L738C:  AND  #$F0
L738E:  EOR  CURRENT,X
L7390:  STA  CURRENT,X
L7392:  LDA  CURRENT,X              ;UPDATE POKEY AUDIO CHANNEL
L7394:  CPX  #$08
L7396:  BCC  L739E
L7398:  STA  $13F8,X
L739B:  JMP  L73A1
L739E:  STA  POKEY,X
L73A1:  DEX
L73A2:  BMI  L73A7
L73A4:  JMP  L731F
L73A7:  RTS

Inisou:
L73A8:  LDA  #$00
L73AA:  STA  $100F
L73AD:  STA  $140F
L73B0:  LDA  #$07
L73B2:  STA  $100F
L73B5:  STA  $140F
L73B8:  LDX  #$07
L73BA:  LDA  #$00
L73BC:  STA  POKEY,X
L73BF:  STA  POKEY2,X
L73C2:  STA  POINT,X
L73C4:  STA  CURRENT,X
L73C6:  DEX
L73C7:  BPL  L73BC
L73C9:  LDA  #$00
L73CB:  STA  $1008
L73CE:  LDX  #$00                   ;DEFAULT VALUE FOR AUDCV2
L73D0:  STX  $1408
L73D3:  RTS

ForceFieldUp:
L73D4:  LDA  COMTIMER               ;FORCE FIELD UP?
L73D7:  BNE  ForceFieldUp_10        ;DO SOUND
L73D9:  STA  $1402                  ;TURN OFF
L73DC:  STA  $1403
L73DF:  STA  SFREQ
L73E2:  STA  $1408                  ;SET BACK TO NORMAL FREQ.
L73E5:  TAX
L73E6:  LDA  #$FF
L73E8:  BNE  ForceFieldUp_25        ;*****ALWAYS**

ForceFieldUp_10:
L73EA:  LDA  #$01
L73EC:  STA  $1408                  ;LOWER FREQ OF HUM
L73EF:  LDA  FRAME
L73F1:  AND  #$07
L73F3:  BNE  ForceFieldUp_20        ;NO CHANGE
L73F5:  LDA  SFREQ                  ;UP FREQ
L73F8:  CMP  #$30                   ;MAX
L73FA:  BCC  ForceFieldUp_20
L73FC:  SBC  #$01                   ;BMP UP
L73FE:  STA  SFREQ

ForceFieldUp_20:
L7401:  LDA  SFREQ                  ;IN CASE WE CAME FROM 10$ ABOVE
L7404:  STA  $1402
L7407:  LDX  #$A3                   ;TONE
L7409:  STX  $1403

ForceFieldUp_25:
L740C:  LDY  $5A                    ;IS CHAN 3 ACTIVE?
L740E:  BNE  ForceFieldUp_40        ;IF IN USE, DON'T TOUCH
L7410:  CLC
L7411:  ADC  #$01
L7413:  STA  $1004
L7416:  STX  $1005

ForceFieldUp_40:
L7419:  RTS
L741A:  LDX  #$02
L741C:  LDA  HALT
L741F:  CPX  #$01
L7421:  BEQ  L7426
L7423:  BCS  L7427
L7425:  LSR
L7426:  LSR
L7427:  LSR

InstructionsBracketsAreIllustration:
L7428:  LDA  $2D,X
L742A:  AND  #$1F                   ;SHARED INST. SEE BELOW IN BRACKETS []
L742C:  BCS  InstructionsBracketsAreIllustration_5 ;BRANCH IF INPUT HIGH (COIN ABSENT)
L742E:  BEQ  InstructionsBracketsAreIllustration_1 ;STICK AT 0 (TERMINAL COUNT)
L7430:  CMP  #$1B                   ;IN FIRST FIVE SAMPLES?
L7432:  BCS  InstructionsBracketsAreIllustration_10 ;YES, RUN FAST
L7434:  TAY                         ;ELSE SAVE STATUS
L7435:  LDA  ZSHIP                  ;CHECK INTERUPT CTR
L7437:  AND  #$07                   ;ARE D0-D2 ALL ONES?
L7439:  CMP  #$07                   ;SET CARRY IF SO
L743B:  TYA                         ;STATUS BACK INTO ACC
L743C:  BCC  InstructionsBracketsAreIllustration_1 ;SKIP IF NOT ALL ONES

InstructionsBracketsAreIllustration_10:
L743E:  SBC  #$01                   ;CARRY SET

InstructionsBracketsAreIllustration_1:
L7440:  STA  $2D,X
L7442:  LDA  HALT                   ;CHECK SLAM SWITCH
L7445:  AND  #$08
L7447:  BNE  InstructionsBracketsAreIllustration_2 ;BRANCH IF BIT HI (SWITCH OFF)
L7449:  LDA  #$F0                   ;ELSE SET PRE-COIN SLAM TIMER
L744B:  STA  $25                    ;DECR. 8 TIMES/FRAME=PRST FRAMES

InstructionsBracketsAreIllustration_2:
L744D:  LDA  $25                    ;CHECK PRE-COIN SLAM TIMER
L744F:  BEQ  InstructionsBracketsAreIllustration_3 ;O.K.
L7451:  DEC  $25                    ;ELSE RUN TIMER
L7453:  LDA  #$00
L7455:  STA  $2D,X                  ;CLEAR COIN STATUS
L7457:  STA  $2A,X                  ;CLEAR POST-COIN SLAM TIMER

InstructionsBracketsAreIllustration_3:
L7459:  CLC                         ;DEFAULT "NO COIN DETECTED"
L745A:  LDA  $2A,X                  ;CHECK POST-COIN SLAM TIMER
L745C:  BEQ  InstructionsBracketsAreIllustration_8 ;EMPTY, PROCEED
L745E:  DEC  $2A,X                  ;ELSE RUN TIMER
L7460:  BNE  InstructionsBracketsAreIllustration_8 ;NOT DONE, PROCEED
L7462:  SEC                         ;WHEN IT BECOMES ZERO, INDICATE A COIN
L7463:  BCS  InstructionsBracketsAreIllustration_8 ;(ALWAYS)

InstructionsBracketsAreIllustration_5:
L7465:  CMP  #$1B                   ;IS COIN VALID YET (ON FOR >4 SAMPLES)
L7467:  BCS  InstructionsBracketsAreIllustration_6 ;NO, RESET IT
L7469:  LDA  $2D,X                  ;GET STATUS AGAIN
L746B:  ADC  #$20                   ;BUMP COIN-OFF UP-CTR.
L746D:  BCC  InstructionsBracketsAreIllustration_1 ;IF IT DIDN'T WRAP, JUST STORE STATUS
L746F:  BEQ  InstructionsBracketsAreIllustration_6 ;IT WRAPPED BUT COIN WAS ON TOO LONG, JUST RESET
L7471:  CLC                         ;SET "VALIDITY" AGAIN

InstructionsBracketsAreIllustration_6:
L7472:  LDA  #$1F                   ;RESET DOWN-COUNTER
L7474:  BCS  InstructionsBracketsAreIllustration_1 ;BRANCH IF COIN TOO LONG OR TOO SHORT
L7476:  STA  $2D,X                  ;SAVE RESET STATUS
L7478:  LDA  $2A,X                  ;CHECK HOWIE'S ASSUMPTION
L747A:  BEQ  InstructionsBracketsAreIllustration_7 ;BRANCH IF $PSTSL VACANT
L747C:  SEC                         ;ELSE GIVE CREDIT A LITTLE EARLY

InstructionsBracketsAreIllustration_7:
L747D:  LDA  #$78                   ;/(4 COUNTS/FRAME)="POST" FRAMES
L747F:  STA  $2A,X

InstructionsBracketsAreIllustration_8:
L7481:  BCC  InstructionsBracketsAreIllustration_9
L7483:  LDA  #$00                   ;START WITH 0 (TO ADD 1)
L7485:  CPX  #$01                   ;CHECK WHICH MECH
L7487:  BCC  L749F                  ;IF LEFT, ALWAYS ADD 1
L7489:  BEQ  L7497                  ;IF CENTER, CHECK HALF-MUL

InstructionsBracketsAreIllustration_83:
L748B:  LDA  ZMINE

InstructionsBracketsAreIllustration_85:
L748D:  AND  #$0C
L748F:  LSR
L7490:  LSR
L7491:  BEQ  L749F
L7493:  ADC  #$02
L7495:  BNE  L749F
L7497:  LDA  ZMINE
L7499:  AND  #$10
L749B:  BEQ  L749F
L749D:  LDA  #$01
L749F:  SEC
L74A0:  PHA
L74A1:  ADC  $22                    ;UPDATE BONUS-ADDER COUNTER
L74A3:  STA  $22
L74A5:  PLA
L74A6:  SEC
L74A7:  ADC  $26
L74A9:  STA  $26                    ;UPDATE CNCT
L74AB:  INC  $27,X                  ;"QUEUE" PULSE FOR E.M. COUNTER

InstructionsBracketsAreIllustration_9:
L74AD:  DEX
L74AE:  BMI  GetBonusAdderMode
L74B0:  JMP  L741C

GetBonusAdderMode:
L74B3:  LDA  ZMINE
L74B5:  LSR
L74B6:  LSR
L74B7:  LSR
L74B8:  LSR
L74B9:  LSR
L74BA:  TAY
L74BB:  LDA  $22
L74BD:  SEC
L74BE:  SBC  NumberUnitCoinsRequired,Y ;SEE IF ENOUGH UNIT-COINS HAVE ACCUMULATED
L74C1:  BMI  Extb                   ;BRANCH IF NOT
L74C3:  STA  $22                    ;ELSE UPDATE BONUS-ADDER AND...
L74C5:  INC  ZPAIR                  ;GIVE ONE OR TWO BONUS UNIT-COINS
L74C7:  CPY  #$03
L74C9:  BNE  Extb
L74CB:  INC  ZPAIR                  ;MODE 3 YIELDS 2 BONUS COINS FOR 4 INSERTED
L74CD:  BNE  Extb                   ;BRA

NumberUnitCoinsRequired:
L74CF:  .byte $7F, $02, $04, $04, $05, $03, $7F, $7F

Extb:
L74D7:  LDA  ZMINE
L74D9:  AND  #$03
L74DB:  TAY                         ;SAVE IT
L74DC:  BEQ  L_2                    ;IF FREE PLAY CMODE=0, DO NOTHING
L74DE:  LSR                         ;ELSE FORM PRICE (0,1,1,2)
L74DF:  ADC  #$00
L74E1:  EOR  #$FF
L74E3:  SEC
L74E4:  ADC  $26                    ;ACC <- COINCT-PRICE
L74E6:  BCS  L_33                   ;BRANCH IF NO BORROW
L74E8:  ADC  ZPAIR                  ;ADD IN BONUS COINS-SEE IF THEY HELP
L74EA:  BMI  Ext                    ;BRANCH IF COINCT+BONUS COINS <PRICE
L74EC:  STA  ZPAIR                  ;ELSE ACC=UNUSED BONUS COINS
L74EE:  LDA  #$00                   ;ACC=NEW $CNCT

L_33:
L74F0:  CPY  #$02                   ;Y=COIN MODE-COIN MODE 2 OR 3?
L74F2:  BCS  L_1                    ;BRANCH IF MODE 2 OR 3-GIVE 1 CREDIT
L74F4:  INC  DIAGBI                 ;ELSE GIVE 2 FOR MODE 1

L_1:
L74F6:  INC  DIAGBI

L_2:
L74F8:  STA  $26                    ;UPDAT COINCT

Ext:
L74FA:  INC  ZSHIP
L74FC:  LDA  ZSHIP
L74FE:  LSR
L74FF:  BCS  Ext_99
L7501:  LDY  #$00                   ;START WITH FLAG OF 0
L7503:  LDX  #$02

Ext_1:
L7505:  LDA  $27,X                  ;CHECK TIMER(X)
L7507:  BEQ  Ext_3                  ;NEITHER RUNNING NOR PENDING
L7509:  CMP  #$10                   ;IS IT RUNNING
L750B:  BCC  Ext_3                  ;NO, SKIP
L750D:  ADC  #$EF                   ;ELSE DEC 4 MSB
L750F:  INY                         ;SET ON FLAG

Ext_2:
L7510:  STA  $27,X

Ext_3:
L7512:  DEX
L7513:  BPL  Ext_1
L7515:  TYA                         ;CHECK "ON" FLAG
L7516:  BNE  Ext_99                 ;SKIP IF ANY ON
L7518:  LDX  #$02

Ext_4:
L751A:  LDA  $27,X                  ;NEED WE START THIS ONE
L751C:  BEQ  Ext_5                  ;NO, NO COUNTS PENDING
L751E:  CLC
L751F:  ADC  #$EF                   ;SET 4 MSB, DEC 4 LSB
L7521:  STA  $27,X                  ;START TIMER
L7523:  BMI  Ext_99                 ;EXIT, SO WE DON'T START MORE

Ext_5:
L7525:  DEX
L7526:  BPL  Ext_4

Ext_99:
L7528:  RTS

Display4Names:
L7529:  LDY  #$03                   ;DISPLAY 4 NAMES
L752B:  STY  TEMP9
L752D:  LDY  #$C1
L752F:  JSR  SetVectorGeneratorStatus ;BOXES ARE BLUE
L7532:  BIT  CABERE
L7535:  BVC  L753E
L7537:  LDA  #$14
L7539:  LDX  #$A8
L753B:  JMP  L7542
L753E:  LDA  #$00
L7540:  LDX  #$A8
L7542:  JSR  Add2WordsToVector

Display4Names_10:
L7545:  LDY  TEMP9                  ;RECALL Y
L7547:  LDX  Display4Names_100,Y    ;GET POSITION OF PICS
L754A:  LDA  Display4Names_110,Y
L754D:  BIT  CABERE
L7550:  BVC  L7555
L7552:  LDA  Display4Names_170,Y    ;SPECIAL CABERET X
L7555:  JSR  Mesgpos                ;POSITION
L7558:  LDY  TEMP9
L755A:  LDX  $764E,Y
L755D:  LDA  $7652,Y
L7560:  JSR  Add2WordsToVector      ;ADD PROPER PIC TO LIST
L7563:  LDA  DIAGBI                 ;IF NO CREDIT...SKIP BOXES
L7565:  BEQ  Display4Names_14
L7567:  BIT  ZSAUCE                 ;WAITING ON TWO COINS?
L7569:  BMI  Display4Names_14
L756B:  BIT  STRTLOK                ;ARE WE NOT DOING STARTS????
L756E:  BMI  Display4Names_14       ;YES WE ARE NOT....NO BOXES
L7570:  LDY  FLASHCOL
L7573:  JSR  SetVectorGeneratorStatus ;TEMP COLOR FLASH*************
L7576:  LDY  GAME                   ;SELECTED GAME
L7578:  LDX  Display4Names_140,Y    ;POSITION OF FLASHING BOX
L757B:  LDA  Display4Names_150,Y
L757E:  BIT  CABERE
L7581:  BVC  L7586
L7583:  LDA  Display4Names_180,Y    ;SPECIAL CABERET X
L7586:  JSR  Mesgpos
L7589:  LDA  FRAME
L758B:  AND  #$1C                   ;WHICH BOX
L758D:  CMP  #$10                   ;OFF TIME!
L758F:  BCS  Display4Names_14       ;YEP
L7591:  LSR
L7592:  LSR
L7593:  TAY
L7594:  LDX  Picadh,Y               ;GET JSRL TO BOX PIC
L7597:  LDA  $764A,Y
L759A:  JSR  Add2WordsToVector

Display4Names_14:
L759D:  LDY  TEMP9
L759F:  LDX  Display4Names_120,Y    ;POSITION FO MESSAGE...
L75A2:  LDA  Display4Names_130,Y    ;..'SELECT GAME','MORE COINS','PUSH START'
L75A5:  BIT  CABERE
L75A8:  BVC  L75AD
L75AA:  LDA  Display4Names_185,Y    ;SPECIAL CABERET X
L75AD:  JSR  Mesgpos
L75B0:  LDX  #$06
L75B2:  JSR  AuxRoutineAddOffset
L75B5:  LDX  #$00                   ;GUESS MESSAGE 0 (PUSH START)
L75B7:  LDY  #$C7
L75B9:  LDA  DIAGBI
L75BB:  BNE  Display4Names_11       ;CREDIT...CONTINUE

Display4Names_17:
L75BD:  LDX  #$02
L75BF:  BNE  Display4Names_16       ;DO ANOTHER COIN EVERYWHERE!

Display4Names_11:
L75C1:  BIT  ZSAUCE
L75C3:  BMI  Display4Names_17
L75C5:  BIT  STRTLOK                ;STARTS NOT ALLOWED NOW???
L75C8:  BMI  Display4Names_12       ;NOPE...SO SKIP 'PUSH START'
L75CA:  LDA  TEMP9
L75CC:  CMP  GAME                   ;THIS ONE SELECTED?
L75CE:  BEQ  Display4Names_30       ;YES...MESSAGE OK

Display4Names_12:
L75D0:  INX                         ;GUESS 'SELECT GAME'
L75D1:  LDY  #$E5
L75D3:  LDA  FRAME
L75D5:  AND  #$08                   ;BLINK 'SELECT GAME' BLUE/VIOLET
L75D7:  BNE  Display4Names_15
L75D9:  LDY  #$E3

Display4Names_15:
L75DB:  BIT  TEMP5                  ;SELL GAME MODE?
L75DD:  BMI  Display4Names_30
L75DF:  LDA  DIAGBI
L75E1:  CMP  #$02                   ;ENOUGH CREDIT FOR ALL GAMES?
L75E3:  BCS  Display4Names_30       ;YES, DO MESSAGE
L75E5:  LDA  TEMP9
L75E7:  LSR                         ;CARRY SET FOR 1 PLAYER GAMES
L75E8:  BCS  Display4Names_30       ;DO MESSAGE
L75EA:  INX                         ;'MORE COINS'

Display4Names_16:
L75EB:  LDY  #$E6
L75ED:  LDA  FRAME
L75EF:  AND  #$04
L75F1:  BNE  Display4Names_30
L75F3:  LDY  #$E4

Display4Names_30:
L75F5:  TYA
L75F6:  LDY  $7656,X                ;GET PROPER MESSAGE
L75F9:  JSR  PassColor
L75FC:  LDX  #$20                   ;OFFSET FROM LAST MESSAGE TO THIS ONE
L75FE:  LDY  LANG
L7600:  LDA  Display4Names_160,Y    ;LANGUAGE CORRECTION FOR NEXT MESSAGE
L7603:  JSR  UpdownVectorUpsideDown ;DO MESSAGE
L7606:  LDX  TEMP9
L7608:  LDY  $7659,X                ;GET MESSAGE #
L760B:  JSR  VectorMessage5
L760E:  LDY  TEMP9
L7610:  BIT  CABERE
L7613:  BVC  L7616
L7615:  DEY                         ;DOWN BY 2
L7616:  DEY
L7617:  STY  TEMP9
L7619:  BMI  L765D                  ;DONE---GO DO CREDIT DISPLAY
L761B:  JMP  Display4Names_10       ;DO NEXT

Display4Names_100:
L761E:  .byte $20, $20, $D6, $D6

Display4Names_110:
L7622:  .byte $C0, $48, $BA, $48

Display4Names_120:
L7626:  .byte $08, $08, $C2, $C2

Display4Names_130:
L762A:  .byte $9A, $20, $9A, $20

Display4Names_140:
L762E:  .byte $3C, $3C, $F6, $F6

Display4Names_150:
L7632:  .byte $82, $02, $82, $03

Display4Names_160:
L7636:  .byte $C0, $AC, $B0, $B8

Display4Names_170:
L763A:  .byte $00, $00, $00, $00

Display4Names_180:
L763E:  .byte $00, $C4, $00, $C4

Display4Names_185:
L7642:  .byte $00, $DC, $00, $DC

Picadh:
L7646:  .byte $A8, $A8, $A8

Mesg2:
L7649:  .byte $A8, $24, $2D, $38

Creddis:
L764D:  .byte $43, $AB, $AA, $AB, $AB, $20, $9B, $2B
L7655:  .byte $26, $0D, $06, $13, $0C, $0B, $0C, $0B
L765D:  LDX  #$40
L765F:  LDA  #$E4
L7661:  JSR  Mesgpos                ;POSITION FOR MESSAGE
L7664:  LDA  #$E3
L7666:  LDY  #$18                   ;MESSAGE NUMBER
L7668:  JSR  PassColor
L766B:  LDA  DIAGBI                 ;ANY CREDIT??
L766D:  BEQ  Creddis_10             ;NO FULL CREDIT
L766F:  JSR  HexBcdConversionInput  ;CONVERT TO DECIMAL
L7672:  LDA  TEMP7                  ;GET DECIMAL NUMBER
L7674:  LSR
L7675:  LSR
L7676:  LSR
L7677:  LSR                         ;DISPLAY TOP NIBBLE
L7678:  SEC
L7679:  JSR  DisplayDigitWithZero
L767C:  LDA  TEMP7                  ;NOW DO BOTTOM NIBBLE
L767E:  JSR  DisplayDigitWithZero

Creddis_10:
L7681:  LDA  $26                    ;ANY COINS???
L7683:  BEQ  Creddis_20             ;NO HALF CREDITS
L7685:  LDA  #$6D
L7687:  LDX  #$A9
L7689:  JMP  Add2WordsToVector      ;PUT OUT HALF

Creddis_20:
L768C:  RTS

BellsWistles:
L768D:  LDX  NEXTEX
L7690:  LDA  OBJ,X                  ;DONE?
L7692:  BNE  BellsWistles_40        ;YEP
L7694:  LDA  $100A
L7697:  AND  #$17
L7699:  STA  OBJ,X

BellsWistles_15:
L769B:  LDA  $140A
L769E:  AND  #$1F
L76A0:  STA  OBJXH,X
L76A3:  LDA  $100A
L76A6:  STA  OBJXL,X
L76A9:  LDA  $140A
L76AC:  STA  OBJYL,X
L76AF:  LDA  #$00
L76B1:  STA  OBJYH,X
L76B4:  STA  XINC,X                 ;NO X MOTION
L76B7:  LDA  $100A
L76BA:  AND  #$3F                   ;RANDOM VELOCITY
L76BC:  ADC  #$40                   ;MIN VEL
L76BE:  STA  YINC,X

BellsWistles_40:
L76C1:  INX
L76C2:  CPX  #$10
L76C4:  BCC  BellsWistles_20
L76C6:  LDX  #$00                   ;START OVER

BellsWistles_20:
L76C8:  STX  NEXTEX
L76CB:  RTS

Bigbang:
L76CC:  LDX  #$2F
L76CE:  LDA  #$00

Bigbang_10:
L76D0:  STA  OBJ,X                  ;REMOVE ALL OBJECTS
L76D2:  DEX
L76D3:  BPL  Bigbang_10
L76D5:  STA  NROCKS                 ;NO ROCKS
L76D8:  STA  ATSTG                  ;NO SPECIAL
L76DA:  RTS

Gtoptn:
L76DB:  SEI
L76DC:  STA  $100B
L76DF:  LDA  $1008
L76E2:  CLI
L76E3:  EOR  #$85                   ;CORRECT FOR ALL OFF NORMAL
L76E5:  STA  OPTN1
L76E7:  LSR
L76E8:  LSR
L76E9:  TAY                         ;SHIFT D2,3 TO BOTTOM & SAVE
L76EA:  AND  #$03                   ;SAVE SWITCH SETTINGS
L76EC:  TAX
L76ED:  LDA  GAME                   ;GAME DETERMINES DIFF LEVEL
L76EF:  LSR
L76F0:  LSR                         ;IF CARRY, SPACE STATION GAME
L76F1:  BCC  L76F7
L76F3:  INX
L76F4:  INX
L76F5:  INX
L76F6:  INX                         ;USE SECOND TABLE OF 4
L76F7:  LDA  Fighters,X             ;GET LEVEL FROM TABLE
L76FA:  STA  DIFF
L76FC:  TYA
L76FD:  LSR
L76FE:  LSR
L76FF:  AND  #$03
L7701:  STA  LANG                   ;SAVE HERE TOO
L7703:  BIT  ATRACT                 ;NOT IF GAME GOING
L7705:  BMI  Gtoptn_10
L7707:  LDA  OPTN1                  ;RECALL OPTN1
L7709:  ROL
L770A:  ROL
L770B:  ROL
L770C:  AND  #$03                   ;MIX DIFF AND BONUS BITS
L770E:  TAX
L770F:  LDA  BonusOptionSwitchesAssumed,X
L7712:  STA  NXTBON
L7714:  STA  $DA
L7716:  STA  BONLVA                 ;SET BONUS LEVEL
L7718:  LDA  OPTN1                  ;GET OPTIONS AGAIN
L771A:  AND  #$03
L771C:  CLC
L771D:  ADC  #$03                   ;WE GET 3 TO 6 HERE
L771F:  STA  HITS
L7721:  STA  $48

Gtoptn_10:
L7723:  RTS

BonusOptionSwitchesAssumed:
L7724:  .byte $00, $08, $10, $15

Fighters:
L7728:  .byte $01, $02, $02, $03

SpaceStation:
L772C:  .byte $01, $01, $02, $03

AuxRoutineAddOffset:
L7730:  LDA  LANG
L7732:  BNE  AuxRoutineAddOffset_10
L7734:  RTS

AuxRoutineAddOffset_10:
L7735:  TXA
L7736:  ASL
L7737:  ASL
L7738:  CLC
L7739:  ADC  LANG
L773B:  TAY
L773C:  LDA  Offset,Y
L773F:  LDX  #$00
L7741:  JMP  UpdownVectorUpsideDown

Offset:
L7744:  .byte $00, $F5, $F5, $F5, $00, $E0, $E0, $F8
L774C:  .byte $00, $E5, $F6, $F5, $00, $EE, $EE, $E0
L7754:  .byte $00, $1A, $F8, $3D, $00, $F2, $F2, $08
L775C:  .byte $00, $EA, $EE, $00

Mesgpos:
L7760:  PHA                         ;SAVE X & Y
L7761:  TXA
L7762:  PHA
L7763:  LDA  #$61
L7765:  LDX  #$AF
L7767:  JSR  Add2WordsToVector
L776A:  PLA
L776B:  TAX
L776C:  PLA
L776D:  JMP  UpdownVectorUpsideDown ;POSITION

VectorGeneratorMessageProcessor:
L7770:  LDX  #$D6                   ;DEFAULT COLOR IS YELLOW

Brightness:
L7772:  TXA                         ;BRIGHTNESS

PassColor:
L7773:  STY  TEMP2                  ;PASS COLOR IN A
L7775:  TAY
L7776:  JMP  VectorMessage7

VectorMessage5:
L7779:  STY  TEMP2
L777B:  LDY  #$D2                   ;GREEN MESSAGES

VectorMessage7:
L777D:  JSR  SetVectorGeneratorStatus
L7780:  LDY  TEMP2

VectorMessage6:
L7782:  LDA  LANG                   ;READ OPTIONS
L7784:  ASL
L7785:  ASL                         ;LANG *4
L7786:  CPY  #$15
L7788:  BCC  VectorMessage6_5       ;NO OVERFLOW
L778A:  ADC  #$01                   ;ADD TWO
L778C:  TAX
L778D:  TYA
L778E:  SEC
L778F:  SBC  #$15                   ;REDUCE RELATIVE MESSAGE NUMBER
L7791:  TAY
L7792:  BPL  VectorMessage6_7       ;ALWAYS

VectorMessage6_5:
L7794:  TAX                         ;4*LANGUAGE (0,4,8,OR 12.)

VectorMessage6_7:
L7795:  LDA  $7804,X
L7798:  STA  EACE
L779A:  LDA  LanguageTablePointersSee,X ;CARRY IS CLEAR FROM ASL ABOVE
L779D:  STA  TEMP1                  ;TEMP1 SETUP NOW
L779F:  CLC
L77A0:  ADC  (TEMP1),Y              ;RELATIVE ADDRESS TO START OF MESSAGE
L77A2:  STA  TEMP1
L77A4:  BCC  VectorMessage6_10      ;NO OVERFLOW
L77A6:  INC  EACE

VectorMessage6_10:
L77A8:  LDY  #$00                   ;Y DOUBLES AS INDEX FOR VGLIST AND TEMP1
L77AA:  LDX  #$00

VectorMessage6_20:
L77AC:  LDA  (TEMP1,X)
L77AE:  STA  TEMP2
L77B0:  LSR
L77B1:  LSR                         ;2*INDEX
L77B2:  JSR  UpdateIndirectPointerCharacters ;PUT OUT CHARACTER AND UPDATE TEMP1
L77B5:  LDA  (TEMP1,X)
L77B7:  ROL
L77B8:  ROL  TEMP2
L77BA:  ROL
L77BB:  LDA  TEMP2
L77BD:  ROL
L77BE:  ASL
L77BF:  JSR  VectorMessage2         ;PUT OUT CHARACTER
L77C2:  LDA  (TEMP1,X)
L77C4:  STA  TEMP2
L77C6:  JSR  UpdateIndirectPointerCharacters ;PUT OUT CHARACTER AND UPDATE TEMP1
L77C9:  LSR  TEMP2
L77CB:  BCC  VectorMessage6_20      ;NOT END OF LIST

VectorMessage0:
L77CD:  DEY
L77CE:  JMP  AddY1ToVector          ;UPDATE VGLIST POINTER

UpdateIndirectPointerCharacters:
L77D1:  INC  TEMP1                  ;UPDATE INDIRECT POINTER TO CHARACTERS
L77D3:  BNE  VectorMessage2         ;NO OVERFLOW
L77D5:  INC  EACE

VectorMessage2:
L77D7:  AND  #$3E
L77D9:  BNE  VectorMessage2_5       ;NOT END OF LIST
L77DB:  PLA
L77DC:  PLA                         ;PURGE RTS
L77DD:  BNE  VectorMessage0         ;RETURN

VectorMessage2_5:
L77DF:  CMP  #$0A
L77E1:  BCC  VectorMessage2_10      ;IF BLANK, 0,1 OR 2
L77E3:  ADC  #$0D                   ;SET CORRECT INDEX (ADD 14.)

VectorMessage2_10:
L77E5:  TAX
L77E6:  LDA  UPDOWN
L77E9:  ASL                         ;SET CARRY
L77EA:  LDA  $3248,X                ;10. FOR A, 12. FOR B, ....
L77ED:  BCC  VectorMessage2_20      ;NORMAL
L77EF:  LDA  $3456,X                ;UPSIDE DOWN LETTERS

VectorMessage2_20:
L77F2:  STA  (VGLIST),Y             ;PUT JSRL INTO VECTOR LIST
L77F4:  INY
L77F5:  LDA  $3249,X
L77F8:  BCC  VectorMessage2_30      ;NORMAL
L77FA:  LDA  $3457,X

VectorMessage2_30:
L77FD:  STA  (VGLIST),Y
L77FF:  INY
L7800:  LDX  #$00
L7802:  RTS

LanguageTablePointersSee:
L7803:  .byte $13, $78, $F4, $78, $97, $79, $A0, $7A
L780B:  .byte $CF, $7A, $C6, $7B, $F4, $7B, $D9, $7C

L0:
L7813:  .byte $15, $1D, $23, $2B, $3D, $51, $69, $71
L781B:  .byte $77, $83, $8D, $99, $9F, $A5, $AD, $B5
L7823:  .byte $BF, $C3, $C7, $D1, $D9

L02:
L7828:  .byte $63, $56, $60, $6E, $3C, $EC, $4D, $C0
L7830:  .byte $A4, $0A, $EA, $6C, $08, $00, $5D, $92
L7838:  .byte $2E

German:
L7839:  .byte $02, $B9, $E6, $B2, $40, $A4, $12, $2D
L7841:  .byte $D2, $0A, $64, $C2, $6C, $0F, $66, $CD
L7849:  .byte $82, $6C, $9A, $C3, $4A

L12:
L784E:  .byte $85, $C0, $A5, $92

L12_10:
L7852:  .byte $BD

French:
L7853:  .byte $C2, $B4, $F0, $2E, $12, $0E, $26, $0D
L785B:  .byte $D2, $82, $4E, $C0, $60, $4E, $30, $4D
L7863:  .byte $80, $A5, $92, $BD, $C2

L22:
L7868:  .byte $BB, $1A, $4C, $10

Spanish:
L786C:  .byte $B8, $76, $62, $64, $0C, $12, $C6, $12
L7874:  .byte $B0, $5A, $B8, $4E, $9D, $AC, $49, $F1
L787C:  .byte $0D, $D2, $82, $4E, $C0

L32:
L7881:  .byte $56, $2C, $53, $59

L32_10:
L7885:  .byte $62, $48, $66, $D2, $6D, $18, $4E, $9B
L788D:  .byte $64, $09, $02, $A4, $0A, $EA, $6C, $B8
L7895:  .byte $00, $18, $4E, $9B, $64, $08, $C2, $A4
L789D:  .byte $0A, $EA, $6D, $20, $4E, $9B, $64, $B8
L78A5:  .byte $46, $0D, $20, $2F, $52, $B0, $00, $18
L78AD:  .byte $68, $81, $7A, $4D, $80, $20, $68, $81
L78B5:  .byte $7A, $4D, $AF, $0D, $2C, $4D, $EE, $0D
L78BD:  .byte $F0, $2D, $B1, $34, $E4, $CD, $C2, $4E
L78C5:  .byte $92, $B7, $43, $3C, $E2, $33, $64, $4A
L78CD:  .byte $02, $B9, $E6, $B2, $40, $94, $EC, $89
L78D5:  .byte $61, $8A, $50, $6E, $63, $20, $4E, $9B
L78DD:  .byte $64, $0C, $5A, $93, $62, $CC, $40, $2C
L78E5:  .byte $A6, $C3, $12, $B0, $4E, $9B, $65, $34
L78ED:  .byte $E4, $CD, $C2, $82, $74, $4C, $03, $11
L78F5:  .byte $1B, $25, $2F, $35, $39, $3F, $43, $49
L78FD:  .byte $53, $5D, $67, $79, $7F, $8D, $95, $9F
L7905:  .byte $18, $4E, $9B, $64, $09, $02, $59, $62
L790D:  .byte $4D, $C0, $18, $4E, $9B, $64, $08, $C2
L7915:  .byte $59, $62, $48, $00, $20, $4E, $9B, $64
L791D:  .byte $B8, $46, $0A, $CA, $8A, $40, $3D, $92
L7925:  .byte $43, $70, $B8, $40, $49, $6E, $E8, $00
L792D:  .byte $BA, $4E, $9C, $90, $B8, $00, $59, $62
L7935:  .byte $4D, $C0, $2E, $96, $0E, $1A, $8A, $6F
L793D:  .byte $54, $EC, $0D, $D2, $82, $82, $C2, $6E
L7945:  .byte $C0, $00, $C4, $C2, $3C, $12, $2D, $82
L794D:  .byte $B9, $E6, $B2, $6F, $C4, $C2, $3C, $12
L7955:  .byte $2D, $82, $C3, $62, $4D, $C0, $C4, $C2
L795D:  .byte $3C, $12, $2D, $82, $C3, $62, $4D, $C2
L7965:  .byte $2C, $90, $0D, $CE, $9D, $92, $B8, $00
L796D:  .byte $4D, $8A, $BB, $64, $58, $00, $A6, $6E
L7975:  .byte $60, $6E, $C1, $6C, $C0, $4A, $92, $02
L797D:  .byte $BA, $60, $49, $F1, $34, $E4, $CD, $C2
L7985:  .byte $2A, $10, $4D, $80, $C4, $F0, $2C, $02
L798D:  .byte $9C, $82, $C3, $62, $48, $00, $61, $6C
L7995:  .byte $40, $00, $15, $21, $27, $35, $4D, $65
L799D:  .byte $77, $85, $8B, $97, $A3, $B1, $B7, $BD
L79A5:  .byte $CB, $D3, $DD, $DD, $DD, $EB, $F9, $64
L79AD:  .byte $D2, $3B, $2E, $C2, $6C, $5A, $4C, $93
L79B5:  .byte $6E, $BA, $40, $BD, $1A, $4C, $12, $B0
L79BD:  .byte $40, $5D, $A6, $BD, $CA, $B6, $1A, $5A
L79C5:  .byte $6E, $0A, $6C, $5A, $4C, $93, $6F, $33
L79CD:  .byte $70, $C2, $42, $5A, $4C, $4C, $82, $BB
L79D5:  .byte $52, $0B, $58, $B2, $42, $6C, $9A, $C3
L79DD:  .byte $4A, $82, $64, $0A, $5A, $90, $00, $F6
L79E5:  .byte $6C, $09, $B2, $3B, $2E, $C1, $4C, $4C
L79ED:  .byte $B6, $2B, $20, $0D, $A6, $C1, $70, $48
L79F5:  .byte $50, $B6, $52, $3B, $D2, $90, $00, $53
L79FD:  .byte $6C, $48, $50, $B6, $52, $3B, $D2, $90
L7A05:  .byte $76, $4C, $A4, $0D, $9A, $3B, $30, $6A
L7A0D:  .byte $C0, $08, $42, $08, $6E, $A3, $52, $86
L7A15:  .byte $CA, $64, $02, $08, $42, $08, $00, $BD
L7A1D:  .byte $1A, $4C, $12, $92, $13, $18, $62, $CA
L7A25:  .byte $64, $F2, $42, $20, $6E, $A3, $52, $82
L7A2D:  .byte $6D, $18, $62, $CA, $64, $F2, $42, $18
L7A35:  .byte $6E, $A3, $52, $82, $6D, $20, $62, $CA
L7A3D:  .byte $64, $F2, $64, $08, $C2, $BD, $1A, $4C
L7A45:  .byte $12, $B0, $00, $18, $6E, $A3, $52, $82
L7A4D:  .byte $6D, $20, $6E, $A3, $52, $82, $6D, $BE
L7A55:  .byte $0A, $B6, $1E, $94, $E8, $50, $50, $B6
L7A5D:  .byte $52, $3B, $D2, $90, $00, $34, $E4, $CD
L7A65:  .byte $C2, $72, $50, $48, $40, $08, $70, $49
L7A6D:  .byte $62, $0D, $32, $93, $F0, $48, $40, $8B
L7A75:  .byte $64, $42, $6E, $C2, $64, $B8, $48, $0C
L7A7D:  .byte $72, $4C, $BC, $4C, $80, $08, $64, $99
L7A85:  .byte $D8, $0A, $5A, $92, $42, $8E, $52, $97
L7A8D:  .byte $92, $08, $00, $A6, $64, $7E, $3C, $2B
L7A95:  .byte $20, $4C, $82, $4D, $98, $9A, $58, $C0
L7A9D:  .byte $72, $88, $40, $04, $10, $1C, $28, $18
L7AA5:  .byte $62, $CA, $64, $F2, $42, $20, $6E, $A3
L7AAD:  .byte $52, $82, $40, $18, $62, $CA, $64, $F2
L7AB5:  .byte $42, $18, $6E, $A3, $52, $80, $00, $20
L7ABD:  .byte $62, $CA, $64, $F2, $64, $08, $C2, $BD
L7AC5:  .byte $1A, $4C, $00, $7D, $92, $43, $70, $48
L7ACD:  .byte $40, $00, $15, $1F, $25, $2F, $3F, $55
L7AD5:  .byte $6F, $7B, $85, $91, $9D, $A9, $AF, $B5
L7ADD:  .byte $C1, $CB, $D5, $D5, $D5, $E3, $EF, $8A
L7AE5:  .byte $5A, $84, $12, $CD, $AE, $0D, $CE, $9D
L7AED:  .byte $93, $74, $F2, $4E, $6C, $08, $00, $BD
L7AF5:  .byte $20, $4C, $90, $6A, $12, $0D, $CE, $9D
L7AFD:  .byte $93, $BE, $A8, $0A, $64, $C5, $92, $F0
L7B05:  .byte $74, $9D, $C2, $6C, $9A, $C3, $4A, $82
L7B0D:  .byte $6F, $A4, $F2, $BD, $D2, $F0, $6C, $9E
L7B15:  .byte $0A, $C2, $42, $A4, $F2, $B0, $74, $9D
L7B1D:  .byte $C2, $6C, $9A, $C3, $4A, $82, $6F, $A4
L7B25:  .byte $F2, $BD, $D2, $F0, $6E, $63, $52, $82
L7B2D:  .byte $2E, $0D, $72, $2C, $90, $0C, $12, $C6
L7B35:  .byte $2C, $48, $4E, $9D, $AC, $49, $F0, $48
L7B3D:  .byte $00, $08, $4E, $64, $DA, $E0, $50, $C8
L7B45:  .byte $5C, $4E, $42, $08, $40, $53, $64, $0A
L7B4D:  .byte $12, $0D, $0A, $B6, $1A, $48, $00, $18
L7B55:  .byte $68, $6A, $4E, $48, $48, $0B, $A6, $CA
L7B5D:  .byte $72, $B5, $C0, $18, $68, $6A, $4E, $48
L7B65:  .byte $46, $0B, $A6, $CA, $72, $B0, $00, $20
L7B6D:  .byte $68, $6A, $4E, $4D, $C2, $18, $5C, $9E
L7B75:  .byte $52, $CD, $80, $18, $5C, $9E, $52, $CD
L7B7D:  .byte $80, $20, $5C, $9E, $52, $CD, $AF, $2D
L7B85:  .byte $28, $CF, $52, $F0, $6E, $CD, $82, $BE
L7B8D:  .byte $0A, $B6, $00, $34, $E4, $CD, $C2, $3B
L7B95:  .byte $0A, $AE, $52, $08, $00, $B9, $E6, $B2
L7B9D:  .byte $42, $3C, $E2, $33, $64, $48, $00, $46
L7BA5:  .byte $52, $E0, $68, $6A, $4E, $4D, $C2, $8B
L7BAD:  .byte $64, $6C, $72, $88, $00, $0E, $64, $48
L7BB5:  .byte $4A, $CE, $2C, $48, $68, $6A, $4E, $48
L7BBD:  .byte $40, $08, $42, $08, $4C, $9C, $B2, $B8
L7BC5:  .byte $40, $04, $10, $1C, $28, $18, $68, $6A
L7BCD:  .byte $4E, $48, $48, $0B, $A6, $CA, $72, $B5
L7BD5:  .byte $C0, $18, $68, $6A, $4E, $48, $46, $0B
L7BDD:  .byte $A6, $CA, $72, $B0, $00, $20, $68, $6A
L7BE5:  .byte $4E, $4D, $C2, $18, $5C, $9E, $52, $CD
L7BED:  .byte $80, $3D, $92, $43, $70, $B8, $40, $15
L7BF5:  .byte $1D, $23, $2B, $3F, $59, $63, $6B, $75
L7BFD:  .byte $83, $8F, $9B, $A1, $A9, $B1, $B9, $C3
L7C05:  .byte $C3, $C3, $CF, $D7, $08, $6C, $49, $E6
L7C0D:  .byte $B2, $2E, $08, $40, $76, $56, $2A, $26
L7C15:  .byte $B0, $40, $5D, $8A, $90, $68, $CC, $B0
L7C1D:  .byte $2B, $93, $A4, $EC, $0A, $8A, $D4, $EC
L7C25:  .byte $0A, $64, $C5, $92, $0D, $F2, $B8, $5A
L7C2D:  .byte $93, $4E, $69, $60, $4D, $C0, $9D, $2C
L7C35:  .byte $6C, $4A, $0D, $A6, $C1, $70, $48, $68
L7C3D:  .byte $2D, $8A, $0D, $D2, $82, $4E, $3B, $66
L7C45:  .byte $91, $6C, $0C, $0A, $0C, $12, $C5, $8B
L7C4D:  .byte $9D, $2C, $6C, $4A, $0D, $D8, $6A, $60
L7C55:  .byte $45, $C0, $4C, $12, $5B, $6C, $0B, $B2
L7C5D:  .byte $4A, $E7, $76, $52, $5C, $C2, $C2, $6C
L7C65:  .byte $8B, $64, $2A, $27, $18, $54, $69, $D8
L7C6D:  .byte $28, $48, $0B, $B2, $59, $50, $9D, $92
L7C75:  .byte $B8, $00, $18, $54, $69, $D8, $28, $46
L7C7D:  .byte $0B, $B2, $59, $50, $9D, $80, $20, $54
L7C85:  .byte $69, $D8, $2D, $C2, $18, $5C, $CA, $CA
L7C8D:  .byte $44, $ED, $18, $5C, $CA, $CA, $44, $ED
L7C95:  .byte $20, $5C, $CA, $CA, $44, $EC, $4D, $C0
L7C9D:  .byte $A6, $60, $B9, $6C, $0D, $F0, $2D, $B1
L7CA5:  .byte $4F, $30, $B1, $42, $39, $50, $28, $40
L7CAD:  .byte $B9, $E6, $B2, $42, $42, $42, $2C, $4C
L7CB5:  .byte $9D, $C0, $44, $EE, $0A, $9A, $3B, $0A
L7CBD:  .byte $B8, $62, $6C, $9A, $8C, $C0, $0C, $F0
L7CC5:  .byte $B1, $42, $53, $4E, $61, $43, $93, $74
L7CCD:  .byte $4C, $02, $42, $42, $34, $E4, $6A, $9A
L7CD5:  .byte $3E, $1A, $9C, $80, $04, $10, $1A, $26
L7CDD:  .byte $18, $54, $69, $D8, $28, $48, $0B, $B2
L7CE5:  .byte $4A, $E6, $B8, $00, $18, $54, $69, $D8
L7CED:  .byte $28, $46, $0B, $B2, $4A, $E7, $20, $54
L7CF5:  .byte $69, $D8, $2D, $C2, $18, $5C, $CA, $56
L7CFD:  .byte $98, $00, $3D, $92, $43, $70, $9D, $C3
L7D05:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7D0D:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7D15:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7D1D:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7D25:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7D2D:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7D35:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7D3D:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7D45:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7D4D:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7D55:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7D5D:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7D65:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7D6D:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7D75:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7D7D:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7D85:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7D8D:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7D95:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7D9D:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7DA5:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7DAD:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7DB5:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7DBD:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7DC5:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7DCD:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7DD5:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7DDD:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7DE5:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7DED:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7DF5:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7DFD:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7E05:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7E0D:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7E15:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7E1D:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7E25:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7E2D:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7E35:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7E3D:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7E45:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7E4D:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7E55:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7E5D:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7E65:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7E6D:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7E75:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7E7D:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7E85:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7E8D:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7E95:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7E9D:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7EA5:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7EAD:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7EB5:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7EBD:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7EC5:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7ECD:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7ED5:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7EDD:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7EE5:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7EED:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7EF5:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7EFD:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7F05:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7F0D:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7F15:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7F1D:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7F25:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7F2D:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7F35:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7F3D:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7F45:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7F4D:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7F55:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7F5D:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7F65:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7F6D:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7F75:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7F7D:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7F85:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7F8D:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7F95:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7F9D:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7FA5:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7FAD:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7FB5:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7FBD:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7FC5:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7FCD:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7FD5:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7FDD:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7FE5:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7FED:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7FF5:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L7FFD:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L8005:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L800D:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L8015:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L801D:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L8025:  .byte $00, $00, $00, $00, $00, $00, $00

InitialInitials:
L802C:  .byte $0A

Ininitls:
L802D:  .byte $00, $00, $00, $19, $1C, $1C, $1D, $1C
L8035:  .byte $0D, $0E, $0F, $1D, $14, $17, $1C, $16
L803D:  .byte $20, $1C

Poweron:
L803F:  SEI
L8040:  LDX  #$FE                   ;C  INIT STACKF
L8042:  TXS
L8043:  LDA  #$00
L8045:  STA  STOPAD                 ;C RESET VEC GEN
L8048:  CLD
L8049:  TAX
L804A:  STA  VGBRIT,X
L804C:  STA  $0100,X
L804F:  STA  XINC,X
L8052:  STA  $0300,X
L8055:  STA  VECMEM,X
L8058:  STA  $2100,X
L805B:  STA  $2200,X
L805E:  STA  PL0SET,X
L8061:  STA  $2400,X
L8064:  STA  $2500,X
L8067:  STA  $2600,X
L806A:  STA  SH0XPCOORD,X
L806D:  STA  POKEY,X
L8070:  STA  POKEY2,X
L8073:  STA  WTCHDG
L8076:  INX
L8077:  BNE  L804A
L8079:  LDA  #$C0
L807B:  STA  OUT1
L807E:  LDA  #$07
L8080:  STA  $100F                  ;TURN ON POKEY
L8083:  STA  $140F
L8086:  LDA  HALT                   ;D  IF SELF TEST
L8089:  AND  #$10
L808B:  BNE  L8090
L808D:  JMP  BeginningPattern
L8090:  LDA  #$01                   ;C  INIT VG BUFFER
L8092:  STA  VECMEM
L8095:  LDA  #$E4
L8097:  STA  $2001
L809A:  LDA  #$20
L809C:  STA  $2003
L809F:  STA  $2403
L80A2:  LDA  CABERE
L80A5:  STA  UPDOWN                 ;INIT UPDOWN OUTPUT POINTER
L80A8:  JSR  SetUpInitialsHigh      ;MOVE IN INITIALS

StartThingsRunning:
L80AB:  CLI                         ;START THINGS RUNNING
L80AC:  LDX  #$60                   ;EAROM WARM UP WAIT COUNTER
L80AE:  LSR  SYNC
L80B0:  BCC  L80AE
L80B2:  STA  WTCHDG                 ;KEEP THING RUNNING
L80B5:  DEX
L80B6:  BPL  L80AE
L80B8:  JSR  ReadEverything         ;READ EA ROM INTO BUFFER
L80BB:  LDA  EAFLG                  ;STILL READING IN?
L80BE:  STA  WTCHDG
L80C1:  BNE  L80BB
L80C3:  LDA  EABAD                  ;DATA OK?
L80C6:  LSR                         ;BIT 0
L80C7:  BCS  L80CE
L80C9:  PHA
L80CA:  JSR  CopyFromBufferBack     ;MOVE TO DISPLAY AREA
L80CD:  PLA
L80CE:  JSR  CopyOntimeFromBuffer   ;MOVE REST DOWN
L80D1:  JMP  Pwron

SetUpInitialsHigh:
L80D4:  LDY  #$3C
L80D6:  LDX  #$0E
L80D8:  LDA  Ininitls,X
L80DB:  STA  $0118,Y
L80DE:  LDA  #$00
L80E0:  STA  ATSTG,Y
L80E3:  DEY
L80E4:  DEX
L80E5:  LDA  #$05
L80E7:  STA  ATSTG,Y
L80EA:  LDA  Ininitls,X
L80ED:  STA  $0118,Y
L80F0:  DEY
L80F1:  DEX
L80F2:  LDA  Ininitls,X
L80F5:  STA  $0118,Y
L80F8:  LDA  #$00
L80FA:  STA  ATSTG,Y
L80FD:  DEY
L80FE:  DEX
L80FF:  BPL  L80D8
L8101:  TYA                         ;SET STATUS
L8102:  BNE  L80D6
L8104:  LDX  #$0E
L8106:  LDA  Ininitls,X
L8109:  STA  SPINT,X
L810C:  DEX
L810D:  BPL  L8106
L810F:  RTS

BeginningPattern:
L8110:  LDX  #$11                   ;BEGINNING PATTERN
L8112:  TXS                         ;S HOLDS PATTERN
L8113:  TXA
L8114:  STX  VGBRIT                 ;TEST CELL START @ 0
L8116:  LDY  #$00

BeginningPattern_2:
L8118:  LDX  #$01                   ;ONE LESS COUNT BEFORE IT WRAPS

BeginningPattern_3:
L811A:  INY                         ;SCAN FORWARD
L811B:  LDA  VGBRIT,Y               ;ZERO ?
L811E:  BNE  BeginningPattern_5     ;NO - ERROR (HIGH BITS BAD)
L8120:  INX                         ;CHK HOW FAR SCANNED
L8121:  BNE  BeginningPattern_3     ;BRANCH - CONTINUE
L8123:  TSX
L8124:  TXA                         ;ACC = PATTERN
L8125:  STA  WTCHDG                 ;WTCHDGDOG
L8128:  INY                         ;POINT TO TEST CELL
L8129:  EOR  VGBRIT,Y               ;DOES IT HAVE PATTERN ?
L812C:  BNE  BeginningPattern_5     ;N0 - ERROR (HIGH BITS BAD)
L812E:  TXA                         ;ACC = PATTERN
L812F:  LDX  #$00
L8131:  STX  VGBRIT,Y               ;ELSE - CLEAR CELL
L8133:  INY                         ;POINT TO NEXT TEST CELL
L8134:  BNE  BeginningPattern_4     ;IF PASS NOT COMPLETE
L8136:  ASL                         ;ELSE SHIFT PATTERN
L8137:  LDX  #$00                   ;IF DONE (0 = GOOD)
L8139:  BCS  Stop0                  ;BRANCH - DONE (GOOD)

BeginningPattern_4:
L813B:  TAX                         ;PATTERN -> X
L813C:  TXS                         ;-> S
L813D:  STX  VGBRIT,Y               ;-> NEXT TEST CELL
L813F:  BNE  BeginningPattern_2     ;ALWAYS - REPEAT SCAN

BeginningPattern_5:
L8141:  TAX                         ;ANY HIGH BITS INDICATE BAD RAM

BeginningPattern_7:
L8142:  TXA
L8143:  LDY  #$82                   ;ASSUME LOW NIBBLE IS GOOD
L8145:  AND  #$0F                   ;CHECK IT
L8147:  BEQ  BeginningPattern_8     ;BRANCH - LOW NIBBLE GOOD
L8149:  LDY  #$12                   ;ELSE - SET Y ACCORDINGLY

BeginningPattern_8:
L814B:  TXA
L814C:  LDX  #$82                   ;ASSUME TOP NIBBLE IS GOOD
L814E:  AND  #$F0                   ;CHECK IT
L8150:  BEQ  BeginningPattern_9     ;BRANCH - TOP NIBBLE GOOD
L8152:  LDX  #$12                   ;ELSE - SET X

BeginningPattern_9:
L8154:  TYA
L8155:  TXS                         ;S = HIGH NIBBLE STATUS
L8156:  TAX                         ;X = LOW

NoiseLowerNibbleStatus:
L8157:  STX  POKEY                  ;NOISE = LOWER NIBBLE STATUS
L815A:  LDX  #$A8
L815C:  STX  $1001
L815F:  LDY  #$0C                   ;Y = HIGH BYTE OF COUNTER

NoiseLowerNibbleStatus_10:
L8161:  LDX  #$64                   ;X = LOW BYTE OF COUNTER

NoiseLowerNibbleStatus_11:
L8163:  BIT  HALT
L8166:  BMI  NoiseLowerNibbleStatus_11 ;BIT 7 (SIGN FLAG) OF HALT = 3000 HZ SQUARE WAVE

NoiseLowerNibbleStatus_12:
L8168:  BIT  HALT
L816B:  BPL  NoiseLowerNibbleStatus_12
L816D:  STA  WTCHDG
L8170:  DEX
L8171:  BNE  NoiseLowerNibbleStatus_11 ;INNER LOOP 255 * 333 US = 85 MS
L8173:  CPY  #$05
L8175:  BNE  NoiseLowerNibbleStatus_13
L8177:  STX  $1001                  ;CLR NOISE

NoiseLowerNibbleStatus_13:
L817A:  DEY
L817B:  BNE  NoiseLowerNibbleStatus_10 ;OUTER LOOP 8 *  85 MS = 580 MS
L817D:  LSR                         ;TEST SIGN
L817E:  BCS  NoiseLowerNibbleStatus_14 ;DONE
L8180:  TSX
L8181:  BNE  NoiseLowerNibbleStatus ;ALWAYS

NoiseLowerNibbleStatus_14:
L8183:  JMP  NoWtchdgdog            ;WAIT FOR SWITCH

Stop0:
L8186:  LDX  #$FF
L8188:  TXS                         ;INITIALIZE STACK (USED IN ROM TESTS)
L8189:  LDX  #$00
L818B:  TXA

Stop0_10:
L818C:  STA  VGBRIT,X               ;ZERO ZERO-PAGE
L818E:  INX
L818F:  BNE  Stop0_10

L04:
L8191:  TAY                         ;Y=0
L8192:  LDA  #$01

L04_5:
L8194:  STA  VGLIST                 ;START @ PAGE 1 (NY,0)

L04_10:
L8196:  LDX  #$11                   ;STARTING PATTERN
L8198:  LDA  (VGBRIT),Y             ;D  IF BAD CELL
L819A:  BNE  L04_20

L04_15:
L819C:  TXA

L04_16:
L819D:  STA  (VGBRIT),Y             ;WRITE
L819F:  EOR  (VGBRIT),Y             ;AND COMPARE
L81A1:  BNE  L04_20                 ;ERROR
L81A3:  TXA
L81A4:  ASL
L81A5:  TAX
L81A6:  BCC  L04_16                 ;NEXT PATTERN
L81A8:  INY
L81A9:  BNE  L04_10                 ;NEXT LOCATION
L81AB:  STA  WTCHDG                 ;MUZZLE THAT BEAST
L81AE:  INC  VGLIST
L81B0:  LDX  VGLIST
L81B2:  CPX  #$04                   ;PAGES 1 TO 3
L81B4:  BCC  L04_10                 ;CHECK NEXT PAGE
L81B6:  LDA  #$20
L81B8:  CPX  #$20
L81BA:  BCC  L04_5                  ;BEGIN NEXT @ 2000
L81BC:  CPX  #$28
L81BE:  BCC  L04_10                 ;CHECK UP TO 27FF
L81C0:  JMP  EorCksumRoms           ;RAM IS GOOD

L04_20:
L81C3:  LDX  VGLIST                 ;X = MSB (ADDRESS) ACC=BAD PATTERN
L81C5:  CPX  #$20
L81C7:  STA  EAC2                   ;BAD PATTERN
L81C9:  BCC  L04_30
L81CB:  TXA
L81CC:  SBC  #$1C

L04_30:
L81CE:  LSR
L81CF:  LSR
L81D0:  AND  #$07
L81D2:  TAY                         ;Y = # OF 1K BLOCK BAD
L81D3:  LDA  EAC2

L0BadRam:
L81D5:  STY  VGBRIT                 ;0 = BAD RAM #
L81D7:  STA  VGLIST                 ;1 = BAD BITS

L0BadRam_5:
L81D9:  LDA  #$01
L81DB:  STA  EAC2

L0BadRam_10:
L81DD:  LDX  #$A8
L81DF:  LDY  #$82                   ;ASSUME GOOD RAM
L81E1:  LDA  VGBRIT
L81E3:  BNE  L0BadRam_30            ;IT IS
L81E5:  LDA  VGLIST
L81E7:  AND  #$0F                   ;LOW NIBBLE
L81E9:  BEQ  L0BadRam_30            ;GOOD

L0BadRam_20:
L81EB:  LDY  #$12                   ;BAD

L0BadRam_30:
L81ED:  STX  $1001                  ;TONE/VOLUME
L81F0:  STY  POKEY                  ;FREQUENCY
L81F3:  LDA  #$09                   ;BAD
L81F5:  CPY  #$12
L81F7:  BEQ  L0BadRam_35            ;YES
L81F9:  LDA  #$01

L0BadRam_35:
L81FB:  TAY
L81FC:  LDX  #$00

L0BadRam_40:
L81FE:  BIT  HALT
L8201:  BMI  L0BadRam_40

L0BadRam_42:
L8203:  BIT  HALT
L8206:  BPL  L0BadRam_42
L8208:  STA  WTCHDG                 ;NO WTCHDGIN' DOG
L820B:  DEX
L820C:  BNE  L0BadRam_40            ;COUNT 256/3000 OF A SECOND
L820E:  DEY
L820F:  BNE  L0BadRam_40
L8211:  STX  $1001                  ;CLR SOUND
L8214:  LDY  #$09

L0BadRam_50:
L8216:  BIT  HALT
L8219:  BMI  L0BadRam_50

L0BadRam_52:
L821B:  BIT  HALT
L821E:  BPL  L0BadRam_52
L8220:  STA  WTCHDG                 ;NO WTCHDGDOG
L8223:  DEX
L8224:  BNE  L0BadRam_50            ;256/3000
L8226:  DEY
L8227:  BNE  L0BadRam_50
L8229:  LDA  VGBRIT
L822B:  BNE  L0BadRam_60
L822D:  LDA  VGLIST
L822F:  LSR
L8230:  LSR
L8231:  LSR
L8232:  LSR
L8233:  STA  VGLIST

L0BadRam_60:
L8235:  DEC  EAC2
L8237:  BEQ  L0BadRam_10
L8239:  DEC  VGBRIT
L823B:  BPL  L0BadRam_5             ;ALWAYS

NoWtchdgdog:
L823D:  STA  WTCHDG                 ;NO WTCHDGDOG
L8240:  LDA  #$FF
L8242:  STA  COCKBI                 ;BAD RAM

EorCksumRoms:
L8244:  LDA  #$00                   ;EOR CKSUM ROMS
L8246:  TAX
L8247:  STA  $0100,X
L824A:  STA  XINC,X
L824D:  STA  $0300,X                ;CLEAR RAM
L8250:  DEX
L8251:  BNE  L8247
L8253:  TAY
L8254:  STA  TEMP1
L8256:  LDA  #$30                   ;WILL DO 2800 AS SPECIAL CASE....
L8258:  STA  EACE
L825A:  LDA  #$10

EorCksumRoms_6:
L825C:  STA  TEMP2                  ;# PAGES
L825E:  TXA                         ;SEED FOR CKSUM
L825F:  EOR  (TEMP1),Y
L8261:  INY
L8262:  BNE  L825F
L8264:  INC  EACE
L8266:  STA  WTCHDG                 ;NO WTCHDGDOG
L8269:  DEC  TEMP2
L826B:  BNE  L825F
L826D:  STA  $F1,X                  ;CKSUMS (SPACE LEFT FOR 2800))
L826F:  INX
L8270:  BEQ  JustLabel              ;IF 0, WAS SPECIAL CASE 2800
L8272:  LDA  EACE
L8274:  CMP  #$40                   ;6K OF VECROM
L8276:  BNE  L827C
L8278:  LDA  #$40
L827A:  STA  EACE
L827C:  CMP  #$90                   ;UP TO 9000
L827E:  BCC  L8258
L8280:  LDX  #$FF                   ;WANT CHECKSUM AT PROPER LOCATION
L8282:  LDA  #$28
L8284:  STA  EACE                   ;START LOCATION
L8286:  LDA  #$08                   ;ONLY 8 PAGES HERE
L8288:  BNE  EorCksumRoms_6         ;********ALWAYS************

JustLabel:
L828A:  LDA  BGSHEN
L828C:  ORA  $F1                    ;ANY VGROM ERROR?
L828E:  BEQ  Stest4
L8290:  LDA  #$F0                   ;IF YES, SOUND OFF
L8292:  LDX  #$A2
L8294:  STA  $1004
L8297:  STX  $1005

Stest4:
L829A:  LDX  #$05
L829C:  LDA  $100A
L829F:  CMP  $100A                  ;MAKE SURE ITS RUNNING
L82A2:  BNE  Ok1_82A9               ;YES -- RANDOM #'S DIFFERENT
L82A4:  DEX                         ;ELSE CHECK 5 TIMES
L82A5:  BPL  L829F
L82A7:  STA  $81                    ;BAD POKEY1

Ok1_82A9:
L82A9:  LDX  #$05
L82AB:  LDA  $140A
L82AE:  CMP  $140A
L82B1:  BNE  Ok2
L82B3:  DEX
L82B4:  BPL  L82AE
L82B6:  STA  $82                    ;BAD POKEY

Ok2:
L82B8:  CLI
L82B9:  JSR  ReadEverything         ;READ EAROM
L82BC:  LDY  #$02                   ;DEFAULT GOOD
L82BE:  LDA  EABAD                  ;ERROR??
L82C1:  BEQ  L82CD
L82C3:  STA  $83                    ;BAD EAROM
L82C5:  JSR  Eazero                 ;CLEAR IT IF BAD
L82C8:  LDY  #$00
L82CA:  STY  EABAD
L82CD:  STY  $A0                    ;WHICH STATE FIRST?
L82CF:  JMP  MainLineDiagLoop       ;DO DIAG MAIN LINE

Stest5:
L82D2:  LDA  EAFLG
L82D5:  ORA  EAREQU
L82D8:  .byte $D0, $0C
L82DA:  JSR  ReadEverything         ;TRY ANOTHER READ
L82DD:  LDA  EABAD
L82E0:  STA  $83                    ;STILL BAD? (REPORT)
L82E2:  LDA  #$02
L82E4:  STA  $A0                    ;GO STRAIGHT TO REPORT
L82E6:  RTS

Cocktail:
L82E7:  BIT  CABERE                 ;COCKTAIL??
L82EA:  .byte $10, $05
L82EC:  LDA  #$00
L82EE:  STA  OUT1
L82F1:  LDY  #$A7
L82F3:  JSR  SetVectorGeneratorStatus
L82F6:  .byte $A9, $61, $A2, $AF
L82FA:  JSR  Add2WordsToVector
L82FD:  LDA  #$B0
L82FF:  LDX  #$F0
L8301:  JSR  UpdownVectorUpsideDown
L8304:  LDA  #$00                   ;SCALE 0
L8306:  JSR  UseFullSize            ;BIG NUMBERS
L8309:  JSR  Optn2                  ;OUTPUT OPTION SWITCHES
L830C:  LDA  #$01
L830E:  JSR  SetVectorGeneratorScale ;RETURN TO NORMAL SCALE
L8311:  LDX  #$46
L8313:  STX  POTGO                  ;STARTING Y VALUE CHECK SUMS
L8315:  LDX  #$06
L8317:  LDA  BGSHEN,X
L8319:  .byte $F0, $2A
L831B:  STX  TEMP2                  ;SAVE CHKSUM #
L831D:  JSR  CenterBeamInMiddle     ;CENTER BEAM
L8320:  LDX  POTGO
L8322:  TXA
L8323:  SEC
L8324:  SBC  #$08                   ;32. BELOW CURRENT LINE
L8326:  STA  POTGO
L8328:  LDA  #$F6
L832A:  JSR  UpdownVectorUpsideDown ;POSITION BEAM
L832D:  LDA  TEMP2
L832F:  JSR  DisplayDigit           ;ROM #
L8332:  LDA  #$06
L8334:  LDX  #$00
L8336:  JSR  UpdownVectorUpsideDown
L8339:  LDA  TEMP2
L833B:  CLC
L833C:  ADC  #$F0
L833E:  LDY  #$01
L8340:  JSR  SaveInpuParameers      ;DISPLAY 2 DIGITS
L8343:  LDX  TEMP2
L8345:  DEX
L8346:  .byte $10, $CF
L8348:  JSR  CenterBeamInMiddle
L834B:  LDA  #$F6
L834D:  LDX  #$50
L834F:  JSR  UpdownVectorUpsideDown ;POSITION FOR ERROR LIST
L8352:  LDX  #$03
L8354:  STX  TEMP2
L8356:  LDX  TEMP2
L8358:  LDY  #$00
L835A:  LDA  COCKBI,X               ;ANY BAD NEWS?
L835C:  .byte $F0, $03
L835E:  LDY  Badnws,X
L8361:  LDA  $324A,Y
L8364:  LDX  $324B,Y                ;GET LETTER
L8367:  JSR  Add2WordsToVector
L836A:  DEC  TEMP2
L836C:  .byte $10, $E8
L836E:  JSR  Swtst                  ;BEEP ON SWITCH CLOSURE
L8371:  RTS

Stest7:
L8372:  .byte $A9, $76, $A2, $AA
L8376:  JMP  Add2WordsToVector

Stest8:
L8379:  LDA  $A1
L837B:  AND  #$3F
L837D:  .byte $D0, $02
L837F:  INC  TEMP3
L8381:  LDA  TEMP3
L8383:  AND  #$07
L8385:  TAX
L8386:  LDY  $83B8,X
L8389:  LDA  #$00
L838B:  STA  $13F1,Y
L838E:  LDY  SoundTableLo,X
L8391:  LDA  Sndfrq,X
L8394:  STA  $13F0,Y                ;FAKE POKEY ADDRESS
L8397:  LDA  #$A8
L8399:  STA  $13F1,Y
L839C:  .byte $A9, $79, $A2, $AA
L83A0:  JSR  Add2WordsToVector
L83A3:  JSR  CenterBeamInMiddle
L83A6:  LDA  TEMP3
L83A8:  AND  #$07
L83AA:  .byte $D0, $02
L83AC:  LDA  #$01                   ;DON'T ALOW 0
L83AE:  JSR  UseFullSize            ;TEST SCALE
L83B1:  .byte $A9, $63, $A2, $A8
L83B5:  JMP  Add2WordsToVector
L83B8:  .byte $16

SoundTableLo:
L83B9:  .byte $00, $10, $02, $12, $04, $14, $06, $16
L83C1:  .byte $00

Sndfrq:
L83C2:  .byte $10, $10, $40, $40, $90, $90, $FF, $FF

SetScale1:
L83CA:  LDA  #$01                   ;SET SCALE 1
L83CC:  JSR  UseFullSize            ;SET SCALE
L83CF:  LDY  #$06
L83D1:  STY  TEMP3
L83D3:  JSR  CenterBeamInMiddle     ;CENTER
L83D6:  LDY  TEMP3
L83D8:  LDA  PositionBars,Y         ;POSITION THIS GROUP
L83DB:  LDX  Position,Y
L83DE:  JSR  UpdownVectorUpsideDown
L83E1:  LDA  TEMP3
L83E3:  EOR  #$FF
L83E5:  AND  #$07
L83E7:  TAY
L83E8:  JSR  SetVectorGeneratorStatus
L83EB:  LDA  TEMP3                  ;WHITE GROUP?
L83ED:  .byte $D0, $07, $A9, $57, $A2, $AA, $4C, $FA
L83F5:  .byte $83, $A9, $54, $A2, $AA
L83FA:  JSR  Add2WordsToVector
L83FD:  DEC  TEMP3
L83FF:  .byte $10, $D2

LastWhite:
L8401:  .byte $A9, $66, $A2, $AA
L8405:  JSR  Add2WordsToVector
L8408:  RTS

DollarMechMultipliers:
L8409:  .byte $01, $04, $05, $06

PositionBars:
L840D:  .byte $DE, $9D, $1F, $9D, $DE, $1F, $DE

Position:
L8414:  .byte $F4, $D8, $D8, $10, $D8, $10, $10

Badnws:
L841B:  .byte $38, $34, $36, $1E

Stst10:
L841F:  JSR  CenterBeamInMiddle
L8422:  LDA  #$01
L8424:  JSR  UseFullSize
L8427:  LDX  #$07                   ;NINE BARS HORIZ
L8429:  STX  TEMP2
L842B:  JSR  CenterBeamInMiddle
L842E:  LDY  TEMP2
L8430:  LDA  #$80
L8432:  LDX  Hlpos,Y
L8435:  JSR  UpdownVectorUpsideDown ;POSITION FOR THIS LINE
L8438:  .byte $A9, $72, $A2, $AA
L843C:  JSR  Add2WordsToVector
L843F:  DEC  TEMP2
L8441:  .byte $10, $EB
L8443:  LDX  #$0B                   ;THIRTEEN BARS VERT
L8445:  STX  TEMP2
L8447:  LDY  TEMP2
L8449:  LDA  Vlpos,Y
L844C:  LDX  #$60
L844E:  JSR  UpdownVectorUpsideDown
L8451:  .byte $A9, $6E, $A2, $AA
L8455:  JSR  Add2WordsToVector
L8458:  DEC  TEMP2
L845A:  .byte $10, $EB
L845C:  LDA  GAMSEL
L845F:  .byte $10, $09
L8461:  ASL  TEMPA                  ;DEBOUNCE COLOR SWITCH
L8463:  .byte $90, $02
L8465:  INC  TEMP8                  ;NEXT COLOR
L8467:  .byte $4C, $6E, $84
L846A:  LDA  #$20                   ;RESET NOT PUSHED
L846C:  STA  TEMPA
L846E:  RTS

Hlpos:
L846F:  .byte $B6, $CB, $E0, $F6, $0A, $20, $35, $4A

Vlpos:
L8477:  .byte $94, $A8, $BB, $CF, $E3, $F6, $0A, $1D
L847F:  .byte $31, $45, $58, $6C

CenterBeam:
L8483:  JSR  CenterBeamInMiddle     ;CENTER BEAM
L8486:  LDA  #$FB
L8488:  LDX  #$4D
L848A:  JSR  UpdownVectorUpsideDown ;POSITION BEAM
L848D:  LDA  #$01
L848F:  JSR  DisplayDigit           ;1 FOR LEFT COIN MECH
L8492:  STA  $140B
L8495:  LDA  $1408                  ;READ 'OPTN3'
L8498:  STA  ZMINE
L849A:  AND  #$10
L849C:  LSR
L849D:  LSR
L849E:  LSR
L849F:  LSR                         ;0 OR 1
L84A0:  ADC  #$01                   ;1 OR 2
L84A2:  JSR  DisplayDigit           ;PUT CENTER MECH VALUE
L84A5:  STA  $140B
L84A8:  LDA  $1408                  ;READ 'OPTN3'
L84AB:  AND  #$0C
L84AD:  LSR
L84AE:  LSR
L84AF:  TAX
L84B0:  LDA  DollarMechMultipliers,X
L84B3:  JSR  DisplayDigit           ;DOLLAR MECH VALUE
L84B6:  LDA  #$C6
L84B8:  LDX  #$EE
L84BA:  JSR  UpdownVectorUpsideDown ;POSITION FOR NEXT LINE
L84BD:  LDA  #$FF
L84BF:  STA  TEMP3                  ;FLAG FOR POSITION

Optn2:
L84C1:  LDX  #$0F
L84C3:  STX  TEMP2
L84C5:  STA  $100B                  ;READ OPTN1
L84C8:  LDA  $1008
L84CB:  STA  POTGO
L84CD:  STA  $140B
L84D0:  LDA  $1408                  ;READ 'OPTN3'
L84D3:  PHA
L84D4:  AND  #$01
L84D6:  JSR  DisplayDigit           ;DISPLAY 0 OR 1
L84D9:  LSR  POTGO
L84DB:  PLA
L84DC:  ROR
L84DD:  DEC  TEMP2
L84DF:  BPL  L84D3
L84E1:  LDY  #$9F                   ;GUESS MAIN TEST
L84E3:  BIT  TEMP3
L84E5:  BPL  L84E9
L84E7:  LDY  #$9E
L84E9:  TYA
L84EA:  LDX  #$F8                   ;POSITION FOR NEXT LINE
L84EC:  JSR  UpdownVectorUpsideDown
L84EF:  LDX  #$07                   ;DO ALL OTHER SWITCHES
L84F1:  STX  TEMP2
L84F3:  LDX  TEMP2
L84F5:  LDA  HYPSW,X
L84F8:  ROL
L84F9:  ROL                         ;LOOK AT FIRST BIT
L84FA:  PHP                         ;SAVE COPY OF CARRY
L84FB:  AND  #$01
L84FD:  JSR  DisplayDigit
L8500:  PLP
L8501:  ROL
L8502:  AND  #$01
L8504:  JSR  DisplayDigit
L8507:  DEC  TEMP2
L8509:  BPL  L84F3
L850B:  LDY  #$9F
L850D:  BIT  TEMP3
L850F:  BPL  L8513
L8511:  LDY  #$9E
L8513:  TYA
L8514:  LDX  #$F8
L8516:  JSR  UpdownVectorUpsideDown ;POSITION FOR NEXT LINE
L8519:  LDX  #$05
L851B:  STX  TEMP2
L851D:  LDA  HALT                   ;REMAINING SWITCHES
L8520:  AND  #$3F                   ;BIT 6 AND 7 DONT CARE
L8522:  PHA
L8523:  AND  #$01
L8525:  JSR  DisplayDigit
L8528:  PLA
L8529:  ROR
L852A:  DEC  TEMP2
L852C:  BPL  L8522
L852E:  LDX  #$09                   ;FILL REST WITH 'X'
L8530:  STX  TEMP2
L8532:  LDA  #$22
L8534:  JSR  SaveCFlag
L8537:  DEC  TEMP2
L8539:  BPL  L8532
L853B:  RTS

Swtst:
L853C:  LDX  #$03
L853E:  LDY  #$00
L8540:  STY  TEMPA
L8542:  LDA  HYPSW,X
L8545:  ASL
L8546:  ROL  TEMPA
L8548:  ASL
L8549:  ROL  TEMPA
L854B:  DEX
L854C:  BPL  L8542
L854E:  LDA  TEMPA
L8550:  BEQ  L8559
L8552:  ADC  #$40
L8554:  STA  POKEY
L8557:  LDY  #$A4
L8559:  STY  $1001
L855C:  LDY  #$00
L855E:  STY  TEMPA
L8560:  LDA  STRT1                  ;BOTH BITS HERE
L8563:  ASL
L8564:  ROL  TEMPA
L8566:  ASL
L8567:  ROL  TEMPA
L8569:  ASL  OPTNA1
L856C:  ROL  TEMPA
L856E:  ASL  GAMSEL                 ;ONLY BIT 7 HERE
L8571:  ROL  TEMPA
L8573:  LDA  HALT
L8576:  EOR  #$FF                   ;BACKWARDS
L8578:  LSR
L8579:  ROL  TEMPA
L857B:  LSR
L857C:  ROL  TEMPA
L857E:  LSR
L857F:  ROL  TEMPA
L8581:  LDA  TEMPA
L8583:  BEQ  L858C
L8585:  ADC  #$40
L8587:  STA  $1002
L858A:  LDY  #$A4
L858C:  STY  $1003
L858F:  RTS

MainLineDiagLoop:
L8590:  LDX  #$18
L8592:  BIT  HALT                   ;16MS WAIT
L8595:  BPL  L8592
L8597:  BIT  HALT
L859A:  BMI  L8597
L859C:  DEX
L859D:  BPL  L8592
L859F:  INC  $A1
L85A1:  BIT  HALT                   ;STOPPED?
L85A4:  BVC  L85A1

ReloadVector:
L85A6:  LDA  #$00                   ;RELOAD VG
L85A8:  STA  VGLIST
L85AA:  LDA  #$20
L85AC:  STA  EAC2
L85AE:  LDA  HALT
L85B1:  EOR  #$FF
L85B3:  AND  #$28                   ;SWITCH PUSHED?
L85B5:  BEQ  L85DB
L85B7:  ASL  TEMP9
L85B9:  BCC  L85D8
L85BB:  LDA  GAMSEL
L85BE:  BPL  L85C6
L85C0:  JSR  Inisou                 ;SOUND OFF
L85C3:  JMP  L8D33                  ;GONE TO SIG ANAL NOT TO RETURN
L85C6:  INC  $A0
L85C8:  INC  $A0                    ;NEXT TEST
L85CA:  LDA  #$00
L85CC:  LDX  #$06
L85CE:  STA  $1001,X
L85D1:  STA  $1401,X
L85D4:  DEX
L85D5:  DEX
L85D6:  BPL  L85CE
L85D8:  JMP  L85DF
L85DB:  LDA  #$20
L85DD:  STA  TEMP9                  ;NOT PRESSED, RESTART TIMER
L85DF:  LDA  $A0
L85E1:  CMP  #$0A                   ;SPECIAL COLORS HERE
L85E3:  BNE  L85F3
L85E5:  LDA  TEMP8
L85E7:  AND  #$07
L85E9:  BNE  L85ED
L85EB:  LDA  #$01
L85ED:  ORA  #$C0                   ;INTENSITY
L85EF:  TAY
L85F0:  JMP  L85F5
L85F3:  LDY  #$A7                   ;PUT UP WHITE BOX
L85F5:  JSR  SetVectorGeneratorStatus
L85F8:  LDA  #$62
L85FA:  LDX  #$A8
L85FC:  JSR  Add2WordsToVector      ;DO BOX
L85FF:  JSR  Sftjse                 ;DO THIS ROUTINE
L8602:  JSR  CenterBeamInMiddle
L8605:  JSR  AddHaltToVector        ;CENTER AND HALT
L8608:  STA  GOADD                  ;START DISPLAY
L860B:  STA  WTCHDG
L860E:  LDA  HALT                   ;STILL SELF TEST?
L8611:  AND  #$10
L8613:  BNE  WatchDogResetExit
L8615:  JMP  MainLineDiagLoop

WatchDogResetExit:
L8618:  BNE  WatchDogResetExit      ;WATCH-DOG RESET FOR EXIT

Sftjsr:
L861A:  CMP  ($82),Y
L861C:  INC  $82
L861E:  ADC  ($83),Y
L8620:  SEI
L8621:  .byte $83, $C9, $83, $1E, $84

Sftjse:
L8626:  LDX  $A0
L8628:  CPX  #$0C                   ;NON VALID STATE?
L862A:  BCC  L8630
L862C:  LDX  #$02
L862E:  STX  $A0                    ;START OVER
L8630:  LDA  $861B,X
L8633:  PHA
L8634:  LDA  Sftjsr,X
L8637:  PHA
L8638:  RTS                         ;RTS (JUMP CASE)

Irq:
L8639:  PHA
L863A:  TYA
L863B:  PHA
L863C:  TXA
L863D:  PHA
L863E:  CLD
L863F:  STA  INTACK
L8642:  DEC  INTRPT
L8644:  LDA  INTRPT
L8646:  AND  #$0F
L8648:  BNE  Irq_2
L864A:  JSR  OutputEaromErasedWritten ;EAROM UPDATE CHECK
L864D:  LDA  INTRPT                 ;RELOAD

Irq_2:
L864F:  AND  #$03
L8651:  BNE  Irq_3
L8653:  INC  SYNC

Irq_3:
L8655:  LDA  LANGBT
L8657:  BMI  Irq_4                  ;NO COIN ROUTINE
L8659:  LDA  HALT
L865C:  AND  #$10
L865E:  BEQ  Irq_4                  ;NOT IF TEST
L8660:  JSR  L741A

Irq_4:
L8663:  LDA  INTRPT
L8665:  BNE  Irq_5                  ;ANOTHER SECOND
L8667:  INC  SECOND
L866A:  LDA  SECOND
L866D:  AND  #$03
L866F:  BNE  Irq_5                  ;4 SECOND PAST
L8671:  CLC
L8672:  SED                         ;*****WARNING--DECIMAL MODE************
L8673:  LDA  ATRACT                 ;GAME ON?
L8675:  BMI  Irq_6                  ;STOP ONTIME DURING GAME TIME TO
L8677:  LDA  ONTIME
L867A:  ADC  #$01                   ;ADD A COUNT
L867C:  STA  ONTIME
L867F:  LDA  $018F
L8682:  ADC  #$00
L8684:  STA  $018F
L8687:  LDA  $0190
L868A:  ADC  #$00
L868C:  STA  $0190
L868F:  LDA  $0191
L8692:  ADC  #$00
L8694:  STA  $0191
L8697:  CLC

Irq_6:
L8698:  LDA  GTIME                  ;ACTUAL GAME TIME IN 4 SEC COUNTS
L869B:  ADC  #$01
L869D:  STA  GTIME
L86A0:  BPL  Irq_7                  ;CHECK FOR 79 COUNTS
L86A2:  LDA  #$80
L86A4:  STA  SCSHSP                 ;SAUCERS MAD NOW
L86A7:  STA  $039E

Irq_7:
L86AA:  LDA  $03B1
L86AD:  ADC  #$00
L86AF:  STA  $03B1
L86B2:  LDA  $03B2
L86B5:  ADC  #$00
L86B7:  STA  $03B2
L86BA:  LDA  $03B3
L86BD:  ADC  #$00
L86BF:  STA  $03B3
L86C2:  CLD                         ;****OUT OF DECIMAL**********

Irq_5:
L86C3:  LDX  #$01

Irq_10:
L86C5:  LDA  PRTDAMAGE,X
L86C8:  BEQ  Irq_12                 ;NOT DAMAGED
L86CA:  LDA  INTRPT
L86CC:  AND  #$02
L86CE:  BNE  Irq_18                 ;THIS IS NOT THE ONE

Irq_12:
L86D0:  BIT  ATRACT
L86D2:  BMI  Irq_13
L86D4:  LDA  FRAME
L86D6:  AND  #$80
L86D8:  BNE  Irq_135
L86DA:  BEQ  Irq_14

Irq_13:
L86DC:  LDA  ROTL,X                 ;ROTATE LEFT
L86DF:  BPL  Irq_14

Irq_135:
L86E1:  INC  IANGLE,X

Irq_14:
L86E4:  BIT  ATRACT
L86E6:  BMI  Irq_15
L86E8:  LDA  FRAME
L86EA:  AND  #$20
L86EC:  BNE  Irq_145
L86EE:  BEQ  Irq_18

Irq_15:
L86F0:  LDA  ROTL,X                 ;ROTATE RIGHT
L86F3:  ASL
L86F4:  BPL  Irq_18

Irq_145:
L86F6:  DEC  IANGLE,X

Irq_18:
L86F9:  DEX
L86FA:  BPL  Irq_10
L86FC:  LDA  HALT
L86FF:  AND  #$10
L8701:  BEQ  Irq_19                 ;NOT IF TEST
L8703:  JSR  ContinuesPreviouslyStartedSound ;CONTINUE SOUNDS

Irq_19:
L8706:  LDA  IANGLE
L8709:  STA  SANGLE
L870C:  BIT  TOGDRONE
L870E:  BMI  Irq_20                 ;SAME ANGLE FOR BOTH
L8710:  LDA  $03D1

Irq_20:
L8713:  STA  $02A4

Irq_40:
L8716:  PLA
L8717:  TAX
L8718:  PLA
L8719:  TAY
L871A:  PLA
L871B:  RTI

SaveInpuParameers:
L871C:  PHP                         ;SAVE INPU PARAMEERS
L871D:  DEY
L871E:  STY  NMROCK                 ;Y MAY BE A CONSTANT
L8720:  CLC
L8721:  ADC  NMROCK
L8723:  STA  TEMP4                  ;MSB OF DIGITS
L8725:  PLP
L8726:  TAX

SaveInpuParameers_10:
L8727:  PHP
L8728:  LDA  VGBRIT,X
L872A:  LSR
L872B:  LSR
L872C:  LSR
L872D:  LSR
L872E:  PLP
L872F:  JSR  DisplayDigitWithZero   ;FIRST DIGIT
L8732:  LDA  NMROCK
L8734:  BNE  SaveInpuParameers_20
L8736:  CLC                         ;DISPLAY LAST DIGIT (EVEN 0)

SaveInpuParameers_20:
L8737:  LDX  TEMP4
L8739:  LDA  VGBRIT,X
L873B:  JSR  DisplayDigitWithZero   ;SECOND DIGIT
L873E:  DEC  TEMP4
L8740:  LDX  TEMP4
L8742:  DEC  NMROCK
L8744:  BPL  SaveInpuParameers_10   ;LOOP FOR EACH SET OF DIGITS
L8746:  RTS
L8747:  .byte $02, $1D, $1E, $3E

EaromOffsetLowestByte:
L874B:  .byte $64, $01, $92, $01

ZeroEarom:
L874F:  LDA  #$02
L8751:  BNE  RequestZeroEarom       ;ZERO BOOKKEEPING ONLY

Eazhis:
L8753:  LDA  #$01
L8755:  BNE  RequestZeroEarom       ;ZERO HI SCORES/INITIALS ONLY

Eazero:
L8757:  LDA  #$03

RequestZeroEarom:
L8759:  LDY  #$FF                   ;REQUEST ZERO EAROM
L875B:  BNE  DoNotZeroEarom         ;REQUEST ALL BATCHES

WriteHighScoresInitials:
L875D:  LDA  #$01                   ;WRITE HIGH SCORES & INITIALS
L875F:  BNE  Nozero

RequestBookkeepingUpdate:
L8761:  LDA  #$02                   ;REQUEST BOOKKEEPING UPDATE

Nozero:
L8763:  LDY  #$00

DoNotZeroEarom:
L8765:  STY  EAZFLG                 ;DO NOT ZERO EAROM
L8768:  PHA
L8769:  ORA  EAREQU
L876C:  STA  EAREQU
L876F:  PLA
L8770:  ORA  EARWRQ
L8773:  STA  EARWRQ
L8776:  RTS

ReadEverything:
L8777:  LDA  #$03                   ;READ IN EVERYTHING
L8779:  STA  EAREQU
L877C:  LDA  #$00
L877E:  STA  EARWRQ

OutputEaromErasedWritten:
L8781:  LDA  EAFLG
L8784:  BNE  L87D1
L8786:  LDA  EAREQU                 ;NO.
L8789:  BEQ  L87D1
L878B:  LDX  #$00                   ;YES
L878D:  STX  EABC                   ;ZERO SOURCE INDEX
L8790:  STX  EACS                   ;ZERO CHECKSUM
L8793:  STX  EASEL                  ;ZERO SELECT BIT
L8796:  LDX  #$08
L8798:  SEC
L8799:  ROR  EASEL
L879C:  ASL
L879D:  DEX
L879E:  BCC  L8799
L87A0:  LDY  #$80                   ;DEFAULT TO ERASE/WRITE
L87A2:  LDA  EASEL
L87A5:  AND  EARWRQ
L87A8:  BNE  L87AC
L87AA:  LDY  #$20                   ;READ
L87AC:  STY  EAFLG                  ;SAVE REQUEST
L87AF:  LDA  EASEL
L87B2:  EOR  EAREQU
L87B5:  STA  EAREQU                 ;TURN OFF REQUEST BIT
L87B8:  TXA
L87B9:  ASL
L87BA:  TAX
L87BB:  LDA  $8747,X                ;SET UP PARAMETERS FOR EAROM WRITE
L87BE:  STA  EAX
L87C1:  LDA  $8748,X
L87C4:  STA  EACNT
L87C7:  LDA  EaromOffsetLowestByte,X
L87CA:  STA  EASRCE
L87CC:  LDA  $874C,X
L87CF:  STA  $C8
L87D1:  LDY  #$00                   ;DESELECT CHIP
L87D3:  STY  EACTL
L87D6:  LDA  EAFLG
L87D9:  BNE  L87DC
L87DB:  RTS                         ;NO. EXIT
L87DC:  LDY  EABC                   ;YES.
L87DF:  LDX  EAX
L87E2:  ASL
L87E3:  BCC  L87F2
L87E5:  STA  EADAL,X                ;STORE ADDRESS
L87E8:  LDA  #$40                   ;REQUEST WRITE
L87EA:  STA  EAFLG
L87ED:  LDY  #$0E                   ;ERASE & SELECT CHIP
L87EF:  JMP  L8865
L87F2:  BPL  L8819
L87F4:  LDA  #$80                   ;WRITE A BYTE
L87F6:  STA  EAFLG                  ;REQUEST ERASE FOR NEXT BYTE
L87F9:  LDA  EAZFLG
L87FC:  BEQ  L8802
L87FE:  LDA  #$00                   ;YES.
L8800:  STA  (EASRCE),Y             ;CLEAR RAM TOO
L8802:  LDA  (EASRCE),Y             ;GET RAM DATA (DEFAULT)
L8804:  CPX  EACNT
L8807:  BCC  L8811
L8809:  LDA  #$00                   ;ALL DONE. SET DONE FLAG
L880B:  STA  EAFLG
L880E:  LDA  EACS                   ;GET CHECKSUM
L8811:  STA  EADAL,X                ;WRITE DATA
L8814:  LDY  #$0C                   ;SELECT WRITE MODE & CHIP SELECT
L8816:  JMP  L8858
L8819:  LDA  #$08
L881B:  STA  EACTL                  ;SELECT CHIP AND READ FUNCTION
L881E:  STA  EADAL,X                ;SELECT ADDRESS
L8821:  LDA  #$09
L8823:  STA  EACTL                  ;SELECT CHIP & CLOCK & READ
L8826:  NOP
L8827:  LDA  #$08
L8829:  STA  EACTL                  ;SELECT CHIP
L882C:  CPX  EACNT
L882F:  LDA  EAIN                   ;READ EAROM
L8832:  BCC  L8854
L8834:  EOR  EACS                   ;MATCH CHECKSUM?
L8837:  BEQ  L884C
L8839:  LDA  #$00                   ;NO.
L883B:  LDY  EABC
L883E:  STA  (EASRCE),Y
L8840:  DEY
L8841:  BPL  L883E
L8843:  LDA  EASEL                  ;SET BAD FLAG
L8846:  ORA  EABAD
L8849:  STA  EABAD
L884C:  LDA  #$00
L884E:  STA  EAFLG                  ;ALL DONE
L8851:  JMP  L8856
L8854:  STA  (EASRCE),Y             ;SAVE DATA IN RAM
L8856:  LDY  #$00                   ;DESELECT
L8858:  CLC
L8859:  ADC  EACS
L885C:  STA  EACS                   ;UPDATE CHECKSUM
L885F:  INC  EABC
L8862:  INC  EAX
L8865:  STY  EACTL
L8868:  TYA
L8869:  BNE  L886E
L886B:  JMP  OutputEaromErasedWritten ;YES. DO ALL READS AT ONCE
L886E:  RTS

TransferHighScoresBuffer:
L886F:  LDX  #$02                   ;3 OF EACH
L8871:  LDY  #$00                   ;BUFFER POINTER

TransferHighScoresBuffer_10:
L8873:  .byte $BD, $DD, $00    ;LDA HSCORE,X (forced absolute) - 2 PLAYER FIGHTERS
L8876:  STA  EABUF,Y
L8879:  INY
L887A:  .byte $BD, $EC, $00    ;LDA $00EC,X (forced absolute) - 1 PLAYER FIGHTER
L887D:  STA  EABUF,Y
L8880:  INY
L8881:  .byte $BD, $FB, $00    ;LDA $00FB,X (forced absolute) - 2 PLAYER SPACE STATION
L8884:  STA  EABUF,Y
L8887:  INY
L8888:  LDA  $010A,X                ;1 PLAYER SPACE STATION
L888B:  STA  EABUF,Y
L888E:  INY
L888F:  LDA  INITL,X                ;2 PLAYER FIGHTER
L8892:  STA  EABUF,Y
L8895:  INY
L8896:  LDA  $0128,X                ;1 PLAYER FIGHTER
L8899:  STA  EABUF,Y
L889C:  INY
L889D:  LDA  $0137,X                ;2 PLAYER SPACE STATION
L88A0:  STA  EABUF,Y
L88A3:  INY
L88A4:  LDA  SPINT,X                ;2 PLR STATION, ALT SET
L88A7:  STA  EABUF,Y
L88AA:  INY
L88AB:  LDA  $0146,X                ;1 PLAYER SPACE STATION
L88AE:  STA  EABUF,Y
L88B1:  INY
L88B2:  DEX
L88B3:  BPL  TransferHighScoresBuffer_10 ;NEXT INITIALS
L88B5:  RTS

CopyFromBufferBack:
L88B6:  LDX  #$02                   ;SAME COMMENTS AS ABOVE
L88B8:  LDY  #$00

CopyFromBufferBack_10:
L88BA:  JSR  SaveCopy
L88BD:  .byte $9D, $DD, $00    ;STA HSCORE,X (forced absolute)
L88C0:  INY
L88C1:  JSR  SaveCopy
L88C4:  .byte $9D, $EC, $00    ;STA $00EC,X (forced absolute)
L88C7:  INY
L88C8:  JSR  SaveCopy
L88CB:  .byte $9D, $FB, $00    ;STA $00FB,X (forced absolute)
L88CE:  INY
L88CF:  JSR  SaveCopy
L88D2:  STA  $010A,X
L88D5:  JSR  SaveOriginal
L88D8:  STA  INITL,X
L88DB:  JSR  SaveOriginal
L88DE:  STA  $0128,X
L88E1:  JSR  SaveOriginal
L88E4:  STA  $0137,X
L88E7:  JSR  SaveOriginal
L88EA:  STA  SPINT,X
L88ED:  JSR  SaveOriginal
L88F0:  STA  $0146,X
L88F3:  INY
L88F4:  DEX
L88F5:  BPL  CopyFromBufferBack_10
L88F7:  .byte $AD, $DD, $00    ;LDA HSCORE (forced absolute)
L88FA:  .byte $0D, $DE, $00    ;ORA $00DE (forced absolute) - IS THIS SCORE ALL 0?
L88FD:  .byte $0D, $DF, $00    ;ORA $00DF (forced absolute)
L8900:  BNE  CopyFromBufferBack_20  ;IF NO, OK, ELSE....
L8902:  LDA  #$05                   ;...MUST HAVE JUST CLEARED EAROM
L8904:  .byte $8D, $DE, $00    ;STA $00DE (forced absolute) - SO REINIT TOP SCORES
L8907:  .byte $8D, $ED, $00    ;STA $00ED (forced absolute)
L890A:  .byte $8D, $FC, $00    ;STA $00FC (forced absolute)
L890D:  STA  $010B

CopyFromBufferBack_20:
L8910:  RTS

SaveCopy:
L8911:  LDA  EABUF,Y                ;SAVE COPY
L8914:  PHA
L8915:  CMP  #$9A
L8917:  BCS  SaveCopy_20
L8919:  AND  #$0F
L891B:  CMP  #$0A
L891D:  BCS  SaveCopy_20
L891F:  PLA                         ;RESTORE ORIGNAL DATA
L8920:  RTS

SaveCopy_20:
L8921:  PLA                         ;THROW AWAY OLD (BAD) DATA
L8922:  LDA  Subnum,X               ;REPLACE WITH SUB NUMBER
L8925:  RTS

Subnum:
L8926:  .byte $00, $05, $00

SaveOriginal:
L8929:  INY                         ;SAVE ORIGINAL
L892A:  LDA  EABUF,Y                ;INPUT
L892D:  BEQ  SaveOriginal_30        ;A BLANK IS OK
L892F:  CMP  #$0A                   ;A?
L8931:  BCC  SaveOriginal_20
L8933:  CMP  #$25                   ;Z?
L8935:  BCC  SaveOriginal_30

SaveOriginal_20:
L8937:  LDA  Subl,X

SaveOriginal_30:
L893A:  RTS

Subl:
L893B:  .byte $0C, $0B, $0E

UpdateInfoAtEnd:
L893E:  SED                         ;ALL IN DECIMAL
L893F:  LDY  #$00
L8941:  .byte $AD, $34, $00    ;LDA GAME (forced absolute)
L8944:  ASL
L8945:  ASL                         ;GAME #*4
L8946:  TAX
L8947:  CLC

UpdateInfoAtEnd_12:
L8948:  JSR  AddGameTimeSubroutime
L894B:  JSR  AddGameTimeSubroutime  ;ADD IN LAST GAME TIME
L894E:  JSR  AddGameTimeSubroutime
L8951:  JSR  AddGameTimeSubroutime  ;4 BYTES OF TIME
L8954:  LDX  #$00
L8956:  LDY  #$03
L8958:  CLC
L8959:  LDA  GTIME,X
L895C:  ADC  ONTIME,X
L895F:  STA  ONTIME,X               ;THIS COUNTER WAS OFF DURING THE GAME
L8962:  INX
L8963:  DEY
L8964:  BPL  L8959
L8966:  .byte $AD, $34, $00    ;LDA GAME (forced absolute)
L8969:  ASL
L896A:  CLC
L896B:  .byte $6D, $34, $00    ;ADC GAME (forced absolute) - *3 FOR GAME NUMBERS
L896E:  TAX

UpdateInfoAtEnd_14:
L896F:  CLC
L8970:  LDA  GAMES1,X               ;UPDATE NUMBER OF GAMES PLAYED
L8973:  ADC  #$01
L8975:  STA  GAMES1,X
L8978:  LDA  $01A7,X
L897B:  ADC  #$00
L897D:  STA  $01A7,X
L8980:  LDA  $01A8,X
L8983:  ADC  #$00
L8985:  STA  $01A8,X
L8988:  CLD
L8989:  LDX  #$03                   ;MOVE ONTIME

UpdateInfoAtEnd_13:
L898B:  LDA  ONTIME,X
L898E:  STA  BONTIME,X              ;FOR EA ROM WRITE
L8991:  DEX
L8992:  BPL  UpdateInfoAtEnd_13
L8994:  JMP  RequestBookkeepingUpdate ;START UPDATE

AddGameTimeSubroutime:
L8997:  LDA  PLAYTIME,X
L899A:  ADC  GTIME,Y
L899D:  STA  PLAYTIME,X
L89A0:  INX
L89A1:  INY                         ;NEXT PLACE
L89A2:  RTS

CopyOntimeFromBuffer:
L89A3:  SEI                         ;DONT LET IT UPDATE WHILE MOVING
L89A4:  LDX  #$03

CopyOntimeFromBuffer_10:
L89A6:  LDA  BONTIME,X
L89A9:  STA  ONTIME,X
L89AC:  DEX
L89AD:  BPL  CopyOntimeFromBuffer_10
L89AF:  CLI
L89B0:  RTS

CalculateAverageGameTime:
L89B1:  .byte $00, $03, $06, $09

Timix:
L89B5:  .byte $00, $04, $08, $0C

Averag:
L89B9:  LDY  #$03
L89BB:  STY  TEMPC
L89BD:  SED                         ;*********CAUTION...DECIMAL ***********
L89BE:  LDY  TEMPC
L89C0:  LDX  CalculateAverageGameTime,Y ;GET INDEX FOR # OF GAMES
L89C3:  LDY  #$00

Averag_10:
L89C5:  LDA  GAMES1,X
L89C8:  STA  TEMP4,Y                ;MOVE TO TEMP
L89CB:  INX
L89CC:  INY
L89CD:  CPY  #$03
L89CF:  BNE  Averag_10              ;DO ALL 3 BYTES
L89D1:  LDY  TEMPC                  ;RECALL GAME #
L89D3:  LDX  Timix,Y                ;GET INDEX FOR SECONDS
L89D6:  LDY  #$00                   ;0 GAMES?
L89D8:  STY  TEMPA

Averag_20:
L89DA:  LDA  PLAYTIME,X
L89DD:  STA  TEMP1,Y                ;MOVE TO TEMPS
L89E0:  ORA  TEMPA
L89E2:  STA  TEMPA                  ;TO CHECK FOR 0 GAMES
L89E4:  INX
L89E5:  INY
L89E6:  CPY  #$04                   ;4 BYTES
L89E8:  BNE  Averag_20
L89EA:  LDY  #$01                   ;1 WILL GO TO 0 IF ERROR (BELOW)
L89EC:  LDA  TEMPA                  ;0 GAMES?
L89EE:  BEQ  Averag_40
L89F0:  DEY                         ;Y=0

Averag_30:
L89F1:  INY
L89F2:  BEQ  Averag_40
L89F4:  LDA  TEMP1
L89F6:  SEC
L89F7:  SBC  TEMP4                  ;SUBTRACT # OF GAMES FROM TOTAL TIME
L89F9:  STA  TEMP1
L89FB:  LDA  EACE
L89FD:  SBC  NMROCK
L89FF:  STA  EACE
L8A01:  LDA  $09
L8A03:  SBC  $12
L8A05:  STA  $09
L8A07:  LDA  TEMP2
L8A09:  SBC  #$00                   ;COME ALONG CARRY
L8A0B:  STA  TEMP2
L8A0D:  BPL  Averag_30              ;NOT DONE YET

Averag_40:
L8A0F:  CLD                         ;****OUT OF DECIMAL******
L8A10:  DEY
L8A11:  TYA                         ;SAVE IN A
L8A12:  LDY  TEMPC
L8A14:  STA  OBJ,Y                  ;A GOOD PLACE TO PUT IT NOW
L8A17:  DEY
L8A18:  STY  TEMPC
L8A1A:  BPL  L89BD
L8A1C:  RTS

AllStopPlease:
L8A1D:  STA  STOPAD                 ;ALL STOP PLEASE
L8A20:  JSR  Inisou                 ;TURN OFF SOUNDS
L8A23:  JSR  Averag                 ;CALCULATE AVERAGES
L8A26:  LDA  #$00
L8A28:  STA  ATRACT                 ;END ANY GAME HERE
L8A2A:  STA  LANG                   ;ALWAYS ENGLISH
L8A2C:  STA  LANGBT                 ;ALLOW COINS AGAIN
L8A2E:  LDX  #$20
L8A30:  LDA  #$00
L8A32:  STA  VGLIST
L8A34:  STX  EAC2
L8A36:  LDA  #$94
L8A38:  LDX  #$AA
L8A3A:  JSR  Add2WordsToVector
L8A3D:  LDY  #$08                   ;'1 PLAYER'
L8A3F:  JSR  CorrectMessageAndColor
L8A42:  LDY  #$09                   ;'2 PLAYER'
L8A44:  JSR  CorrectMessageAndColor
L8A47:  LDY  #$0A                   ;'SECONDS'
L8A49:  JSR  CorrectMessageAndColor
L8A4C:  LDY  #$0B                   ;'GAMES'
L8A4E:  JSR  CorrectMessageAndColor
L8A51:  LDY  #$0C                   ;'AVG GAME TIME'
L8A53:  JSR  CorrectMessageAndColor
L8A56:  LDA  #$02                   ;PUT UP SPACE STATION / FIGHTERS
L8A58:  STA  TEMP7                  ;SAVE INDEX

AllStopPlease_10:
L8A5A:  JSR  CenterBeamInMiddle
L8A5D:  LDY  TEMP7                  ;RECALL INDEX
L8A5F:  LDA  #$98
L8A61:  LDX  PositionsFightersSpaceStation,Y ;Y POS
L8A64:  JSR  UpdownVectorUpsideDown
L8A67:  LDA  #$10                   ;'F'
L8A69:  JSR  SaveCFlag
L8A6C:  JSR  CenterBeamInMiddle
L8A6F:  LDY  TEMP7                  ;RECALL INDEX
L8A71:  LDA  #$98
L8A73:  LDX  Y2pos,Y                ;Y POSIT
L8A76:  JSR  UpdownVectorUpsideDown
L8A79:  LDA  #$1D
L8A7B:  JSR  SaveCFlag              ;'S'
L8A7E:  DEC  TEMP7                  ;NEXT USE
L8A80:  BPL  AllStopPlease_10
L8A82:  LDA  #$54
L8A84:  LDX  #$E2                   ;SO NEXT SWAP GOES TO FIRST BUFFER
L8A86:  JSR  Add2WordsToVector
L8A89:  JSR  AddHaltToVector        ;SO IT WILL HALT

St2:
L8A8C:  BIT  HALT
L8A8F:  BVC  St2                    ;WAIT FOR HALT
L8A91:  LDA  $20A7
L8A94:  EOR  #$02
L8A96:  STA  $20A7                  ;SWAP BUFFERS
L8A99:  STA  WTCHDG                 ;KEEP THE SLEEPING DOG SLEEPING
L8A9C:  LDX  #$20
L8A9E:  AND  #$02
L8AA0:  BNE  St2_12
L8AA2:  LDX  #$24

St2_12:
L8AA4:  LDA  #$A8
L8AA6:  STA  VGLIST
L8AA8:  STX  EAC2
L8AAA:  STA  GOADD
L8AAD:  JSR  L8F43                  ;GET DIFF READING
L8AB0:  ADC  #$0D                   ;MESSAGE # OFFSET
L8AB2:  TAY
L8AB3:  JSR  CorrectMessageAndColor
L8AB6:  BIT  CABERE
L8AB9:  BPL  L8AD6
L8ABB:  JSR  CenterBeamInMiddle     ;NEED C FOR COCKTAIL
L8ABE:  LDA  #$98
L8AC0:  LDX  #$00
L8AC2:  JSR  UpdownVectorUpsideDown
L8AC5:  LDA  #$0D                   ;OUTPUT A 'C'
L8AC7:  JSR  SaveCFlag
L8ACA:  LDA  #$00                   ;GUESS NORMAL
L8ACC:  BIT  STRT1
L8ACF:  BVC  L8AD3
L8AD1:  LDA  #$C0
L8AD3:  STA  OUT1
L8AD6:  JSR  CenterBeamInMiddle     ;DISPLAY LIVES
L8AD9:  LDA  #$96
L8ADB:  LDX  #$0E
L8ADD:  JSR  UpdownVectorUpsideDown
L8AE0:  LDA  #$02
L8AE2:  JSR  SetVectorGeneratorScale
L8AE5:  JSR  Gtoptn
L8AE8:  LDA  LANG
L8AEA:  PHA                         ;SAVE LANGUAGE
L8AEB:  LDA  #$00
L8AED:  STA  LANG                   ;ALWAYS ENGLISH
L8AEF:  LDA  HITS
L8AF1:  STA  TEMP1
L8AF3:  LDA  $30AC
L8AF6:  LDX  $30AF
L8AF9:  JSR  Add2WordsToVector
L8AFC:  DEC  TEMP1
L8AFE:  BNE  L8AF3
L8B00:  LDA  #$01
L8B02:  JSR  SetVectorGeneratorScale ;RETURN TO NORMAL
L8B05:  JSR  CenterBeamInMiddle     ;CENTER
L8B08:  LDA  #$A0
L8B0A:  LDX  #$00
L8B0C:  JSR  UpdownVectorUpsideDown ;POSITION FOR LANG LETTER
L8B0F:  PLA
L8B10:  TAX                         ;LETTER INDEX
L8B11:  LDA  Langlt,X               ;GET LETTER
L8B14:  JSR  SaveCFlag              ;OUTPUT LETTER
L8B17:  BIT  GAMSEL                 ;2 COIN MIN??
L8B1A:  BVC  L8B2B
L8B1C:  JSR  CenterBeamInMiddle     ;POSITION FOR 2
L8B1F:  LDA  #$0D
L8B21:  LDX  #$4D
L8B23:  JSR  UpdownVectorUpsideDown
L8B26:  LDA  #$03
L8B28:  JSR  SaveCFlag              ;DISPLAY A '2' IF 2 COIN MIN
L8B2B:  LDY  #$07                   ;'TOTAL ON TIME'
L8B2D:  JSR  CorrectMessageAndColor
L8B30:  LDX  #$03

St2_50:
L8B32:  LDA  ONTIME,X
L8B35:  STA  TEMP7,X
L8B37:  DEX
L8B38:  BPL  St2_50                 ;MOVE TO 0 PAGE FOR DISPLAY
L8B3A:  JSR  Times4Decimal          ;SECONDS TIMES 4
L8B3D:  LDY  #$04
L8B3F:  JSR  Set0Balnking

TimeDisplayCalulationsHere:
L8B42:  LDA  #$03
L8B44:  STA  TEMPC                  ;WILL HOLD GAME NUMBER HERE

TimeDisplayCalulationsHere_20:
L8B46:  LDX  TEMPC                  ;RECALL GAME NUMBER
L8B48:  LDY  Timix,X                ;OFFSET INTO RAM
L8B4B:  LDX  #$00                   ;TRANSFER POINTER

TimeDisplayCalulationsHere_21:
L8B4D:  LDA  PLAYTIME,Y
L8B50:  STA  TEMP7,X
L8B52:  INX
L8B53:  INY
L8B54:  CPX  #$04                   ;4 BYTES?
L8B56:  BNE  TimeDisplayCalulationsHere_21
L8B58:  JSR  CenterBeamInMiddle     ;CENTER BEAM
L8B5B:  LDY  TEMPC                  ;NEED THIS AGAIN
L8B5D:  LDA  Tiposx,Y               ;POSTION OF TIME DISPLAY (X)
L8B60:  LDX  Tiposy,Y
L8B63:  JSR  UpdownVectorUpsideDown ;POSITION BEAM
L8B66:  JSR  Times4Decimal          ;TEMP * 4 FOR ACTUAL SECOND COUNT
L8B69:  LDY  #$04                   ;DISPLAY 4 BYTES (8 DIGITS)
L8B6B:  JSR  Set0Balnking
L8B6E:  JSR  CenterBeamInMiddle     ;READY FOR NEXT
L8B71:  LDY  TEMPC                  ;NEED THIS AGAIN
L8B73:  LDA  Gmposx,Y               ;GAME COUNT POSITION
L8B76:  LDX  Gmposy,Y
L8B79:  JSR  UpdownVectorUpsideDown ;READY FOR DISPLAY
L8B7C:  LDX  TEMPC                  ;GET THIS AGAIN!
L8B7E:  LDY  CalculateAverageGameTime,X ;OFFSET INTO RAM FOR THIS NUMBER
L8B81:  LDX  #$00

TimeDisplayCalulationsHere_22:
L8B83:  LDA  GAMES1,Y               ;TRANSFER TO TEMP FOR DISPLAY
L8B86:  STA  TEMP7,X
L8B88:  INX
L8B89:  INY
L8B8A:  CPX  #$03                   ;3 BYTES?
L8B8C:  BNE  TimeDisplayCalulationsHere_22
L8B8E:  LDY  #$03
L8B90:  JSR  Set0Balnking           ;DISPLAY 3 BYTES (6 DIGITS)
L8B93:  JSR  CenterBeamInMiddle     ;GET READY FOR NEXT DISPLAY
L8B96:  LDY  TEMPC                  ;GUESS WHAT I NEED AGAIN
L8B98:  LDA  Avposx,Y               ;X POSITION OF AVG GAME TIME DISPLAY
L8B9B:  LDX  Avposy,Y               ;Y POSIT.
L8B9E:  JSR  UpdownVectorUpsideDown ;READY FOR DISPLAY
L8BA1:  LDY  TEMPC                  ;MAX AVG TIME IS 255 * 4 SECONDS
L8BA3:  LDA  OBJ,Y                  ;GET NUMBER
L8BA6:  JSR  HexBcdConversionInput  ;CONVERT TO DECIMAL (RESULTS IN TEMP7&8)
L8BA9:  JSR  Times4Decimal          ;CONVERT TO 4 COUNT SECONDS
L8BAC:  LDY  #$02
L8BAE:  JSR  Set0Balnking           ;DISPLAY 2 BYTES (4 DIGITS)
L8BB1:  DEC  TEMPC
L8BB3:  BMI  TimeDisplayCalulationsHere_30 ;DONE
L8BB5:  JMP  TimeDisplayCalulationsHere_20 ;DO NEXT

TimeDisplayCalulationsHere_30:
L8BB8:  LDY  #$00                   ;''PUSH START & SELECT'
L8BBA:  JSR  CorrectMessageAndColor
L8BBD:  LDA  TEMP11
L8BBF:  AND  #$03                   ;SELECTED OPTION 1 OF 4
L8BC1:  TAY
L8BC2:  INY                         ;CORRECT OPTION MESSAGE
L8BC3:  JSR  CorrectMessageAndColor
L8BC6:  LDA  STRT1                  ;CHECK FOR BOTH STARTS PUSHED
L8BC9:  ASL                         ;D6=STARTS,MOVE TO D7
L8BCA:  AND  GAMSEL
L8BCD:  BPL  Nooptn                 ;NOT BOTH PUSHED
L8BCF:  JSR  OptionSelected

Nooptn:
L8BD2:  LDA  GAMSEL                 ;SELECT PUSHED?
L8BD5:  BPL  Nooptn_10              ;YES
L8BD7:  STA  TEMP12                 ;NOT PUSHED, CLEAR FLAG
L8BD9:  BMI  Nooptn_20              ;*****ALWAYS*******

Nooptn_10:
L8BDB:  ORA  TEMP12                 ;PUSHED BEFORE?
L8BDD:  BPL  Nooptn_20              ;YES, SKIP
L8BDF:  LDA  #$00
L8BE1:  STA  TEMP12                 ;CLEAR FLAG
L8BE3:  INC  TEMP11                 ;BUMP OPTION

Nooptn_20:
L8BE5:  LDA  EAFLG                  ;EAROM OPERATING?
L8BE8:  BEQ  Nooptn_40              ;NO
L8BEA:  LDA  EAZFLG                 ;ERASEING?
L8BED:  BEQ  Nooptn_40
L8BEF:  LDY  #$05                   ;'ERASING'
L8BF1:  JSR  CorrectMessageAndColor

Nooptn_40:
L8BF4:  LDY  #$06                   ;'BONUS ADDRES
L8BF6:  JSR  CorrectMessageAndColor
L8BF9:  LDA  ZMINE                  ;DISPLAY BONUS ADDER MODE
L8BFB:  ROL
L8BFC:  ROL
L8BFD:  ROL
L8BFE:  ROL                         ;MOVE TO BOTTOM 3 BITS
L8BFF:  AND  #$07
L8C01:  TAX
L8C02:  LDA  BonusAddresTableDisplay,X ;GET DISPLAY INFO
L8C05:  STA  TEMP7                  ;PUT HERE FOR DISPLAY
L8C07:  CLC
L8C08:  LDY  #$01
L8C0A:  JSR  Set0Balnking
L8C0D:  JSR  CenterBeamInMiddle     ;CENTER BEAM THEN...
L8C10:  LDA  #$D7
L8C12:  LDX  #$38                   ;...POSITION BEAM FOR...
L8C14:  JSR  Vgvtr1
L8C17:  JSR  CenterBeam             ;...OUTPUT OF OPTIONS
L8C1A:  JSR  AddHaltToVector
L8C1D:  LDA  HALT
L8C20:  AND  #$10                   ;STILL TEST
L8C22:  BEQ  Nooptn_45
L8C24:  LDA  #$00
L8C26:  STA  FRAME                  ;START ATTRACT OVER
L8C28:  STA  $45
L8C2A:  STA  NROCKS
L8C2D:  STA  ATSTG
L8C2F:  JMP  Pwron                  ;NOT TEST

Nooptn_45:
L8C32:  JSR  Swtst                  ;BEEP ON SWITCH PUSHED
L8C35:  JMP  St2                    ;CONTINUE HERE

BonusAddresTableDisplay:
L8C38:  .byte $00, $12, $14, $24, $15, $00, $00, $00

PositionsFightersSpaceStation:
L8C40:  .byte $E8, $C8, $A8

Y2pos:
L8C43:  .byte $E0, $C0, $A0

Tiposx:
L8C46:  .byte $F8, $40, $F8, $40

Tiposy:
L8C4A:  .byte $E8, $E8, $E0, $E0

Gmposx:
L8C4E:  .byte $04, $4C, $04, $4C

Gmposy:
L8C52:  .byte $C8, $C8, $C0, $C0

Avposx:
L8C56:  .byte $10, $58, $10, $58

Avposy:
L8C5A:  .byte $A8, $A8, $A0, $A0

Langlt:
L8C5E:  .byte $0F, $11, $10, $1D

HexBcdConversionInput:
L8C62:  STA  TEMP9
L8C64:  LDY  #$07                   ;BIT COUNT
L8C66:  LDA  #$00
L8C68:  STA  TEMP7
L8C6A:  STA  TEMP7B                 ;CLEAR END REGS
L8C6C:  SED                         ;****WARNING--DECIMAL MODE*******

HexBcdConversionInput_10:
L8C6D:  ASL  TEMP9
L8C6F:  LDA  TEMP7
L8C71:  ADC  TEMP7
L8C73:  STA  TEMP7
L8C75:  LDA  TEMP7B
L8C77:  ADC  TEMP7B
L8C79:  STA  TEMP7B
L8C7B:  DEY
L8C7C:  BPL  HexBcdConversionInput_10
L8C7E:  CLD
L8C7F:  RTS

Set0Balnking:
L8C80:  SEC                         ;SET 0 BALNKING

PointerData:
L8C81:  LDA  #$15                   ;POINTER TO DATA
L8C83:  JMP  SaveInpuParameers

MultiplyBy2Decimal:
L8C86:  CLC
L8C87:  SED                         ;*******WARNING--DECIMAL MODE
L8C88:  LDX  #$00
L8C8A:  LDY  #$02

MultiplyBy2Decimal_10:
L8C8C:  LDA  TEMP7,X
L8C8E:  ADC  TEMP7,X
L8C90:  STA  TEMP7,X
L8C92:  INX
L8C93:  DEY
L8C94:  BPL  MultiplyBy2Decimal_10
L8C96:  CLD
L8C97:  RTS

Times4Decimal:
L8C98:  JSR  MultiplyBy2Decimal
L8C9B:  JMP  MultiplyBy2Decimal

DoSelfTest:
L8C9E:  .byte $3E, $80, $CD, $8C, $B4, $8C, $C4, $8C

OptionSelected:
L8CA6:  LDA  TEMP11                 ;OPTION SELECTED
L8CA8:  AND  #$03
L8CAA:  ASL                         ;WORDS (X2)
L8CAB:  TAX
L8CAC:  LDA  $8C9F,X
L8CAF:  PHA
L8CB0:  LDA  DoSelfTest,X
L8CB3:  PHA
L8CB4:  RTS                         ;JUMP TO ROUTINE

ClearTimes:
L8CB5:  JSR  ZeroEarom

Clrbuf:
L8CB8:  LDA  #$00
L8CBA:  LDX  #$29

Clrbuf_10:
L8CBC:  STA  ONTIME,X               ;CLEAR RAM ALSO
L8CBF:  STA  OBJ,X                  ;CLEAR TEMP BUFFER TOO
L8CC1:  DEX
L8CC2:  BPL  Clrbuf_10
L8CC4:  RTS

ClearBoth:
L8CC5:  JSR  Eazero
L8CC8:  JSR  Clrbuf
L8CCB:  JMP  SetUpInitialsHigh      ;RECOPY DEFAULT INITIALS

ClearScores:
L8CCE:  JSR  Eazhis
L8CD1:  JMP  SetUpInitialsHigh      ;RECOPY DEFAULT INITIALS

CorrectMessageAndColor:
L8CD4:  STY  TEMP5                  ;SAVE Y
L8CD6:  JSR  CenterBeamInMiddle
L8CD9:  LDY  TEMP5
L8CDB:  LDA  L0Normal0fMedium,Y     ;POSITION MESSAGE
L8CDE:  LDX  Y3pos,Y
L8CE1:  JSR  UpdownVectorUpsideDown ;POSITION
L8CE4:  LDX  TEMP5                  ;DO COLOR MESSAGE
L8CE6:  LDA  MessageColor,X         ;COLOR
L8CE9:  LDY  MessageNumberRealMessage,X ;MESSAGE NUMBER
L8CEC:  JMP  PassColor              ;(EXIT)

L0Normal0fMedium:
L8CEF:  .byte $CE, $EC, $E4, $E8, $C4, $F0, $DC, $C0
L8CF7:  .byte $40, $FC, $8C, $8C, $8C, $F8, $F8, $F8
L8CFF:  .byte $F8

Y3pos:
L8D00:  .byte $14, $0C, $0C, $0C, $0C, $1C, $44, $24
L8D08:  .byte $00, $00, $F0, $D0, $B0, $56, $56, $56
L8D10:  .byte $56

MessageColor:
L8D11:  .byte $E1, $E1, $E1, $E1, $E1, $E4, $E3, $E6
L8D19:  .byte $E7, $E7, $E7, $E7, $E7, $E7, $E7, $E7
L8D21:  .byte $E7

MessageNumberRealMessage:
L8D22:  .byte $22, $1D, $1E, $1F, $20, $21, $23, $24
L8D2A:  .byte $0B, $0C, $1A, $1B, $1C, $19, $10, $11
L8D32:  .byte $25
L8D33:  SEI
L8D34:  CLD
L8D35:  LDA  #$FF
L8D37:  STA  EAC2
L8D39:  BNE  L8D4C
L8D3B:  LDA  VGBRIT
L8D3D:  BEQ  L8D4C
L8D3F:  LDA  HALT
L8D42:  AND  #$40
L8D44:  BEQ  L8D4C
L8D46:  STA  STOPAD
L8D49:  STA  GOADD
L8D4C:  STA  WTCHDG
L8D4F:  LDA  HALT
L8D52:  AND  #$10
L8D54:  BEQ  L8D57
L8D56:  BRK
L8D57:  LDA  #$00
L8D59:  STA  VGBRIT
L8D5B:  LDA  CABERE
L8D5E:  ROL
L8D5F:  ROL
L8D60:  ROL  VGBRIT
L8D62:  LDA  GAMSEL
L8D65:  ROL
L8D66:  ROL
L8D67:  ROL  VGBRIT
L8D69:  LDA  OPTNA1
L8D6C:  ROL
L8D6D:  ROL
L8D6E:  ROL  VGBRIT
L8D70:  LDA  VGBRIT
L8D72:  CMP  EAC2
L8D74:  BEQ  L8D3B
L8D76:  STA  EAC2
L8D78:  TAX
L8D79:  BEQ  L8D9C
L8D7B:  LDA  #$C7
L8D7D:  STA  VECMEM
L8D80:  LDA  #$60
L8D82:  STA  $2001
L8D85:  LDY  $8DC0,X
L8D88:  LDA  $8DC8,X
L8D8B:  TAX
L8D8C:  LDA  $8DD0,Y
L8D8F:  STA  $2002,X
L8D92:  DEY
L8D93:  DEX
L8D94:  BPL  L8D8C
L8D96:  STA  STOPAD
L8D99:  JMP  L8D3B
L8D9C:  LDA  #$20
L8D9E:  STA  RED
L8DA0:  LDA  #$00
L8DA2:  STA  XCOMP
L8DA4:  STA  VGLIST
L8DA6:  TAY
L8DA7:  LDA  #$08
L8DA9:  STA  VGBRIT
L8DAB:  CLC
L8DAC:  LDA  VGLIST
L8DAE:  STA  (XCOMP),Y
L8DB0:  ADC  #$05
L8DB2:  STA  VGLIST
L8DB4:  INY
L8DB5:  BNE  L8DAB
L8DB7:  INC  RED
L8DB9:  DEC  VGBRIT
L8DBB:  BNE  L8DAB
L8DBD:  JMP  L8D96
L8DC0:  .byte $01, $01, $15, $2B, $45, $71, $01, $01
L8DC8:  .byte $01, $01, $13, $15, $19, $2B, $01, $01
L8DD0:  .byte $00, $20, $40, $80, $00, $71, $80, $01
L8DD8:  .byte $00, $22, $40, $80, $00, $60, $80, $1E
L8DE0:  .byte $00, $3E, $40, $80, $00, $20, $40, $80
L8DE8:  .byte $00, $71, $80, $01, $00, $22, $07, $E0
L8DF0:  .byte $00, $20, $40, $80, $80, $1E, $00, $3E
L8DF8:  .byte $40, $80, $00, $20, $40, $80, $00, $71
L8E00:  .byte $80, $01, $00, $22, $07, $E0, $00, $20
L8E08:  .byte $40, $80, $80, $1E, $00, $3E, $40, $80
L8E10:  .byte $2F, $51, $40, $80, $00, $20, $40, $80
L8E18:  .byte $00, $71, $80, $01, $00, $22, $07, $E0
L8E20:  .byte $00, $20, $40, $80, $80, $1E, $00, $3E
L8E28:  .byte $40, $80, $2F, $51, $40, $80, $11, $A0
L8E30:  .byte $20, $51, $40, $80, $00, $20, $13, $A0
L8E38:  .byte $00, $C0, $15, $A0, $00, $C0, $2F, $40
L8E40:  .byte $00, $C0

AddRtslToVector:
L8E42:  LDA  #$C0                   ;DXXX IS RTSL
L8E44:  BNE  Vghal1                 ;ALWASY

AddHaltToVector:
L8E46:  LDA  #$20                   ;BXXX IS HALT

Vghal1:
L8E48:  LDY  #$00
L8E4A:  STA  (VGLIST),Y
L8E4C:  JMP  Vgwai1                 ;ADD LAST BYTE

DisplayDigitWithZero:
L8E4F:  BCC  DisplayDigit           ;IF NO ZERO SUPPRESSION
L8E51:  AND  #$0F
L8E53:  BEQ  SaveCFlag              ;LEAVE C SET

DisplayDigit:
L8E55:  AND  #$0F
L8E57:  CLC
L8E58:  ADC  #$01                   ;CLEARS C BIT

SaveCFlag:
L8E5A:  PHP                         ;SAVE C FLAG
L8E5B:  ASL
L8E5C:  LDY  #$00
L8E5E:  TAX
L8E5F:  LDA  UPDOWN
L8E62:  ASL
L8E63:  LDA  $324A,X
L8E66:  BCC  SaveCFlag_20           ;NORMAL
L8E68:  LDA  $3458,X

SaveCFlag_20:
L8E6B:  STA  (VGLIST),Y
L8E6D:  LDA  $324B,X                ;COPY JSRL TO CHARACTER ROUTINE
L8E70:  BCC  SaveCFlag_30           ;NORMAL
L8E72:  LDA  $3459,X

SaveCFlag_30:
L8E75:  INY
L8E76:  STA  (VGLIST),Y
L8E78:  JSR  AddY1ToVector          ;UPDATE VECTOR LIST POINTER
L8E7B:  PLP                         ;RESTORE C FLAG
L8E7C:  RTS

AddJmplToVector:
L8E7D:  LSR
L8E7E:  AND  #$0F                   ;BASE ADDRESS IS RELATIVE TO ZERO
L8E80:  ORA  #$E0

Vgjmp1:
L8E82:  LDY  #$01
L8E84:  STA  (VGLIST),Y             ;SAVE MSB + OPCODE
L8E86:  DEY
L8E87:  TXA
L8E88:  ROR
L8E89:  STA  (VGLIST),Y             ;LSB OF ADDRESS
L8E8B:  INY
L8E8C:  BNE  AddY1ToVector          ;UPDATE VECTOR POINTER

AddJsrlToVector:
L8E8E:  LSR
L8E8F:  AND  #$0F                   ;BASE ADDRESS IS RELATIVE
L8E91:  ORA  #$A0
L8E93:  BNE  Vgjmp1                 ;MOVE INTO VECTOR LIST

VglistVglist1Vector:
L8E95:  LDY  VGBRIT

SetVectorGeneratorStatus:
L8E97:  LDX  #$64

Vgsta2:
L8E99:  TYA
L8E9A:  JMP  Add2WordsToVector      ;ADD 2 BYTES TO VECTOR LIST

SetHoldingBufferZ:
L8E9D:  LDX  #$60
L8E9F:  BNE  Vgsta2                 ;ALWAYS

CenterBeamInMiddle:
L8EA1:  LDA  #$40                   ;TIMER + SCALE
L8EA3:  LDX  #$80                   ;OPCODE

Add2WordsToVector:
L8EA5:  LDY  #$00

LsbByte:
L8EA7:  STA  (VGLIST),Y             ;LSB BYTE
L8EA9:  INY
L8EAA:  TXA

MsbByte:
L8EAB:  STA  (VGLIST),Y             ;MSB BYTE

AddY1ToVector:
L8EAD:  TYA                         ;ADD 1+(Y) TO VGLIST
L8EAE:  SEC
L8EAF:  ADC  VGLIST
L8EB1:  STA  VGLIST
L8EB3:  BCC  AddY1ToVector_10
L8EB5:  INC  EAC2

AddY1ToVector_10:
L8EB7:  RTS

UseFullSize:
L8EB8:  LDY  #$00                   ;USE FULL SIZE

SetVectorGeneratorScale:
L8EBA:  ORA  #$70                   ;OPCODE + SCALE SIZE
L8EBC:  TAX
L8EBD:  TYA
L8EBE:  JMP  Add2WordsToVector      ;ADD 2 BYTES TO VECTOR LIST

UpdownVectorUpsideDown:
L8EC1:  LDY  #$00

ShortFormVgvctrCall:
L8EC3:  STY  VGBRIT

Vgvtr1:
L8EC5:  LDY  #$00

Vgvtr3:
L8EC7:  BIT  UPDOWN
L8ECA:  BPL  Vgvtr3_8               ;NORMAL
L8ECC:  EOR  #$FF
L8ECE:  CLC
L8ECF:  ADC  #$01

Vgvtr3_8:
L8ED1:  ASL
L8ED2:  BCC  Vgvtr3_10              ;SIGN EXTEND
L8ED4:  DEY                         ;Y=-1

Vgvtr3_10:
L8ED5:  STY  RED                    ;WITH SCALE=0 A=1 MEANS=DOTS ON XY
L8ED7:  ASL
L8ED8:  ROL  RED
L8EDA:  STA  XCOMP
L8EDC:  TXA                         ;WRITE Y VALUE TO XCOMP+2,XCOMP+3
L8EDD:  BIT  UPDOWN
L8EE0:  BPL  Vgvtr3_15              ;NORMAL
L8EE2:  EOR  #$FF
L8EE4:  CLC
L8EE5:  ADC  #$01

Vgvtr3_15:
L8EE7:  ASL
L8EE8:  LDY  #$00
L8EEA:  BCC  Vgvtr3_20              ;SIGN EXTEND
L8EEC:  DEY                         ;Y=-1

Vgvtr3_20:
L8EED:  STY  TWOPI
L8EEF:  ASL
L8EF0:  ROL  TWOPI
L8EF2:  STA  CHAN3V

Vgvtr2:
L8EF4:  LDX  #$03

AddVectorToVector:
L8EF6:  LDY  #$00

Lsb:
L8EF8:  LDA  EAC2,X                 ;Y LSB
L8EFA:  STA  (VGLIST),Y
L8EFC:  LDA  XCOMP,X                ;Y MSB
L8EFE:  AND  #$1F                   ;CLEAR SIGN EXTENSION
L8F00:  INY
L8F01:  STA  (VGLIST),Y
L8F03:  LDA  VGBRIT,X               ;X LSB
L8F05:  INY
L8F06:  STA  (VGLIST),Y
L8F08:  LDA  VGLIST,X               ;X MSB
L8F0A:  EOR  VGBRIT
L8F0C:  AND  #$1F                   ;CLEAR SIGN EXTENSION
L8F0E:  EOR  VGBRIT                 ;COMBINE UPPER 3 BITS OF VGBRIT WITH X MSB

Vgwai1:
L8F10:  INY
L8F11:  STA  (VGLIST),Y             ;SET INTENSITY
L8F13:  BNE  AddY1ToVector          ;ALWAYS - UPDATE VGLIST POINTER

NegateALongVector:
L8F15:  LDY  #$00
L8F17:  LDA  (TEMP2),Y
L8F19:  EOR  #$FF
L8F1B:  CLC
L8F1C:  ADC  #$01
L8F1E:  STA  (VGLIST),Y             ;Y LSBYTE
L8F20:  INY
L8F21:  LDA  (TEMP2),Y
L8F23:  EOR  #$FF
L8F25:  ADC  #$00
L8F27:  AND  #$1F                   ;LEAVE INSTRUCTION OF OOO
L8F29:  STA  (VGLIST),Y             ;Y UPPER WITH INSTRUCTION
L8F2B:  INY
L8F2C:  LDA  (TEMP2),Y
L8F2E:  EOR  #$FF
L8F30:  CLC
L8F31:  ADC  #$01
L8F33:  STA  (VGLIST),Y             ;X LSBYTE
L8F35:  INY
L8F36:  LDA  (TEMP2),Y
L8F38:  EOR  #$FF
L8F3A:  ADC  #$00
L8F3C:  AND  #$1F                   ;INTENSITY TO ZERO
L8F3E:  STA  (VGLIST),Y             ;INTENSITY + X UPPER
L8F40:  JMP  AddY1ToVector
L8F43:  SEI                         ;NO INTERRUPTS
L8F44:  STA  $100B
L8F47:  LDA  $1008
L8F4A:  CLI                         ;GOT IT
L8F4B:  EOR  #$85
L8F4D:  LSR
L8F4E:  LSR
L8F4F:  AND  #$03                   ;THIS IS DIFFICULTY SWITCH SETTING
L8F51:  CLC
L8F52:  RTS
L8F53:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L8F5B:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L8F63:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L8F6B:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L8F73:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L8F7B:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L8F83:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L8F8B:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L8F93:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L8F9B:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L8FA3:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L8FAB:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L8FB3:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L8FBB:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L8FC3:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L8FCB:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L8FD3:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L8FDB:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L8FE3:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L8FEB:  .byte $00, $00, $00, $00, $00, $00, $00, $00
L8FF3:  .byte $00, $00, $00, $00, $00, $00, $00, $3F
L8FFB:  .byte $80, $3F, $80, $39, $86
