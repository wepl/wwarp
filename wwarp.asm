;*---------------------------------------------------------------------------
;  :Program.	WWarp.asm
;  :Contents.	Disk-Warper
;  :Author.	Bert Jahn
;  :Version	$Id: wwarp.asm 1.69 2008/05/06 21:39:36 wepl Exp wepl $
;  :History.	29.08.98 started
;		20.09.98 reading of std tracks added, and major rework
;		22.09.98 tracksize calculation added
;		08.10.98 def-tracklen changed from $7c00 to $6c00 (harry)
;		07.11.99 major rework started
;		24.12.99 varios stuff enhanced
;		28.05.00 gremlin format added, movehead fixed
;		21.06.00 writing std/gremlin added
;		28.06.00 remove fixed, _cmdwork improved
;		06.08.00 FORCE now skips all tracks which cannot be decoded
;		11.08.00 cmd dump improved
;		23.07.01 rob format added
;		05.09.01 asyncio.library support added
;		20.09.01 many changes
;		20.10.01 _getsynclen fixed
;		21.10.01 multiple syncs added
;		31.10.01 cmd P implemented, cmd I small change
;		21.11.01 cmd I sync offsets added
;		23.04.02 wwarp.i separated from WWarp.asm
;		09.05.02 cmd force clears sync; cmd info better name
;		28.08.02 dummy (revision bump)
;		02.11.02 command dump moved to extra file
;			 rework for new sync-search
;		01.12.02 command Z added
;		16.05.03 command G added
;		01.02.04 MAXTRACKS increased from 164 to 168
;		11.02.04 WWFF_MULTISYNC added
;		07.03.04 cmd_info name increased to 5 chars
;			 DEFTRACKS set to 162
;		12.03.04 DBG/K/N added
;		18.06.04 io.s separated
;		05.10.04 check for bad wth_trknum added
;		08.10.04 fixes for hackdisk.device added
;		02.02.05 trackwarp.library support added
;		22.03.05 option Force/S added
;		24.03.05 wwf_minrawlen splitted into wwf_minrawlen and wwf_writelen
;		24.05.07 option NoFmt/K added
;		23.04.08 added support for 40 tracks 5.25" drives (Mark)
;			 tracktable compression added, _expandtt fixed
;		06.06.19 adapted for vamos build
;		14.02.20 fix printing of long syncs
;  :Requires.	OS V37+, MC68020+
;  :Copyright.	©1998-2008 Bert Jahn, All Rights Reserved
;  :Language.	68020 Assembler
;  :Translator.	Barfly V2.9
;  :To Do.
;---------------------------------------------------------------------------*
;##########################################################################

	INCDIR	Includes:
	INCLUDE	lvo/exec.i
	INCLUDE	exec/execbase.i
	INCLUDE	exec/io.i
	INCLUDE	exec/memory.i
	INCLUDE	lvo/dos.i
	INCLUDE	dos/datetime.i
	INCLUDE	dos/dos.i
	INCLUDE	devices/trackdisk.i
	INCLUDE	hardware/cia.i
	INCLUDE	resources/misc.i
	INCLUDE	libraries/trackwarp.i
	INCLUDE	libraries/trackwarp_lib.i

	INCLUDE	macros/ntypes.i

	INCLUDE	wwarp.i

SD_SECS		= 880		;total sectors of a 5.25" floppy
DD_SECS		= 1760		;total sectors of a dd-floppy
HD_SECS		= 2*DD_SECS	;total sectors of a hd-floppy

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

DEFTRACKS_35	= 162-1		;default amount tracks to process for 3.5"
DEFTRACKS_525	= 80-1		;default amount tracks to process for 5.25"
MAXTRACKS	= 168		;maximum amount of tracks which can be procecced (fileformat)
MAXTRACKS_35	= 168		;maximum amount of tracks for 3.5"
MAXTRACKS_525	= 80		;maximum amount of tracks for 5.25"
CALCDRVCNT	= 5		;amount of loops to calculate drive write length capabilities

;length for mfm raw operations
MINTRACKLEN	= $3000		;minimal track length (limited physical)
MAXTRACKLEN	= $3580		;maximal track length (long tracks...)
DEFREADLEN	= $6c00		;default track length for reads
DEFWRITELEN	= $3200		;default track length for writes
MAXTDLEN	= $7ffe		;maximal track length (limited by trackdisk.device)
DEFREADRETRY	= 6		;default amount of read retries on command C
WRITEDRVTOL	= 24		;bytes more written than real drive write length
				;for security, drive tolerance

	STRUCTURE	WWarpFormat,0		;internal structure for known formats
		APTR	wwf_succ		;pointer to next structure
		APTR	wwf_decode		;routine to decode from mfm
		APTR	wwf_encode		;routine to create mfm
		APTR	wwf_info		;routine to display infos
		APTR	wwf_name		;name of format
		APTR	wwf_sync		;sync of format, or table if WWFF_MULTISYNC
		APTR	wwf_density		;density map
		UWORD	wwf_index		;distance from index to sync
		UWORD	wwf_speclen		;length of special data (for write back)
		UWORD	wwf_datalen		;length for decoded data
		UWORD	wwf_minrawlen		;minimum length for encoded data, bytes incl. sync required for detection
		UWORD	wwf_writelen		;length of the track when written using wwarps encoder
		UWORD	wwf_type		;for use in WWarpTrackHeader
		UWORD	wwf_flags		;flags for the format
		LABEL	wwf_SIZEOF

 BITDEF WWF,FORCE,0	;if set, try this format only when command Force is used
 BITDEF WWF,INDEX,1	;format must be written using index sync
 BITDEF WWF,MULTISYNC,2	;format uses variable syncs

	STRUCTURE	WWarpFormatFast,0	;internal structure for fast search
		APTR	wwff_succ		;pointer to next structure with same LONG sync
		APTR	wwff_wwf		;full format description
		APTR	wwff_sync		;address of sync + SYNCLEN - synclen
		UWORD	wwff_synclen		;length of sync - 3 (-3..13)
		UWORD	wwff_count		;for profiling only
		ALIGNLONG
		LABEL	wwff_SIZEOF

WWFF_SYNCCNT	= TT_CNT+7			;amount of different long sync's
WWFF_FMTCNT	= TT_CNT+15			;amount of FormatFast's is amount of formats
						;+ amount of MULTISYNC's
FILENAMELEN	= 1024

	STRUCTURE	Globals,0
		APTR	gl_execbase
		APTR	gl_dosbase
		APTR	gl_asynciobase
		APTR	gl_twbase
		ULONG	gl_twfh			;trackwarp filehandle
		ULONG	gl_twti			;trackwarp trackinfo buffer
		APTR	gl_rdargs
		LABEL	gl_rdarray
		ULONG	gl_rd_file		;name of the wwarp file
		ULONG	gl_rd_cmd		;operation to perform
		ULONG	gl_rd_tracks		;affected tracks
		ULONG	gl_rd_arg		;further argument depending on operation
		ULONG	gl_rd_import		;bytes per track
		ULONG	gl_rd_bpt		;bytes per track
		ULONG	gl_rd_unit		;drive unit
		ULONG	gl_rd_nostd		;dont try to decode known formats
		ULONG	gl_rd_nofmt		;dont try to decode formats in given list
		ULONG	gl_rd_force		;detect also F formats
		ULONG	gl_rd_retry		;how many read retries
		ULONG	gl_rd_nover		;no verify
		ULONG	gl_rd_sybil		;use SYBIL hardware
		ULONG	gl_rd_dbg		;debug level
		ULONG	gl_rc			;programs return code
		APTR	gl_chipbuf
		APTR	gl_fastbuf
		ULONG	gl_deftracks		;default amount tracks
		ULONG	gl_maxtracks		;maximum amount tracks for the actual drive <>MAXTRACKS !!!
		APTR	gl_formats		;pointer to linked list of formats
		ULONG	gl_sybil_drivelen	;sybil current amount of bits drive can write
		ULONG	gl_td_drivelen		;trackdisk amount of bits current drive can write
		ULONG	gl_drivelen		;average amount of bits current drive can write
		ULONG	gl_writelen		;amount of bytes to write
		ULONG	gl_pregap		;bytes before mfm track data (density writes)
		ULONG	gl_detectflags		;use during format detection on ambiguous formats
		ULONG	gl_tdpatchdata		;trackdisk cyl81 patch: saved max offset
		UWORD	gl_tdpatchtrk		;trackdisk cyl81 patch: saved max track
		UBYTE	gl_tdpatchdone		;trackdisk cyl81 patch: is patched
		ALIGNLONG
		UWORD	gl_fmtminrawlen		;minimal raw length
		STRUCT	gl_fmtptr,WWFF_SYNCCNT*4	;pointer to fast structures for custom formats
		STRUCT	gl_fmtwwff,WWFF_FMTCNT*wwff_SIZEOF	;fast structures for custom formats
		STRUCT	gl_DateTime,dat_SIZEOF
		STRUCT	gl_date,LEN_DATSTRING
		STRUCT	gl_time,LEN_DATSTRING
		STRUCT	gl_headin,wfh_SIZEOF		;file header input
		STRUCT	gl_headout,wfh_SIZEOF		;file header output
TABMAXLEN = (MAXTRACKS+7)/8
		STRUCT	gl_tabarg,wtt_tab+TABMAXLEN	;tracks specified via command line
							;default = argument || tabin
		STRUCT	gl_tabin,wtt_tab+TABMAXLEN	;tracks contained in input file
		STRUCT	gl_tabread,wtt_tab+TABMAXLEN	;tracks to read from the input file
							;default = 0
		STRUCT	gl_tabout,wtt_tab+TABMAXLEN	;tracks to write to the output file
							;default = tabin
		STRUCT	gl_tabdo,wtt_tab+TABMAXLEN	;tracks on which user func will called
							;default = tabarg
		ALIGNLONG
		STRUCT	gl_trk,wth_data
		ALIGNLONG
		ULONG	gl_trklen			;length of loaded track data in gl_tmpbuf
		STRUCT	gl_filename,FILENAMELEN
		STRUCT	gl_filename2,FILENAMELEN
		STRUCT	gl_io,8+dg_SIZEOF		;*iorequest,*msgport,DriveGeometry
		STRUCT	gl_sync,SYNCLEN*2
		BYTE	gl_break
		ALIGNLONG
SYBILTBLCNT=100
SYBILTBLLEN=SYBILTBLCNT*4
SYBILSTART	= $980		;if too low it doesnt work and will give always $1670 bytes!
SYBILINC	= 8
		STRUCT	gl_sybil_caltbl,SYBILTBLLEN	;calibration table
		ULONG	gl_sybil_miscres		;base of misc.resource
		UWORD	gl_sybil_ticks			;speed ticks set
		UBYTE	gl_sybil_parport		;bit#0=1 if parport is allocated
		UBYTE	gl_sybil_parbits		;bit#0=1 if parbits are allocated
		UBYTE	gl_sybil_init			;bit#0=1 if hardware is initialized
		UBYTE	gl_sybil_on			;bit#0=1 if hardware is enabled
		ALIGNLONG
		STRUCT	gl_verbuf,MAXTDLEN/2		;verify, must be last because of length!
		ALIGNLONG
		STRUCT	gl_tmpbuf,MAXTDLEN		;must be last because of length!
		STRUCT	gl_fmthash,$10000
		LABEL	gl_SIZEOF

	;flags for gl_detectflags

	BITDEF	DTCTFLAG,RNCLOLD_Chk,0			;true if check for rnclold has be done
	BITDEF	DTCTFLAG,RNCLOLD_True,1			;result of rnclold check, 1 if sync has been found

;##########################################################################

GL	EQUR	A4		;a4 ptr to Globals
LOC	EQUR	A5		;a5 for local vars
CPU	=	68020

	BOPT	O+		;enable optimizing
	BOPT	ODd-		;disable mul optimizing
	BOPT	ODe-		;disable mul optimizing
	BOPT	wo-		;no optimize warnings
	BOPT	sa+		;write symbol hunks

	IFND	.passchk
	DOSCMD	"WBuild >NIL:"
	DOSCMD	"WDate >.date"
.passchk
	ENDC

Version		= 1
Revision	= 29

	SECTION a,CODE

		bra	_Start

		dc.b	"$VER: "
_txt_creator	sprintx	"WWarp %ld.%ld [build ",Version,Revision
		INCBIN	".build"
		dc.b	"] "
		INCBIN	".date"
		dc.b	0
	EVEN

;##########################################################################

	INCDIR	sources
	INCLUDE	dosio.i
		CheckBreak
		FlushOutput
		GetKey
		PrintArgs
		PrintLn
		PrintMore
	INCLUDE	strings.i
		atoi
		etoi
		AppendString
		StrNCaseCmp
		CopyString
		StrLen
		FormatString
	INCLUDE	error.i
		PrintErrorDOS
		PrintErrorDOSName
		PrintErrorTD
	INCLUDE	files.i
		LoadFileMsg
		SaveFileMsg

