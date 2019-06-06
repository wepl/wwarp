;*---------------------------------------------------------------------------
;  :Program.	specialfx.s
;  :Contents.	decode/encode custom track format for Special FX games
;  :Author.	Codetapper, Wepl
;  :Version	$Id: fmt_specialfx.s 1.3 2005/04/07 23:26:58 wepl Exp wepl $
;  :History.	02.12.02 created
;		14.02.04 new decode/encode parameters and rework
;		20.02.04 completed and tested with RoboCop 2
;  :Requires.	OS V37+, MC68020+
;  :Language.	68020 Assembler
;  :Translator.	Barfly V2.9
;  :To Do.
;  :Info.	This format is used on Midnight Resistance, Striker, Robocop 2
;		and probably on Hudson Hawk, Untouchables etc (untested)
;---------------------------------------------------------------------------*
; mfm-track structure
;
;   $8944aaaa                                    \
;   $xxxxxxxx (odd sector info)  \ $01 $03 $0c00  \
;   $xxxxxxxx (even sector info) / trk sec bytes   \
;   $xxxxxxxx (odd checksum)                        \ 12 sectors * $418
;   $xxxxxxxx (even checksum)                       /
;   $0200 words mfm data (odd)                     /
;   $0200 words mfm data (even)                   /
;   $2aaaaaaa (sector gap masked with $2fffffff) /
;
;   Sector information follows this pattern:
;   $01 $03 $0c $00 ($01 = track, $03 = sector, $0c = sectors remaining, $00 = unused)
;   $01 $04 $0b $00
;   $01 $05 $0a $00
;   $01 $06 $09 $00
;   $01 $07 $08 $00
;   $01 $08 $07 $00
;   $01 $09 $06 $00
;   $01 $0a $05 $00
;   $01 $0b $04 $00
;   $01 $00 $03 $00
;   $01 $01 $02 $00
;   $01 $02 $01 $00
;   the gap after the last sector must be at least $250 bytes, otherwise the
;   loader will fail
;
;   The game track is the physical track + 2 and then bit 0 changed
;   to effectively swap sides. The first usable track is track 2:
;
;   Physical   Game Track Value
;   --------   ----------------
;      00            N/A
;      01            N/A
;      02             01
;      03             00
;      04             03
;      05             02
;     ...            ...
;     156            155
;     157            154
;     158            157
;     159            156
;
;   disk allocation map and directory is in track 81, it contains disk name
;   and date, a map telling which sector is used by which file, the disk
;   directory
;   files are packed and will decompressed by the diskloader
;   the directory structure is:
;	$00	WORD	file number
;	$02	CHAR17	filename
;	$13	BYTE	rc for loader???
;	$14	LONG	default destination address
;	$18	LONG	length unpacked
;	$1c	LONG	length packed
;
;   The sector gap is $aaaaaaaa on all sectors except one which is $2aaaaaaa
;------------------------------------------

		dc.l	_decode_specialfx	;decode
		dc.l	_encode_specialfx	;encode
		dc.l	0			;info
		dc.l	_name_specialfx		;name
		dc.l	_sync_specialfx		;sync
		dc.l	0			;density
		dc.w	0			;index
		dc.w	0			;speclen
		dc.w	$1800			;datalen
		dc.w	$418*12+$250		;minimal rawlen
		dc.w	$418*12+$250		;writelen
		dc.w	TT_SPECIALFX		;type
		dc.w	0			;flags

_sync_specialfx	dc.l	0,0,0,$8944aaaa
		dc.l	0,0,0,$ffffffff

_name_specialfx	dc.b	"specialfx",0
		EVEN

;----------------------------------------
; decode specialfx track
; IN:	D0 = ULONG length of raw mfm-data in bits
;	D1 = ULONG track number
;	D2 = ULONG offset in mfm buffer
;	A0 = APTR  mfm buffer (source)
;	A1 = APTR  decoded buffer (destination)
; OUT:	D0 = BOOL  true on success
;	all other regs may scratched

_decode_specialfx
		sub.w	#2,d1			;Tracks 0 and 1 can't be Special FX!
		blt	.no
		bchg	#0,d1
		move.l	#$c0000,d7		;D7 = sectors left + track
		move.w	d1,d7
		move.l	d2,d6			;D6 = offset
		move.l	#$55555555,d2		;D2 = mfm

	;first we check for all syncs to speed up
	;because we can only decode if we are after the intersector gap
		moveq	#0,d1
		moveq	#12-1,d4
