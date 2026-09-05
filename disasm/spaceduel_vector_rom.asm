;Space Duel (Atari, 1982) - vector ROMs, byte-exact listing.
;
;  $2800-$2FFF  136006-106  ship PICTURE data - NOT AVG. A 34-entry
;               pointer table, then pictures built from 2-byte signed
;               (dy,dx) records (A2SHIP.MAC TWBYPIC -> .BYTE YY,XX)
;               which SHPDISPLAYS expands into vectors at run time.
;  $3000-$3FFF  136006-107  real AVG display lists (AS2ROM.MAC), then
;               zero fill and the CKUM1 checksum byte at $3FFF.
;
;AVG deltas are 13-bit TWO'S COMPLEMENT (see aae_avg.cpp twos_comp_val
;and VGMC.MAC's .WORD DY&^H1FFF) - not the sign-magnitude of the DVG.
;Space Duel is the colour XY board, so COLOR replaces STAT.
;Every line below was re-encoded and byte-compared with the ROM.
;Shapes are labelled with Atari's own names; see vec_names.py for the
;name table and shapes_preview.html for rendered previews.

.org $2800

;------------------------[ ship picture pointer table ]------------------------
V2800:  .word $2844              ;[ 0] -> SHPA0
V2802:  .word $287A              ;[ 1] -> SHPA1
V2804:  .word $28B0              ;[ 2] -> SHPA2
V2806:  .word $2900              ;[ 3] -> SHPA3
V2808:  .word $2936              ;[ 4] -> SHPA4
V280A:  .word $296C              ;[ 5] -> SHPA5
V280C:  .word $29A2              ;[ 6] -> SHPA6
V280E:  .word $2A00              ;[ 7] -> SHPA7
V2810:  .word $2A36              ;[ 8] -> SHPA8
V2812:  .word $2A6C              ;[ 9] -> SHPA9
V2814:  .word $2AA2              ;[10] -> SHPA10
V2816:  .word $2B00              ;[11] -> SHPA11
V2818:  .word $2B36              ;[12] -> SHPA12
V281A:  .word $2B6C              ;[13] -> SHPA13
V281C:  .word $2BA2              ;[14] -> SHPA14
V281E:  .word $2C00              ;[15] -> SHPA15
V2820:  .word $2C36              ;[16] -> SHPA16
V2822:  .word $2C6C              ;[17] -> SHPB0
V2824:  .word $2C9E              ;[18] -> SHPB1
V2826:  .word $2D00              ;[19] -> SHPB2
V2828:  .word $2D32              ;[20] -> SHPB3
V282A:  .word $2D64              ;[21] -> SHPB4
V282C:  .word $2D96              ;[22] -> SHPB5
V282E:  .word $2DC8              ;[23] -> SHPB6
V2830:  .word $2E00              ;[24] -> SHPB7
V2832:  .word $2E32              ;[25] -> SHPB8
V2834:  .word $2E64              ;[26] -> SHPB9
V2836:  .word $2E96              ;[27] -> SHPB10
V2838:  .word $2EC8              ;[28] -> SHPB11
V283A:  .word $2F00              ;[29] -> SHPB12
V283C:  .word $2F32              ;[30] -> SHPB13
V283E:  .word $2F64              ;[31] -> SHPB14
V2840:  .word $2F96              ;[32] -> SHPB15
V2842:  .word $2FC8              ;[33] -> SHPB16

;----------------------------[ ship pictures ]----------------------------

SHPA0:  ;type A: 23 ship records + 4 thrust-flame, 2 bytes each
V2844:  .byte $14, $F4          ;dy=20    dx=-12   move (blanked by SHPDI8 epilogue)
V2846:  .byte $F0, $18          ;dy=-16   dx=24    ship
V2848:  .byte $00, $02          ;dy=0     dx=2     ship
V284A:  .byte $06, $00          ;dy=6     dx=0     ship
V284C:  .byte $00, $04          ;dy=0     dx=4     ship
V284E:  .byte $FA, $02          ;dy=-6    dx=2     ship
V2850:  .byte $00, $04          ;dy=0     dx=4     ship
V2852:  .byte $FC, $0C          ;dy=-4    dx=12    ship
V2854:  .byte $FC, $F4          ;dy=-4    dx=-12   ship
V2856:  .byte $00, $FC          ;dy=0     dx=-4    ship
V2858:  .byte $FA, $F9          ;dy=-6    dx=-7    ship
V285A:  .byte $00, $01          ;dy=0     dx=1     ship
V285C:  .byte $06, $00          ;dy=6     dx=0     ship
V285E:  .byte $00, $FE          ;dy=0     dx=-2    ship
V2860:  .byte $F0, $E8          ;dy=-16   dx=-24   ship
V2862:  .byte $00, $F0          ;dy=0     dx=-16   ship
V2864:  .byte $0A, $00          ;dy=10    dx=0     ship
V2866:  .byte $02, $FC          ;dy=2     dx=-4    ship
V2868:  .byte $10, $00          ;dy=16    dx=0     ship
V286A:  .byte $02, $04          ;dy=2     dx=4     ship
V286C:  .byte $0A, $00          ;dy=10    dx=0     ship
V286E:  .byte $00, $10          ;dy=0     dx=16    ship
V2870:  .byte $EC, $0C          ;dy=-20   dx=12    move (blanked: return leg / flame bridge)
V2872:  .byte $F8, $E0          ;dy=-8    dx=-32   thrust flame (white)
V2874:  .byte $08, $EC          ;dy=8     dx=-20   thrust flame (white)
V2876:  .byte $08, $14          ;dy=8     dx=20    thrust flame (white)
V2878:  .byte $F8, $20          ;dy=-8    dx=32    thrust flame (white)

SHPA1:  ;type A: 23 ship records + 4 thrust-flame, 2 bytes each
V287A:  .byte $13, $F2          ;dy=19    dx=-14   move (blanked by SHPDI8 epilogue)
V287C:  .byte $F2, $1A          ;dy=-14   dx=26    ship
V287E:  .byte $00, $02          ;dy=0     dx=2     ship
V2880:  .byte $06, $FF          ;dy=6     dx=-1    ship
V2882:  .byte $01, $04          ;dy=1     dx=4     ship
V2884:  .byte $FA, $03          ;dy=-6    dx=3     ship
V2886:  .byte $00, $03          ;dy=0     dx=3     ship
V2888:  .byte $FE, $0D          ;dy=-2    dx=13    ship
V288A:  .byte $FA, $F4          ;dy=-6    dx=-12   ship
V288C:  .byte $00, $FC          ;dy=0     dx=-4    ship
V288E:  .byte $F9, $FA          ;dy=-7    dx=-6    ship
V2890:  .byte $00, $01          ;dy=0     dx=1     ship
V2892:  .byte $06, $FF          ;dy=6     dx=-1    ship
V2894:  .byte $00, $FE          ;dy=0     dx=-2    ship
V2896:  .byte $EE, $EA          ;dy=-18   dx=-22   ship
V2898:  .byte $FE, $F0          ;dy=-2    dx=-16   ship
V289A:  .byte $0A, $FF          ;dy=10    dx=-1    ship
V289C:  .byte $02, $FC          ;dy=2     dx=-4    ship
V289E:  .byte $10, $FE          ;dy=16    dx=-2    ship
V28A0:  .byte $02, $04          ;dy=2     dx=4     ship
V28A2:  .byte $0A, $FF          ;dy=10    dx=-1    ship
V28A4:  .byte $02, $10          ;dy=2     dx=16    ship
V28A6:  .byte $ED, $0E          ;dy=-19   dx=14    move (blanked: return leg / flame bridge)
V28A8:  .byte $F5, $E1          ;dy=-11   dx=-31   thrust flame (white)
V28AA:  .byte $06, $EB          ;dy=6     dx=-21   thrust flame (white)
V28AC:  .byte $0A, $13          ;dy=10    dx=19    thrust flame (white)
V28AE:  .byte $FB, $21          ;dy=-5    dx=33    thrust flame (white)

SHPA2:  ;type A: 23 ship records + 4 thrust-flame, 2 bytes each
V28B0:  .byte $11, $F0          ;dy=17    dx=-16   move (blanked by SHPDI8 epilogue)
V28B2:  .byte $F5, $1B          ;dy=-11   dx=27    ship
V28B4:  .byte $01, $02          ;dy=1     dx=2     ship
V28B6:  .byte $06, $FF          ;dy=6     dx=-1    ship
V28B8:  .byte $00, $04          ;dy=0     dx=4     ship
V28BA:  .byte $FB, $03          ;dy=-5    dx=3     ship
V28BC:  .byte $01, $04          ;dy=1     dx=4     ship
V28BE:  .byte $FE, $0C          ;dy=-2    dx=12    ship
V28C0:  .byte $FA, $F5          ;dy=-6    dx=-11   ship
V28C2:  .byte $FF, $FC          ;dy=-1    dx=-4    ship
V28C4:  .byte $F9, $FB          ;dy=-7    dx=-5    ship
V28C6:  .byte $00, $01          ;dy=0     dx=1     ship
V28C8:  .byte $06, $FF          ;dy=6     dx=-1    ship
V28CA:  .byte $FF, $FE          ;dy=-1    dx=-2    ship
V28CC:  .byte $EC, $EB          ;dy=-20   dx=-21   ship
V28CE:  .byte $FD, $F0          ;dy=-3    dx=-16   ship
V28D0:  .byte $0A, $FE          ;dy=10    dx=-2    ship
V28D2:  .byte $01, $FC          ;dy=1     dx=-4    ship
V28D4:  .byte $10, $FD          ;dy=16    dx=-3    ship
V28D6:  .byte $02, $04          ;dy=2     dx=4     ship
V28D8:  .byte $0A, $FE          ;dy=10    dx=-2    ship
V28DA:  .byte $03, $0F          ;dy=3     dx=15    ship
V28DC:  .byte $EF, $10          ;dy=-17   dx=16    move (blanked: return leg / flame bridge)
V28DE:  .byte $F2, $E2          ;dy=-14   dx=-30   thrust flame (white)
V28E0:  .byte $04, $EB          ;dy=4     dx=-21   thrust flame (white)
V28E2:  .byte $0C, $12          ;dy=12    dx=18    thrust flame (white)
V28E4:  .byte $FE, $21          ;dy=-2    dx=33    thrust flame (white)

SHPA3:  ;type A: 23 ship records + 4 thrust-flame, 2 bytes each
V2900:  .byte $10, $EF          ;dy=16    dx=-17   move (blanked by SHPDI8 epilogue)
V2902:  .byte $F7, $1B          ;dy=-9    dx=27    ship
V2904:  .byte $01, $02          ;dy=1     dx=2     ship
V2906:  .byte $06, $FE          ;dy=6     dx=-2    ship
V2908:  .byte $01, $04          ;dy=1     dx=4     ship
V290A:  .byte $FB, $04          ;dy=-5    dx=4     ship
V290C:  .byte $01, $04          ;dy=1     dx=4     ship
V290E:  .byte $FF, $0C          ;dy=-1    dx=12    ship
V2910:  .byte $F9, $F6          ;dy=-7    dx=-10   ship
V2912:  .byte $FF, $FC          ;dy=-1    dx=-4    ship
V2914:  .byte $F8, $FB          ;dy=-8    dx=-5    ship
V2916:  .byte $00, $01          ;dy=0     dx=1     ship
V2918:  .byte $06, $FF          ;dy=6     dx=-1    ship
V291A:  .byte $00, $FE          ;dy=0     dx=-2    ship
V291C:  .byte $E9, $ED          ;dy=-23   dx=-19   ship
V291E:  .byte $FC, $F1          ;dy=-4    dx=-15   ship
V2920:  .byte $09, $FD          ;dy=9     dx=-3    ship
V2922:  .byte $01, $FC          ;dy=1     dx=-4    ship
V2924:  .byte $0F, $FB          ;dy=15    dx=-5    ship
V2926:  .byte $03, $03          ;dy=3     dx=3     ship
V2928:  .byte $0A, $FD          ;dy=10    dx=-3    ship
V292A:  .byte $05, $10          ;dy=5     dx=16    ship
V292C:  .byte $F0, $11          ;dy=-16   dx=17    move (blanked: return leg / flame bridge)
V292E:  .byte $EF, $E4          ;dy=-17   dx=-28   thrust flame (white)
V2930:  .byte $02, $EA          ;dy=2     dx=-22   thrust flame (white)
V2932:  .byte $0D, $11          ;dy=13    dx=17    thrust flame (white)
V2934:  .byte $02, $21          ;dy=2     dx=33    thrust flame (white)

SHPA4:  ;type A: 23 ship records + 4 thrust-flame, 2 bytes each
V2936:  .byte $0E, $ED          ;dy=14    dx=-19   move (blanked by SHPDI8 epilogue)
V2938:  .byte $FA, $1D          ;dy=-6    dx=29    ship
V293A:  .byte $01, $01          ;dy=1     dx=1     ship
V293C:  .byte $06, $FE          ;dy=6     dx=-2    ship
V293E:  .byte $01, $04          ;dy=1     dx=4     ship
V2940:  .byte $FB, $04          ;dy=-5    dx=4     ship
V2942:  .byte $02, $04          ;dy=2     dx=4     ship
V2944:  .byte $01, $0C          ;dy=1     dx=12    ship
V2946:  .byte $F7, $F7          ;dy=-9    dx=-9    ship
V2948:  .byte $FF, $FC          ;dy=-1    dx=-4    ship
V294A:  .byte $F8, $FC          ;dy=-8    dx=-4    ship
V294C:  .byte $00, $01          ;dy=0     dx=1     ship
V294E:  .byte $06, $FD          ;dy=6     dx=-3    ship
V2950:  .byte $FF, $FF          ;dy=-1    dx=-1    ship
V2952:  .byte $E8, $F0          ;dy=-24   dx=-16   ship
V2954:  .byte $FA, $F1          ;dy=-6    dx=-15   ship
V2956:  .byte $09, $FC          ;dy=9     dx=-4    ship
V2958:  .byte $00, $FB          ;dy=0     dx=-5    ship
V295A:  .byte $0F, $FA          ;dy=15    dx=-6    ship
V295C:  .byte $04, $03          ;dy=4     dx=3     ship
V295E:  .byte $09, $FC          ;dy=9     dx=-4    ship
V2960:  .byte $06, $0F          ;dy=6     dx=15    ship
V2962:  .byte $F2, $13          ;dy=-14   dx=19    move (blanked: return leg / flame bridge)
V2964:  .byte $EC, $E5          ;dy=-20   dx=-27   thrust flame (white)
V2966:  .byte $00, $EB          ;dy=0     dx=-21   thrust flame (white)
V2968:  .byte $0F, $0F          ;dy=15    dx=15    thrust flame (white)
V296A:  .byte $05, $21          ;dy=5     dx=33    thrust flame (white)

SHPA5:  ;type A: 23 ship records + 4 thrust-flame, 2 bytes each
V296C:  .byte $0C, $EC          ;dy=12    dx=-20   move (blanked by SHPDI8 epilogue)
V296E:  .byte $FD, $1D          ;dy=-3    dx=29    ship
V2970:  .byte $01, $01          ;dy=1     dx=1     ship
V2972:  .byte $05, $FE          ;dy=5     dx=-2    ship
V2974:  .byte $02, $03          ;dy=2     dx=3     ship
V2976:  .byte $FC, $05          ;dy=-4    dx=5     ship
V2978:  .byte $02, $03          ;dy=2     dx=3     ship
V297A:  .byte $02, $0D          ;dy=2     dx=13    ship
V297C:  .byte $F7, $F7          ;dy=-9    dx=-9    ship
V297E:  .byte $FE, $FD          ;dy=-2    dx=-3    ship
V2980:  .byte $F7, $FC          ;dy=-9    dx=-4    ship
V2982:  .byte $01, $01          ;dy=1     dx=1     ship
V2984:  .byte $05, $FD          ;dy=5     dx=-3    ship
V2986:  .byte $FF, $FE          ;dy=-1    dx=-2    ship
V2988:  .byte $E7, $F3          ;dy=-25   dx=-13   ship
V298A:  .byte $F8, $F2          ;dy=-8    dx=-14   ship
V298C:  .byte $09, $FB          ;dy=9     dx=-5    ship
V298E:  .byte $00, $FC          ;dy=0     dx=-4    ship
V2990:  .byte $0E, $F8          ;dy=14    dx=-8    ship
V2992:  .byte $04, $03          ;dy=4     dx=3     ship
V2994:  .byte $08, $FB          ;dy=8     dx=-5    ship
V2996:  .byte $08, $0E          ;dy=8     dx=14    ship
V2998:  .byte $F4, $14          ;dy=-12   dx=20    move (blanked: return leg / flame bridge)
V299A:  .byte $EA, $E8          ;dy=-22   dx=-24   thrust flame (white)
V299C:  .byte $FD, $EA          ;dy=-3    dx=-22   thrust flame (white)
V299E:  .byte $11, $0E          ;dy=17    dx=14    thrust flame (white)
V29A0:  .byte $08, $20          ;dy=8     dx=32    thrust flame (white)

SHPA6:  ;type A: 23 ship records + 4 thrust-flame, 2 bytes each
V29A2:  .byte $0A, $EB          ;dy=10    dx=-21   move (blanked by SHPDI8 epilogue)
V29A4:  .byte $00, $1D          ;dy=0     dx=29    ship
V29A6:  .byte $01, $01          ;dy=1     dx=1     ship
V29A8:  .byte $05, $FD          ;dy=5     dx=-3    ship
V29AA:  .byte $02, $03          ;dy=2     dx=3     ship
V29AC:  .byte $FC, $05          ;dy=-4    dx=5     ship
V29AE:  .byte $03, $04          ;dy=3     dx=4     ship
V29B0:  .byte $03, $0C          ;dy=3     dx=12    ship
V29B2:  .byte $F6, $F8          ;dy=-10   dx=-8    ship
V29B4:  .byte $FE, $FD          ;dy=-2    dx=-3    ship
V29B6:  .byte $F7, $FD          ;dy=-9    dx=-3    ship
V29B8:  .byte $00, $01          ;dy=0     dx=1     ship
V29BA:  .byte $05, $FD          ;dy=5     dx=-3    ship
V29BC:  .byte $FF, $FE          ;dy=-1    dx=-2    ship
V29BE:  .byte $E6, $F5          ;dy=-26   dx=-11   ship
V29C0:  .byte $F7, $F3          ;dy=-9    dx=-13   ship
V29C2:  .byte $08, $FA          ;dy=8     dx=-6    ship
V29C4:  .byte $00, $FC          ;dy=0     dx=-4    ship
V29C6:  .byte $0D, $F7          ;dy=13    dx=-9    ship
V29C8:  .byte $04, $02          ;dy=4     dx=2     ship
V29CA:  .byte $08, $FB          ;dy=8     dx=-5    ship
V29CC:  .byte $09, $0D          ;dy=9     dx=13    ship
V29CE:  .byte $F4, $14          ;dy=-12   dx=20    move (blanked: return leg / flame bridge)
V29D0:  .byte $E8, $EA          ;dy=-24   dx=-22   thrust flame (white)
V29D2:  .byte $FB, $EB          ;dy=-5    dx=-21   thrust flame (white)
V29D4:  .byte $12, $0C          ;dy=18    dx=12    thrust flame (white)
V29D6:  .byte $0B, $1F          ;dy=11    dx=31    thrust flame (white)

SHPA7:  ;type A: 23 ship records + 4 thrust-flame, 2 bytes each
V2A00:  .byte $08, $EA          ;dy=8     dx=-22   move (blanked by SHPDI8 epilogue)
V2A02:  .byte $03, $1D          ;dy=3     dx=29    ship
V2A04:  .byte $01, $01          ;dy=1     dx=1     ship
V2A06:  .byte $05, $FC          ;dy=5     dx=-4    ship
V2A08:  .byte $02, $04          ;dy=2     dx=4     ship
V2A0A:  .byte $FD, $05          ;dy=-3    dx=5     ship
V2A0C:  .byte $02, $03          ;dy=2     dx=3     ship
V2A0E:  .byte $05, $0C          ;dy=5     dx=12    ship
V2A10:  .byte $F5, $F9          ;dy=-11   dx=-7    ship
V2A12:  .byte $FE, $FD          ;dy=-2    dx=-3    ship
V2A14:  .byte $F7, $FE          ;dy=-9    dx=-2    ship
V2A16:  .byte $00, $01          ;dy=0     dx=1     ship
V2A18:  .byte $05, $FC          ;dy=5     dx=-4    ship
V2A1A:  .byte $FF, $FF          ;dy=-1    dx=-1    ship
V2A1C:  .byte $E4, $F7          ;dy=-28   dx=-9    ship
V2A1E:  .byte $F6, $F4          ;dy=-10   dx=-12   ship
V2A20:  .byte $08, $FA          ;dy=8     dx=-6    ship
V2A22:  .byte $FF, $FB          ;dy=-1    dx=-5    ship
V2A24:  .byte $0C, $F6          ;dy=12    dx=-10   ship
V2A26:  .byte $04, $02          ;dy=4     dx=2     ship
V2A28:  .byte $08, $FA          ;dy=8     dx=-6    ship
V2A2A:  .byte $0A, $0C          ;dy=10    dx=12    ship
V2A2C:  .byte $F8, $16          ;dy=-8    dx=22    move (blanked: return leg / flame bridge)
V2A2E:  .byte $E6, $EC          ;dy=-26   dx=-20   thrust flame (white)
V2A30:  .byte $F9, $EC          ;dy=-7    dx=-20   thrust flame (white)
V2A32:  .byte $13, $0A          ;dy=19    dx=10    thrust flame (white)
V2A34:  .byte $0E, $1E          ;dy=14    dx=30    thrust flame (white)

SHPA8:  ;type A: 23 ship records + 4 thrust-flame, 2 bytes each
V2A36:  .byte $06, $E9          ;dy=6     dx=-23   move (blanked by SHPDI8 epilogue)
V2A38:  .byte $05, $1D          ;dy=5     dx=29    ship
V2A3A:  .byte $02, $01          ;dy=2     dx=1     ship
V2A3C:  .byte $04, $FC          ;dy=4     dx=-4    ship
V2A3E:  .byte $03, $03          ;dy=3     dx=3     ship
V2A40:  .byte $FD, $05          ;dy=-3    dx=5     ship
V2A42:  .byte $03, $03          ;dy=3     dx=3     ship
V2A44:  .byte $05, $0B          ;dy=5     dx=11    ship
V2A46:  .byte $F5, $FB          ;dy=-11   dx=-5    ship
V2A48:  .byte $FD, $FD          ;dy=-3    dx=-3    ship
V2A4A:  .byte $F7, $FF          ;dy=-9    dx=-1    ship
V2A4C:  .byte $01, $01          ;dy=1     dx=1     ship
V2A4E:  .byte $04, $FC          ;dy=4     dx=-4    ship
V2A50:  .byte $FF, $FE          ;dy=-1    dx=-2    ship
V2A52:  .byte $E3, $FB          ;dy=-29   dx=-5    ship
V2A54:  .byte $F5, $F4          ;dy=-11   dx=-12   ship
V2A56:  .byte $07, $F9          ;dy=7     dx=-7    ship
V2A58:  .byte $FF, $FC          ;dy=-1    dx=-4    ship
V2A5A:  .byte $0B, $F5          ;dy=11    dx=-11   ship
V2A5C:  .byte $04, $01          ;dy=4     dx=1     ship
V2A5E:  .byte $07, $F9          ;dy=7     dx=-7    ship
V2A60:  .byte $0C, $0B          ;dy=12    dx=11    ship
V2A62:  .byte $FA, $17          ;dy=-6    dx=23    move (blanked: return leg / flame bridge)
V2A64:  .byte $E4, $EF          ;dy=-28   dx=-17   thrust flame (white)
V2A66:  .byte $F7, $EC          ;dy=-9    dx=-20   thrust flame (white)
V2A68:  .byte $14, $09          ;dy=20    dx=9     thrust flame (white)
V2A6A:  .byte $11, $1C          ;dy=17    dx=28    thrust flame (white)

