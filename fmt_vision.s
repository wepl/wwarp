;*---------------------------------------------------------------------------
;  :Program.	vision.s
;  :Contents.	decode/encode custom track format for Vision games
;  :Author.	Codetapper, Wepl
;  :Version	$Id: fmt_vision.s 1.6 2008/05/06 21:54:18 wepl Exp wepl $
;  :History.	25.09.02 created
;		08.11.02 rework for new sync-search
;		12.11.02 some changes (Wepl)
;		09.03.04 new decode/encode parameters and rework
;		27.04.08 sync changed to speed up the wwarp detection loop
;  :Requires.	OS V37+, MC68020+
;  :Language.	68020 Assembler
;  :Translator.	Barfly V2.9
;  :To Do.
;  :Info.	This format is used on Guardian and Seek and Destroy
;---------------------------------------------------------------------------*
; mfm-track structure
;   $44892aaa
;   $1800 words mfm data (odd)
;   $xxxxxxxx (unknown)
;   $xxxxxxxx (odd checksum)
;   $1800 words mfm data (even)
;   $xxxxxxxx (unknown)
;   $xxxxxxxx (even checksum)
;------------------------------------------

VISION_FASTSYNC=1

		dc.l	_decode_vision	;decode
		dc.l	_encode_vision	;encode
		dc.l	0		;info
		dc.l	_name_vision	;name
		dc.l	_sync_vision	;sync
		dc.l	0		;density
		dc.w	0		;index
		dc.w	0		;speclen
		dc.w	$1800		;datalen
		dc.w	6+($1808*2)	;minimal rawlen
		dc.w	6+($1808*2)	;writelen
		dc.w	TT_VISION	;type
		dc.w	0		;flags

	IFEQ VISION_FASTSYNC
_sync_vision	dc.l	0,0,$aaaa,$44892aaa	;this slows down the detection loop because '$aaaa'
		dc.l	0,0,$ffff,$ffffffff
	ELSE
_sync_vision	dc.l	0,0,0,$44892aaa
		dc.l	0,0,0,$ffffffff
	ENDC

_name_vision	dc.b	"vision",0
		EVEN

;----------------------------------------
; decode vision track
; IN:	D0 = ULONG length of raw mfm-data in bits
;	D1 = ULONG track number
;	D2 = ULONG offset in mfm buffer
;	A0 = APTR  mfm buffer (source)
;	A1 = APTR  decoded buffer (destination)
; OUT:	D0 = BOOL  true on success
;	all other regs may scratched

_decode_vision	move.l	d2,d6			;offset
		move.l	#$55555555,d2

	;check unused long
	IFEQ VISION_FASTSYNC
		add.w	#$1800+6,a0		;skip sync(aaaa44892aaa)
	ELSE
		add.w	#$1800+4,a0		;skip sync(44892aaa)
	ENDC
		bsr	.getlong
		move.l	d0,d4			;Seek and Destroy Disk.1 Disk.3
		beq	.unusedok
		cmp.l	#$00faf5f1,d4		;Seek and Destroy Disk.2
		beq	.unusedok
		cmp.l	#$fd000703,d4		;Seek and Destroy Disk.4
		beq	.unusedok
		cmp.l	#$aaaaaaaa,d4		;Guardian
		bne	.no
.unusedok	sub.w	#$1800+4,a0

	;decode track
		move.l	#($1800/4)-2,d3
		moveq	#0,d7
		moveq	#0,d5
.decode_data	bsr	.getlong
		move.l	d0,(a1)+
		add.l	d0,d7
		addx.l	d5,d7
		dbf	d3,.decode_data
		bsr	.getlong
		move.l	d0,(a1)+
		add.l	d0,d7

		addq.l	#4,a0			;unknown (never used)

		bsr	.getlong		;d0 = checksum (read from data)
		addq.l	#1,d0
		add.l	d7,d0
		bne	.no

		moveq	#-1,d0
		rts

.no		tst.l	(gl_rd_dbg,GL)
		beq	.nono
		lea	.txt,a0
		move.l	d4,-(a7)
		move.l	a7,a1
		bsr	_PrintArgs
		addq.l	#4,a7
.nono		moveq	#0,d0
		rts

.getlong	bfextu	(a0){d6:32},d0		;move.l	(a0)+,d0
		bfextu	($1808,a0){d6:32},d1	;move.l	(a2)+,d1
		addq.l	#4,a0
		and.l	d2,d0
		and.l	d2,d1
		add.l	d0,d0
		or.l	d1,d0
		rts

.txt		dc.b	" d4=%08lx",0
	EVEN

;----------------------------------------
; encode vision track
; IN:	D0 = ULONG track number
;	A0 = APTR  destination buffer
;	A1 = APTR  source data to encode
; OUT:	D0 = mfmdata length written, 0 means error
;	all other regs may scratched

_encode_vision	move.l	#$55555555,d3

		move.w	#$aaaa,(a0)+		;2
		move.l	#$44892aaa,(a0)+	;4

		move	#0,ccr			;clear x-flag
		move.l	#($1800/4)-2,d0
		move.l	(a1)+,d7
.chksum		move.l	(a1)+,d1
		addx.l	d1,d7
		dbf	d0,.chksum
		neg.l	d7
		subq.l	#1,d7			;D7 = chksum

		sub.w	#$1800,a1
		move.w	#($1800/4)-1,d6		;Encode odd data
.data_odd	move.l	(a1)+,d2		;$1800
		bsr	_encode_longodd
		dbf	d6,.data_odd

		moveq	#0,d2			;usused longword
		bsr	_encode_longodd		;4

		move.l	d7,d2			;encode odd checksum
		bsr	_encode_longodd		;4

		sub.w	#$1800,a1
		move.w	#($1800/4)-1,d6		;Encode even data
.data_even	move.l	(a1)+,d2		;$1800
		bsr	_encode_long
		dbf	d6,.data_even

		moveq	#0,d2			;usused longword
		bsr	_encode_long		;4

		move.l	d7,d2			;encode even checksum
		bsr	_encode_long		;4

		move.l	#6+2*$1808,d0
		rts
