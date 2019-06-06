;*---------------------------------------------------------------------------
;  :Program.	beyond.s
;  :Contents.	decode/encode custom track format for Beyond the Ice Palace
;  :Author.	Codetapper
;  :Version	$Id: fmt_beyond.s 1.3 2005/04/07 23:34:02 wepl Exp wepl $
;  :History.	08.12.02 created
;		14.02.04 new decode/encode parameters and rework
;  :Requires.	OS V37+, MC68020+
;  :Language.	68020 Assembler
;  :Translator.	Barfly V2.9
;  :To Do.
;  :Info.	This format is used on Beyond the Ice Palace
;---------------------------------------------------------------------------*
; mfm-track structure
;   $4489 (sync)
;   $xaaa (usually $aaaa but sometimes $2aaa and $6aaa - first 2 bits ignored!)
;   $1400 bytes mfm data (odd)
;   $xxxx checksum (odd)
;   $1400 bytes mfm data (even)
;   $xxxx checksum (even)
;------------------------------------------

		dc.l	_decode_beyond	;decode
		dc.l	_encode_beyond	;encode
		dc.l	0		;info
		dc.l	_name_beyond	;name
		dc.l	_sync_beyond	;sync
		dc.l	0		;density
		dc.w	0		;index
		dc.w	0		;speclen
		dc.w	$1400		;datalen
		dc.w	($1404*2)+4	;minimal rawlen
		dc.w	($1404*2)+4	;writelen
		dc.w	TT_BEYOND	;type
		dc.w	0		;flags

_sync_beyond	dc.l	0,0,0,$44892aaa
		dc.l	0,0,0,$ffff3fff

_name_beyond	dc.b	"beyond",0
		EVEN

;----------------------------------------
; decode beyond track
; IN:	D0 = ULONG length of raw mfm-data in bits
;	D1 = ULONG track number
;	D2 = ULONG offset in mfm buffer
;	A0 = APTR  mfm buffer (source)
;	A1 = APTR  decoded buffer (destination)
; OUT:	D0 = BOOL  true on success
;	all other regs may scratched

_decode_beyond

	;skip sync(4489) + first word ($2aaa when masked with $3fff)
		addq.l	#4,a0

	;decode track
		move.l	#$55555555,d3

		lea	$1404(a0),a2
		moveq	#0,d4			;D4 = checksum

		move.l	#($1400>>2)-1,d7
.decode_loop	bsr	.get
		add.l	d0,d4			;adjust checksum
		move.l	d0,(a1)+
		dbf	d7,.decode_loop

		bsr	.get
		not.l	d4
		cmp.l	d0,d4			;compare checksum
		bne	.no

		moveq	#-1,d0
		bra	.quit

.no		moveq	#0,d0

.quit		rts

.get		bfextu	(a0){d2:32},d0		;move.l	(a0)+,d0
		addq.l	#4,a0
		bfextu	(a2){d2:32},d1		;move.l	(a0)+,d1
		addq.l	#4,a2
		and.l	d3,d0
		and.l	d3,d1
		lsl.l	#1,d0
		or.l	d1,d0
		rts

;----------------------------------------
; encode beyond track
; IN:	D0 = ULONG track number
;	A0 = APTR  destination buffer
;	A1 = APTR  source data to encode
; OUT:	D0 = mfmdata length written, 0 means error
;	all other regs may scratched

_encode_beyond	move.l	#$55555555,d3

		move.l	#$44892aaa,(a0)+	;4 (sync + $4489)

		moveq	#0,d4			;D4 = checksum
		move.l	#($1400>>2)-1,d6
.data_odd	move.l	(a1)+,d2		;$1400 (odd data)
		add.l	d2,d4			;adjust checksum
		bsr	_encode_longodd
		dbf	d6,.data_odd

		not.l	d4			;final checksum
		move.l	d4,d2
		bsr	_encode_longodd		;4 (odd checksum)

		sub.l	#$1400,a1
		move.l	#($1400>>2)-1,d6
.data_even	move.l	(a1)+,d2		;$1400 (even data)
		bsr	_encode_long
		dbf	d6,.data_even

		move.l	d4,d2
		bsr	_encode_long		;4 (even checksum)

		move.l	#$1404*2+4,d0
		rts
