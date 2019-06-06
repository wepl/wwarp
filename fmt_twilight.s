;*---------------------------------------------------------------------------
;  :Program.	twilight.s
;  :Contents.	decode/encode custom track format for twilight games
;  :Author.	Codetapper
;  :Version	$Id: fmt_twilight.s 1.7 2005/04/07 23:34:02 wepl Exp wepl $
;  :History.	25.09.02 created
;		08.11.02 rework for new sync-search
;		11.11.02 minor changes (Wepl)
;		07.03.04 new decode/encode parameters and rework
;		04.10.04 variation 2 and 3 (Awesome) added
;  :Requires.	OS V37+, MC68020+
;  :Language.	68020 Assembler
;  :Translator.	Barfly V2.9
;  :To Do.
;  :Info.	twilight1 is used on Hong Kong Phooey, Top Cat, WWF
;		Wrestlemania, Yogi Bear and Friends in the Greed Monster
;		and probably plenty of others... Thanks to Psygore for
;		assistance and bug fixing!
;		twilight2/3 is used on Awesome
;---------------------------------------------------------------------------*
; mfm-track structure
;   $44894489 (sync)
;   $ffffffxx (track number odd)
;   $ffffffxx (track number even)
;   $xxxxxxxx (checksum odd) no information due mfm masking!
;   $xxxxxxxx (checksum even)
;   $1400/1520/1800 words mfm data (odd)
;   $1400/1520/1800 words mfm data (even)
;------------------------------------------

;----------------------------------------
; decode twilight track
; IN:	D0 = ULONG length of raw mfm-data in bits
;	D1 = ULONG track number
;	D2 = ULONG offset in mfm buffer
;	A0 = APTR  mfm buffer (source)
;	A1 = APTR  decoded buffer (destination)
; OUT:	D0 = BOOL  true on success
;	all other regs may scratched

_decode_twilight1
		move.w	#$1400,d4
		bra	_decode_twilight
_decode_twilight2
		move.w	#$1520,d4
		bra	_decode_twilight
_decode_twilight3
		move.w	#$1800,d4
_decode_twilight
		move.l	d2,d6			;offset
		moveq	#-1,d3
		move.b	d1,d3			;tracknumber long

	;skip sync(44894489)
		addq.l	#4,a0

	;decode track
		move.l	#$55555555,d2

		bsr	.getlong		;Check track matches
		cmp.l	d0,d3
		bne	.no

		bsr	.getlong		;Read checksum
		move.l	d0,d3			;D3 = chksum

		move.w	d4,d7
		lsr.w	#2,d7
		subq.w	#1,d7
		lea	(a0,d4.w),a2

.decodeloop	bfextu	(a0){d6:32},d0
		bfextu	(a2){d6:32},d1
		addq.l	#4,a0
		addq.l	#4,a2
		and.l	d2,d0
		and.l	d2,d1
		eor.l	d0,d3
		eor.l	d1,d3
		add.l	d0,d0
		or.l	d1,d0
		move.l	d0,(a1)+
		dbra	d7,.decodeloop

		tst.l	d3
		bne	.no

		moveq	#-1,d0
		rts

.no		moveq	#0,d0
		rts

.getlong	bfextu	(a0){d6:32},d0
		bfextu	(4,a0){d6:32},d1
		addq.l	#8,a0
		and.l	d2,d0
		and.l	d2,d1
		add.l	d0,d0
		or.l	d1,d0
		rts

;----------------------------------------
; encode twilight track
; IN:	D0 = ULONG track number
;	A0 = APTR  destination buffer
;	A1 = APTR  source data to encode
; OUT:	D0 = mfmdata length written, 0 means error
;	all other regs may scratched

_encode_twilight1
		move.w	#$1400,d5
		bra	_encode_twilight
_encode_twilight2
		move.w	#$1520,d5
		bra	_encode_twilight
_encode_twilight3
		move.w	#$1800,d5
_encode_twilight
		moveq	#-1,d4
		move.b	d0,d4			;d4 = Track number
		move.l	#$55555555,d3

		move.l	#$44894489,(a0)+	;4

		move.l	d4,d2			;Encode track number
		bsr	_encode_longodd		;4
		move.l	d4,d2
		bsr	_encode_long		;4

	;chksum
		moveq	#0,d2
		bsr	_encode_long
		move.w	d5,d0
		lsr.w	#2,d0
		subq.w	#2,d0
		move.l	(a1)+,d2
.chksum		move.l	(a1)+,d1
		eor.l	d1,d2
		dbf	d0,.chksum
		move.l	d2,d0
		lsr.l	#1,d0
		eor.l	d0,d2
		bsr	_encode_long

	;data
		sub.w	d5,a1
		move.w	d5,d6
		lsr.w	#2,d6
		subq.w	#1,d6
.data1		move.l	(a1)+,d2
		bsr	_encode_longodd
		dbf	d6,.data1
		sub.w	d5,a1
		move.w	d5,d6
		lsr.w	#2,d6
		subq.w	#1,d6
.data2		move.l	(a1)+,d2
		bsr	_encode_long
		dbf	d6,.data2

	;the following is only added to avoid false format
	;detections between the various twilight formats
		moveq	#-1,d2
		bsr	_encode_word
		bsr	_encode_wordodd

		moveq	#4+8+8+4,d0
		add.w	d5,d0
		add.w	d5,d0
		rts
