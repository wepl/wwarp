;*---------------------------------------------------------------------------
;  :Program.	cmdw.s
;  :Contents.	command w - write
;  :Author.	Bert Jahn
;  :Version	$Id: cmdw.s 1.28 2020/03/14 14:10:59 wepl Exp wepl $
;  :History.	18.03.01 separated from wwarp.asm
;		20.10.01 verify supports multiple syncs now
;		21.10.01 multiple syncs added
;		31.10.01 bug in post gap data fixed, drive inhibit added
;		26.04.02 writelen can be calculated on HD floppy drive
;		01.11.02 TF_SLEQ added
;		02.11.02 rework for new sync-search
;		01.12.02 sybil started
;		18.12.02 raw write fixed
;		01.01.04 more descriptive verify error messages (Codetapper)
;		11.02.04 adapted for MULTISYNC
;		01.07.04 sybil handling fixed
;		08.04.05 _unpacktrack fixed for special handling
;		23.04.08 Open/CloseDevice removed
;  :Requires.	OS V37+, MC68020+
;  :Copyright.	©1998-2008 Bert Jahn, All Rights Reserved
;  :Language.	68020 Assembler
;  :Translator.	Barfly V2.9
;  :To Do.
;---------------------------------------------------------------------------*

_cmd_write	bsr	_cmdw_init
		tst.l	d0
		beq	_rts

	;main
		move.l	#CMDF_IN|CMDF_TRKDATA,d0	;flags
		lea	_cmdw_tracktable,a1		;cbtt
		lea	_cmdw_tracks,a2			;cbt
		bsr	_cmdwork

		bra	_cmdw_finit

_cmdw_init

	;inhibit drive
		move.l	(gl_rd_unit,GL),d0
		lsl.w	#8,d0
		add.l	#"DF0:",d0
		clr.l	-(a7)
		move.l	d0,-(a7)
		move.l	a7,d1
		moveq	#-1,d2
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOInhibit,a6)
		addq.l	#8,a7

	;init SYBIL
		tst.l	(gl_rd_sybil,GL)
		beq	.nosybil
		bsr	_sybil_init
		tst.l	d0
		bne	.nosybil
		bsr	_cmdw_sybilerr
		moveq	#0,d0
		rts
.nosybil
		moveq	#-1,d0
		rts

_cmdw_finit
		bsr	_sybil_finit
_cmdw_sybilerr

	;deinhibit drive
		move.l	(gl_rd_unit,GL),d0
		lsl.w	#8,d0
		add.l	#"DF0:",d0
		clr.l	-(a7)
		move.l	d0,-(a7)
		move.l	a7,d1
		moveq	#0,d2
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOInhibit,a6)
		addq.l	#8,a7

		rts

	;copy tabarg to tabout so that the trackdata for all tracks
	;to write will read
_cmdw_tracktable
		lea	(gl_tabarg,GL),a0
		lea	(gl_tabread,GL),a1
		bsr	_copytt
		moveq	#-1,d0
		rts

_cmdw_tracks	cmp.w	#TT_RAW,(gl_trk+wth_type,GL)
		beq	_cmdw_raw

_cmdw_custom
		bsr	_gettt
		move.l	a0,a2				;A2 = format

	;get length, print info
		move.l	(wwf_name,a2),-(a7)
		move.w	(gl_trk+wth_num,GL),-(a7)
		clr.w	-(a7)
		lea	(_wtrack),a0
		move.l	a7,a1
		bsr	_PrintArgs
		addq.l	#8,a7

	;dos standard has special routine
		cmp.w	#TT_STD,(gl_trk+wth_type,GL)
		beq	.std
		cmp.w	#TT_STDF,(gl_trk+wth_type,GL)
		beq	.std

	;density control
		tst.l	(wwf_density,a2)
		beq	.nodens
		tst.b	(gl_sybil_init,GL)
		bne	.densok0
		lea	(_densrequired),a0
		bsr	_Print
		bra	.failed
.densok0	tst.w	(wwf_index,a2)
		bne	.densbad0
		btst	#WWFB_INDEX,(wwf_flags+1,a2)
		beq	.nodens
.densbad0	lea	(_densindex),a0
		bsr	_Print
		bra	.failed
.nodens

	;calculate drive capabilties
		move.w	(gl_trk+wth_num,GL),d0
		move.w	(wwf_writelen,a2),d1
		move.l	(gl_io,GL),a0
		bsr	_calcdrive
		tst.l	d0
		beq	.failed

	;density control: calculate gaplen/drivelen/writelen
	;RPM:	300/min = 5/s > 0.2s
	;Dens:	2us/bit = 16us/byte
		move.l	(wwf_density,a2),d0
		beq	.nodens2
		move.l	d0,a6
	;calc gaplen
	;ln,gap = length in bytes
	;dn = density in ns/bit
	;(gap+l0)*d0 + l1*d1 + ... = 0.2s
	;gap = (0.2s - ... - l1*d1 -l0*d0) / d0
		move.l	#200000000,d2	;ns
		moveq	#0,d7			;custom mfm length
		move.w	(2,a6),d1		;d0
.densloop	move.w	(a6)+,d0
		add.w	d0,d7
		mulu.w	(a6)+,d0
		lsl.l	#3,d0
		sub.l	d0,d2
		tst.w	(a6)
		bne	.densloop
		cmp.w	(wwf_writelen,a2),d7
		beq	.densok1
		lea	(_densbadlen),a0
		bsr	_Print
		bra	.failed
.densok1	divu.w	d1,d2			;div first density
		ext.l	d2
		lsl.l	#3,d7			;bytes -> bits
		add.l	d2,d7
		move.l	d7,(gl_drivelen,GL)
		add.l	#WRITEDRVTOL*8+15,d7
		lsr.l	#4,d7			;bits -> words
		add.l	d7,d7			;words -> bytes
		move.l	d7,(gl_writelen,GL)
.nodens2

	; the implementation of index writes is not optimized, because it
	; would not be necessary that writelen+index < drivelen, but with
	; the current formats its fine. for a general solution writelen
	; must be modified for index

	;check rawlen
		moveq	#0,d0
		move.w	(wwf_writelen,a2),d0
		add.w	(wwf_index,a2),d0
		addq.l	#2,d0				;security
		lsl.l	#3,d0
		cmp.l	(gl_drivelen,GL),d0
		bhs	_cmdw_longtrk

	;encode mfm-data
		move.w	(gl_trk+wth_num,GL),d0		;track number
		ext.l	d0
		moveq	#0,d6
		move.w	(wwf_index,a2),d6		;D6 = custom start
		move.l	d6,d7
		beq	.noidx
		add.w	(wwf_writelen,a2),d7		;D7 = custom end
		bra	.seta0
.noidx		add.l	(gl_writelen,GL),d7
		subq.l	#2,d7
		move.l	d7,d6
		sub.w	(wwf_writelen,a2),d6
.seta0		move.l	(gl_chipbuf,GL),a0		;destination buffer
		move.l	#$a0a0a0a0,(-2,a0,d6.l)		;for postcheck start
		move.l	#$e0e0e0e0,(-2,a0,d7.l)		;for postcheck end
		add.l	d6,a0
		move.l	d6,(gl_pregap,GL)		;for density writes
		lea	(gl_tmpbuf,GL),a1		;source data to encode
		move.l	(wwf_encode,a2),d1
		beq	_cmdw_encoder_na
		movem.l	d2-d7/a2-a6,-(a7)
		jsr	(d1.l)
		movem.l	(a7)+,_MOVEMREGS
		tst.l	d0
		beq	_cmdw_encoder_fail
		cmp.w	(wwf_writelen,a2),d0
		bne	_cmdw_encoder_badlen
	;dump encoded mfm
		moveq	#1,d0
		sub.l	(gl_rd_dbg,GL),d0
		bcc	.nodbg
		lea	_mfmencode,a0
		bsr	_Print
		move.l	(gl_chipbuf,GL),a0
		move.l	(gl_writelen,GL),d0
		moveq	#0,d1
		bsr	_DumpMemory
