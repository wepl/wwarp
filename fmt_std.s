;*---------------------------------------------------------------------------
;  :Program.	fmt_std.s
;  :Contents.	decode standard dos track
;  :Author.	Wepl
;  :Version	$Id: fmt_std.s 1.9 2020/03/14 14:10:32 wepl Exp wepl $
;  :History.	11.11.02 separated from formats.s
;		12.11.02 optimized
;		20.02.04 new decode/encode parameters and rework
;		04.11.04 changes for rnclold support
;		12.01.07 wrong comments for odd/even exchanged
;  :Requires.	OS V37+, MC68020+
;  :Language.	68020 Assembler
;  :Translator. Barfly V2.9
;  :To Do.
;  :Info.
;---------------------------------------------------------------------------*
; $000 word	2	MFM value 0xAAAA AAAA (used for timing ?)
; $004 word	1	MFM value 0x4489
; $006 word	1	MFM value 0x4489
; $008 long	1	info (odd bits)
; $00c long	1	info (even bits)
;		decoded long is : ff TT SS SG
;			TT = track number ( 3 means cylinder 1, head 1)
;			SS = sector number ( 0 upto 10/21 ) sectors are not ordered !!!
;			SG = number of sectors before gap (including current one)
;		Example for cylinder 0, head 1 of a DD disk :
;			ff010009
;			ff010108
;			ff010207
;			ff010306
;			ff010405
;			ff010504
;			ff010603
;			ff010702
;			ff010801
;				-- inter-sector-gap here !
;			ff01090b (b means -1 ?)
;			ff010a0a (a means -2 ?)
; $010 long	4	sector label (odd)
; $020 long	4	sector label (even)
;			decoded value seems to be always 0
; $030 long	1	header checksum (odd)
; $034 long	1	header checksum (even)
;		computed on mfm longs between offsets 8 and $30, 2*(1+4) longs
; $038 long	1	data checksum (odd)
; $03c long	1	data checksum (even)
; $040 long	512	coded data (odd)
; $240 long	512	coded data (even)
; $440
;----------------------------------------
; decode standard amigados track
; IN:	D0 = ULONG length of raw mfm-data in bits
;	D1 = ULONG track number
;	D2 = ULONG offset in mfm buffer
;	A0 = APTR  mfm buffer (source)
;	A1 = APTR  decoded buffer (destination)
; OUT:	D0 = BOOL  true on success
;	all other regs may scratched

	NSTRUCTURE	locals_decodedos,0
		NWORD	lc1_trknum
		NALIGNLONG
		NLABEL	lc1_SIZEOF

_decode_std	link	LOC,#lc1_SIZEOF

		or.w	#$ff00,d1
		move.w	d1,(lc1_trknum,LOC)

		move.l	d0,d5			;D5 = mfm-length
		move.l	a0,a2			;A2 = mfm-buffer
		move.l	a1,a3			;A3 = dest-buffer

	;fast check for standard dos track
		move.l	#$55555555,d4		;D4 = mfm decode
	;check first word of info
		bfextu	(4,a0){d2:16},d0
		bfextu	(8,a0){d2:16},d7
		and.w	d4,d0
		and.w	d4,d7
		add.w	d0,d0
		or.w	d7,d0
		cmp.w	d0,d1
		bne	.no
	;check sector labels, all must be cleared
		moveq	#7,d7
.lblchk		bfextu	(12,a0,d7.l*4){d2:32},d0
		and.l	d4,d0
		dbne	d7,.lblchk
		bne	.no

	;check if track is the last before inter sector gap
		bfextu	($440,a0){d2:32},d0
		cmp.l	#$44894489,d0
		beq	.no

	;search first track after inter sector gap
		move.l	d2,d0
		addq.l	#1,d0			;offset
		move.l	d5,d1			;buffer length
		lea	(_sync_std),a1		;44894489...
		bsr	_searchsync
		tst.l	d0
		bmi	.no

	;d2 = last sector before gap
	;d0 = first sector after gap
		move.l	d0,d6			;D6 = first sector after gap

	;check that inter sector gap is set to all zeros
		move.l	a2,a0
		sub.l	d2,d0			;sub start of last sector before gap
		sub.l	#($440-4)*8+33,d0	;length of gap in bits to check
		bmi	.no
		move.l	#$aaaaaaaa,d3
		bra	.cmpin
.cmp		bfextu	(a0){d6:32},d1
		cmp.l	d1,d3
		bne	.no
.cmpin		subq.l	#4,a0
		sub.l	#32,d0
		bcc	.cmp
		bfextu	(a0){d6:32},d1
		neg.l	d0
		lsl.l	d0,d1
		lsl.l	d0,d3
		cmp.l	d1,d3
		bne	.no

	;decode track
		move.l	#%11111111111,d4	;D4 = sectors
		move.l	#$55555555,d5		;D5 = mfm decode
		moveq	#11-1,d7		;D7 = sector loop count
		move.l	a2,a0			;A0 = mfm buffer
		subq.l	#4,a0			;first $aaaaaaaa

