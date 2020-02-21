;*---------------------------------------------------------------------------
;  :Program.	cmdd.s
;  :Contents.	command d - dump
;  :Author.	Bert Jahn
;  :Version	$Id: cmdd.s 1.6 2008/05/06 21:54:18 wepl Exp wepl $
;  :History.	02.11.02 separated from wwarp.asm
;		14.02.20 fix printing of long syncs
;  :Requires.	OS V37+, MC68020+
;  :Copyright.	©1998-2008 Bert Jahn, All Rights Reserved
;  :Language.	68020 Assembler
;  :Translator.	Barfly V2.9
;  :To Do.
;---------------------------------------------------------------------------*

_cmd_dump	moveq	#0,d4			;D4 = sync specified
		moveq	#1,d5			;D5 = sync num
		moveq	#-1,d6			;D6 = length in bytes
		moveq	#0,d7			;D7 = offset in bits
		sub.l	a3,a3			;A3 = sync num specified

	;parse argument
		move.l	(gl_rd_arg,GL),d0
		beq	.argend
		move.l	d0,a2			;A2 = arg
	;sync
		cmp.b	#",",(a2)
		beq	.send
		move.l	a2,a0
.sl		move.b	(a0)+,d0
		beq	.se
		cmp.b	#",",d0
		bne	.sl
.se		move.b	-(a0),d2
		clr.b	(a0)
		exg.l	a0,a2
		bsr	_parsesync
		tst.l	d0
		beq	_rts
		moveq	#-1,d4			;sync specified
		move.b	d2,(a2)
	;sync num
.send		cmp.b	#",",(a2)+
		bne	.arglast
		cmp.b	#",",(a2)
		beq	.snend
		move.l	a2,a0
		bsr	_atoi
		cmp.l	a0,a2
		beq	.argerr
		move.l	a0,a2
		move.l	d0,d5
		ble	.argerr
		addq.l	#1,a3			;sync num specified
	;length
.snend		cmp.b	#",",(a2)+
		bne	.arglast
		cmp.b	#",",(a2)
		beq	.lend
		move.l	a2,a0
		bsr	_etoi
		cmp.l	a0,a2
		beq	.argerr
		move.l	a0,a2
		move.l	d0,d6
		ble	.argerr
	;offset
.lend		cmp.b	#",",(a2)+
		bne	.arglast
		st	d2			;sign negative
		cmp.b	#'-',(a2)+
		beq	.off0
		sf	d2
		subq.l	#1,a2
.off0		move.l	a2,a0
		bsr	_etoi
		move.l	d0,d7
		lsl.l	#3,d7			;D7 = offset in bits
		tst.b	d2
		beq	.off1
		neg.l	d7
.off1		move.l	a0,a2
		cmp.b	#".",(a2)+
		bne	.arglast
		move.l	a2,a0
		bsr	_etoi
		cmp.l	#7,d0
		bhi	.argerr
		tst.b	d2
		bpl	.off2
		neg.l	d0
.off2		add.l	d0,d7
		lea	(1,a0),a2
.arglast	tst.b	-(a2)
		bne	.argerr
.argend
		move.l	#CMDF_IN|CMDF_TRKDATA,d0	;flags
		movem.l	d4-d7/a3,-(a7)
		move.l	a7,a0			;cbdata
		lea	.tracktable,a1		;cbtt
		lea	.tracks,a2		;cbt
		bsr	_cmdwork
		add.w	#20,a7
		rts

.argerr		lea	(_badarg),a0
		bra	_Print

.tracktable	lea	(gl_tabarg,GL),a0
		lea	(gl_tabread,GL),a1
		bsr	_copytt
		moveq	#-1,d0
		rts

.tracks		move.l	a0,a3			;a3 = cbdata
						;(a3)    = sync specified
						;(4,a3)  = sync num
						;(8,a3)  = length in bytes
						;(12,a3) = offset in bits
						;(16,a3) = sync num specified

	;display track info
		move.l	(gl_trk+wth_wlen,GL),-(a7)
		move.l	(gl_trk+wth_len,GL),d0
		move.l	d0,d1
		and.l	#7,d1
		lsr.l	#3,d0
		movem.l	d0-d1,-(a7)
		moveq	#" ",d0
		btst	#TFB_INDEX,(gl_trk+wth_flags+1,GL)
		beq	.fi
		moveq	#"I",d0
