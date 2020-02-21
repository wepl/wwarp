;*---------------------------------------------------------------------------
;  :Program.	cmdc.s
;  :Contents.	command c - create
;  :Author.	Bert Jahn
;  :Version	$Id: cmdc.s 1.21 2008/05/06 21:54:18 wepl Exp wepl $
;  :History.	12.06.00 separated from wwarp.asm
;		28.06.00 adapted for _cmdwork
;		06.08.00 inter sector gap check improved
;		24.07.01 trackdisk Update and Clear added before doing a Read
;		01.11.02 TF_SLEQ added
;		02.11.02 rework for new sync-search
;		12.02.04 adapted for MULTISYNC
;		08.10.04 space inserted before trackdisk errors
;		02.02.04 trackwarp.library support added
;		22.03.05 option Force/S added
;		08.04.05 _packtrack added and improved (special handling)
;		23.04.08 Open/CloseDevice removed
;		27.04.08 new search routine for known formats using lookup table
;  :Requires.	OS V37+, MC68020+
;  :Copyright.	©1998-2008 Bert Jahn, All Rights Reserved
;  :Language.	68020 Assembler
;  :Translator.	Barfly V2.9
;  :To Do.
;---------------------------------------------------------------------------*

_cmd_create
		move.l	(gl_rd_import,GL),d0
		beq	.fromdev

.fromfile	lea	_tracksfile,a2		;cbt

	;print announcement
		move.l	d0,-(a7)
		pea	(gl_filename,GL)
		lea	(_txt_createfile),a0
		move.l	a7,a1
		bsr	_PrintArgs
		add.w	#8,a7

	;open library
		move.l	(gl_twbase,GL),d0
		bne	.libok
		moveq	#1,d0
		lea	(_twname),a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOOpenLibrary,a6)
		move.l	d0,(gl_twbase,GL)
		bne	.libok
		lea	(_twnolib),a0
		bsr	_Print
		bra	.notwlib
.libok		move.l	d0,a6

	;open file
		move.l	(gl_rd_import,GL),a0
		sub.l	a1,a1			;taglist
		move.l	d0,a6
		jsr	(_LVOtwOpen,a6)
		move.l	d0,(gl_twfh,GL)
		bne	.twfhok
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOIoErr,a6)
		move.l	d0,d1			;code
		lea	(_twnoopen),a0
		move.l	a0,d2			;header
		sub.l	#80,a7
		move.l	a7,d3			;buffer
		move.l	#80,d4			;buflen
		move.l	(gl_twbase,GL),a6
		jsr	(_LVOtwFault,a6)
		move.l	a7,a0
		bsr	_Print
		add.l	#80,a7
		bsr	_PrintLn
		bra	.notwfh
.twfhok
	;alloc track info
		move.l	(gl_twbase,GL),a6
		jsr	(_LVOtwAllocTrackInfo,a6)
		move.l	d0,(gl_twti,GL)
		bne	.fromany
		lea	(_twnoti),a0
		bsr	_Print
		bra	.notwinfo

.fromdev	lea	_tracksdev,a2		;cbt

	;print announcement
		move.l	#MAXTRACKS-1,d0
		moveq	#0,d1
.pa_0		bftst	(gl_tabarg+wtt_tab,GL){d0:1}
		beq	.pa_1
		addq.l	#1,d1
.pa_1		dbf	d0,.pa_0
		move.l	d1,-(a7)
		move.l	(gl_rd_unit,GL),-(a7)
		pea	(gl_filename,GL)
		lea	(_txt_createdev),a0
		move.l	a7,a1
		bsr	_PrintArgs
		add.w	#12,a7

.fromany
	;set file header
		lea	(gl_headout+wfh_ctime,GL),a0
		move.l	a0,d1
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVODateStamp,a6)

	;main loop
		move.l	#CMDF_OUT,d0		;flags
		sub.l	a0,a0			;cbdata
		lea	.tracktable,a1		;cbtt
		bsr	_cmdwork

	;free track info
		move.l	(gl_twti,GL),d0
		beq	.notwinfo
		move.l	d0,a0
		move.l	(gl_twbase,GL),a6
		jsr	(_LVOtwFreeTrackInfo,a6)