;##########################################################################

_StartErr	moveq	#33,d0			;kick 1.2
		lea	(_dosname),a1
		jsr	(_LVOOpenLibrary,a6)
		tst.l	d0
		beq	.q
		move.l	d0,a6
		jsr	(_LVOOutput,a6)
		move.l	d0,d1			;file handle
		move.l	(a7)+,d2
		move.l	d2,a0
		moveq	#-1,d3
.c		addq.l	#1,d3
		tst.b	(a0)+
		bne	.c
		jsr	(_LVOWrite,a6)
		move.l	a6,a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOCloseLibrary,a6)
.q		move.l	(gl_rc,GL),d0
		rts

	;program start
_Start		lea	(_Globals),GL
		move.l	#RETURN_FAIL,(gl_rc,GL)
		move.l	(4).w,a6
		move.l	a6,(gl_execbase,GL)
		lea	(_formats),a0
		move.l	a0,(gl_formats,GL)

	;check cpu
		btst	#AFB_68020,(AttnFlags+1,a6)
		bne	.cpuok
		pea	(_badcpu)
		bra	_StartErr
.cpuok
	MC68020
	;open dos.library
		move.l	#37,d0
		lea	(_dosname),a1
		move.l	(gl_execbase,GL),a6
		jsr	_LVOOpenLibrary(a6)
		move.l	d0,(gl_dosbase,GL)
		bne	.dosok
		pea	(_badkick)
		bra	_StartErr
.dosok
	;open asyncio.library
		move.l	#39,d0
		lea	(_asyncioname),a1
		move.l	(gl_execbase,GL),a6
		jsr	_LVOOpenLibrary(a6)
		move.l	d0,(gl_asynciobase,GL)

	;read arguments
		lea	(_template),a0
		move.l	a0,d1
		lea	(gl_rdarray,GL),a0
		move.l	a0,d2
		moveq	#0,d3
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOReadArgs,a6)
		move.l	d0,(gl_rdargs,GL)
		bne	.argsok
		jsr	(_LVOIoErr,a6)
		cmp.l	#ERROR_REQUIRED_ARG_MISSING,d0
		bne	.argerr
		bsr	_help
		bra	.noargs
.argerr		lea	(_readargs),a0
		bsr	_PrintErrorDOS
		bne	.noargs
.argsok
	;check filename
		move.l	(gl_rd_file,GL),a0
		lea	(gl_filename,GL),a1
		move.l	#FILENAMELEN,d0
		bsr	_CopyString
		lea	(gl_filename,GL),a0
		bsr	_StrLen
		cmp.l	#4,d0
		bls	.cs_1
		lea	(gl_filename-4.w,GL,d0.l),a0
		lea	(_extension),a1
		moveq	#4,d0
		bsr	_StrNCaseCmp
		tst.l	d0
		beq	.cs_end
.cs_1		lea	(gl_filename,GL),a0
		move.l	a0,d1
		move.l	#ACCESS_READ,d2
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOLock,a6)
		move.l	d0,d1
		beq	.cs_2
		jsr	(_LVOUnLock,a6)
		bra	.cs_end
.cs_2		lea	(_extension),a0
		lea	(gl_filename,GL),a1
		move.l	#FILENAMELEN,d0
		bsr	_AppendString
.cs_end
	;set unit
		move.l	(gl_rd_unit,GL),d0
		beq	.unitok
		move.l	d0,a0
		move.l	(a0),(gl_rd_unit,GL)
.unitok
	;open device if required to get geometry
		move.l	#DEFTRACKS_35,(gl_deftracks,GL)
		move.l	#MAXTRACKS_35,(gl_maxtracks,GL)
		tst.l	(gl_rd_import,GL)
		bne	.noopendev
		move.l	(gl_rd_cmd,GL),d0
		beq	.opendev		;default cmd is Create
		move.l	d0,a0
		move.b	(a0),d0
		UPPER	d0
		cmp.b	#"C",d0
		beq	.opendev
		cmp.b	#"W",d0
		beq	.opendev
		cmp.b	#"Z",d0
		bne	.noopendev
.opendev	bsr	_OpenDevice
		beq	.nodev
.noopendev
	;parse tracks
		move	#0,(gl_tabarg+wtt_first,GL)
		move	#MAXTRACKS-1,(gl_tabarg+wtt_last,GL)
		move.l	(gl_rd_tracks,GL),a0
		move.l	a0,d0
		beq	.pt_def
		cmp.w	#"*"<<8,(a0)
		bne	.pt_loop
		clr.l	(gl_rd_tracks,GL)
.pt_def		move.l	(gl_deftracks,GL),d0
.pt_1		bfset	(gl_tabarg+wtt_tab,GL){d0:1}
		dbf	d0,.pt_1
		bra	.pt_end

.pt_loop	bsr	.pt_getnum
		move.b	(a0)+,d1
		beq	.pt_single
		cmp.b	#",",d1
		beq	.pt_single
		cmp.b	#"-",d1
		beq	.pt_area
		cmp.b	#"*",d1
		beq	.pt_step
		bra	.pt_err

.pt_single	bfset	(gl_tabarg+wtt_tab,GL){d0:1}
.pt_check	tst.b	d1
		beq	.pt_end
		cmp.b	#",",d1
		beq	.pt_loop
		bra	.pt_err

.pt_step	move.l	d0,d2			;D2 = start
		move.l	(gl_deftracks,GL),d3	;D3 = last
.pt_step0	bsr	.pt_getnum		;D0 = skip
		tst.l	d0
		ble	.pt_err
.pt_step1	cmp.l	d2,d3
		blo	.pt_err
.pt_step_l	bfset	(gl_tabarg+wtt_tab,GL){d2:1}
		add.l	d0,d2
		cmp.l	d2,d3
		bhs	.pt_step_l
		move.b	(a0)+,d1
		bra	.pt_check

.pt_area	move.l	d0,d2			;D2 = start
		bsr	.pt_getnum
		move.l	d0,d3			;D3 = last
		moveq	#1,d0			;D0 = skip
		cmp.b	#"*",(a0)
		bne	.pt_step1
		addq.l	#1,a0
		bra	.pt_step0

.pt_getnum	move.l	(a7)+,a1
		move.l	a0,a3
		bsr	_atoi
		cmp.l	a0,a3
		beq	.pt_err
		cmp.l	(gl_maxtracks,GL),d0
		bhs	.pt_err
		jmp	(a1)

.pt_err		lea	(_txt_badtracks),a0
		bsr	_PrintBold
		bra	.badargs

.pt_end
		move.l	#MAXTDLEN,d2		;D2 = maximal rawreadlen
		move.l	#DEFREADLEN,d0		;default tracklength
		move.l	(gl_rd_bpt,GL),d1
		beq	.bptok
		move.l	d1,a0
		bsr	_atoi
		addq.l	#1,d0
		bclr	#0,d0			;word aligned
		cmp.l	d2,d0
		blt	.bptok
		move.l	d2,d0
.bptok		move.l	d0,(gl_rd_bpt,GL)

		move.l	#DEFREADRETRY,d1
		move.l	(gl_rd_retry,GL),d0
		beq	.retryok
		move.l	d0,a0
		move.l	(a0),d1
.retryok	move.l	d1,(gl_rd_retry,GL)

		move.l	(gl_rd_dbg,GL),d0
		beq	.dbgok
		move.l	d0,a0
		move.l	(a0),(gl_rd_dbg,GL)
.dbgok
	;remove known formats from list
		move.l	(gl_rd_nofmt,GL),d0
		beq	.nofmtok
		move.l	d0,a0
.nofmt_next	move.l	a0,a2
		bsr	_atoi
		cmp.l	a0,a2
		beq	.nofmt_illegal
		cmp.l	#$ffff,d0
		bhi	.nofmt_illegal
		lea	(gl_formats,GL),a1	;a1 = previous
		move.l	(a1),a2			;a2 = actual
.nofmt_search	cmp.w	(wwf_type,a2),d0
		beq	.nofmt_found
		move.l	a2,a1
		move.l	(a2),a2
		move.l	a2,d1
		bne	.nofmt_search
		move.l	d0,-(a7)
		bsr	_TxtBold
		lea	(_txt_nofmtnf),a0
		move.l	a7,a1
		bsr	_PrintArgs
		addq.l	#4,a7
		bsr	_TxtReset
		bra	.badargs
.nofmt_found	move.l	(a2),(a1)
		move.b	(a0)+,d0
		beq	.nofmtok
		cmp.b	#",",d0
		beq	.nofmt_next
.nofmt_illegal	lea	(_txt_nofmtill),a0
		bsr	_PrintBold
		bra	.badargs
.nofmtok

	;init globals
		lea	(_chipbuf),a0
		move.l	a0,(gl_chipbuf,GL)
		move.l	#MAXTDLEN,d0
		move.l	#MEMF_FAST,d1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOAllocVec,a6)
		move.l	d0,(gl_fastbuf,GL)
		bne	.memok
		move.l	(gl_chipbuf,GL),(gl_fastbuf,GL)
.memok

	;execute command
		pea	(.return)
		move.l	(gl_rd_cmd,GL),d0
		beq	_cmd_create
		move.l	d0,a0
		move.b	(a0)+,d0
		tst.b	(a0)
		bne	.bad
		UPPER	d0
		cmp.b	#"C",d0
		beq	_cmd_create
		cmp.b	#"D",d0
		beq	_cmd_dump
		cmp.b	#"F",d0
		beq	_cmd_force
		cmp.b	#"G",d0
		beq	_cmd_image
		cmp.b	#"I",d0
		beq	_cmd_info
		cmp.b	#"L",d0
		beq	_cmd_length
		cmp.b	#"M",d0
		beq	_cmd_merge
		cmp.b	#"P",d0
		beq	_cmd_pack
		cmp.b	#"R",d0
		beq	_cmd_remove
		cmp.b	#"S",d0
		beq	_cmd_save
		cmp.b	#"Y",d0
		beq	_cmd_sync
		cmp.b	#"W",d0
		beq	_cmd_write
		cmp.b	#"Z",d0
		beq	_cmd_zap

.bad		lea	(_txt_badcmd),a0
		bra	_PrintBold

.return
	IFD PROF
	;print profiling info about format detection routine
	;good examples for testing: MegaLoMania, NoSecondPrize, LifeAndLetDie
	;speedtest 27.4.2008 (without PROF)
	;	mlm	nsp	lld	sum
	;1.17	 39.24	 37.78	 37.50	114.52
	;1.27	123.78	119.10	110.68	353.56
	;1.28	 19.80	 20.04	 10.24	 50.08
		tst.l	(gl_fmtptr,GL)
		beq	.noprof
		lea	(gl_fmtwwff,GL),a2
.prof_lp	move.w	(wwff_count,a2),d0
		beq	.prof_next
		move.w	d0,-(a7)
		move.l	(wwff_sync,a2),a0
		move.w	-(a0),-(a7)
		lea	.prof_txt,a0
		move.l	a7,a1
		bsr	_PrintArgs
		addq.l	#4,a7
.prof_next	add.w	#wwff_SIZEOF,a2
		tst.l	(wwff_wwf,a2)
		bne	.prof_lp
		bra	.noprof
.prof_txt	dc.b	"prof: $%04x %5u",10,0
	EVEN
.noprof
	ENDC

	;free globals
		move.l	(gl_fastbuf,GL),a1
		cmp.l	(gl_chipbuf,GL),a1
		beq	.fgle
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOFreeVec,a6)
.fgle
.badargs
		tst.l	(gl_io,GL)
		beq	.nodev
		bsr	_CloseDevice
.nodev
		move.l	(gl_rdargs,GL),d1
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOFreeArgs,a6)
.noargs
		move.l	(gl_asynciobase,GL),d0
		beq	.noasynciolib
		move.l	d0,a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOCloseLibrary,a6)
.noasynciolib
		move.l	(gl_dosbase,GL),a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOCloseLibrary,a6)
.nodoslib
		move.l	(gl_rc,GL),d7
_rts		rts

;##########################################################################

_help		lea	(_txt_help),a0
		lea	(gl_tmpbuf,GL),a6		;A6 = buffer
.copy		move.b	(a0)+,(a6)+
		bne	.copy
		subq.l	#1,a6

	;print infos about supported custom formats
		move.l	(gl_formats,GL),a2
.nextfmt	lea	(_fmtinfo1),a0
		lea	(wwf_type,a2),a1
		bsr	.PrintArgs
		move.l	(wwf_name,a2),a0
		bsr	.PrintArgs
		move.l	(wwf_name,a2),a0
		bsr	_StrLen
		moveq	#10,d3
		sub.l	d0,d3
		moveq	#" ",d2
.nextspc	move.b	d2,(a6)+
		sub.l	#1,d3
		bpl	.nextspc
		lea	(_fmtinfo2),a0
		lea	(wwf_speclen,a2),a1
		bsr	.PrintArgs
		moveq	#" ",d2
		btst	#WWFB_INDEX,(wwf_flags+1,a2)
		beq	.fi
		moveq	#"I",d2