SHPA9:  ;type A: 23 ship records + 4 thrust-flame, 2 bytes each
V2A6C:  .byte $03, $E9          ;dy=3     dx=-23   move (blanked by SHPDI8 epilogue)
V2A6E:  .byte $09, $1C          ;dy=9     dx=28    ship
V2A70:  .byte $01, $01          ;dy=1     dx=1     ship
V2A72:  .byte $04, $FB          ;dy=4     dx=-5    ship
V2A74:  .byte $03, $03          ;dy=3     dx=3     ship
V2A76:  .byte $FE, $06          ;dy=-2    dx=6     ship
V2A78:  .byte $03, $02          ;dy=3     dx=2     ship
V2A7A:  .byte $07, $0B          ;dy=7     dx=11    ship
V2A7C:  .byte $F4, $FB          ;dy=-12   dx=-5    ship
V2A7E:  .byte $FD, $FE          ;dy=-3    dx=-2    ship
V2A80:  .byte $F7, $00          ;dy=-9    dx=0     ship
V2A82:  .byte $00, $01          ;dy=0     dx=1     ship
V2A84:  .byte $04, $FB          ;dy=4     dx=-5    ship
V2A86:  .byte $FF, $FF          ;dy=-1    dx=-1    ship
V2A88:  .byte $E3, $FD          ;dy=-29   dx=-3    ship
V2A8A:  .byte $F4, $F6          ;dy=-12   dx=-10   ship
V2A8C:  .byte $06, $F8          ;dy=6     dx=-8    ship
V2A8E:  .byte $FE, $FC          ;dy=-2    dx=-4    ship
V2A90:  .byte $0A, $F4          ;dy=10    dx=-12   ship
V2A92:  .byte $05, $01          ;dy=5     dx=1     ship
V2A94:  .byte $06, $F8          ;dy=6     dx=-8    ship
V2A96:  .byte $0C, $0A          ;dy=12    dx=10    ship
V2A98:  .byte $FD, $17          ;dy=-3    dx=23    move (blanked: return leg / flame bridge)
V2A9A:  .byte $E2, $F2          ;dy=-30   dx=-14   thrust flame (white)
V2A9C:  .byte $F6, $ED          ;dy=-10   dx=-19   thrust flame (white)
V2A9E:  .byte $14, $07          ;dy=20    dx=7     thrust flame (white)
V2AA0:  .byte $14, $1A          ;dy=20    dx=26    thrust flame (white)

SHPA10:  ;type A: 23 ship records + 4 thrust-flame, 2 bytes each
V2AA2:  .byte $01, $E9          ;dy=1     dx=-23   move (blanked by SHPDI8 epilogue)
V2AA4:  .byte $0B, $1A          ;dy=11    dx=26    ship
V2AA6:  .byte $02, $01          ;dy=2     dx=1     ship
V2AA8:  .byte $03, $FB          ;dy=3     dx=-5    ship
V2AAA:  .byte $04, $03          ;dy=4     dx=3     ship
V2AAC:  .byte $FE, $06          ;dy=-2    dx=6     ship
V2AAE:  .byte $03, $02          ;dy=3     dx=2     ship
V2AB0:  .byte $08, $0A          ;dy=8     dx=10    ship
V2AB2:  .byte $F4, $FD          ;dy=-12   dx=-3    ship
V2AB4:  .byte $FC, $FD          ;dy=-4    dx=-3    ship
V2AB6:  .byte $F7, $02          ;dy=-9    dx=2     ship
V2AB8:  .byte $01, $00          ;dy=1     dx=0     ship
V2ABA:  .byte $03, $FB          ;dy=3     dx=-5    ship
V2ABC:  .byte $FF, $FF          ;dy=-1    dx=-1    ship
V2ABE:  .byte $E3, $00          ;dy=-29   dx=0     ship
V2AC0:  .byte $F3, $F7          ;dy=-13   dx=-9    ship
V2AC2:  .byte $05, $F8          ;dy=5     dx=-8    ship
V2AC4:  .byte $FE, $FC          ;dy=-2    dx=-4    ship
V2AC6:  .byte $09, $F3          ;dy=9     dx=-13   ship
V2AC8:  .byte $04, $00          ;dy=4     dx=0     ship
V2ACA:  .byte $06, $F8          ;dy=6     dx=-8    ship
V2ACC:  .byte $0D, $09          ;dy=13    dx=9     ship
V2ACE:  .byte $FF, $17          ;dy=-1    dx=23    move (blanked: return leg / flame bridge)
V2AD0:  .byte $E1, $F5          ;dy=-31   dx=-11   thrust flame (white)
V2AD2:  .byte $F4, $EE          ;dy=-12   dx=-18   thrust flame (white)
V2AD4:  .byte $15, $05          ;dy=21    dx=5     thrust flame (white)
V2AD6:  .byte $16, $18          ;dy=22    dx=24    thrust flame (white)

SHPA11:  ;type A: 23 ship records + 4 thrust-flame, 2 bytes each
V2B00:  .byte $FF, $E9          ;dy=-1    dx=-23   move (blanked by SHPDI8 epilogue)
V2B02:  .byte $0D, $19          ;dy=13    dx=25    ship
V2B04:  .byte $02, $01          ;dy=2     dx=1     ship
V2B06:  .byte $03, $FB          ;dy=3     dx=-5    ship
V2B08:  .byte $04, $02          ;dy=4     dx=2     ship
V2B0A:  .byte $FF, $06          ;dy=-1    dx=6     ship
V2B0C:  .byte $03, $02          ;dy=3     dx=2     ship
V2B0E:  .byte $09, $09          ;dy=9     dx=9     ship
V2B10:  .byte $F3, $FE          ;dy=-13   dx=-2    ship
V2B12:  .byte $FD, $FE          ;dy=-3    dx=-2    ship
V2B14:  .byte $F7, $02          ;dy=-9    dx=2     ship
V2B16:  .byte $01, $00          ;dy=1     dx=0     ship
V2B18:  .byte $02, $FB          ;dy=2     dx=-5    ship
V2B1A:  .byte $FF, $FF          ;dy=-1    dx=-1    ship
V2B1C:  .byte $E3, $03          ;dy=-29   dx=3     ship
V2B1E:  .byte $F2, $F8          ;dy=-14   dx=-8    ship
V2B20:  .byte $05, $F8          ;dy=5     dx=-8    ship
V2B22:  .byte $FD, $FC          ;dy=-3    dx=-4    ship
V2B24:  .byte $08, $F2          ;dy=8     dx=-14   ship
V2B26:  .byte $04, $00          ;dy=4     dx=0     ship
V2B28:  .byte $05, $F7          ;dy=5     dx=-9    ship
V2B2A:  .byte $0E, $08          ;dy=14    dx=8     ship
V2B2C:  .byte $01, $17          ;dy=1     dx=23    move (blanked: return leg / flame bridge)
V2B2E:  .byte $E0, $F8          ;dy=-32   dx=-8    thrust flame (white)
V2B30:  .byte $F2, $EF          ;dy=-14   dx=-17   thrust flame (white)
V2B32:  .byte $16, $03          ;dy=22    dx=3     thrust flame (white)
V2B34:  .byte $18, $16          ;dy=24    dx=22    thrust flame (white)

SHPA12:  ;type A: 23 ship records + 4 thrust-flame, 2 bytes each
V2B36:  .byte $FD, $E9          ;dy=-3    dx=-23   move (blanked by SHPDI8 epilogue)
V2B38:  .byte $10, $18          ;dy=16    dx=24    ship
V2B3A:  .byte $01, $01          ;dy=1     dx=1     ship
V2B3C:  .byte $03, $FA          ;dy=3     dx=-6    ship
V2B3E:  .byte $03, $02          ;dy=3     dx=2     ship
V2B40:  .byte $00, $06          ;dy=0     dx=6     ship
V2B42:  .byte $04, $01          ;dy=4     dx=1     ship
V2B44:  .byte $09, $09          ;dy=9     dx=9     ship
V2B46:  .byte $F4, $FF          ;dy=-12   dx=-1    ship
V2B48:  .byte $FC, $FE          ;dy=-4    dx=-2    ship
V2B4A:  .byte $F7, $03          ;dy=-9    dx=3     ship
V2B4C:  .byte $01, $01          ;dy=1     dx=1     ship
V2B4E:  .byte $02, $FA          ;dy=2     dx=-6    ship
V2B50:  .byte $FF, $FF          ;dy=-1    dx=-1    ship
V2B52:  .byte $E3, $06          ;dy=-29   dx=6     ship
V2B54:  .byte $F1, $FA          ;dy=-15   dx=-6    ship
V2B56:  .byte $04, $F7          ;dy=4     dx=-9    ship
V2B58:  .byte $FD, $FC          ;dy=-3    dx=-4    ship
V2B5A:  .byte $06, $F1          ;dy=6     dx=-15   ship
V2B5C:  .byte $05, $00          ;dy=5     dx=0     ship
V2B5E:  .byte $04, $F7          ;dy=4     dx=-9    ship
V2B60:  .byte $0F, $06          ;dy=15    dx=6     ship
V2B62:  .byte $03, $17          ;dy=3     dx=23    move (blanked: return leg / flame bridge)
V2B64:  .byte $DF, $FB          ;dy=-33   dx=-5    thrust flame (white)
V2B66:  .byte $F1, $F1          ;dy=-15   dx=-15   thrust flame (white)
V2B68:  .byte $15, $00          ;dy=21    dx=0     thrust flame (white)
V2B6A:  .byte $1B, $14          ;dy=27    dx=20    thrust flame (white)

SHPA13:  ;type A: 23 ship records + 4 thrust-flame, 2 bytes each
V2B6C:  .byte $FA, $E9          ;dy=-6    dx=-23   move (blanked by SHPDI8 epilogue)
V2B6E:  .byte $13, $17          ;dy=19    dx=23    ship
V2B70:  .byte $02, $00          ;dy=2     dx=0     ship
V2B72:  .byte $01, $FA          ;dy=1     dx=-6    ship
V2B74:  .byte $04, $02          ;dy=4     dx=2     ship
V2B76:  .byte $00, $06          ;dy=0     dx=6     ship
V2B78:  .byte $04, $01          ;dy=4     dx=1     ship
V2B7A:  .byte $0A, $07          ;dy=10    dx=7     ship
V2B7C:  .byte $F4, $01          ;dy=-12   dx=1     ship
V2B7E:  .byte $FC, $FF          ;dy=-4    dx=-1    ship
V2B80:  .byte $F8, $03          ;dy=-8    dx=3     ship
V2B82:  .byte $00, $01          ;dy=0     dx=1     ship
V2B84:  .byte $02, $FA          ;dy=2     dx=-6    ship
V2B86:  .byte $FE, $FF          ;dy=-2    dx=-1    ship
V2B88:  .byte $E5, $09          ;dy=-27   dx=9     ship
V2B8A:  .byte $F0, $FB          ;dy=-16   dx=-5    ship
V2B8C:  .byte $03, $F6          ;dy=3     dx=-10   ship
V2B8E:  .byte $FD, $FD          ;dy=-3    dx=-3    ship
V2B90:  .byte $05, $F1          ;dy=5     dx=-15   ship
V2B92:  .byte $04, $FF          ;dy=4     dx=-1    ship
V2B94:  .byte $03, $F7          ;dy=3     dx=-9    ship
V2B96:  .byte $0F, $04          ;dy=15    dx=4     ship
V2B98:  .byte $06, $17          ;dy=6     dx=23    move (blanked: return leg / flame bridge)
V2B9A:  .byte $DF, $FE          ;dy=-33   dx=-2    thrust flame (white)
V2B9C:  .byte $EF, $F3          ;dy=-17   dx=-13   thrust flame (white)
V2B9E:  .byte $16, $FE          ;dy=22    dx=-2    thrust flame (white)
V2BA0:  .byte $1C, $11          ;dy=28    dx=17    thrust flame (white)

SHPA14:  ;type A: 23 ship records + 4 thrust-flame, 2 bytes each
V2BA2:  .byte $F8, $EA          ;dy=-8    dx=-22   move (blanked by SHPDI8 epilogue)
V2BA4:  .byte $15, $14          ;dy=21    dx=20    ship
V2BA6:  .byte $02, $01          ;dy=2     dx=1     ship
V2BA8:  .byte $01, $FA          ;dy=1     dx=-6    ship
V2BAA:  .byte $04, $01          ;dy=4     dx=1     ship
V2BAC:  .byte $00, $06          ;dy=0     dx=6     ship
V2BAE:  .byte $04, $01          ;dy=4     dx=1     ship
V2BB0:  .byte $0B, $06          ;dy=11    dx=6     ship
V2BB2:  .byte $F4, $02          ;dy=-12   dx=2     ship
V2BB4:  .byte $FC, $FF          ;dy=-4    dx=-1    ship
V2BB6:  .byte $F8, $04          ;dy=-8    dx=4     ship
V2BB8:  .byte $01, $01          ;dy=1     dx=1     ship
V2BBA:  .byte $01, $FA          ;dy=1     dx=-6    ship
V2BBC:  .byte $FE, $FF          ;dy=-2    dx=-1    ship
V2BBE:  .byte $E5, $0B          ;dy=-27   dx=11    ship
V2BC0:  .byte $F1, $FD          ;dy=-15   dx=-3    ship
V2BC2:  .byte $02, $F6          ;dy=2     dx=-10   ship
V2BC4:  .byte $FC, $FE          ;dy=-4    dx=-2    ship
V2BC6:  .byte $03, $F0          ;dy=3     dx=-16   ship
V2BC8:  .byte $04, $FF          ;dy=4     dx=-1    ship
V2BCA:  .byte $02, $F6          ;dy=2     dx=-10   ship
V2BCC:  .byte $10, $03          ;dy=16    dx=3     ship
V2BCE:  .byte $08, $16          ;dy=8     dx=22    move (blanked: return leg / flame bridge)
V2BD0:  .byte $DF, $02          ;dy=-33   dx=2     thrust flame (white)
V2BD2:  .byte $EE, $F4          ;dy=-18   dx=-12   thrust flame (white)
V2BD4:  .byte $15, $FC          ;dy=21    dx=-4    thrust flame (white)
V2BD6:  .byte $1E, $0E          ;dy=30    dx=14    thrust flame (white)

SHPA15:  ;type A: 23 ship records + 4 thrust-flame, 2 bytes each
V2C00:  .byte $F6, $EB          ;dy=-10   dx=-21   move (blanked by SHPDI8 epilogue)
V2C02:  .byte $16, $12          ;dy=22    dx=18    ship
V2C04:  .byte $02, $00          ;dy=2     dx=0     ship
V2C06:  .byte $01, $FA          ;dy=1     dx=-6    ship
V2C08:  .byte $04, $01          ;dy=4     dx=1     ship
V2C0A:  .byte $01, $06          ;dy=1     dx=6     ship
V2C0C:  .byte $04, $00          ;dy=4     dx=0     ship
V2C0E:  .byte $0C, $06          ;dy=12    dx=6     ship
V2C10:  .byte $F3, $02          ;dy=-13   dx=2     ship
V2C12:  .byte $FD, $00          ;dy=-3    dx=0     ship
V2C14:  .byte $F8, $05          ;dy=-8    dx=5     ship
V2C16:  .byte $01, $00          ;dy=1     dx=0     ship
V2C18:  .byte $01, $FA          ;dy=1     dx=-6    ship
V2C1A:  .byte $FE, $00          ;dy=-2    dx=0     ship
V2C1C:  .byte $E6, $0E          ;dy=-26   dx=14    ship
V2C1E:  .byte $F0, $FE          ;dy=-16   dx=-2    ship
V2C20:  .byte $01, $F6          ;dy=1     dx=-10   ship
V2C22:  .byte $FC, $FE          ;dy=-4    dx=-2    ship
V2C24:  .byte $02, $F0          ;dy=2     dx=-16   ship
V2C26:  .byte $04, $FE          ;dy=4     dx=-2    ship
V2C28:  .byte $01, $F6          ;dy=1     dx=-10   ship
V2C2A:  .byte $10, $02          ;dy=16    dx=2     ship
V2C2C:  .byte $0A, $15          ;dy=10    dx=21    move (blanked: return leg / flame bridge)
V2C2E:  .byte $DF, $05          ;dy=-33   dx=5     thrust flame (white)
V2C30:  .byte $ED, $F6          ;dy=-19   dx=-10   thrust flame (white)
V2C32:  .byte $15, $FA          ;dy=21    dx=-6    thrust flame (white)
V2C34:  .byte $1F, $0B          ;dy=31    dx=11    thrust flame (white)

SHPA16:  ;type A: 23 ship records + 4 thrust-flame, 2 bytes each
V2C36:  .byte $F4, $EC          ;dy=-12   dx=-20   move (blanked by SHPDI8 epilogue)
V2C38:  .byte $18, $10          ;dy=24    dx=16    ship
V2C3A:  .byte $02, $00          ;dy=2     dx=0     ship
V2C3C:  .byte $00, $FA          ;dy=0     dx=-6    ship
V2C3E:  .byte $04, $00          ;dy=4     dx=0     ship
V2C40:  .byte $02, $06          ;dy=2     dx=6     ship
V2C42:  .byte $04, $00          ;dy=4     dx=0     ship
V2C44:  .byte $0C, $04          ;dy=12    dx=4     ship
V2C46:  .byte $F4, $04          ;dy=-12   dx=4     ship
V2C48:  .byte $FC, $00          ;dy=-4    dx=0     ship
V2C4A:  .byte $F9, $06          ;dy=-7    dx=6     ship
V2C4C:  .byte $01, $00          ;dy=1     dx=0     ship
V2C4E:  .byte $00, $FA          ;dy=0     dx=-6    ship
V2C50:  .byte $FE, $00          ;dy=-2    dx=0     ship
V2C52:  .byte $E8, $10          ;dy=-24   dx=16    ship
V2C54:  .byte $F0, $00          ;dy=-16   dx=0     ship
V2C56:  .byte $00, $F6          ;dy=0     dx=-10   ship
V2C58:  .byte $FC, $FE          ;dy=-4    dx=-2    ship
V2C5A:  .byte $00, $F0          ;dy=0     dx=-16   ship
V2C5C:  .byte $04, $FE          ;dy=4     dx=-2    ship
V2C5E:  .byte $00, $F6          ;dy=0     dx=-10   ship
V2C60:  .byte $10, $00          ;dy=16    dx=0     ship
V2C62:  .byte $0C, $14          ;dy=12    dx=20    move (blanked: return leg / flame bridge)
V2C64:  .byte $E0, $08          ;dy=-32   dx=8     thrust flame (white)
V2C66:  .byte $EC, $F8          ;dy=-20   dx=-8    thrust flame (white)
V2C68:  .byte $14, $F8          ;dy=20    dx=-8    thrust flame (white)
V2C6A:  .byte $20, $08          ;dy=32    dx=8     thrust flame (white)

SHPB0:  ;type B: 21 ship records + 4 thrust-flame, 2 bytes each
V2C6C:  .byte $14, $E8          ;dy=20    dx=-24   move (blanked by SHPDI8 epilogue)
V2C6E:  .byte $00, $14          ;dy=0     dx=20    ship
V2C70:  .byte $F8, $04          ;dy=-8    dx=4     ship
V2C72:  .byte $01, $F8          ;dy=1     dx=-8    ship
V2C74:  .byte $F9, $04          ;dy=-7    dx=4     ship
V2C76:  .byte $00, $10          ;dy=0     dx=16    ship
V2C78:  .byte $FC, $18          ;dy=-4    dx=24    ship
V2C7A:  .byte $FC, $00          ;dy=-4    dx=0     ship
V2C7C:  .byte $FC, $E8          ;dy=-4    dx=-24   ship
V2C7E:  .byte $00, $F0          ;dy=0     dx=-16   ship
V2C80:  .byte $FA, $FC          ;dy=-6    dx=-4    ship
V2C82:  .byte $00, $08          ;dy=0     dx=8     ship
V2C84:  .byte $F8, $FC          ;dy=-8    dx=-4    ship
V2C86:  .byte $00, $EC          ;dy=0     dx=-20   ship
V2C88:  .byte $08, $F8          ;dy=8     dx=-8    ship
V2C8A:  .byte $00, $08          ;dy=0     dx=8     ship
V2C8C:  .byte $0C, $04          ;dy=12    dx=4     ship
V2C8E:  .byte $0C, $FC          ;dy=12    dx=-4    ship
V2C90:  .byte $00, $F8          ;dy=0     dx=-8    ship
V2C92:  .byte $08, $08          ;dy=8     dx=8     ship
V2C94:  .byte $EC, $18          ;dy=-20   dx=24    move (blanked: return leg / flame bridge)
V2C96:  .byte $0C, $E8          ;dy=12    dx=-24   thrust flame (white)
V2C98:  .byte $F4, $F0          ;dy=-12   dx=-16   thrust flame (white)
V2C9A:  .byte $F4, $10          ;dy=-12   dx=16    thrust flame (white)
V2C9C:  .byte $0C, $18          ;dy=12    dx=24    thrust flame (white)

SHPB1:  ;type B: 21 ship records + 4 thrust-flame, 2 bytes each
V2C9E:  .byte $12, $E6          ;dy=18    dx=-26   move (blanked by SHPDI8 epilogue)
V2CA0:  .byte $02, $14          ;dy=2     dx=20    ship
V2CA2:  .byte $F8, $05          ;dy=-8    dx=5     ship
V2CA4:  .byte $00, $F8          ;dy=0     dx=-8    ship
V2CA6:  .byte $FA, $04          ;dy=-6    dx=4     ship
V2CA8:  .byte $01, $10          ;dy=1     dx=16    ship
V2CAA:  .byte $FF, $19          ;dy=-1    dx=25    ship
V2CAC:  .byte $FC, $00          ;dy=-4    dx=0     ship
V2CAE:  .byte $F9, $E9          ;dy=-7    dx=-23   ship
V2CB0:  .byte $FF, $F0          ;dy=-1    dx=-16   ship
V2CB2:  .byte $F9, $FC          ;dy=-7    dx=-4    ship
V2CB4:  .byte $01, $08          ;dy=1     dx=8     ship
V2CB6:  .byte $F8, $FD          ;dy=-8    dx=-3    ship
V2CB8:  .byte $FE, $EC          ;dy=-2    dx=-20   ship
V2CBA:  .byte $07, $F7          ;dy=7     dx=-9    ship
V2CBC:  .byte $01, $08          ;dy=1     dx=8     ship
V2CBE:  .byte $0C, $03          ;dy=12    dx=3     ship
V2CC0:  .byte $0C, $FB          ;dy=12    dx=-5    ship
V2CC2:  .byte $FF, $F8          ;dy=-1    dx=-8    ship
V2CC4:  .byte $09, $07          ;dy=9     dx=7     ship
V2CC6:  .byte $EE, $1A          ;dy=-18   dx=26    move (blanked: return leg / flame bridge)
V2CC8:  .byte $0A, $E7          ;dy=10    dx=-25   thrust flame (white)
V2CCA:  .byte $F2, $F1          ;dy=-14   dx=-15   thrust flame (white)
V2CCC:  .byte $F6, $11          ;dy=-10   dx=17    thrust flame (white)
V2CCE:  .byte $0E, $17          ;dy=14    dx=23    thrust flame (white)

SHPB2:  ;type B: 21 ship records + 4 thrust-flame, 2 bytes each
V2D00:  .byte $0F, $E5          ;dy=15    dx=-27   move (blanked by SHPDI8 epilogue)
V2D02:  .byte $04, $13          ;dy=4     dx=19    ship
V2D04:  .byte $F9, $06          ;dy=-7    dx=6     ship
V2D06:  .byte $FF, $F8          ;dy=-1    dx=-8    ship
V2D08:  .byte $FA, $05          ;dy=-6    dx=5     ship
V2D0A:  .byte $03, $10          ;dy=3     dx=16    ship
V2D0C:  .byte $01, $18          ;dy=1     dx=24    ship
V2D0E:  .byte $FC, $01          ;dy=-4    dx=1     ship
V2D10:  .byte $F7, $E9          ;dy=-9    dx=-23   ship
V2D12:  .byte $FD, $F0          ;dy=-3    dx=-16   ship
V2D14:  .byte $FA, $FD          ;dy=-6    dx=-3    ship
V2D16:  .byte $01, $08          ;dy=1     dx=8     ship
V2D18:  .byte $F8, $FE          ;dy=-8    dx=-2    ship
V2D1A:  .byte $FC, $EC          ;dy=-4    dx=-20   ship
V2D1C:  .byte $06, $F7          ;dy=6     dx=-9    ship
V2D1E:  .byte $02, $08          ;dy=2     dx=8     ship
V2D20:  .byte $0C, $01          ;dy=12    dx=1     ship
V2D22:  .byte $0B, $FA          ;dy=11    dx=-6    ship
V2D24:  .byte $FF, $F8          ;dy=-1    dx=-8    ship
V2D26:  .byte $09, $07          ;dy=9     dx=7     ship
V2D28:  .byte $F1, $1B          ;dy=-15   dx=27    move (blanked: return leg / flame bridge)
V2D2A:  .byte $07, $E6          ;dy=7     dx=-26   thrust flame (white)
V2D2C:  .byte $F1, $F3          ;dy=-15   dx=-13   thrust flame (white)
V2D2E:  .byte $F8, $12          ;dy=-8    dx=18    thrust flame (white)
V2D30:  .byte $10, $15          ;dy=16    dx=21    thrust flame (white)

