;*---------------------------------------------------------------------------
;  :Program.	fmt_robnorthenold.s
;  :Contents.	decode/encode rob northen copylock old
;  :Author.	Wepl
;  :Version	$Id: fmt_rncopylockold.s 1.3 2005/04/07 23:26:58 wepl Exp wepl $
;  :History.	04.11.04 created
;  :Requires.	OS V37+, MC68020+
;  :Language.	68020 Assembler
;  :Translator.	Barfly V2.9
;  :To Do.
;  :Info.	examples: Crossbow, Cyberball, GuardianAngel, HardDrivin, Onslaught,
;		PhotonStorm, Pyramax, RainbowIslands, Steel
;---------------------------------------------------------------------------*
; rob northen copylock old format:
; - its always on track 1
;	standard dos format +
;	0	891444a9	sync
;	4	16 byte		data
;	$14	$2aaa/$aaaa	mfm-zero
;----------------------------------------
; known keys:
;	$0c4b692d      Crossbow
;	$005e49b5  #1  Cyberball
;	$7c3369c9  #0  Guardian Angel
;	$2a113417  #1  Hard Drivin'
;	$2a113417  #1  Onslaught
;	$7c3369c9      Photon Storm
;	$8b26336f  #0  Pyramax
;	$8062b447  #1  Rainbow Islands
;	$2a113417  #1  Steel
;----------------------------------------

		dc.l	_decode_rnclold	;decode
		dc.l	0		;encode
		dc.l	_info_rnclold	;info
		dc.l	_name_rnclold	;name
		dc.l	_sync_rnclold	;sync
		dc.l	0		;density
		dc.w	0		;index
		dc.w	22		;speclen
		dc.w	$1600		;datalen
		dc.w	$440*11+22	;minimal rawlen
		dc.w	$440*11+22	;writelen
		dc.w	TT_RNCLOLD	;type
		dc.w	WWFF_FORCE	;flags

_sync_rnclold	dc.l	0,0,0,$891444a9
		dc.l	0,0,0,$ffffffff

_name_rnclold	dc.b	"rnclold",0
		EVEN

;----------------------------------------
; check if track is possible rob copylock old, to deny detection of stdf
; IN:	D0 = ULONG length of raw mfm-data in bits
;	D1 = ULONG track number
;	D2 = ULONG offset in mfm buffer
;	A0 = APTR  mfm buffer (source)
;	A1 = APTR  decoded buffer (destination)
; OUT:	Z  = BOOL  ne=detected eq=not detected
;	all regs must be preserved!

_trkchk_rnclold	movem.l	d0-d1/a0-a1,-(a7)
		bset	#DTCTFLAGB_RNCLOLD_Chk,(gl_detectflags+3,GL)
		bne	.checked
		move.l	d0,d1			;buflen
		moveq	#0,d0			;offset
	;	move.l	a0,a0			;buffer
		lea	(_sync_rnclold),a1	;sync
		bsr	_searchsync
		cmp.l	#-1,d0			;set flags
		beq	.checked
		bset	#DTCTFLAGB_RNCLOLD_True,(gl_detectflags+3,GL)
.checked	btst	#DTCTFLAGB_RNCLOLD_True,(gl_detectflags+3,GL)
		movem.l	(a7)+,_MOVEMREGS
		rts

;----------------------------------------
; decode rob copylock old, subroutine called from _decode_dosf
; IN:	D0 = ULONG length of raw mfm-data in bits
;	D1 = ULONG track number
;	D2 = ULONG offset in mfm buffer
;	A0 = APTR  mfm buffer (source)
;	A1 = APTR  decoded buffer (destination)
; OUT:	D0 = BOOL  true on success
;	all other regs may scratched

_decode_rnclold
		move.l	d0,d3			;D3 = length
		move.l	d1,d4			;D4 = track number
		move.l	a0,a2			;A2 = mfm buffer
		move.l	a1,a3			;A3 = decoded

	;copy data
		moveq	#22/4-1,d6
.copy		bfextu	(a0){d2:32},d7
		move.l	d7,(a3)+
		addq.l	#4,a0
		dbf	d6,.copy
		bfextu	(a0){d2:16},d7
		move.w	d7,(a3)+

	;search for stdf sync
	;this is not safe! because only the first stdf-sync will be tried for decoding
		moveq	#0,d0			;offset
		move.l	d3,d1			;buflen
		move.l	a2,a0			;mfm buffer
		lea	(_sync_stdf),a1		;sync
		bsr	_searchsync
		move.l	d0,d2			;offset
		beq	.no
		move.l	d3,d0			;buflen
		move.l	d4,d1			;track number
		move.l	a2,a0			;mfm buffer
		move.l	a3,a1			;decoded buffer
		bra	_decode_stdf_nochk

.no		rts

;----------------------------------------
; info rob copylock old
; IN:	A0 = track data
; OUT:	-

_info_rnclold	addq.l	#2,a0
		move.l	a0,a1		;A1 = buffer

	;number 1
		moveq	#3,d1
		moveq	#0,d0
.loop1		add.l	(a0)+,d0
		dbf	d1,.loop1
		move.l	(a0)+,d1
		and.w	#$5555,d1
		add.l	d1,d0
		move.l	d0,-(a7)

	;number 0
		move.l	a1,a0
		moveq	#3,d1
		moveq	#0,d0
.loop0		sub.l	(a0)+,d0
		dbf	d1,.loop0
		move.l	(a0)+,d1
		and.w	#$5555,d1
		sub.l	d1,d0
		move.l	d0,-(a7)

		lea	(.txt),a0
		move.l	a7,a1
		bsr	_PrintArgs
		add.l	#2*4,a7
		rts

.txt		dc.b	" CopyLock CheckSum's:",10
		dc.b	"		$%08lx  #0  sub.l (a0)+,d0",10
		dc.b	"		$%08lx  #1  add.l (a0)+,d0",10
		dc.b	0
	EVEN