.fi		move.b	d2,(a6)+
		moveq	#" ",d2
		btst	#WWFB_FORCE,(wwf_flags+1,a2)
		beq	.ff
		moveq	#"F",d2
.ff		move.b	d2,(a6)+
		move.b	#" ",(a6)+
		move.l	(wwf_sync,a2),a3
		moveq	#1,d2
		btst	#WWFB_MULTISYNC,(wwf_flags+1,a2)
		beq	.nomultisync
		move.w	(a3)+,d2
.nomultisync	subq.w	#1,d2
		bra	.syncin
.syncloop	lea	(_fmtsynctab),a0
		bsr	.PrintArgs
		add.w	#2*SYNCLEN,a3
.syncin		moveq	#45,d0			;ident
		moveq	#1,d1			;flags
		move.l	a3,a0			;sync
		move.l	a6,a1			;buffer
		bsr	_printsync
.search2	tst.b	(a6)+
		bne	.search2
		move.b	#10,(-1,a6)
		dbf	d2,.syncloop

		move.l	(a2),a2
		move.l	a2,d0
		bne	.nextfmt

		lea	(gl_tmpbuf,GL),a0
		bra	_PrintMore

.PrintArgs	move.l	a2,-(a7)
		lea	(gl_tmpbuf,GL),a2
		add.l	#MAXTDLEN,a2
		sub.l	a6,a2
		move.l	a2,d0
		move.l	a6,a2
		bsr	_FormatString
.search		tst.b	(a6)+
		bne	.search
		subq.l	#1,a6
		move.l	(a7)+,a2
		rts

;##########################################################################
;##########################################################################

	INCLUDE	formats.s
	INCLUDE	cmdc.s
	INCLUDE	cmdd.s
	INCLUDE	cmdw.s
	INCLUDE	io.s

;##########################################################################
;##########################################################################

_cmd_force	move.l	#CMDF_OUT|CMDF_IN,d0	;flags
		sub.l	a0,a0			;cbdata
		lea	.tracktable,a1		;cbtt
		lea	.tracks,a2		;cbt
		bra	_cmdwork

.tracktable	lea	(gl_tabin,GL),a0
		lea	(gl_tabread,GL),a1
		bsr	_copytt
		moveq	#-1,d0
		rts

.tracks
	;check type
		cmp.w	#TT_RAW,(gl_trk+wth_type,GL)
		bne	.badtype

	;if single -> double
		bsr	_doubleraws		;mfm length in bits -> d0

		move.w	(gl_trk+wth_num,GL),d1
		st	d2			;force decode
		bsr	_cmdc_decode
		tst.l	d0
		beq	.no

	;set track header
		move.w	d0,(gl_trk+wth_type,GL)
		move.w	d2,(gl_trk+wth_flags,GL)
		move.l	d1,(gl_trk+wth_len,GL)
		clr.l	(gl_trk+wth_wlen,GL)
		moveq	#(2*SYNCLEN)-1,d0
		lea	(gl_trk+wth_sync,GL),a0
.clrsync	clr.b	(a0)+
		dbf	d0,.clrsync
		clr.w	(gl_trk+wth_syncnum,GL)

		moveq	#-1,d0
		rts

.badtype	lea	(_forcebadtype),a0
		bra	.print
.no		lea	(_forcebad),a0
.print		lea	(gl_trk+wth_num,GL),a1
		bsr	_PrintArgs
		moveq	#-1,d0
		rts

;##########################################################################
;##########################################################################

_cmd_image	lea	(_disk1),a0
		move.l	(gl_rd_arg,GL),d0
		beq	.1
		move.l	d0,a0
.1		move.l	a0,d7			;D7 = name
		bsr	_OpenWrite
		move.l	d0,d6			;D6 = fh
		beq	.error
		move.l	#CMDF_IN|CMDF_TRKDATA,d0	;flags
		move.l	d6,-(a7)
		clr.l	-(a7)
		move.l	d7,-(a7)
		move.l	a7,a0			;cbdata
		lea	.tracktable,a1		;cbtt
		lea	.tracks,a2		;cbt
		bsr	_cmdwork
		move.l	(8,a7),d1
		bsr	_Close
		lea	(_imagewritten),a0
		move.l	a7,a1
		bsr	_PrintArgs
		add.w	#12,a7
.error		rts

.tracktable	lea	(gl_tabarg,GL),a0
		lea	(gl_tabread,GL),a1
		bsr	_copytt
		moveq	#-1,d0
		rts

.tracks		move.l	a0,a2			;A2 = (name,size,fh)
		bsr	_gettt
		move.l	a0,a1			;A1 = wwf
		lea	(gl_tmpbuf,GL),a0	;A0 = buffer
		cmp.w	#TT_RAW,(gl_trk+wth_type,GL)
		beq	.raw
		moveq	#0,d0
		move.w	(wwf_datalen,a1),d0
		beq	.raw			;datalen == 0 -> copylock
		add.w	(wwf_speclen,a1),a0
		bra	.write

.raw		move.l	#"TDIC",d0
		move.w	#$1600/4-1,d1
.raw1		move.l	d0,(a0)+
		dbf	d1,.raw1
		move.l	#$1600,d0
		sub.l	d0,a0

.write		add.l	d0,(4,a2)		;length
		move.l	(8,a2),d1		;fh
		bra	_Write

;##########################################################################
;##########################################################################

_cmd_info	move.l	#CMDF_NOTTC|CMDF_IN|CMDF_TRKDATA,d0	;flags
		sub.l	a0,a0			;cbdata
		lea	.tracktable,a1		;cbtt
		lea	.tracks,a2		;cbt
		bra	_cmdwork

	;display for file
.tracktable	lea	(_txt_infohead1),a0
		bsr	_Print
		lea	(gl_headin+wfh_creator,GL),a0
		bsr	_Print

		lea	(gl_headin+wfh_ctime,GL),a0
		bsr	_GetDate
		lea	(_txt_infohead2),a0
		pea	(gl_time,GL)
		pea	(gl_date,GL)
		move.l	a7,a1
		bsr	_PrintArgs
		add.w	#8,a7

		lea	(gl_headin+wfh_mtime,GL),a0
		bsr	_GetDate
		lea	(_txt_infohead3),a0
		pea	(gl_time,GL)
		pea	(gl_date,GL)
		move.l	a7,a1
		bsr	_PrintArgs
		add.w	#8,a7

		moveq	#0,d0
		move.l	#MAXTRACKS-1,d1
.c0		bftst	(gl_tabin+wtt_tab,GL){d1:1}
		beq	.c1
		addq.l	#1,d0
.c1		dbf	d1,.c0

		lea	(_txt_infohead4),a0
		move.l	d0,-(a7)
		move.l	a7,a1
		bsr	_PrintArgs
		addq.l	#4,a7

		lea	(gl_tabarg,GL),a0
		lea	(gl_tabread,GL),a1
		bsr	_copytt

		moveq	#-1,d0
		rts

	;display for each track
.tracks		bsr	_gettt
		move.l	a0,a2			;A2 = wwf
		move.l	(wwf_name,a0),a0
		subq.l	#8,a7
		move.l	a7,a1
		pea	(a1)
		moveq	#4,d0
.fs1		move.b	(a0)+,(a1)+
		dbeq	d0,.fs1
		bne	.fs3
		subq.l	#1,a1
.fs2		move.b	#" ",(a1)+
		dbf	d0,.fs2
.fs3		clr.b	(a1)
	;if name > 5 and last char is 0-9
		tst.b	(-1,a0)			;len < 5?
		beq	.fs4
		tst.b	(a0)			;len == 5?
		beq	.fs4
.fs5		tst.b	(a0)+			;search end
		bne	.fs5
		move.b	(-2,a0),d0		;last char
		cmp.b	#"0",d0
		blo	.fs51
		cmp.b	#"9",d0
		bhi	.fs51
		move.b	d0,-(a1)
		bra	.fs4
	;pre last char is 0-9
.fs51		move.b	(-3,a0),d1
		cmp.b	#"0",d1
		blo	.fs4
		cmp.b	#"9",d1
		bhi	.fs4
		move.b	d0,-(a1)
		move.b	d1,-(a1)
	;print info
.fs4		lea	(_txt_infotrack),a0
		move.l	d5,-(a7)
		move.l	a7,a1
		bsr	_PrintArgs
		add.w	#16,a7

		moveq	#" ",d2
		btst	#TFB_SLEQ,(gl_trk+wth_flags+1,GL)
		beq	.fd
		moveq	#"D",d2
.fd		move.l	(gl_dosbase,GL),a6	;A6 = dosbase
		jsr	(_LVOOutput,a6)
		move.l	d0,d1
		move.l	d0,d6			;D6 = output
		jsr	(_LVOFPutC,a6)

		moveq	#" ",d2
		btst	#TFB_SLINC,(gl_trk+wth_flags+1,GL)
		beq	.fc
		moveq	#"C",d2
.fc		move.l	d6,d1
		jsr	(_LVOFPutC,a6)

		moveq	#" ",d2
		btst	#TFB_LEQ,(gl_trk+wth_flags+1,GL)
		beq	.fq
		moveq	#"Q",d2
.fq		move.l	d6,d1
		jsr	(_LVOFPutC,a6)

		moveq	#" ",d2
		btst	#TFB_RAWSINGLE,(gl_trk+wth_flags+1,GL)
		beq	.fs
		moveq	#"S",d2
.fs		move.l	d6,d1
		jsr	(_LVOFPutC,a6)

		moveq	#" ",d2
		btst	#TFB_INDEX,(gl_trk+wth_flags+1,GL)
		beq	.fi
		moveq	#"I",d2
.fi		move.l	d6,d1
		jsr	(_LVOFPutC,a6)

		cmp.w	#TT_RAW,(gl_trk+wth_type,GL)
		beq	.raw
		move.l	(wwf_info,a2),d0
		beq	.finish
		lea	(gl_tmpbuf,GL),a0		;buffer
		jsr	(d0.l)
		bra	.finish

	;raw track length and write length
.raw		lea	(_length),a0
		move.l	(gl_trk+wth_len,GL),d0
		move.l	d0,d1
		and.l	#7,d1
		lsr.l	#3,d0
		move.l	(gl_trk+wth_wlen,GL),d2
		movem.l	d0-d2,-(a7)
		move.l	a7,a1
		bsr	_PrintArgs
		add.w	#12,a7

	;print sync
		moveq	#30,d0				;ident
		moveq	#0,d1				;flags
		lea	(gl_trk+wth_sync,GL),a0		;sync
		bsr	_printsync

	;print sync number
		moveq	#0,d0
		move.w	(gl_trk+wth_syncnum,GL),d0
		beq	.nsn
		move.l	d0,-(a7)
		move.l	a7,a1
		lea	(_syncnum),a0
		bsr	_PrintArgs
		addq.l	#4,a7
.nsn
	;print sync offsets
		lea	(gl_trk+wth_sync,GL),a0
		bsr	_getsynclen
		tst.l	d0
		beq	.nso
		bsr	_getsyncsearchlen
		move.l	d0,d4				;D4 = buflen
		move.l	d0,d1				;buflen
		moveq	#0,d0				;syncno
		lea	(gl_tmpbuf,GL),a0		;buffer
		lea	(gl_trk+wth_sync,GL),a1		;sync
		bsr	_countsync
		move.l	d0,d2				;D2 = bit offset
	;print count
		move.l	d1,-(a7)
		move.l	a7,a1
		lea	(_synccnt),a0
		bsr	_PrintArgs
		move.l	(a7)+,d0
		beq	.nso
	;print each sync offset
		moveq	#1,d3				;D3 = syncnum
		bra	.in
.next		move.l	d2,d0
		addq.l	#1,d0				;offset
		move.l	d4,d1				;buflen
		lea	(gl_tmpbuf,GL),a0		;buffer
		lea	(gl_trk+wth_sync,GL),a1		;sync
		bsr	_searchsync
		move.l	d0,d2
		bmi	.nso
.in		move.l	d3,-(a7)
		move.l	a7,a1
		lea	(_syncoff),a0
		bsr	_PrintArgs
		addq.l	#4,a7
		move.l	d2,d0
		bsr	_printbitlen
		addq.l	#1,d3
		bra	.next
.nso
	;finish
.finish		bsr	_PrintLn

	;return
.ret		moveq	#-1,d0				;success
		rts

;##########################################################################
;##########################################################################

_cmd_length	move.l	(gl_rd_arg,GL),d0
		bne	.1
		lea	(_needlength),a0
		bra	_Print

.wronglength	lea	(_wronglength),a0
		bra	_Print

.1		move.l	d0,a0
		bsr	_etoi
		tst.l	d0
		bmi	.wronglength
		btst	#0,d0
		bne	.wronglength
		tst.b	(a0)
		bne	.wronglength

		move.l	d0,-(a7)
		move.l	#CMDF_OUT|CMDF_IN,d0	;flags
		move.l	a7,a0			;cbdata
		lea	.tracktable,a1		;cbtt
		lea	.tracks,a2		;cbt
		bsr	_cmdwork
		add.w	#4,a7
		rts

