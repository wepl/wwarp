;*---------------------------------------------------------------------------
;  :Program.	fmt_turrican3A_1800.s
;  :Contents.	decode/encode custom track format "Turrican 3" (Factor 5)
;  :Author.	Psygore
;  :Version	$Id: fmt_turrican3a_1800.s 1.7 2005/04/07 23:35:14 wepl Exp wepl $
;  :History.	16.04.02 created
;		01.05.02 mask sync changed (check $2AAA or $2AA5 after sync)
;		02.11.02 rework for new sync-search
;		05.03.04 new decode/encode parameters and rework
;  :Requires.	OS V37+, MC68020+
;  :Language.	68020 Assembler
;  :Translator.	Barfly V2.9
;  :To Do.
;---------------------------------------------------------------------------*
; mfm-track structure
;   $4489 (sync)
;   $2AAA or $2AA5 (unused)
;   $1800 mfm-words (data)
;   2 mfm-longwords (checksum)
;------------------------------------------

		dc.l	_decode_turrican3a	;decode
		dc.l	_encode_turrican3a	;encode
		dc.l	0			;info
		dc.l	_name_turrican3a	;name
		dc.l	_sync_turrican3a	;sync
		dc.l	0			;density
		dc.w	0			;index
		dc.w	0			;speclen
		dc.w	$1800			;datalen
		dc.w	4+($1800*2)+8		;minimal rawlen
		dc.w	4+($1800*2)+8		;writelen
		dc.w	TT_TURRICAN3A		;type
		dc.w	0			;flags

_sync_turrican3a dc.l	0,0,0,$44892AA0
		dc.l	0,0,0,$fffffff0
_name_turrican3a dc.b	"turrican3a",0
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

_decode_turrican3a

		move.l	d2,d6			;offset

	;skip sync
		addq.l	#2,a0

	;must have $2AAA or $2AA5 after sync
		bfextu	(a0){d6:16},d0
		cmp.w	#$2AA5,d0
		beq	.ok
		cmp.w	#$2AAA,d0
		bne	.no
.ok		addq.l	#2,a0

	;decode track
		move.l	#$55555555,d2

		moveq	#0,d5
		move.w	#$1800/4-1,d3
.decode		bfextu	(a0){d6:32},d0
		bfextu	(4,a0){d6:32},d1
		addq.l	#8,a0
		and.l	d2,d0
		and.l	d2,d1
		add.l	d0,d0
		or.l	d1,d0
		move.l	d0,(a1)+
		add.l	d0,d5
		dbf	d3,.decode

	;checksum
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

_encode_turrican3a
		move.l	#$55555555,d3

		move.l	#$44892AAA,(a0)+	;4
		moveq	#0,d5
		move.w	#$1800/4-1,d6
.data		move.l	(a1)+,d4
		add.l	d4,d5			:D5 = checksum
		move.l	d4,d2
		bsr	_encode_longodd
		move.l	d4,d2
		bsr	_encode_long
		dbf	d6,.data

	;encode checksum
		move.l	d5,d2
		bsr	_encode_longodd
		move.l	d5,d2
		bsr	_encode_long

		move.l	#4+2*$1804,d0
		rts