.nodbg
	;check encoded data end
		move.l	(gl_chipbuf,GL),a1		;destination buffer
		move.l	a1,a0
		add.l	(gl_writelen,GL),a0
		add.l	d7,a1
		cmp.w	#$e0e0,(a1)
		bne	_cmdw_encoder_badend
		cmp.b	#$e0,-(a1)
		beq	_cmdw_encoder_badend
		move.w	#$5555,d0
		btst	#0,(a1)+
		bne	.1
		ror.w	#1,d0
.1		move.w	d0,(a1)+
		cmp.l	a0,a1
		blo	.1
	;check encoded data start
		move.l	(gl_chipbuf,GL),a1		;destination buffer
		add.l	d6,a1
		cmp.b	#$a0,(a1)
		beq	_cmdw_encoder_badstrt
		cmp.w	#$a0a0,(-2,a1)
		bne	_cmdw_encoder_badstrt
		move.l	#$55555555,d0
		tst.b	(a1)
		bpl	.2
		ror.l	#1,d0
.2		move.l	a1,d1
		sub.l	(gl_chipbuf,GL),d1
		ble	_cmdw_encoder_fail
		lsr.l	#1,d1
		bcc	.3
		move.b	d0,-(a1)
.3		lsr.l	#1,d1
		bcc	.4
		move.w	d0,-(a1)
		bra	.4
.5		move.l	d0,-(a1)
.4		dbf	d1,.5

	;check for invalid mfm-data
		tst.l	(gl_rd_dbg,GL)
		beq	.nodbgmfm

		move.l	(gl_chipbuf,GL),a1		;destination buffer
		move.l	(gl_writelen,GL),d0
		lsl.l	#3,d0				;bytes
		subq.l	#2,d0
	;first 2 bits
		bfextu	(a1){d0:2},d1
		cmp.w	#%11,d1
		beq	.many11
		subq.l	#1,d0
	;first 3 bits
		bfextu	(a1){d0:2},d1
		cmp.w	#%11,d1
		beq	.many11
		subq.l	#1,d0
	;loop
.chk		bfextu	(a1){d0:2},d1
		cmp.w	#%11,d1
		beq	.many11
		bfextu	(a1){d0:4},d1
		beq	.many0000
.chkin		subq.l	#1,d0
		bpl	.chk
		bra	.nodbgmfm

.many11		lea	_dbgmfm11,a0
		bra	.many
.many0000	lea	_dbgmfm0000,a0
.many		movem.l	d0/a1,-(a7)
		bsr	_Print
		move.l	(a7),d0
		bsr	_printbitlen
		lea	_dbgmfm,a0
		move.l	(a7),d0
		sub.l	#16,d0
		lsr.l	#3,d0
		move.l	(gl_chipbuf,GL),a1
		add.l	d0,a1
		move.l	(a1),-(a7)
		move.l	d0,-(a7)
		move.l	a7,a1
		bsr	_PrintArgs
		addq.l	#8,a7
		bsr	_CheckBreak
		tst.l	d0
		bne	.chkbrk
		movem.l	(a7)+,d0/a1
		bra	.chkin

.chkbrk		add.l	#8,a7
.failed		moveq	#0,d0
		rts

.nodbgmfm

	IFEQ 1
		move.l	(gl_chipbuf,GL),a0
		move.l	#$400,d0
		moveq	#0,d1
		bsr	_DumpMemory
		move.l	(gl_fastbuf,GL),a0
		move.l	#$400,d0
		moveq	#0,d1
		bsr	_DumpMemory
		lea	(gl_tmpbuf,GL),a0
		move.l	#$400,d0
		moveq	#0,d1
		bsr	_DumpMemory
		lea	(gl_verbuf,GL),a0
		move.l	#$400,d0
		moveq	#0,d1
		bsr	_DumpMemory
	ENDC

	;write and flush track
		moveq	#0,d0
		btst	#WWFB_INDEX,(wwf_flags+1,a2)
		beq	.noindex
		moveq	#IOTDF_INDEXSYNC,d0
.noindex	move.l	(wwf_density,a2),a0
		bsr	_cmdw_writeraw
		tst.l	d0
		bne	_cmdw_werr
	;verify?
		tst.l	(gl_rd_nover,GL)
		bne	.suc
	;clear trackbuffer
		move.l	(gl_io,GL),a1
		move.w	#ETD_CLEAR,(IO_COMMAND,a1)
		move.l	(gl_execbase,GL),a6
		jsr	(_LVODoIO,a6)
		move.l	(gl_io,GL),a1
		move.b	(IO_ERROR,a1),d0
		bne	_cmdw_werr
	;read track
		move.l	(gl_io,GL),a1
		move.l	(gl_chipbuf,GL),(IO_DATA,a1)
		moveq	#0,d0
		move.w	(gl_trk+wth_num,GL),d0
		move.l	d0,(IO_OFFSET,a1)
		bsr	_tdenable81
		move.l	(gl_writelen,GL),d5
		add.l	d5,d5
		cmp.l	#MAXTDLEN,d5
		bls	.lenok
		move.l	#MAXTDLEN,d5			;D5 = readlen
.lenok		move.l	d5,(IO_LENGTH,a1)
		move.w	#ETD_RAWREAD,(IO_COMMAND,a1)
		moveq	#IOF_QUICK,d0
		btst	#WWFB_INDEX,(wwf_flags+1,a2)
		beq	.noindex2
		moveq	#IOTDF_INDEXSYNC,d0
.noindex2	move.b	d0,(IO_FLAGS,a1)
		clr.b	(IO_ERROR,a1)
		move.l	(IO_DEVICE,a1),a6
		jsr	(DEV_BEGINIO,a6)
		move.l	(gl_io,GL),a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOWaitIO,a6)
		move.l	(gl_io,GL),a1
		bsr	_tddisable81
		move.b	(IO_ERROR,a1),d0
		bne	_cmdw_rerr
	;copy mfm data to fast mem for better performance
		move.l	d5,d0
		bsr	_copy_c2f
	IFEQ 1
		move.l	(gl_chipbuf,GL),a0
		move.l	#$400,d0
		moveq	#0,d1
		bsr	_DumpMemory
		move.l	(gl_fastbuf,GL),a0
		move.l	#$400,d0
		moveq	#0,d1
		bsr	_DumpMemory
		lea	(gl_tmpbuf,GL),a0
		move.l	#$400,d0
		moveq	#0,d1
		bsr	_DumpMemory
		lea	(gl_verbuf,GL),a0
		move.l	#$400,d0
		moveq	#0,d1
		bsr	_DumpMemory
	ENDC
	;decode
		sf	d4				;sync found?
		move.l	(wwf_sync,a2),a3		;A3 = sync table
		moveq	#1,d3				;sync count
		btst	#WWFB_MULTISYNC,(wwf_flags+1,a2)
		beq	.syncloop
		move.w	(a3)+,d3
.syncloop	moveq	#-1,d2				;offset
.decode		addq.l	#1,d2
		move.l	d2,d0
		move.l	d5,d1
		lsl.l	#3,d1				;mfm length in bits
		move.l	(gl_fastbuf,GL),a0		;buffer
		move.l	a3,a1				;sync
		bsr	_searchsync
		tst.l	d0
		bpl	.decode1
		add.w	#2*SYNCLEN,a3
		subq.w	#1,d3
		bne	.syncloop
		tst.b	d4
		beq	_cmdw_verrsync
		bra	_cmdw_verrdec
