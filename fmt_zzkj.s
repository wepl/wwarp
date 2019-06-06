;*---------------------------------------------------------------------------
;  :Program.	fmt_zzkj.s
;  :Contents.	decode/encode custom track format "zzkj" ($1000 and $1600 bytes/track)
;  :Author.	Codetapper/Wepl
;  :Version	$Id: fmt_zzkj.s 1.4 2005/04/07 23:34:02 wepl Exp wepl $
;  :History.	25.09.02 created
;		08.11.02 rework for new sync-search
;		30.11.02 adapted, index sync aligment
;		11.03.04 new decode/encode parameters and rework
;  :Requires.	OS V37+, MC68020+
;  :Language.	68020 Assembler
;  :Translator.	Barfly V2.9
;  :To Do.
;---------------------------------------------------------------------------*
;
; format ZZKJ A:
;	Super Hang On highscores on track 1 only
;	format is written with index sync, but read routine doen't depend on it
;	44894489 2aaa <$808 odd bits> <$808 even bits>
;
; format ZZKJ B:
;	Super Hang On, Super Monaco GP, Smash TV each on track 2 only
;	the sync must be not more than $160 bytes after the index signal!!!
;	44894489 2aaa <$1008 odd bits> <$1008 even bits>
;
; format ZZKJ C:
;	Super Hang On each track 3...
;	the sync must be not more than $160 bytes after the index signal!!!
;	44894489 2aaaaaaa aaaaaaaa aaaaaaaa aaaaaaaa
;	44894489 2aaa <$1608 odd bits> <$1608 even bits>
;
; the data section contains
;	xxxxxxxx cylinder number
;	$800/$1000/$1600 byte data
;	xxxxxxxx checksum (which is added the cylinder number plus data)
;
; format ZZKJ D:
;	Super Monaco GP, Smash TV
; 11 sectors containing
;	44894489 2aaa <$208 odd bits> <$208 even bits> aaaa aaaaaaaa
; sector data contains
;	0000ccss cc=cylinder ss=sector
;	$200 byte data
;	xxxxxxxx checksum (which is added all the data)
; format is written with index sync, but read routine doen't depend on it
;
;----------------------------------------
; decode zzkj A/B/C track
; IN:	D0 = ULONG length of raw mfm-data in bits
;	D1 = ULONG track number
;	D2 = ULONG offset in mfm buffer
;	A0 = APTR  mfm buffer (source)
;	A1 = APTR  decoded buffer (destination)
; OUT:	D0 = BOOL  true on success
;	all other regs may scratched

_decode_zzkja	move.l	#$800,d4		;D4 = data length
		bra	_decode_zzkj_noidx

_decode_zzkjb	move.l	#$1000,d4		;D4 = data length
		bra	_decode_zzkj_idx

_decode_zzkjc	move.l	#$1600,d4		;D4 = data length
		bfextu	(16,a0){d2:32},d7
		cmp.l	#$aaaaaaaa,d7
		bne	_zzkj_no
		bfextu	(20,a0){d2:32},d7
		cmp.l	#$44894489,d7
		bne	_zzkj_no
		bfextu	(24,a0){d2:16},d7
		cmp.w	#$2aaa,d7
		bne	_zzkj_no
		add.w	#20,a0			;skip extra sync

_decode_zzkj_idx

	;check that sync is less than $160 bytes after sync
		cmp.l	#$160*8,d2
		bhs	_zzkj_no

_decode_zzkj_noidx

		move.l	d0,d5			;D5 = mfm-length
		move.l	d1,d3			;D3 = track number
		move.l	d2,d6			;D6 = offset

	;skip sync
		addq.l	#6,a0

	;decode track
		lea	(8,a0,d4.l),a2
		move.l	#$55555555,d2

		bsr	_zzkj_getlong
		lsr.l	#1,d3			;track -> cylinder
		cmp.l	d0,d3
		bne	.no

		move.l	d4,d7
		lsr.l	#2,d7
		subq.l	#1,d7
.decode		bsr	_zzkj_getlong
		move.l	d0,(a1)+
		add.l	d0,d3			;Adjust checksum
		dbf	d7,.decode

		bsr	_zzkj_getlong		;Read checksum and
		cmp.l	d3,d0			;compare with calculated
		bne	.no			;value

		moveq	#-1,d0
		rts

.no
_zzkj_no	moveq	#0,d0
		rts

_zzkj_getlong	bfextu	(a0){d6:32},d1
		bfextu	(a2){d6:32},d0
		addq.l	#4,a0
		addq.l	#4,a2
		and.l	d2,d0
		and.l	d2,d1
		add.l	d0,d0
		or.l	d1,d0
		rts

;----------------------------------------
; encode zzkj A/B/C track
; IN:	D0 = ULONG track number
;	A0 = APTR  destination buffer
;	A1 = APTR  source data to encode
; OUT:	D0 = mfmdata length written, 0 means error
;	all other regs may scratched


_encode_zzkja	move.l	#$800,d4		;D4 = data length
		bsr	_encode_zzkj
		move.l	#6+$808*2,d0
		rts

