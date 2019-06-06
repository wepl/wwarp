;*---------------------------------------------------------------------------
;  :Program.	slackskin.s
;  :Contents.	decode/encode custom track format for slackskin & flint
;  :Author.	Codetapper
;  :Version	$Id: fmt_slackskin.s 1.2 2006/01/30 21:21:59 wepl Exp wepl $
;  :History.	27.08.05 created
;		30.01.06 Wepl - cleanup
;  :Requires.	OS V37+, MC68020+
;  :Language.	68020 Assembler
;  :Translator.	Barfly V2.9
;  :To Do.
;  :Info.	This format is used on Slackskin & Flint
;---------------------------------------------------------------------------*
; mfm-track structure
;   $4489 (sync)
;   $4489
;   $ffffffxx (xx = track number - odd)
;   $ffffffxx (xx = track number - even)
;   $1400/2 words mfm data (odd)
;   $1400/2 words mfm data (even)
;   $2 words (checksum - odd - even)
;------------------------------------------

		dc.l	_decode_slack	;decode
		dc.l	_encode_slack	;encode
		dc.l	0		;info
		dc.l	_name_slack	;name
		dc.l	_sync_slack	;sync
		dc.l	0		;density
		dc.w	0		;index
		dc.w	0		;speclen
		dc.w	$1400		;datalen
		dc.w	($1404*2)+12	;minimal rawlen
		dc.w    ($1404*2)+12	;writelen
		dc.w	TT_SLACKSKIN	;type
		dc.w	0		;flags

_sync_slack	dc.l	0,$44894489,$55555500,$55555500
		dc.l	0,$ffffffff,$ffffff00,$ffffff00

_name_slack	dc.b	"slackskin",0
		EVEN

;----------------------------------------
; decode slack track
; IN:	D0 = ULONG length of raw mfm-data in bits
;	D1 = ULONG track number
;	D2 = ULONG offset in mfm buffer
;	A0 = APTR  mfm buffer (source)
;	A1 = APTR  decoded buffer (destination)
; OUT:	D0 = BOOL  true on success
;	all other regs may scratched

_decode_slack	move.l	#$ffffff00,d4
		move.b	d1,d4			;d4 = Track number
		move.l	d2,d6			;d6 = offset

	;skip sync(4489) + extra sync (4489)
		addq.l	#4,a0

	;decode track
		move.l	#$55555555,d2

		bfextu	(a0){d6:32},d0		;move.l	(a0)+,d0
		bfextu	(4,a0){d6:32},d1	;move.l	(a0)+,d1
		addq.l	#8,a0
		and.l	d2,d0
		and.l	d2,d1
		add.l	d0,d0
		or.l	d1,d0
		cmp.l	d0,d4			;Check track number matches
		bne	.no

		moveq	#0,d4			;D4 = checksum
		move.l	#$500-1,d7
.decode_loop	bfextu	(a0){d6:32},d0		;move.l	(a0)+,d0
		bfextu	($1400,a0){d6:32},d1	;move.l	(a0)+,d1
		addq.l	#4,a0
		eor.l	d0,d4			;Adjust checksum
		eor.l	d1,d4
		and.l	d2,d0
		and.l	d2,d1
		add.l	d0,d0
		or.l	d1,d0
		move.l	d0,(a1)+
		dbf	d7,.decode_loop

		bfextu	($1400,a0){d6:32},d0	;move.l	(a0)+,d0
		bfextu	($1404,a0){d6:32},d1	;move.l	(a0)+,d1
		and.l	d2,d0
		and.l	d2,d1
		add.l	d0,d0
		or.l	d1,d0
		and.l	d2,d4			;Compare stored checksum
		cmp.l	d0,d4
		bne	.no

		moveq	#-1,d0
		rts

.no		moveq	#0,d0
		rts

;----------------------------------------
; encode slack track
; IN:	D0 = ULONG track number
;	A0 = APTR  destination buffer
;	A1 = APTR  source data to encode
; OUT:	D0 = mfmdata length written, 0 means error
;	all other regs may scratched

_encode_slack	move.l	#$ffffff00,d4		;d4 = Track number
		move.b	d0,d4
		move.l	#$55555555,d3

		move.l	#$44894489,(a0)+	;4 (sync + $4489)

		move.l	d4,d2			;4 (track number)
		bsr	_encode_longodd
		move.l	d4,d2
		bsr	_encode_long

		moveq	#0,d4			;D4 = checksum
		move.l	a0,a2			;A2 = Start of real data

		move.l	#$500-1,d6
.data_odd	move.l	(a1)+,d2		;$1400 (odd data)
		bsr	_encode_longodd
		dbf	d6,.data_odd

		sub.l	#$1400,a1
		move.l	#$500-1,d6
.data_even	move.l	(a1)+,d2		;$1400 (even data)
		bsr	_encode_long
		dbf	d6,.data_even

		move.l	#$a00-1,d6
.calc_loop	move.l	(a2)+,d0
		eor.l	d0,d4
		dbf	d6,.calc_loop
		and.l	d3,d4

		move.l	d4,d2
		bsr	_encode_longodd		;4 (odd checksum)
		move.l	d4,d2
		bsr	_encode_long		;4 (even checksum)

		move.l	#2*$1404+12,d0
		rts