.decode1	st	d4				;sync found
		move.l	d0,d2				;offset
		move.l	d5,d0
		lsl.l	#3,d0				;mfm length in bits
		move.w	(gl_trk+wth_num,GL),d1		;track number
		ext.l	d1
		move.l	(gl_fastbuf,GL),a0		;mfm buffer
		lea	(gl_verbuf,GL),a1		;decoded buffer
		movem.l	d2-d7/a2-a6,-(a7)
		jsr	([wwf_decode,a2])
		movem.l	(a7)+,_MOVEMREGS
		tst.l	d0
		beq	.decode

	;compare
	IFEQ 1
		lea	(gl_tmpbuf,GL),a0
		moveq	#0,d0
		move.w	(wwf_datalen,a2),d0
		moveq	#0,d1
		bsr	_DumpMemory
		lea	(gl_verbuf,GL),a0
		moveq	#0,d0
		move.w	(wwf_datalen,a2),d0
		moveq	#0,d1
		bsr	_DumpMemory
	ENDC
		lea	(gl_tmpbuf,GL),a0
		lea	(gl_verbuf,GL),a1
		move.w	(wwf_speclen,a2),d0
		add.w	(wwf_datalen,a2),d0
		move.b	d0,d1
		lsr.w	#2,d0
		subq.w	#1,d0
.cmp		cmp.l	(a0)+,(a1)+
		dbne	d0,.cmp
		bne	_cmdw_verrcmp
		and.w	#3,d1
		beq	.suc
		subq.w	#1,d1
.cmp1		cmp.b	(a0)+,(a1)+
		dbne	d1,.cmp1
		bne	_cmdw_verrcmp

.suc		moveq	#-1,d0
		rts

	;write track
.std		move.l	(gl_io,GL),a1
		lea	(gl_tmpbuf,GL),a0
		move.l	a0,(IO_DATA,a1)
		moveq	#0,d0
		move.w	(gl_trk+wth_num,GL),d0
		move.l	d0,d1
		mulu	#$1600,d1
		move.l	d1,(IO_OFFSET,a1)
		bsr	_tdenable81
		move.l	#$1600,(IO_LENGTH,a1)
		move.w	#ETD_FORMAT,(IO_COMMAND,a1)
		cmp.l	#DD_SECS,(gl_io+8+dg_TotalSectors,GL)
		beq	.nohd
		move.w	#ETD_WRITE,(IO_COMMAND,a1)
.nohd		clr.b	(IO_ERROR,a1)
		move.l	(gl_execbase,GL),a6
		jsr	(_LVODoIO,a6)
		move.l	(gl_io,GL),a1
		bsr	_tddisable81
		move.l	(gl_io,GL),a1
		move.b	(IO_ERROR,a1),d0
		bne	_cmdw_werr
	;flush
		move.l	(gl_io,GL),a1
		move.w	#ETD_UPDATE,(IO_COMMAND,a1)
		jsr	(_LVODoIO,a6)
		move.l	(gl_io,GL),a1
		move.b	(IO_ERROR,a1),d0
		bne	_cmdw_werr
	;verify?
		tst.l	(gl_rd_nover,GL)
		bne	.suc
	;clear trackbuffer
		move.l	(gl_io,GL),a1
		move.w	#ETD_CLEAR,(IO_COMMAND,a1)
		jsr	(_LVODoIO,a6)
		move.l	(gl_io,GL),a1
		move.b	(IO_ERROR,a1),d0
		bne	_cmdw_werr
	;read track
		move.l	(gl_io,GL),a1
		move.l	(gl_fastbuf,GL),(IO_DATA,a1)
		moveq	#0,d0
		move.w	(gl_trk+wth_num,GL),d0
		move.l	d0,d1
		mulu	#$1600,d1
		move.l	d1,(IO_OFFSET,a1)
		bsr	_tdenable81
		move.l	#$1600,(IO_LENGTH,a1)
		move.w	#ETD_READ,(IO_COMMAND,a1)
		jsr	(_LVODoIO,a6)
		move.l	(gl_io,GL),a1
		bsr	_tddisable81
		move.l	(gl_io,GL),a1
		move.b	(IO_ERROR,a1),d0
		bne	_cmdw_rerr
	;compare
		lea	(gl_tmpbuf,GL),a0
		move.l	(gl_fastbuf,GL),a1
		move.w	#$1600/4-1,d0
.cmps		cmp.l	(a0)+,(a1)+
		dbne	d0,.cmps
		beq	.suc
	;verify error
		bra	_cmdw_verrcmp

;----------------------------------------

PRESECGAP = 4	; bits before write length prepended for security and drive speed tolerance
PREMAXGAP = 256	; maximum data length before data to write, to make sure that the data to
		; write will not start too late after the index sync
POSTSECGAP = 4	; bits after write length appended for security

_cmdw_raw

	;calculate drive capabilties
		move.w	(gl_trk+wth_num,GL),d0
		move.l	(gl_trk+wth_wlen,GL),d1
		bne	.calgo
		move.l	(gl_trk+wth_len,GL),d1
		addq.l	#7,d1
		lsr.l	#3,d1
		btst	#TFB_RAWSINGLE,(gl_trk+wth_flags+1,a2)
		bne	.calgo
		move.l	#DEFWRITELEN,d1
.calgo		move.l	(gl_io,GL),a0
		bsr	_calcdrive
		tst.l	d0
		bne	.calcok
		moveq	#0,d0
		rts
.calcok

	;info
		lea	(_writetrk),a0
		lea	(gl_trk+wth_num,GL),a1
		bsr	_PrintArgs

	;set raw write len
	;length specified
		move.l	(gl_trk+wth_wlen,GL),d7
		addq.l	#1,d7
		bclr	#0,d7				;round up to word length
		lsl.l	#3,d7				;d7 = data write length in bits
		beq	.nowlen
		move.l	d7,d0
		add.l	#PRESECGAP+POSTSECGAP,d0
		cmp.l	(gl_drivelen,GL),d0
		bhi	_cmdw_longtrk
		bra	.wlenok
	;if not specified use either drivelen or tracklen, whatever is shorter
.nowlen		move.l	(gl_drivelen,GL),d7
		sub.l	#PRESECGAP+POSTSECGAP,d7	;security
		cmp.l	(gl_trk+wth_len,GL),d7
		blo	.wlenround
		move.l	(gl_trk+wth_len,GL),d7
.wlenround	and.b	#$f0,d7
.wlenok

	;info
		move.l	d7,d0
		bsr	_printbitlen
		lea	(_writebytes),a0
		bsr	_Print
		bsr	_FlushOutput

	;check if sync is set
		lea	(gl_trk+wth_sync,GL),a0
		bsr	_getsynclen
		tst.l	d0
		beq	_cmdw_nosyncset

	;search and count syncs
		bsr	_getsyncsearchlen
		move.l	d0,d3				;d3 = bitlength buffer

		moveq	#0,d0
		move.w	(gl_trk+wth_syncnum,GL),d0	;syncno
		move.l	d3,d1				;buflen
		lea	(gl_tmpbuf,GL),a0		;buffer
		lea	(gl_trk+wth_sync,GL),a1		;sync
		bsr	_countsync
		tst.l	d1
		beq	_cmdw_nosync
		move.l	d0,d6				;D6 = bit offset sync
		bmi	_cmdw_lesssync
		tst.w	(gl_trk+wth_syncnum,GL)
		bne	.onesync
		cmp.w	#1,d1
		beq	.onesync
		lea	(_moresync),a0
		move.l	d1,-(a7)
		move.l	a7,a1
		bsr	_PrintArgs
		addq.l	#4,a7
		bsr	_FlushOutput
.onesync

	;check for enough data after sync
		move.l	(gl_trklen,GL),d2
		sub.l	d6,d2
		cmp.l	d7,d2
		blo	_cmdw_lesstrkdata

	;build data to write
		move.l	(gl_writelen,GL),d5
		lsl.l	#3,d5
		sub.l	d7,d5
		sub.l	#POSTSECGAP,d5			;D5 = pre fill length
		cmp.l	#PREMAXGAP,d5
		bls	.pregapok
		move.l	#PREMAXGAP,d5
