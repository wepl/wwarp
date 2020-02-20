;*---------------------------------------------------------------------------
;  :Program.	formats.s
;  :Contents.	informations and routines regarding special formats
;  :Author.	Bert Jahn
;  :EMail.	wepl@whdload.org
;  :Address.	Feodorstrasse 8, Zwickau, 08058, Germany
;  :Version	$Id: formats.s 1.26 2006/01/30 21:21:43 wepl Exp wepl $
;  :History.	18.03.01 created
;		23.07.01 rob format added
;		28.10.01 dos force made more tolerant
;		02.11.02 rework for new sync-search
;		08.11.02 added ocean, vision and twilight formats (Codetapper)
;		21.12.03 added goliath format (Codetapper)
;		01.01.04 added thalamus format (Codetapper)
;		09.01.04 added beyond the ice palace format (Codetapper)
;		09.02.04 added rob northen copylock
;		12.02.04 wwf_info added
;		05.10.04 twilight2/3 added
;		04.11.04 added rnclold
;		07.02.20 fixed structures for unknown/raw
;  :Requires.	OS V37+, MC68020+
;  :Copyright.	©1998-2001 Bert Jahn, All Rights Reserved
;  :Language.	68020 Assembler
;  :Translator.	Barfly V2.9
;  :To Do.
;---------------------------------------------------------------------------*

		dc.b	"$Id: formats.s 1.26 2006/01/30 21:21:43 wepl Exp wepl $",0
	EVEN

		INCLUDE	fmt_std.s
		INCLUDE	fmt_gremlin.s
		INCLUDE	fmt_robnorthen.s
		INCLUDE	fmt_twilight.s
		INCLUDE	fmt_zzkj.s

_format_unknown	dc.l	0		;succ
		dc.l	0		;decode
		dc.l	0		;encode
		dc.l	0		;info
		dc.l	_name_unknown	;name
		dc.l	0		;sync
		dc.l	0		;density
		dc.w	0		;index
		dc.w	0		;speclen
		dc.w	0		;datalen
		dc.w	0		;minimal rawlen
		dc.w	0		;writelen
		dc.w	-1		;type
		dc.w	0		;flags

_format_raw	dc.l	_formats	;succ
		dc.l	0		;decode
		dc.l	0		;encode
		dc.l	0		;info
		dc.l	_name_raw	;name
		dc.l	0		;sync
		dc.l	0		;density
		dc.w	0		;index
		dc.w	0		;speclen
		dc.w	DEFREADLEN	;datalen
		dc.w	0		;minimal rawlen
		dc.w	0		;writelen
		dc.w	TT_RAW		;type
		dc.w	0		;flags

_formats
.std		dc.l	.stdf		;succ
		dc.l	_decode_std	;decode
		dc.l	0		;encode
		dc.l	0		;info
		dc.l	_name_std	;name
		dc.l	_sync_stdls	;sync
		dc.l	0		;density
		dc.w	0		;index
		dc.w	0		;speclen
		dc.w	$1600		;datalen
		dc.w	$440*11		;minimal rawlen
		dc.w	$440*11		;writelen
		dc.w	TT_STD		;type
		dc.w	0		;flags

.stdf		dc.l	.grem		;succ
		dc.l	_decode_stdf	;decode
		dc.l	0		;encode
		dc.l	0		;info
		dc.l	_name_stdf	;name
		dc.l	_sync_stdf	;sync
		dc.l	0		;density
		dc.w	0		;index
		dc.w	0		;speclen
		dc.w	$1600		;datalen
		dc.w	$440*11		;minimal rawlen
		dc.w	$440*11		;writelen
		dc.w	TT_STDF		;type
		dc.w	WWFF_FORCE	;flags

.grem		dc.l	.rob		;succ
		dc.l	_decode_grem	;decode
		dc.l	_encode_grem	;encode
		dc.l	0		;info
		dc.l	_name_grem	;name
		dc.l	_sync_grem	;sync
		dc.l	0		;density
		dc.w	0		;index
		dc.w	0		;speclen
		dc.w	$1800		;datalen
		dc.w	$3000+16	;minimal rawlen
		dc.w	$3000+16	;writelen
		dc.w	TT_GREM		;type
		dc.w	0		;flags

.rob		dc.l	.pmover		;succ
		dc.l	_decode_rob	;decode
		dc.l	_encode_rob	;encode
		dc.l	_info_rob	;info
		dc.l	_name_rob	;name
		dc.l	_sync_rob	;sync
		dc.l	0		;density
		dc.w	0		;index
		dc.w	4		;speclen (diskkey)
		dc.w	$1800		;datalen
		dc.w	2+(12*$40c)	;minimal rawlen (that is minimum length, often a long track)
		dc.w	2+(12*$40c)	;writelen
		dc.w	TT_ROB		;type
		dc.w	0		;flags

.pmover		dc.l	_beast1
		INCLUDE	fmt_primemover.s

_beast1		dc.l	_beast2
		INCLUDE	fmt_beast1.s

