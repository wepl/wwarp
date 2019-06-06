;*---------------------------------------------------------------------------
;  :Program.	fmt_robnorthen.s
;  :Contents.	decode/encode rob northen tracks (PDOS)
;  :Author.	Wepl
;  :Version	$Id: fmt_robnorthen.s 1.4 2005/04/07 23:24:21 wepl Exp wepl $
;  :History.	11.11.02 separated from formats.s
;		12.02.04 info added
;		14.02.04 new decode/encode parameters and rework
;  :Requires.	OS V37+, MC68020+
;  :Language.	68020 Assembler
;  :Translator.	Barfly V2.9
;  :To Do.
;  :Info.	examples AlienBreed2, BodyBlows, MortalKombat, ProjectXSE,
;		ArcadePool, SuperFrog
;---------------------------------------------------------------------------*
; rob northen disk format:
;	0	1448		track header sync
;	now following 12 sectors:
;	0	4891		sync word
;	2	xxxxxxxx	mfm odd  bits \ eor.l with (diskkey|$80000000)
;	6	xxxxxxxx	mfm even bits / sector-number.b track-number.b sector-chksum.w
;	$a	$200 byte	mfm odd  bit data
;	$20a	$200 byte	mfm even bit data
;	$40a	xxxx		mfm encoded byte which is the length of the inter sector gap
;----------------------------------------
; decode rob track
; IN:	D0 = ULONG length of raw mfm-data in bits
;	D1 = ULONG track number
;	D2 = ULONG offset in mfm buffer
;	A0 = APTR  mfm buffer (source)
;	A1 = APTR  decoded buffer (destination)
; OUT:	D0 = BOOL  true on success
;	all other regs may scratched

	NSTRUCTURE	locals_decoderob,0
		NLONG	lcdr_mfmbuf
		NLONG	lcdr_bitsleft		;remaining bits in mfm buffer
		NWORD	lcdr_chksum		;sector chksum
		NWORD	lcdr_trknum		;track number
		NALIGNLONG
		NLABEL	lcdr_SIZEOF

_decode_rob	link	LOC,#lcdr_SIZEOF

		move.l	d0,(lcdr_bitsleft,LOC)
		move.w	d1,(lcdr_trknum,LOC)
		move.l	d2,d6			;D6 = offset
		move.l	a0,(lcdr_mfmbuf,LOC)

	;skip sync 1448
		add.l	#16,d6
		sub.l	#16,(lcdr_bitsleft,LOC)

	;calculate disk key
		add.w	#10,a0			;skip sector header
		moveq	#0,d1
		move.w	#1024/4-1,d7
.chksum		bfextu	(a0){d6:32},d0
		addq.l	#4,a0
		eor.l	d0,d1
		dbf	d7,.chksum
		move.l	#$55555555,d2		;D2 = 55555555
		and.l	d2,d1
		move.l	d1,d5
		swap	d5
		add.w	d5,d5
		or.w	d1,d5
		swap	d5
		move.w	(lcdr_trknum,LOC),d5	;sector=0
		swap	d5
		move.l	(lcdr_mfmbuf,LOC),a0	;A0 = mfm buffer
		bfextu	(2,a0){d6:32},d0
		bfextu	(6,a0){d6:32},d1
		and.l	d2,d0
		and.l	d2,d1
		add.l	d0,d0
		or.l	d1,d0
		eor.l	d0,d5			;D5 = diskkey|$80000000

		move.l	d5,(a1)+

	;decode 12 sectors
		moveq	#0,d7			;D7 = actual sector

.sector		cmp.l	#$40c*8,(lcdr_bitsleft,LOC)
		blo	.no
		bfextu	(a0){d6:16},d0
		cmp.w	#$4891,d0
		bne	.no
		addq.w	#2,a0
		bfextu	(a0){d6:32},d0
		addq.w	#4,a0
		bfextu	(a0){d6:32},d1
		addq.w	#4,a0
		and.l	d2,d0
		and.l	d2,d1
		add.l	d0,d0
		or.l	d1,d0
		eor.l	d5,d0
		move.w	d0,(lcdr_chksum,LOC)
		swap	d0
		cmp.b	(lcdr_trknum+1,LOC),d0
		bne	.no
		lsr.w	#8,d0
		cmp.b	d7,d0			;sector number
		bne	.no

		moveq	#512/4-1,d3
		moveq	#0,d4

		bclr	#31,d5

