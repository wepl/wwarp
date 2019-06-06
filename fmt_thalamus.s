;*---------------------------------------------------------------------------
;  :Program.	thalamus.s
;  :Contents.	decode/encode custom track format for thalamus games
;  :Author.	Codetapper
;  :Version	$Id: fmt_thalamus.s 1.3 2005/04/07 23:35:14 wepl Exp wepl $
;  :History.	01.01.04 created
;		20.02.04 new decode/encode parameters and rework
;  :Requires.	OS V37+, MC68020+
;  :Language.	68020 Assembler
;  :Translator.	Barfly V2.9
;  :To Do.
;  :Info.	This format is used on Winter Camp, Hoi, Bump'n'Burn,
;		Borobodur...
;---------------------------------------------------------------------------*
; mfm-track structure
;
;   $2291 (sync)
;   $2291
;     $xx Track Number   \
;     $yy Next track      \ (odd data follows all even data)
;   $zzzz Version string  /
;   $180c words mfm data /
;   $2 words (checksum - odd then even for high byte which is always 0,
;             then odd/even low byte which matches checksum of data area)
;------------------------------------------

		dc.l	_decode_thalamus	;decode
		dc.l	_encode_thalamus	;encode
		dc.l	0			;info
		dc.l	_name_thalamus		;name
		dc.l	_sync_thalamus		;sync
		dc.l	0			;density
		dc.w	0			;index
		dc.w	4			;speclen
		dc.w	$180c			;datalen
		dc.w	($1810*2)+$8		;minimal rawlen
		dc.w	($1810*2)+$8		;writelen
		dc.w	TT_THALAMUS		;type
		dc.w	0			;flags

_sync_thalamus	dc.l	0,0,0,$22912291
		dc.l	0,0,0,$ffffffff

_name_thalamus	dc.b	"thalamus",0
		EVEN

;----------------------------------------
; decode thalamus track
; IN:	D0 = ULONG length of raw mfm-data in bits
;	D1 = ULONG track number
;	D2 = ULONG offset in mfm buffer
;	A0 = APTR  mfm buffer (source)
;	A1 = APTR  decoded buffer (destination)
; OUT:	D0 = BOOL  true on success
;	all other regs may scratched

_decode_thalamus
		move.w	d1,d4			;d4 = Track number

	;skip syncs (2 x $2291)
		addq.l	#4,a0
		move.l	d2,d6			;offset

	;decode track
		move.l	#$55555555,d2
		moveq	#0,d3			;d3 = Checksum

		bfextu	(a0){d6:32},d0		;move.l	(a0)+,d0
		bfextu	($1810,a0){d6:32},d1	;move.l	(a2)+,d1
		addq.l	#4,a0
		and.l	d2,d0
		and.l	d2,d1
		lsl.l	#1,d0
		or.l	d1,d0

		move.l	d0,d1			;Check track number matches
		rol.l	#8,d1
		cmp.b	d1,d4
		bne	.no

		move.l	d0,(a1)+		;Store header data (4 bytes)
		eor.b	d0,d3			;Adjust checksum
		ror.l	#8,d0
		eor.b	d0,d3
		ror.l	#8,d0
		eor.b	d0,d3
		ror.l	#8,d0
		eor.b	d0,d3

		move.l	#($180c/4)-1,d7
.decodetrack	bfextu	(a0){d6:32},d0		;move.l	(a0)+,d0
		bfextu	($1810,a0){d6:32},d1	;move.l	(a2)+,d1
		addq.l	#4,a0
		and.l	d2,d0
		and.l	d2,d1
		lsl.l	#1,d0
		or.l	d1,d0
		move.l	d0,(a1)+

		eor.b	d0,d3			;Adjust checksum
		ror.l	#8,d0
		eor.b	d0,d3
		ror.l	#8,d0
		eor.b	d0,d3
		ror.l	#8,d0
		eor.b	d0,d3
		dbf	d7,.decodetrack

		bfextu	($1810,a0){d6:32},d0	;move.l	(a2)+,d0
						;d0 = $12345678
		rol.l	#8,d0			;d0 = $34567812
		move.l	d0,d1			;d1 = $34567812
		rol.l	#8,d1			;d1 = $56781234
		and.l	d2,d0
		and.l	d2,d1			;This is done so we get high
		lsl.l	#1,d0			;byte xx and low byte yy
		or.l	d1,d0			;     $00yy00xx
		cmp.b	#0,d0			;High byte of checksum must
		bne	.no			;be 0 or data is corrupt
		swap	d0			;Swap word to get low byte
		cmp.b	d0,d3			;Check checksum matches
		bne	.no

		moveq	#-1,d0
		bra	.quit

.no		moveq	#0,d0

.quit		rts

;----------------------------------------
; encode thalamus track
; IN:	D0 = ULONG track number
;	A0 = APTR  destination buffer
;	A1 = APTR  source data to encode
; OUT:	D0 = mfmdata length written, 0 means error
;	all other regs may scratched

_encode_thalamus
		move.l	#$55555555,d3
		move.l	d0,d4			;d4 = Track number

		move.l	#$22912291,(a0)+	;4 (sync + sync)

		move.l	#($1810/4)-1,d6
.data_odd	move.l	(a1)+,d2
		bsr	_encode_longodd		;$1810 (odd data)
		dbf	d6,.data_odd

		sub.l	#$1810,a1
		move.l	#($1810/4)-1,d6
.data_even	move.l	(a1)+,d2		;$1810 (even data)
		bsr	_encode_long
		dbf	d6,.data_even

		sub.l	#$1810,a1		;Calculate checksum
		moveq	#0,d5
		move.l	#$1810-1,d6
.calc_csum_loop	move.b	(a1)+,d1
		eor.b	d1,d5
		dbra	d6,.calc_csum_loop

		move.l	d5,d2			;Encode checksum ($0000xxyy)
		rol.l	#7,d2			;where $xx = odd data and
		move.b	d5,d2			;$yy = even data
		bsr	_encode_long		;Already taken care of shift

		move.l	#2*$1810+8,d0
		rts