.fi		move.w	d0,-(a7)
		moveq	#" ",d0
		btst	#TFB_RAWSINGLE,(gl_trk+wth_flags+1,GL)
		beq	.rs
		moveq	#"S",d0
.rs		move.w	d0,-(a7)
		bsr	_gettt
		move.l	(wwf_name,a0),-(a7)
		move.l	d5,-(a7)
		lea	(_dump1),a0
		move.l	a7,a1
		bsr	_PrintArgs			;returns d0=ident
		add.w	#6*4,a7
		moveq	#0,d1				;flags
		lea	(gl_trk+wth_sync,GL),a0		;sync
		bsr	_printsync
		bsr	_PrintLn

	;fork on tracktype
		cmp.w	#TT_RAW,(gl_trk+wth_type,GL)
		beq	.raw

	;decoded
		bsr	_gettt
		moveq	#0,d0
		move.w	(wwf_speclen,a0),d0
		add.w	(wwf_datalen,a0),d0		;length in bytes
		move.l	(12,a3),d1			;offset in bits
		bmi	.offerr
		move.l	d1,d2
		bftst	d2{29:3}
		bne	.offerr
		lsr.l	#3,d2				;delta in bytes
		sub.l	d2,d0
		ble	.offerr
		cmp.l	(8,a3),d0
		blo	.d_dump
		move.l	(8,a3),d0
.d_dump		lea	(gl_tmpbuf.w,GL,d2.l),a0	;memory
		bsr	_DumpMemory
		bra	.success

	;tracktype raw
.raw
	;defaults
		moveq	#0,d7				;d7 = bitoffset in buffer to display

	;sync to use
		lea	(gl_sync,GL),a2			;a2 = sync (via arg)
		tst.l	(a3)
		bne	.syncarg
		lea	(gl_trk+wth_sync,GL),a2		;a2 = sync (from track header)
.syncarg	move.l	a2,a0
		bsr	_getsynclen			;is there a sync?
		move.l	d0,d4				;d4 = bool sync set

	;check single
		btst	#TFB_RAWSINGLE,(gl_trk+wth_flags+1,GL)
		bne	.rawsingle

	;tracktype raw normal
.rawnormal	tst.l	d4
		beq	.rn_sok
		move.l	(gl_trk+wth_len,GL),d0
		bsr	.checksync
		move.l	d0,d7				;d7 = bitoffset in buffer to display
.rn_sok
		add.l	(12,a3),d7
		bmi	.offerr
		move.l	(gl_trk+wth_len,GL),d6
		sub.l	d7,d6				;d6 = remaining bits in buffer
		ble	.offerr

		bra	.len

	;tracktype raw single
.rawsingle	tst.l	d4
		beq	.rs_sok
		lea	(SYNCLEN,a2),a0			;mask
		moveq	#SYNCLEN-1,d0
.rs_cs		tst.b	(a0)+
		dbne	d0,.rs_cs
		addq.w	#1,d0
		neg.l	d0
		add.l	#SYNCLEN,d0
		lsl.l	#3,d0
		subq.l	#1,d0
		add.l	(gl_trk+wth_len,GL),d0
		bsr	.checksync
		move.l	d0,d7				;d7 = bitoffset in buffer to display
.rs_sok
		move.l	(gl_trk+wth_len,GL),d6		;d6 = remaining bits in buffer
		add.l	(12,a3),d7
		divsl.l	d6,d0:d7
		move.l	d0,d7
		bpl	.rs_1
		add.l	d6,d7
.rs_1

	;set length
.len		addq.l	#7,d6
		lsr.l	#3,d6				;d6 = length in bytes
		move.l	(8,a3),d0
		beq	.len_ok
		cmp.l	d0,d6
		blo	.len_ok
		move.l	d0,d6