SHPB3:  ;type B: 21 ship records + 4 thrust-flame, 2 bytes each
V2D32:  .byte $0C, $E3          ;dy=12    dx=-29   move (blanked by SHPDI8 epilogue)
V2D34:  .byte $06, $13          ;dy=6     dx=19    ship
V2D36:  .byte $F9, $07          ;dy=-7    dx=7     ship
V2D38:  .byte $FF, $F8          ;dy=-1    dx=-8    ship
V2D3A:  .byte $FB, $05          ;dy=-5    dx=5     ship
V2D3C:  .byte $04, $10          ;dy=4     dx=16    ship
V2D3E:  .byte $03, $18          ;dy=3     dx=24    ship
V2D40:  .byte $FD, $01          ;dy=-3    dx=1     ship
V2D42:  .byte $F5, $EA          ;dy=-11   dx=-22   ship
V2D44:  .byte $FB, $F1          ;dy=-5    dx=-15   ship
V2D46:  .byte $F9, $FE          ;dy=-7    dx=-2    ship
V2D48:  .byte $03, $07          ;dy=3     dx=7     ship
V2D4A:  .byte $F7, $FF          ;dy=-9    dx=-1    ship
V2D4C:  .byte $FA, $ED          ;dy=-6    dx=-19   ship
V2D4E:  .byte $05, $F6          ;dy=5     dx=-10   ship
V2D50:  .byte $03, $08          ;dy=3     dx=8     ship
V2D52:  .byte $0C, $00          ;dy=12    dx=0     ship
V2D54:  .byte $0B, $F9          ;dy=11    dx=-7    ship
V2D56:  .byte $FD, $F8          ;dy=-3    dx=-8    ship
V2D58:  .byte $0A, $05          ;dy=10    dx=5     ship
V2D5A:  .byte $F4, $1D          ;dy=-12   dx=29    move (blanked: return leg / flame bridge)
V2D5C:  .byte $05, $E6          ;dy=5     dx=-26   thrust flame (white)
V2D5E:  .byte $EF, $F4          ;dy=-17   dx=-12   thrust flame (white)
V2D60:  .byte $FA, $13          ;dy=-6    dx=19    thrust flame (white)
V2D62:  .byte $12, $13          ;dy=18    dx=19    thrust flame (white)

SHPB4:  ;type B: 21 ship records + 4 thrust-flame, 2 bytes each
V2D64:  .byte $09, $E2          ;dy=9     dx=-30   move (blanked by SHPDI8 epilogue)
V2D66:  .byte $08, $13          ;dy=8     dx=19    ship
V2D68:  .byte $FA, $06          ;dy=-6    dx=6     ship
V2D6A:  .byte $FD, $F9          ;dy=-3    dx=-7    ship
V2D6C:  .byte $FC, $06          ;dy=-4    dx=6     ship
V2D6E:  .byte $06, $0F          ;dy=6     dx=15    ship
V2D70:  .byte $06, $17          ;dy=6     dx=23    ship
V2D72:  .byte $FC, $02          ;dy=-4    dx=2     ship
V2D74:  .byte $F3, $EB          ;dy=-13   dx=-21   ship
V2D76:  .byte $FA, $F2          ;dy=-6    dx=-14   ship
V2D78:  .byte $F9, $FE          ;dy=-7    dx=-2    ship
V2D7A:  .byte $03, $08          ;dy=3     dx=8     ship
V2D7C:  .byte $F7, $FF          ;dy=-9    dx=-1    ship
V2D7E:  .byte $F8, $ED          ;dy=-8    dx=-19   ship
V2D80:  .byte $05, $F6          ;dy=5     dx=-10   ship
V2D82:  .byte $03, $07          ;dy=3     dx=7     ship
V2D84:  .byte $0C, $00          ;dy=12    dx=0     ship
V2D86:  .byte $0A, $F7          ;dy=10    dx=-9    ship
V2D88:  .byte $FD, $F9          ;dy=-3    dx=-7    ship
V2D8A:  .byte $0A, $04          ;dy=10    dx=4     ship
V2D8C:  .byte $F7, $1E          ;dy=-9    dx=30    move (blanked: return leg / flame bridge)
V2D8E:  .byte $02, $E5          ;dy=2     dx=-27   thrust flame (white)
V2D90:  .byte $EF, $F6          ;dy=-17   dx=-10   thrust flame (white)
V2D92:  .byte $FB, $13          ;dy=-5    dx=19    thrust flame (white)
V2D94:  .byte $14, $12          ;dy=20    dx=18    thrust flame (white)

SHPB5:  ;type B: 21 ship records + 4 thrust-flame, 2 bytes each
V2D96:  .byte $06, $E1          ;dy=6     dx=-31   move (blanked by SHPDI8 epilogue)
V2D98:  .byte $0A, $12          ;dy=10    dx=18    ship
V2D9A:  .byte $FB, $07          ;dy=-5    dx=7     ship
V2D9C:  .byte $FC, $F9          ;dy=-4    dx=-7    ship
V2D9E:  .byte $FC, $07          ;dy=-4    dx=7     ship
V2DA0:  .byte $08, $0E          ;dy=8     dx=14    ship
V2DA2:  .byte $08, $17          ;dy=8     dx=23    ship
V2DA4:  .byte $FC, $02          ;dy=-4    dx=2     ship
V2DA6:  .byte $F1, $EC          ;dy=-15   dx=-20   ship
V2DA8:  .byte $F9, $F2          ;dy=-7    dx=-14   ship
V2DAA:  .byte $F9, $00          ;dy=-7    dx=0     ship
V2DAC:  .byte $03, $07          ;dy=3     dx=7     ship
V2DAE:  .byte $F7, $00          ;dy=-9    dx=0     ship
V2DB0:  .byte $F7, $EE          ;dy=-9    dx=-18   ship
V2DB2:  .byte $03, $F5          ;dy=3     dx=-11   ship
V2DB4:  .byte $04, $07          ;dy=4     dx=7     ship
V2DB6:  .byte $0D, $FE          ;dy=13    dx=-2    ship
V2DB8:  .byte $08, $F7          ;dy=8     dx=-9    ship
V2DBA:  .byte $FC, $F9          ;dy=-4    dx=-7    ship
V2DBC:  .byte $0B, $03          ;dy=11    dx=3     ship
V2DBE:  .byte $FA, $1F          ;dy=-6    dx=31    move (blanked: return leg / flame bridge)
V2DC0:  .byte $FF, $E5          ;dy=-1    dx=-27   thrust flame (white)
V2DC2:  .byte $EE, $F8          ;dy=-18   dx=-8    thrust flame (white)
V2DC4:  .byte $FD, $13          ;dy=-3    dx=19    thrust flame (white)
V2DC6:  .byte $16, $10          ;dy=22    dx=16    thrust flame (white)

SHPB6:  ;type B: 21 ship records + 4 thrust-flame, 2 bytes each
V2DC8:  .byte $03, $E1          ;dy=3     dx=-31   move (blanked by SHPDI8 epilogue)
V2DCA:  .byte $0B, $11          ;dy=11    dx=17    ship
V2DCC:  .byte $FC, $07          ;dy=-4    dx=7     ship
V2DCE:  .byte $FC, $F9          ;dy=-4    dx=-7    ship
V2DD0:  .byte $FD, $07          ;dy=-3    dx=7     ship
V2DD2:  .byte $09, $0E          ;dy=9     dx=14    ship
V2DD4:  .byte $0A, $16          ;dy=10    dx=22    ship
V2DD6:  .byte $FC, $02          ;dy=-4    dx=2     ship
V2DD8:  .byte $F0, $EE          ;dy=-16   dx=-18   ship
V2DDA:  .byte $F7, $F3          ;dy=-9    dx=-13   ship
V2DDC:  .byte $F9, $00          ;dy=-7    dx=0     ship
V2DDE:  .byte $04, $07          ;dy=4     dx=7     ship
V2DE0:  .byte $F7, $01          ;dy=-9    dx=1     ship
V2DE2:  .byte $F5, $EF          ;dy=-11   dx=-17   ship
V2DE4:  .byte $02, $F5          ;dy=2     dx=-11   ship
V2DE6:  .byte $05, $07          ;dy=5     dx=7     ship
V2DE8:  .byte $0C, $FC          ;dy=12    dx=-4    ship
V2DEA:  .byte $08, $F6          ;dy=8     dx=-10   ship
V2DEC:  .byte $FB, $FA          ;dy=-5    dx=-6    ship
V2DEE:  .byte $0B, $02          ;dy=11    dx=2     ship
V2DF0:  .byte $FD, $1F          ;dy=-3    dx=31    move (blanked: return leg / flame bridge)
V2DF2:  .byte $FD, $E5          ;dy=-3    dx=-27   thrust flame (white)
V2DF4:  .byte $ED, $FA          ;dy=-19   dx=-6    thrust flame (white)
V2DF6:  .byte $FF, $14          ;dy=-1    dx=20    thrust flame (white)
V2DF8:  .byte $17, $0D          ;dy=23    dx=13    thrust flame (white)

SHPB7:  ;type B: 21 ship records + 4 thrust-flame, 2 bytes each
V2E00:  .byte $00, $E1          ;dy=0     dx=-31   move (blanked by SHPDI8 epilogue)
V2E02:  .byte $0D, $0F          ;dy=13    dx=15    ship
V2E04:  .byte $FC, $08          ;dy=-4    dx=8     ship
V2E06:  .byte $FC, $FA          ;dy=-4    dx=-6    ship
V2E08:  .byte $FD, $07          ;dy=-3    dx=7     ship
V2E0A:  .byte $0A, $0C          ;dy=10    dx=12    ship
V2E0C:  .byte $0C, $16          ;dy=12    dx=22    ship
V2E0E:  .byte $FD, $02          ;dy=-3    dx=2     ship
V2E10:  .byte $EE, $F0          ;dy=-18   dx=-16   ship
V2E12:  .byte $F6, $F4          ;dy=-10   dx=-12   ship
V2E14:  .byte $F9, $00          ;dy=-7    dx=0     ship
V2E16:  .byte $05, $07          ;dy=5     dx=7     ship
V2E18:  .byte $F7, $02          ;dy=-9    dx=2     ship
V2E1A:  .byte $F3, $F0          ;dy=-13   dx=-16   ship
V2E1C:  .byte $01, $F5          ;dy=1     dx=-11   ship
V2E1E:  .byte $05, $06          ;dy=5     dx=6     ship
V2E20:  .byte $0C, $FC          ;dy=12    dx=-4    ship
V2E22:  .byte $07, $F5          ;dy=7     dx=-11   ship
V2E24:  .byte $FB, $FA          ;dy=-5    dx=-6    ship
V2E26:  .byte $0B, $01          ;dy=11    dx=1     ship
V2E28:  .byte $00, $1F          ;dy=0     dx=31    move (blanked: return leg / flame bridge)
V2E2A:  .byte $FA, $E6          ;dy=-6    dx=-26   thrust flame (white)
V2E2C:  .byte $ED, $FB          ;dy=-19   dx=-5    thrust flame (white)
V2E2E:  .byte $00, $14          ;dy=0     dx=20    thrust flame (white)
V2E30:  .byte $19, $0B          ;dy=25    dx=11    thrust flame (white)

SHPB8:  ;type B: 21 ship records + 4 thrust-flame, 2 bytes each
V2E32:  .byte $FD, $E1          ;dy=-3    dx=-31   move (blanked by SHPDI8 epilogue)
V2E34:  .byte $0E, $0E          ;dy=14    dx=14    ship
V2E36:  .byte $FD, $09          ;dy=-3    dx=9     ship
V2E38:  .byte $FB, $FA          ;dy=-5    dx=-6    ship
V2E3A:  .byte $FE, $07          ;dy=-2    dx=7     ship
V2E3C:  .byte $0C, $0B          ;dy=12    dx=11    ship
V2E3E:  .byte $0E, $14          ;dy=14    dx=20    ship
V2E40:  .byte $FD, $03          ;dy=-3    dx=3     ship
V2E42:  .byte $EC, $F2          ;dy=-20   dx=-14   ship
V2E44:  .byte $F5, $F4          ;dy=-11   dx=-12   ship
V2E46:  .byte $F9, $02          ;dy=-7    dx=2     ship
V2E48:  .byte $06, $05          ;dy=6     dx=5     ship
V2E4A:  .byte $F7, $03          ;dy=-9    dx=3     ship
V2E4C:  .byte $F2, $F2          ;dy=-14   dx=-14   ship
V2E4E:  .byte $00, $F5          ;dy=0     dx=-11   ship
V2E50:  .byte $06, $06          ;dy=6     dx=6     ship
V2E52:  .byte $0B, $FA          ;dy=11    dx=-6    ship
V2E54:  .byte $06, $F5          ;dy=6     dx=-11   ship
V2E56:  .byte $FA, $FA          ;dy=-6    dx=-6    ship
V2E58:  .byte $0B, $00          ;dy=11    dx=0     ship
V2E5A:  .byte $03, $1F          ;dy=3     dx=31    move (blanked: return leg / flame bridge)
V2E5C:  .byte $F8, $E7          ;dy=-8    dx=-25   thrust flame (white)
V2E5E:  .byte $EC, $FD          ;dy=-20   dx=-3    thrust flame (white)
V2E60:  .byte $03, $14          ;dy=3     dx=20    thrust flame (white)
V2E62:  .byte $19, $08          ;dy=25    dx=8     thrust flame (white)

SHPB9:  ;type B: 21 ship records + 4 thrust-flame, 2 bytes each
V2E64:  .byte $FA, $E1          ;dy=-6    dx=-31   move (blanked by SHPDI8 epilogue)
V2E66:  .byte $10, $0D          ;dy=16    dx=13    ship
V2E68:  .byte $FE, $09          ;dy=-2    dx=9     ship
V2E6A:  .byte $FA, $FA          ;dy=-6    dx=-6    ship
V2E6C:  .byte $FF, $08          ;dy=-1    dx=8     ship
V2E6E:  .byte $0C, $0A          ;dy=12    dx=10    ship
V2E70:  .byte $10, $12          ;dy=16    dx=18    ship
V2E72:  .byte $FE, $03          ;dy=-2    dx=3     ship
V2E74:  .byte $EA, $F4          ;dy=-22   dx=-12   ship
V2E76:  .byte $F4, $F6          ;dy=-12   dx=-10   ship
V2E78:  .byte $F9, $02          ;dy=-7    dx=2     ship
V2E7A:  .byte $06, $05          ;dy=6     dx=5     ship
V2E7C:  .byte $F8, $04          ;dy=-8    dx=4     ship
V2E7E:  .byte $F1, $F3          ;dy=-15   dx=-13   ship
V2E80:  .byte $FF, $F5          ;dy=-1    dx=-11   ship
V2E82:  .byte $06, $05          ;dy=6     dx=5     ship
V2E84:  .byte $0B, $F9          ;dy=11    dx=-7    ship
V2E86:  .byte $04, $F4          ;dy=4     dx=-12   ship
V2E88:  .byte $FA, $FB          ;dy=-6    dx=-5    ship
V2E8A:  .byte $0B, $FF          ;dy=11    dx=-1    ship
V2E8C:  .byte $06, $1F          ;dy=6     dx=31    move (blanked: return leg / flame bridge)
V2E8E:  .byte $F5, $E7          ;dy=-11   dx=-25   thrust flame (white)
V2E90:  .byte $EC, $00          ;dy=-20   dx=0     thrust flame (white)
V2E92:  .byte $05, $13          ;dy=5     dx=19    thrust flame (white)
V2E94:  .byte $1A, $06          ;dy=26    dx=6     thrust flame (white)

SHPB10:  ;type B: 21 ship records + 4 thrust-flame, 2 bytes each
V2E96:  .byte $F7, $E2          ;dy=-9    dx=-30   move (blanked by SHPDI8 epilogue)
V2E98:  .byte $11, $0B          ;dy=17    dx=11    ship
V2E9A:  .byte $FF, $09          ;dy=-1    dx=9     ship
V2E9C:  .byte $F9, $FB          ;dy=-7    dx=-5    ship
V2E9E:  .byte $00, $08          ;dy=0     dx=8     ship
V2EA0:  .byte $0D, $09          ;dy=13    dx=9     ship
V2EA2:  .byte $12, $10          ;dy=18    dx=16    ship
V2EA4:  .byte $FE, $04          ;dy=-2    dx=4     ship
V2EA6:  .byte $EA, $F6          ;dy=-22   dx=-10   ship
V2EA8:  .byte $F2, $F7          ;dy=-14   dx=-9    ship
V2EAA:  .byte $FA, $03          ;dy=-6    dx=3     ship
V2EAC:  .byte $06, $04          ;dy=6     dx=4     ship
V2EAE:  .byte $F9, $04          ;dy=-7    dx=4     ship
V2EB0:  .byte $EF, $F5          ;dy=-17   dx=-11   ship
V2EB2:  .byte $FE, $F5          ;dy=-2    dx=-11   ship
V2EB4:  .byte $06, $05          ;dy=6     dx=5     ship
V2EB6:  .byte $0A, $F8          ;dy=10    dx=-8    ship
V2EB8:  .byte $04, $F4          ;dy=4     dx=-12   ship
V2EBA:  .byte $F9, $FB          ;dy=-7    dx=-5    ship
V2EBC:  .byte $0B, $FE          ;dy=11    dx=-2    ship
V2EBE:  .byte $09, $1E          ;dy=9     dx=30    move (blanked: return leg / flame bridge)
V2EC0:  .byte $F3, $E9          ;dy=-13   dx=-23   thrust flame (white)
V2EC2:  .byte $EC, $01          ;dy=-20   dx=1     thrust flame (white)
V2EC4:  .byte $06, $13          ;dy=6     dx=19    thrust flame (white)
V2EC6:  .byte $1B, $03          ;dy=27    dx=3     thrust flame (white)

SHPB11:  ;type B: 21 ship records + 4 thrust-flame, 2 bytes each
V2EC8:  .byte $F4, $E3          ;dy=-12   dx=-29   move (blanked by SHPDI8 epilogue)
V2ECA:  .byte $12, $09          ;dy=18    dx=9     ship
V2ECC:  .byte $00, $09          ;dy=0     dx=9     ship
V2ECE:  .byte $F9, $FC          ;dy=-7    dx=-4    ship
V2ED0:  .byte $00, $08          ;dy=0     dx=8     ship
V2ED2:  .byte $0E, $07          ;dy=14    dx=7     ship
V2ED4:  .byte $14, $0F          ;dy=20    dx=15    ship
V2ED6:  .byte $FE, $04          ;dy=-2    dx=4     ship
V2ED8:  .byte $E9, $F8          ;dy=-23   dx=-8    ship
V2EDA:  .byte $F2, $F8          ;dy=-14   dx=-8    ship
V2EDC:  .byte $F9, $04          ;dy=-7    dx=4     ship
V2EDE:  .byte $07, $04          ;dy=7     dx=4     ship
V2EE0:  .byte $F9, $05          ;dy=-7    dx=5     ship
V2EE2:  .byte $EE, $F6          ;dy=-18   dx=-10   ship
V2EE4:  .byte $FD, $F5          ;dy=-3    dx=-11   ship
V2EE6:  .byte $07, $04          ;dy=7     dx=4     ship
V2EE8:  .byte $09, $F8          ;dy=9     dx=-8    ship
V2EEA:  .byte $02, $F3          ;dy=2     dx=-13   ship
V2EEC:  .byte $F9, $FC          ;dy=-7    dx=-4    ship
V2EEE:  .byte $0B, $FD          ;dy=11    dx=-3    ship
V2EF0:  .byte $0C, $1D          ;dy=12    dx=29    move (blanked: return leg / flame bridge)
V2EF2:  .byte $F0, $EA          ;dy=-16   dx=-22   thrust flame (white)
V2EF4:  .byte $ED, $03          ;dy=-19   dx=3     thrust flame (white)
V2EF6:  .byte $08, $12          ;dy=8     dx=18    thrust flame (white)
V2EF8:  .byte $1B, $01          ;dy=27    dx=1     thrust flame (white)

SHPB12:  ;type B: 21 ship records + 4 thrust-flame, 2 bytes each
V2F00:  .byte $F1, $E4          ;dy=-15   dx=-28   move (blanked by SHPDI8 epilogue)
V2F02:  .byte $13, $08          ;dy=19    dx=8     ship
V2F04:  .byte $01, $09          ;dy=1     dx=9     ship
V2F06:  .byte $F8, $FC          ;dy=-8    dx=-4    ship
V2F08:  .byte $02, $08          ;dy=2     dx=8     ship
V2F0A:  .byte $0E, $06          ;dy=14    dx=6     ship
V2F0C:  .byte $15, $0D          ;dy=21    dx=13    ship
V2F0E:  .byte $FE, $04          ;dy=-2    dx=4     ship
V2F10:  .byte $E9, $FA          ;dy=-23   dx=-6    ship
V2F12:  .byte $F1, $FA          ;dy=-15   dx=-6    ship
V2F14:  .byte $FA, $04          ;dy=-6    dx=4     ship
V2F16:  .byte $07, $03          ;dy=7     dx=3     ship
V2F18:  .byte $FA, $06          ;dy=-6    dx=6     ship
V2F1A:  .byte $ED, $F8          ;dy=-19   dx=-8    ship
V2F1C:  .byte $FC, $F6          ;dy=-4    dx=-10   ship
V2F1E:  .byte $07, $03          ;dy=7     dx=3     ship
V2F20:  .byte $09, $F6          ;dy=9     dx=-10   ship
V2F22:  .byte $00, $F4          ;dy=0     dx=-12   ship
V2F24:  .byte $F9, $FD          ;dy=-7    dx=-3    ship
V2F26:  .byte $0A, $FB          ;dy=10    dx=-5    ship
V2F28:  .byte $0F, $1C          ;dy=15    dx=28    move (blanked: return leg / flame bridge)
V2F2A:  .byte $EE, $EC          ;dy=-18   dx=-20   thrust flame (white)
V2F2C:  .byte $ED, $05          ;dy=-19   dx=5     thrust flame (white)
V2F2E:  .byte $0A, $11          ;dy=10    dx=17    thrust flame (white)
V2F30:  .byte $1B, $FE          ;dy=27    dx=-2    thrust flame (white)

SHPB13:  ;type B: 21 ship records + 4 thrust-flame, 2 bytes each
V2F32:  .byte $EF, $E6          ;dy=-17   dx=-26   move (blanked by SHPDI8 epilogue)
V2F34:  .byte $13, $06          ;dy=19    dx=6     ship
V2F36:  .byte $01, $09          ;dy=1     dx=9     ship
V2F38:  .byte $F9, $FD          ;dy=-7    dx=-3    ship
V2F3A:  .byte $02, $07          ;dy=2     dx=7     ship
V2F3C:  .byte $0F, $05          ;dy=15    dx=5     ship
V2F3E:  .byte $16, $0B          ;dy=22    dx=11    ship
V2F40:  .byte $FF, $03          ;dy=-1    dx=3     ship
V2F42:  .byte $E8, $FD          ;dy=-24   dx=-3    ship
V2F44:  .byte $F0, $FC          ;dy=-16   dx=-4    ship
V2F46:  .byte $FB, $04          ;dy=-5    dx=4     ship
V2F48:  .byte $08, $02          ;dy=8     dx=2     ship
V2F4A:  .byte $F9, $07          ;dy=-7    dx=7     ship
V2F4C:  .byte $ED, $FA          ;dy=-19   dx=-6    ship
V2F4E:  .byte $FB, $F6          ;dy=-5    dx=-10   ship
V2F50:  .byte $08, $03          ;dy=8     dx=3     ship
V2F52:  .byte $07, $F5          ;dy=7     dx=-11   ship
V2F54:  .byte $00, $F4          ;dy=0     dx=-12   ship
V2F56:  .byte $F8, $FD          ;dy=-8    dx=-3    ship
V2F58:  .byte $0A, $FB          ;dy=10    dx=-5    ship
V2F5A:  .byte $11, $1A          ;dy=17    dx=26    move (blanked: return leg / flame bridge)
V2F5C:  .byte $ED, $EE          ;dy=-19   dx=-18   thrust flame (white)
V2F5E:  .byte $ED, $06          ;dy=-19   dx=6     thrust flame (white)
V2F60:  .byte $0C, $11          ;dy=12    dx=17    thrust flame (white)
V2F62:  .byte $1A, $FB          ;dy=26    dx=-5    thrust flame (white)