.tracktable	lea	(gl_tabin,GL),a0
		lea	(gl_tabread,GL),a1
		bsr	_copytt
		moveq	#-1,d0
		rts

.tracks		cmp.w	#TT_RAW,(gl_trk+wth_type,GL)
		bne	.badtype
		move.l	(gl_trk+wth_len,GL),d0
		lsr.l	#3,d0
		cmp.l	(a0),d0
		blo	.tobig
		move.l	(a0),(gl_trk+wth_wlen,GL)
		moveq	#-1,d0
		rts

.badtype	lea	(_lenbadtype),a0
		bra	.print
.tobig		lea	(_lentobig),a0
.print		lea	(gl_trk+wth_num,GL),a1
		bsr	_PrintArgs
		moveq	#0,d0
		rts

;##########################################################################
;##########################################################################

_cmd_merge	lea	.sorry,a0
		bra	_Print
.sorry		dc.b	"Sorry, this command is currently not implemented.",10,0,0

;##########################################################################
;##########################################################################

_cmd_pack	move.l	#CMDF_OUT|CMDF_IN|CMDF_TRKDATA,d0	;flags
		sub.l	a0,a0			;cbdata
		lea	.tracktable,a1		;cbtt
		lea	.tracks,a2		;cbt
		bra	_cmdwork

.tracktable	lea	(gl_tabin,GL),a0
		lea	(gl_tabread,GL),a1
		bsr	_copytt
		moveq	#-1,d0
		rts

.tracks		cmp.w	#TT_RAW,(gl_trk+wth_type,GL)
		bne	.success

		lea	(gl_trk+wth_sync,GL),a0
		bsr	_getsynclen
		tst.l	d0
		beq	.nosync

		bsr	_getsyncsearchlen
		move.l	d0,d1				;buflen
		moveq	#0,d0
		move.w	(gl_trk+wth_syncnum,GL),d0	;syncno
		lea	(gl_tmpbuf,GL),a0		;buffer
		lea	(gl_trk+wth_sync,GL),a1		;sync
		bsr	_countsync
		move.l	d0,d4				;D4 = bit offset
		bmi	.badsync

		move.l	(gl_trklen,GL),d3		;D3 = bit length buffer
		sub.l	d4,d3
		move.l	(gl_trk+wth_wlen,GL),d0
		lsl.l	#3,d0
		beq	.nolen
		cmp.l	d0,d3
		blo	.badlen
		move.l	d0,(gl_trk+wth_len,GL)

		add.l	#8*3,d0				;round up
		lsr.l	#3+2,d0				;longs
		subq.l	#1,d0
		lea	(gl_tmpbuf,GL),a0
		move.l	(gl_fastbuf,GL),a1
.cp		bfextu	(a0){d4:32},d1
		move.l	d1,(a1)+
		add.l	#4,a0
		dbf	d0,.cp

		and.w	#~(TFF_INDEX|TFF_RAWSINGLE),(gl_trk+wth_flags,GL)
		move.w	#1,(gl_trk+wth_syncnum,GL)

.success	moveq	#-1,d0
		rts

.nosync		lea	(_warnnosync),a0
		move.w	(gl_trk+wth_num,GL),-(a7)
		clr.w	-(a7)
		move.l	a7,a1
		bsr	_PrintArgs
		add.w	#4,a7
		bra	.success

.badsync	lea	(_errornosync),a0
.errtxt		move.w	(gl_trk+wth_num,GL),-(a7)
		clr.w	-(a7)
		move.l	a7,a1
		bsr	_PrintArgs
		add.w	#4,a7
		moveq	#0,d0
		rts

.nolen		lea	(_errornolen),a0
		bra	.errtxt

.badlen		lea	(_errorbadlen),a0
		bra	.errtxt

;##########################################################################
;##########################################################################

_cmd_remove
		tst.l	(gl_rd_tracks,GL)
		bne	.1
		lea	(_notracks),a0
		bra	_Print

.1		move.l	#CMDF_OUT|CMDF_IN,d0	;flags
		sub.l	a0,a0			;cbdata
		lea	.tracktable,a1		;cbtt
		sub.l	a2,a2			;cbt
		bra	_cmdwork

.tracktable
	;remove all selected tracks from output
		move.l	#MAXTRACKS-1,d0
.loop		bftst	(gl_tabarg+wtt_tab,GL){d0:1}
		beq	.next
		bfclr	(gl_tabout+wtt_tab,GL){d0:1}
.next		dbf	d0,.loop
	;skip removed tracks
		lea	(gl_tabout,GL),a0
		lea	(gl_tabread,GL),a1
		bsr	_copytt
	;return
		moveq	#-1,d0
		rts

;##########################################################################
;##########################################################################

_cmd_save	move.l	#CMDF_IN|CMDF_TRKDATA,d0	;flags
		sub.l	a0,a0			;cbdata
		lea	.tracktable,a1		;cbtt
		lea	.tracks,a2		;cbt
		bra	_cmdwork

.tracktable	lea	(gl_tabarg,GL),a0
		lea	(gl_tabread,GL),a1
		bsr	_copytt
		moveq	#-1,d0
		rts

.tracks
		bsr	_gettt
		move.l	a0,a3			;A3 = wwf

		lea	(.name),a0
		move.l	(wwf_name,a3),-(a7)
		move.w	(gl_trk+wth_num,GL),-(a7)
		clr.w	-(a7)
		move.l	a7,a1
		moveq	#30,d0
		sub.l	d0,a7
		move.l	a7,a2
		bsr	_FormatString

		move.l	(gl_trklen,GL),d0
		addq.l	#7,d0
		lsr.l	#3,d0

		lea	(gl_tmpbuf,GL),a0
		move.l	a7,a1
		bsr	_SaveFileMsg

.end		add.w	#38,a7
		rts

.name		dc.b	"track.%03ld.%s",0
	EVEN

;##########################################################################
;##########################################################################

_cmd_sync	moveq	#0,d4			;D4 = sync specified
		moveq	#0,d5			;D5 = sync num

	;parse argument
		move.l	(gl_rd_arg,GL),d0
		bne	.1
		lea	(_needsync),a0
		bra	_Print
.1		move.l	d0,a2			;A2 = arg
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
		moveq	#-1,d4
		move.b	d2,(a2)
	;sync num
.send		cmp.b	#",",(a2)+
		bne	.arglast
		move.l	a2,a0
		bsr	_atoi
		cmp.l	a0,a2
		beq	.argerr
		lea	(1,a0),a2
		move.l	d0,d5
		blt	.argerr

.arglast	tst.b	-(a2)
		bne	.argerr
.argend
		move.l	#CMDF_OUT|CMDF_IN|CMDF_TRKDATA,d0	;flags
		movem.l	d4-d5,-(a7)
		move.l	a7,a0			;cbdata
		lea	.tracktable,a1		;cbtt
		lea	.tracks,a2		;cbt
		bsr	_cmdwork
		add.w	#8,a7
		rts

.argerr		lea	(_badarg),a0
		bra	_Print

.tracktable	lea	(gl_tabin,GL),a0
		lea	(gl_tabread,GL),a1
		bsr	_copytt
		moveq	#-1,d0
		rts

.tracks		cmp.w	#TT_RAW,(gl_trk+wth_type,GL)
		bne	.badtype

		move.l	a0,a3			;a3 = cbdata
						;(a3)    = sync
						;(4,a3)  = syncnum
		tst.l	(a3)
		beq	.nonewsync

		lea	(gl_sync,GL),a0
		lea	(gl_trk+wth_sync,GL),a1
		move.w	#SYNCLEN-1,d0
.cp		move.w	(a0)+,(a1)+
		dbf	d0,.cp

.nonewsync	move.w	(6,a3),(gl_trk+wth_syncnum,GL)

		lea	(gl_trk+wth_sync,GL),a0
		bsr	_getsynclen
		tst.l	d0
		beq	.success

		bsr	_getsyncsearchlen
		move.l	d0,d1				;buflen
		moveq	#1,d0				;syncno
		lea	(gl_tmpbuf,GL),a0		;buffer
		lea	(gl_trk+wth_sync,GL),a1		;sync
		bsr	_countsync
		tst.l	d0
		bmi	.nosync
		cmp.l	(4,a3),d1
		blo	.less_syncs

.success	moveq	#-1,d0
		rts

.badtype	lea	(_lenbadtype),a0
.error		lea	(gl_trk+wth_num,GL),a1
		bsr	_PrintArgs
		moveq	#0,d0
		rts

.nosync		lea	(_sync_not),a0
		bra	.error

.less_syncs	lea	(_sync_less),a0
		bra	.error

;----------------------------------------
; translate arg into sync
; sync will be stored in gl_sync
; IN:	A0 = CPTR arg
; OUT:	D0 = BOOL true if sync has been translated

_parsesync	movem.l	d2-d7/a2-a3,-(a7)

		move.l	a0,a2		;A2 = string
		bsr	_StrLen
		move.l	d0,d2
		beq	.badsync
		subq.w	#1,d2		;D2 = last char (mask)

		move.l	d2,d3		;D3 = amparsent
.samp		cmp.b	#"&",(a2,d3.l)
		beq	.mfound
		dbf	d3,.samp
.mfound
		tst.w	d3		;empty data?
		beq	.badsync
		cmp.w	d2,d3		;empty mask?
		beq	.badsync

		move.w	d2,d4		;D4 = last char data
		tst.w	d3
		bmi	.nomask
		move.w	d3,d4
		subq.w	#1,d4
.nomask
	;decode sync data
		cmp.w	#31,d4		;to many chars?
		bhi	.badsync
		lea	(gl_sync+SYNCLEN,GL),a3
.dloop		move.l	(gl_fastbuf,GL),a1
		move.b	#"$",(a1)+
		moveq	#7,d5
		cmp.w	d5,d4
		bhs	.2
		move.w	d4,d5
.2		move.w	d5,d0
		lea	(a2,d4.w),a0
		sub.w	d0,a0
.c1		move.b	(a0)+,(a1)+
		dbf	d0,.c1
		clr.b	(a1)
		move.l	a1,d7
		move.l	(gl_fastbuf,GL),a0
		bsr	_atoi
		cmp.l	a0,d7
		bne	.badsync
		move.l	d0,-(a3)
		sub.w	d5,d4
		subq.w	#1,d4
		bpl	.dloop

		tst.w	d3
		bpl	.mask

	;calculate default mask
		moveq	#SYNCLEN-1,d0
		sf	d1
		lea	(gl_sync,GL),a0
		lea	(SYNCLEN,a0),a1
.dmloop		tst.b	(a0)+
		beq	.dm1
		st	d1
.dm1		move.b	d1,(a1)+
		dbf	d0,.dmloop
		bra	.success

	;decode sync mask
.mask		lea	(1,a2,d3.w),a2
		move.w	d2,d4
		sub.w	d3,d4
		sub.w	#1,d4
		cmp.w	#31,d4		;to many chars?
		bhi	.badsync
		lea	(gl_sync+SYNCLEN+SYNCLEN,GL),a3
.mloop		move.l	(gl_fastbuf,GL),a1
		move.b	#"$",(a1)+
		moveq	#7,d5
		cmp.w	d5,d4
		bhs	.m2
		move.w	d4,d5
.m2		move.w	d5,d0
		lea	(a2,d4.w),a0
		sub.w	d0,a0
.mc1		move.b	(a0)+,(a1)+
		dbf	d0,.mc1
		clr.b	(a1)
		move.l	a1,d7
		move.l	(gl_fastbuf,GL),a0
		bsr	_atoi
		cmp.l	a0,d7
		bne	.badsync
		move.l	d0,-(a3)
		sub.w	d5,d4
		subq.w	#1,d4
		bpl	.mloop
	;apply mask on the sync
		lea	(gl_sync,GL),a0
		lea	(SYNCLEN,a0),a1
		moveq	#SYNCLEN/4-1,d1
.m		move.l	(a1)+,d0
		and.l	d0,(a0)+
		dbf	d1,.m

.success	moveq	#-1,d0
.end		movem.l	(a7)+,_MOVEMREGS
		rts

.badsync	lea	(_badsync),a0
		bsr	_Print
		moveq	#0,d0
		bra	.end

;##########################################################################
;##########################################################################

_cmd_zap
		move.l	(gl_rd_arg,GL),d0
		beq	.noarg
		move.l	d0,a0
		bsr	_etoi
		tst.l	d0
		ble	.badfmt
		cmp.l	#TT_CNT,d0
		bhi	.badfmt
		move.w	d0,(gl_trk+wth_type,GL)
		bsr	_gettt
		move.l	a0,a2			;A2 = wwf

		moveq	#0,d0
		move.l	#MAXTRACKS-1,d1
