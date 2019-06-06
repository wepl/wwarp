;*---------------------------------------------------------------------------
;  :Program.	fmt_bloodmoney.s
;  :Contents.	decode/encode custom track format "Blood Money" (Psygnosis)
;  :Author.	Psygore
;  :Version	$Id: fmt_bloodmoney.s 1.5 2005/04/07 23:25:25 wepl Exp wepl $
;  :History.	16.14.02 created
;		02.11.02 rework for new sync-search
;		14.02.04 new decode/encode parameters and rework
;  :Requires.	OS V37+, MC68020+
;  :Language.	68020 Assembler
;  :Translator.	Barfly V2.9
;  :To Do.
;---------------------------------------------------------------------------*
; mfm-track structure
;
;   $4489 (sync)
;   $552A2A55 (unused)
;   $1838 mfm-words (data)
;   2 mfm-words (checksum)
;------------------------------------------

		dc.l	_decode_bloodmoney	;decode
		dc.l	_encode_bloodmoney	;encode
		dc.l	0			;info
		dc.l	_name_bloodmoney	;name
		dc.l	_sync_bloodmoney	;sync
		dc.l	0			;density
		dc.w	0			;index
		dc.w	0			;speclen
		dc.w	$1838			;datalen
		dc.w	6+($1838*2)+4		;minimal rawlen
		dc.w	6+($1838*2)+4		;writelen
		dc.w	TT_BLOODMONEY		;type
		dc.w	0			;flags

_sync_bloodmoney dc.l	0,0,$4489,$552A2A55
		dc.l	0,0,$ffff,$ffffffff

_name_bloodmoney
		dc.b	"bloodmoney",0
		EVEN

;----------------------------------------
; decode blood money track
; IN:	D0 = ULONG length of raw mfm-data in bits
;	D1 = ULONG track number
;	D2 = ULONG offset in mfm buffer
;	A0 = APTR  mfm buffer (source)
;	A1 = APTR  decoded buffer (destination)
; OUT:	D0 = BOOL  true on success
;	all other regs may scratched

_decode_bloodmoney
		move.l	d0,d5			;D5 = mfm-length
		move.l	d1,d3
		lsr.w	#1,d3			;D3 = track number/2

	;skip sync(4489) and unknown word(552A2A55)
		addq.l	#6,a0
		move.l	d2,d6			;offset

	;decode track
		move.l	#$55555555,d2
		moveq	#0,d4
		move.w	#$1838/2-1,d7
.decode		bfextu	(a0){d6:32},d0
		addq.l	#4,a0
		and.l	d2,d0
		move.w	d0,d1
		swap	d0
		add.w	d0,d0
		or.w	d1,d0
		eor.w	d3,d0
		move.w	d0,(a1)+
		add.w	d0,d4			;D4 = sector checksum
		dbf	d7,.decode

	;decode checksum
		bfextu	(a0){d6:32},d0
		addq.l	#4,a0
		and.l	d2,d0
		move.w	d0,d1
		swap	d0
		add.w	d0,d0
		or.w	d1,d0
		eor.w	d3,d0			;D0 = checksum
		cmp.w	d0,d4
		bne	.no

		moveq	#-1,d0
		bra	.quit

.no		moveq	#0,d0

.quit		rts

;----------------------------------------
; encode Blood Money track
; IN:	D0 = ULONG track number
;	A0 = APTR  destination buffer
;	A1 = APTR  source data to encode
; OUT:	D0 = mfmdata length written, 0 means error
;	all other regs may scratched

_encode_bloodmoney
		move.l	#$55555555,d3
		move.l	d0,d4
		lsr.w	#1,d4			;D4 = track number/2

		move.w	#$4489,(a0)+		;2
		move.l	#$552A2A55,(a0)+	;4

		moveq	#0,d5
		move.w	#$1838/2-1,d6
.encode		move.w	(a1)+,d0
		add.w	d0,d5			;D5 = checksum
		eor.w	d4,d0
		move.w	d0,d2
		lsr.w	#1,d2
		swap	d2
		move.w	d0,d2
		bsr	_encode_long
		dbf	d6,.encode

	;encode checksum
		eor.w	d4,d5
		move.w	d5,d2
		lsr.w	#1,d2
		swap	d2
		move.w	d5,d2
		bsr	_encode_long		;4

		move.l	#6+($1838*2)+4,d0
		rts
