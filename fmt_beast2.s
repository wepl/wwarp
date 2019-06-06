;*---------------------------------------------------------------------------
;  :Program.	fmt_beast2.s
;  :Contents.	decode/encode custom track format "Beast 2" (Psygnosis)
;  :Author.	Psygore
;  :Version	$Id: fmt_beast2.s 1.7 2005/04/07 23:25:25 wepl Exp wepl $
;  :History.	14.12.01 merged into wwarp sources (wepl)
;		02.11.02 rework for new sync-search
;		14.02.04 new decode/encode parameters and rework
;		11.03.05 return value for encoder fixed (w->l)
;  :Requires.	OS V37+, MC68020+
;  :Language.	68020 Assembler
;  :Translator.	Barfly V2.9
;  :To Do.
;---------------------------------------------------------------------------*
; mfm-track structure
;
; $4489 sync
; "BST2" mfm encoded
; $189C*2 bytes of mfm data
; no checksum track!
;----------------------------------------

		dc.l	_decode_beast2	;decode
		dc.l	_encode_beast2	;encode
		dc.l	0		;info
		dc.l	_name_beast2	;name
		dc.l	_sync_beast2	;sync
		dc.l	0		;density
		dc.w	0		;index
		dc.w	0		;speclen
		dc.w	$189C		;datalen
		dc.w	2+8+($189c*2)	;minimal rawlen
		dc.w	2+8+($189c*2)	;writelen
		dc.w	TT_BEAST2	;type
		dc.w	0		;flags

_sync_beast2	dc.l	0,$4489,$29292a91,$4a515492
		dc.l	0,$ffff,$ffffffff,$ffffffff

_name_beast2	dc.b	"beast2",0
		EVEN

;----------------------------------------
; decode psygnosis track (beast 2)
; IN:	D0 = ULONG length of raw mfm-data in bits
;	D1 = ULONG track number
;	D2 = ULONG offset in mfm buffer
;	A0 = APTR  mfm buffer (source)
;	A1 = APTR  decoded buffer (destination)
; OUT:	D0 = BOOL  true on success
;	all other regs may scratched

_decode_beast2	add.l	#10,a0			;skip sync

		move.w	#$189c/4-1,d7
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
; encode psygnosis track (beast 2)
; IN:	D0 = ULONG track number
;	A0 = APTR  destination buffer
;	A1 = APTR  source data to encode
; OUT:	D0 = mfmdata length written, 0 means error
;	all other regs may scratched

_encode_beast2	move.l	#$55555555,d3

		move.w	#$4489,(a0)+		;2

		move.l	#"BST2",d4		;encode "BST2"
		move.l	d4,d2
		bsr	_encode_longodd		;4
		move.l	d4,d2
		bsr	_encode_long		;4

		moveq	#0,d5
		move.w	#$189c/4-1,d6
.data		move.l	(a1)+,d4
		move.l	d4,d2
		bsr	_encode_longodd
		move.l	d4,d2
		bsr	_encode_long
		dbf	d6,.data

		move.l	#2+8+($189c*2),d0
		rts