.c0		bftst	(gl_tabarg+wtt_tab,GL){d1:1}
		beq	.c1
		move.w	d1,(gl_trk+wth_num,GL)
		addq.l	#1,d0
.c1		dbf	d1,.c0
		cmp.w	#1,d0
		bne	.badtrkcnt

		lea	(gl_filename,GL),a0
		bsr	_LoadFileMsg
		move.l	d0,d3			;D3 = mem
		beq	.rts
		moveq	#0,d2
		move.w	(wwf_speclen,a2),d2
		add.w	(wwf_datalen,a2),d2
		cmp.l	d1,d2
		bne	.badlen

		move.l	d0,a0
		lea	(gl_tmpbuf,GL),a1
		lsr.l	#2,d1
.copy		move.l	(a0)+,(a1)+
		dbf	d1,.copy

		move.l	d3,a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOFreeVec,a6)

		bsr	_cmdw_init
		tst.l	d0
		beq	.rts
		bsr	_cmdw_custom
		bsr	_cmdw_finit

.rts		rts

.noarg		lea	.tnoarg,a0
		bra	_Print
.badfmt		lea	.tbadfmt,a0
		bra	_Print
.badtrkcnt	lea	.tbadtrkcnt,a0
		bra	_Print
.badlen		lea	.tbadlen,a0
		move.l	d2,-(a7)
		move.l	d2,-(a7)
		move.l	d1,-(a7)
		move.l	d1,-(a7)
		move.l	a7,a1
		bsr	_PrintArgs
		add.w	#16,a7
		move.l	d3,a1
		move.l	(gl_execbase,GL),a6
		jmp	(_LVOFreeVec,a6)

.tnoarg		dc.b	"custom format must be specified as number",10,0
.tbadfmt	dc.b	"invalid custom format",10,0
.tbadtrkcnt	dc.b	"only one destination track must be specified",10,0
.tbadlen	dc.b	"invalid file length, got $%lx=%ld, expected $%lx=%ld",10,0
	EVEN

;##########################################################################
;##########################################################################
; read wwarp file,
; call given function after tracktable has been read,
; call given function on each track in the input file which is marked in gl_tabdo,
; optionally copy all tracks marked in tabout to new wwarp file (which will
; be created and renamed to the original on success)
; IN:	D0 = ULONG flags
;	A0 = APTR  data area for routines, provided in a0 on calling
;	A1 = FPTR  routine for tracktable (a0 = data)
;	A2 = FPTR  routine for tracks (d0 = trknum, a0 = data) returning -2=skip -1=success 0=fail
; OUT:	D0 = BOOL  success

	NSTRUCTURE cmdwork_locals,0
		NULONG	wl_flags
		NULONG	wl_tlseek	;file position of track table
		NBYTE	wl_tmpfile
		NBYTE	wl_tlmodi	;if true tracklist has been modified and must be rewritten at the end
		NSTRUCT	wl_pad,2
		NULONG	wl_cbdata
		NULONG	wl_cbtt
		NULONG	wl_cbt
		NULONG	wl_lt
		NLABEL	wl_SIZEOF

 BITDEF CMD,IN,0	;read input (obsolete)
 BITDEF CMD,OUT,1	;write output
 BITDEF CMD,NOTTC,2	;dont print warning for tracks in tabarg but not in tabin
 BITDEF CMD,TRKDATA,3	;unpack trackdata to gl_tmpbuf and set gl_trklen

_cmdwork	link	LOC,#wl_SIZEOF
		move.l	d0,(wl_flags,LOC)
		move.l	a0,(wl_cbdata,LOC)
		move.l	a1,(wl_cbtt,LOC)
		move.l	a2,(wl_cbt,LOC)
		sf	(wl_tmpfile,LOC)
		sf	(wl_tlmodi,LOC)
		move.l	#wfh_SIZEOF,(wl_tlseek,LOC)
		moveq	#0,d6				;d6 = fh input
		moveq	#0,d7				;d7 = fh output

		btst	#CMDB_IN,(wl_flags+3,LOC)
		beq	.noin1

	;open input file
		lea	(gl_filename,GL),a0
		bsr	_OpenRead
		move.l	d0,d6				;d6 = fh input
		beq	.error
	;read input file header
		bsr	_readfilehead

		beq	.error
	;read input track table
		bsr	_readtt
		beq	.error
	;copy original stamp to output file header
		lea	(gl_headin+wfh_ctime,GL),a0
		lea	(gl_headout+wfh_ctime,GL),a1
		move.l	(a0)+,(a1)+
		move.l	(a0)+,(a1)+
		move.l	(a0)+,(a1)+
	;if no track specification given copy gl_tabin to gl_tabarg
		tst.l	(gl_rd_tracks,GL)
		bne	.aftersetarg
		lea	(gl_tabin,GL),a0
		lea	(gl_tabarg,GL),a1
		bsr	_copytt
.aftersetarg
	;compare tabarg against tabin and print a warning for all tracks
	;delete also these tracks
	;which are in tabarg but not in tabin
		sf	d4
		move.l	#-1,d5
.loop		addq.l	#1,d5
		bftst	(gl_tabarg+wtt_tab,GL){d5:1}
		beq	.next
		bftst	(gl_tabin+wtt_tab,GL){d5:1}
		bne	.next
		bfclr	(gl_tabarg+wtt_tab,GL){d5:1}
		btst	#CMDB_NOTTC,(wl_flags+3,LOC)
		bne	.next
		lea	(_notinfile1),a0
		tst.b	d4
		beq	.nif1
		lea	(_notinfile2),a0
.nif1		st	d4
		move.l	d5,-(a7)
		move.l	a7,a1
		bsr	_PrintArgs
		add.w	#4,a7
.next		cmp.l	#MAXTRACKS-1,d5
		bne	.loop
		tst.b	d4
		beq	.nif2
		lea	(_notinfile3),a0
		bsr	_Print
.nif2
	;copy gl_tabin to gl_tabout
		lea	(gl_tabin,GL),a0
		lea	(gl_tabout,GL),a1
		bsr	_copytt
.noin1

		btst	#CMDB_OUT,(wl_flags+3,LOC)
		beq	.noout1
	;check if creating new or modifying existing
		btst	#CMDB_IN,(wl_flags+3,LOC)
		sne	(wl_tmpfile,LOC)
		bne	.tmpout

.newout
	;check file exists
		lea	(gl_filename,GL),a0
		move.l	a0,d1
		move.l	#ACCESS_READ,d2
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOLock,a6)
		move.l	d0,d1
		beq	.noold
		jsr	(_LVOUnLock,a6)
		lea	(_txt_exists),a0
		pea	(gl_filename,GL)
		move.l	a7,a1
		bsr	_PrintArgs
		addq.l	#4,a7
		bsr	_FlushOutput
		bsr	_GetKey
		move.b	d0,d2
		bsr	_PrintLn
		UPPER	d2
		cmp.b	#"Y",d2
		bne	.error

	;open new output file
.noold		lea	(gl_filename,GL),a0
		bsr	_OpenWrite
		move.l	d0,d7				;d7 = fh output
		bne	.fhoutok
		bra	.error

	;open temp output file
.tmpout		lea	(gl_filename,GL),a0
		lea	(gl_filename2,GL),a1
		move.l	#FILENAMELEN,d0
		bsr	_CopyString
		move.l	#"!"<<24,-(a7)
		move.l	a7,a0
		lea	(gl_filename2,GL),a1
		move.l	#FILENAMELEN,d0
		bsr	_AppendString
		add.w	#4,a7
		lea	(gl_filename2,GL),a0
		bsr	_OpenWrite
		move.l	d0,d7				;d7 = fh output
		beq	.error
.fhoutok
	;write output file header
		bsr	_writefilehead
		beq	.error

.noout1

	;copy gl_tabarg to gl_tabdo
		lea	(gl_tabarg,GL),a0
		lea	(gl_tabdo,GL),a1
		bsr	_copytt

	;callback tracktable
		move.l	(wl_cbtt,LOC),d0
		beq	.s1
		move.l	(wl_cbdata,LOC),a0
		movem.l	d2-d7/a2-a6,-(a7)
		jsr	(d0.l)
		movem.l	(a7)+,_MOVEMREGS
		tst.l	d0
		beq	.error
.s1
	;write output track table
		btst	#CMDB_OUT,(wl_flags+3,LOC)
		beq	.skipout2
		bsr	_writett
		beq	.error
.skipout2

	;count last track to process
		lea	(gl_tabdo+wtt_tab,GL),a0
		btst	#CMDB_OUT,(wl_flags+3,LOC)
		beq	.clt1
		lea	(gl_tabout+wtt_tab,GL),a0
.clt1		move.l	#MAXTRACKS-1,d0
.clt2		bftst	(a0){d0:1}
		dbne	d0,.clt2
		beq	.finish
		move.l	d0,(wl_lt,LOC)

	;***
	;do for each input track upto wl_lt
	;
		move.l	#-1,d5				;d5 = actual track
.trkloop	addq.l	#1,d5
		cmp.l	(wl_lt,LOC),d5
		bhi	.finish

	;check CTRL-C pressed
		bsr	_CheckBreak			;check for CTRL-C
		tst.l	d0
		bne	.break

	;input
		btst	#CMDB_IN,(wl_flags+3,LOC)
		beq	.noin2
		bftst	(gl_tabin+wtt_tab,GL){d5:1}
		beq	.noin2
	;read input track header
		bsr	_readth
		beq	.error
		cmp.w	(gl_trk+wth_num,GL),d5
		beq	.th_numok
		move.w	d5,-(a7)
		move.w	(gl_trk+wth_num,GL),-(a7)
		move.l	a7,a1
		lea	(_badthtrknum),a0
		bsr	_PrintArgs
		addq.l	#4,a7
		move.w	d5,(gl_trk+wth_num,GL)
.th_numok
	;if track in gl_tabread read track data else skip it
		bftst	(gl_tabread+wtt_tab,GL){d5:1}
		bne	.td_read
.td_skip	bsr	_skiptd
		beq	.error
		bra	.td_ok
.td_read	bsr	_readtd
		beq	.error
		btst	#CMDB_TRKDATA,(wl_flags+3,LOC)
		beq	.td_ok
		bsr	_unpacktrack
		move.l	d0,(gl_trklen,GL)
		beq	.error
.td_ok
.noin2

	;callback track if in tabdo
		bftst	(gl_tabdo+wtt_tab,GL){d5:1}
		beq	.nodo
		move.l	(wl_cbt,LOC),d1
		beq	.nodo
		move.l	d5,d0
		move.l	(wl_cbdata,LOC),a0
		movem.l	d2-d7/a2-a6,-(a7)
		jsr	(d1.l)
		movem.l	(a7)+,_MOVEMREGS
		tst.l	d0
		beq	.error
		cmp.l	#-1,d0
		beq	.nodo
		cmp.l	#-2,d0
		beq	.skip
		lea	(_badrcdotrk),a0
		bsr	_Print
		bra	.error
.skip		st	(wl_tlmodi,LOC)
		bfclr	(gl_tabout+wtt_tab,GL){d5:1}
.nodo

	;write
		btst	#CMDB_OUT,(wl_flags+3,LOC)
		beq	.trkloop
		bftst	(gl_tabout+wtt_tab,GL){d5:1}
		beq	.trkloop
	;write track
		bsr	_writet
		beq	.error
		bra	.trkloop

	;success, all tracks
.finish		move.l	#0,(gl_rc,GL)
.break
.error
	;rewrite track table if necessary
		tst.b	(wl_tlmodi,LOC)
		beq	.notlmodi
		move.l	(wl_tlseek,LOC),d0	;position
		move.l	d7,d1			;handle
		bsr	_SeekBeginning
		bsr	_writettnc
.notlmodi

	;close output file
		move.l	d7,d1
		bsr	_Close

	;close input file
		move.l	d6,d1
		bsr	_Close

	;success or fail
		tst.l	(gl_rc,GL)
		bne	.fail

.success
	;if tmpfile rename
		tst.b	(wl_tmpfile,LOC)
		beq	.end
		lea	(gl_filename,GL),a0
		move.l	a0,d1
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVODeleteFile,a6)
		lea	(gl_filename2,GL),a0
		move.l	a0,d1
		lea	(gl_filename,GL),a0
		move.l	a0,d2
		jsr	(_LVORename,a6)
		bra	.end

.fail
		tst.l	d7
		beq	.end
	;delete output file
		lea	(gl_filename,GL),a0
		tst.b	(wl_tmpfile,LOC)
		beq	.del
		lea	(gl_filename2,GL),a0
.del		move.l	a0,d1
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVODeleteFile,a6)

.end		unlk	LOC
		rts

;##########################################################################
;##########################################################################
;----------------------------------------
; open device
; IN:	-
; OUT:	D0 = BOOL  success
;	CC = D0

_OpenDevice	movem.l	a2/a6,-(a7)
		lea	(gl_io,GL),a2		;A2 = io structure (*iorequest,*msgport,DriveGeometry)

		move.l	(gl_execbase,GL),a6
		jsr	(_LVOCreateMsgPort,a6)
		move.l	d0,(4,a2)
		bne	.portok
		moveq	#0,d0
		lea	(_noport),a0
		sub.l	a1,a1
		bsr	_PrintError
		bra	.noport
