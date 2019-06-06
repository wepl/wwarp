;*---------------------------------------------------------------------------
;  :Program.	fmt_rncopylock.s
;  :Contents.	decode/encode rob northen copylock
;  :Author.	Wepl
;  :Version.	$Id: fmt_rncopylock.s 1.4 2005/04/07 23:35:14 wepl Exp wepl $
;  :History.	09.02.04 started
;		12.02.04 adapted Codetapper's CopyLockSync.s
;		14.02.04 new decode/encode parameters and rework
;		23.03.04 density made
;		24.03.05 cosmetic changes, some bytes code saved
;  :Requires.	OS V37+, MC68020+
;  :Language.	68020 Assembler
;  :Translator.	Barfly V2.9
;  :To Do.
;  :Info.	examples see CopyLockDecoder
;---------------------------------------------------------------------------*
; rob northen copylock format:
; - its always on track 1
; - it contains 11 sectors each 4 byte sync and $400 byte mfm data
;   (although the copylock check reads only 4 + $3ff)
; - the copylock check routine only checks 4 of these sectors
; REMARK: the sector numbering is arbitrariness and taken from the game
;	  Rick Dangerous with assumed INDEX
;
;		8912 aa92	sector 5 less time ($3080)
;		$3fe bytes	data
;
;		8911 2a91	sector 6 normal time ($3100)
;		$3fe bytes	data
;
;		8914 aa94	sector 7 more time ($3180)
;		$3fe bytes	data
;
;		the time difference to read sectors 5 - 6 and 6 - 7 must be
;		at least 2% to make the protection succeed
;
;		sector 7 is also used for initial check if there is a copylock
;		track and calculation of the diskkey:
;			the first 8 longs must give the value $A573632C when
;			subtracted from 0
;			the first 12 longs are used for the diskkey with
;			different routines
;
;		8951		sector 11
;		$400 bytes	data
;
;		for sector 11 the copylock counts the mfmbytes which are read in
;		a specific time (ciab.ta = $bb8), the amount must be between
;		$3ac=940 and $53c=1340 bytes, due the large allowed speed
;		difference its maybe only a cracking protection (patched trace
;		vector)?
;
; the whole tracklength is:
;	Rick Dangerous		$30a8.7
; known diskkey's
;	Graham Gooches Cricket	$ae3b9ce3
;	Warzone (Core)		$7b8669f8
;	WWF European Rampage	$7dd5d4f9
;	WWF Wrestlemania	$17af868b
;----------------------------------------

		dc.l	_decode_rncl	;decode
		dc.l	_encode_rncl	;encode
		dc.l	_info_rncl	;info
		dc.l	_name_rncl	;name
		dc.l	_sync_rncl	;sync
		dc.l	_dens_rncl	;density
		dc.w	0		;index
		dc.w	$32		;speclen
		dc.w	0		;datalen
		dc.w	$34		;minimal rawlen
		dc.w	$3000		;writelen
		dc.w	TT_RNCL		;type
		dc.w	WWFF_FORCE	;flags

_sync_rncl	dc.l	0,0,0,$8914aa94
		dc.l	0,0,0,$ffffffff

		;	length (bytes), bitcell (ns)
_dens_rncl	dc.w	$c00-$100,1942	;#5	-3%
		dc.w	$c00,2000	;#6
		dc.w	$c00,2060	;#7	+3%
		dc.w	$c00+$100,2000	;#11
		dc.w	0

_name_rncl	dc.b	"rncl",0
		EVEN

;----------------------------------------
; decode rob copylock
; IN:	D0 = ULONG length of raw mfm-data in bits
;	D1 = ULONG track number
;	D2 = ULONG offset in mfm buffer
;	A0 = APTR  mfm buffer (source)
;	A1 = APTR  decoded buffer (destination)
; OUT:	D0 = BOOL  true on success
;	all other regs may scratched

_decode_rncl	;cmp.w	#1,d1			;only track 1
		;bne	.no

	;skip first syncword
		add.l	#2*8,d2
		move.l	d2,d6			;D6 = offset

	;verify checksum and copy data (first 32 byte)
		moveq	#0,d1
		moveq	#7,d7
.chk		bfextu	(a0){d6:32},d0
		sub.l	d0,d1
		move.l	d0,(a1)+
		addq.l	#4,a0
		dbf	d7,.chk
		cmp.l	#$a573632c,d1
		bne	.no

	;copy data (remaining 18 byte)
		moveq	#4,d7
.copy		bfextu	(a0){d6:32},d0
		move.l	d0,(a1)+
		addq.l	#4,a0
		dbf	d7,.copy

		moveq	#-1,d0
		rts

.no		moveq	#0,d0
		rts

;----------------------------------------
; encode rob copylock
; writing requires drive speed control (e.g. sybil)
; IN:	D0 = ULONG track number
;	A0 = APTR  destination buffer
;	A1 = APTR  source data to encode
; OUT:	D0 = mfmdata length written, 0 means error
;	all other regs may scratched

_encode_rncl	move.l	#$55555555<<1,d1	;$aaaaaaaa

	;sector 5
		move.l	#$8912aa92,(a0)+	;4
		move.w	#$c00/4-2,d0		;$bfc
