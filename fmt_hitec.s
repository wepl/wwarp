;*---------------------------------------------------------------------------
;  :Program.	hitec.s
;  :Contents.	decode/encode custom track format for hi-tec games
;  :Author.	Codetapper
;  :Version	$Id: fmt_hitec.s 1.2 2005/04/07 23:34:02 wepl Exp wepl $
;  :History.	01.01.04 created
;		14.02.04 new decode/encode parameters and rework
;  :Requires.	OS V37+, MC68020+
;  :Language.	68020 Assembler
;  :Translator.	Barfly V2.9
;  :To Do.
;  :Info.	This format is used on Alien World, Blazing Thunder, Future
;		Bike Simulator, Hi-tec Hanna Barbera Cartoon Collection,
;		Jetsons, Scooby and Scrappy Doo...
;---------------------------------------------------------------------------*
; mfm-track structure
;
;   $xxxx (sync - one of 16 possible syncs)
;   $55555151
;   $180c/2 longs (odd then even) - 6 sectors of $400 bytes + word for next sector
;   $xxxxxxxx (odd checksum)
;   $xxxxxxxx (even checksum)
;------------------------------------------

		dc.l	_decode_hitec	;decode
		dc.l	_encode_hitec	;encode
		dc.l	_info_hitec	;info
		dc.l	_name_hitec	;name
		dc.l	_sync_hitec	;sync
		dc.l	0		;density
		dc.w	0		;index
		dc.w	2		;speclen (sync)
		dc.w	$180c		;datalen
		dc.w	($180c<<1)+14	;minimal rawlen
		dc.w	($180c<<1)+14	;writelen
		dc.w	TT_HITEC	;type
		dc.w	WWFF_MULTISYNC	;flags

_sync_hitec	dc.w	16		;sync count
		dc.l	0,0,$8944,$55555151
		dc.l	0,0,$ffff,$ffffffff
		dc.l	0,0,$4489,$55555151
		dc.l	0,0,$ffff,$ffffffff
		dc.l	0,0,$8912,$55555151
		dc.l	0,0,$ffff,$ffffffff
		dc.l	0,0,$2891,$55555151
		dc.l	0,0,$ffff,$ffffffff
		dc.l	0,0,$2251,$55555151
		dc.l	0,0,$ffff,$ffffffff
		dc.l	0,0,$5122,$55555151
		dc.l	0,0,$ffff,$ffffffff
		dc.l	0,0,$2245,$55555151
		dc.l	0,0,$ffff,$ffffffff
		dc.l	0,0,$4522,$55555151
		dc.l	0,0,$ffff,$ffffffff
		dc.l	0,0,$44a2,$55555151
		dc.l	0,0,$ffff,$ffffffff
		dc.l	0,0,$a244,$55555151
		dc.l	0,0,$ffff,$ffffffff
		dc.l	0,0,$448a,$55555151
		dc.l	0,0,$ffff,$ffffffff
		dc.l	0,0,$8a44,$55555151
		dc.l	0,0,$ffff,$ffffffff
		dc.l	0,0,$8914,$55555151
		dc.l	0,0,$ffff,$ffffffff
		dc.l	0,0,$4891,$55555151
		dc.l	0,0,$ffff,$ffffffff
		dc.l	0,0,$2291,$55555151
		dc.l	0,0,$ffff,$ffffffff
		dc.l	0,0,$9122,$55555151
		dc.l	0,0,$ffff,$ffffffff

_name_hitec	dc.b	"hitec",0
		EVEN

;----------------------------------------
; decode hitec track
; IN:	D0 = ULONG length of raw mfm-data in bits
;	D1 = ULONG track number
;	D2 = ULONG offset in mfm buffer
;	A0 = APTR  mfm buffer (source)
;	A1 = APTR  decoded buffer (destination)
; OUT:	D0 = BOOL  true on success
;	all other regs may scratched

_decode_hitec	move.l	d2,d6
		move.l	#$55555555,d2

	;save sync
		bfextu	(a0){d6:16},d0
		move.w	d0,(a1)+

	;skip sync
		add.l	#6,a0

		moveq	#0,d3			;d3 = Checksum
		move.l	#($180c>>2)-1,d7
.decode_loop	bfextu	(a0){d6:32},d0		;move.l	(a0)+,d0
		bfextu	(4,a0){d6:32},d1	;move.l	(a0)+,d1
		addq.l	#8,a0
		and.l	d2,d0
		and.l	d2,d1
		add.l	d0,d0
		or.l	d1,d0
		add.l	d0,d3			;adjust checksum
		move.l	d0,(a1)+
		dbf	d7,.decode_loop

		bfextu	(a0){d6:32},d0		;move.l	(a0)+,d0
		bfextu	(4,a0){d6:32},d1	;move.l	(a0)+,d1
		and.l	d2,d0
		and.l	d2,d1
		add.l	d0,d0
		or.l	d1,d0
		cmp.l	d0,d3			;compare checksum
		bne	.no

		moveq	#-1,d0
		bra	.quit

.no		moveq	#0,d0

.quit		rts

;----------------------------------------
; encode hitec track
; IN:	D0 = ULONG track number
;	A0 = APTR  destination buffer
;	A1 = APTR  source data to encode
; OUT:	D0 = mfmdata length written, 0 means error
;	all other regs may scratched

_encode_hitec	move.l	#$55555555,d3

		move.w	(a1)+,(a0)+		;2 (sync)
		move.l	#$55555151,(a0)+	;4

		moveq	#0,d5			;d5 = Checksum
		move.l	#($180c/4)-1,d6
.encode_data	move.l	(a1),d2
		add.l	d2,d5
		bsr	_encode_longodd		;$180c (odd data)
		move.l	(a1)+,d2
		bsr	_encode_long		;$180c (even data)
		dbf	d6,.encode_data

		move.l	d5,d2
		bsr	_encode_longodd		;4 (odd checksum)
		move.l	d5,d2
		bsr	_encode_long		;4 (even checksum)

		move.l	#2*$180c+14,d0
		rts

;----------------------------------------
; info hitec track
; IN:	A0 = track data
; OUT:	-

_info_hitec	move.l	a0,a1
		lea	(.txt),a0
		bra	_PrintArgs

.txt		dc.b	" sync=%x",0
	EVEN