.portok
		move.l	d0,a0
		move.l	#IOTD_SIZE,d0
		jsr	(_LVOCreateIORequest,a6)
		move.l	d0,(a2)
		bne	.ioreqok
		moveq	#0,d0
		lea	(_noioreq),a0
		sub.l	a1,a1
		bsr	_PrintError
		bra	.noioreq
.ioreqok
		lea	(_trackdisk),a0
		move.l	(gl_rd_unit,GL),d0		;unit
		move.l	(a2),a1				;ioreq
		moveq	#0,d1				;flags
		jsr	(_LVOOpenDevice,a6)
		tst.l	d0
		beq	.deviceok
		move.l	(a2),a1
		move.b	(IO_ERROR,a1),d0
		lea	(_opendevice),a0
		bsr	_PrintErrorTD
		bra	.nodevice
.deviceok
		move.l	(a2),a1
		move.w	#TD_CHANGENUM,(IO_COMMAND,a1)
		jsr	(_LVODoIO,a6)
		move.l	(a2),a1
		move.l	(IO_ACTUAL,a1),(IOTD_COUNT,a1)	;the diskchanges

		move.l	(a2),a1
		move.w	#TD_GETGEOMETRY,(IO_COMMAND,a1)
		lea	(8,a2),a0
		move.l	a0,(IO_DATA,a1)
		jsr	(_LVODoIO,a6)

		move.l	(8+dg_TotalSectors,a2),d0
		cmp.l	#DD_SECS,d0
		beq	.ok
		cmp.l	#HD_SECS,d0
		beq	.ok
		cmp.l	#SD_SECS,d0
		bne	.baddrive
		move.l	#DEFTRACKS_525,(gl_deftracks,GL)
		move.l	#MAXTRACKS_525,(gl_maxtracks,GL)
		
.ok		moveq	#-1,d0				;success

.end		movem.l	(a7)+,_MOVEMREGS
		rts

.baddrive	lea	(_baddrive),a0
		lea	(8+dg_TotalSectors,a2),a1
		bsr	_PrintArgs
		move.l	(a2),a1
		jsr	(_LVOCloseDevice,a6)
.nodevice	move.l	(a2),a0
		jsr	(_LVODeleteIORequest,a6)
.noioreq	move.l	(4,a2),a0
		jsr	(_LVODeleteMsgPort,a6)
.noport		moveq	#0,d0
		bra	.end

;----------------------------------------
; close device
; IN:	-
; OUT:	-

_CloseDevice	movem.l	a2/a6,-(a7)
		lea	(gl_io,GL),a2		;A2 = io structure (*iorequest,*msgport,DriveGeometry)

		move.l	(a2),a1
		move.l	#0,(IO_LENGTH,a1)
		move.w	#ETD_MOTOR,(IO_COMMAND,a1)
		move.l	(gl_execbase,GL),a6
		jsr	(_LVODoIO,a6)

		move.l	(a2),a1
		jsr	(_LVOCloseDevice,a6)

		move.l	(a2)+,a0
		jsr	(_LVODeleteIORequest,a6)

		move.l	(a2),a0
		jsr	(_LVODeleteMsgPort,a6)

		movem.l	(a7)+,_MOVEMREGS
		rts

;##########################################################################
;----------------------------------------
; write fileheader
; IN:	D7 = BPTR  filehandle
; OUT:	D0 = BOOL  success
;	CC = D0

_writefilehead	move.l	#FILEID,(gl_headout+wfh_id,GL)
		move	#FILEVER,(gl_headout+wfh_ver,GL)
		lea	(gl_headout+wfh_creator,GL),a0
		move	#CREATORLEN-1,d0
.cc		clr.b	(a0)+
		dbf	d0,.cc
		lea	(_txt_creator),a0
		lea	(gl_headout+wfh_creator,GL),a1
		move.l	#CREATORLEN,d0
		bsr	_CopyString
		lea	(gl_headout+wfh_mtime,GL),a0
		move.l	a0,d1
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVODateStamp,a6)
		move.l	#wfh_SIZEOF,d0		;length
		move.l	d7,d1			;handle
		lea	(gl_headout,GL),a0
		bra	_Write

;----------------------------------------
; write track table
; IN:	D7 = BPTR  filehandle
; OUT:	D0 = BOOL  success
;	CC = D0

_writett	lea	(gl_tabout,GL),a0
		move.l	#TABLEID,(wtt_id,a0)
		move	#TABLEVER,(wtt_ver,a0)
	;compress track table
		moveq	#-1,d0
		lea	(wtt_tab,a0),a1
	;search first used
.first		addq.l	#1,d0
		bftst	(a1){d0:1}
		beq	.first
		move.w	d0,(wtt_first,a0)
	;search last used
		move.l	#MAXTRACKS,d1
.last		subq.l	#1,d1
		bftst	(a1){d1:1}
		beq	.last
		move.w	d1,(wtt_last,a0)
	;shift table
		sub.l	d0,d1
		lsr.l	#5,d1
		move.l	d2,-(a7)
.copy		bfextu	(a1){d0:32},d2
		move.l	d2,(a1)+
		dbf	d1,.copy
		move.l	(a7)+,d2
	;calc size
		moveq	#0,d1
		move	(wtt_last,a0),d1
		sub	d0,d1
		addq	#8,d1
		lsr	#3,d1
		add	#wtt_tab,d1
		move.l	d1,d0			;length
		move.l	d7,d1			;handle
		bsr	_Write
		beq	.rts

		lea	(gl_tabout,GL),a0
		bsr	_expandtt

		moveq	#-1,d0
.rts		rts

; no compress

_writettnc	lea	(gl_tabout,GL),a0
		moveq	#0,d0
		move	(wtt_last,a0),d0
		sub	(wtt_first,a0),d0
		addq	#8,d0
		lsr	#3,d0
		add	#wtt_tab,d0		;length
		move.l	d7,d1			;handle
		bra	_Write

;----------------------------------------
; write track
; IN:	D7 = BPTR  filehandle
; OUT:	D0 = BOOL  success
;	CC = D0

_writet		move.l	#TRACKID,(gl_trk+wth_id,GL)
		move	#TRACKVER,(gl_trk+wth_ver,GL)
		move.l	#wth_data,d0		;length
		move.l	d7,d1			;handle
		lea	(gl_trk,GL),a0
		bsr	_Write
		beq	_rts
		move.l	(gl_trk+wth_len,GL),d0	;length
		addq.l	#7,d0
		lsr.l	#3,d0
		move.l	d7,d1			;handle
		move.l	(gl_fastbuf,GL),a0
		bra	_Write

;----------------------------------------
; read fileheader
; IN:	D6 = BPTR  filehandle
; OUT:	D0 = BOOL  success
;	CC = D0

_readfilehead	move.l	#wfh_SIZEOF,d0		;length
		move.l	d6,d1			;handle
		lea	(gl_headin,GL),a0	;buffer
		bsr	_Read
		beq	_rts

		cmp.l	#FILEID,(gl_headin+wfh_id,GL)
		bne	.badfile
		cmp.w	#FILEVER,(gl_headin+wfh_ver,GL)
		bne	_badstruct

		moveq	#-1,d0
		rts

.badfile	lea	(_txt_badfile),a0
		bsr	_Print
		bra	_readerr

_badstruct	lea	(_txt_badstruct),a0
		bsr	_Print
_readerr	moveq	#0,d0
		rts

;----------------------------------------
; read track table
; IN:	D6 = BPTR  filehandle
; OUT:	D0 = BOOL  success
;	CC = D0

_readtt		move.l	#wtt_tab,d0		;length
		move.l	d6,d1			;handle
		lea	(gl_tabin,GL),a0	;buffer
		bsr	_Read
		beq	_rts

		cmp.l	#TABLEID,(gl_tabin+wtt_id,GL)
		bne	_badstruct
		cmp.w	#TABLEVER,(gl_tabin+wtt_ver,GL)
		bne	_badstruct

		moveq	#0,d0
		move	(gl_tabin+wtt_last,GL),d0
		sub	(gl_tabin+wtt_first,GL),d0
		bcs	_badstruct
		addq.l	#8,d0
		lsr.l	#3,d0			;length
		move.l	d6,d1			;handle
		lea	(gl_tabin+wtt_tab,GL),a0
		bsr	_Read
		beq	_rts

		lea	(gl_tabin,GL),a0
		bsr	_expandtt

		moveq	#-1,d0
		rts

;----------------------------------------
; read track header
; IN:	D6 = BPTR  filehandle
; OUT:	D0 = BOOL  success
;	CC = D0

_readth		move.l	#wth_data_v1,d0		;length
		move.l	d6,d1			;handle
		lea	(gl_trk,GL),a0
		bsr	_Read
		beq	_rts

		cmp.l	#TRACKID,(gl_trk+wth_id,GL)
		bne	_badstruct
		cmp	#1,(gl_trk+wth_ver,GL)
		bne	.v2

.v1		and.w	#~TFF_INDEX,(gl_trk+wth_flags,GL)	;old versions couldn't read with indexsync!
		clr.w	(gl_trk+wth_syncnum,GL)
		bra	.ok

.v2		cmp	#TRACKVER,(gl_trk+wth_ver,GL)
		bne	_badstruct

		move.l	#wth_data-wth_data_v1,d0	;length
		move.l	d6,d1			;handle
		lea	(gl_trk+wth_data_v1,GL),a0
		bsr	_Read
		beq	_rts

.ok		moveq	#-1,d0
		rts

;----------------------------------------
; read track data
; IN:	D6 = BPTR  filehandle
; OUT:	D0 = BOOL  success
;	CC = D0

_readtd		move.l	(gl_trk+wth_len,GL),d0
		addq.l	#7,d0
		lsr.l	#3,d0
		cmp.l	#MAXTDLEN,d0
		bhi	.error
		move.l	d6,d1
		move.l	(gl_fastbuf,GL),a0
		bra	_Read

.error		lea	(_tdlenmax),a0
		pea	MAXTDLEN
		move.l	d0,-(a7)
		move.l	a7,a1
		bsr	_PrintArgs
		addq.l	#8,a7
		moveq	#0,d0
		rts

;----------------------------------------
; skip track data
; IN:	D6 = BPTR  filehandle
; OUT:	D0 = BOOL  success
;	CC = D0

_skiptd		move.l	d6,d1			;handle
		move.l	(gl_trk+wth_len,GL),d0
		addq.l	#7,d0
		lsr.l	#3,d0			;position
		bra	_SeekCurrent

;----------------------------------------
; convert given datestamp to strings
; IN:	A0 = APTR  stamp
; OUT:	-

_GetDate	move.l	a6,-(a7)

		move.b	#FORMAT_DOS,(gl_DateTime+dat_Format,GL)
		lea	(gl_time,GL),a1
		move.l	a1,(gl_DateTime+dat_StrTime,GL)
		lea	(gl_date,GL),a1
		move.l	a1,(gl_DateTime+dat_StrDate,GL)

		lea	(gl_DateTime+dat_Stamp,GL),a1
		move.l	(a0)+,(a1)+
		move.l	(a0)+,(a1)+
		move.l	(a0)+,(a1)+

		lea	(gl_DateTime,GL),a0
		move.l	a0,d1
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVODateToStr,a6)

	;fix that on some formats there is a trailing space
		lea	(gl_date,GL),a0
.l		tst.b	(a0)+
		bne	.l
		subq.l	#2,a0
		cmp.b	#" ",(a0)
		bne	.q
		clr.b	(a0)
.q
		move.l	(a7)+,a6
		rts

;----------------------------------------
; copy track table
; IN:	A0 = APTR  wtt source
;	A1 = APTR  wtt destination
; OUT:	-

_copytt		move.w	#wtt_tab+TABMAXLEN-1,d0
.1		move.b	(a0)+,(a1)+
		dbf	d0,.1
		rts

;----------------------------------------
; expand given track table
; IN:	A0 = APTR  wtt
; OUT:	-

_expandtt	move.l	#MAXTRACKS-1,d0
.loop		cmp	(wtt_last,a0),d0
		bhi	.clear
		cmp	(wtt_first,a0),d0
		blo	.clear
		move.l	d0,d1
		sub	(wtt_first,a0),d1
		bftst	(wtt_tab,a0){d1:1}
		bne	.set

.clear		bfclr	(wtt_tab,a0){d0:1}
.dbf		dbf	d0,.loop
		clr.w	(wtt_first,a0)
		move	#MAXTRACKS-1,(wtt_last,a0)
		rts

.set		bfset	(wtt_tab,a0){d0:1}
		bra	.dbf

;----------------------------------------
; get length of sync in bytes
; IN:	A0 = sync
; OUT:	D0 = LONG length

_getsynclen	add.w	#SYNCLEN,a0		;we check the mask
		moveq	#SYNCLEN-1,d0