.notwinfo
	;close file
		move.l	(gl_twfh,GL),d0
		beq	.notwfh
		move.l	(gl_twbase,GL),a6
		jsr	(_LVOtwClose,a6)
.notwfh
	;close library
		move.l	(gl_twbase,GL),d0
		beq	.notwlib
		move.l	d0,a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOCloseLibrary,a6)
.notwlib
		rts

;----------------------------------------

.tracktable	lea	(gl_tabarg,GL),a0
		lea	(gl_tabout,GL),a1
		bsr	_copytt
		moveq	#-1,d0
		rts

;----------------------------------------

_tracksdev	move.l	d0,d6				;D6 = actual track

	;progress output
		lea	(_diskprogress),a0		;output progress
		move.l	d6,-(a7)
		move.l	a7,a1
		bsr	_PrintArgs
		addq.l	#4,a7
		bsr	_FlushOutput

	;read track
		move.l	(gl_rd_retry,GL),d7		;D7 = read retries

.retryloop

	;check CTRL-C pressed
		bsr	_CheckBreak			;check for CTRL-C
		tst.l	d0
		bne	.error

	;read track
		move.l	d6,d0
		bsr	_cmdc_read
		beq	.error

		tst.l	(gl_rd_nostd,GL)
		bne	.nonstd
	;try to decode
		move.l	(gl_rd_bpt,GL),d0
		lsl.l	#3,d0
		move.l	d6,d1
		move.l	(gl_rd_force,GL),d2		;force mode
		bsr	_cmdc_decode
		move.w	d0,d4				;D4 = type
		beq	.nonstd
		move.l	d1,d5				;D5 = length
		move.w	d2,d3				;D3 = flags
	;progress output decoded
		move.w	d4,(gl_trk+wth_type,GL)
		bsr	_gettt
		move.w	(wwf_speclen,a0),-(a7)
		move.w	(wwf_datalen,a0),-(a7)
		move.l	(wwf_name,a0),-(a7)
		lea	(_decoded),a0
		move.l	a7,a1
		bsr	_PrintArgs
		addq.l	#8,a7
	;write
		bra	.write

.nonstd
	;try to calculate track length
		move.l	(gl_rd_bpt,GL),d0
		bsr	_cmdc_CalcTrackSize
		move.l	d0,d5				;D5 = length
		beq	.nolen
	;progress output raw single
		lea	(_trklens),a0
		move.l	d5,d3
		lsr.l	#3,d3				;bytes
		move.l	d5,d4
		and.l	#7,d4				;bits
		movem.l	d3-d4,-(a7)
		move.l	a7,a1
		bsr	_PrintArgs
		addq.l	#8,a7
	;write
		bfclr	([gl_fastbuf,GL]){d5:7}		;alignment
		move.w	#TT_RAW,d4			;D4 = type
		move.w	#TFF_INDEX|TFF_RAWSINGLE,d3	;D3 = flags
		bra	.write

.nolen		subq	#1,d7
		bmi	.writefull
		bsr	_cmdc_movehead
		bra	.retryloop

.writefull
	;progress output raw
		lea	(_trklen),a0
		clr.l	-(a7)
		move.l	(gl_rd_bpt,GL),d5
		move.l	d5,-(a7)
		lsl.l	#3,d5				;D5 = length
		move.l	a7,a1
		bsr	_PrintArgs
		add.w	#8,a7
	;write
		move.w	#TT_RAW,d4			;D4 = type
		move.w	#TFF_INDEX,d3			;D3 = flags

	;write track
.write		move	d6,(gl_trk+wth_num,GL)
		move	d4,(gl_trk+wth_type,GL)
		move	d3,(gl_trk+wth_flags,GL)
		move.l	d5,(gl_trk+wth_len,GL)
		clr.l	(gl_trk+wth_wlen,GL)
		lea	(gl_trk+wth_sync,GL),a0
		lea	(gl_trk+wth_mask,GL),a1
		move.b	#SYNCLEN-1,d0
