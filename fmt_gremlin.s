;*---------------------------------------------------------------------------
;  :Program.	fmt_gremlin.s
;  :Contents.	decode/encode gremlin tracks
;  :Author.	Wepl
;  :Version	$Id: fmt_gremlin.s 1.3 2005/04/07 23:24:32 wepl Exp wepl $
;  :History.	11.11.02 separated from formats.s
;		14.02.04 new decode/encode parameters and rework
;  :Requires.	OS V37+, MC68020+
;  :Language.	68020 Assembler
;  :Translator.	Barfly V2.9
;  :To Do.
;  :Info.	examples Lotus 1-3
;---------------------------------------------------------------------------*
; mfm-track structure
;
;	$448944894489	sync
;	$5555		unused
;	...		$3000 byte data
;	$xxxx $xxxx	checksum
;	$xxxx $xxxx	track number (sides swapped)
;----------------------------------------
; decode gremlin track (lotus)
; IN:	D0 = ULONG length of raw mfm-data in bits
;	D1 = ULONG track number
;	D2 = ULONG offset in mfm buffer
;	A0 = APTR  mfm buffer (source)
;	A1 = APTR  decoded buffer (destination)
; OUT:	D0 = BOOL  true on success
;	all other regs may scratched

_decode_grem	move.l	d0,d5			;D5 = mfm-length
		move.w	d1,d4			;D4 = track number

	;skip sync(448944894489) and unknown word(5555)
		add.w	#8,a0
		move.l	d2,d6			;offset

	;decode track
		move.w	#$bff,d7
		move.l	#$55555555,d2
		moveq	#0,d3

.loop		bsr	.get
		move.w	d1,(a1)+
		add.w	d1,d3
		dbf	d7,.loop

		bsr	.get
		cmp.w	d1,d3
		bne	.no

		bsr	.get
		bchg	#0,d1
		cmp.w	d1,d4
		bne	.no

		moveq	#-1,d0
		bra	.quit

.no		moveq	#0,d0

.quit		rts

.get		bfextu	(a0){d6:32},d0
		addq.l	#4,a0
		and.l	d2,d0
		move.w	d0,d1
		swap	d0
		add.w	d1,d1
		add.w	d0,d1
		rts

;----------------------------------------
; encode gremlin track
; IN:	D0 = ULONG track number
;	A0 = APTR  destination buffer
;	A1 = APTR  source data to encode
; OUT:	D0 = mfmdata length written, 0 means error
;	all other regs may scratched

_encode_grem	move.l	#$55555555,d3
		move.w	d0,d4			;D4 = tracknum

		move.l	#$44894489,(a0)+	;4
		move.l	#$44895555,(a0)+	;4
		moveq	#0,d5
		move.w	#$1800/2-1,d6
.data		move.w	(a1)+,d2		;$3000
		add.w	d2,d5
		move.w	d2,d0
		swap	d2
		lsr.w	#1,d0
		move.w	d0,d2
		bsr	_encode_long
		dbf	d6,.data
		move.w	d5,d2
		swap	d2
		lsr.w	#1,d5
		move.w	d5,d2
		bsr	_encode_long		;4
		move.w	d4,d2
		bchg	#0,d2
		move.w	d2,d0
		swap	d2
		lsr.w	#1,d0
		move.w	d0,d2
		bsr	_encode_long		;4

		move.l	#$3000+16,d0
		rts