.cnt		tst.b	(a0)+
		dbne	d0,.cnt
		addq.w	#1,d0
		rts

;----------------------------------------
; get length of mfm-data for sync search
; IN:	-
; OUT:	D0 = ULONG length

_getsyncsearchlen
		move.l	d3,-(a7)

		move.l	(gl_trklen,GL),d3		;d3 = bitlength buffer
		btst	#TFB_RAWSINGLE,(gl_trk+wth_flags+1,GL)
		beq	.nos

	;if we have single we must enlarge search buffer
		lsr.l	#1,d3
		lea	(gl_trk+wth_sync,GL),a0
		bsr	_getsynclen
		lsl.l	#3,d0
		subq.l	#1,d0
		add.l	d0,d3				;d3 = bitlength buffer

.nos		move.l	d3,d0
		move.l	(a7)+,d3
		rts

;##########################################################################
;----------------------------------------
; expand rawsinge track to double size
; IN:	-
; OUT:	d0 = ULONG track length in bits

_doubleraws	move.l	(gl_trk+wth_len,GL),d0
		btst	#TFB_RAWSINGLE,(gl_trk+wth_flags+1,GL)
		bne	.single
		rts

.single		move.l	d0,-(a7)
		add.l	d0,(a7)
		move.l	d2,a1
		move.l	d0,d1
		lsr.l	#5,d1
		move.l	(gl_fastbuf,GL),a0
		sub.l	#32,d0
.loop		move.l	(a0)+,d2
		bfins	d2,(a0){d0:32}
		dbf	d1,.loop
		move.l	a1,d2
		move.l	(a7)+,d0
		rts

;----------------------------------------
; get track type
; IN:	-
; OUT:	A0 = APTR to structure WWarpFormat

_gettt		move.w	(gl_trk+wth_type,GL),d0

		lea	(_format_raw),a0
.next		cmp.w	(wwf_type,a0),d0
		beq	.found
		move.l	(wwf_succ,a0),a0
		move.l	a0,d1
		bne	.next

		lea	(_format_unknown),a0
.found		rts

;----------------------------------------
; shift mfm buffer
; IN:	D0 = ULONG  bitoffset in buffer which make the new start
;	D1 = ULONG  bitlength for new mfm-buffer
;	A0 = APTR   mfm-buffer
; OUT:	-

_shiftmfm	move.l	d2,a1
		lsr.l	#5,d1
.loop		bfextu	(a0){d0:32},d2
		move.l	d2,(a0)+
		dbf	d1,.loop
		move.l	a1,d2
		rts

;----------------------------------------
; search sync and count occurencies in mfm buffer
; IN:	D0 = ULONG  number of sync to search
;	D1 = ULONG  bitlength of mfm-buffer
;	A0 = APTR   mfm-buffer
;	A1 = STRUCT sync to search (16 byte sync + 16 byte mask)
; OUT:	D0 = ULONG  bitoffset in buffer where first sync has been found, -1 on error
;	D1 = ULONG  amount of syncs found

_countsync	movem.l	d2-d7/a2,-(a7)

		moveq	#0,d2			;D2 = count
		moveq	#-1,d3			;D3 = first sync
		moveq	#0,d4			;D4 = offset
		move.l	d1,d5			;D5 = buffer length
		move.l	a0,d6			;D6 = buffer
		move.l	a1,a2			;A2 = sync
		move.l	d0,d7			;D7 = syncno
		bne	.1
		moveq	#1,d7
.1

.loop		move.l	d4,d0			;offset
		move.l	d5,d1			;buffer length
		move.l	d6,a0			;buffer
		move.l	a2,a1			;sync
		bsr	_searchsync
		tst.l	d0
		bmi	.end
		addq.l	#1,d2
		cmp.l	d7,d2
		bne	.not
		move.l	d0,d3
.not		move.l	d0,d4
		addq.l	#1,d4
		cmp.l	d5,d4
		blo	.loop

.end		move.l	d3,d0			;first
		move.l	d2,d1			;count
		movem.l	(a7)+,_MOVEMREGS
		rts

;----------------------------------------
; search sync in mfm buffer
; IN:	D0 = ULONG  bitoffset in buffer to start search
;	D1 = ULONG  bitlength of mfm-buffer
;	A0 = APTR   mfm-buffer
;	A1 = STRUCT sync to search (16 byte sync + 16 byte mask)
; OUT:	D0 = ULONG  bitoffset in buffer where sync has been found, -1 on error

_searchsync	movem.l	d2-d7/a2,-(a7)

	;count bits to compare
		move.l	#SYNCLEN*8-1,d2
		moveq	#-1,d3
.cs		addq.l	#1,d3
		bftst	(SYNCLEN,a1){d3:1}
		dbne	d2,.cs
		addq.l	#1,d2			;D2 = bits to compare (synclen)
		beq	.err

	;search for sync
		subq.l	#1,d0			;because loop starts with increment
		move.l	d2,a2			;A2 = bits to compare (synclen)

	;outer loop (128 bit - full size)
.lo		move.l	a2,d2			;D2 = actual bits to compare (synclen)
		moveq	#32,d6
		cmp.l	d6,d2
		bhs	.s1
		move.l	d2,d6			;D6 = actual synclen
.s1
		move.l	#SYNCLEN*8,d5
		sub.l	d2,d5			;D5 = actual syncoffset
		bfextu	(SYNCLEN,a1){d5:d6},d3	;D3 = mask
		bfextu	(a1){d5:d6},d4		;D4 = sync
		and.l	d3,d4

	;inner loop (32 bit)
.li		addq.l	#1,d0
		cmp.l	d1,d0
		bhs	.err
		bfextu	(a0){d0:d6},d7
		and.l	d3,d7
		cmp.l	d4,d7
		bne	.li

		sub.l	d6,d2
		beq	.end

		moveq	#32,d6
		cmp.l	d6,d2
		bhs	.s2
		move.l	d2,d6			;D6 = actual synclen
.s2		move.l	#SYNCLEN*8,d5
		sub.l	d2,d5			;D5 = actual syncoffset
		bfextu	(SYNCLEN,a1){d5:d6},d3	;D3 = mask
		bfextu	(a1){d5:d6},d4		;D4 = sync
		and.l	d3,d4
		bfextu	(4,a0){d0:d6},d7
		and.l	d3,d7
		cmp.l	d4,d7
		bne	.lo

		sub.l	d6,d2
		beq	.end

		moveq	#32,d6
		cmp.l	d6,d2
		bhs	.s3
		move.l	d2,d6			;D6 = actual synclen
.s3		move.l	#SYNCLEN*8,d5
		sub.l	d2,d5			;D5 = actual syncoffset
		bfextu	(SYNCLEN,a1){d5:d6},d3	;D3 = mask
		bfextu	(a1){d5:d6},d4		;D4 = sync
		and.l	d3,d4
		bfextu	(8,a0){d0:d6},d7
		and.l	d3,d7
		cmp.l	d4,d7
		bne	.lo

		sub.l	d6,d2
		beq	.end

		move.l	#SYNCLEN*8,d5
		sub.l	d2,d5			;D5 = actual syncoffset
		bfextu	(SYNCLEN,a1){d5:d2},d3	;D3 = mask
		bfextu	(a1){d5:d2},d4		;D4 = sync
		and.l	d3,d4
		bfextu	(12,a0){d0:d2},d7
		and.l	d3,d7
		cmp.l	d4,d7
		bne	.lo

.end		movem.l	(a7)+,_MOVEMREGS
		rts

.err		moveq	#-1,d0
		bra	.end

;##########################################################################
;----------------------------------------
; print sync
; IN:	D0 = ULONG ident on line switch on large syncs
;	D1 = ULONG flags, 0=stdout 1=buffer
;	A0 = APTR  sync
;	A1 = APTR  buffer (only if flags=1)
; OUT:	-

_printsync	movem.l	d2-d5/a2-a3/LOC/a6,-(a7)
		move.l	d0,d4			;d4 = ident
		move.l	d1,d5			;d5 = flags
		move.l	a0,a3			;a3 = sync
		move.l	a1,LOC			;LOC = buffer
		lea	(SYNCLEN,a3),a0
		moveq	#SYNCLEN-1,d3
.cnt		tst.b	(a0)+
		dbne	d3,.cnt
		cmp.w	#1,d3
		bge	.ndef
		moveq	#1,d3
.ndef		lea	(SYNCLEN-1,a3),a2
		move.w	d3,d2
		bsr	.ps
		cmp.w	#8,d3
		bls	.small
		bsr	.PrintLn
		subq.w	#2,d4
		bcs	.small
		bsr	.ident
.small		lea	(_amp),a0
		bsr	.PrintArgs
		lea	(2*SYNCLEN-1,a3),a2
		move.w	d3,d2
		bsr	.ps
	;check for sync/mask mismatch
		moveq	#SYNCLEN/4-1,d0
		lea	(SYNCLEN,a3),a0
.chk		move.l	(a3)+,d1
		move.l	(a0)+,d2
		not.l	d2
		and.l	d2,d1
		bne	.mismatch
		dbf	d0,.chk
.end		tst.l	d5
		beq	.quit
		clr.b	(LOC)
.quit		movem.l	(a7)+,_MOVEMREGS
		rts

.ps		sub.w	d2,a2
.p		lea	(_lx),a0
		moveq	#0,d0
		move.b	(a2)+,d0
		move.l	d0,-(a7)
		move.l	a7,a1
		bsr	.PrintArgs
		add.w	#4,a7
		dbf	d2,.p
		rts

.mismatch	lea	(_syncmismatch),a0
		bsr	.PrintArgs
		bra	.end

.PrintArgs	tst.l	d5
		beq	_PrintArgs
		move.l	a2,-(a7)
		moveq	#-1,d0
		move.l	LOC,a2
		bsr	_FormatString
.search		tst.b	(LOC)+
		bne	.search
		subq.l	#1,LOC
		move.l	(a7)+,a2
		rts
.PrintLn	tst.l	d5
		beq	_PrintLn
		move.b	#10,(LOC)+
		rts

.ident		tst.l	d5
		beq	.ident_dos
.ident_buf_lp	move.b	#" ",(LOC)+
		dbf	d4,.ident_buf_lp
		rts
.ident_dos	move.l	(gl_dosbase,GL),a6
.ident_dos_lp	jsr	(_LVOOutput,a6)
		move.l	d0,d1
		moveq	#" ",d2
		jsr	(_LVOFPutC,a6)
		dbf	d4,.ident_dos_lp
		rts

;----------------------------------------
; print value as bit count in hex
; IN:	D0 = ULONG value to print
; OUT:	-

_printbitlen	move.l	d0,d1
		lsr.l	#3,d0
		and.l	#7,d1
		movem.l	d0-d1,-(a7)
		lea	(_bitlen),a0
		move.l	a7,a1
		bsr	_PrintArgs
		addq.l	#8,a7
		rts

_TxtBold	lea	(_txt_bold),a0
		bra	_Print

_TxtReset	lea	(_txt_reset),a0
		bra	_Print

_PrintBold	pea	(a0)
		bsr	_TxtBold
		move.l	(a7)+,a0
		bsr	_Print
		bra	_TxtReset

;##########################################################################
;----------------------------------------
; patch trackdisk device to allow access to cylinder 80/81
; IN:	D0 = ULONG track to access
;	A1 = APTR  ioreq
; OUT:	-

_tdenable81	move.l	d2,-(a7)
		cmp.w	#160,d0
		blo	.end

	;check hackdisk.device
		move.l	(IO_DEVICE,a1),a0
		cmp.l	#"Hack",([LIB_IDSTRING,a0])
		bne	.check_td
		move.l	(IO_UNIT,a1),a0
	;offset taken from hackdisk source:
		cmp.b	#160,(TDU_PUBLICUNITSIZE+TV_SIZE+MLH_SIZE+7,a0)
		bne	.check_td
		move.b	#MAXTRACKS,(TDU_PUBLICUNITSIZE+TV_SIZE+MLH_SIZE+7,a0)
		move.l	#"Hack",(gl_tdpatchdata,GL)
		bra	.patched

	;ckeck trackdisk.device
.check_td	move.l	(IO_UNIT,a1),a0
		move.l	#512,d2
		mulu.l	(gl_io+8+dg_TotalSectors,GL),d2

		moveq	#$28,d1
.search		cmp.l	(a0),d2
		beq	.found_td
		addq.l	#2,a0
		dbf	d1,.search
		bra	.end

.found_td	subq.l	#2,a0
		cmp.w	#160,(a0)
		bne	.end
		move.w	#MAXTRACKS,(a0)+
		divu.l	#160,d2
		mulu.l	#MAXTRACKS,d2
		move.l	d2,(a0)
		move.l	d2,(gl_tdpatchdata,GL)

.patched	move.w	d0,(gl_tdpatchtrk,GL)
		st	(gl_tdpatchdone,GL)

.end		move.l	(a7)+,d2
		rts