.cp5		move.l	d1,(a0)+
		dbf	d0,.cp5

	;sector 6
		move.l	#$89112a91,(a0)+	;4
		move.w	#$c00/4-2,d0		;$bfc
		ror.l	#1,d1			;55555555
.cp6		move.l	d1,(a0)+
		dbf	d0,.cp6
		bclr	#0,(-1,a0)

	;sector 7
		move.w	#$8914,(a0)+		;2
		move.w	(a1)+,(a0)+		;2
		move.w	#$30/4-1,d0		;$30
.cp71		move.l	(a1)+,(a0)+
		dbf	d0,.cp71
		ror.l	#1,d1			;aaaaaaaa
		move.w	#($c00-$30-4)/4-1,d0	;$500-$30
.cp72		move.l	d1,(a0)+
		dbf	d0,.cp72

	;sector 11
		move.l	#$8951aaaa,(a0)+	;4
		move.w	#$c00/4-2,d0		;$bfc
.cp11		move.l	d1,(a0)+
		dbf	d0,.cp11

		move.l	#$3000,d0
		rts

;----------------------------------------
; info rob copylock
; adapted from Codetapper's 'CopyLockSync.s'
; IN:	A0 = track data
; OUT:	-

_info_rncl	move.l	a0,a1		;A1 = buffer

	;number 8
		add.w	#2,a0
		move	#0,ccr		;clear X
		moveq	#5,d1
		moveq	#0,d0
.Loop8		move.l	(a0)+,d3
		move.l	d3,d4
		moveq	#15,d2
.Roxl		roxl.l	#2,d4
		roxl.l	#1,d3
		dbra	d2,.Roxl
		swap	d3
		move.l	(a0)+,d5
		move.l	d5,d4
		moveq	#15,d2
.Roxl2		roxl.l	#2,d4
		roxl.l	#1,d5
		dbra	d2,.Roxl2
		move.w	d5,d3
		add.l	d3,d0
		rol.l	#1,d0
		dbf	d1,.Loop8
		move.l	d0,-(a7)

	;number 7
		move.l	a1,a0
		moveq	#11,d1
		moveq	#0,d0
.Loop7		add.l	d0,d0
		add.l	(a0)+,d0
		swap	d0
		dbf	d1,.Loop7
		move.l	d0,-(a7)

	;number 6
		move.l	a1,a0
		moveq	#11,d1
		moveq	#0,d0
.Loop6		add.l	d0,d0
		sub.l	(a0)+,d0
		dbf	d1,.Loop6
		move.l	d0,-(a7)

	;number 5
		move.l	a1,a0
		moveq	#11,d1
		moveq	#0,d0
.Loop5		add.l	d0,d0
		add.l	(a0)+,d0
		dbf	d1,.Loop5
		move.l	d0,-(a7)

	;number 4
		move.l	a1,a0
		moveq	#11,d1
		moveq	#0,d0
.Loop4		sub.l	(a0)+,d0
		swap	d0
		dbf	d1,.Loop4
		move.l	d0,-(a7)

	;number 3
		move.l	a1,a0
		moveq	#11,d1
		moveq	#0,d0
.Loop3		add.l	(a0)+,d0
		swap	d0
		dbf	d1,.Loop3
		move.l	d0,-(a7)

	;number 2
		move.l	a1,a0
		moveq	#11,d1
		moveq	#0,d0
.Loop2		sub.l	(a0)+,d0
		dbf	d1,.Loop2
		move.l	d0,-(a7)

	;number 1
		move.l	a1,a0
		moveq	#11,d1
		moveq	#0,d0
.Loop1		add.l	(a0)+,d0
		dbf	d1,.Loop1
		move.l	d0,-(a7)

	;number 0
		move.l	a1,a0
		moveq	#11,d1
		moveq	#0,d0
.Loop0		add.l	(a0)+,d0
		rol.l	#1,d0
		dbf	d1,.Loop0
		move.l	d0,-(a7)

		lea	(.txt),a0
		move.l	a7,a1
		bsr	_PrintArgs
		add.l	#9*4,a7
		rts

.txt		dc.b	" CopyLock CheckSum's:",10
		dc.b	"		$%08lx  #0  add.l (a1)+,d0  rol.l #1,d0",10
		dc.b	"		$%08lx  #1  add.l (a0)+,d6",10
		dc.b	"		$%08lx  #2  sub.l (a0)+,d6",10
		dc.b	"		$%08lx  #3  add.l (a0)+,d6  swap d6",10
		dc.b	"		$%08lx  #4  sub.l (a0)+,d6  swap d6",10
		dc.b	"		$%08lx  #5  add.l d6,d6     add.l (a0)+,d6",10
		dc.b	"		$%08lx  #6  add.l d6,d6     sub.l (a0)+,d6",10
		dc.b	"		$%08lx  #7  add.l d6,d6     add.l (a0)+,d6  swap d6",10
		dc.b	"		$%08lx  #8  add.l (a1)+,d0  rol.l #1,d0    (5 x roxl)",0
	EVEN
