;*---------------------------------------------------------------------------
;  :Program.	fmt_beast1.s
;  :Contents.	decode/encode custom track format "Beast 1" (Psygnosis)
;  :Author.	Psygore
;  :Version.	$Id: fmt_beast1.s 1.7 2005/04/07 23:25:25 wepl Exp wepl $
;  :History.	14.12.01 merged into wwarp sources (wepl)
;		02.11.02 rework for new sync-search
;		13.02.04 new decode/encode parameters and rework
;		11.03.05 return value for encoder fixed (w->l)
;  :Requires.	OS V37+, MC68020+
;  :Language.	68020 Assembler
;  :Translator.	Barfly V2.9
;  :To Do.
;---------------------------------------------------------------------------*
; mfm-track structure
;   $4489 sync
;   "SOTB" mfm encoded
;   $1838*2 bytes of mfm data
; no checksum track!
;----------------------------------------

		dc.l	_decode_beast1	;decode
		dc.l	_encode_beast1	;encode
		dc.l	0		;info
		dc.l	_name_beast1	;name
		dc.l	_sync_beast1	;sync
		dc.l	0		;density
		dc.w	0		;index
		dc.w	0		;speclen
		dc.w	$1838		;datalen
		dc.w	2+8+($1838*2)	;minimal rawlen
		dc.w	2+8+($1838*2)	;writelen
		dc.w	TT_BEAST1	;type
		dc.w	0		;flags

_sync_beast1	dc.l	0,$4489,$29252aa9,$5145544a
		dc.l	0,$ffff,$ffffffff,$ffffffff

_name_beast1	dc.b	"beast1",0
		EVEN

;----------------------------------------
; decode psygnosis track (beast 1)
; IN:	D0 = ULONG length of raw mfm-data in bits
;	D1 = ULONG track number
;	D2 = ULONG offset in mfm buffer
;	A0 = APTR  mfm buffer (source)
;	A1 = APTR  decoded buffer (destination)
; OUT:	D0 = BOOL  true on success
;	all other regs may scratched

_decode_beast1	add.l	#10,a0			;skip sync

		move.w	#$1838/4-1,d7
		move.l	#$55555555,d3
.loop		bfextu	(a0){d2:32},d0
		addq.l	#4,a0
		bfextu	(a0){d2:32},d1
		addq.l	#4,a0
		and.l	d3,d0
		and.l	d3,d1
		add.l	d0,d0
		or.l	d1,d0
		move.l	d0,(a1)+
		dbf	d7,.loop

		moveq	#-1,d0
		rts

;----------------------------------------
; encode psygnosis track (beast 1)
; IN:	D0 = ULONG track number
;	A0 = APTR  destination buffer
;	A1 = APTR  source data to encode
; OUT:	D0 = mfmdata length written, 0 means error
;	all other regs may scratched

_encode_beast1	move.l	#$55555555,d3

		move.w	#$4489,(a0)+		;2

		move.l	#"SOTB",d4		;encode "SOTB"
		move.l	d4,d2
		bsr	_encode_longodd		;4
		move.l	d4,d2
		bsr	_encode_long		;4

		moveq	#0,d5
		move.w	#$1838/4-1,d6
.data		move.l	(a1)+,d4
		move.l	d4,d2
		bsr	_encode_longodd
		move.l	d4,d2
		bsr	_encode_long
		dbf	d6,.data

		move.l	#2+8+($1838*2),d0
		rts