_encode_zzkjb	move.l	#$1000,d4		;D4 = data length
		bsr	_encode_zzkj
		move.l	#6+$1008*2,d0
		rts

_encode_zzkjc	move.l	#$1600,d4		;D4 = data length
		bsr	_encode_zzkj
		move.l	#26+$1608*2,d0
		rts

_encode_zzkj	move.l	d0,d5
		lsr.l	#1,d5			;D5 = cylinder number
		move.l	#$55555555,d3

	;calc checksum
		move.l	d5,d6			;D6 = checksum
		move.l	d4,d7
		lsr.l	#2,d7
		subq.l	#1,d7
.checksum	add.l	(a1)+,d6
		dbf	d7,.checksum
		sub.l	d4,a1

	;header
		cmp.l	#$1600,d4		;format C?
		bne	.skip
		move.l	#$44894489,(a0)+
		move.l	#$2aaaaaaa,(a0)+
		move.l	#$aaaaaaaa,(a0)+
		move.l	#$aaaaaaaa,(a0)+
		move.l	#$aaaaaaaa,(a0)+
.skip		move.l	#$44894489,(a0)+
		move.w	#$2aaa,(a0)+

		move.l	d5,d2			;cylinder
		bsr	_encode_long

		move.l	d4,d7
		lsr.l	#2,d7
		subq.l	#1,d7
.odd		move.l	(a1)+,d2
		bsr	_encode_long
		dbf	d7,.odd
		sub.l	d4,a1

		move.l	d6,d2			;checksum
		bsr	_encode_long

		move.l	d5,d2			;cylinder
		bsr	_encode_longodd

		move.l	d4,d7
		lsr.l	#2,d7
		subq.l	#1,d7
.even		move.l	(a1)+,d2
		bsr	_encode_longodd
		dbf	d7,.even

		move.l	d6,d2			;checksum
		bra	_encode_longodd

;----------------------------------------
; decode zzkj D track
; IN:	D0 = ULONG length of raw mfm-data in bits
;	D1 = ULONG track number
;	D2 = ULONG offset in mfm buffer
;	A0 = APTR  mfm buffer (source)
;	A1 = APTR  decoded buffer (destination)
; OUT:	D0 = BOOL  true on success
;	all other regs may scratched

_decode_zzkjd	move.l	d1,d3
		bclr	#0,d3
		lsl.l	#7,d3			;D3 = 0000ccss cylinder + sector number

		move.l	d2,d6			;D6 = offset

	;decode track
		move.l	#$55555555,d2

.sector		bfextu	(a0){d6:32},d0
		cmp.l	#$44894489,d0
		bne	.no
		bfextu	(4,a0){d6:16},d0
		cmp.w	#$2aaa,d0
		bne	.no
		addq.l	#6,a0

		lea	($208,a0),a2

		bsr	_zzkj_getlong
		cmp.l	d0,d3
		bne	.no
		move.l	d0,d4			;D4 = chksum

		move.l	#$200/4-1,d7
.decode		bsr	_zzkj_getlong
		move.l	d0,(a1)+
		add.l	d0,d4
		dbf	d7,.decode

		bsr	_zzkj_getlong		;Read checksum and
		cmp.l	d4,d0			;compare with calculated
		bne	.no			;value

		add.l	#6+$208,a0

		addq.b	#1,d3			;next sector
		cmp.b	#11,d3
		bne	.sector

		moveq	#-1,d0
		rts

.no		moveq	#0,d0
		rts

;----------------------------------------
; encode zzkj D track ($1600 bytes/track)
; IN:	D0 = ULONG track number
;	A0 = APTR  destination buffer
;	A1 = APTR  source data to encode
; OUT:	D0 = mfmdata length written, 0 means error
;	all other regs may scratched

_encode_zzkjd	move.l	d0,d6
		bclr	#0,d6
		lsl.l	#7,d6			;D6 = 0000ccss cylinder + sector number
		move.l	#$55555555,d3

.sector		move.l	#$44894489,(a0)+	;4
		move.w	#$2aaa,(a0)+		;2

		move.l	d6,d4
		move.l	#$200/4-1,d7
.checksum	add.l	(a1)+,d4		;D4 = chksum
		dbf	d7,.checksum
		sub.w	#512,a1

		move.l	d6,d2
		bsr	_encode_long		;4
		move.l	#$200/4-1,d7
.odd		move.l	(a1)+,d2
		bsr	_encode_long		;$200
		dbf	d7,.odd
		sub.w	#512,a1
		move.l	d4,d2
		bsr	_encode_long		;4

		move.l	d6,d2
		bsr	_encode_longodd		;4
		move.l	#$200/4-1,d7
.even		move.l	(a1)+,d2
		bsr	_encode_longodd		;$200
		dbf	d7,.even
		move.l	d4,d2
		bsr	_encode_longodd		;4

		moveq	#0,d2
		bsr	_encode_long		;4 (sector gap)
		moveq	#0,d2
		bsr	_encode_word		;2 (sector gap)

		addq.b	#1,d6
		cmp.b	#11,d6
		bne	.sector

		move.l	#11*(6+$410+6),d0
		rts