.chksync	bfextu	(a0,d1.l){d6:32},d0
		cmp.l	#$8944aaaa,d0
		bne	.no
		add.w	#$418,d1
		dbf	d4,.chksync

	;decode track
		moveq	#12-1,d4		;D4 = Sectors remaining
.next_sector	addq.l	#4,a0			;skip $8944aaaa

		bsr	.getlonga0a0		;2 longwords form sector info
		swap	d0
		cmp.b	#11,d0			;Make sure sector number isn't > 11
		bhi	.no
		swap	d4			;High 16 bits of d4 is a bit array
		bset	d0,d4			;of sectors processed
		bne	.no			;duplicate sector?
		swap	d4
		moveq	#0,d1
		move.b	d0,d1
		mulu	#$200,d1
		lea	(a1,d1.l),a2		;A2 = destination
		lsr.l	#8,d0
		cmp.l	d0,d7
		bne	.no

		bsr	.getlonga0a0		;2 longwords form checksum
		move.l	d0,d5			;D5 = Checksum

		move.l	#($200/4)-1,d3
.decode_data	bsr	.getlonga0a2
		move.l	d0,(a2)+
		dbf	d3,.decode_data

		sub.l	#$200,a2
		bsr	_sfx_checksum

		cmp.l	d1,d5			;Compare the checksum
		bne	.no

		add.w	#$200+4,a0		;skip odd mfm and sector gap
		sub.l	#$10000,d7		;dec sectors left

		dbf	d4,.next_sector

		moveq	#-1,d0
		bra	.quit

.no		moveq	#0,d0

.quit		rts

.getlonga0a0	bfextu	(a0){d6:32},d0		;move.l	(a0)+,d0
		addq.l	#4,a0
		bfextu	(a0){d6:32},d1		;move.l	(a0)+,d1
		bra	.getlongcommon

.getlonga0a2	bfextu	(a0){d6:32},d0		;move.l	(a0)+,d0
		bfextu	($200,a0){d6:32},d1	;move.l	(a2)+,d1

.getlongcommon	addq.l	#4,a0
		and.l	d2,d0
		and.l	d2,d1
		lsl.l	#1,d0
		or.l	d1,d0
		rts

;----------------------------------------
; calc specialfx sector checksum
; IN:	A2 = Sector data
; OUT:	D1 = Checksum

_sfx_checksum	movem.l	d3/d7/a2,-(sp)
		move	#0,ccr			;clear x-flag
		moveq	#0,d1
		moveq	#0,d3
		move.l	#($200/2)-1,d7
.checksum_loop	andi.w	#15,d3
		move.w	(a2)+,d0
		rol.w	d3,d0
		addx.w	d0,d1
		addq.w	#1,d3
		dbra	d7,.checksum_loop
		ext.l	d1
		rol.l	#8,d1
		movem.l	(sp)+,d3/d7/a2
		rts

;----------------------------------------
; encode specialfx track
; IN:	D0 = ULONG track number
;	A0 = APTR  destination buffer
;	A1 = APTR  source data to encode
; OUT:	D0 = mfmdata length written, 0 means error
;	all other regs may scratched

_encode_specialfx
		sub.w	#2,d0			;Tracks 0 and 1 can't be Special FX!
		blt	.no

		move.l	#$55555555,d3

		move.l	#$c0000,d4		;D4 = sectors left + track
		move.w	d0,d4
		bchg	#0,d4			;Flip track sides
		ror.l	#8,d4

		moveq	#12-1,d7

.enc_next_sctor	move.l	#$8944aaaa,(a0)+	;4

		move.l	d4,d2
		bsr	_encode_longodd		;4
		move.l	d4,d2
		bsr	_encode_long		;4

		move.l	a1,a2
		bsr	_sfx_checksum
		move.l	d1,d6
		move.l	d6,d2
		bsr	_encode_longodd		;4
		move.l	d6,d2
		bsr	_encode_long		;4

		move.l	#($200/4)-1,d6		;Encode odd data
.data_odd	move.l	(a1)+,d2		;$400
		bsr	_encode_longodd
		dbf	d6,.data_odd

		sub.l	#$200,a1
		move.l	#($200/4)-1,d6		;Encode even data
.data_even	move.l	(a1)+,d2		;$400
		bsr	_encode_long
		dbf	d6,.data_even

		moveq	#0,d2			;Sector gap
		bsr	_encode_long		;4

		add.l	#$10000-$100,d4		;adjust sectors left and actual sector
		dbf	d7,.enc_next_sctor

		move.w	#$250/4-1,d7
.gap		moveq	#0,d2
		bsr	_encode_long
		dbf	d7,.gap

		move.l	#$418*12+$250,d0
		rts

.no		moveq	#0,d0
		rts