.pregapok
	;copy data
		lea	(gl_tmpbuf,GL),a0
		move.l	(gl_chipbuf,GL),a1

		moveq	#32,d4				;D4 = 32
		move.l	d5,d2
		move.l	d7,d0
		move.l	d6,d3

.copy		bfextu	(a0){d3:32},d1
		bfins	d1,(a1){d2:32}
		add.l	d4,d3
		add.l	d4,d2
		sub.l	d4,d0
		bcc	.copy

	;post gap
		move.l	#$55555555,d0
		move.l	d5,d1
		add.l	d7,d1
		subq.l	#1,d1
		bftst	(a1){d1:1}			;last bit of data to write
		bne	.p1
		ror.l	#1,d0
.p1		addq.l	#1,d1				;first bit to write
		move.l	(gl_writelen,GL),d2
		lsl.l	#3,d2
		sub.l	d1,d2				;amount of bits to write
		bra	.p6

.p5		bfins	d0,(a1){d1:32}
		add.l	d4,d1
		sub.l	d4,d2
.p6		cmp.l	d4,d2
		bhi	.p5
		bfins	d0,(a1){d1:d2}

	;pre gap
		move.l	#$55555555,d0
		bftst	(a1){d5:1}			;first bit of data to write
		beq	.p2
		ror.l	#1,d0
.p2		move.l	d5,d2
		bra	.p4

.p3		sub.l	d4,d2
		bfins	d0,(a1){d2:32}
.p4		cmp.l	d4,d2
		bhi	.p3
		bfins	d0,(a1){0:d2}

	;write and flush track
		moveq	#IOTDF_INDEXSYNC,d0
		sub.l	a0,a0				;density
		bsr	_cmdw_writeraw
		tst.l	d0
		bne	_cmdw_werr
	;verify?
		tst.l	(gl_rd_nover,GL)
		bne	.suc
	;clear trackbuffer
		move.l	(gl_io,GL),a1
		move.w	#ETD_CLEAR,(IO_COMMAND,a1)
		jsr	(_LVODoIO,a6)
		move.l	(gl_io,GL),a1
		move.b	(IO_ERROR,a1),d0
		bne	_cmdw_werr
	;read track
		move.l	(gl_io,GL),a1
		move.l	(gl_chipbuf,GL),(IO_DATA,a1)
		moveq	#0,d0
		move.w	(gl_trk+wth_num,GL),d0
		move.l	d0,(IO_OFFSET,a1)
		move.l	(gl_writelen,GL),d5
		add.l	d5,d5
		cmp.l	#MAXTDLEN,d5
		bls	.lenok
		move.l	#MAXTDLEN,d5			;D5 = readlen
.lenok		move.l	d5,(IO_LENGTH,a1)
		move.w	#ETD_RAWREAD,(IO_COMMAND,a1)
		move.w	(gl_trk+wth_num,GL),d0
		bsr	_tdenable81
		jsr	(_LVODoIO,a6)
		move.l	(gl_io,GL),a1
		bsr	_tddisable81
		move.b	(IO_ERROR,a1),d0
		bne	_cmdw_rerr
	;copy mfm data to fast mem for better performance
		move.l	d5,d0
		bsr	_copy_c2f

	;search sync
		moveq	#1,d0				;syncno
		move.l	(gl_writelen,GL),d1
		lsl.l	#3,d1				;buflen
		move.l	(gl_fastbuf,GL),a0
		lea	(gl_trk+wth_sync,GL),a1
		bsr	_countsync
		move.l	d0,d3				;D3 = bit offset first sync
		move.l	d1,d5				;D5 = sync count
		beq	_cmdw_verrsync
		cmp.w	#1,d5
		beq	.vonesync
		lea	(_moreverifysync),a0
		move.l	d5,-(a7)
		move.l	a7,a1
		bsr	_PrintArgs
		addq.l	#4,a7
		bsr	_FlushOutput
.vonesync

	;compare beginning from start
.compare	lea	(gl_tmpbuf,GL),a0
		move.l	(gl_fastbuf,GL),a1
		move.l	d7,d2				;bit length to write/compare
		moveq	#32,d4				;D4 = 32
.cmp		bfextu	(a0){d6:32},d0
		bfextu	(a1){d3:32},d1
		cmp.l	d0,d1
		bne	.verr
		sub.l	d4,d2
		addq.l	#4,a0
		addq.l	#4,a1
		cmp.l	d4,d2
		bhs	.cmp
		tst.l	d2
		beq	.suc
		bfextu	(a0){d6:d2},d0
		bfextu	(a1){d3:d2},d1
		ror.l	d2,d0				;for correct error position
		ror.l	d2,d1
		cmp.l	d0,d1
		bne	.verr

.suc
	;info
		lea	(_writesuc),a0
		bsr	_Print

		moveq	#-1,d0
		rts

.verr		subq.l	#1,d5				;syncs left?
		beq	.verr0

		move.l	d3,d0
		addq.l	#1,d0				;offset
		move.l	(gl_writelen,GL),d1		;buflen
		lsl.l	#3,d1
		move.l	(gl_fastbuf,GL),a0
		lea	(gl_trk+wth_sync,GL),a1
		bsr	_searchsync
		move.l	d0,d3
		bra	.compare

.verr0		move.l	d7,d5
		sub.l	d2,d5				;d5 = offset start
		moveq	#0,d2
		moveq	#0,d3
		subq.l	#1,d5
.verr1		addq.l	#1,d5
		addx.l	d0,d0
		addx.l	d2,d2
		addx.l	d1,d1
		addx.l	d3,d3
		cmp.w	d2,d3
		beq	.verr1

	;compare beginning from end
		lea	(gl_tmpbuf,GL),a0
		move.l	(gl_fastbuf,GL),a1
		add.l	d7,d6
		add.l	d7,d3
.cmp2		subq.l	#4,a0
		subq.l	#4,a1
		bfextu	(a0){d6:32},d0
		bfextu	(a1){d3:32},d1
		cmp.l	d0,d1
		bne	.verr2
		sub.l	d4,d7
		cmp.l	d4,d7
		bhs	.cmp2
		bfextu	(a0){d6:d7},d0
		bfextu	(a1){d3:d7},d1

.verr2		moveq	#0,d2
		moveq	#0,d3
.verr3		sub.l	#1,d7
		roxr.l	#1,d0
		addx.l	d2,d2
		roxr.l	#1,d1
		addx.l	d3,d3
		cmp.w	d2,d3
		beq	.verr3

		move.l	d5,d0
		move.l	d7,d1
		bra	_cmdw_verroff

;----------------------------------------

_cmdw_werr	lea	(_writedisk),a0
		bsr	_PrintErrorTD
		moveq	#0,d0
		rts

_cmdw_rerr	lea	(_readdisk),a0
		bsr	_PrintErrorTD
		moveq	#0,d0
		rts

_cmdw_nosync	lea	(_nosync),a0
_cmdw_error	bsr	_Print
		moveq	#0,d0
		rts

_cmdw_encoder_na
		lea	_encoder_na,a0
		bra	_cmdw_error
_cmdw_encoder_badlen
		lea	_encoder_badlen,a0
		bra	_cmdw_error
_cmdw_encoder_badend
		lea	_encoder_badend,a0
		bra	_cmdw_error
_cmdw_encoder_badstrt
		lea	_encoder_badstrt,a0
		bra	_cmdw_error
_cmdw_encoder_fail
		lea	_encoder_fail,a0
		bra	_cmdw_error

_cmdw_lesssync	lea	(_lesssync),a0
		bra	_cmdw_error

_cmdw_nosyncset	lea	(_nosyncset),a0
		bra	_cmdw_error

_cmdw_corrupt	lea	(_corrupt),a0
		bra	_cmdw_error