.len_ok

	;shift track
		move.l	d7,d0				;offset
		move.l	d6,d1
		lsl.l	#3,d1				;length
		lea	(gl_tmpbuf,GL),a0		;buffer
		bsr	_shiftmfm

	;dump
		move.l	d6,d0				;length in bytes
		move.l	d7,d1				;delta in bits
		lea	(gl_tmpbuf,GL),a0		;memory
		bsr	_DumpMemory

	;return
.success	moveq	#-1,d0				;success
.end		rts

.offerr		lea	(_offerr),a0
		bsr	_Print
		moveq	#0,d0
		bra	.end

; IN:	d0 = buflen in bits
;	(4,a3) = sync num
;	(16,a3) = sync num specified
; OUT:	d0 = offset found

.checksync	move.l	d0,d1				;buflen
		move.l	(4,a3),d0			;syncno
		tst.l	(16,a3)
		bne	.cs_1
		moveq	#0,d0
		move.w	(gl_trk+wth_syncnum,GL),d0
		bne	.cs_1
		moveq	#1,d0
.cs_1		move.l	d0,-(a7)
		lea	(gl_tmpbuf,GL),a0		;buffer
		move.l	a2,a1				;sync
		bsr	_countsync
		move.l	d0,d7				;offset
		move.l	d1,-(a7)			;count
		tst.l	d7
		bmi	.cs_2
		lea	(_syncfound2),a0
		move.l	a7,a1
		bsr	_PrintArgs
		move.l	d7,d0
		bsr	_printbitlen
		bsr	_PrintLn
		move.l	d7,d0
.cs_3		addq.l	#8,a7
		rts

.cs_2		lea	(_syncfound3),a0
		move.l	a7,a1
		bsr	_PrintArgs
		moveq	#0,d0
		bra	.cs_3

;----------------------------------------
; dump memory
; IN:	d0 = ULONG len in bytes
;	d1 = ULONG delta in bits
;	a0 = APTR  memory
; OUT:	-

_DumpMemory	movem.l	d2-d6/a2-a3,-(a7)
		move.l	d0,d2			;D2 = length
		move.l	a0,a2			;A2 = actual address

		lea	(.padr),a3
		move.l	d1,d3
		move.l	d1,d4
		lsr.l	#3,d3			;D3 = byte offset
		and.l	#7,d4			;D4 = bit offset
		beq	.1
		lea	(.padrb),a3
.1
		moveq	#32,d5			;D5 = bytes per line

.loop		bsr	_CheckBreak		;check for CTRL-C
		tst.l	d0
		bne	.break

		jsr	(a3)

		sub.l	d5,d2
		bcs	.last
		add.l	d5,d3

		lea	(.line),a0
		move.l	a2,a1
		bsr	_PrintArgs
		add.l	d5,a2

		tst.l	d2
		bne	.loop
		bra	.end

.last		add.l	d5,d2

.mem		lea	(.space),a0
		bsr	_Print

		moveq	#3,d6

.long		lea	(.byte),a0
		moveq	#0,d0
		move.b	(a2)+,d0
		move.l	d0,-(a7)
		move.l	a7,a1
		bsr	_PrintArgs
		addq.l	#4,a7
		subq.l	#1,d2
		ble	.ok
		dbf	d6,.long
		bra	.mem

.ok		bsr	_PrintLn
.end
.break		movem.l	(a7)+,_MOVEMREGS
		rts

.padr		lea	(.adr),a0
		subq.w	#2,a7
		move.w	d3,-(a7)
		move.l	a7,a1
		bsr	_PrintArgs
		addq.l	#4,a7
		rts

.padrb		lea	(.adrb),a0
		movem.w	d3-d4,-(a7)
		move.l	a7,a1
		bsr	_PrintArgs
		addq.l	#4,a7
		rts

.adr		dc.b	"$%04x",0
.adrb		dc.b	"$%04x.%x",0
.space		dc.b	" ",0
.byte		dc.b	"%02lx",0
.line		dc.b	" %08lx %08lx %08lx %08lx %08lx %08lx %08lx %08lx",10,0
	EVEN
