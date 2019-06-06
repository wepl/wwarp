;*---------------------------------------------------------------------------
;  :Program.	fmt_turrican3B_1A00.s
;  :Contents.	decode/encode custom track format "Turrican 3" (Factor 5)
;  :Author.	Psygore
;  :Version	$Id: fmt_turrican3b_1A00.s 1.7 2005/04/07 23:28:58 wepl Exp wepl $
;  :History.	16.14.02 created
;		02.11.02 rework for new sync-search
;		05.03.04 new decode/encode parameters and rework
;  :Requires.	OS V37+, MC68020+
;  :Language.	68020 Assembler
;  :Translator.	Barfly V2.9
;  :To Do.
;---------------------------------------------------------------------------*
; mfm-track structure
;   $4489 (sync)
;   $2AA5 (unused)
;   2 mfm-words (cylinder number)
;   $1A00 mfm-words (data)
;   2 mfm-longs (checksum)
;------------------------------------------

		dc.l	_decode_turrican3b	;decode
		dc.l	_encode_turrican3b	;encode
		dc.l	0			;info
		dc.l	_name_turrican3b	;name
		dc.l	_sync_turrican3b	;sync
		dc.l	0			;density
		dc.w	0			;index
		dc.w	0			;speclen
		dc.w	$1A00			;datalen
		dc.w	4+4+($1A00*2)+8		;minimal rawlen
		dc.w	4+4+($1A00*2)+8		;writelen
		dc.w	TT_TURRICAN3B		;type
		dc.w	0			;flags

_sync_turrican3b dc.l	0,0,0,$44892AA5
		dc.l	0,0,0,$ffffffff

_name_turrican3b dc.b	"turrican3b",0
		EVEN

;----------------------------------------
; decode Turrican3 track
; IN:	D0 = ULONG length of raw mfm-data in bits
;	D1 = ULONG track number
;	D2 = ULONG offset in mfm buffer
;	A0 = APTR  mfm buffer (source)
;	A1 = APTR  decoded buffer (destination)
; OUT:	D0 = BOOL  true on success
;	all other regs may scratched

_decode_turrican3b

		move.l	d1,d3
		move.l	d2,d6			;offset

	;skip sync(4489) and unknown word(2AA5)
		addq.l	#4,a0

	;decode track
		move.l	#$55555555,d2

	;check track number
		bfextu	(a0){d6:32},d0
		addq.l	#4,a0
		and.l	d2,d0
		move.w	d0,d1
		swap	d0
		add.w	d0,d0
		or.w	d1,d0
		lsr.w	#1,d3
		cmp.w	d0,d3
		bne	.no

		moveq	#0,d5
		move.w	#$1A00/4-1,d3
.decode		bfextu	(a0){d6:32},d0
		bfextu	(4,a0){d6:32},d1
		addq.l	#8,a0
		and.l	d2,d0
		and.l	d2,d1
		add.l	d0,d0
		or.l	d1,d0
		move.l	d0,(a1)+
		add.l	d0,d5			;D5 = checksum
		dbf	d3,.decode

	;compare checksum
		bfextu	(a0){d6:32},d0
		bfextu	(4,a0){d6:32},d1
		and.l	d2,d0
		and.l	d2,d1
		add.l	d0,d0
		or.l	d1,d0
		cmp.l	d0,d5
		bne	.no

		moveq	#-1,d0
		rts

.no		moveq	#0,d0
		rts

;----------------------------------------
; encode Turrican 3 track
; IN:	D0 = ULONG track number
;	A0 = APTR  destination buffer
;	A1 = APTR  source data to encode
; OUT:	D0 = mfmdata length written, 0 means error
;	all other regs may scratched

_encode_turrican3b

		move.l	#$55555555,d3
		move.l	d0,d4

		move.l	#$44892AA5,(a0)+	;4

	;encode	track number
		lsr.w	#1,d4			;cylinder
		move.w	d4,d2
		lsr.w	#1,d2
		swap	d2
		move.w	d4,d2
		bsr	_encode_long		;4

		moveq	#0,d5
		move.w	#$1A00/4-1,d6
.data		move.l	(a1)+,d4
		add.l	d4,d5
		move.l	d4,d2
		bsr	_encode_longodd
		move.l	d4,d2
		bsr	_encode_long
		dbf	d6,.data

	;encode checksum
		move.l	d5,d2
		bsr	_encode_longodd		;4
		move.l	d5,d2
		bsr	_encode_long		;4

		move.l	#4+4+2*$1a04,d0
		rts