.hc		clr.b	(a0)+
		clr.b	(a1)+
		dbf	d0,.hc
		clr.w	(gl_trk+wth_syncnum,GL)

		moveq	#-1,d0
		rts

.error		moveq	#0,d0
		rts

;----------------------------------------

_tracksfile	move.l	d0,d6				;D6 = actual track

	;get track info
		move.l	(gl_twfh,GL),d0			;handle
		move.l	d6,d1				;track number
		move.l	(gl_twti,GL),a0			;track info
		move.l	a0,a3				;A3 = trackinfo
		move.l	(gl_twbase,GL),a6
		jsr	(_LVOtwTrackInfo,a6)
		move.l	d0,d2				;D2 = ti rc
		bne	.tiok
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOIoErr,a6)
		move.l	d0,d3				;D3 = ti ioerr
		cmp.l	#TWE_TrackNotPresent,d0
		bne	.tiok
.endskip	moveq	#-2,d0
		rts
.tiok
	;progress output
		lea	(_diskprogress),a0		;output progress
		move.l	d6,-(a7)
		move.l	a7,a1
		bsr	_PrintArgs
		addq.l	#4,a7
		bsr	_FlushOutput

	;if error print and skip
		tst.l	d2
		bne	.tifine
		move.l	d3,d1				;code
		bra	.twfaulterr
.tifine
	;check type
		cmp.w	#TWTT_RAW,(twti_type,a3)
		beq	.dataraw
		cmp.w	#TWTT_DOS,(twti_type,a3)
		beq	.datados
		lea	(_twdataunknown),a0
		lea	(twti_type,a3),a1
		bsr	_PrintArgs
		bra	.endskip

	;dos format
.datados	move.l	(gl_twfh,GL),d0			;handle
		move.l	d6,d1				;track number
		move.l	#TWTT_DOS,d2			;track type
		move.l	(gl_fastbuf,GL),a0		;buffer
		move.l	(gl_twbase,GL),a6
		jsr	(_LVOtwReadForm,a6)
		tst.l	d0
		beq	.twfault
		move.l	#$1600,d0			;length
		move.l	(gl_fastbuf,GL),a0		;input
		move.l	a0,a1				;output
		bsr	_packtrack
		lsl.l	#3,d0
		move.l	d0,d5				;D5 = length
		moveq	#TT_STDF,d4			;D4 = type
		move.l	d1,d3				;D3 = flags
		bra	.progress

	;raw format
.dataraw	move.l	(gl_twfh,GL),d0			;handle
		move.l	d6,d1				;track number
		move.l	#MAXTDLEN,d2			;buffer length
		move.l	(gl_fastbuf,GL),a0		;buffer
		move.l	(gl_twbase,GL),a6
		jsr	(_LVOtwReadRaw,a6)
		move.l	d0,d5				;D5 = length
		beq	.twfault
		lsl.l	#3,d5

		tst.l	(gl_rd_nostd,GL)
		bne	.nonstd
	;try to decode
		move.l	d5,d0
		move.l	d6,d1
		move.l	(gl_rd_force,GL),d2		;force mode
		bsr	_cmdc_decode
		move.w	d0,d4				;D4 = type
		beq	.nonstd
		move.l	d1,d5				;D5 = length
		move.w	d2,d3				;D3 = flags

	;progress output decoded
.progress	move.w	d4,(gl_trk+wth_type,GL)
		bsr	_gettt
		move.w	(wwf_speclen,a0),-(a7)
		move.w	(wwf_datalen,a0),-(a7)
		move.l	(wwf_name,a0),-(a7)
		lea	(_decoded),a0
		move.l	a7,a1
		bsr	_PrintArgs
		addq.l	#8,a7
	;write
		bra	.write

.nonstd
	;try to calculate track length
		move.l	d5,d0
		bsr	_cmdc_CalcTrackSize
		tst.l	d0
		beq	.writefull
		move.l	d0,d5				;D5 = length
	;progress output raw single
		lea	(_trklens),a0
		move.l	d5,d3
		lsr.l	#3,d3				;bytes
		move.l	d5,d4
		and.l	#7,d4				;bits
		movem.l	d3-d4,-(a7)
		move.l	a7,a1
		bsr	_PrintArgs
		addq.l	#8,a7
	;write
		bfclr	([gl_fastbuf,GL]){d5:7}		;alignment
		move.w	#TT_RAW,d4			;D4 = type
		move.w	#TFF_RAWSINGLE,d3		;D3 = flags
		bra	.writeraw