_beast2		dc.l	_bloodmoney
		INCLUDE	fmt_beast2.s

_bloodmoney	dc.l	_psygnosis1
		INCLUDE	fmt_bloodmoney.s

_psygnosis1	dc.l	_turrican1
		INCLUDE	fmt_psygnosis1.s

_turrican1	dc.l	_turrican2
		INCLUDE	fmt_turrican1.s

_turrican2	dc.l	_turrican3a
		INCLUDE	fmt_turrican2.s

_turrican3a	dc.l	_turrican3b
		INCLUDE	fmt_turrican3a_1800.s

_turrican3b	dc.l	_ocean
		INCLUDE	fmt_turrican3b_1A00.s

_ocean		dc.l	_vision
		INCLUDE	fmt_ocean.s

_vision		dc.l	_slackskin
		INCLUDE	fmt_vision.s

_slackskin	dc.l	_twilight3		;must ordered before twilight1
		INCLUDE	fmt_slackskin.s		;otherwise false detections

_twilight3	dc.l	_twilight2
		dc.l	_decode_twilight3	;decode
		dc.l	_encode_twilight3	;encode
		dc.l	0			;info
		dc.l	_name_twilight3		;name
		dc.l	_sync_twilight		;sync
		dc.l	0			;density
		dc.w	0			;index
		dc.w	0			;speclen
		dc.w	$1800			;datalen
		dc.w	4+8+8+($1800*2)+4	;minimal rawlen
		dc.w	4+8+8+($1800*2)+4	;writelen
		dc.w	TT_TWILIGHT3		;type
		dc.w	0			;flags

_twilight2	dc.l	_twilight1
		dc.l	_decode_twilight2	;decode
		dc.l	_encode_twilight2	;encode
		dc.l	0			;info
		dc.l	_name_twilight2		;name
		dc.l	_sync_twilight		;sync
		dc.l	0			;density
		dc.w	0			;index
		dc.w	0			;speclen
		dc.w	$1520			;datalen
		dc.w	4+8+8+($1520*2)+4	;minimal rawlen
		dc.w	4+8+8+($1520*2)+4	;writelen
		dc.w	TT_TWILIGHT2		;type
		dc.w	0			;flags

_twilight1	dc.l	_zzkja
		dc.l	_decode_twilight1	;decode
		dc.l	_encode_twilight1	;encode
		dc.l	0			;info
		dc.l	_name_twilight1		;name
		dc.l	_sync_twilight		;sync
		dc.l	0			;density
		dc.w	0			;index
		dc.w	0			;speclen
		dc.w	$1400			;datalen
		dc.w	4+8+8+($1400*2)+4	;minimal rawlen
		dc.w	4+8+8+($1400*2)+4	;writelen
		dc.w	TT_TWILIGHT		;type
		dc.w	0			;flags

_zzkja		dc.l	_zzkjb		;succ
		dc.l	_decode_zzkja	;decode
		dc.l	_encode_zzkja	;encode
		dc.l	0		;info
		dc.l	_name_zzkja	;name
		dc.l	_sync_zzkj	;sync
		dc.l	0		;density
		dc.w	0		;index
		dc.w	0		;speclen
		dc.w	$800		;datalen
		dc.w	6+($808*2)	;minimal rawlen
		dc.w	6+($808*2)	;writelen
		dc.w	TT_ZZKJA	;type
		dc.w	0		;flags

_zzkjb		dc.l	_zzkjc		;succ
		dc.l	_decode_zzkjb	;decode
		dc.l	_encode_zzkjb	;encode
		dc.l	0		;info
		dc.l	_name_zzkjb	;name
		dc.l	_sync_zzkj	;sync
		dc.l	0		;density
		dc.w	$130		;index
		dc.w	0		;speclen
		dc.w	$1000		;datalen
		dc.w	6+($1008*2)	;minimal rawlen
		dc.w	6+($1008*2)	;writelen
		dc.w	TT_ZZKJB	;type
		dc.w	WWFF_INDEX	;flags

_zzkjc		dc.l	_zzkjd		;succ
		dc.l	_decode_zzkjc	;decode
		dc.l	_encode_zzkjc	;encode
		dc.l	0		;info
		dc.l	_name_zzkjc	;name
		dc.l	_sync_zzkjc	;sync
		dc.l	0		;density
		dc.w	$130		;index
		dc.w	0		;speclen
		dc.w	$1600		;datalen
		dc.w	26+($1608*2)	;minimal rawlen
		dc.w	26+($1608*2)	;writelen
		dc.w	TT_ZZKJC	;type
		dc.w	WWFF_INDEX	;flags

_zzkjd		dc.l	_specialfx	;succ
		dc.l	_decode_zzkjd	;decode
		dc.l	_encode_zzkjd	;encode
		dc.l	0		;info
		dc.l	_name_zzkjd	;name
		dc.l	_sync_zzkjd	;sync
		dc.l	0		;density
		dc.w	0		;index
		dc.w	0		;speclen
		dc.w	$1600		;datalen
		dc.w	$41c*11		;minimal rawlen
		dc.w	$41c*11		;writelen
		dc.w	TT_ZZKJD	;type
		dc.w	0		;flags

