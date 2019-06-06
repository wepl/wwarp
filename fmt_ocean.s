;*---------------------------------------------------------------------------
;  :Program.	ocean.s
;  :Contents.	decode/encode custom track format for ocean games
;  :Author.	Codetapper
;  :Version	$Id: fmt_ocean.s 1.4 2005/04/07 23:26:58 wepl Exp wepl $
;  :History.	27.10.02 created
;		08.11.02 rework for new sync-search
;		08.11.02 minor changes (Wepl)
;		14.02.04 new decode/encode parameters and rework
;  :Requires.	OS V37+, MC68020+
;  :Language.	68020 Assembler
;  :Translator.	Barfly V2.9
;  :To Do.
;  :Info.	This format is used on Bart Vs the Space Mutants, WWF
;		European Rampage and probably lots of others...
;---------------------------------------------------------------------------*
; mfm-track structure
;
;   $4489 (sync)
;   $2aaaaaaa
;   $200 words mfm data (odd then even) \ 12 sectors x $200 bytes
;   $2 words (checksum)                 /
;------------------------------------------

		dc.l	_decode_ocean	;decode
		dc.l	_encode_ocean	;encode
		dc.l	0		;info
		dc.l	_name_ocean	;name
		dc.l	_sync_ocean	;sync
		dc.l	0		;density
		dc.w	0		;index
		dc.w	0		;speclen
		dc.w	$1800		;datalen
		dc.w	($404*12)+6	;minimal rawlen
		dc.w	($404*12)+6	;writelen
		dc.w	TT_OCEAN	;type
		dc.w	0		;flags

_sync_ocean	dc.l	0,0,$4489,$2aaaaaaa
		dc.l	0,0,$ffff,$ffffffff

_name_ocean	dc.b	"ocean",0
		EVEN

;----------------------------------------
; decode ocean track
; IN:	D0 = ULONG length of raw mfm-data in bits
;	D1 = ULONG track number
;	D2 = ULONG offset in mfm buffer
;	A0 = APTR  mfm buffer (source)
;	A1 = APTR  decoded buffer (destination)
; OUT:	D0 = BOOL  true on success
;	all other regs may scratched

_decode_ocean

	;skip sync(4489) + extra longword
		addq.l	#6,a0
		move.l	d2,d6			;offset

	;decode track
		move.l	#$55555555,d2

		moveq	#12-1,d4		;D4 = sectors to decode
.decode_sector	moveq	#0,d7			;D7 = checksum
		move.l	#($200/4)-1,d3
.decode_loop	bfextu	(a0){d6:32},d0		;move.l	(a0)+,d0
		bfextu	(4,a0){d6:32},d1	;move.l	(a0)+,d1
		addq.l	#8,a0
		and.l	d2,d0
		and.l	d2,d1
		lsl.l	#1,d0
		or.l	d1,d0
		move.l	d0,(a1)+
		eor.w	d0,d7
		dbf	d3,.decode_loop

		bfextu	(a0){d6:32},d0		;move.w	(a0)+,d0
		and.l	d2,d0
		move.l	d0,d1
		swap	d0
		lsl.w	#1,d0
		or.w	d1,d0
		eor.w	d0,d7
		bne	.no
		addq.l	#4,a0
		dbf	d4,.decode_sector

		moveq	#-1,d0
		bra	.quit

.no		moveq	#0,d0

.quit		rts

;----------------------------------------
; encode ocean track
; IN:	D0 = ULONG track number
;	A0 = APTR  destination buffer
;	A1 = APTR  source data to encode
; OUT:	D0 = mfmdata length written, 0 means error
;	all other regs may scratched

_encode_ocean	move.l	#$55555555,d3

		move.w	#$4489,(a0)+		;2
		move.l	#$2aaaaaaa,(a0)+	;4

		moveq	#12-1,d5		;d5 = Sectors left to encode

.next_sector	move.w	#($200/4)-1,d6		;Encode data
		moveq	#0,d7

.data_sector	move.l	(a1)+,d4		;$400
		eor.l	d4,d7
		move.l	d4,d2
		bsr	_encode_longodd
		move.l	d4,d2
		bsr	_encode_long
		dbf	d6,.data_sector

		move.w	d7,d2
		lsr.w	#1,d2
		swap	d2
		move.w	d7,d2
		bsr	_encode_long		;4

		dbf	d5,.next_sector

		move.l	#($404*12)+6,d0
		rts