.writefull
	;progress output raw
		lea	(_trklen),a0
		clr.l	-(a7)
		move.l	d5,d0
		lsr.l	#3,d0
		move.l	d0,-(a7)
		move.l	a7,a1
		bsr	_PrintArgs
		add.w	#8,a7
	;write
		move.w	#TT_RAW,d4			;D4 = type
.writeraw	btst	#TWTIB_INDEX,(twti_flags+3,a3)
		beq	.write
		or.w	#TFF_INDEX,d3			;D3 = flags

	;write track
.write		move	d6,(gl_trk+wth_num,GL)
		move	d4,(gl_trk+wth_type,GL)
		move	d3,(gl_trk+wth_flags,GL)
		move.l	d5,(gl_trk+wth_len,GL)
		clr.l	(gl_trk+wth_wlen,GL)
		lea	(gl_trk+wth_sync,GL),a0
		lea	(gl_trk+wth_mask,GL),a1
		move.b	#SYNCLEN-1,d0
.hc		clr.b	(a0)+
		clr.b	(a1)+
		dbf	d0,.hc
		move.w	(twti_sync,a3),d0
		beq	.nosync
		move.w	d0,-(a0)
		move.w	#-1,-(a1)
.nosync		clr.w	(gl_trk+wth_syncnum,GL)

		moveq	#-1,d0
		rts

	;print error message and skip
.twfault	move.l	(gl_dosbase,GL),a6
		jsr	(_LVOIoErr,a6)
		move.l	d0,d1				;code
.twfaulterr	move.w	#" "<<8,-(a7)
		move.l	a7,d2				;header
		sub.l	#78,a7
		move.l	a7,d3				;buffer
		move.l	#78,d4				;buflen
		move.l	(gl_twbase,GL),a6
		jsr	(_LVOtwFault,a6)
		move.l	a7,a0
		bsr	_Print
		add.l	#80,a7
		bsr	_PrintLn
		bra	.endskip

;----------------------------------------
; read raw mfm track
; IN:	D0 = UWORD track number
; OUT:	D0 = BOOL true on success
;	_fastbuf contains mfm data

_cmdc_read	move.w	d0,-(a7)
		clr.w	-(a7)
	;flush trackdisk buffers
		move.l	(gl_io,GL),a1
		move.w	#ETD_UPDATE,(IO_COMMAND,a1)
		clr.b	(IO_FLAGS,a1)
		clr.b	(IO_ERROR,a1)
		move.l	(gl_execbase,GL),a6
		jsr	(_LVODoIO,a6)
		move.l	(gl_io,GL),a1
		move.b	(IO_ERROR,a1),d0
		bne	.err
		move.l	(gl_io,GL),a1
		move.w	#ETD_CLEAR,(IO_COMMAND,a1)
		clr.b	(IO_FLAGS,a1)
		clr.b	(IO_ERROR,a1)
		jsr	(_LVODoIO,a6)
		move.l	(gl_io,GL),a1
		move.b	(IO_ERROR,a1),d0
		bne	.err
	;read mfm
		move.l	(gl_io,GL),a1
		move.l	(a7),d0
		move.l	d0,(IO_OFFSET,a1)
		bsr	_tdenable81
		move.l	(gl_chipbuf,GL),(IO_DATA,a1)
		move.l	(gl_rd_bpt,GL),(IO_LENGTH,a1)
		move.w	#ETD_RAWREAD,(IO_COMMAND,a1)
		move.b	#IOTDF_INDEXSYNC|IOF_QUICK,(IO_FLAGS,a1)
		clr.b	(IO_ERROR,a1)
		move.l	(IO_DEVICE,a1),a6
		jsr	(-$1e,a6)
		move.l	(gl_io,GL),a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOWaitIO,a6)
		move.l	(gl_io,GL),a1
		bsr	_tddisable81
		move.b	(IO_ERROR,a1),d0
		bne	.err
	;copy mfm data to fast mem for better performance
		move.l	(gl_rd_bpt,GL),d0
		bsr	_copy_c2f

		moveq	#-1,d0
		addq.l	#4,a7
		rts