_cmdw_verrsync	lea	(_verifyerrsync),a0
		bra	_cmdw_error

_cmdw_verrdec	lea	(_verifyerrdec),a0
		bra	_cmdw_error

_cmdw_verrcmp	lea	(_verifyerrcmp),a0
		bra	_cmdw_error

;	D0 = first offset in bits
;	D1 = last offset in bits
_cmdw_verroff	movem.l	d0-d1,-(a7)
		lea	(_verifyerroff1),a0
		bsr	_Print
		move.l	(a7)+,d0
		bsr	_printbitlen
		lea	(_verifyerroff2),a0
		bsr	_Print
		move.l	(a7)+,d0
		bsr	_printbitlen
		lea	(_verifyerroff3),a0
		bsr	_Print
		moveq	#0,d0
		rts

_cmdw_longtrk	lsr.l	#3,d0
		move.l	d0,-(a7)
		move.l	a7,a1
		lea	(_longtrk),a0
		bsr	_PrintArgs
		addq.l	#4,a7
		move.l	(gl_drivelen,GL),d0
		bsr	_printbitlen
		bsr	_PrintLn
		moveq	#0,d0
		rts

_cmdw_lesstrkdata
		lea	(_lesstrkdata1),a0
		bsr	_Print
		move.l	d2,d0
		bsr	_printbitlen
		lea	(_lesstrkdata2),a0
		bsr	_Print
		move.l	d7,d0
		bsr	_printbitlen
		lea	(_lesstrkdata3),a0
		bsr	_Print
		moveq	#0,d0
		rts

;----------------------------------------
; unpack track data, and copy to gl_tmpbuf
; IN:	_fastbuf track data
; OUT:	D0 = ULONG length in bits, or 0 on failure
;	gl_tmpbuf unpacked track data

_unpacktrack	movem.l	d2-d7,-(a7)

		cmp.w	#TT_RAW,(gl_trk+wth_type,GL)
		beq	.raw

		bsr	_gettt
		moveq	#0,d0
		move.w	(wwf_speclen,a0),d0		;D0 = speclen
		move.w	(wwf_datalen,a0),d2		;D2 = datalen
		move.l	d0,d4
		add.w	d2,d4				;D4 = speclen + datalen
		move.l	(gl_trk+wth_len,GL),d7		;in bits
		lsr.l	#1,d7
		bcs	.fail
		lsr.l	#1,d7
		bcs	.fail
		lsr.l	#1,d7
		bcs	.fail
		sub.l	d0,d7				;D7 = length
		bcs	.fail
		move.l	(gl_fastbuf,GL),a0		;A0 = fastbuf
		lea	(gl_tmpbuf,GL),a1		;A1 = tmpbuf

	;copy special
		bra	.copyspecin
.copyspec	move.b	(a0)+,(a1)+
.copyspecin	dbf	d0,.copyspec

		move.w	(gl_trk+wth_flags,GL),d0
		btst	#TFB_LEQ,d0
		bne	.leq
		btst	#TFB_SLINC,d0
		bne	.slinc
		btst	#TFB_SLEQ,d0
		bne	.sleq

		cmp.w	d2,d7
		bne	.fail
		addq.l	#3,d7				;round up
		lsr.w	#2,d7
		beq	.ok				;if datalen=0
		subq.w	#1,d7
.cpy		move.l	(a0)+,(a1)+
		dbf	d7,.cpy
		bra	.ok

.leq		cmp.l	#4,d7
		bne	.fail
		move.w	d2,d7
		lsr.w	#2,d7
		subq.w	#1,d7
		move.l	(a0),d1
.leq1		move.l	d1,(a1)+
		dbf	d7,.leq1
		bra	.ok

.slinc		move.w	d2,d0
		lsr.w	#9-2,d0
		cmp.w	d0,d7
		bne	.fail
		lsr.w	#2,d7
		subq.w	#1,d7
.slinc2		moveq	#$200/4-1,d6
		move.l	(a0)+,d1
.slinc1		move.l	d1,(a1)+
		addq.l	#1,d1
		dbf	d6,.slinc1
		dbf	d7,.slinc2
		bra	.ok

.sleq		move.w	d2,d0
		lsr.w	#9-2,d0
		cmp.w	d0,d7
		bne	.fail
		lsr.w	#2,d7
		subq.w	#1,d7
.sleq2		moveq	#$200/4-1,d6
		move.l	(a0)+,d1
.sleq1		move.l	d1,(a1)+
		dbf	d6,.sleq1
		dbf	d7,.sleq2

.ok		move.l	d4,d0
		lsl.l	#3,d0

.end		movem.l	(a7)+,_MOVEMREGS
		rts

.fail		lea	(_badtrkdatlen),a0
		bsr	_Print
		moveq	#0,d0
		bra	.end

.raw		bsr	_doubleraws
		move.l	d0,d7
		move.l	(gl_fastbuf,GL),a0		;A0 = fastbuf
		lea	(gl_tmpbuf,GL),a1		;A1 = tmpbuf
		add.l	#%11111,d7
		lsr.l	#3+2,d7
		subq.w	#1,d7
.rawcpy		move.l	(a0)+,(a1)+
		dbf	d7,.rawcpy
		bra	.end

;----------------------------------------
; check how many bits the drive can write
; IN:	D0 = UWORD  track
;	D1 = UWORD  writelen (in bytes), used with SYBIL mode only
;	A0 = STRUCT ioreq
; OUT:	D0 = BOOL   success
;	gl_drivelen average bits the drive can write (in bits)
;	gl_writelen length which should be written (in bytes)
;	_chipbuf destroyed!

_calcdrive	movem.l	d2-d7/a2-a3/a6,-(a7)
		move.l	a0,a3				;A3 = ioreq
		ext.l	d0
		move.l	d0,d6				;D6 = track
		move.w	d1,d7				;D7 = requested write len

		tst.b	(gl_sybil_init,GL)
		bne	.sybil

		tst.l	(gl_drivelen,GL)		;already calculated?
		bne	.ok

	;message calculating
		lea	.text,a0
		move.l	d6,-(a7)
		move.l	a7,a1
		bsr	_PrintArgs
		bsr	_FlushOutput
		addq.l	#4,a7
	;test speed
		move.l	d6,d0				;track
		move.l	#DEFWRITELEN,d1			;writelen
		cmp.l	#HD_SECS,(gl_io+8+dg_TotalSectors,GL)
		bne	.nohd
		add.l	d1,d1
.nohd		move.l	a3,a0				;ioreq
		bsr	_calcspeed
		move.l	d0,(gl_drivelen,GL)
		beq	.fail
	;calc writelen
.calcwlen	add.l	#WRITEDRVTOL*8+15,d0		;+WRITEDRVTOL bytes and round up
		cmp.l	#HD_SECS,(gl_io+8+dg_TotalSectors,GL)
		bne	.nohd1
		add.l	#WRITEDRVTOL*8,d0		;half speed -> double tolerance
.nohd1		lsr.l	#4,d0
		add.l	d0,d0
		move.l	d0,(gl_writelen,GL)
	;message success
		lea	.textsucc,a0
		lea	(gl_writelen,GL),a1
		bsr	_PrintArgs

.ok		moveq	#-1,d0
.quit		movem.l	(a7)+,_MOVEMREGS
		rts

.failsybil	bsr	_sybil_off
.fail		moveq	#0,d0
		bra	.quit

	;sybil mode
.sybil
	;adapt requested writelen
		add.w	#WRITEDRVTOL,d7
		cmp.l	#HD_SECS,(gl_io+8+dg_TotalSectors,GL)
		bne	.nohd2
		add.w	#WRITEDRVTOL,d7			;half speed -> double tolerance
.nohd2
	;check calibration
		tst.l	(gl_sybil_caltbl,GL)
		bne	.calok
	;calibrate SYBIL
