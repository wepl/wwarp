;*---------------------------------------------------------------------------
;  :Program.	fmt_turrican.s
;  :Contents.	decode/encode custom track format "Turrican" (Factor 5)
;  :Author.	Psygore
;  :Version	$Id: fmt_turrican1.s 1.6 2005/04/07 23:28:58 wepl Exp wepl $
;  :History.	15.14.02 created
;		02.11.02 rework for new sync-search
;		27.02.04 new decode/encode parameters and rework
;  :Requires.	OS V37+, MC68020+
;  :Language.	68020 Assembler
;  :Translator.	Barfly V2.9
;  :To Do.
;---------------------------------------------------------------------------*
; mfm-track structure
;
;   $9521 (sync)
;   $2AAA (unused)
;   $1978 mfm-words (data)
;   2 mfm-longwords (checksum)
;------------------------------------------

		dc.l	_decode_turrican1	;decode
		dc.l	_encode_turrican1	;encode
		dc.l	0			;info
		dc.l	_name_turrican1		;name
		dc.l	_sync_turrican1		;sync
		dc.l	0			;density
		dc.w	0			;index
		dc.w	0			;speclen
		dc.w	$1978			;datalen
		dc.w	4+($1978*2)+8		;minimal rawlen
		dc.w	4+($1978*2)+8		;writelen
		dc.w	TT_TURRICAN1		;type
		dc.w	0			;flags

_sync_turrican1	dc.l	0,0,0,$95212AAA
		dc.l	0,0,0,$ffffffff

_name_turrican1	dc.b	"turrican1",0
		EVEN

;----------------------------------------
; decode Turrican track
; IN:	D0 = ULONG length of raw mfm-data in bits
;	D1 = ULONG track number
;	D2 = ULONG offset in mfm buffer
;	A0 = APTR  mfm buffer (source)
;	A1 = APTR  decoded buffer (destination)
; OUT:	D0 = BOOL  true on success
;	all other regs may scratched

_decode_turrican1
		move.w	#$1978,d1

_decode_tur	move.l	d1,d3			;D3 = decoded length
		move.l	d2,d6			;D6 = offset

	;skip sync(9521) and unknown word(2AAA)
		addq.l	#4,a0

	;decode track
		move.l	#$55555555,d2
		moveq	#0,d5
		lsr.w	#2,d3
		subq.w	#1,d3
.decode
		bfextu	(a0){d6:32},d0
		bfextu	(4,a0){d6:32},d1
		addq.l	#8,a0
		eor.l	d0,d5
		eor.l	d1,d5
		and.l	d2,d0
		and.l	d2,d1
		add.l	d0,d0
		or.l	d1,d0
		move.l	d0,(a1)+
		dbf	d3,.decode

	;checksum
		bfextu	(a0){d6:32},d0
		bfextu	(4,a0){d6:32},d1
		and.l	d2,d0
		and.l	d2,d1
		add.l	d0,d0
		or.l	d1,d0
		and.l	d2,d5
		cmp.l	d0,d5
		bne	.no

		moveq	#-1,d0
		rts

.no		moveq	#0,d0
		rts

;----------------------------------------
; encode Turrican track
; IN:	D0 = ULONG track number
;	A0 = APTR  destination buffer
;	A1 = APTR  source data to encode
; OUT:	D0 = mfmdata length written, 0 means error
;	all other regs may scratched

_encode_turrican1
		move.w	#$1978,d1

_encode_tur	move.w	d1,d7			;D7 = decoded length
		move.l	#$55555555,d3

		move.l	#$95212AAA,(a0)+	;4
		moveq	#0,d5
		move.w	d7,d6
		lsr.w	#2,d6
		subq.w	#1,d6
.data		move.l	(a1)+,d4
		move.l	d4,d2
		bsr	_encode_longodd
		eor.l	d2,d5
		move.l	d4,d2
		bsr	_encode_long
		eor.l	d2,d5			;D5 = checksum
		dbf	d6,.data

	;encode checksum
		and.l	d3,d5
		move.l	d5,d2
		bsr	_encode_longodd
		move.l	d5,d2
		bsr	_encode_long

		moveq	#12,d0
		add.w	d7,d0
		add.w	d7,d0
		rts
