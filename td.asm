;*---------------------------------------------------------------------------
;  :Program.	td.asm
;  :Contents.	trackdisk test tool, read/write single sector including label
;		data using trackdisk.device
;  :Author.	Bert Jahn
;  :History.	2020-08-23 initial
;  :Requires.	OS V37+
;  :Copyright.	© 2020 Bert Jahn, All Rights Reserved
;  :Language.	68000 Assembler
;  :Translator.	basm 2.16, vasm
;  :To Do.
;---------------------------------------------------------------------------*
;##########################################################################

	INCDIR	Includes:
	INCLUDE	lvo/exec.i
	INCLUDE	exec/execbase.i
	INCLUDE	lvo/dos.i
	INCLUDE	dos/dos.i
	INCLUDE	devices/trackdisk.i

	INCLUDE	macros/sprint.i

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

	STRUCTURE	Globals,0
		APTR	gl_execbase
		APTR	gl_dosbase
		APTR	gl_rdargs
		LABEL	gl_rdarray
		ULONG	gl_rd_data		; data filename
		ULONG	gl_rd_label		; label data filename
		ULONG	gl_rd_sector		; sector number
		ULONG	gl_rd_write		; write instead read
		ULONG	gl_rd_unit		; unit number
		ULONG	gl_rc			; programs return code
		STRUCT	gl_io,8+dg_SIZEOF	; *iorequest,*msgport,DriveGeometry
		STRUCT	gl_data,TD_SECTOR	; sector data
		STRUCT	gl_label,TD_LABELSIZE	; label data
		LABEL	gl_SIZEOF

;##########################################################################

GL	EQUR	A4		;a4 ptr to Globals
LOC	EQUR	A5		;a5 for local vars
CPU	=	68000

Version		= 0
Revision	= 1

	SECTION a,CODE

		bra	_Start

		dc.b	"$VER: "
_txt_creator	sprint	<"td ">,Version,<".">,Revision,<" ">
		INCBIN	".date"
		dc.b	0
	EVEN

;##########################################################################

	INCDIR	sources
	INCLUDE	dosio.i
		PrintArgs
	INCLUDE	files.i
		LoadFileMsg
		SaveFileMsg
	INCLUDE	error.i
		PrintErrorDOS
		PrintErrorTD

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
		lea	(_readargs),a0
		bsr	_PrintErrorDOS
		bra	.noargs
.argsok
	; open trackdisk.device
		bsr	_OpenDevice
		beq	.nodev
		move.l	(gl_io,GL),a5		; A5 = io

	; message
		move.l	(gl_rd_sector,GL),a0
		move.l	(a0),d0
		move.l	#TD_SECTOR,d7
		mulu.w	d0,d7			; D7 = offset
		move.l	d0,d6
		move.l	(gl_io+8+dg_TrackSectors,GL),d1
		divu	d1,d6
		swap	d6			; D6 = track/sector
		move.l	d6,-(a7)		; track/sector
		move.l	d7,-(a7)		; offset
		move.l	d0,-(a7)		; sector
		lea	_process,a0
		move.l	a7,a1
		bsr	_PrintArgs
		add.w	#3*4,a7
	
	; init ioreq
		move.l	d7,(IO_OFFSET,a5)
		move.l	#TD_SECTOR,(IO_LENGTH,a5)
		clr.b	(IO_FLAGS,a5)
		clr.b	(IO_ERROR,a5)

	; check mode
		tst.l	(gl_rd_write,GL)
		bne	.write

	; read mode
		move.l	a5,a1			; io
		lea	(gl_data,GL),a0
		move.l	a0,(IO_DATA,a5)
		lea	(gl_label,GL),a0
		move.l	a0,(IOTD_SECLABEL,a5)
		move.w	#ETD_READ,(IO_COMMAND,a1)
		move.l	(gl_execbase,GL),a6
		jsr	(_LVODoIO,a6)
		move.b	(IO_ERROR,a5),d0
		bne	.readerr
	; write data
		move.l	#TD_SECTOR,d0		; length
		lea	(gl_data,GL),a0		; buffer
		move.l	(gl_rd_data,GL),a1	; filename
		bsr	_SaveFileMsg
	; write label data
		move.l	#TD_LABELSIZE,d0	; length
		lea	(gl_label,GL),a0	; buffer
		move.l	(gl_rd_label,GL),a1	; filename
		move.l	a1,d1
		beq	.freedev
		bsr	_SaveFileMsg
		bra	.freedev

.readerr	lea	(_readdisk),a0
		bsr	_PrintErrorTD
		bra	.freedev

	; write mode
.write		move.l	(gl_rd_data,GL),a0
		bsr	_LoadFileMsg
		move.l	d0,d2			; D2 = data
		beq	.freedev
		move.l	(gl_rd_label,GL),a0
		move.l	a0,d4
		beq	.nolab
		bsr	_LoadFileMsg
		move.l	d0,d4			; D4 = label data
		beq	.freedata
.nolab
		move.l	a5,a1			; io
		move.l	d2,(IO_DATA,a5)
		move.l	d4,(IOTD_SECLABEL,a5)
		move.w	#ETD_WRITE,(IO_COMMAND,a1)
		move.l	(gl_execbase,GL),a6
		jsr	(_LVODoIO,a6)
		move.b	(IO_ERROR,a5),d0
		beq	.freelabel

.writeerr	lea	(_writedisk),a0
		bsr	_PrintErrorTD

.freelabel	tst.l	d4
		beq	.freedata
		move.l	d4,a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOFreeVec,a6)
	
.freedata	move.l	d2,a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOFreeVec,a6)

	; close trackdisk.device
.freedev	tst.l	(gl_io,GL)
		beq	.nodev
		bsr	_CloseDevice
.nodev
	; free args
		move.l	(gl_rdargs,GL),d1
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOFreeArgs,a6)
.noargs
		move.l	(gl_dosbase,GL),a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOCloseLibrary,a6)
.nodoslib
		move.l	(gl_rc,GL),d7
_rts		rts

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
		beq	.unitok
		move.l	d0,a1
		move.l	(a1),d0
.unitok		move.l	(a2),a1				;ioreq
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

		moveq	#-1,d0				;success

.end		movem.l	(a7)+,_MOVEMREGS
		rts

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

_badkick	dc.b	"requires Kickstart 2.0 or better.",10,0
_readargs	dc.b	"read arguments",0
_noport		dc.b	"can't create MessagePort",0
_noioreq	dc.b	"can't create IO-Request",0
_readdisk	dc.b	"read disk",0
_writedisk	dc.b	"write disk",0
_opendevice	dc.b	"open device",0
_process	dc.b	"processing sector=%ld offset=$%lx track=%d/%d",10,0

;subsystems
_dosname	DOSNAME
_trackdisk	dc.b	"trackdisk.device",0

_template	dc.b	"D=Data/K/A"		; data filename
		dc.b	",L=LabelData/K"	; label data filename
		dc.b	",S=Sector/K/N"		; sector number to read/write
		dc.b	",Write/S"		; write instead read
		dc.b	",Unit/K/N"		; unit number
		dc.b	0

;##########################################################################

	SECTION g,BSS

_Globals	ds.b	gl_SIZEOF

;##########################################################################

	END