SHPB14:  ;type B: 21 ship records + 4 thrust-flame, 2 bytes each
V2F64:  .byte $EC, $E8          ;dy=-20   dx=-24   move (blanked by SHPDI8 epilogue)
V2F66:  .byte $14, $04          ;dy=20    dx=4     ship
V2F68:  .byte $02, $08          ;dy=2     dx=8     ship
V2F6A:  .byte $F9, $FE          ;dy=-7    dx=-2    ship
V2F6C:  .byte $02, $07          ;dy=2     dx=7     ship
V2F6E:  .byte $10, $03          ;dy=16    dx=3     ship
V2F70:  .byte $17, $09          ;dy=23    dx=9     ship
V2F72:  .byte $FF, $04          ;dy=-1    dx=4     ship
V2F74:  .byte $E8, $FF          ;dy=-24   dx=-1    ship
V2F76:  .byte $F0, $FD          ;dy=-16   dx=-3    ship
V2F78:  .byte $FB, $05          ;dy=-5    dx=5     ship
V2F7A:  .byte $08, $02          ;dy=8     dx=2     ship
V2F7C:  .byte $FA, $07          ;dy=-6    dx=7     ship
V2F7E:  .byte $ED, $FC          ;dy=-19   dx=-4    ship
V2F80:  .byte $F9, $F7          ;dy=-7    dx=-9    ship
V2F82:  .byte $08, $01          ;dy=8     dx=1     ship
V2F84:  .byte $06, $F5          ;dy=6     dx=-11   ship
V2F86:  .byte $FF, $F4          ;dy=-1    dx=-12   ship
V2F88:  .byte $F8, $FE          ;dy=-8    dx=-2    ship
V2F8A:  .byte $09, $FA          ;dy=9     dx=-6    ship
V2F8C:  .byte $14, $18          ;dy=20    dx=24    move (blanked: return leg / flame bridge)
V2F8E:  .byte $EB, $F0          ;dy=-21   dx=-16   thrust flame (white)
V2F90:  .byte $EE, $08          ;dy=-18   dx=8     thrust flame (white)
V2F92:  .byte $0D, $0F          ;dy=13    dx=15    thrust flame (white)
V2F94:  .byte $1A, $F9          ;dy=26    dx=-7    thrust flame (white)

SHPB15:  ;type B: 21 ship records + 4 thrust-flame, 2 bytes each
V2F96:  .byte $EA, $EA          ;dy=-22   dx=-22   move (blanked by SHPDI8 epilogue)
V2F98:  .byte $14, $02          ;dy=20    dx=2     ship
V2F9A:  .byte $03, $08          ;dy=3     dx=8     ship
V2F9C:  .byte $F8, $FF          ;dy=-8    dx=-1    ship
V2F9E:  .byte $04, $07          ;dy=4     dx=7     ship
V2FA0:  .byte $10, $01          ;dy=16    dx=1     ship
V2FA2:  .byte $17, $07          ;dy=23    dx=7     ship
V2FA4:  .byte $00, $04          ;dy=0     dx=4     ship
V2FA6:  .byte $E7, $01          ;dy=-25   dx=1     ship
V2FA8:  .byte $F0, $FF          ;dy=-16   dx=-1    ship
V2FAA:  .byte $FC, $05          ;dy=-4    dx=5     ship
V2FAC:  .byte $08, $01          ;dy=8     dx=1     ship
V2FAE:  .byte $FB, $08          ;dy=-5    dx=8     ship
V2FB0:  .byte $EC, $FE          ;dy=-20   dx=-2    ship
V2FB2:  .byte $F9, $F7          ;dy=-7    dx=-9    ship
V2FB4:  .byte $08, $01          ;dy=8     dx=1     ship
V2FB6:  .byte $05, $F4          ;dy=5     dx=-12   ship
V2FB8:  .byte $FD, $F4          ;dy=-3    dx=-12   ship
V2FBA:  .byte $F8, $FF          ;dy=-8    dx=-1    ship
V2FBC:  .byte $09, $F9          ;dy=9     dx=-7    ship
V2FBE:  .byte $16, $16          ;dy=22    dx=22    move (blanked: return leg / flame bridge)
V2FC0:  .byte $E9, $F2          ;dy=-23   dx=-14   thrust flame (white)
V2FC2:  .byte $EF, $0A          ;dy=-17   dx=10    thrust flame (white)
V2FC4:  .byte $0F, $0E          ;dy=15    dx=14    thrust flame (white)
V2FC6:  .byte $19, $F6          ;dy=25    dx=-10   thrust flame (white)

SHPB16:  ;type B: 21 ship records + 4 thrust-flame, 2 bytes each
V2FC8:  .byte $E8, $EC          ;dy=-24   dx=-20   move (blanked by SHPDI8 epilogue)
V2FCA:  .byte $14, $00          ;dy=20    dx=0     ship
V2FCC:  .byte $04, $08          ;dy=4     dx=8     ship
V2FCE:  .byte $F8, $FF          ;dy=-8    dx=-1    ship
V2FD0:  .byte $04, $07          ;dy=4     dx=7     ship
V2FD2:  .byte $10, $00          ;dy=16    dx=0     ship
V2FD4:  .byte $18, $04          ;dy=24    dx=4     ship
V2FD6:  .byte $00, $04          ;dy=0     dx=4     ship
V2FD8:  .byte $E8, $04          ;dy=-24   dx=4     ship
V2FDA:  .byte $F0, $00          ;dy=-16   dx=0     ship
V2FDC:  .byte $FC, $06          ;dy=-4    dx=6     ship
V2FDE:  .byte $08, $00          ;dy=8     dx=0     ship
V2FE0:  .byte $FC, $08          ;dy=-4    dx=8     ship
V2FE2:  .byte $EC, $00          ;dy=-20   dx=0     ship
V2FE4:  .byte $F8, $F8          ;dy=-8    dx=-8    ship
V2FE6:  .byte $08, $00          ;dy=8     dx=0     ship
V2FE8:  .byte $04, $F4          ;dy=4     dx=-12   ship
V2FEA:  .byte $FC, $F4          ;dy=-4    dx=-12   ship
V2FEC:  .byte $F8, $00          ;dy=-8    dx=0     ship
V2FEE:  .byte $08, $F8          ;dy=8     dx=-8    ship
V2FF0:  .byte $18, $14          ;dy=24    dx=20    move (blanked: return leg / flame bridge)
V2FF2:  .byte $E8, $F4          ;dy=-24   dx=-12   thrust flame (white)
V2FF4:  .byte $F0, $0C          ;dy=-16   dx=12    thrust flame (white)
V2FF6:  .byte $10, $0C          ;dy=16    dx=12    thrust flame (white)
V2FF8:  .byte $18, $F4          ;dy=24    dx=-12   thrust flame (white)

;---- inter-picture padding (CRPAGE keeps pictures off page breaks) ----
V28E6:  .byte $00, $00, $00, $00, $00, $00, $00, $00
V28EE:  .byte $00, $00, $00, $00, $00, $00, $00, $00
V28F6:  .byte $00, $00, $00, $00, $00, $00, $00, $00
V28FE:  .byte $00, $00
V29D8:  .byte $00, $00, $00, $00, $00, $00, $00, $00
V29E0:  .byte $00, $00, $00, $00, $00, $00, $00, $00
V29E8:  .byte $00, $00, $00, $00, $00, $00, $00, $00
V29F0:  .byte $00, $00, $00, $00, $00, $00, $00, $00
V29F8:  .byte $00, $00, $00, $00, $00, $00, $00, $00
V2AD8:  .byte $00, $00, $00, $00, $00, $00, $00, $00
V2AE0:  .byte $00, $00, $00, $00, $00, $00, $00, $00
V2AE8:  .byte $00, $00, $00, $00, $00, $00, $00, $00
V2AF0:  .byte $00, $00, $00, $00, $00, $00, $00, $00
V2AF8:  .byte $00, $00, $00, $00, $00, $00, $00, $00
V2BD8:  .byte $00, $00, $00, $00, $00, $00, $00, $00
V2BE0:  .byte $00, $00, $00, $00, $00, $00, $00, $00
V2BE8:  .byte $00, $00, $00, $00, $00, $00, $00, $00
V2BF0:  .byte $00, $00, $00, $00, $00, $00, $00, $00
V2BF8:  .byte $00, $00, $00, $00, $00, $00, $00, $00
V2CD0:  .byte $00, $00, $00, $00, $00, $00, $00, $00
V2CD8:  .byte $00, $00, $00, $00, $00, $00, $00, $00
V2CE0:  .byte $00, $00, $00, $00, $00, $00, $00, $00
V2CE8:  .byte $00, $00, $00, $00, $00, $00, $00, $00
V2CF0:  .byte $00, $00, $00, $00, $00, $00, $00, $00
V2CF8:  .byte $00, $00, $00, $00, $00, $00, $00, $00
V2DFA:  .byte $00, $00, $00, $00, $00, $00
V2EFA:  .byte $00, $00, $00, $00, $00, $00
V2FFA:  .byte $00, $00, $00, $00, $00, $8A

;--------------------------[ AVG display lists ]--------------------------
;Shape names come from vec_names.py, resolved by shapes.py (see
;README.md): glyph tables, program-ROM immediates, the RSOURC
;table, and the JSRL word tables. A name carrying a '?' in
;vec_names.py comes only from AS2ROM source order, which drifts;
;the '?' is not part of the label - such entry points are marked
;UNVERIFIED on their label line instead.

BOXES:           ;JSRL operand $800
;  refs: vector ROM $3AD5
;  refs: main ROM $4F50
;  refs: main ROM $52A5
;  refs: main ROM $5328
;  refs: main ROM $818D
;  refs: main ROM $89CA
;  refs: ... and 1 more
V3000:  JSRL   CNTSCL                 ;AF61
V3002:  VCTR   -510, 248, 0           ;00F8 1E02
V3006:  VCTR   1022, 0, 1             ;0000 23FE
V300A:  VCTR   0, -560, 1             ;1DD0 2000
V300E:  VCTR   -1022, 0, 1            ;0000 3C02
V3012:  VCTR   0, 560, 1              ;0230 2000
V3016:  VCTR   511, 0, 0              ;0000 01FF
V301A:  VCTR   0, -560, 1             ;1DD0 2000
V301E:  VCTR   508, 280, 0            ;0118 01FC
V3022:  VCTR   -1023, 0, 1            ;0000 3C01
V3026:  RTSL                          ;C000

BOXCB:           ;JSRL operand $814
V3028:  JSRL   CNTSCL                 ;AF61
V302A:  VCTR   -255, 248, 0           ;00F8 1F01
V302E:  VCTR   510, 0, 1              ;0000 21FE
V3032:  VCTR   0, -560, 1             ;1DD0 2000
V3036:  VCTR   -510, 0, 1             ;0000 3E02
V303A:  VCTR   0, 560, 1              ;0230 2000
V303E:  VCTR   0, -280, 0             ;1EE8 0000
V3042:  VCTR   510, 0, 1              ;0000 21FE
V3046:  RTSL                          ;C000

BOX1:           ;JSRL operand $824  -- name from AS2ROM source order only, UNVERIFIED
V3048:  VCTR   492, 0, 1              ;0000 21EC
V304C:  VCTR   0, -260, 1             ;1EFC 2000
V3050:  VCTR   -492, 0, 1             ;0000 3E14
V3054:  VCTR   0, 260, 1              ;0104 2000
V3058:  RTSL                          ;C000

BOX2:           ;JSRL operand $82D  -- name from AS2ROM source order only, UNVERIFIED
V305A:  SVEC   10, -10, 0             ;5B05
V305C:  VCTR   470, 0, 1              ;0000 21D6
V3060:  VCTR   0, -240, 1             ;1F10 2000
V3064:  VCTR   -472, 0, 1             ;0000 3E28
V3068:  VCTR   0, 240, 1              ;00F0 2000
V306C:  SVEC   -10, 10, 0             ;451B
V306E:  RTSL                          ;C000

BOX3:           ;JSRL operand $838  -- name from AS2ROM source order only, UNVERIFIED
V3070:  SVEC   20, -20, 0             ;560A
V3072:  VCTR   450, 0, 1              ;0000 21C2
V3076:  VCTR   0, -220, 1             ;1F24 2000
V307A:  VCTR   -450, 0, 1             ;0000 3E3E
V307E:  VCTR   0, 220, 1              ;00DC 2000
V3082:  SVEC   -20, 20, 0             ;4A16
V3084:  RTSL                          ;C000

BOX4:           ;JSRL operand $843  -- name from AS2ROM source order only, UNVERIFIED
V3086:  SVEC   30, -30, 0             ;510F
V3088:  VCTR   430, 0, 1              ;0000 21AE
V308C:  VCTR   0, -200, 1             ;1F38 2000
V3090:  VCTR   -430, 0, 1             ;0000 3E52
V3094:  VCTR   0, 200, 1              ;00C8 2000
V3098:  SVEC   30, -30, 0             ;510F
V309A:  RTSL                          ;C000

LIVEPAR:         ;JSRL operand $84E
;  no lit vectors - beam positioning / clip / advance list,
;  not a drawable shape; renders blank by design
V309C:  SCAL   2, $00                 ;7200
V309E:  VCTR   64, 0, 0               ;0000 0040
V30A2:  RTSL                          ;C000

LIVUDPAR:        ;JSRL operand $852
;  no lit vectors - beam positioning / clip / advance list,
;  not a drawable shape; renders blank by design
V30A4:  SCAL   2, $00                 ;7200
V30A6:  VCTR   -64, 0, 0              ;0000 1FC0
V30AA:  RTSL                          ;C000

LLIVESHIP:      ;JSRL operand $856  -- name from AS2ROM source order only, UNVERIFIED
;  secondary entry points: ULIVESHIP, LLIVUDSHIP, ULIVUDSHIP, CNTRS, CNTHSC
;  no lit vectors - beam positioning / clip / advance list,
;  not a drawable shape; renders blank by design
V30AC:  .word $C09B              ;RTSL 

FRCFLD:          ;JSRL operand $857
;  secondary entry points: FRCFLD, FRCFL, FRBOX
;  no lit vectors - beam positioning / clip / advance list,
;  not a drawable shape; renders blank by design
;  JSRL word table (2 entries) - the 6502 copies one entry
;  into vector RAM; executing it start-to-finish would draw
;  every frame stacked on top of one another
V30AE:  JSRL   $3490                  ;AA48
V30B0:  JSRL   $3F54                  ;AFAA
V30B2:  .word $DA03              ;RTSL 

CHAR.A:         ;JSRL operand $85A  -- name from AS2ROM source order only, UNVERIFIED
;  no lit vectors - beam positioning / clip / advance list,
;  not a drawable shape; renders blank by design
;  refs: vector ROM $33BD
;  refs: vector ROM $3451
V30B4:  JSRL   $3556                  ;AAAB

CNTHSC:          ;JSRL operand $85B
;  no lit vectors - beam positioning / clip / advance list,
;  not a drawable shape; renders blank by design
V30B6:  CNTR                          ;8040
V30B8:  SCAL   3, $00                 ;7300
V30BA:  RTSL                          ;C000

QHEADER:         ;JSRL operand $85E
;  secondary entry points: CHAR.C, CHAR.D, CHAR.E, CHAR.F, CHARF1
V30BC:  CNTR                          ;8040
V30BE:  JSRL   $2300                  ;A180
V30C0:  JSRL   $230A                  ;A185
V30C2:  JMPL   $2342                  ;E1A1

FRCFL:           ;JSRL operand $862
V30C4:  JSRL   CNTSCL                 ;AF61

FRBOX:           ;JSRL operand $863
;  refs: main ROM $62C1
V30C6:  VCTR   -511, -383, 0          ;1E81 1E01
V30CA:  VCTR   1023, 0, 1             ;0000 23FF
V30CE:  VCTR   0, 767, 1              ;02FF 2000
V30D2:  VCTR   -1023, 0, 1            ;0000 3C01
V30D6:  VCTR   0, -767, 1             ;1D01 2000
V30DA:  RTSL                          ;C000

CHR_A:           ;JSRL operand $86E
;  refs: vector ROM $3260
;  refs: vector ROM $3EFE
;  refs: vector ROM $3F02
;  refs: main ROM $792A
V30DC:  SVEC   0, 16, 1               ;4820
V30DE:  SVEC   8, 8, 1                ;4424
V30E0:  SVEC   8, -8, 1               ;5C24
V30E2:  SVEC   0, -16, 1              ;5820
V30E4:  SVEC   -16, 8, 0              ;4418
V30E6:  SVEC   16, 0, 1               ;4028
V30E8:  SVEC   8, -8, 0               ;5C04
V30EA:  RTSL                          ;C000

CHR_B:           ;JSRL operand $876
;  refs: vector ROM $3262
V30EC:  SVEC   0, 24, 1               ;4C20
V30EE:  SVEC   12, 0, 1               ;4026
V30F0:  SVEC   4, -4, 1               ;5E22
V30F2:  SVEC   0, -4, 1               ;5E20
V30F4:  SVEC   -4, -4, 1              ;5E3E
V30F6:  SVEC   -12, 0, 1              ;403A
V30F8:  SVEC   12, 0, 0               ;4006
V30FA:  SVEC   4, -4, 1               ;5E22
V30FC:  SVEC   0, -4, 1               ;5E20
V30FE:  SVEC   -4, -4, 1              ;5E3E
V3100:  SVEC   -12, 0, 1              ;403A
V3102:  JMPL   CHR_SPACE              ;E8C0

CHR_C:           ;JSRL operand $882
;  refs: vector ROM $3264
;  refs: vector ROM $3EF0
;  refs: vector ROM $3F0E
V3104:  SVEC   0, 24, 1               ;4C20
V3106:  SVEC   16, 0, 1               ;4028
V3108:  SVEC   -16, -24, 0            ;5418
V310A:  JMPL   $3206                  ;E903

CHR_D:           ;JSRL operand $886
;  refs: vector ROM $3266
V310C:  SVEC   0, 24, 1               ;4C20
V310E:  SVEC   8, 0, 1                ;4024
V3110:  SVEC   8, -8, 1               ;5C24
V3112:  SVEC   0, -8, 1               ;5C20
V3114:  SVEC   -8, -8, 1              ;5C3C
V3116:  SVEC   -8, 0, 1               ;403C
V3118:  JMPL   CHR_SPACE              ;E8C0

CHR_E:           ;JSRL operand $88D
;  refs: vector ROM $3268
;  refs: main ROM $5554
;  refs: main ROM $5B21
V311A:  SVEC   16, 0, 1               ;4028
V311C:  SVEC   -16, 0, 0              ;4018

CHR_F:           ;JSRL operand $88F
;  refs: vector ROM $326A
V311E:  SVEC   0, 24, 1               ;4C20
V3120:  SVEC   16, 0, 1               ;4028
V3122:  SVEC   -4, -12, 0             ;5A1E
V3124:  SVEC   -12, 0, 1              ;403A
V3126:  SVEC   24, -12, 0             ;5A0C
V3128:  RTSL                          ;C000

CHR_G:           ;JSRL operand $895
;  refs: vector ROM $326C
;  refs: main ROM $6B32
V312A:  SVEC   0, 24, 1               ;4C20
V312C:  SVEC   16, 0, 1               ;4028
V312E:  SVEC   0, -8, 1               ;5C20
V3130:  SVEC   -8, -8, 0              ;5C1C
V3132:  SVEC   8, 0, 1                ;4024
V3134:  SVEC   0, -8, 1               ;5C20
V3136:  JMPL   $317E                  ;E8BF

CHR_H:           ;JSRL operand $89C
;  refs: vector ROM $326E
;  refs: main ROM $6E29
V3138:  SVEC   0, 24, 1               ;4C20
V313A:  SVEC   0, -12, 0              ;5A00
V313C:  SVEC   16, 0, 1               ;4028
V313E:  SVEC   0, 12, 0               ;4600
V3140:  JMPL   $3238                  ;E91C

CHR_I:           ;JSRL operand $8A1
;  refs: vector ROM $3270
;  refs: vector ROM $3F06
;  refs: vector ROM $3F0A
V3142:  SVEC   16, 0, 1               ;4028
V3144:  SVEC   -16, 24, 0             ;4C18
V3146:  SVEC   16, 0, 1               ;4028
V3148:  SVEC   -8, 0, 0               ;401C
V314A:  SVEC   0, -24, 1              ;5420
V314C:  SVEC   16, 0, 0               ;4008
V314E:  RTSL                          ;C000

CHR_J:           ;JSRL operand $8A8
;  refs: vector ROM $3271
;  refs: vector ROM $3272
;  refs: vector ROM $328B
;  refs: main ROM $7646
;  refs: main ROM $7647
;  refs: main ROM $7648
;  refs: ... and 1 more
V3150:  SVEC   0, 8, 0                ;4400
V3152:  SVEC   8, -8, 1               ;5C24
V3154:  SVEC   8, 0, 1                ;4024
V3156:  JMPL   $31C2                  ;E8E1

CHR_K:           ;JSRL operand $8AC
;  refs: vector ROM $3274
V3158:  SVEC   0, 24, 1               ;4C20
V315A:  SVEC   12, 0, 0               ;4006
V315C:  SVEC   -12, -12, 1            ;5A3A
V315E:  SVEC   12, -12, 1             ;5A26
V3160:  SVEC   12, 0, 0               ;4006
V3162:  RTSL                          ;C000

CHR_L:           ;JSRL operand $8B2
;  refs: vector ROM $3276
;  refs: vector ROM $3EF4
V3164:  SVEC   0, 24, 0               ;4C00
V3166:  SVEC   0, -24, 1              ;5420
V3168:  JMPL   $3206                  ;E903

CHR_M:           ;JSRL operand $8B5
;  refs: vector ROM $3278
;  refs: vector ROM $3EEE
;  refs: vector ROM $3EF2
;  refs: main ROM $69C1
V316A:  SVEC   0, 24, 1               ;4C20
V316C:  SVEC   8, -8, 1               ;5C24
V316E:  SVEC   8, 8, 1                ;4424
V3170:  JMPL   $3238                  ;E91C

CHR_N:           ;JSRL operand $8B9
;  refs: vector ROM $327A
;  refs: vector ROM $3F0C
;  refs: main ROM $5055
V3172:  SVEC   0, 24, 1               ;4C20
V3174:  SVEC   16, -24, 1             ;5428
V3176:  JMPL   $31C2                  ;E8E1

CHR_0:           ;JSRL operand $8BC
;  refs: vector ROM $324C
;  refs: vector ROM $327C
V3178:  SVEC   0, 24, 1               ;4C20
V317A:  SVEC   16, 0, 1               ;4028
V317C:  SVEC   0, -24, 1              ;5420
V317E:  SVEC   -16, 0, 1              ;4038

CHR_SPACE:       ;JSRL operand $8C0
;  no lit vectors - beam positioning / clip / advance list,
;  not a drawable shape; renders blank by design
;  refs: vector ROM $3102
;  refs: vector ROM $3118
;  refs: vector ROM $324A
;  refs: vector ROM $3EFC
;  refs: vector ROM $3F08
;  refs: main ROM $85EE
V3180:  SVEC   24, 0, 0               ;400C
V3182:  RTSL                          ;C000

CHR_P:           ;JSRL operand $8C2
;  refs: vector ROM $327E
V3184:  SVEC   0, 24, 1               ;4C20
V3186:  SVEC   16, 0, 1               ;4028
V3188:  SVEC   0, -12, 1              ;5A20
V318A:  SVEC   -16, 0, 1              ;4038
V318C:  JMPL   $3126                  ;E893

CHR_Q:           ;JSRL operand $8C7
;  refs: vector ROM $3280
V318E:  SVEC   0, 24, 1               ;4C20
V3190:  SVEC   16, 0, 1               ;4028
V3192:  SVEC   0, -16, 1              ;5820
V3194:  SVEC   -8, -8, 1              ;5C3C
V3196:  SVEC   -8, 0, 1               ;403C
V3198:  SVEC   8, 8, 0                ;4404
V319A:  SVEC   8, -8, 1               ;5C24
V319C:  JMPL   $3208                  ;E904

CHR_R:           ;JSRL operand $8CF
;  refs: vector ROM $3282
;  refs: vector ROM $3F04
V319E:  SVEC   0, 24, 1               ;4C20
V31A0:  SVEC   16, 0, 1               ;4028
V31A2:  SVEC   0, -12, 1              ;5A20
V31A4:  SVEC   -16, 0, 1              ;4038
V31A6:  SVEC   4, 0, 0                ;4002
V31A8:  SVEC   12, -12, 1             ;5A26
V31AA:  JMPL   $3208                  ;E904

