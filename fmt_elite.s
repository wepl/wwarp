;*---------------------------------------------------------------------------
;  :Program.	elite.s
;  :Contents.	decode/encode custom track format for elite games
;  :Author.	Codetapper
;  :Version	$Id: fmt_elite.s 1.3 2005/04/07 23:26:58 wepl Exp wepl $
;  :History.	08.12.02 created
;		14.02.04 new decode/encode parameters and rework
;  :Requires.	OS V37+, MC68020+
;  :Language.	68020 Assembler
;  :Translator.	Barfly V2.9
;  :To Do.
;  :Info.	This format is used on Mighty Bombjack and Tournament Golf
;---------------------------------------------------------------------------*
;------------------------------------------
; mfm-track structure
;
;   $9122 (sync)
;   $8912
;   $2 words (track number - odd then even)
;   $2 words (checksum - odd then even)
;   $1800/2 words mfm data (odd then even)
;------------------------------------------

		dc.l	_decode_elite	;decode
		dc.l	_encode_elite	;encode
		dc.l	0		;info
		dc.l	_name_elite	;name
		dc.l	_sync_elite	;sync
		dc.l	0		;density
		dc.w	0		;index
		dc.w	0		;speclen
		dc.w	$1800		;datalen
		dc.w	($1800*2)+$c	;minimal rawlen
		dc.w	($1800*2)+$c	;writelen
		dc.w	TT_ELITE	;type
		dc.w	0		;flags

_sync_elite	dc.l	0,0,$9122,$8912aa00
		dc.l	0,0,$ffff,$ffffff00

_name_elite	dc.b	"elite",0
		EVEN

;----------------------------------------
; decode elite track
; IN:	D0 = ULONG length of raw mfm-data in bits
;	D1 = ULONG track number
;	D2 = ULONG offset in mfm buffer
;	A0 = APTR  mfm buffer (source)
;	A1 = APTR  decoded buffer (destination)
; OUT:	D0 = BOOL  true on success
;	all other regs may scratched

_decode_elite	move.w	d1,d4			;d4 = Track number

	;skip sync(9122) + extra word (8912)
		addq.l	#4,a0
		move.l	d2,d6			;offset

	;decode track
		move.l	#$55555555,d2

		moveq	#-1,d3			;d3 = Checksum

		bfextu	(a0){d6:32},d0		;move.w	(a0)+,d0 and move.w (a0)+,d1
		addq.l	#4,a0
		move.w	d0,d1
		swap	d0
		and.w	d2,d0
		and.w	d2,d1
		lsl.w	#1,d0
		or.w	d1,d0
		eor.w	d0,d3			;Adjust checksum
		cmp.w	d0,d4			;Check track number matches
		bne	.no

		bfextu	(a0){d6:32},d0		;move.w	(a0)+,d0 and move.w (a0)+,d1
		addq.l	#4,a0
		move.w	d0,d1
		swap	d0
		and.w	d2,d0
		and.w	d2,d1
		lsl.w	#1,d0
		or.w	d1,d0
		eor.w	d0,d3			;Adjust checksum

		move.l	#($1800/2)-1,d7
.decodetrack	bfextu	(a0){d6:32},d0		;move.w	(a0)+,d0 and move.w (a0)+,d1
		addq.l	#4,a0
		move.w	d0,d1
		swap	d0
		and.w	d2,d0
		and.w	d2,d1
		lsl.w	#1,d0
		or.w	d1,d0
		move.w	d0,(a1)+
		eor.w	d0,d3			;Adjust checksum
		dbf	d7,.decodetrack

		tst.w	d3			;d3 = 0 if OK
		bne	.no

		moveq	#-1,d0
		bra	.quit

.no		moveq	#0,d0

.quit		rts

;----------------------------------------
; encode elite track
; IN:	D0 = ULONG track number
;	A0 = APTR  destination buffer
;	A1 = APTR  source data to encode
; OUT:	D0 = mfmdata length written, 0 means error
;	all other regs may scratched

_encode_elite	move.l	#$55555555,d3

		move.w	d0,d4			;d4 = Track number

		move.l	#$91228912,(a0)+	;4 (sync + $8912)

		move.w	d4,d2			;4 (track number)
		bsr	_encode_wordodd
		move.w	d4,d2
		bsr	_encode_word

		moveq	#-1,d5
		eor.w	d4,d5
		move.l	#($1800/2)-1,d7
.checksum	move.w	(a1)+,d0
		eor.w	d0,d5
		dbf	d7,.checksum

		move.w	d5,d2			;4 (checksum)
		bsr	_encode_wordodd
		move.w	d5,d2
		bsr	_encode_word

		sub.l	#$1800,a1
		move.l	#($1800/2)-1,d6
.data_loop	move.w	(a1)+,d4		;$1800 (odd data)
		move.w	d4,d2
		bsr	_encode_wordodd
		move.w	d4,d2
		bsr	_encode_word
		dbf	d6,.data_loop

		move.l	#(2*$1800)+12,d0
		rts
