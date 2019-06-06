;*---------------------------------------------------------------------------
;  :Program.	fmt_psygnosis1.s
;  :Contents.	decode/encode custom track format psygnosis1 (Beast3, Lemmings...)
;  :Author.	Psygore
;  :Version	$Id: fmt_psygnosis1.s 1.5 2005/04/07 23:34:02 wepl Exp wepl $
;  :History.	15.14.02 created
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
;   $552AAAAA (unused)
; 6 sectors x (2 mfm-words (checksum) + $400 mfm-words data)
;------------------------------------------

		dc.l	_decode_psygnosis1	;decode
		dc.l	_encode_psygnosis1	;encode
		dc.l	0			;info
		dc.l	_name_psygnosis1	;name
		dc.l	_sync_psygnosis1	;sync
		dc.l	0			;density
		dc.w	0			;index
		dc.w	0			;speclen
		dc.w	$1800			;datalen
		dc.w	6+($402*6*2)		;minimal rawlen
		dc.w	6+($402*6*2)		;writelen
		dc.w	TT_PSYGNOSIS1		;type
		dc.w	0			;flags

_sync_psygnosis1 dc.l	0,0,$4489,$552AAAAA
		dc.l	0,0,$ffff,$ffffffff

_name_psygnosis1
		dc.b	"psygnosis1",0
		EVEN

;----------------------------------------
; decode psygnosis1 track
; IN:	D0 = ULONG length of raw mfm-data in bits
;	D1 = ULONG track number
;	D2 = ULONG offset in mfm buffer
;	A0 = APTR  mfm buffer (source)
;	A1 = APTR  decoded buffer (destination)
; OUT:	D0 = BOOL  true on success
;	all other regs may scratched

_decode_psygnosis1

	;skip sync(4489) and unknown word(552AAAAA)
		add.w	#6,a0
		move.l	d2,d6			;offset

	;decode track
		move.l	#$55555555,d2
		moveq	#6-1,d3			;D3 = 6 sectors
.track		bfextu	(a0){d6:32},d0
		addq.l	#4,a0
		and.l	d2,d0
		move.w	d0,d1
		swap	d0
		add.w	d0,d0
		or.w	d1,d0
		move.w	d0,d5			;D5 = checksum

		moveq	#0,d4
		move.w	#$400/2-1,d7
.sector		bfextu	(a0){d6:32},d0
		addq.l	#4,a0
		and.l	d2,d0
		move.w	d0,d1
		swap	d0
		add.w	d0,d0
		or.w	d1,d0
		move.w	d0,(a1)+
		add.w	d0,d4
		dbf	d7,.sector
		cmp.w	d4,d5
		bne	.no
		dbf	d3,.track

		moveq	#-1,d0
		bra	.quit

.no		moveq	#0,d0

.quit		rts

;----------------------------------------
; encode psygnosis1 track
; IN:	D0 = ULONG track number
;	A0 = APTR  destination buffer
;	A1 = APTR  source data to encode
; OUT:	D0 = mfmdata length written, 0 means error
;	all other regs may scratched

_encode_psygnosis1
		move.l	#$55555555,d3

		move.w	#$4489,(a0)+		;2
		move.l	#$552AAAAA,(a0)+	;4

		moveq	#6-1,d6
.track		move.w	#$400/2-1,d1
		moveq	#0,d0
.1		add.w	(a1)+,d0
		dbf	d1,.1
		sub.w	#$400,a1
		move.w	d0,d2
		lsr.w	#1,d2
		swap	d2
		move.w	d0,d2
		bsr	_encode_long		;4

		move.w	#$400/2-1,d5
.sector		move.w	(a1)+,d0
		move.w	d0,d2
		lsr.w	#1,d2
		swap	d2
		move.w	d0,d2
		bsr	_encode_long
		dbf	d5,.sector
		dbf	d6,.track

		move.l	#6+($402*6*2),d0
		rts