.err		move.l	d0,-(a7)
		move.l	#" "<<24,-(a7)
		move.l	a7,a0
		bsr	_Print
		addq.l	#4,a7
		move.l	(a7)+,d0
		lea	(_readdisk),a0
		bsr	_PrintErrorTD
		moveq	#0,d0
		addq.l	#4,a7
		rts

;----------------------------------------
; copy _chipbuf to _fastbuf
; IN:	D0 = ULONG bytes to copy
;	_chipbuf
; OUT:	_fastbuf contains mfm data

_copy_c2f	move.l	(gl_chipbuf,GL),a0
		move.l	(gl_fastbuf,GL),a1
		cmp.l	a0,a1
		beq	.ok
		addq.l	#3,d0
		lsr.l	#2,d0
		subq.w	#1,d0
.cp		move.l	(a0)+,(a1)+
		dbf	d0,.cp
.ok		rts

;----------------------------------------
; try to decode track as known format
; IN:	D0 = ULONG length of raw mfm-data in bits
;	D1 = UWORD track number
;	D2 = BOOL  force decoding
;	gl_fastbuf mfm data
; OUT:	D0 = ULONG track type identified
;	D1 = ULONG decoded data length in bits!
;	D2 = ULONG track flags
;	gl_fastbuf contains decoded data

_cmdc_decode	ext.l	d1				;track number
		movem.l	d0-d1/d3-d7/a2-a3/a6,-(a7)	;(a7) = mfm length
							;(4,a7) = track number
		clr.l	(gl_detectflags,GL)

	;check fast sync table already inited
		tst.l	(gl_fmtptr,GL)
		bne	.syncok
	;initialize fast sync table
		move.b	d2,d7				;D7 = force
		moveq	#-1,d6				;D6 = min raw length (=maxint)
		moveq	#1,d3				;D3 = actual fmt
		move.l	(gl_formats,GL),a2		;A2 = wwf
		lea	(gl_fmtwwff,GL),a6		;A6 = wwff
		moveq	#0,d2				;D2 = sync (used as long!)
	;big loop
.syncnext
	;skip on WWF_FORCE
		tst.b	d7
		bne	.sync1
		btst	#WWFB_FORCE,(wwf_flags+1,a2)
		bne	.syncskip
	;remember shortest wwf_minrawlen
.sync1		cmp.w	(wwf_minrawlen,a2),d6
		bls	.sync2
		move.w	(wwf_minrawlen,a2),d6
	;set (multi)sync table
.sync2		move.l	(wwf_sync,a2),a3		;A3 = synctable
		moveq	#1,d5				;D5 = synccnt
		btst	#WWFB_MULTISYNC,(wwf_flags+1,a2)
		beq	.syncloop
		move.w	(a3)+,d5
	;multisync loop
.syncloop
	;check space left in gl_fmtwwff
		lea	(gl_fmtwwff+wwff_SIZEOF*WWFF_FMTCNT,GL),a0
		cmp.l	a0,a6
		bhs	.fmtcnt_fail
	;init wwff structure
		move.l	a2,(wwff_wwf,a6)		;wwff_wwf
		move.l	a3,a0
		bsr	_getsynclen
		moveq	#-3,d1
		add.l	d0,d1
		move.w	d1,(wwff_synclen,a6)		;wwff_synclen (-3..13)
		move.l	a3,a0
		moveq	#SYNCLEN+2,d1
		add.l	a0,d1
		sub.l	d0,d1
		move.l	d1,(wwff_sync,a6)		;wwff_sync
		neg.l	d0
		move.w	(SYNCLEN,a0,d0.l),d2		;first sync word
		cmp.w	#-1,(2*SYNCLEN,a0,d0.l)		;check mask
		bne	.fmtmask_fail

		moveq	#0,d0
		move.b	(gl_fmthash.l,GL,d2.l),d0
		beq	.sync_new

		move.l	(gl_fmtptr-4.w,GL,d0.l*4),a0