.calibrate	lea	(.calib),a0
		bsr	_Print
		move.l	#DEFWRITELEN,d5			;D5 = writelen
		cmp.l	#HD_SECS,(gl_io+8+dg_TotalSectors,GL)
		bne	.nohd3
		add.l	d5,d5
.nohd3		move.l	#SYBILSTART-SYBILINC,d4		;D4 = ticks
		move.w	#SYBILTBLCNT-1,d3		;D3 = loop
		lea	(gl_sybil_caltbl,GL),a2		;A2 = caltbl
		bsr	_sybil_on
.cloop		bsr	_CheckBreak
		tst.l	d0
		bne	.failsybil
		add.l	#SYBILINC,d4
		move.l	a2,a1
		move.w	d4,(a2)
		lea	(.calib1),a0
		bsr	_PrintArgs
		move.w	d4,d0
		bsr	_sybil_setspeed
		move.l	d6,d0				;track
		move.l	d5,d1				;writelen
		move.l	a3,a0				;ioreq
		bsr	_calcspeed
		move.l	d0,d2
		lsr.l	#3,d2
	;	beq	.cloop
		beq	.failsybil
	;new writelen
		move.l	d2,d5
		mulu	#$14,d5
		lsr.l	#4,d5
	;write table
		lea	(2,a2),a1
		move.w	d2,(a1)
	;print message
		lea	(.calib2),a0
		bsr	_PrintArgs
	;check too short
		cmp.l	#MINTRACKLEN,d2
		blo	.cloop
	;check too long
		cmp.l	#MAXTRACKLEN,d2
		bhi	.writecal
		addq.l	#4,a2
		dbf	d3,.cloop
	;write calibration file
.writecal	bsr	_sybil_off
		bsr	_sybil_getname
		move.l	d0,d1
		move.l	#MODE_NEWFILE,d2
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOOpen,a6)
		move.l	d0,d4
		beq	.nocal
		move.l	d4,d1
		pea	"WWSC"
		move.l	a7,d2
		move.l	#4,d3
		jsr	(_LVOWrite,a6)
		addq.l	#4,a7
		cmp.l	d0,d3
		bne	.writeerr
		move.l	d4,d1
		lea	(gl_sybil_caltbl,GL),a0
		move.l	a0,d2
		move.l	#SYBILTBLLEN,d3
		jsr	(_LVOWrite,a6)
.writeerr
		move.l	d4,d1
		jsr	(_LVOClose,a6)
.nocal

	;search matching speed
.calok		move.w	#SYBILTBLCNT-1,d0
		lea	(gl_sybil_caltbl,GL),a0
.search		move.l	(a0)+,d1
		beq	.notfound
		cmp.w	d1,d7
		blo	.found
		dbf	d0,.search
.notfound	move.l	(-8,a0),-(a7)
		move.l	d7,-(a7)
		move.l	a7,a1
		lea	(.sybilnomatch),a0
		bsr	_PrintArgs
		addq.l	#8,a7
		bra	.fail

	;SYBIL already in that speed?
.found		move.w	d1,d4				;D4 = calibrated drivelen
		swap	d1
		cmp.w	(gl_sybil_ticks,GL),d1
		beq	.ok
	;setup SYBIL
		move.l	d1,-(a7)
		bsr	_sybil_on
		move.l	(a7)+,d0
		bsr	_sybil_setspeed
	;message calculating
		lea	.text,a0
		move.l	d6,-(a7)
		move.l	a7,a1
		bsr	_PrintArgs
		addq.l	#4,a7
		lea	(.sybilinf),a0
		lea	(gl_sybil_ticks,GL),a1
		bsr	_PrintArgs
		bsr	_FlushOutput
		move.l	d6,d0				;track
		move.l	d4,d1
		mulu	#$14,d1
		lsr.l	#4,d1				;writelen
		move.l	a3,a0				;ioreq
		bsr	_calcspeed
		move.l	d0,d2
		bsr	_sybil_off
		move.l	d2,(gl_drivelen,GL)
		beq	.fail
		lsr.l	#3,d2
		sub.w	d4,d2
		bpl	.pos
		neg.w	d2
.pos		cmp.w	#WRITEDRVTOL,d2
		blo	.tolok
	;tolerance too large
		lea	(.tollarge),a0
		clr.w	-(a7)
		move.w	d4,-(a7)
		move.l	a7,a1
		bsr	_PrintArgs
		addq.l	#4,a7
		bsr	_FlushOutput
		bsr	_GetKey
		move.b	d0,d2
		bsr	_PrintLn
		UPPER	d2
		cmp.b	#"Y",d2
		beq	.calibrate
		bra	.fail

.tolok		move.l	(gl_drivelen,GL),d0
		bra	.calcwlen


.text		dc.b	"testing drive/dma speed at track %ld,",0
.textsucc	dc.b	", using writelen $%lx.",10,0
.sybilnomatch	dc.b	"no matching speed found, want $%lx, last $%04x=$%x",10,0
.tollarge	dc.b	" tolerance too large, expected $%x, recalibrate? (yN) ",0
.sybilinf	dc.b	" sybil=$%04x,",0
.calib		dc.b	"starting calibration:",10,0
.calib1		dc.b	"$%04x ",0
.calib2		dc.b	" = $%4x",10,0
	EVEN

;----------------------------------------
; check how many bits the drive can write
; IN:	D0 = ULONG  track
;	D1 = ULONG  writelen to test
;	A0 = STRUCT ioreq
; OUT:	D0 = ULONG  length in bits
;	_chipbuf destroyed!

_calcspeed	movem.l	d2-d7/a2/a6,-(a7)

		move.l	d0,d2				;D2 = track number
		move.l	d1,d4				;D4 = writelen
		move.l	a0,a2				;A2 = ioreq
		moveq	#0,d6				;D6 = sum of lengths for calc

		move.l	d4,d5
		move.l	d4,d0
		lsr.l	#2,d0				; a quarter more
		add.l	d0,d5				;D5 = readlen
		moveq	#CALCDRVCNT-1,d7		;D7 = loop count
.loop

	;prepare mfm
		move.l	(gl_chipbuf,GL),a0
		move.l	#$55555555,d0
		move.l	d4,d1
		lsr.l	#2,d1
		subq.w	#3,d1