.dec		bfextu	(a0){d6:32},d0
		bfextu	($200,a0){d6:32},d1
		eor.l	d0,d4
		and.l	d2,d0
		eor.l	d1,d4
		and.l	d2,d1
		add.l	d0,d0
		addq.w	#4,a0
		or.l	d1,d0
		eor.l	d5,d0
		move.l	d0,(a1)+
		dbf	d3,.dec

		bset	#31,d5

		and.l	d2,d4
		move.l	d4,d0
		swap	d4
		add.w	d4,d4
		or.w	d4,d0
		cmp.w	(lcdr_chksum,LOC),d0
		bne	.no

		add.w	#$200,a0

		bfextu	(a0){d6:16},d0
		moveq	#0,d1
		moveq	#7,d3
.gap		roxl.w	#2,d0
		roxl.b	#1,d1
		dbf	d3,.gap

		lea	(2,a0,d1.w*2),a0	;sector gap

		lsl.l	#4,d1
		add.l	#$40c*8,d1
		sub.l	d1,(lcdr_bitsleft,LOC)
		bcs	.no

		addq.w	#1,d7
		cmp.w	#12,d7
		bne	.sector

		moveq	#-1,d0
		bra	.quit

.no		moveq	#0,d0

.quit		unlk	LOC
		rts

;----------------------------------------
; encode rob track
; IN:	D0 = ULONG track number
;	A0 = APTR  destination buffer
;	A1 = APTR  source data to encode
; OUT:	D0 = mfmdata length written, 0 means error
;	all other regs may scratched

_encode_rob	move.l	#$55555555,d3
		move.w	d0,a3			;A3 = track number
		move.l	(a1)+,d6		;D6 = diskkey

		move.w	#$1448,(a0)+		;2

		moveq	#0,d7			;D7 = sector

.sector		move.w	#$4891,(a0)+		;2

		move.l	a1,a2
		moveq	#512/4-1,d2
		moveq	#0,d4
.chksum		move.l	(a2)+,d0
		eor.l	d0,d4
		dbf	d2,.chksum

		move.l	d4,d0
		lsr.l	#1,d0
		eor.l	d0,d4
		and.l	d3,d4
		move.l	d4,d0
		swap	d0
		add.w	d0,d0
		or.w	d0,d4			;chksum

		move.b	d7,d2			;sector
		lsl.w	#8,d2
		add.l	a3,d2			;track
		swap	d2
		move.w	d4,d2			;chksum
		eor.l	d6,d2			;diskkey

		move.l	d2,d4
		bsr	_encode_longodd		;4
		move.l	d4,d2
		bsr	_encode_long		;4

		bclr	#31,d6

		move.l	a1,a2
		moveq	#512/4-1,d4
.odd		move.l	(a2)+,d2
		eor.l	d6,d2
		bsr	_encode_longodd		;$200
		dbf	d4,.odd

		moveq	#512/4-1,d4
.even		move.l	(a1)+,d2
		eor.l	d6,d2
		bsr	_encode_long		;$200
		dbf	d4,.even

		bset	#31,d6

		move.w	#$aaaa,d0
		btst	#0,-1(a0)
		beq	.ok
		bclr	#15,d0
.ok		move.w	d0,(a0)+		;2

		addq.w	#1,d7
		cmp.w	#12,d7
		bne	.sector

		move.l	#2+(12*$40c),d0
		rts

;----------------------------------------
; info rob track
; IN:	A0 = track data
; OUT:	-

_info_rob	move.l	a0,a1
		lea	(.txt),a0
		bra	_PrintArgs

.txt		dc.b	" diskkey=%lx",0
	EVEN