CHR_5:           ;JSRL operand $8D6
;  refs: vector ROM $3256
;  refs: vector ROM $3284
V31AC:  SVEC   16, 0, 1               ;4028
V31AE:  SVEC   0, 12, 1               ;4620
V31B0:  SVEC   -16, 0, 1              ;4038
V31B2:  SVEC   0, 12, 1               ;4620
V31B4:  SVEC   16, 0, 1               ;4028
V31B6:  JMPL   $31C4                  ;E8E2

CHR_T:           ;JSRL operand $8DC
;  refs: vector ROM $3286
;  refs: vector ROM $3F00
;  refs: main ROM $7645
V31B8:  SVEC   0, 24, 0               ;4C00
V31BA:  JMPL   $3146                  ;E8A3

CHR_U:           ;JSRL operand $8DE
;  refs: vector ROM $3288
V31BC:  SVEC   0, 24, 0               ;4C00
V31BE:  SVEC   0, -24, 1              ;5420
V31C0:  SVEC   16, 0, 1               ;4028
V31C2:  SVEC   0, 24, 1               ;4C20
V31C4:  SVEC   8, -24, 0              ;5404
V31C6:  RTSL                          ;C000

CHR_V:           ;JSRL operand $8E4
;  refs: vector ROM $328A
;  refs: main ROM $8CF1
V31C8:  SVEC   0, 24, 0               ;4C00
V31CA:  SVEC   8, -24, 1              ;5424
V31CC:  SVEC   8, 24, 1               ;4C24
V31CE:  JMPL   $31C4                  ;E8E2

CHR_W:           ;JSRL operand $8E8
;  refs: vector ROM $328C
;  refs: main ROM $4C9D
;  refs: main ROM $6F88
;  refs: main ROM $76F3
;  refs: main ROM $76F4
;  refs: main ROM $76F5
;  refs: ... and 1 more
V31D0:  SVEC   0, 24, 0               ;4C00
V31D2:  SVEC   0, -24, 1              ;5420
V31D4:  SVEC   8, 8, 1                ;4424
V31D6:  SVEC   8, -8, 1               ;5C24
V31D8:  JMPL   $31C2                  ;E8E1

CHR_X:           ;JSRL operand $8ED
;  refs: vector ROM $328E
;  refs: vector ROM $3EF6
;  refs: vector ROM $3EF8
;  refs: vector ROM $3EFA
V31DA:  SVEC   16, 24, 1              ;4C28
V31DC:  SVEC   -16, 0, 0              ;4018
V31DE:  SVEC   16, -24, 1             ;5428
V31E0:  JMPL   $323A                  ;E91D

CHR_Y:           ;JSRL operand $8F1
;  refs: vector ROM $3290
;  refs: main ROM $826E
V31E2:  SVEC   8, 0, 0                ;4004
V31E4:  SVEC   0, 16, 1               ;4820
V31E6:  SVEC   -8, 8, 1               ;443C
V31E8:  SVEC   16, 0, 0               ;4008
V31EA:  SVEC   -8, -8, 1              ;5C3C
V31EC:  SVEC   16, -16, 0             ;5808
V31EE:  RTSL                          ;C000

CHR_Z:           ;JSRL operand $8F8
;  refs: vector ROM $3292
V31F0:  SVEC   0, 24, 0               ;4C00
V31F2:  SVEC   16, 0, 1               ;4028
V31F4:  SVEC   -16, -24, 1            ;5438
V31F6:  JMPL   $3206                  ;E903

CHR_1:           ;JSRL operand $8FC
;  refs: vector ROM $324E
;  refs: vector ROM $32E0
V31F8:  SVEC   8, 24, 0               ;4C04
V31FA:  JMPL   $314A                  ;E8A5

CHR_2:           ;JSRL operand $8FE
;  refs: vector ROM $3250
;  refs: vector ROM $32E4
V31FC:  SVEC   0, 24, 0               ;4C00
V31FE:  SVEC   16, 0, 1               ;4028
V3200:  SVEC   0, -12, 1              ;5A20
V3202:  SVEC   -16, 0, 1              ;4038
V3204:  SVEC   0, -12, 1              ;5A20
V3206:  SVEC   16, 0, 1               ;4028
V3208:  SVEC   8, 0, 0                ;4004
V320A:  RTSL                          ;C000

CHR_3:           ;JSRL operand $906
;  refs: vector ROM $3252
;  refs: main ROM $484C
;  refs: main ROM $4AF4
;  refs: main ROM $4DD2
;  refs: main ROM $4EAC
;  refs: main ROM $529D
;  refs: ... and 5 more
V320C:  SVEC   0, 24, 0               ;4C00
V320E:  SVEC   16, 0, 1               ;4028
V3210:  SVEC   0, -24, 1              ;5420
V3212:  SVEC   -16, 0, 1              ;4038
V3214:  SVEC   0, 12, 0               ;4600
V3216:  SVEC   16, 0, 1               ;4028
V3218:  SVEC   8, -12, 0              ;5A04
V321A:  RTSL                          ;C000

CHR_4:           ;JSRL operand $90E
;  refs: vector ROM $3254
;  refs: main ROM $4093
;  refs: main ROM $4E26
;  refs: main ROM $53A6
;  refs: main ROM $5B1B
;  refs: main ROM $8901
;  refs: ... and 1 more
V321C:  SVEC   0, 24, 0               ;4C00
V321E:  SVEC   0, -12, 1              ;5A20
V3220:  SVEC   16, 0, 1               ;4028
V3222:  SVEC   0, 12, 0               ;4600
V3224:  JMPL   $3238                  ;E91C

CHR_6:           ;JSRL operand $913
;  refs: vector ROM $3258
;  refs: main ROM $6032
;  refs: main ROM $8396
;  refs: main ROM $839B
;  refs: main ROM $8838
V3226:  SVEC   0, 12, 0               ;4600
V3228:  SVEC   16, 0, 1               ;4028
V322A:  SVEC   0, -12, 1              ;5A20
V322C:  SVEC   -16, 0, 1              ;4038
V322E:  SVEC   0, 24, 1               ;4C20
V3230:  SVEC   24, -24, 0             ;540C
V3232:  RTSL                          ;C000

CHR_7:           ;JSRL operand $91A
;  refs: vector ROM $325A
V3234:  SVEC   0, 24, 0               ;4C00
V3236:  SVEC   16, 0, 1               ;4028
V3238:  SVEC   0, -24, 1              ;5420
V323A:  SVEC   8, 0, 0                ;4004
V323C:  RTSL                          ;C000

CHR_8:           ;JSRL operand $91F
;  refs: vector ROM $325C
;  refs: vector ROM $37FB
;  refs: vector ROM $3A27
;  refs: vector ROM $3BE7
V323E:  SVEC   0, 24, 1               ;4C20
V3240:  JMPL   $320E                  ;E907

CHR_9:           ;JSRL operand $921
;  refs: vector ROM $325E
;  refs: main ROM $4D73
;  refs: main ROM $5D16
;  refs: main ROM $8D7A
V3242:  SVEC   16, 12, 0              ;4608
V3244:  SVEC   -16, 0, 1              ;4038
V3246:  SVEC   0, 12, 1               ;4620
V3248:  JMPL   $3236                  ;E91B
V324A:  JSRL   CHR_SPACE              ;A8C0
V324C:  JSRL   CHR_0                  ;A8BC
V324E:  JSRL   CHR_1                  ;A8FC
V3250:  JSRL   CHR_2                  ;A8FE
V3252:  JSRL   CHR_3                  ;A906
V3254:  JSRL   CHR_4                  ;A90E
V3256:  JSRL   CHR_5                  ;A8D6
V3258:  JSRL   CHR_6                  ;A913
V325A:  JSRL   CHR_7                  ;A91A
V325C:  JSRL   CHR_8                  ;A91F
V325E:  JSRL   CHR_9                  ;A921
V3260:  JSRL   CHR_A                  ;A86E
V3262:  JSRL   CHR_B                  ;A876
V3264:  JSRL   CHR_C                  ;A882
V3266:  JSRL   CHR_D                  ;A886
V3268:  JSRL   CHR_E                  ;A88D
V326A:  JSRL   CHR_F                  ;A88F
V326C:  JSRL   CHR_G                  ;A895
V326E:  JSRL   CHR_H                  ;A89C
V3270:  JSRL   CHR_I                  ;A8A1
V3272:  JSRL   CHR_J                  ;A8A8
V3274:  JSRL   CHR_K                  ;A8AC
V3276:  JSRL   CHR_L                  ;A8B2
V3278:  JSRL   CHR_M                  ;A8B5
V327A:  JSRL   CHR_N                  ;A8B9
V327C:  JSRL   CHR_0                  ;A8BC
V327E:  JSRL   CHR_P                  ;A8C2
V3280:  JSRL   CHR_Q                  ;A8C7
V3282:  JSRL   CHR_R                  ;A8CF
V3284:  JSRL   CHR_5                  ;A8D6
V3286:  JSRL   CHR_T                  ;A8DC
V3288:  JSRL   CHR_U                  ;A8DE
V328A:  JSRL   CHR_V                  ;A8E4
V328C:  JSRL   CHR_W                  ;A8E8
V328E:  JSRL   CHR_X                  ;A8ED
V3290:  JSRL   CHR_Y                  ;A8F1
V3292:  JSRL   CHR_Z                  ;A8F8
V3294:  JSRL   HALF                   ;A96D
V3296:  RTSL                          ;C000

UCHR.B:         ;JSRL operand $94C  -- name from AS2ROM source order only, UNVERIFIED
;  secondary entry points: UCHR.C, UCHR.D, UCHR.E, UCHR.F, UCHRF1
;  refs: vector ROM $34F0
;  refs: main ROM $4934
;  refs: main ROM $4BB1
V3298:  VCTR   -512, -384, 0          ;1E80 1E00
V329C:  VCTR   767, 767, 5            ;02FF A2FF
V32A0:  VCTR   256, -256, 5           ;1F00 A100
V32A4:  VCTR   -511, -511, 5          ;1E01 BE01
V32A8:  VCTR   -512, 512, 5           ;0200 BE00
V32AC:  VCTR   256, 255, 5            ;00FF A100
V32B0:  VCTR   767, -767, 5           ;1D01 A2FF
V32B4:  CNTR                          ;8040
V32B6:  VCTR   511, 383, 0            ;017F 01FF
V32BA:  VCTR   -767, -767, 5          ;1D01 BD01
V32BE:  VCTR   -256, 255, 5           ;00FF BF00
V32C2:  VCTR   512, 512, 5            ;0200 A200
V32C6:  VCTR   511, -511, 5           ;1E01 A1FF
V32CA:  VCTR   -256, -256, 5          ;1F00 BF00
V32CE:  VCTR   -767, 767, 5           ;02FF BD01
V32D2:  CNTR                          ;8040
V32D4:  VCTR   -496, -128, 0          ;1F80 1E10
V32D8:  JMPL   $324A                  ;E925

HALF:            ;JSRL operand $96D
;  refs: vector ROM $3294
V32DA:  SVEC   16, 24, 6              ;4CC8
V32DC:  SVEC   -14, -10, 0            ;5B19
V32DE:  SCAL   2, $00                 ;7200
V32E0:  JSRL   CHR_1                  ;A8FC
V32E2:  SVEC   -8, -28, 1             ;523C
V32E4:  JSRL   CHR_2                  ;A8FE
V32E6:  SCAL   1, $00                 ;7100
V32E8:  RTSL                          ;C000

CHRF_A:          ;JSRL operand $975
;  refs: vector ROM $346E
;  refs: main ROM $753D
V32EA:  SVEC   0, -16, 5              ;58A0
V32EC:  SVEC   -8, -8, 5              ;5CBC
V32EE:  SVEC   -8, 8, 5               ;44BC
V32F0:  SVEC   0, 16, 5               ;48A0
V32F2:  SVEC   16, -8, 0              ;5C08
V32F4:  SVEC   -16, 0, 5              ;40B8
V32F6:  SVEC   -8, 8, 0               ;441C
V32F8:  RTSL                          ;C000

CHRF_B:          ;JSRL operand $97D
;  refs: vector ROM $3470
;  refs: main ROM $5AB7
V32FA:  SVEC   0, -24, 5              ;54A0
V32FC:  SVEC   -12, 0, 5              ;40BA
V32FE:  SVEC   -4, 4, 5               ;42BE
V3300:  SVEC   0, 4, 5                ;42A0
V3302:  SVEC   4, 4, 5                ;42A2
V3304:  SVEC   12, 0, 5               ;40A6
V3306:  SVEC   -12, 0, 0              ;401A
V3308:  SVEC   -4, 4, 5               ;42BE
V330A:  SVEC   0, 4, 5                ;42A0
V330C:  SVEC   4, 4, 5                ;42A2
V330E:  SVEC   12, 0, 5               ;40A6
V3310:  JMPL   CHRF_SPACE             ;E9C7

CHRF_C:          ;JSRL operand $989
;  refs: vector ROM $3472
;  refs: main ROM $8A25
V3312:  SVEC   0, -24, 5              ;54A0
V3314:  SVEC   -16, 0, 5              ;40B8
V3316:  SVEC   16, 24, 0              ;4C08
V3318:  JMPL   $3414                  ;EA0A

CHRF_D:          ;JSRL operand $98D
;  refs: vector ROM $3474
;  refs: main ROM $522A
;  refs: main ROM $73DF
;  refs: main ROM $73FE
;  refs: main ROM $8D9B
V331A:  SVEC   0, -24, 5              ;54A0
V331C:  SVEC   -8, 0, 5               ;40BC
V331E:  SVEC   -8, 8, 5               ;44BC
V3320:  SVEC   0, 8, 5                ;44A0
V3322:  SVEC   8, 8, 5                ;44A4
V3324:  SVEC   8, 0, 5                ;40A4
V3326:  JMPL   CHRF_SPACE             ;E9C7

CHRF_E:          ;JSRL operand $994
;  refs: vector ROM $3476
V3328:  SVEC   -16, 0, 5              ;40B8
V332A:  SVEC   16, 0, 0               ;4008

CHRF_F:          ;JSRL operand $996
;  refs: vector ROM $3478
V332C:  SVEC   0, -24, 5              ;54A0
V332E:  SVEC   -16, 0, 5              ;40B8
V3330:  SVEC   4, 12, 0               ;4602
V3332:  SVEC   12, 0, 5               ;40A6
V3334:  SVEC   -24, 12, 0             ;4614
V3336:  RTSL                          ;C000

CHRF_G:          ;JSRL operand $99C
;  refs: vector ROM $347A
;  refs: main ROM $6E38
V3338:  SVEC   0, -24, 5              ;54A0
V333A:  SVEC   -16, 0, 5              ;40B8
V333C:  SVEC   0, 8, 5                ;44A0
V333E:  SVEC   8, 8, 0                ;4404
V3340:  SVEC   -8, 0, 5               ;40BC
V3342:  SVEC   0, 8, 5                ;44A0
V3344:  JMPL   $338C                  ;E9C6

CHRF_H:          ;JSRL operand $9A3
;  refs: vector ROM $347C
V3346:  SVEC   0, -24, 5              ;54A0
V3348:  SVEC   0, 12, 0               ;4600
V334A:  SVEC   -16, 0, 5              ;40B8
V334C:  SVEC   0, -12, 0              ;5A00
V334E:  JMPL   $3446                  ;EA23

CHRF_I:          ;JSRL operand $9A8
;  refs: vector ROM $347E
;  refs: main ROM $4238
;  refs: main ROM $5C53
;  refs: main ROM $5C5C
;  refs: main ROM $6758
;  refs: main ROM $8191
;  refs: ... and 1 more
V3350:  SVEC   -16, 0, 5              ;40B8
V3352:  SVEC   16, -24, 0             ;5408
V3354:  SVEC   -16, 0, 5              ;40B8
V3356:  SVEC   8, 0, 0                ;4004
V3358:  SVEC   0, 24, 5               ;4CA0
V335A:  SVEC   -16, 0, 0              ;4018
V335C:  RTSL                          ;C000

CHRF_J:          ;JSRL operand $9AF
;  refs: vector ROM $3480
V335E:  SVEC   0, -8, 0               ;5C00
V3360:  SVEC   -8, 8, 5               ;44BC
V3362:  SVEC   -8, 0, 5               ;40BC
V3364:  JMPL   $33D0                  ;E9E8

CHRF_K:          ;JSRL operand $9B3
;  refs: vector ROM $3482
V3366:  SVEC   0, -24, 5              ;54A0
V3368:  SVEC   -12, 0, 0              ;401A
V336A:  SVEC   12, 12, 5              ;46A6
V336C:  SVEC   -12, 12, 5             ;46BA
V336E:  SVEC   -12, 0, 0              ;401A
V3370:  RTSL                          ;C000

CHRF_L:          ;JSRL operand $9B9
;  refs: vector ROM $3484
;  refs: main ROM $443B
;  refs: main ROM $66C8
V3372:  SVEC   0, -24, 0              ;5400
V3374:  SVEC   0, 24, 5               ;4CA0
V3376:  JMPL   $3414                  ;EA0A

CHRF_M:          ;JSRL operand $9BC
;  refs: vector ROM $3486
V3378:  SVEC   0, -24, 5              ;54A0
V337A:  SVEC   -8, 8, 5               ;44BC
V337C:  SVEC   -8, -8, 5              ;5CBC
V337E:  JMPL   $3446                  ;EA23

CHRF_N:          ;JSRL operand $9C0
;  refs: vector ROM $3488
;  refs: main ROM $4B73
;  refs: main ROM $8E41
V3380:  SVEC   0, -24, 5              ;54A0
V3382:  SVEC   -16, 24, 5             ;4CB8
V3384:  JMPL   $33D0                  ;E9E8

CHRF_0:          ;JSRL operand $9C3
;  refs: vector ROM $345A
;  refs: vector ROM $348A
V3386:  SVEC   0, -24, 5              ;54A0
V3388:  SVEC   -16, 0, 5              ;40B8
V338A:  SVEC   0, 24, 5               ;4CA0
V338C:  SVEC   16, 0, 5               ;40A8

CHRF_SPACE:      ;JSRL operand $9C7
;  no lit vectors - beam positioning / clip / advance list,
;  not a drawable shape; renders blank by design
;  refs: vector ROM $3310
;  refs: vector ROM $3326
;  refs: vector ROM $3458
V338E:  SVEC   -24, 0, 0              ;4014
V3390:  RTSL                          ;C000

CHRF_P:          ;JSRL operand $9C9
;  refs: vector ROM $348C
V3392:  SVEC   0, -24, 5              ;54A0
V3394:  SVEC   -16, 0, 5              ;40B8
V3396:  SVEC   0, 12, 5               ;46A0
V3398:  SVEC   16, 0, 5               ;40A8
V339A:  JMPL   $3334                  ;E99A

CHRF_Q:          ;JSRL operand $9CE
;  refs: vector ROM $348E
V339C:  SVEC   0, -24, 5              ;54A0
V339E:  SVEC   -16, 0, 5              ;40B8
V33A0:  SVEC   0, 16, 5               ;48A0
V33A2:  SVEC   8, 8, 5                ;44A4
V33A4:  SVEC   8, 0, 5                ;40A4
V33A6:  SVEC   -8, -8, 0              ;5C1C
V33A8:  SVEC   -8, 8, 5               ;44BC
V33AA:  JMPL   $3416                  ;EA0B

CHRF_R:          ;JSRL operand $9D6
;  refs: vector ROM $3490
;  refs: main ROM $4FBF
V33AC:  SVEC   0, -24, 5              ;54A0
V33AE:  SVEC   -16, 0, 5              ;40B8
V33B0:  SVEC   0, 12, 5               ;46A0
V33B2:  SVEC   16, 0, 5               ;40A8
V33B4:  SVEC   -4, 0, 0               ;401E
V33B6:  SVEC   -12, 12, 5             ;46BA
V33B8:  JMPL   $3416                  ;EA0B

CHRF_5:          ;JSRL operand $9DD
;  refs: vector ROM $3464
;  refs: vector ROM $3492
V33BA:  SVEC   -16, 0, 5              ;40B8
V33BC:  SVEC   0, -12, 5              ;5AA0
V33BE:  SVEC   16, 0, 5               ;40A8
V33C0:  SVEC   0, -12, 5              ;5AA0
V33C2:  SVEC   -16, 0, 5              ;40B8
V33C4:  JMPL   $33D2                  ;E9E9

CHRF_T:          ;JSRL operand $9E3
;  refs: vector ROM $3494
V33C6:  SVEC   0, -24, 0              ;5400
V33C8:  JMPL   $3354                  ;E9AA

CHRF_U:          ;JSRL operand $9E5
;  refs: vector ROM $3496
V33CA:  SVEC   0, -24, 0              ;5400
V33CC:  SVEC   0, 24, 5               ;4CA0
V33CE:  SVEC   -16, 0, 5              ;40B8
V33D0:  SVEC   0, -24, 5              ;54A0
V33D2:  SVEC   -8, 24, 0              ;4C1C
V33D4:  RTSL                          ;C000

CHRF_V:          ;JSRL operand $9EB
;  refs: vector ROM $3498
V33D6:  SVEC   0, -24, 0              ;5400
V33D8:  SVEC   -8, 24, 5              ;4CBC
V33DA:  SVEC   -8, -24, 5             ;54BC
V33DC:  JMPL   $33D2                  ;E9E9

CHRF_W:          ;JSRL operand $9EF
;  refs: vector ROM $349A
V33DE:  SVEC   0, -24, 0              ;5400
V33E0:  SVEC   0, 24, 5               ;4CA0
V33E2:  SVEC   -8, -8, 5              ;5CBC
V33E4:  SVEC   -8, 8, 5               ;44BC
V33E6:  JMPL   $33D0                  ;E9E8

CHRF_X:          ;JSRL operand $9F4
;  refs: vector ROM $349C
V33E8:  SVEC   -16, -24, 5            ;54B8
V33EA:  SVEC   16, 0, 0               ;4008
V33EC:  SVEC   -16, 24, 5             ;4CB8
V33EE:  JMPL   $3448                  ;EA24

CHRF_Y:          ;JSRL operand $9F8
;  refs: vector ROM $349E
;  refs: main ROM $8EA0
V33F0:  SVEC   -8, 0, 0               ;401C
V33F2:  SVEC   0, -16, 5              ;58A0
V33F4:  SVEC   8, -8, 5               ;5CA4
V33F6:  SVEC   -16, 0, 0              ;4018
V33F8:  SVEC   8, 8, 5                ;44A4
V33FA:  SVEC   -16, 16, 0             ;4818
V33FC:  RTSL                          ;C000

CHRF_Z:          ;JSRL operand $9FF
;  refs: vector ROM $34A0
;  refs: main ROM $8281
;  refs: main ROM $83C9
V33FE:  SVEC   0, -24, 0              ;5400
V3400:  SVEC   -16, 0, 5              ;40B8
V3402:  SVEC   16, 24, 5              ;4CA8
V3404:  JMPL   $3414                  ;EA0A

CHRF_1:          ;JSRL operand $A03
;  refs: vector ROM $345C
;  refs: main ROM $4F94
;  refs: main ROM $6FFF
;  refs: main ROM $7066
;  refs: main ROM $76EB
;  refs: main ROM $770D
V3406:  SVEC   -8, -24, 0             ;541C
V3408:  JMPL   $3358                  ;E9AC

CHRF_2:          ;JSRL operand $A05
;  refs: vector ROM $345E
;  refs: main ROM $6F4F
V340A:  SVEC   0, -24, 0              ;5400
V340C:  SVEC   -16, 0, 5              ;40B8
V340E:  SVEC   0, 12, 5               ;46A0
V3410:  SVEC   16, 0, 5               ;40A8
V3412:  SVEC   0, 12, 5               ;46A0
V3414:  SVEC   -16, 0, 5              ;40B8
V3416:  SVEC   -8, 0, 0               ;401C
V3418:  RTSL                          ;C000

CHRF_3:          ;JSRL operand $A0D
;  refs: vector ROM $3460
;  refs: main ROM $77E4
V341A:  SVEC   0, -24, 0              ;5400
V341C:  SVEC   -16, 0, 5              ;40B8
V341E:  SVEC   0, 24, 5               ;4CA0
V3420:  SVEC   16, 0, 5               ;40A8
V3422:  SVEC   0, -12, 0              ;5A00
V3424:  SVEC   -16, 0, 5              ;40B8
V3426:  SVEC   -8, 12, 0              ;461C
V3428:  RTSL                          ;C000

CHRF_4:          ;JSRL operand $A15
;  refs: vector ROM $3462
V342A:  SVEC   0, -24, 0              ;5400
V342C:  SVEC   0, 12, 5               ;46A0
V342E:  SVEC   -16, 0, 5              ;40B8
V3430:  SVEC   0, -12, 0              ;5A00
V3432:  JMPL   $3446                  ;EA23