.sync_sub1	tst.l	(wwff_succ,a0)
		beq	.sync_sub2
		move.l	(wwff_succ,a0),a0
		bra	.sync_sub1
.sync_sub2	move.l	a6,(wwff_succ,a0)
		bra	.sync_set

	;actual sync/new is not already stored
.sync_new	move.b	d3,(gl_fmthash.l,GL,d2.l)
		move.l	a6,(gl_fmtptr-4.w,GL,d3.l*4)
		addq.l	#1,d3
		cmp.l	#WWFF_SYNCCNT,d3
		bhs	.synccnt_fail

.sync_set	add.l	#wwff_SIZEOF,a6
	;more multisync?
		add.w	#2*SYNCLEN,a3
		subq.w	#1,d5
		bne	.syncloop
.syncskip	move.l	(a2),a2
		move.l	a2,d0
		bne	.syncnext
		move.w	d6,(gl_fmtminrawlen,GL)
.syncok

	;scan mfm
		moveq	#0,d2				;D2 = offset in mfm-buffer
		move.l	(gl_fastbuf,GL),a3		;A3 = _fastbuf
		moveq	#0,d3
		move.w	(gl_fmtminrawlen,GL),d3
		lsl.l	#3,d3
		neg.l	d3
		add.l	(a7),d3				;D3 = last offset to check
		bmi	.no
		lea	(gl_fmthash.l,GL),a2		;A2 = hash table
		moveq	#0,d6

.nextmfm	bfextu	(a3){d2:16},d7			;D7 = mfm word
		move.b	(a2,d7.l),d6			;D6 = format index
		bne	.found1
.nextmfmout	addq.l	#1,d2
		cmp.l	d2,d3
		bhi	.nextmfm
		bra	.no

	;compare whole sync
.found1		move.l	(gl_fmtptr-4.w,GL,d6.l*4),a6	;A6 = wwff
	IFD PROF
		addq.w	#1,(wwff_count,a6)
		bcc	.f10
		lea	(.profovl),a0
		move.l	d7,-(a7)
		move.l	a7,a1
		bsr	_PrintArgs
		addq.l	#4,a7
	ENDC
.f10		move.w	(wwff_synclen,a6),d0		;bytes left to compare - 1
		bmi	.found2

		lea	(2,a3),a0			;skip already compared sync part
		move.l	(wwff_sync,a6),a1		;sync - SYNCLEN + synclen
.f11		bfextu	(a0){d2:8},d1
		and.b	(SYNCLEN,a1),d1
		addq.l	#1,a0
		cmp.b	(a1)+,d1
		dbne	d0,.f11
		beq	.found2
.found1out	move.l	(wwff_succ,a6),d0
		beq	.nextmfmout
		move.l	d0,a6
		bra	.f10

	;check minrawlen
.found2		move.l	(a7),d0
		sub.l	d2,d0				;bits left
		lsr.l	#3,d0
		cmp.w	([wwff_wwf,a6],wwf_minrawlen),d0
		blo	.found1out
	;try decode
		movem.l	(a7),d0-d1			;mfm length, track number
		move.l	(gl_fastbuf,GL),a0		;mfm buffer
		lea	(gl_tmpbuf,GL),a1		;decoded buffer
		movem.l	d2-d7/a2-a6,-(a7)
		move.l	([wwff_wwf,a6],wwf_decode),a2
		jsr	(a2)
		movem.l	(a7)+,_MOVEMREGS
		tst.l	d0
		bne	.found3
	;print try
		tst.l	(gl_rd_dbg,GL)
		beq	.found1out
		lea	_fmttried,a0
		move.l	([wwff_wwf,a6],wwf_name),-(a7)
		move.l	a7,a1
		bsr	_PrintArgs
		addq.l	#4,a7
		move.l	d2,d0
		bsr	_printbitlen
		bra	.found1out