.prep		move.l	d0,(a0)+
		dbf	d1,.prep
		move.l	#$448a448a,(a0)+
		move.l	d0,(a0)

	;write track
		move.l	a2,a1
		move.l	(gl_chipbuf,GL),(IO_DATA,a1)
		move.l	d2,(IO_OFFSET,a1)
		move.l	d2,d0
		bsr	_tdenable81
		move.l	d4,(IO_LENGTH,a1)		;writelen
		move.w	#ETD_RAWWRITE,(IO_COMMAND,a1)
		move.b	#IOTDF_INDEXSYNC|IOF_QUICK,(IO_FLAGS,a1)
		clr.b	(IO_ERROR,a1)
		move.l	(IO_DEVICE,a1),a6
		jsr	(DEV_BEGINIO,a6)
		move.l	a2,a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOWaitIO,a6)
		move.l	a2,a1
		bsr	_tddisable81
		move.b	(IO_ERROR,a2),d0
		bne	.writeerr

	;flush trackdisk buffers
		move.l	a2,a1
		move.w	#ETD_UPDATE,(IO_COMMAND,a1)
		clr.b	(IO_FLAGS,a1)
		clr.b	(IO_ERROR,a1)
		jsr	(_LVODoIO,a6)
		move.l	a2,a1
		move.b	(IO_ERROR,a1),d0
		bne	.writeerr
		move.l	a2,a1
		move.w	#ETD_CLEAR,(IO_COMMAND,a1)
		clr.b	(IO_FLAGS,a1)
		clr.b	(IO_ERROR,a1)
		jsr	(_LVODoIO,a6)
		move.b	(IO_ERROR,a2),d0
		bne	.writeerr

	;read track
		move.l	a2,a1
		move.l	(gl_chipbuf,GL),(IO_DATA,a1)
		move.l	d2,(IO_OFFSET,a1)
		move.l	d2,d0
		bsr	_tdenable81
		move.l	d5,(IO_LENGTH,a1)		;readlen
		move.w	#ETD_RAWREAD,(IO_COMMAND,a1)
		move.b	#IOTDF_INDEXSYNC|IOF_QUICK,(IO_FLAGS,a1)
		clr.b	(IO_ERROR,a1)
		move.l	(IO_DEVICE,a1),a6
		jsr	(DEV_BEGINIO,a6)
		move.l	a2,a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOWaitIO,a6)
		move.l	a2,a1
		bsr	_tddisable81
		move.b	(IO_ERROR,a2),d0
		bne	.readerr

	;calculate
		moveq	#0,d0			;offset
		move.l	d5,d1			;readlen
		lsl.l	#3,d1			;buffer length
		move.l	(gl_chipbuf,GL),a0
		lea	(_sync_calc),a1
		bsr	_searchsync
		move.l	d0,d3
		bmi	.nosync
		addq.l	#1,d0
		move.l	d5,d1
		lsl.l	#3,d1			;buffer length
		move.l	(gl_chipbuf,GL),a0
		lea	(_sync_calc),a1
		bsr	_searchsync
		tst.l	d0
		bmi	.nosync
		sub.l	d3,d0
		add.l	d0,d6

	;message
		move.l	d0,-(a7)
		lea	.textlen,a0
		bsr	_Print
		move.l	(a7)+,d0
		bsr	_printbitlen
		bsr	_FlushOutput

		dbf	d7,.loop

		move.l	d6,d0
		divu.l	#CALCDRVCNT,d0
.quit
		movem.l	(a7)+,_MOVEMREGS
		rts

.writeerr	lea	(_writedisk),a0
		bsr	_PrintErrorTD
		bra	.fail

.readerr	lea	(_readdisk),a0
		bsr	_PrintErrorTD
		bra	.fail

.nosync		lea	.textsync,a0
		bsr	_Print

.fail		lea	.textfail,a0
		bsr	_Print
		moveq	#0,d0
		bra	.quit

.textfail	dc.b	"couldn't estimate write length capability!",10,0
.textlen	dc.b	" ",0
.textsync	dc.b	" sync not found",10,0
	EVEN

;----------------------------------------
; write track and flush buffer
; IN:	D0 = ULONG flags (IOTDF_INDEXSYNC)
;	A0 = APTR  density map
; OUT:	D0 = ULONG IO_ERROR

_cmdw_writeraw	move.l	a0,d1
	;	bne	.density
		move.l	d7,-(a7)
		move.l	d0,d7			;D7 = flags

	;enable SYBIL if wanted
		bsr	_sybil_on

	;write track
		move.l	(gl_io,GL),a1
		moveq	#0,d0
		move.w	(gl_trk+wth_num,GL),d0
		move.l	d0,(IO_OFFSET,a1)
		bsr	_tdenable81
		move.l	(gl_chipbuf,GL),(IO_DATA,a1)
		move.l	(gl_writelen,GL),(IO_LENGTH,a1)
		move.w	#ETD_RAWWRITE,(IO_COMMAND,a1)
		or.b	#IOF_QUICK,d7
		move.b	d7,(IO_FLAGS,a1)
		clr.b	(IO_ERROR,a1)
		move.l	(IO_DEVICE,a1),a6
		jsr	(DEV_BEGINIO,a6)
		move.l	(gl_io,GL),a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOWaitIO,a6)
		move.l	(gl_io,GL),a1
		bsr	_tddisable81
		move.b	(IO_ERROR,a1),d7
		bne	.error

	;flush
		move.l	(gl_io,GL),a1
		move.w	#ETD_UPDATE,(IO_COMMAND,a1)
		jsr	(_LVODoIO,a6)
		move.l	(gl_io,GL),a1
		move.b	(IO_ERROR,a1),d7
.error
	;disable SYBIL
		bsr	_sybil_off

		move.b	d7,d0
		extb.l	d0
		move.l	(a7)+,d7
		rts

.density	moveq	#-1,d0
		rts
	IFEQ 1
		movem.l	d2-d7/a2-a3/a6,-(a7)
		moveq	#-1,d5				;D5 = return code
		move.l	d0,d7				;D7 = trackdisk flags
		move.l	a0,a3				;A3 = density map

		move.l	(gl_execbase,GL),a6
		jsr	(_LVOCreateMsgPort,a6)
		move.l	d0,d6				;D6 = message port
		bne	.portok
		moveq	#0,d0
		lea	(_noport),a0
		sub.l	a1,a1
		bsr	_PrintError
		bra	.noport
.portok
		move.l	d6,a0
		move.l	#IOTV_SIZE,d0
		jsr	(_LVOCreateIORequest,a6)
		move.l	d0,a2				;A2 = timer ioreq
		tst.l	d0
		bne	.ioreqok
		moveq	#0,d0
		lea	(_noioreq),a0
		sub.l	a1,a1
		bsr	_PrintError
		bra	.noioreq
.ioreqok
		lea	(_timername),a0
		move.l	#UNIT_WAITECLOCK,d0		;unit
		move.l	a2,a1				;ioreq
		clr.b	(IO_FLAGS,a1)
		move.l	#0,d1				;flags
		jsr	(_LVOOpenDevice,a6)
		tst.l	d0
		beq	.deviceok
		move.b	(IO_ERROR,a2),d0
		lea	(_opendevice),a0
		bsr	_PrintErrorTD
		bra	.nodevice
.deviceok

	;enable SYBIL
		bsr	_sybil_on

	;calc first part
		move.l	(gl_pregap,GL),d2
		add.w	(a3)+,d2			;D2 = length
		move.w	(a3)+,d0

	;start disk write
		move.l	(gl_io,GL),a1
		moveq	#0,d0
		move.w	(gl_trk+wth_num,GL),d0
		move.l	d0,(IO_OFFSET,a1)
		bsr	_tdenable81
		move.l	(gl_chipbuf,GL),(IO_DATA,a1)
		move.l	(gl_writelen,GL),(IO_LENGTH,a1)
		move.w	#ETD_RAWWRITE,(IO_COMMAND,a1)
		or.b	#IOF_QUICK,d7
		move.b	d7,(IO_FLAGS,a1)
		clr.b	(IO_ERROR,a1)
		move.l	(IO_DEVICE,a1),a6
		jsr	(DEV_BEGINIO,a6)

		subq.l	#EV_SIZE,a7
		move.l	a7,a0
		move.l	(IO_DEVICE,a2),a6
		jsr	(_LVOReadEClock,a6)

.loop		move.w	(a3)+,d0
		addq.l	#2,a0
	;	...
		add.l	d0,(4,a7)
		moveq	#0,d0
	;	addx.l	d0,(a7)
		move.l	(a7),(IOTV_TIME,a2)
		move.l	(4,a7),(IOTV_TIME+4,a2)
		move.w	#TR_ADDREQUEST,(IO_COMMAND,a2)
		move.l	a2,a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVODoIO,a6)

		tst.w	(a3)
		bne	.loop


	;wait disk write end
		move.l	(gl_io,GL),a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOWaitIO,a6)
		move.l	(gl_io,GL),a1
		bsr	_tddisable81
		move.b	(IO_ERROR,a1),d5

	;disable SYBIL
		bsr	_sybil_off

		move.l	a2,a1
		jsr	(_LVOCloseDevice,a6)
.nodevice
		move.l	a2,a0
		jsr	(_LVODeleteIORequest,a6)
.noioreq
		move.l	d6,a0
		jsr	(_LVODeleteMsgPort,a6)
.noport
		move.b	d5,d0
		movem.l	(a7)+,_MOVEMREGS
		extb.l	d0
		rts
	ENDC