CHRF_6:          ;JSRL operand $A1A
;  refs: vector ROM $3466
V3434:  SVEC   0, -12, 0              ;5A00
V3436:  SVEC   -16, 0, 5              ;40B8
V3438:  SVEC   0, 12, 5               ;46A0
V343A:  SVEC   16, 0, 5               ;40A8
V343C:  SVEC   0, -24, 5              ;54A0
V343E:  SVEC   -24, 24, 0             ;4C14
V3440:  RTSL                          ;C000

CHRF_7:          ;JSRL operand $A21
;  refs: vector ROM $3468
V3442:  SVEC   0, -24, 0              ;5400
V3444:  SVEC   -16, 0, 5              ;40B8
V3446:  SVEC   0, 24, 5               ;4CA0
V3448:  SVEC   -8, 0, 0               ;401C
V344A:  RTSL                          ;C000

CHRF_8:          ;JSRL operand $A26
;  refs: vector ROM $346A
V344C:  SVEC   0, -24, 5              ;54A0
V344E:  JMPL   $341C                  ;EA0E

CHRF_9:          ;JSRL operand $A28
;  refs: vector ROM $346C
;  refs: main ROM $8725
V3450:  SVEC   -16, -12, 0            ;5A18
V3452:  SVEC   16, 0, 5               ;40A8
V3454:  SVEC   0, -12, 5              ;5AA0
V3456:  JMPL   $3444                  ;EA22
V3458:  JSRL   CHRF_SPACE             ;A9C7
V345A:  JSRL   CHRF_0                 ;A9C3
V345C:  JSRL   CHRF_1                 ;AA03
V345E:  JSRL   CHRF_2                 ;AA05
V3460:  JSRL   CHRF_3                 ;AA0D
V3462:  JSRL   CHRF_4                 ;AA15
V3464:  JSRL   CHRF_5                 ;A9DD
V3466:  JSRL   CHRF_6                 ;AA1A
V3468:  JSRL   CHRF_7                 ;AA21
V346A:  JSRL   CHRF_8                 ;AA26
V346C:  JSRL   CHRF_9                 ;AA28
V346E:  JSRL   CHRF_A                 ;A975
V3470:  JSRL   CHRF_B                 ;A97D
V3472:  JSRL   CHRF_C                 ;A989
V3474:  JSRL   CHRF_D                 ;A98D
V3476:  JSRL   CHRF_E                 ;A994
V3478:  JSRL   CHRF_F                 ;A996
V347A:  JSRL   CHRF_G                 ;A99C
V347C:  JSRL   CHRF_H                 ;A9A3
V347E:  JSRL   CHRF_I                 ;A9A8
V3480:  JSRL   CHRF_J                 ;A9AF
V3482:  JSRL   CHRF_K                 ;A9B3
V3484:  JSRL   CHRF_L                 ;A9B9
V3486:  JSRL   CHRF_M                 ;A9BC
V3488:  JSRL   CHRF_N                 ;A9C0
V348A:  JSRL   CHRF_0                 ;A9C3
V348C:  JSRL   CHRF_P                 ;A9C9
V348E:  JSRL   CHRF_Q                 ;A9CE
V3490:  JSRL   CHRF_R                 ;A9D6
V3492:  JSRL   CHRF_5                 ;A9DD
V3494:  JSRL   CHRF_T                 ;A9E3
V3496:  JSRL   CHRF_U                 ;A9E5
V3498:  JSRL   CHRF_V                 ;A9EB
V349A:  JSRL   CHRF_W                 ;A9EF
V349C:  JSRL   CHRF_X                 ;A9F4
V349E:  JSRL   CHRF_Y                 ;A9F8
V34A0:  JSRL   CHRF_Z                 ;A9FF
V34A2:  VCTR   -256, 16, 0            ;0010 1F00
V34A6:  RTSL                          ;C000

CLPAT:           ;JSRL operand $A54
;  refs: vector ROM $33C7
V34A8:  VCTR   256, 0, 7              ;0000 E100
V34AC:  JSRL   $34A2                  ;AA51

CLPT2:           ;JSRL operand $A57
V34AE:  VCTR   256, 0, 6              ;0000 C100
V34B2:  JSRL   $34A2                  ;AA51
V34B4:  VCTR   256, 0, 5              ;0000 A100
V34B8:  JSRL   $34A2                  ;AA51
V34BA:  VCTR   256, 0, 4              ;0000 8100
V34BE:  JSRL   $34A2                  ;AA51
V34C0:  VCTR   256, 0, 3              ;0000 6100
V34C4:  JSRL   $34A2                  ;AA51
V34C6:  VCTR   256, 0, 2              ;0000 4100
V34CA:  RTSL                          ;C000

CL73:            ;JSRL operand $A66
V34CC:  COLOR  $7, 1                  ;6417
V34CE:  VCTR   64, 0, 2               ;0000 4040
V34D2:  VCTR   -320, 16, 0            ;0010 1EC0
V34D6:  VCTR   256, 0, 1              ;0000 2100
V34DA:  RTSL                          ;C000

VLINE:           ;JSRL operand $A6E
;  secondary entry points: HYSTR
V34DC:  VCTR   0, -767, 1             ;1D01 2000
V34E0:  CNTR                          ;8040
V34E2:  RTSL                          ;C000

HLINE:           ;JSRL operand $A72
V34E4:  VCTR   1023, 0, 1             ;0000 23FF
V34E8:  CNTR                          ;8040
V34EA:  RTSL                          ;C000

QTST6:           ;JSRL operand $A76
;  secondary entry points: WNDSET
V34EC:  COLOR  $7, 12                 ;64C7
V34EE:  CNTR                          ;8040
V34F0:  JMPL   UCHR.B                 ;E94C

HYSTR:           ;JSRL operand $A79
V34F2:  CNTR                          ;8040
V34F4:  SCAL   0, $00                 ;7000
V34F6:  VCTR   0, 192, 0              ;00C0 0000
V34FA:  JSRL   LONE                   ;AA90
V34FC:  SVEC   10, 0, 1               ;4025
V34FE:  CNTR                          ;8040
V3500:  VCTR   0, -192, 0             ;1F40 0000
V3504:  JSRL   LONE                   ;AA90
V3506:  SVEC   10, 0, 1               ;4025
V3508:  CNTR                          ;8040
V350A:  VCTR   256, 0, 0              ;0000 0100
V350E:  JSRL   LONE                   ;AA90
V3510:  SVEC   0, 10, 1               ;4520
V3512:  CNTR                          ;8040
V3514:  VCTR   -256, 0, 0             ;0000 1F00
V3518:  JSRL   LONE                   ;AA90
V351A:  SVEC   0, 10, 1               ;4520
V351C:  CNTR                          ;8040
V351E:  RTSL                          ;C000

LONE:           ;JSRL operand $A90  -- name from AS2ROM source order only, UNVERIFIED
;  secondary entry points: RHTSHP
;  no lit vectors - beam positioning / clip / advance list,
;  not a drawable shape; renders blank by design
;  refs: vector ROM $34FA
;  refs: vector ROM $3504
;  refs: vector ROM $350E
;  refs: vector ROM $3518
V3520:  COLOR  $7, 8                  ;6487
V3522:  CNTR                          ;8040
V3524:  CNTR                          ;8040
V3526:  RTSL                          ;C000

WNDSE:           ;JSRL operand $A94
;  secondary entry points: LFTSH2
;  no lit vectors - beam positioning / clip / advance list,
;  not a drawable shape; renders blank by design
V3528:  JSRL   CNTSCL                 ;AF61
V352A:  VCTR   -300, -300, 0          ;1ED4 1ED4
V352E:  .word $6000              ;STAT $6000
V3530:  VCTR   600, 600, 0            ;0258 0258
V3534:  RTSL                          ;C000