_specialfx	dc.l	_tiertex	;succ
		INCLUDE	fmt_specialfx.s

_tiertex	dc.l	_elite		;succ
		INCLUDE	fmt_tiertex.s

_elite		dc.l	_goliath	;succ
		INCLUDE	fmt_elite.s

_goliath	dc.l	_thalamus	;succ
		INCLUDE	fmt_goliath.s

_thalamus	dc.l	_beyond		;succ
		INCLUDE	fmt_thalamus.s

_beyond		dc.l	_rncl		;succ
		INCLUDE	fmt_beyond.s

_rncl		dc.l	_rnclold	;succ
		INCLUDE	fmt_rncopylock.s

_rnclold	dc.l	_hitec		;succ
		INCLUDE	fmt_rncopylockold.s

_hitec		dc.l	_mason		;succ
		INCLUDE	fmt_hitec.s

_mason		dc.l	0		;succ
		INCLUDE	fmt_mason.s

		;		       even	 odd
		;	   --sync--  ffTTSSGG  ffTTSSGG
_sync_std	dc.l	0,$44,$89448955,$00000055		;finds one sector
		dc.l	0,$ff,$ffffffff,$000000ff
		;dc.l	0,$44894489,$55000025,$55000029		;finds first sector after gap
		;dc.l	0,$ffffffff,$ff00007f,$ff00007f
_sync_stdls	dc.l	0,$44894489,$5500002a,$55000029		;finds last sector before gap
		dc.l	0,$ffffffff,$ff00007f,$ff00007f
_sync_stdf	dc.l	0,0,0,$44894489				;finds one sector
		dc.l	0,0,0,$ffffffff
_sync_grem	dc.l	0,0,$44894489,$44895555
		dc.l	0,0,$ffffffff,$ffffffff
_sync_rob	dc.l	0,0,0,$14484891
		dc.l	0,0,0,$ffffffff
_sync_twilight	dc.l	$44894489,$55555500,$55555500,$2aaaaaaa
		dc.l	$ffffffff,$ffffff00,$ffffff00,$7fffffff
_sync_zzkj	dc.l	0,0,$44894489,$2aaaaaaa
		dc.l	0,0,$ffffffff,$ffffffff
_sync_zzkjc	dc.l	$44894489,$2aaaaaaa,$aaaaaaaa,$aaaaaaaa
		dc.l	$ffffffff,$ffffffff,$ffffffff,$ffffffff
_sync_zzkjd	dc.l	0,$4489,$44892aaa,$aaaa0000
		dc.l	0,$ffff,$ffffffff,$ffff0055
_sync_calc	dc.l	0,0,0,$448a448a
		dc.l	0,0,0,$ffffffff

_name_unknown	dc.b	"unknown",0
_name_raw	dc.b	"raw",0
_name_std	dc.b	"dos",0
_name_stdf	dc.b	"dosf",0
_name_grem	dc.b	"gremlin",0
_name_rob	dc.b	"robnorthen",0
_name_twilight1	dc.b	"twilight1",0
_name_twilight2	dc.b	"twilight2",0
_name_twilight3	dc.b	"twilight3",0
_name_zzkja	dc.b	"zzkja",0
_name_zzkjb	dc.b	"zzkjb",0
_name_zzkjc	dc.b	"zzkjc",0
_name_zzkjd	dc.b	"zzkjd",0
	EVEN

;----------------------------------------
; encode a long to mfm
; IN:	D2 = ULONG data long to encode
;	D3 = ULONG $55555555
;	A0 = APTR  destination mfm buffer
; OUT:	D0/D1 destroyed
;	A0 = A0 + 4

	CNOP 0,4
_encode_longodd	lsr.l	#1,d2
_encode_long	and.l	d3,d2
		move.l	d2,d0
		eor.l	d3,d0
		move.l	d0,d1
		add.l	d0,d0
		lsr.l	#1,d1
		bset	#31,d1
		and.l	d0,d1
		or.l	d1,d2
		btst	#0,-1(a0)
		beq	.ok
		bclr	#31,d2
.ok		move.l	d2,(a0)+
		rts

;----------------------------------------
; encode a word to mfm
; IN:	D2 = UWORD data word to encode
;	D3 = ULONG $55555555
;	A0 = APTR  destination mfm buffer
; OUT:	D0/D1 destroyed
;	A0 = A0 + 2

	CNOP 0,4
_encode_wordodd	lsr.w	#1,d2
_encode_word	and.w	d3,d2
		move.w	d2,d0
		eor.w	d3,d0
		move.w	d0,d1
		add.w	d0,d0
		lsr.w	#1,d1
		bset	#15,d1
		and.w	d0,d1
		or.w	d1,d2
		btst	#0,-1(a0)
		beq	.ok
		bclr	#15,d2
.ok		move.w	d2,(a0)+
		rts
