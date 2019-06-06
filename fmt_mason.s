;*---------------------------------------------------------------------------
;  :Program.	mason.s
;  :Contents.	decode/encode custom track format for mason games
;  :Author.	Codetapper
;  :Version	$Id: fmt_mason.s 1.3 2005/04/07 23:34:02 wepl Exp wepl $
;  :History.	14.02.04 created
;		15.03.04 reworked for new structures
;  :Requires.	OS V37+, MC68020+
;  :Language.	68020 Assembler
;  :Translator.	Barfly V2.9
;  :To Do.
;  :Info.	This format is used on Ian Botham's Cricket
;---------------------------------------------------------------------------*
; mfm-track structure
;   $44894489 = (2 syncs)
;   $55555555 \ $fafafafa
;   $52525252 /
;   $aaaaaaaa \ 0
;   $aaaaaaaa /
;   $aaaaaaaa \ 0
;   $aaaaaaaa /
;   $1600/2 longs of data (odd long then even long)
;   $xxxxxxxx \ checksum
;   $xxxxxxxx /
;------------------------------------------

		dc.l	_decode_mason	;decode
		dc.l	_encode_mason	;encode
		dc.l	0		;info
		dc.l	_name_mason	;name
		dc.l	_sync_mason	;sync
		dc.l	0		;density
		dc.w	0		;index
		dc.w	0		;speclen
		dc.w	$1600		;datalen
		dc.w	$2c24		;minimal rawlen
		dc.w	$2c24		;writelen
		dc.w	TT_MASON	;type
		dc.w	0		;flags

_sync_mason	dc.l	$44894489,$55555555,$52525252,$aaaaaaaa
		dc.l	$ffffffff,$ffffffff,$ffffffff,$ffffffff

_name_mason	dc.b	"mason",0
		EVEN

;----------------------------------------
; decode mason track
; IN:	D0 = ULONG length of raw mfm-data in bits
;	D1 = ULONG track number
;	D2 = ULONG offset in mfm buffer
;	A0 = APTR  mfm buffer (source)
;	A1 = APTR  decoded buffer (destination)
; OUT:	D0 = BOOL  true on success
;	all other regs may scratched

_decode_mason	move.l	d2,d6			;offset

	;skip syncs (44894489) + decoded long $fafafafa ($55555555 $52525252)
		add.l	#12,a0

	;decode track
		move.l	#$55555555,d2

		bsr	.decode_long
		tst.l	d0
		bne	.no

		bsr	.decode_long
		tst.l	d0
		bne	.no

		moveq	#0,d4			;d4 = chksum calc
		move.w	#($1600>>2)-1,d7	;decode $1600 bytes
.decode_loop	bsr	.decode_long
		move.l	d0,(a1)+
		dbf	d7,.decode_loop
		move.l	d4,d3
		and.l	d2,d3

		bsr	.decode_long
		cmp.l	d0,d3			;d3 = checksum
		bne	.no

		moveq	#-1,d0
		rts

.no		moveq	#0,d0
		rts

;----------------------------------------
; decode long (odd long then even long)
; IN:	D0 = Word to decode
;	D4 = chksum in
; OUT:	D0 = Decoded byte
;	D1 destroyed
;	D4 = chksum out

.decode_long	bfextu	(a0){d6:32},d0		;move.l	(a0)+,d0
		bfextu	(4,a0){d6:32},d1	;move.l	(a0)+,d1
		eor.l	d0,d4
		eor.l	d1,d4
		addq.l	#8,a0
		and.l	d2,d0
		and.l	d2,d1
		lsl.l	#1,d0
		or.l	d1,d0
		rts

;----------------------------------------
; encode mason track
; IN:	D0 = ULONG track number
;	A0 = APTR  destination buffer
;	A1 = APTR  source data to encode
; OUT:	D0 = mfmdata length written, 0 means error
;	all other regs may scratched

_encode_mason	move.l	#$55555555,d3

		move.l	#$44894489,(a0)+	;4

		move.l	#$fafafafa,d4
		bsr	.encode_long		;8

		moveq	#0,d4
		bsr	.encode_long		;8

		moveq	#0,d4
		bsr	.encode_long		;8

		move.w	#($1600>>2)-1,d6
		moveq	#0,d5
.encode		move.l	(a1)+,d4		;$2c00
		eor.l	d4,d5
		bsr	.encode_long
		dbf	d6,.encode

		move.l	d5,d4
		lsr.l	#1,d5
		eor.l	d5,d4
		and.l	d3,d4
		bsr	.encode_long

		move.l	#4+8+8+8+$2c00+8,d0
		rts

.encode_long	move.l	d4,d2
		bsr	_encode_longodd
		move.l	d4,d2
		bra	_encode_long
