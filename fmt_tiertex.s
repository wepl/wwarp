;*---------------------------------------------------------------------------
;  :Program.	tiertex.s
;  :Contents.	decode/encode custom track format for tiertex games
;  :Author.	Codetapper
;  :Version	$Id: fmt_tiertex.s 1.3 2005/04/07 23:26:58 wepl Exp wepl $
;  :History.	08.12.02 created
;		27.02.04 new decode/encode parameters and rework
;  :Requires.	OS V37+, MC68020+
;  :Language.	68020 Assembler
;  :Translator.	Barfly V2.9
;  :To Do.
;  :Info.	This format is used on Strider
;---------------------------------------------------------------------------*
; mfm-track structure
;   $a245 (sync)
;   $4489
;   $2 words (track number - odd then even)
;   $1800/2 words mfm data (odd)
;   $2 words (checksum - odd)
;   $1800/2 words mfm data (even)
;   $2 words (checksum - even)
;------------------------------------------

		dc.l	_decode_tiertex	;decode
		dc.l	_encode_tiertex	;encode
		dc.l	0		;info
		dc.l	_name_tiertex	;name
		dc.l	_sync_tiertex	;sync
		dc.l	0		;density
		dc.w	0		;index
		dc.w	0		;speclen
		dc.w	$1800		;datalen
		dc.w	($1804*2)+8	;minimal rawlen
		dc.w	($1804*2)+8	;writelen
		dc.w	TT_TIERTEX	;type
		dc.w	0		;flags

_sync_tiertex	dc.l	0,0,$a2,$4544892a
		dc.l	0,0,$ff,$ffffffff

_name_tiertex	dc.b	"tiertex",0
		EVEN

;----------------------------------------
; decode tiertex track
; IN:	D0 = ULONG length of raw mfm-data in bits
;	D1 = ULONG track number
;	D2 = ULONG offset in mfm buffer
;	A0 = APTR  mfm buffer (source)
;	A1 = APTR  decoded buffer (destination)
; OUT:	D0 = BOOL  true on success
;	all other regs may scratched

_decode_tiertex move.w	d1,d4			;d4 = Track number
		move.l	d2,d6			;d6 = offset

	;skip sync(a245) + extra word (4489)
		addq.l	#4,a0

	;decode track
		move.l	#$55555555,d2

		bfextu	(a0){d6:32},d0		;move.w	(a0)+,d0 and move.w (a0)+,d1
		addq.l	#4,a0
		move.w	d0,d1
		swap	d0
		and.w	d2,d0
		and.w	d2,d1
		lsl.w	#1,d0
		or.w	d1,d0
		cmp.w	d0,d4			;Check track number matches
		bne	.no

		moveq	#0,d4			;D4 = checksum
		move.l	#$600-1,d7
.decode_loop	bfextu	(a0){d6:32},d0		;move.l	(a0)+,d0
		bfextu	($1804,a0){d6:32},d1	;move.l	(a0)+,d1
		addq.l	#4,a0
		and.l	d2,d0
		and.l	d2,d1
		lsl.l	#1,d0
		or.l	d1,d0
		add.l	d0,d4			;Adjust checksum
		move.l	d0,(a1)+
		dbf	d7,.decode_loop

		bfextu	(a0){d6:32},d0		;move.l	(a0)+,d0
		bfextu	($1804,a0){d6:32},d1	;move.l	(a0)+,d1
		and.l	d2,d0
		and.l	d2,d1
		lsl.l	#1,d0
		or.l	d1,d0
		not.l	d4
		cmp.l	d0,d4
		bne	.no

		moveq	#-1,d0
		bra	.quit

.no		moveq	#0,d0

.quit		rts

;----------------------------------------
; encode tiertex track
; IN:	D0 = ULONG track number
;	A0 = APTR  destination buffer
;	A1 = APTR  source data to encode
; OUT:	D0 = mfmdata length written, 0 means error
;	all other regs may scratched

_encode_tiertex	move.w	d0,d4			;d4 = Track number
		move.l	#$55555555,d3

		move.l	#$a2454489,(a0)+	;4 (sync + $4489)

		move.w	d4,d2			;4 (track number)
		bsr	_encode_wordodd
		move.w	d4,d2
		bsr	_encode_word

		moveq	#0,d4			;D4 = checksum

		move.l	#$600-1,d6
.data_odd	move.l	(a1)+,d2		;$1800 (odd data)
		add.l	d2,d4
		bsr	_encode_longodd
		dbf	d6,.data_odd

		not.l	d4
		move.l	d4,d2
		bsr	_encode_longodd		;4 (odd checksum)

		sub.l	#$1800,a1
		move.l	#$600-1,d6
.data_even	move.l	(a1)+,d2		;$1800 (even data)
		bsr	_encode_long
		dbf	d6,.data_even

		move.l	d4,d2
		bsr	_encode_long		;4 (even checksum)

		move.l	#2*$1804+8,d0
		rts
