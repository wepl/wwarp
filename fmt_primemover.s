;*---------------------------------------------------------------------------
;  :Program.	primemover.s
;  :Contents.	decode/encode custom track format "Prime Mover" (Psygnosis)
;  :Author.	Psygore
;  :Version	$Id: fmt_primemover.s 1.6 2005/04/07 23:26:58 wepl Exp wepl $
;  :History.	08.12.01 created
;		11.12.01 check if there is enough mfm data to decode
;		14.12.01 merged into wwarp sources (wepl)
;		02.11.02 rework for new sync-search
;		14.02.04 new decode/encode parameters and rework
;  :Requires.	OS V37+, MC68020+
;  :Language.	68020 Assembler
;  :Translator.	Barfly V2.9
;  :To Do.
;---------------------------------------------------------------------------*
; mfm-track structure
;
;   $448A448A,$5555555,$xxxxxxxx (checksum)
;   $AAAAAAA5 (checksum even)
;or $4AAAAAA5 (checksum odd)
;   $18A0 words mfm data
;------------------------------------------

		dc.l	_decode_pmover	;decode
		dc.l	_encode_pmover	;encode
		dc.l	0		;info
		dc.l	_name_pmover	;name
		dc.l	_sync_pmover	;sync
		dc.l	0		;density
		dc.w	0		;index
		dc.w	0		;speclen
		dc.w	$18A0		;datalen+checksum
		dc.w	($18A0*2)+16	;minimal rawlen
		dc.w	($18A0*2)+16	;writelen
		dc.w	TT_PMOVER	;type
		dc.w	0		;flags

_sync_pmover	dc.l	0,0,$448A448A,$55555555
		dc.l	0,0,$ffffffff,$FFFFFFFF

_name_pmover	dc.b	"primemover",0
		EVEN

;----------------------------------------
; decode psygnosis track (prime mover)
; IN:	D0 = ULONG length of raw mfm-data in bits
;	D1 = ULONG track number
;	D2 = ULONG offset in mfm buffer
;	A0 = APTR  mfm buffer (source)
;	A1 = APTR  decoded buffer (destination)
; OUT:	D0 = BOOL  true on success
;	all other regs may scratched

_decode_pmover

	;skip sync(448A448A) and unknown long word(55555555)
		addq.l	#8,a0
		move.l	d2,d6			;offset

	;decode track
		move.l	#$55555555,d2

		bfextu	(a0){d6:32},d0
		addq.l	#4,a0
		and.l	d2,d0
		move.w	d0,d1
		swap	d0
		add.w	d1,d1
		add.w	d0,d1
		move.w	d1,d4			;D4 = checksum decoded

		addq.l	#4,a0			;skip 4 bytes mfm

		move.w	#$18A0/2-1,d7
		moveq	#0,d3
.loop		bfextu	(a0){d6:32},d0
		addq.l	#4,a0
		swap	d0
		add.w	d0,d3
		swap	d0
		add.w	d0,d3			;D3 = checksum
		and.l	d2,d0
		move.w	d0,d1
		swap	d0
		add.w	d1,d1
		add.w	d0,d1
		move.w	d1,(a1)+
		dbf	d7,.loop
		cmp.w	d3,d4			;compare checksum
		bne	.no

		moveq	#-1,d0
		bra	.quit

.no		moveq	#0,d0

.quit		rts

;----------------------------------------
; encode psygnosis track
; IN:	D0 = ULONG track number
;	A0 = APTR  destination buffer
;	A1 = APTR  source data to encode
; OUT:	D0 = mfmdata length written, 0 means error
;	all other regs may scratched

_encode_pmover	move.l	#$55555555,d3

		move.l	#$448A448A,(a0)+	;4
		move.l	d3,(a0)+		;D3 = $55555555

		move.l	a0,-(sp)
		move.l	d3,d2			;skip checksum (it will be calculated later)
		bsr	_encode_long
		move.l	d3,d2
		bsr	_encode_long

		moveq	#0,d5
		move.w	#$18A0/2-1,d6
.data		move.w	(a1)+,d2
		move.w	d2,d0
		swap	d2
		lsr.w	#1,d0
		move.w	d0,d2
		bsr	_encode_long
		add.w	-4(a0),d5
		add.w	-2(a0),d5
		dbf	d6,.data

		move.l	(sp)+,a0

		move.w	d5,d2			;D5 = checksum
		swap	d2
		lsr.w	#1,d5
		move.w	d5,d2
		bsr	_encode_long		;4

		move.w	#$000A,d2
		btst	#0,-1(a0)
		beq	.even
		or.w	#$4000,d2
.even		move.w	d2,d0
		swap	d2
		lsr.w	#1,d0
		move.w	d0,d2
		bsr	_encode_long

		move.l	#($18A0*2)+16,d0
		rts