.sector		bsr	_getlw
		bclr	#31,d0
		cmp.l	#$2aaaaaaa,d0
		bne	.no
		bsr	_getlw
		cmp.l	#$44894489,d0
		bne	.no

		moveq	#0,d3			;D3 = chksum

		bsr	_getlwd			;sector header

		subq.b	#1,d0			;num sectors before gap
		cmp.b	d7,d0
		bne	.no

		lsr.l	#8,d0			;D0.b = sector number 0..10
		cmp.b	#10,d0
		bhi	.no
		bclr	d0,d4
		beq	.no			;same sector again
		moveq	#0,d1
		move.b	d0,d1
		mulu	#$200,d1
		lea	(a3,d1.l),a1		;A1 = decode destination

		lsr.l	#8,d0			;D0.w = format + track number
		cmp.w	(lc1_trknum,LOC),d0
		bne	.no

	;the sector labels, 4 longs decoded
		moveq	#3,d2
.label		bfextu	(a0){d6:32},d0
		bfextu	(16,a0){d6:32},d1
		eor.l	d0,d3
		eor.l	d1,d3
		and.l	d5,d0
		bne	.no
		and.l	d5,d1
		bne	.no
		addq.l	#4,a0
		dbf	d2,.label
		add.w	#16,a0

		move.l	d3,d2
		and.l	d5,d2
		bsr	_getlwd			;header chksum
		cmp.l	d2,d0
		bne	.no

		bsr	_getlwd			;data chksum
		move.l	d0,d3

	;the sector data
		moveq	#$200/4-1,d2
.data		bfextu	(a0){d6:32},d0
		bfextu	($200,a0){d6:32},d1
		eor.l	d0,d3
		and.l	d5,d0
		eor.l	d1,d3
		and.l	d5,d1
		add.l	d0,d0
		addq.l	#4,a0
		or.l	d0,d1
		move.l	d1,(a1)+
		dbf	d2,.data
		add.w	#$200,a0

		and.l	d5,d3
		bne	.no

		dbf	d7,.sector

		moveq	#-1,d0
		bra	.quit

.no		moveq	#0,d0

.quit		unlk	LOC
		rts

;----------------------------------------
; force decode standard amigados track
; IN:	D0 = ULONG length of raw mfm-data in bits
;	D1 = ULONG track number
;	D2 = ULONG offset in mfm buffer
;	A0 = APTR  mfm buffer (source)
;	A1 = APTR  decoded buffer (destination)
; OUT:	D0 = BOOL  true on success
;	all other regs may scratched

_decode_stdf	bsr	_trkchk_rnclold		;check if there are extra data of rnclold
		bne	_decode_stdf_no
_decode_stdf_nochk

	;decode track
		move.l	#%11111111111,d4	;D4 = sectors (0 means already decoded)
		move.l	#$55555555,d5		;D5 = mfm decode mask
		move.l	d2,d6			;D6 = offset
		moveq	#11-1,d7		;D7 = sector loop count
		move.l	a0,a2			;A2 = mfm-buffer
		move.l	a1,a3			;A3 = dest-buffer
		move.l	d0,a6			;A6 = mfm length

		bra	.in

.sector

	;search sync
		move.l	d6,d0			;offset
		move.l	a6,d1			;buflen
		move.l	a2,a0			;buffer
		lea	(_sync_stdf),a1		;sync
		bsr	_searchsync
		move.l	d0,d6			;D6 = offset
		bmi	.no

	;check that remaining mfm data is sufficent
.in		move.l	a6,d0
		sub.l	d6,d0			;in bits
		cmp.l	#$43c*8,d0
		blo	.no

		move.l	a2,a0			;A0 = mfm buffer
		addq.l	#4,a0			;skip $44894489

		bsr	_getlwd			;sector header

		lsr.l	#8,d0			;sector number 0..10
		cmp.b	#10,d0
		bhi	.no
		bclr	d0,d4
		beq	.no			;same sector again
		moveq	#0,d1
		move.b	d0,d1
		mulu	#$200,d1
		lea	(a3,d1.l),a1 		;A1 = dest buffer

		add.w	#32+8,a0		;skip sector label + chksum

		bsr	_getlwd			;data chksum
		move.l	d0,d3

		moveq	#$200/4-1,d2
.data		bfextu	(a0){d6:32},d0
		bfextu	($200,a0){d6:32},d1
		eor.l	d0,d3
		and.l	d5,d0
		eor.l	d1,d3
		and.l	d5,d1
		add.l	d0,d0
		addq.l	#4,a0
		or.l	d0,d1
		move.l	d1,(a1)+
		dbf	d2,.data

		and.l	d5,d3
		bne	.no

		add.l	#$43c*8,d6
		dbf	d7,.sector

		moveq	#-1,d0
		rts
.no
_decode_stdf_no
		moveq	#0,d0
		rts

;----------------------------------------

_getlw		bfextu	(a0){d6:32},d0
		addq.l	#4,a0
		eor.l	d0,d3
		rts

;----------------------------------------

_getlwd		bsr	_getlw
		move.l	d0,d1
		bsr	_getlw
		and.l	d5,d1
		and.l	d5,d0
		add.l	d1,d1
		or.l	d1,d0
		rts