.found3		move.l	(wwff_wwf,a6),a2

	;copy special
		lea	(gl_tmpbuf,GL),a0	;input
		move.l	(gl_fastbuf,GL),a1	;output
		move.w	(wwf_speclen,a2),d0
		bra	.copyspecin
.copyspec	move.b	(a0)+,(a1)+
.copyspecin	dbf	d0,.copyspec
	;pack track
		moveq	#0,d0
		move.w	(wwf_datalen,a2),d0	;length
		bsr	_packtrack
		move.l	d1,d2			;flags
		moveq	#0,d1
		move.w	(wwf_speclen,a2),d1
		add.l	d0,d1
		lsl.l	#3,d1			;length in bits
		moveq	#0,d0
		move.w	(wwf_type,a2),d0	;type

.end		addq.l	#8,a7			;free d0/d1

		tst.l	(gl_rd_dbg,GL)
		beq	.nodbg
		movem.l	d0-d1,-(a7)
		lea	(.space),a0
		bsr	_Print
		movem.l	(a7)+,d0-d1
.nodbg
		movem.l	(a7)+,d3-d7/a2-a3/a6
		rts

.no		moveq	#0,d0
		bra	.end

.synccnt_fail	lea	(.synccnt),a0
		bsr	_Print
		bra	.no
.fmtcnt_fail	lea	(.fmtcnt),a0
		bsr	_Print
		bra	.no
.fmtmask_fail	lea	(.fmtmask),a0
		bsr	_Print
		bra	.no
.synccnt	dc.b	"WWFF_SYNCCNT too low!",10,0
.fmtcnt		dc.b	"WWFF_FMTCNT too low!",10,0
.fmtmask	dc.b	"WWFF mask is not -1!",10,0
.space		dc.b	" ",0
	IFD PROF
.profovl	dc.b	155,"1m ovl=$%04lx",155,"0m",0
	ENDC
	EVEN

;----------------------------------------
; pack track data
; IN:	D0 = ULONG input length in bytes
;	A0 = APTR  input buffer
;	A1 = APTR  output buffer (can be equal to input buffer)
; OUT:	D0 = ULONG resulting length in bytes
;	D1 = ULONG track flags

_packtrack	movem.l	d4-d7/a2,-(a7)
		moveq	#0,d1			;flags

	;all lw's equal
		move.l	a0,a2
		move.l	d0,d6
		lsr.l	#1,d6
		bcs	.neq
		lsr.l	#1,d6
		bcs	.neq
		subq.w	#2,d6
		move.l	(a2)+,d7
.eq		cmp.l	(a2)+,d7
		dbne	d6,.eq
		bne	.neq
		move.l	d7,(a1)
		moveq	#4,d0			;length
		moveq	#TFF_LEQ,d1		;flags
		bra	.end
.neq
	;each sector with lw's incremented
		move.l	d0,d5
		and.w	#$1ff,d5		;must be a multiple of $200
		bne	.nlinc
		move.l	a0,a2
		move.l	d0,d5
		moveq	#9,d6
		lsr.l	d6,d5
		subq.l	#1,d5			;sector count
		move.l	d5,d4
.linc2		moveq	#$200/4-2,d6
		move.l	(a2)+,d7
.linc		addq.l	#1,d7
		cmp.l	(a2)+,d7
		dbne	d6,.linc
		dbne	d5,.linc2
		bne	.nlinc
.linc3		move.l	(a0)+,(a1)+
		add.w	#512-4,a0
		dbf	d4,.linc3
		lsr.l	#9-2,d0			;length
		moveq	#TFF_SLINC,d1		;flags
		bra	.end
.nlinc
	;each sector has the same lw's
		move.l	d0,d5
		and.w	#$1ff,d5		;must be a multiple of $200
		bne	.nleq
		move.l	a0,a2
		move.l	d4,d5			;sector count
.leq2		moveq	#$200/4-2,d6
		move.l	(a2)+,d7
.leq		cmp.l	(a2)+,d7
		dbne	d6,.leq
		dbne	d5,.leq2
		bne	.nleq