;----------------------------------------
; SYBIL stuff:
; parallel port (_ciaa+ciaprb) controls the hardware
; bit #0 bclr/bset make slower
; bit #1 bset/blcr set normal speed
; bit #2 0=enable 1=disable hardware
; parallel port select (#2,_ciab+ciapra) enables the parallel port

_ciaa	= $bfe001
_ciab	= $bfd000

;----------------------------------------
; initialize hardware
; IN:	-
; OUT:	D0 = success

_sybil_init	movem.l	d2-d3/d7/a6,-(a7)

		lea	(.miscname),a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOOpenResource,a6)
		move.l	d0,(gl_sybil_miscres,GL)
		beq	.nores
		move.l	d0,a6

		move.l	#MR_PARALLELPORT,d0
		lea	.myname,a1
		jsr	(MR_ALLOCMISCRESOURCE,a6)
		tst.l	d0
		bne	.noparport
		st	(gl_sybil_parport,GL)

		move.l	#MR_PARALLELBITS,d0
		lea	.myname,a1
		jsr	(MR_ALLOCMISCRESOURCE,a6)
		tst.l	d0
		bne	.noparbits
		st	(gl_sybil_parbits,GL)

	;read calibration file
		bsr	_sybil_getname
		move.l	d0,d1
		move.l	#MODE_OLDFILE,d2
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOOpen,a6)
		move.l	d0,d7
		beq	.nocal
		move.l	d7,d1
		lea	(gl_sybil_caltbl,GL),a0
		move.l	a0,d2
		move.l	#4,d3
		jsr	(_LVORead,a6)
		cmp.l	d0,d3
		bne	.readerr
		cmp.l	#"WWSC",(gl_sybil_caltbl,GL)
		bne	.readerr
		move.l	d7,d1
		lea	(gl_sybil_caltbl,GL),a0
		move.l	a0,d2
		move.l	#SYBILTBLLEN,d3
		jsr	(_LVORead,a6)
		cmp.l	d0,d3
		beq	.readok
.readerr	clr.l	(gl_sybil_caltbl,GL)	;checked later if table is loaded
.readok		move.l	d7,d1
		jsr	(_LVOClose,a6)
.nocal

	;set ciaa
		move.b	#%111,_ciaa+ciaddrb	;direction output
		bsr	_sybil_delay
		move.b	#%111,_ciaa+ciaprb	;data
		bsr	_sybil_delay

	;set ciab
		bset	#2,_ciab+ciaddra	;direction output
		bsr	_sybil_delay
		bclr	#2,_ciab+ciapra		;SEL parallel port on
		bsr	_sybil_delay

		bsr	_sybil_on
		bsr	_sybil_normal
		bsr	_sybil_off

		st	(gl_sybil_init,GL)

		moveq	#-1,d0

.end		movem.l	(a7)+,_MOVEMREGS
		rts

.nores		lea	.tnores,a0
		bra	.error
.noparport	lea	.tnoparport,a0
		bra	.error
.noparbits	lea	.tnoparbits,a0
.error		move.l	d0,-(a7)
		move.l	a7,a1
		bsr	_PrintArgs
		addq.l	#4,a7
		bsr	_sybil_finit
		moveq	#0,d0
		bra	.end

.miscname	dc.b	"misc.resource",0
.myname		dc.b	"WWarp",0
.tnores		dc.b	"sybil: cannot open misc.resource",10,0
.tnoparport	dc.b	"sybil: cannot allocate parallel port (already owned by %s)",10,0
.tnoparbits	dc.b	"sybil: cannot allocate parallel port bits (already owned by %s)",10,0
_sybil_name	dc.b	"S:WWarp-SYBIL-Calib-"
_sybil_name1	dc.b	"DD-Unit"
_sybil_name2	dc.b	"0",0
	EVEN

;----------------------------------------
; get calib cfg name
; IN:	-
; OUT:	D0 = CPTR cfg name

_sybil_getname	moveq	#'D',d0
		cmp.l	#HD_SECS,(gl_io+8+dg_TotalSectors,GL)
		bne	.nohd
		moveq	#'H',d0
.nohd		moveq	#'0',d1
		add.l	(gl_rd_unit,GL),d1
		lea	(_sybil_name),a0
		move.b	d0,(_sybil_name1-_sybil_name,a0)
		move.b	d1,(_sybil_name2-_sybil_name,a0)
		move.l	a0,d0
		rts

;----------------------------------------
; free sybil ressources
; IN:	-
; OUT:	-

_sybil_finit	movem.l	a6,-(a7)

		bclr	#0,(gl_sybil_init,GL)
		beq	.notinit
		bsr	_sybil_on
		bsr	_sybil_normal
		bsr	_sybil_off
		bset	#2,_ciab+ciapra		;SEL parallel port off
.notinit
		bclr	#0,(gl_sybil_parport,GL)
		beq	.noparport
		move.l	#MR_PARALLELPORT,d0
		move.l	(gl_sybil_miscres,GL),a6
		jsr	(MR_FREEMISCRESOURCE,a6)
.noparport
		bclr	#0,(gl_sybil_parbits,GL)
		beq	.noparbits
		move.l	#MR_PARALLELBITS,d0
		jsr	(MR_FREEMISCRESOURCE,a6)
.noparbits
		movem.l	(a7)+,_MOVEMREGS
		rts

;----------------------------------------
; set hardware active
; IN:	-
; OUT:	-

_sybil_on	tst.b	(gl_sybil_init,GL)
		beq	_rts
		bclr	#2,_ciaa+ciaprb		;enable
		bra	_sybil_delay

;----------------------------------------
; set hardware inactive
; IN:	-
; OUT:	-

_sybil_off	tst.b	(gl_sybil_init,GL)
		beq	_rts
		bset	#2,_ciaa+ciaprb		;disable
		bra	_sybil_delay

;----------------------------------------
; set normal speed
; IN:	-
; OUT:	-

_sybil_normal	clr.w	(gl_sybil_ticks,GL)
		bsr	_disable
		bset	#1,_ciaa+ciaprb		;reset
		bsr	_sybil_delay
		bclr	#1,_ciaa+ciaprb
		bsr	_sybil_delay
		bra	_enable

;----------------------------------------
; set speed by density
; IN:	D0 = UWORD density in ns per bitcell
; OUT:	-
; RPM:	300/min = 5/s > 0.2s
; Dens:	2us/bit = 16us/byte

_sybil_setdensity
		move.l	#200000000/8,d1		;ns for full track, bits -> bytes
		divu	d0,d1
		move.w	d1,d0

;----------------------------------------
; set speed by tracklen
; IN:	D0 = UWORD track length in bytes
; OUT:	-

_sybil_settrklen

;----------------------------------------
; set speed
; IN:	D0 = UWORD ticks to set
; OUT:	-

_sybil_setspeed	cmp.w	(gl_sybil_ticks,GL),d0
		beq	_rts
		bhi	.noreset
		bsr	_sybil_normal
.noreset	sub.w	(gl_sybil_ticks,GL),d0
		add.w	d0,(gl_sybil_ticks,GL)

;----------------------------------------
; make speed slower
; IN:	D0 = UWORD ticks to add
; OUT:	-

_sybil_slower	bsr	_disable
		subq.w	#1,d0
.1		bclr	#0,_ciaa+ciaprb
		bsr	_sybil_delay
		bset	#0,_ciaa+ciaprb
		bsr	_sybil_delay
		dbf	d0,.1

_enable		movem.l	d0/a6,-(a7)
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOEnable,a6)
		movem.l	(a7)+,d0/a6
		rts

_disable	movem.l	d0/a6,-(a7)
		move.l	(gl_execbase,GL),a6
		jsr	(_LVODisable,a6)
		movem.l	(a7)+,d0/a6
		rts

_sybil_delay	tst.b	_ciaa
	;	tst.b	_ciaa
		rts