RHTSHP:          ;JSRL operand $A9B
;  right-facing lives ship (JSRL'd by PLTLIV)
;  refs: vector ROM $364A
;  refs: vector ROM $3666
;  refs: vector ROM $3E92
V3536:  COLOR  $4, 12                 ;64C4
V3538:  SVEC   4, -16, 0              ;5802
V353A:  VCTR   1, 2, 1                ;0002 2001
V353E:  VCTR   5, 0, 1                ;0000 2005
V3542:  SVEC   0, 8, 1                ;4420
V3544:  SVEC   -8, 12, 1              ;463C
V3546:  VCTR   0, 1, 1                ;0001 2000
V354A:  VCTR   3, 0, 1                ;0000 2003
V354E:  SVEC   0, 2, 1                ;4120
V3550:  VCTR   -3, 1, 1               ;0001 3FFD
V3554:  SVEC   0, 2, 1                ;4120
V3556:  SVEC   -2, 6, 1               ;433F
V3558:  SVEC   -2, -6, 1              ;5D3F
V355A:  SVEC   0, -2, 1               ;5F20
V355C:  VCTR   -3, -4, 1              ;1FFC 3FFD
V3560:  VCTR   0, 1, 1                ;0001 2000
V3564:  VCTR   3, 0, 1                ;0000 2003
V3568:  VCTR   0, -1, 1               ;1FFF 2000
V356C:  SVEC   -8, -12, 1             ;5A3C
V356E:  SVEC   0, -8, 1               ;5C20
V3570:  VCTR   5, 0, 1                ;0000 2005
V3574:  VCTR   -2, -1, 1              ;1FFF 3FFE
V3578:  SVEC   8, 0, 1                ;4024
V357A:  VCTR   46, 15, 0              ;000F 002E
V357E:  RTSL                          ;C000

LFTSHP:          ;JSRL operand $AC0
;  left-facing lives ship (JSRL'd by PLTLIV)
;  refs: vector ROM $3644
;  refs: vector ROM $365A
;  refs: vector ROM $3E98
V3580:  COLOR  $2, 12                 ;64C2
V3582:  SVEC   6, -12, 0              ;5A03
V3584:  SVEC   0, -4, 1               ;5E20
V3586:  SVEC   4, 4, 1                ;4222
V3588:  SVEC   0, 10, 1               ;4520
V358A:  SVEC   -4, 2, 1               ;413E
V358C:  VCTR   1, -4, 1               ;1FFC 2001
V3590:  SVEC   -4, 2, 1               ;413E
V3592:  SVEC   0, 8, 1                ;4420
V3594:  SVEC   -2, 12, 1              ;463F
V3596:  SVEC   -2, 0, 1               ;403F
V3598:  SVEC   -2, -12, 1             ;5A3F
V359A:  SVEC   0, -8, 1               ;5C20
V359C:  VCTR   -3, -2, 1              ;1FFE 3FFD
V35A0:  SVEC   0, 4, 1                ;4220
V35A2:  SVEC   -4, -2, 1              ;5F3E
V35A4:  SVEC   0, -10, 1              ;5B20
V35A6:  SVEC   4, -4, 1               ;5E22
V35A8:  SVEC   0, 4, 1                ;4220
V35AA:  SVEC   6, 2, 1                ;4123
V35AC:  SVEC   6, -2, 1               ;5F23
V35AE:  VCTR   38, 12, 0              ;000C 0026
V35B2:  RTSL                          ;C000

FIGP:           ;JSRL operand $ADA  -- name from AS2ROM source order only, UNVERIFIED
;  secondary entry points: SPONE, SPSTA, SPCONT, XPLPIECE, EXPSHP, EXP16
V35B4:  SCAL   2, $00                 ;7200
V35B6:  COLOR  $4, 12                 ;64C4
V35B8:  SVEC   -4, 16, 0              ;481E
V35BA:  VCTR   -1, -2, 1              ;1FFE 3FFF
V35BE:  VCTR   -5, 0, 1               ;0000 3FFB
V35C2:  SVEC   0, -8, 1               ;5C20
V35C4:  SVEC   8, -12, 1              ;5A24
V35C6:  VCTR   0, -1, 1               ;1FFF 2000
V35CA:  VCTR   -3, 0, 1               ;0000 3FFD
V35CE:  SVEC   0, -2, 1               ;5F20
V35D0:  VCTR   3, -1, 1               ;1FFF 2003
V35D4:  SVEC   0, -2, 1               ;5F20
V35D6:  SVEC   2, -6, 1               ;5D21
V35D8:  SVEC   2, 6, 1                ;4321
V35DA:  SVEC   0, 2, 1                ;4120
V35DC:  VCTR   3, 4, 1                ;0004 2003
V35E0:  VCTR   0, -1, 1               ;1FFF 2000
V35E4:  VCTR   -3, 0, 1               ;0000 3FFD
V35E8:  VCTR   0, 1, 1                ;0001 2000
V35EC:  SVEC   8, 12, 1               ;4624
V35EE:  SVEC   0, 8, 1                ;4420
V35F0:  VCTR   -5, 0, 1               ;0000 3FFB
V35F4:  VCTR   2, 1, 1                ;0001 2002
V35F8:  SVEC   -8, 0, 1               ;403C
V35FA:  VCTR   -10, -63, 0            ;1FC1 1FF6
V35FE:  JSRL   EXP14                  ;AB03
V3600:  VCTR   0, 50, 0               ;0032 0000
V3604:  RTSL                          ;C000

EXP14:          ;JSRL operand $B03  -- name from AS2ROM source order only, UNVERIFIED
;  refs: vector ROM $35FE
V3606:  COLOR  $2, 12                 ;64C2
V3608:  SVEC   -6, 12, 0              ;461D
V360A:  SVEC   0, 4, 1                ;4220
V360C:  SVEC   -4, -4, 1              ;5E3E
V360E:  SVEC   0, -10, 1              ;5B20
V3610:  SVEC   4, -2, 1               ;5F22
V3612:  VCTR   -1, 4, 1               ;0004 3FFF
V3616:  SVEC   4, -2, 1               ;5F22
V3618:  SVEC   0, -8, 1               ;5C20
V361A:  SVEC   2, -12, 1              ;5A21
V361C:  SVEC   2, 0, 1                ;4021
V361E:  SVEC   2, 12, 1               ;4621
V3620:  SVEC   0, 8, 1                ;4420
V3622:  VCTR   3, 2, 1                ;0002 2003
V3626:  SVEC   0, -4, 1               ;5E20
V3628:  VCTR   3, 2, 1                ;0002 2003
V362C:  SVEC   0, -4, 1               ;5E20
V362E:  SVEC   4, 2, 1                ;4122
V3630:  SVEC   0, 10, 1               ;4520
V3632:  SVEC   -4, 4, 1               ;423E
V3634:  SVEC   0, -4, 1               ;5E20
V3636:  SVEC   -6, -2, 1              ;5F3D
V3638:  SVEC   -6, 2, 1               ;413D
V363A:  VCTR   -38, -12, 0            ;1FF4 1FDA
V363E:  RTSL                          ;C000

EXP12:          ;JSRL operand $B20  -- name from AS2ROM source order only, UNVERIFIED
;  refs: vector ROM $3A6B
;  refs: main ROM $527A
;  refs: main ROM $67E3
V3640:  VCTR   -100, 0, 0             ;0000 1F9C
V3644:  JSRL   LFTSHP                 ;AAC0
V3646:  VCTR   100, 0, 0              ;0000 0064
V364A:  JMPL   RHTSHP                 ;EA9B
V364C:  COLOR  $4, 10                 ;64A4
V364E:  VCTR   -50, 0, 0              ;0000 1FCE
V3652:  JSRL   $3582                  ;AAC1
V3654:  JMPL   $365C                  ;EB2E
V3656:  VCTR   -50, 0, 0              ;0000 1FCE
V365A:  JSRL   LFTSHP                 ;AAC0
V365C:  COLOR  $6, 15                 ;64F6
V365E:  VCTR   -50, 0, 0              ;0000 1FCE
V3662:  VCTR   100, 0, 5              ;0000 A064
V3666:  JMPL   RHTSHP                 ;EA9B
V3668:  SVEC   -8, -12, 7             ;5AFC
V366A:  SVEC   8, 12, 0               ;4604
V366C:  SVEC   4, -8, 7               ;5CE2
V366E:  SVEC   -4, 8, 0               ;441E
V3670:  SVEC   6, 2, 7                ;41E3
V3672:  SVEC   -6, -2, 0              ;5F1D
V3674:  SVEC   -8, 8, 7               ;44FC
V3676:  SVEC   8, -8, 0               ;5C04
V3678:  SVEC   -6, 2, 7               ;41FD
V367A:  SVEC   6, -2, 0               ;5F03
V367C:  SVEC   4, -4, 7               ;5EE2
V367E:  SVEC   -4, 4, 0               ;421E
V3680:  COLOR  $4, 11                 ;64B4
V3682:  SVEC   -16, 0, 0              ;4018
V3684:  SVEC   2, 0, 1                ;4021
V3686:  SVEC   -16, -16, 0            ;5818
V3688:  SVEC   2, 0, 1                ;4021
V368A:  SVEC   16, -16, 0             ;5808
V368C:  SVEC   2, 0, 1                ;4021
V368E:  SVEC   24, 8, 0               ;440C
V3690:  SVEC   2, 0, 1                ;4021
V3692:  SVEC   16, -8, 0              ;5C08
V3694:  SVEC   2, 0, 1                ;4021
V3696:  SVEC   0, 16, 0               ;4800
V3698:  SVEC   2, 0, 1                ;4021
V369A:  SVEC   8, 24, 0               ;4C04
V369C:  SVEC   2, 0, 1                ;4021
V369E:  SVEC   -8, 24, 0              ;4C1C
V36A0:  SVEC   2, 0, 1                ;4021
V36A2:  VCTR   -32, -8, 0             ;1FF8 1FE0
V36A6:  SVEC   2, 0, 1                ;4021
V36A8:  SVEC   -24, 8, 0              ;4414
V36AA:  SVEC   2, 0, 1                ;4021
V36AC:  RTSL                          ;C000

EXP10:          ;JSRL operand $B57  -- name from AS2ROM source order only, UNVERIFIED
;  refs: main ROM $6E66
V36AE:  COLOR  $4, 13                 ;64D4
V36B0:  SVEC   -14, 0, 0              ;4019
V36B2:  SVEC   2, 0, 1                ;4021
V36B4:  SVEC   -14, -14, 0            ;5919
V36B6:  SVEC   2, 0, 1                ;4021
V36B8:  SVEC   14, -14, 0             ;5907
V36BA:  SVEC   2, 0, 1                ;4021
V36BC:  VCTR   21, 7, 0               ;0007 0015
V36C0:  SVEC   2, 0, 1                ;4021
V36C2:  VCTR   14, -7, 0              ;1FF9 000E
V36C6:  SVEC   2, 0, 1                ;4021
V36C8:  SVEC   0, 14, 0               ;4700
V36CA:  SVEC   2, 0, 1                ;4021
V36CC:  VCTR   7, 21, 0               ;0015 0007
V36D0:  SVEC   2, 0, 1                ;4021
V36D2:  VCTR   -7, 21, 0              ;0015 1FF9
V36D6:  SVEC   2, 0, 1                ;4021
V36D8:  VCTR   -28, -7, 0             ;1FF9 1FE4
V36DC:  SVEC   2, 0, 1                ;4021
V36DE:  VCTR   -21, 7, 0              ;0007 1FEB
V36E2:  SVEC   2, 0, 1                ;4021
V36E4:  RTSL                          ;C000

EXP15:          ;JSRL operand $B73  -- name from AS2ROM source order only, UNVERIFIED
;  refs: main ROM $6E62
V36E6:  COLOR  $6, 12                 ;64C6
V36E8:  SVEC   -12, 0, 0              ;401A
V36EA:  SVEC   2, 0, 1                ;4021
V36EC:  SVEC   -12, -12, 0            ;5A1A
V36EE:  SVEC   2, 0, 1                ;4021
V36F0:  SVEC   12, -12, 0             ;5A06
V36F2:  SVEC   2, 0, 1                ;4021
V36F4:  SVEC   18, 6, 0               ;4309
V36F6:  SVEC   2, 0, 1                ;4021
V36F8:  SVEC   12, -6, 0              ;5D06
V36FA:  SVEC   2, 0, 1                ;4021
V36FC:  SVEC   0, 12, 0               ;4600
V36FE:  SVEC   2, 0, 1                ;4021
V3700:  SVEC   6, 18, 0               ;4903
V3702:  SVEC   2, 0, 1                ;4021
V3704:  SVEC   -6, 18, 0              ;491D
V3706:  SVEC   2, 0, 1                ;4021
V3708:  SVEC   -24, -6, 0             ;5D14
V370A:  SVEC   2, 0, 1                ;4021
V370C:  SVEC   -18, 6, 0              ;4317
V370E:  SVEC   2, 0, 1                ;4021
V3710:  RTSL                          ;C000

EXP13:          ;JSRL operand $B89  -- name from AS2ROM source order only, UNVERIFIED
;  refs: main ROM $6E5E
V3712:  COLOR  $7, 15                 ;64F7
V3714:  SVEC   -10, 0, 0              ;401B
V3716:  SVEC   2, 0, 1                ;4021
V3718:  SVEC   -10, -10, 0            ;5B1B
V371A:  SVEC   2, 0, 1                ;4021
V371C:  SVEC   10, -10, 0             ;5B05
V371E:  SVEC   2, 0, 1                ;4021
V3720:  VCTR   15, 5, 0               ;0005 000F
V3724:  SVEC   2, 0, 1                ;4021
V3726:  VCTR   10, -5, 0              ;1FFB 000A
V372A:  SVEC   2, 0, 1                ;4021
V372C:  SVEC   0, 10, 0               ;4500
V372E:  SVEC   2, 0, 1                ;4021
V3730:  VCTR   5, 15, 0               ;000F 0005
V3734:  SVEC   2, 0, 1                ;4021
V3736:  VCTR   -5, 15, 0              ;000F 1FFB
V373A:  SVEC   2, 0, 1                ;4021
V373C:  VCTR   -20, -5, 0             ;1FFB 1FEC
V3740:  SVEC   2, 0, 1                ;4021
V3742:  VCTR   -15, 5, 0              ;0005 1FF1
V3746:  SVEC   2, 0, 1                ;4021
V3748:  RTSL                          ;C000

EXP11:          ;JSRL operand $BA5  -- name from AS2ROM source order only, UNVERIFIED
;  refs: main ROM $6E68
V374A:  COLOR  $4, 12                 ;64C4
V374C:  VCTR   -15, 0, 0              ;0000 1FF1
V3750:  SVEC   2, 0, 1                ;4021
V3752:  VCTR   -15, -15, 0            ;1FF1 1FF1
V3756:  SVEC   2, 0, 1                ;4021
V3758:  VCTR   15, -15, 0             ;1FF1 000F
V375C:  SVEC   2, 0, 1                ;4021
V375E:  VCTR   22, 7, 0               ;0007 0016
V3762:  SVEC   2, 0, 1                ;4021
V3764:  VCTR   15, -7, 0              ;1FF9 000F
V3768:  SVEC   2, 0, 1                ;4021
V376A:  VCTR   0, 15, 0               ;000F 0000
V376E:  SVEC   2, 0, 1                ;4021
V3770:  VCTR   7, 22, 0               ;0016 0007
V3774:  SVEC   2, 0, 1                ;4021
V3776:  VCTR   -7, 22, 0              ;0016 1FF9
V377A:  SVEC   2, 0, 1                ;4021
V377C:  VCTR   -30, -7, 0             ;1FF9 1FE2
V3780:  SVEC   2, 0, 1                ;4021
V3782:  VCTR   -22, 7, 0              ;0007 1FEA
V3786:  SVEC   2, 0, 1                ;4021
V3788:  RTSL                          ;C000

EXP9:           ;JSRL operand $BC5  -- name from AS2ROM source order only, UNVERIFIED
;  refs: main ROM $6E64
V378A:  COLOR  $4, 14                 ;64E4
V378C:  VCTR   -13, 0, 0              ;0000 1FF3
V3790:  SVEC   2, 0, 1                ;4021
V3792:  VCTR   -13, -13, 0            ;1FF3 1FF3
V3796:  SVEC   2, 0, 1                ;4021
V3798:  VCTR   13, -13, 0             ;1FF3 000D
V379C:  SVEC   2, 0, 1                ;4021
V379E:  VCTR   19, 6, 0               ;0006 0013
V37A2:  SVEC   2, 0, 1                ;4021
V37A4:  VCTR   13, -6, 0              ;1FFA 000D
V37A8:  SVEC   2, 0, 1                ;4021
V37AA:  VCTR   0, 13, 0               ;000D 0000
V37AE:  SVEC   2, 0, 1                ;4021
V37B0:  VCTR   6, 19, 0               ;0013 0006
V37B4:  SVEC   2, 0, 1                ;4021
V37B6:  VCTR   -6, 19, 0              ;0013 1FFA
V37BA:  SVEC   2, 0, 1                ;4021
V37BC:  SVEC   -26, -6, 0             ;5D13
V37BE:  SVEC   -2, 0, 1               ;403F
V37C0:  VCTR   -19, 7, 0              ;0007 1FED
V37C4:  SVEC   2, 0, 1                ;4021
V37C6:  RTSL                          ;C000
V37C8:  COLOR  $6, 14                 ;64E6
V37CA:  VCTR   -11, 0, 0              ;0000 1FF5
V37CE:  SVEC   2, 0, 1                ;4021
V37D0:  VCTR   -11, -11, 0            ;1FF5 1FF5
V37D4:  SVEC   2, 0, 1                ;4021
V37D6:  VCTR   11, -11, 0             ;1FF5 000B
V37DA:  SVEC   2, 0, 1                ;4021
V37DC:  VCTR   17, 6, 0               ;0006 0011
V37E0:  SVEC   2, 0, 1                ;4021
V37E2:  VCTR   11, -6, 0              ;1FFA 000B
V37E6:  SVEC   2, 0, 1                ;4021
V37E8:  VCTR   0, 11, 0               ;000B 0000
V37EC:  SVEC   2, 0, 1                ;4021
V37EE:  VCTR   6, 17, 0               ;0011 0006
V37F2:  SVEC   2, 0, 1                ;4021
V37F4:  VCTR   -6, 17, 0              ;0011 1FFA
V37F8:  SVEC   2, 0, 1                ;4021
V37FA:  VCTR   -23, -6, 0             ;1FFA 1FE9
V37FE:  SVEC   2, 0, 1                ;4021
V3800:  VCTR   -17, 6, 0              ;0006 1FEF
V3804:  SVEC   2, 0, 1                ;4021
V3806:  RTSL                          ;C000
V3808:  COLOR  $7, 15                 ;64F7
V380A:  VCTR   -9, 0, 0               ;0000 1FF7
V380E:  SVEC   2, 0, 1                ;4021
V3810:  VCTR   -9, -9, 0              ;1FF7 1FF7
V3814:  SVEC   2, 0, 1                ;4021
V3816:  VCTR   9, -9, 0               ;1FF7 0009
V381A:  SVEC   2, 0, 1                ;4021
V381C:  VCTR   13, 4, 0               ;0004 000D
V3820:  SVEC   2, 0, 1                ;4021
V3822:  VCTR   9, -4, 0               ;1FFC 0009
V3826:  SVEC   2, 0, 1                ;4021
V3828:  VCTR   0, 9, 0                ;0009 0000
V382C:  SVEC   2, 0, 1                ;4021
V382E:  VCTR   4, 13, 0               ;000D 0004
V3832:  SVEC   2, 0, 1                ;4021
V3834:  VCTR   -4, 9, 0               ;0009 1FFC
V3838:  SVEC   2, 0, 1                ;4021
V383A:  VCTR   -17, -4, 0             ;1FFC 1FEF
V383E:  SVEC   2, 0, 1                ;4021
V3840:  VCTR   -13, 4, 0              ;0004 1FF3
V3844:  SVEC   2, 0, 1                ;4021
V3846:  RTSL                          ;C000

PENT01:          ;JSRL operand $C24
;  hat box
;  secondary entry points: SAUCER
;  refs: main ROM $6E97
V3848:  VCTR   19, 13, 0              ;000D 0013
V384C:  COLOR  $7, 15                 ;64F7
V384E:  VCTR   -8, -11, 1             ;1FF5 3FF8
V3852:  SVEC   -22, 0, 1              ;4035
V3854:  VCTR   -8, 11, 1              ;000B 3FF8
V3858:  VCTR   19, 7, 1               ;0007 2013
V385C:  VCTR   19, -7, 1              ;1FF9 2013
V3860:  COLOR  $1, 13                 ;64D1
V3862:  SVEC   0, -20, 1              ;5620
V3864:  COLOR  $2, 12                 ;64C2
V3866:  VCTR   -8, -11, 1             ;1FF5 3FF8
V386A:  SVEC   -22, 0, 1              ;4035
V386C:  VCTR   -8, 11, 1              ;000B 3FF8
V3870:  COLOR  $1, 13                 ;64D1
V3872:  SVEC   0, 20, 1               ;4A20
V3874:  VCTR   8, -11, 0              ;1FF5 0008
V3878:  SVEC   0, -20, 1              ;5620
V387A:  SVEC   22, 0, 0               ;400B
V387C:  SVEC   0, 20, 1               ;4A20
V387E:  RTSL                          ;C000

PENT11:          ;JSRL operand $C40
;  hat box
;  refs: main ROM $6EA7
V3880:  SVEC   20, 10, 0              ;450A
V3882:  COLOR  $4, 14                 ;64E4
V3884:  VCTR   -14, -9, 1             ;1FF7 3FF2
V3888:  VCTR   -22, 3, 1              ;0003 3FEA
V388C:  SVEC   0, 12, 1               ;4620
V388E:  VCTR   22, 3, 1               ;0003 2016
V3892:  VCTR   14, -9, 1              ;1FF7 200E
V3896:  COLOR  $7, 15                 ;64F7
V3898:  SVEC   0, -20, 1              ;5620
V389A:  COLOR  $2, 12                 ;64C2
V389C:  VCTR   -14, -9, 1             ;1FF7 3FF2
V38A0:  VCTR   -22, 3, 1              ;0003 3FEA
V38A4:  COLOR  $7, 15                 ;64F7
V38A6:  SVEC   0, 20, 1               ;4A20
V38A8:  VCTR   22, -3, 0              ;1FFD 0016
V38AC:  SVEC   0, -20, 1              ;5620
V38AE:  RTSL                          ;C000

PENT21:          ;JSRL operand $C58
;  hat box
;  refs: main ROM $6EB7
V38B0:  COLOR  $4, 14                 ;64E4
V38B2:  VCTR   19, 7, 1               ;0007 2013
V38B6:  VCTR   -8, 11, 1              ;000B 3FF8
V38BA:  SVEC   -22, 0, 1              ;4035
V38BC:  VCTR   -8, -11, 1             ;1FF5 3FF8
V38C0:  VCTR   19, -7, 1              ;1FF9 2013
V38C4:  COLOR  $1, 13                 ;64D1
V38C6:  SVEC   0, -20, 1              ;5620
V38C8:  VCTR   19, 7, 0               ;0007 0013
V38CC:  SVEC   0, 20, 1               ;4A20
V38CE:  VCTR   -38, 0, 0              ;0000 1FDA
V38D2:  SVEC   0, -20, 1              ;5620
V38D4:  COLOR  $7, 15                 ;64F7
V38D6:  VCTR   19, -7, 1              ;1FF9 2013
V38DA:  VCTR   19, 7, 1               ;0007 2013
V38DE:  RTSL                          ;C000

PENT31:          ;JSRL operand $C70
;  hat box
;  refs: main ROM $6EC7
V38E0:  SVEC   16, 4, 0               ;4208
V38E2:  COLOR  $4, 14                 ;64E4
V38E4:  SVEC   0, 12, 1               ;4620
V38E6:  VCTR   -22, 3, 1              ;0003 3FEA
V38EA:  VCTR   -14, -9, 1             ;1FF7 3FF2
V38EE:  VCTR   14, -9, 1              ;1FF7 200E
V38F2:  VCTR   22, 3, 1               ;0003 2016
V38F6:  COLOR  $1, 13                 ;64D1
V38F8:  SVEC   0, -20, 1              ;5620
V38FA:  COLOR  $2, 12                 ;64C2
V38FC:  VCTR   -22, -3, 1             ;1FFD 3FEA
V3900:  VCTR   -14, 9, 1              ;0009 3FF2
V3904:  COLOR  $1, 13                 ;64D1
V3906:  SVEC   0, 20, 1               ;4A20
V3908:  VCTR   14, -9, 0              ;1FF7 000E
V390C:  SVEC   0, -20, 1              ;5620
V390E:  RTSL                          ;C000

PLN01:           ;JSRL operand $C88
;  book
;  refs: main ROM $6E99
V3910:  COLOR  $4, 14                 ;64E4
V3912:  SVEC   -20, -20, 0            ;5616
V3914:  VCTR   0, 40, 1               ;0028 2000
V3918:  VCTR   40, 0, 1               ;0000 2028
V391C:  VCTR   0, -40, 1              ;1FD8 2000
V3920:  VCTR   -40, 0, 1              ;0000 3FD8
V3924:  RTSL                          ;C000

PLN11:           ;JSRL operand $C93
;  book
;  secondary entry points: CNTSCL
;  refs: main ROM $6EA9
V3926:  COLOR  $4, 14                 ;64E4
V3928:  SVEC   10, -20, 0             ;5605
V392A:  VCTR   -25, 0, 1              ;0000 3FE7
V392E:  VCTR   0, 40, 1               ;0028 2000
V3932:  VCTR   25, 0, 1               ;0000 2019
V3936:  COLOR  $6, 14                 ;64E6
V3938:  VCTR   5, 0, 1                ;0000 2005
V393C:  VCTR   0, -40, 1              ;1FD8 2000
V3940:  VCTR   -5, 0, 1               ;0000 3FFB
V3944:  VCTR   0, 40, 1               ;0028 2000
V3948:  RTSL                          ;C000

PLN21:           ;JSRL operand $CA5
;  book
;  secondary entry points: ASTMSG, FLARE
;  refs: main ROM $6EB9
V394A:  COLOR  $6, 14                 ;64E6
V394C:  VCTR   -3, -20, 0             ;1FEC 1FFD
V3950:  VCTR   0, 40, 1               ;0028 2000
V3954:  SVEC   6, 0, 1                ;4023
V3956:  VCTR   0, -40, 1              ;1FD8 2000
V395A:  SVEC   -6, 0, 1               ;403D
V395C:  RTSL                          ;C000

PLN31:           ;JSRL operand $CAF
;  book
;  refs: main ROM $6EC9
V395E:  COLOR  $4, 14                 ;64E4
V3960:  SVEC   -10, -20, 0            ;561B
V3962:  VCTR   25, 0, 1               ;0000 2019
V3966:  VCTR   0, 40, 1               ;0028 2000
V396A:  VCTR   -25, 0, 1              ;0000 3FE7
V396E:  COLOR  $6, 14                 ;64E6
V3970:  VCTR   -5, 0, 1               ;0000 3FFB
V3974:  VCTR   0, -40, 1              ;1FD8 2000
V3978:  VCTR   5, 0, 1                ;0000 2005
V397C:  VCTR   0, 40, 1               ;0028 2000
V3980:  RTSL                          ;C000

CUBNM:           ;JSRL operand $CC1
V3982:  SVEC   18, 12, 0              ;4609
V3984:  VCTR   -9, 6, 1               ;0006 3FF7
V3988:  SVEC   -24, 0, 1              ;4034
V398A:  VCTR   -3, -27, 1             ;1FE5 3FFD
V398E:  VCTR   9, -6, 1               ;1FFA 2009
V3992:  SVEC   24, 0, 1               ;402C
V3994:  VCTR   3, 27, 1               ;001B 2003
V3998:  SVEC   -24, 0, 1              ;4034
V399A:  VCTR   -9, 6, 1               ;0006 3FF7
V399E:  VCTR   6, -33, 0              ;1FDF 0006
V39A2:  VCTR   3, 27, 1               ;001B 2003
V39A6:  VCTR   7, -20, 0              ;1FEC 0007
V39AA:  RTSL                          ;C000

CUBE01:          ;JSRL operand $CD6
;  cube
;  refs: main ROM $6E93
V39AC:  SVEC   2, 18, 0               ;4901
V39AE:  SVEC   20, -20, 1             ;562A
V39B0:  VCTR   -18, -19, 1            ;1FED 3FEE
V39B4:  VCTR   -8, 3, 1               ;0003 3FF8
V39B8:  SVEC   -20, 20, 1             ;4A36
V39BA:  VCTR   16, 19, 1              ;0013 2010
V39BE:  VCTR   8, -3, 1               ;1FFD 2008
V39C2:  VCTR   -16, -19, 1            ;1FED 3FF0
V39C6:  VCTR   -8, 3, 1               ;0003 3FF8
V39CA:  VCTR   8, -3, 0               ;1FFD 0008
V39CE:  SVEC   20, -20, 1             ;562A
V39D0:  RTSL                          ;C000

CUBE11:          ;JSRL operand $CE9
;  cube
;  refs: main ROM $6EA3
V39D2:  SVEC   2, 20, 0               ;4A01
V39D4:  SVEC   20, -20, 1             ;562A
V39D6:  SVEC   -10, -18, 1            ;573B
V39D8:  SVEC   -14, -2, 1             ;5F39
V39DA:  SVEC   -20, 20, 1             ;4A36
V39DC:  SVEC   10, 18, 1              ;4925
V39DE:  SVEC   14, 2, 1               ;4127
V39E0:  SVEC   -10, -18, 1            ;573B
V39E2:  SVEC   -14, -2, 1             ;5F39
V39E4:  SVEC   14, 2, 0               ;4107
V39E6:  SVEC   20, -20, 1             ;562A
V39E8:  RTSL                          ;C000

CUBE21:          ;JSRL operand $CF5
;  cube
;  refs: main ROM $6EB3
V39EA:  SVEC   0, 22, 0               ;4B00
V39EC:  SVEC   20, -20, 1             ;562A
V39EE:  SVEC   -2, -14, 1             ;593F
V39F0:  SVEC   -18, -10, 1            ;5B37
V39F2:  SVEC   -20, 20, 1             ;4A36
V39F4:  SVEC   2, 14, 1               ;4721
V39F6:  SVEC   18, 10, 1              ;4529
V39F8:  SVEC   -2, -14, 1             ;593F
V39FA:  SVEC   -18, -10, 1            ;5B37
V39FC:  SVEC   18, 10, 0              ;4509
V39FE:  SVEC   20, -20, 1             ;562A
V3A00:  RTSL                          ;C000

CUBE31:          ;JSRL operand $D01
;  cube
;  refs: main ROM $6EC3
;  refs: main ROM $867E
;  refs: main ROM $8686
;  refs: main ROM $868E
;  refs: main ROM $8780
;  refs: main ROM $87AE
;  refs: ... and 3 more
V3A02:  SVEC   -2, 22, 0              ;4B1F
V3A04:  SVEC   20, -20, 1             ;562A
V3A06:  VCTR   3, -8, 1               ;1FF8 2003
V3A0A:  VCTR   -19, -16, 1            ;1FF0 3FED
V3A0E:  SVEC   -20, 20, 1             ;4A36
V3A10:  VCTR   -3, 8, 1               ;0008 3FFD
V3A14:  VCTR   19, 16, 1              ;0010 2013
V3A18:  VCTR   3, -8, 1               ;1FF8 2003
V3A1C:  VCTR   -19, -16, 1            ;1FF0 3FED
V3A20:  VCTR   19, 16, 0              ;0010 0013
V3A24:  SVEC   20, -20, 1             ;562A
V3A26:  VCTR   -23, -4, 0             ;1FFC 1FE9
V3A2A:  RTSL                          ;C000

PYRM01:          ;JSRL operand $D16
;  octahedron
;  refs: main ROM $6969
;  refs: main ROM $6E91
V3A2C:  JSRL   $22B2                  ;A159
V3A2E:  SVEC   18, 12, 0              ;4609
V3A30:  SVEC   -6, -30, 1             ;513D
V3A32:  JSRL   $22AE                  ;A157
V3A34:  SVEC   -30, 6, 1              ;4331
V3A36:  SVEC   6, 30, 1               ;4F23
V3A38:  JSRL   $22B2                  ;A159
V3A3A:  SVEC   30, -6, 1              ;5D2F
V3A3C:  VCTR   -12, -21, 1            ;1FEB 3FF4
V3A40:  JSRL   $22AE                  ;A157
V3A42:  VCTR   -18, 27, 1             ;001B 3FEE
V3A46:  SVEC   -6, -30, 0             ;511D
V3A48:  VCTR   24, 3, 1               ;0003 2018
V3A4C:  VCTR   6, -9, 1               ;1FF7 2006
V3A50:  RTSL                          ;C000

PYRM11:          ;JSRL operand $D29
;  octahedron
;  refs: main ROM $6EA1
V3A52:  JSRL   $22B2                  ;A159
V3A54:  VCTR   21, 9, 0               ;0009 0015
V3A58:  VCTR   -9, -27, 1             ;1FE5 3FF7
V3A5C:  JSRL   $22AE                  ;A157
V3A5E:  VCTR   -33, 9, 1              ;0009 3FDF
V3A62:  VCTR   9, 27, 1               ;001B 2009
V3A66:  JSRL   $22B2                  ;A159
V3A68:  VCTR   33, -9, 1              ;1FF7 2021
V3A6C:  VCTR   -21, -21, 1            ;1FEB 3FEB
V3A70:  JSRL   $22AE                  ;A157
V3A72:  SVEC   -12, 30, 1             ;4F3A
V3A74:  VCTR   -9, -27, 0             ;1FE5 1FF7
V3A78:  VCTR   21, -3, 1              ;1FFD 2015
V3A7C:  SVEC   6, -6, 1               ;5D23
V3A7E:  RTSL                          ;C000

PYRM21:          ;JSRL operand $D40
;  octahedron
;  refs: main ROM $6EB1
;  refs: main ROM $7286
V3A80:  JSRL   $22B6                  ;A15B
V3A82:  VCTR   9, 15, 0               ;000F 0009
V3A86:  VCTR   9, -12, 1              ;1FF4 2009
V3A8A:  JSRL   $22B2                  ;A159
V3A8C:  VCTR   -6, -21, 1             ;1FEB 3FFA
V3A90:  VCTR   -21, 3, 1              ;0003 3FEB
V3A94:  JSRL   $22AE                  ;A157
V3A96:  VCTR   -9, 12, 1              ;000C 3FF7
V3A9A:  VCTR   6, 21, 1               ;0015 2006
V3A9E:  JSRL   $22B2                  ;A159
V3AA0:  VCTR   3, -33, 1              ;1FDF 2003
V3AA4:  VCTR   27, 18, 1              ;0012 201B
V3AA8:  VCTR   -30, 15, 1             ;000F 3FE2
V3AAC:  JSRL   $22B6                  ;A15B
V3AAE:  VCTR   21, -3, 1              ;1FFD 2015
V3AB2:  RTSL                          ;C000

PYRM31:          ;JSRL operand $D5A
;  octahedron
;  refs: main ROM $5837
;  refs: main ROM $6EC1
V3AB4:  JSRL   $22B6                  ;A15B
V3AB6:  VCTR   15, 15, 0              ;000F 000F
V3ABA:  VCTR   -3, -33, 1             ;1FDF 3FFD
V3ABE:  JSRL   $22B2                  ;A159
V3AC0:  VCTR   -27, 3, 1              ;0003 3FE5
V3AC4:  VCTR   3, 33, 1               ;0021 2003
V3AC8:  JSRL   $22B6                  ;A15B
V3ACA:  VCTR   27, -3, 1              ;1FFD 201B
V3ACE:  VCTR   -3, -18, 1             ;1FEE 3FFD
V3AD2:  JSRL   $22B2                  ;A159
V3AD4:  VCTR   -24, 21, 1             ;0015 3FE8
V3AD8:  VCTR   -3, -33, 0             ;1FDF 1FFD
V3ADC:  VCTR   27, 12, 1              ;000C 201B
V3AE0:  VCTR   0, -15, 1              ;1FF1 2000
V3AE4:  RTSL                          ;C000

ROCK01:          ;JSRL operand $D73
;  spinner
;  refs: main ROM $6E8D
;  refs: main ROM $8705
V3AE6:  JSRL   $2292                  ;A149
V3AE8:  VCTR   32, 0, 0               ;0000 0020
V3AEC:  VCTR   -64, 0, 1              ;0000 3FC0
V3AF0:  JSRL   $2296                  ;A14B
V3AF2:  SVEC   16, 28, 0              ;4E08
V3AF4:  VCTR   32, -56, 1             ;1FC8 2020
V3AF8:  JSRL   $229A                  ;A14D
V3AFA:  VCTR   -32, 0, 0              ;0000 1FE0
V3AFE:  VCTR   32, 56, 1              ;0038 2020
V3B02:  COLOR  $3, 8                  ;6483
V3B04:  VCTR   -6, -11, 0             ;1FF5 1FFA
V3B08:  SVEC   -20, 0, 1              ;4036
V3B0A:  VCTR   -10, -17, 1            ;1FEF 3FF6
V3B0E:  VCTR   10, -17, 1             ;1FEF 200A
V3B12:  SVEC   20, 0, 1               ;402A
V3B14:  VCTR   10, 17, 1              ;0011 200A
V3B18:  VCTR   -10, 17, 1             ;0011 3FF6
V3B1C:  RTSL                          ;C000

ROCK02:          ;JSRL operand $D8F
;  spinner, opposite spin
;  refs: main ROM $6E8F
V3B1E:  JSRL   $22A0                  ;A150
V3B20:  VCTR   32, 0, 0               ;0000 0020
V3B24:  VCTR   -64, 0, 1              ;0000 3FC0
V3B28:  JSRL   $22A4                  ;A152
V3B2A:  SVEC   16, 28, 0              ;4E08
V3B2C:  VCTR   32, -56, 1             ;1FC8 2020
V3B30:  JSRL   $22A8                  ;A154
V3B32:  JMPL   $3AFA                  ;ED7D

ROCK11:          ;JSRL operand $D9A
;  spinner
;  refs: main ROM $6E9D
V3B34:  JSRL   $2292                  ;A149
V3B36:  VCTR   31, 8, 0               ;0008 001F
V3B3A:  VCTR   -62, -16, 1            ;1FF0 3FC2
V3B3E:  JSRL   $2296                  ;A14B
V3B40:  VCTR   8, 31, 0               ;001F 0008
V3B44:  VCTR   46, -46, 1             ;1FD2 202E
V3B48:  JSRL   $229A                  ;A14D
V3B4A:  VCTR   -31, -8, 0             ;1FF8 1FE1
V3B4E:  VCTR   16, 62, 1              ;003E 2010
V3B52:  COLOR  $3, 8                  ;6483
V3B54:  VCTR   -3, -12, 0             ;1FF4 1FFD
V3B58:  VCTR   -19, -5, 1             ;1FFB 3FED
V3B5C:  VCTR   -5, -19, 1             ;1FED 3FFB
V3B60:  SVEC   14, -14, 1             ;5927
V3B62:  VCTR   19, 5, 1               ;0005 2013
V3B66:  VCTR   5, 19, 1               ;0013 2005
V3B6A:  SVEC   -14, 14, 1             ;4739
V3B6C:  RTSL                          ;C000

ROCK12:          ;JSRL operand $DB7
;  spinner, opposite spin
;  refs: main ROM $6E9F
;  refs: main ROM $7044
V3B6E:  JSRL   $22A0                  ;A150
V3B70:  VCTR   31, 8, 0               ;0008 001F
V3B74:  VCTR   -62, -16, 1            ;1FF0 3FC2
V3B78:  JSRL   $22A4                  ;A152
V3B7A:  VCTR   8, 31, 0               ;001F 0008
V3B7E:  VCTR   46, -46, 1             ;1FD2 202E
V3B82:  JSRL   $22A8                  ;A154
V3B84:  JMPL   $3B4A                  ;EDA5

ROCK21:          ;JSRL operand $DC3
;  spinner
;  refs: main ROM $6EAD
;  refs: main ROM $88F6
V3B86:  JSRL   $2292                  ;A149
V3B88:  SVEC   28, 16, 0              ;480E
V3B8A:  VCTR   -56, -32, 1            ;1FE0 3FC8
V3B8E:  JSRL   $2296                  ;A14B
V3B90:  VCTR   0, 32, 0               ;0020 0000
V3B94:  VCTR   56, -32, 1             ;1FE0 2038
V3B98:  JSRL   $229A                  ;A14D
V3B9A:  SVEC   -28, -16, 0            ;5812
V3B9C:  VCTR   0, 64, 1               ;0040 2000
V3BA0:  COLOR  $3, 8                  ;6483
V3BA2:  SVEC   0, -12, 0              ;5A00
V3BA4:  VCTR   -17, -10, 1            ;1FF6 3FEF
V3BA8:  SVEC   0, -20, 1              ;5620
V3BAA:  VCTR   17, -10, 1             ;1FF6 2011
V3BAE:  VCTR   17, 10, 1              ;000A 2011
V3BB2:  SVEC   0, 20, 1               ;4A20
V3BB4:  VCTR   -17, 10, 1             ;000A 3FEF
V3BB8:  RTSL                          ;C000

ROCK22:          ;JSRL operand $DDD
;  spinner, opposite spin
;  refs: main ROM $6EAF
V3BBA:  JSRL   $22A0                  ;A150
V3BBC:  SVEC   28, 16, 0              ;480E
V3BBE:  VCTR   -56, -32, 1            ;1FE0 3FC8
V3BC2:  JSRL   $22A4                  ;A152
V3BC4:  VCTR   0, 32, 0               ;0020 0000
V3BC8:  VCTR   56, -32, 1             ;1FE0 2038
V3BCC:  JSRL   $22A8                  ;A154
V3BCE:  JMPL   $3B9A                  ;EDCD

ROCK31:          ;JSRL operand $DE8
;  spinner
;  refs: main ROM $6EBD
V3BD0:  JSRL   $2292                  ;A149
V3BD2:  VCTR   23, 23, 0              ;0017 0017
V3BD6:  VCTR   -46, -46, 1            ;1FD2 3FD2
V3BDA:  JSRL   $2296                  ;A14B
V3BDC:  VCTR   -8, 31, 0              ;001F 1FF8
V3BE0:  VCTR   62, -16, 1             ;1FF0 203E
V3BE4:  JSRL   $229A                  ;A14D
V3BE6:  VCTR   -23, -23, 0            ;1FE9 1FE9
V3BEA:  VCTR   -16, 62, 1             ;003E 3FF0
V3BEE:  COLOR  $3, 8                  ;6483
V3BF0:  VCTR   3, -12, 0              ;1FF4 0003
V3BF4:  SVEC   -14, -14, 1            ;5939
V3BF6:  VCTR   5, -19, 1              ;1FED 2005
V3BFA:  VCTR   19, -5, 1              ;1FFB 2013
V3BFE:  SVEC   14, 14, 1              ;4727
V3C00:  VCTR   -5, 19, 1              ;0013 3FFB
V3C04:  VCTR   -19, 5, 1              ;0005 3FED
V3C08:  RTSL                          ;C000

ROCK32:          ;JSRL operand $E05
;  spinner, opposite spin
;  refs: main ROM $6EBF
V3C0A:  JSRL   $22A0                  ;A150
V3C0C:  VCTR   23, 23, 0              ;0017 0017
V3C10:  VCTR   -46, -46, 1            ;1FD2 3FD2
V3C14:  JSRL   $22A4                  ;A152
V3C16:  VCTR   -8, 31, 0              ;001F 1FF8
V3C1A:  VCTR   62, -16, 1             ;1FF0 203E
V3C1E:  JSRL   $22A8                  ;A154
V3C20:  JMPL   $3BE6                  ;EDF3

STAR01:          ;JSRL operand $E11
;  stargon
;  refs: main ROM $6E95
V3C22:  SVEC   8, 20, 0               ;4A04
V3C24:  VCTR   0, -40, 1              ;1FD8 2000
V3C28:  SVEC   -28, 28, 1             ;4E32
V3C2A:  VCTR   40, 0, 1               ;0000 2028
V3C2E:  SVEC   -28, -28, 1            ;5232
V3C30:  VCTR   0, 40, 1               ;0028 2000
V3C34:  SVEC   28, -28, 1             ;522E
V3C36:  VCTR   -40, 0, 1              ;0000 3FD8
V3C3A:  SVEC   28, 28, 1              ;4E2E
V3C3C:  RTSL                          ;C000

STAR11:          ;JSRL operand $E1F
;  stargon
;  refs: vector ROM $39B1
;  refs: main ROM $6EA5
V3C3E:  SVEC   12, 18, 0              ;4906
V3C40:  COLOR  $2, 14                 ;64E2
V3C42:  VCTR   -8, -40, 1             ;1FD8 3FF8
V3C46:  VCTR   -22, 34, 1             ;0022 3FEA
V3C4A:  VCTR   40, -8, 1              ;1FF8 2028
V3C4E:  VCTR   -34, -22, 1            ;1FEA 3FDE
V3C52:  VCTR   8, 40, 1               ;0028 2008
V3C56:  VCTR   22, -34, 1             ;1FDE 2016
V3C5A:  VCTR   -40, 8, 1              ;0008 3FD8
V3C5E:  VCTR   34, 22, 1              ;0016 2022
V3C62:  RTSL                          ;C000

STAR21:          ;JSRL operand $E32
;  stargon
;  refs: main ROM $6EB5
V3C64:  VCTR   15, 15, 0              ;000F 000F
V3C68:  COLOR  $2, 14                 ;64E2
V3C6A:  VCTR   -15, -37, 1            ;1FDB 3FF1
V3C6E:  VCTR   -15, 37, 1             ;0025 3FF1
V3C72:  VCTR   37, -15, 1             ;1FF1 2025
V3C76:  VCTR   -37, -15, 1            ;1FF1 3FDB
V3C7A:  VCTR   15, 37, 1              ;0025 200F
V3C7E:  VCTR   15, -37, 1             ;1FDB 200F
V3C82:  VCTR   -37, 15, 1             ;000F 3FDB
V3C86:  VCTR   37, 15, 1              ;000F 2025
V3C8A:  RTSL                          ;C000

STAR31:          ;JSRL operand $E46
;  stargon
;  refs: main ROM $6EC5
V3C8C:  SVEC   18, 12, 0              ;4609
V3C8E:  COLOR  $2, 14                 ;64E2
V3C90:  VCTR   -22, -34, 1            ;1FDE 3FEA
V3C94:  VCTR   -8, 40, 1              ;0028 3FF8
V3C98:  VCTR   34, -22, 1             ;1FEA 2022
V3C9C:  VCTR   -40, -8, 1             ;1FF8 3FD8
V3CA0:  VCTR   22, 34, 1              ;0022 2016
V3CA4:  VCTR   8, -40, 1              ;1FD8 2008
V3CA8:  VCTR   -34, 22, 1             ;0016 3FDE
V3CAC:  VCTR   40, 8, 1               ;0008 2028
V3CB0:  RTSL                          ;C000

HEXA01:          ;JSRL operand $E59
;  hexaraheadon
;  refs: main ROM $6E9B
V3CB2:  SVEC   20, 0, 0               ;400A
V3CB4:  VCTR   -10, 17, 1             ;0011 3FF6
V3CB8:  SVEC   -20, 0, 1              ;4036
V3CBA:  VCTR   -10, -17, 1            ;1FEF 3FF6
V3CBE:  VCTR   10, -17, 1             ;1FEF 200A
V3CC2:  SVEC   20, 0, 1               ;402A
V3CC4:  VCTR   10, 17, 1              ;0011 200A
V3CC8:  VCTR   -15, 9, 0              ;0009 1FF1
V3CCC:  COLOR  $4, 15                 ;64F4
V3CCE:  SVEC   -10, -18, 1            ;573B
V3CD0:  VCTR   -5, 9, 1               ;0009 3FFB
V3CD4:  SVEC   20, 0, 1               ;402A
V3CD6:  VCTR   -5, -9, 1              ;1FF7 3FFB
V3CDA:  SVEC   -10, 18, 1             ;493B
V3CDC:  SVEC   10, 0, 1               ;4025
V3CDE:  RTSL                          ;C000

HEXA11:          ;JSRL operand $E70
;  hexaraheadon
;  refs: main ROM $6EAB
V3CE0:  VCTR   19, 5, 0               ;0005 0013
V3CE4:  SVEC   -14, 14, 1             ;4739
V3CE6:  VCTR   -19, -5, 1             ;1FFB 3FED
V3CEA:  VCTR   -5, -19, 1             ;1FED 3FFB
V3CEE:  SVEC   14, -14, 1             ;5927
V3CF0:  VCTR   19, 5, 1               ;0005 2013
V3CF4:  VCTR   5, 19, 1               ;0013 2005
V3CF8:  SVEC   -10, 0, 0              ;401B
V3CFA:  COLOR  $4, 9                  ;6494
V3CFC:  SVEC   -18, -10, 1            ;5B37
V3CFE:  SVEC   0, 10, 1               ;4520
V3D00:  SVEC   18, -10, 1             ;5B29
V3D02:  VCTR   -9, -5, 1              ;1FFB 3FF7
V3D06:  SVEC   0, 20, 1               ;4A20
V3D08:  VCTR   9, -5, 1               ;1FFB 2009
V3D0C:  RTSL                          ;C000

HEXA21:          ;JSRL operand $E87
;  hexaraheadon
;  refs: main ROM $6EBB
V3D0E:  VCTR   17, 10, 0              ;000A 0011
V3D12:  VCTR   -17, 10, 1             ;000A 3FEF
V3D16:  VCTR   -17, -10, 1            ;1FF6 3FEF
V3D1A:  SVEC   0, -20, 1              ;5620
V3D1C:  VCTR   17, -10, 1             ;1FF6 2011
V3D20:  VCTR   17, 10, 1              ;000A 2011
V3D24:  SVEC   0, 20, 1               ;4A20
V3D26:  VCTR   -12, -1, 0             ;1FFF 1FF4
V3D2A:  COLOR  $4, 5                  ;6454
V3D2C:  VCTR   5, -9, 1               ;1FF7 2005
V3D30:  SVEC   -20, 0, 1              ;4036
V3D32:  VCTR   5, 9, 1                ;0009 2005
V3D36:  SVEC   10, -18, 1             ;5725
V3D38:  SVEC   -10, 0, 1              ;403B
V3D3A:  SVEC   10, 18, 1              ;4925
V3D3C:  RTSL                          ;C000

HEXA31:          ;JSRL operand $E9F
;  hexaraheadon
;  refs: main ROM $6ECB
V3D3E:  SVEC   14, 14, 0              ;4707
V3D40:  VCTR   -19, 5, 1              ;0005 3FED
V3D44:  SVEC   -14, -14, 1            ;5939
V3D46:  VCTR   5, -19, 1              ;1FED 2005
V3D4A:  VCTR   19, -5, 1              ;1FFB 2013
V3D4E:  SVEC   14, 14, 1              ;4727
V3D50:  VCTR   -5, 19, 1              ;0013 3FFB
V3D54:  VCTR   -5, -9, 0              ;1FF7 1FFB
V3D58:  COLOR  $4, 9                  ;6494
V3D5A:  SVEC   0, -10, 1              ;5B20
V3D5C:  SVEC   -18, 10, 1             ;4537
V3D5E:  VCTR   9, 5, 1                ;0005 2009
V3D62:  SVEC   0, -20, 1              ;5620
V3D64:  VCTR   -9, 5, 1               ;0005 3FF7
V3D68:  SVEC   18, 10, 1              ;4529
V3D6A:  RTSL                          ;C000

COMET:           ;JSRL operand $EB6
V3D6C:  SCAL   2, $00                 ;7200
V3D6E:  SVEC   8, 0, 0                ;4004
V3D70:  VCTR   15, 8, 1               ;0008 200F
V3D74:  VCTR   -16, -3, 1             ;1FFD 3FF0
V3D78:  VCTR   7, 15, 1               ;000F 2007
V3D7C:  VCTR   -11, -12, 1            ;1FF4 3FF5
V3D80:  VCTR   -3, 16, 1              ;0010 3FFD
V3D84:  VCTR   -3, -16, 1             ;1FF0 3FFD
V3D88:  VCTR   -11, 12, 1             ;000C 3FF5
V3D8C:  VCTR   7, -15, 1              ;1FF1 2007
V3D90:  VCTR   -16, 3, 1              ;0003 3FF0
V3D94:  VCTR   15, -8, 1              ;1FF8 200F
V3D98:  VCTR   -15, -8, 1             ;1FF8 3FF1
V3D9C:  VCTR   16, 3, 1               ;0003 2010
V3DA0:  VCTR   -7, -15, 1             ;1FF1 3FF9
V3DA4:  VCTR   11, 12, 1              ;000C 200B
V3DA8:  VCTR   3, -16, 1              ;1FF0 2003
V3DAC:  VCTR   3, 16, 1               ;0010 2003
V3DB0:  VCTR   11, -12, 1             ;1FF4 200B
V3DB4:  VCTR   -7, 15, 1              ;000F 3FF9
V3DB8:  VCTR   16, -3, 1              ;1FFD 2010
V3DBC:  VCTR   -15, 8, 1              ;0008 3FF1
V3DC0:  RTSL                          ;C000

DWARF:           ;JSRL operand $EE1
V3DC2:  COLOR  $3, 15                 ;64F3
V3DC4:  SCAL   2, $00                 ;7200
V3DC6:  SVEC   0, 24, 0               ;4C00
V3DC8:  SVEC   4, -16, 6              ;58C2
V3DCA:  SVEC   18, 0, 6               ;40C9
V3DCC:  SVEC   -16, -10, 6            ;5BD8
V3DCE:  SVEC   6, -18, 6              ;57C3
V3DD0:  SVEC   -12, 12, 6             ;46DA
V3DD2:  SVEC   -12, -12, 6            ;5ADA
V3DD4:  SVEC   6, 18, 6               ;49C3
V3DD6:  SVEC   -16, 10, 6             ;45D8
V3DD8:  SVEC   18, 0, 6               ;40C9
V3DDA:  SVEC   4, 16, 6               ;48C2
V3DDC:  RTSL                          ;C000

SAUC0:           ;JSRL operand $EEF
;  saucer frame 0, entry 0 of the SAUCRC table (shape data from A2SAUC.DAT)
;  refs: vector ROM $3E46
V3DDE:  SVEC   6, 6, 0                ;4303
V3DE0:  JSRL   $22C4                  ;A162
V3DE2:  SVEC   -12, -12, 1            ;5A3A
V3DE4:  SVEC   -4, 16, 0              ;481E
V3DE6:  JSRL   $22C8                  ;A164
V3DE8:  SVEC   20, -20, 1             ;562A
V3DEA:  SVEC   -12, -4, 0             ;5E1A
V3DEC:  JSRL   $22CC                  ;A166
V3DEE:  SVEC   -12, 12, 1             ;463A
V3DF0:  SVEC   16, 16, 1              ;4828
V3DF2:  SVEC   12, -12, 1             ;5A26
V3DF4:  SVEC   -16, -16, 1            ;5838
V3DF6:  RTSL                          ;C000

SAUC1:           ;JSRL operand $EFC
;  saucer frame 1, entry 1 of the SAUCRC table (shape data from A2SAUC.DAT)
;  refs: vector ROM $3E48
V3DF8:  SVEC   10, 10, 0              ;4505
V3DFA:  JSRL   $22C4                  ;A162
V3DFC:  SVEC   -20, -20, 1            ;5636
V3DFE:  SVEC   4, 16, 0               ;4802
V3E00:  JSRL   $22C8                  ;A164
V3E02:  SVEC   12, -12, 1             ;5A26
V3E04:  SVEC   -4, -8, 0              ;5C1E
V3E06:  JSRL   $22CC                  ;A166
V3E08:  SVEC   -16, 16, 1             ;4838
V3E0A:  SVEC   12, 12, 1              ;4626
V3E0C:  SVEC   16, -16, 1             ;5828
V3E0E:  SVEC   -12, -12, 1            ;5A3A
V3E10:  RTSL                          ;C000

SAUC2:           ;JSRL operand $F09
;  saucer frame 2, entry 2 of the SAUCRC table (shape data from A2SAUC.DAT)
;  refs: vector ROM $3E4A
V3E12:  SVEC   10, 14, 0              ;4705
V3E14:  JSRL   $22C4                  ;A162
V3E16:  SVEC   4, -4, 1               ;5E22
V3E18:  SVEC   -24, -24, 1            ;5434
V3E1A:  SVEC   -4, 4, 1               ;423E
V3E1C:  SVEC   24, 24, 1              ;4C2C
V3E1E:  SVEC   4, -20, 0              ;5602
V3E20:  JSRL   $22CC                  ;A166
V3E22:  SVEC   -8, -8, 1              ;5C3C
V3E24:  SVEC   -20, 20, 1             ;4A36
V3E26:  SVEC   8, 8, 1                ;4424
V3E28:  SVEC   20, -20, 1             ;562A
V3E2A:  RTSL                          ;C000

SAUC3:           ;JSRL operand $F16
;  saucer frame 3, entry 3 of the SAUCRC table (shape data from A2SAUC.DAT)
;  refs: vector ROM $3E4C
V3E2C:  SVEC   6, 14, 0               ;4703
V3E2E:  JSRL   $22C4                  ;A162
V3E30:  SVEC   8, -8, 1               ;5C24
V3E32:  SVEC   -20, -20, 1            ;5636
V3E34:  SVEC   -8, 8, 1               ;443C
V3E36:  SVEC   20, 20, 1              ;4A2A
V3E38:  SVEC   8, -24, 0              ;5404
V3E3A:  JSRL   $22CC                  ;A166
V3E3C:  SVEC   -4, -4, 1              ;5E3E
V3E3E:  SVEC   -24, 24, 1             ;4C34
V3E40:  SVEC   4, 4, 1                ;4222
V3E42:  SVEC   24, -24, 1             ;542C
V3E44:  RTSL                          ;C000

SAUCRC:          ;JSRL operand $F23
;  JSRL table of 4 saucer frames, immediately before SAUCER
;  JSRL word table (4 entries) - the 6502 copies one entry
;  into vector RAM; executing it start-to-finish would draw
;  every frame stacked on top of one another
V3E46:  JSRL   SAUC0                  ;AEEF
V3E48:  JSRL   SAUC1                  ;AEFC
V3E4A:  JSRL   SAUC2                  ;AF09
V3E4C:  JSRL   SAUC3                  ;AF16

SAUCER:          ;JSRL operand $F27
V3E4E:  VCTR   15, 5, 0               ;0005 000F
V3E52:  SVEC   -10, 10, 1             ;453B
V3E54:  SVEC   -10, 0, 1              ;403B
V3E56:  SVEC   -10, -10, 1            ;5B3B
V3E58:  SVEC   0, -10, 1              ;5B20
V3E5A:  SVEC   10, -10, 1             ;5B25
V3E5C:  SVEC   10, 0, 1               ;4025
V3E5E:  SVEC   10, 10, 1              ;4525
V3E60:  SVEC   0, 10, 1               ;4520
V3E62:  VCTR   -15, -5, 0             ;1FFB 1FF1
V3E66:  RTSL                          ;C000

MINE:            ;JSRL operand $F34
V3E68:  SCAL   1, $00                 ;7100
V3E6A:  SVEC   -8, 0, 0               ;401C
V3E6C:  SVEC   4, 0, 1                ;4022
V3E6E:  SVEC   4, 4, 1                ;4222
V3E70:  SVEC   0, 4, 0                ;4200
V3E72:  SVEC   0, -4, 1               ;5E20
V3E74:  SVEC   4, -4, 1               ;5E22
V3E76:  SVEC   4, 0, 0                ;4002
V3E78:  SVEC   -4, 0, 1               ;403E
V3E7A:  SVEC   -4, -4, 1              ;5E3E
V3E7C:  SVEC   0, -4, 1               ;5E20
V3E7E:  SVEC   0, 4, 1                ;4220
V3E80:  SVEC   -4, 4, 1               ;423E
V3E82:  RTSL                          ;C000

SHOT:            ;JSRL operand $F42
V3E84:  SCAL   1, $00                 ;7100
V3E86:  SVEC   2, 0, 1                ;4021
V3E88:  SVEC   -2, 0, 1               ;403F
V3E8A:  SVEC   2, 0, 1                ;4021
V3E8C:  SVEC   0, -2, 1               ;5F20
V3E8E:  RTSL                          ;C000

PLTLIV:          ;JSRL operand $F48
;  plot-lives list: JSRLs the two lives ships
;  no lit vectors - beam positioning / clip / advance list,
;  not a drawable shape; renders blank by design
V3E90:  SCAL   2, $00                 ;7200
V3E92:  JSRL   RHTSHP                 ;AA9B
V3E94:  VCTR   -48, 36, 0             ;0024 1FD0
V3E98:  JSRL   LFTSHP                 ;AAC0
V3E9A:  VCTR   0, -36, 0              ;1FDC 0000
V3E9E:  RTSL                          ;C000

SHIELD:          ;JSRL operand $F50
V3EA0:  SCAL   1, $00                 ;7100
V3EA2:  SVEC   -18, 8, 0              ;4417
V3EA4:  VCTR   9, 9, 1                ;0009 2009
V3EA8:  SVEC   16, 0, 1               ;4028
V3EAA:  VCTR   9, -9, 1               ;1FF7 2009
V3EAE:  SVEC   0, -16, 1              ;5820
V3EB0:  VCTR   -9, -9, 1              ;1FF7 3FF7
V3EB4:  SVEC   -16, 0, 1              ;4038
V3EB6:  VCTR   -9, 9, 1               ;0009 3FF7
V3EBA:  SVEC   0, 16, 1               ;4820
V3EBC:  SVEC   18, -8, 0              ;5C09
V3EBE:  SCAL   2, $00                 ;7200
V3EC0:  RTSL                          ;C000

CNTSCL:          ;JSRL operand $F61
;  no lit vectors - beam positioning / clip / advance list,
;  not a drawable shape; renders blank by design
;  refs: vector ROM $3000
;  refs: vector ROM $3028
;  refs: vector ROM $30C4
;  refs: vector ROM $3528
V3EC2:  CNTR                          ;8040
V3EC4:  SCAL   1, $00                 ;7100
V3EC6:  RTSL                          ;C000

ASTMG:           ;JSRL operand $F64
V3EC8:  SCAL   1, $00                 ;7100
V3ECA:  COLOR  $4, 12                 ;64C4
V3ECC:  CNTR                          ;8040
V3ECE:  VCTR   -244, -288, 0          ;1EE0 1F0C
V3ED2:  SVEC   0, 4, 0                ;4200
V3ED4:  SVEC   0, 16, 1               ;4820
V3ED6:  SVEC   4, 4, 1                ;4222
V3ED8:  SVEC   8, 0, 1                ;4024
V3EDA:  SVEC   4, -4, 1               ;5E22
V3EDC:  SVEC   0, -16, 1              ;5820
V3EDE:  SVEC   -4, -4, 1              ;5E3E
V3EE0:  SVEC   -8, 0, 1               ;403C
V3EE2:  SVEC   -4, 4, 1               ;423E
V3EE4:  SVEC   12, 4, 0               ;4206
V3EE6:  SVEC   -8, 0, 1               ;403C
V3EE8:  SVEC   0, 8, 1                ;4420
V3EEA:  SVEC   8, 0, 1                ;4024
V3EEC:  SVEC   12, -16, 0             ;5806
V3EEE:  JSRL   CHR_M                  ;A8B5
V3EF0:  JSRL   CHR_C                  ;A882
V3EF2:  JSRL   CHR_M                  ;A8B5
V3EF4:  JSRL   CHR_L                  ;A8B2
V3EF6:  JSRL   CHR_X                  ;A8ED
V3EF8:  JSRL   CHR_X                  ;A8ED
V3EFA:  JSRL   CHR_X                  ;A8ED
V3EFC:  JSRL   CHR_SPACE              ;A8C0
V3EFE:  JSRL   CHR_A                  ;A86E
V3F00:  JSRL   CHR_T                  ;A8DC
V3F02:  JSRL   CHR_A                  ;A86E
V3F04:  JSRL   CHR_R                  ;A8CF
V3F06:  JSRL   CHR_I                  ;A8A1
V3F08:  JSRL   CHR_SPACE              ;A8C0
V3F0A:  JSRL   CHR_I                  ;A8A1
V3F0C:  JSRL   CHR_N                  ;A8B9
V3F0E:  JMPL   CHR_C                  ;E882

FLARE:           ;JSRL operand $F88
V3F10:  COLOR  $7, 15                 ;64F7
V3F12:  SCAL   0, $00                 ;7000
V3F14:  SVEC   0, -2, 1               ;5F20
V3F16:  COLOR  $6, 15                 ;64F6
V3F18:  VCTR   0, -3, 1               ;1FFD 2000
V3F1C:  COLOR  $6, 10                 ;64A6
V3F1E:  SVEC   0, -2, 1               ;5F20
V3F20:  COLOR  $4, 12                 ;64C4
V3F22:  SVEC   0, -2, 1               ;5F20
V3F24:  COLOR  $4, 10                 ;64A4
V3F26:  SVEC   0, -4, 1               ;5E20
V3F28:  RTSL                          ;C000

;------------------------------[ ROM tail ]------------------------------
;AS2ROM.MAC pads with `.REPT R / .BYTE 0` up to `.=3FFF`, then CKUM1.
;A linear AVG sweep would decode the $0000 fill as VCTR - it is not code.
V3F2A:  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
V3F3A:  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
V3F4A:  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
V3F5A:  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
V3F6A:  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
V3F7A:  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
V3F8A:  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
V3F9A:  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
V3FAA:  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
V3FBA:  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
V3FCA:  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
V3FDA:  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
V3FEA:  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
V3FFA:  .byte $00, $00, $00, $00, $00
CKUM1:
V3FFF:  .byte $25                    ;ROM checksum