.leq3		move.l	(a0)+,(a1)+
		add.w	#512-4,a0
		dbf	d4,.leq3
		lsr.l	#9-2,d0
		moveq	#TFF_SLEQ,d1		;flags
		bra	.end
.nleq
	;copy buffer if required
		cmp.l	a0,a1
		beq	.end
		move.l	d0,d7
		lsr.l	#2,d7			;round up!
.copy		move.l	(a0)+,(a1)+
		dbf	d7,.copy

.end		movem.l	(a7)+,_MOVEMREGS
		rts

;----------------------------------------
; calculate track length if possible
; IN:	D0 = ULONG length of raw mfm-data in bytes
;	_fastbuf mfm data
; OUT:	D0 = ULONG size in bits if successful, otherwise 0

_cmdc_CalcTrackSize
		movem.l	d2-d7/a2,-(a7)

		move.l	d0,d5			;D5 = mfm-length
		move.l	(gl_fastbuf,GL),a0	;A0 = buffer start
		move.l	#MINTRACKLEN*8,d0	;D0 = actual offset (track size)

.s		move.l	a0,a1			;A1 = actual p1
		move.l	d0,d1
		lsr.l	#5,d1			;/32
		lsl.l	#2,d1			;*4
		lea	(a1,d1.l),a2

.n		bfextu	(a1){d0:32},d7
		cmp.l	(a1)+,d7
		bne	.ne
		cmp.l	a1,a2
		bhi	.n
		move.l	d0,d1
		and.w	#31,d1			;how many bits are left to compare ?
		beq	.eq
		bfextu	(a1){d0:d1},d7
		bfextu	(a1){0:d1},d6
		cmp.l	d6,d7
		bne	.ne
.eq		movem.l	(a7)+,_MOVEMREGS
		rts

.ne		addq.l	#1,d0
		move.l	d0,d1
		add.l	d1,d1			;track must fit two times in the raw buffer
		add.l	#7,d1			;round up
		lsr.l	#3,d1			;in bytes
		cmp.l	d5,d1
		bls	.s

		moveq	#0,d0
		movem.l	(a7)+,_MOVEMREGS
		rts

;----------------------------------------
; move head
; IN:	D6 = ULONG actual track
; OUT:	-

_cmdc_movehead
		move.l	d6,d0
		lsr.l	#1,d0			;cylinder

		lea	(.data),a0
		cmp.w	(a0),d6
		beq	.calc
.init
		move.w	d6,(a0)			;set new track
		clr.w	(2,a0)			;offset
.calc
		move.w	(2,a0),d1		;offset
		addq.w	#2,(2,a0)
		cmp.w	#.liste-.list,d1
		beq	.init

		add.w	(4,a0,d1.w),d0
		bpl	.1
		moveq	#1,d0
.1		cmp.w	#MAXTRACKS/2,d0
		blo	.2
		move.w	#MAXTRACKS/2-2,d0
.2
		move.l	d0,-(a7)
		lea	.txt1,a0
		moveq	#2,d1
		sub.l	(gl_rd_dbg,GL),d1
		bcc	.nodbg
		lea	.txt2,a0
.nodbg		move.l	a7,a1
		bsr	_PrintArgs
		bsr	_FlushOutput
		move.l	(a7)+,d0

		mulu	#2*$1600,d0
		add.l	#$1600,d0

		move.l	(gl_io,GL),a1
		move.l	d0,(IO_OFFSET,a1)
		divu.l	#$1600,d0
		bsr	_tdenable81
		move.w	#ETD_SEEK,(IO_COMMAND,a1)
		clr.b	(IO_ERROR,a1)
		move.l	(gl_execbase,GL),a6
		jsr	(_LVODoIO,a6)
		move.l	(gl_io,GL),a1
		bsr	_tddisable81
		move.b	(IO_ERROR,a1),d0
		bne	.err

		rts

.err		lea	(_movehead),a0
		bra	_PrintErrorTD

.data		dc.w	-1		;actual cylinder
		dc.w	0		;offset in list
.list		dc.w	0,0,1,0,0,0,-1,0
.liste
.txt1		dc.b	".",0
.txt2		dc.b	"»%ld",0
	EVEN
