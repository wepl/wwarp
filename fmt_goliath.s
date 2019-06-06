;*---------------------------------------------------------------------------
;  :Program.	goliath.s
;  :Contents.	decode/encode custom track format for goliath games
;  :Author.	Codetapper
;  :Version	$Id: fmt_goliath.s 1.3 2005/04/07 23:26:58 wepl Exp wepl $
;  :History.	21.12.03 created
;		14.02.04 new decode/encode parameters and rework
;  :Requires.	OS V37+, MC68020+
;  :Language.	68020 Assembler
;  :Translator.	Barfly V2.9
;  :To Do.
;  :Info.	This format is used on Subbuteo
;---------------------------------------------------------------------------*
; mfm-track structure
;
;   $8a51 (sync)
;   $2aaa
;   $aaaa
;   $aaa5
;   $1600 longs mfm data (odd then even)
;   $2 words (checksum - odd then even)
;------------------------------------------

		dc.l	_decode_goliath	;decode
		dc.l	_encode_goliath	;encode
		dc.l	0		;info
		dc.l	_name_goliath	;name
		dc.l	_sync_goliath	;sync
		dc.l	0		;density
		dc.w	0		;index
		dc.w	0		;speclen
		dc.w	$1600		;datalen
		dc.w	($1600*2)+$10	;minimal rawlen
		dc.w	($1600*2)+$10	;writelen
		dc.w	TT_GOLIATH	;type
		dc.w	0		;flags

_sync_goliath	dc.l	0,0,$8a512aaa,$aaaaaaa5
		dc.l	0,0,$ffffffff,$ffffffff

_name_goliath	dc.b	"goliath",0
		EVEN

;----------------------------------------
; decode goliath track
; IN:	D0 = ULONG length of raw mfm-data in bits
;	D1 = ULONG track number
;	D2 = ULONG offset in mfm buffer
;	A0 = APTR  mfm buffer (source)
;	A1 = APTR  decoded buffer (destination)
; OUT:	D0 = BOOL  true on success
;	all other regs may scratched

_decode_goliath

	;skip sync(8a51) + extra word (2aaa) + extra long (aaaaaaa5)
		addq.l	#8,a0
		move.l	d2,d6			;offset

	;decode track
		move.l	#$55555555,d2
		moveq	#0,d3			;d3 = Checksum

		move.l	#($1600/4)-1,d7
.decodetrack	bfextu	(a0){d6:32},d0		;move.l	(a0)+,d0
		bfextu	(4,a0){d6:32},d1	;move.l	(a0)+,d1
		addq.l	#8,a0
		and.l	d2,d0
		and.l	d2,d1
		lsl.l	#1,d0
		or.l	d1,d0
		move.l	d0,(a1)+
		add.l	d0,d3			;Adjust checksum
		dbf	d7,.decodetrack

		bfextu	(a0){d6:32},d0		;move.l	(a0)+,d0
		bfextu	(4,a0){d6:32},d1	;move.l	(a0)+,d1
		and.l	d2,d0
		and.l	d2,d1
		lsl.l	#1,d0
		or.l	d1,d0
		cmp.l	d0,d3			;Check checksum matches
		bne	.no

		moveq	#-1,d0
		bra	.quit

.no		moveq	#0,d0

.quit		rts

;----------------------------------------
; encode goliath track
; IN:	D0 = ULONG track number
;	A0 = APTR  destination buffer
;	A1 = APTR  source data to encode
; OUT:	D0 = mfmdata length written, 0 means error
;	all other regs may scratched

_encode_goliath	move.l	#$55555555,d3

		move.l	#$8a512aaa,(a0)+	;4 (sync + $2aaa)
		move.l	#$aaaaaaa5,(a0)+	;4 ($aaaaaaa5)

		moveq	#0,d5			;Checksum
		move.l	#($1600/4)-1,d6
.data_loop	move.l	(a1)+,d4
		add.l	d4,d5
		move.l	d4,d2
		bsr	_encode_longodd		;$1600 (odd data)
		move.l	d4,d2
		bsr	_encode_long		;$1600 (even data)
		dbf	d6,.data_loop

		move.l	d5,d2
		bsr	_encode_longodd		;$4 checksum (odd data)
		move.l	d5,d2
		bsr	_encode_long		;$4 checksum (even data)

		move.l	#$1600*2+16,d0
		rts