;----------------------------------------
; remove trackdisk device patch
; IN:	A1 = APTR  ioreq
; OUT:	-

_tddisable81	tst.b	(gl_tdpatchdone,GL)
		beq	.end

		move.l	(IO_UNIT,a1),a0
		move.l	(gl_tdpatchdata,GL),d0

		cmp.l	#"Hack",d0
		bne	.trackdisk

.hackdisk	move.b	#160,(TDU_PUBLICUNITSIZE+TV_SIZE+MLH_SIZE+7,a0)
		bra	.unpatched

.trackdisk	moveq	#$28,d1
.search		cmp.l	(a0),d0
		beq	.found
		addq.l	#2,a0
		dbf	d1,.search
		bra	.end

.found		subq.l	#2,a0
		cmp.w	#MAXTRACKS,(a0)
		bne	.end
		move.w	#160,(a0)+
		divu.l	#MAXTRACKS,d0
		mulu.l	#160,d0
		move.l	d0,(a0)

.unpatched	sf	(gl_tdpatchdone,GL)

.end		rts

;##########################################################################

_txt_help	dc.b	155,"1m"
		sprintx	"WWarp %ld.%ld [build ",Version,Revision
	INCBIN	".build"
		dc.b	"] "
	INCBIN	".date"
		dc.b	155,"0m",10,155,"4msynopsis:",155,"0m",10
		dc.b	"	WWarp filename[.wwp] [command] [tracks] [args] [options...]",10
		dc.b	155,"4mcommands:",155,"0m",10
		dc.b	"	C - create wwarp file (default)",10
		dc.b	"	    use import=filename to read file via trackwarp.library",10
		dc.b	"	D - dump track(s)",10
		dc.b	"	    args = [sync[&mask]][,[syncno][,[len][,off]]]",10
		dc.b	"	F - force tracks to known format, rerun custom format detection",10
		dc.b	"	G - create decoded disk image",10
		dc.b	"	    args = name of file to save (default=Disk.1)",10
		dc.b	"	I - print informations about wwarp file",10
		dc.b	"	L - set track length",10
		dc.b	"	    args = length",10
	;	dc.b	"	M - merge two wwarp files together",10
	;	dc.b	"	    args = wwarp-to-add",10
		dc.b	"	P - pack wwarp file, remove unnecessary data",10
		dc.b	"	R - remove tracks from a wwarp file",10
		dc.b	"	S - save tracks (mfm/custom format)",10
		dc.b	"	W - write wwarp file back to disk",10
		dc.b	"	Y - set sync",10
		dc.b	"	    args = [sync[&mask]][,syncno]",10
		dc.b	"	Z - write data given as filename to disk",10
		dc.b	"	    args = custom format as number",10
		dc.b	155,"4mtracks:",155,"0m",10
		dc.b	"	1-5		tracks 1,2,3,4,5",10
		dc.b	"	2,90		tracks 2 and 90",10
		dc.b	"	2*2		tracks 2,4,...,156,158",10
		dc.b	"	10-20*5		tracks 10,15,20",10
		dc.b	"	1-5,7,99-104*2	tracks 1,2,3,4,5,7,99,101,103",10
		dc.b	"	*		all tracks",10
		dc.b	155,"4moptions:",155,"0m",10
		dc.b	"	BPT=BytesPerTrack/K - rawread/write bytes, default $6c00",10
		dc.b	"	DBG/K/N - enable debugging messages",10
		dc.b	"	Force/S - enable detection of formats with flag force",10
		dc.b	"	Import/K - import alien file via trackwarp.library",10
		dc.b	"	NoFmt/K - don't try to detect specified formats, e.g. NoFmt=16,30",10
		dc.b	"	NoStd/S - don't try to detect known formats",10
		dc.b	"	NV=NoVerify/S - disables verify on write",10
		dc.b	"	RC=RetryCnt/N/K - number of read retries, default 6",10
		dc.b	"	SYBIL/S - use SYBIL hardware to write long tracks",10
		dc.b	"	Unit/N/K - trackdisk.device unit number, use 1 for DF1:",10
		dc.b	155,"4msupported custom formats:",155,"0m",10
		dc.b	"(slen=special length, mrlen=min read length,",10
		dc.b	"wlen=write length, flags: I=index F=force)",10
		dc.b	"  # name        slen  len  mrlen  wlen flags sync"
_txt_nl		dc.b	10,0
_fmtinfo1	dc.b	"%3d ",0
_fmtinfo2	dc.b	"$%4x $%4x $%4x $%4x    ",0
_fmtsynctab	dc.b	"					     ",0
_txt_bold	dc.b	155,"1m",0
_txt_reset	dc.b	155,"22m",0
_txt_badtracks	dc.b	"Invalid [tracks] specification",10,0
_txt_nofmtill	dc.b	"Invalid argument for NoFmt option",10,0
_txt_nofmtnf	dc.b	"format type %ld cannot be found to disable from NoFmt option",10,0
_txt_badcmd	dc.b	"Invalid [command]",10,0
_extension	dc.b	".wwp",0
_txt_createdev	dc.b	'creating new wwarp file "%s" from DF%ld: %ld tracks',10,0
_txt_createfile	dc.b	'creating new wwarp file "%s" from file "%s" using trackwarp.library',10,0
_txt_exists	dc.b	'file "%s" already exists, overwrite ? (yN) ',0
_diskprogress	dc.b	"reading track %ld",0
_trklens	dc.b	" single"
_trklen		dc.b	" raw trklen=$%lx.%ld",10,0
_txt_badfile	dc.b	"file is not a WWarp file.",10,0
_txt_badstruct	dc.b	"structure of WWarp file is corrupt.",10,0
_txt_infohead1	dc.b	"created by: ",0
_txt_infohead2	dc.b	10,"created at: %s %s",10,0
_txt_infohead3	dc.b	"last modified at: %s %s",10,0
_txt_infohead4	dc.b	"total tracks in file: %ld",10
		dc.b	"trk type  flags length  wlen  sync",10,0
_txt_infotrack	dc.b	"%3ld %s ",0
_lx		dc.b	"%02lx",0
_amp		dc.b	"&",0
_syncmismatch	dc.b	" sync/mask mismatch!",0
_length		dc.b	" $%4lx.%ld $%04lx ",0
_bitlen		dc.b	"$%lx.%ld",0
_syncnum	dc.b	",#%ld",0
_synccnt	dc.b	" «%ld»",0
_syncoff	dc.b	" %ld=",0
_needlength	dc.b	"length must be specified",10,0
_wronglength	dc.b	"invalid length (must be even and positive)",10,0
_notinfile1	dc.b	"warning, tracks %ld",0
_notinfile2	dc.b	",%ld",0
_notinfile3	dc.b	" aren't contained in wwarp file!",10,0
_lenbadtype	dc.b	"error track %d, type must be raw!",10,0
_lentobig	dc.b	"error track %d, length cannot be larger than stored track size!",10,0
_forcebadtype	dc.b	"skipping track %d, no raw mfm-data!",10,0
_forcebad	dc.b	"skipping track %d, could not decode",10,0
_needsync	dc.b	"sync must be specified",10,0
_badsync	dc.b	"invalid sync",10,0
_sync_not	dc.b	"error track %ld, sync not found!",10,0
_sync_less	dc.b	"error track %ld, too less syncs found!",10,0
_dump1		dc.b	"track=%ld type=%s flags=%c%c len=$%4lx.%ld wlen=$%04lx sync=",0
_badarg		dc.b	"Invalid [arg]",10,0
_offerr		dc.b	"error, offset invalid",10,0
_syncfound2	dc.b	"sync found %ld times, using #%ld offset ",0
_syncfound3	dc.b	"sync found %ld times, using offset 0",10,0
_moreverifysync	dc.b	"warning %ld syncs found during verify, ",0
_moresync	dc.b	"warning %ld syncs found using first, ",0
_unknowntt	dc.b	"unknown track type",10,0
_nosyncset	dc.b	"error sync must be set",10,0
_lesssync	dc.b	"too less syncs found",10,0
_corrupt	dc.b	"wwarp file is corrupt",10,0
_encoder_na	dc.b	"format encoder is not available",10,0
_encoder_badlen	dc.b	"format encoder has returned bad mfm length",10,0
_encoder_badend	dc.b	"format encoder mfm end is corrupt",10,0
_encoder_badstrt dc.b	"format encoder mfm start is corrupt",10,0
_encoder_fail	dc.b	"format encoder has failed",10,0
_verifyerrsync	dc.b	"verify error, sync not found!",10,0
_verifyerrdec	dc.b	"verify error, decoding failed!",10,0
_verifyerrcmp	dc.b	"verify error, decoded data differs!",10,0
_verifyerroff1	dc.b	"verify error first offset at ",0
_verifyerroff2	dc.b	" last offset at ",0
_verifyerroff3	dc.b	" !",10,0
_longtrk	dc.b	"track=$%lx too long to write using this drive=",0
_wtrack		dc.b	"writing track %ld, format %s",10,0
_notracks	dc.b	"error tracks must be specified",10,0
_lesstrkdata1	dc.b	"error: ",0
_lesstrkdata2	dc.b	" bytes are to less to write ",0
_lesstrkdata3	dc.b	" bytes",10,0
_writetrk	dc.b	"writing track %d, ",0
_writebytes	dc.b	" bytes, ",0
_writesuc	dc.b	"success.",10,0
_baddrive	dc.b	"drive has %ld sectors, which isn't supported",10,0
_disk1		dc.b	"Disk.1",0
_imagewritten	dc.b	"disk image '%s' has been written, size=%ld",10,0
_fmttried	dc.b	" %s=",0
_tdlenmax	dc.b	"invalid trackdata length in file $%lx (max=$%lx)",10,0

_decoded	dc.b	" format %s ($%x+%x bytes)",10,0
_nosync		dc.b	"no sync found",10,0
_noport		dc.b	"can't create MessagePort",0
_noioreq	dc.b	"can't create IO-Request",0
_readdisk	dc.b	"read disk",0
_movehead	dc.b	"move head",0
_writedisk	dc.b	"write disk",0
_opendevice	dc.b	"open device",0
_badkick	dc.b	"Sorry, WWarp requires Kickstart 2.0 or better.",10,0
_badcpu		dc.b	"Sorry, WWarp requires a 68020 or better.",10,0
_readargs	dc.b	"read arguments",0
_twnolib	dc.b	"cannot open trackwarp.library",10,0
_twnoopen	dc.b	"cannot open file",0
_twnoti		dc.b	"couldn't allocate trackwarp info buffer",0
_twdataunknown	dc.b	"cannot read data, unknown format type %d",10,0

_warnnosync	dc.b	"warning, no sync specified for track %ld",10,0
_errornosync	dc.b	"error, sync not found on track %ld",10,0
_errornolen	dc.b	"error, write length must be specified for track %ld",10,0
_errorbadlen	dc.b	"error, not enough data for write length on track %ld",10,0
_badtrkdatlen	dc.b	"error in wwarp file, track data length did not match",10,0
_mfmencode	dc.b	"encoded mfm-data:",10,0
_dbgmfm0000	dc.b	"binary 0000 found in encoded mfm at ",0
_dbgmfm11	dc.b	"binary 11 found in encoded mfm at ",0
_dbgmfm		dc.b	", $%lx=%08lx",10,0
_densrequired	dc.b	"dynamic density control required (SYBIL)",10,0
_densindex	dc.b	"dynamic density control doesn't work with INDEX",10,0
_densbadlen	dc.b	"dynamic density control minrawlen mismatch",10,0
_badthtrknum	dc.b	"bad trknum in th, is=%d requested=%d",10,0
_badrcdotrk	dc.b	"internal error: rc dotrk invalid",10,0

;subsystems
_dosname	DOSNAME
_trackdisk	dc.b	"trackdisk.device",0
_timername	dc.b	"timer.device",0
_twname		dc.b	"trackwarp.library",0

_template	dc.b	"Filename/A"		;file to create/read
		dc.b	",Command"		;operation to perform
		dc.b	",Tracks"		;tracks affected
		dc.b	",Argument"		;depending on operation
		dc.b	",Import/K"		;read file via trackwarp.library
		dc.b	",BPT=BytesPerTrack/K"	;
		dc.b	",Unit/N/K"		;drive unit to read from/write to
		dc.b	",NoStd/S"		;don't try to decode known formats
		dc.b	",NoFmt/K"		;list of known formats to not decode
		dc.b	",Force/S"		;detect also formats with Force
		dc.b	",RC=RetryCnt/N/K"	;how many retries
		dc.b	",NV=NoVerify/S"	;don't verify writes
		dc.b	",SYBIL/S"		;use SYBIL hardware
		dc.b	",DBG/K/N"		;debug level
		dc.b	0

;##########################################################################

	SECTION c,BSS,CHIP

_chipbuf	ds.b	MAXTDLEN

;##########################################################################

	SECTION g,BSS

_Globals	ds.b	gl_SIZEOF

;##########################################################################

	END
