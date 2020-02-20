;*---------------------------------------------------------------------------
;  :Program.	encode.asm
;  :Contents.	encodes data to mfm
;  :Author.	Bert Jahn
;  :EMail.	wepl@whdload.de
;  :Version	$Id: encode.asm 1.2 2005/04/07 23:36:50 wepl Exp wepl $
;  :History.	06.02.02 initial
;		20.02.20 adapted for vamos build
;  :Requires.	OS V37+
;  :Language.	68000 Assembler
;  :Translator.	Barfly V2.9
;  :To Do.
;---------------------------------------------------------------------------*
;##########################################################################

	INCDIR	Includes:
	INCLUDE	lvo/exec.i
	INCLUDE	exec/execbase.i
	INCLUDE	lvo/dos.i
	INCLUDE	dos/dos.i

	INCLUDE	macros/ntypes.i

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

	STRUCTURE	Globals,0
		APTR	gl_execbase
		APTR	gl_dosbase
		APTR	gl_rdargs
		LABEL	gl_rdarray
		ULONG	gl_rd_input
		ULONG	gl_rd_output
		ULONG	gl_rc			;programs return code
		ALIGNLONG
		LABEL	gl_SIZEOF

;##########################################################################

GL	EQUR	A4		;a4 ptr to Globals
LOC	EQUR	A5		;a5 for local vars
CPU	=	68000

	OUTPUT	C:encode
	IFD _BARFLY_
	BOPT	O+			;enable optimizing
	BOPT	OG+			;enable optimizing
	BOPT	ODd-			;disable mul optimizing
	BOPT	ODe-			;disable mul optimizing

	IFND	.passchk
	DOSCMD	"WDate  >.date"
.passchk
	ENDC
	ENDC

Version		= 1
Revision	= 0

	SECTION a,CODE

		bra	_Start

		dc.b	"$VER: "
_txt_creator	sprintx	"encode %ld.%ld ",Version,Revision
		INCBIN	".date"
		dc.b	0
		dc.b	"$Id: encode.asm 1.2 2005/04/07 23:36:50 wepl Exp wepl $",0
	EVEN

;##########################################################################

	INCDIR	sources
	INCLUDE	dosio.i
		PrintArgs
	INCLUDE	error.i
		PrintErrorDOS
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
	;parse args
		move.l	(gl_rd_input,GL),a0
		bsr	_LoadFileMsg
		move.l	d1,d7				;d7 = input length
		move.l	d0,d6				;d6 = input
		beq	.noinput

	;align length
		addq.l	#3,d7
		and.b	#%11111100,d7

	;alloc destination mem
		move.l	d7,d0
		add.l	d0,d0
		move.l	d0,a2				;a2 = save length
		addq.l	#4,d0				;+4 security
		moveq	#MEMF_ANY,d1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOAllocVec,a6)
		move.l	d0,d5				;d5 = output
		bne	.memok
		moveq	#0,d0
		lea	(_nomem),a0
		lea	(_allocdestmem),a1
		bsr	_PrintError
		bra	.afterfreedest
.memok
	;process
		move.l	d6,a0
		move.l	d5,a1
		clr.l	(a1)+
		move.l	#$55555555,d4
.loop		move.l	(a0)+,d2
		move.l	d2,d3
		lsr.l	#1,d2
		and.l	d4,d2
		move.l	d2,d0
		eor.l	d4,d0
		move.l	d0,d1
		add.l	d0,d0
		lsr.l	#1,d1
		bset	#31,d1
		and.l	d0,d1
		or.l	d1,d2
		btst	#0,-1(a1)
		beq	.ok1
		bclr	#31,d2
.ok1		move.l	d2,(a1)+
		and.l	d4,d3
		move.l	d3,d0
		eor.l	d4,d0
		move.l	d0,d1
		add.l	d0,d0
		lsr.l	#1,d1
		bset	#31,d1
		and.l	d0,d1
		or.l	d1,d3
		btst	#0,-1(a1)
		beq	.ok2
		bclr	#31,d3
.ok2		move.l	d3,(a1)+
		subq.l	#4,d7
		bne	.loop

	;save file
		move.l	a2,d0
		move.l	d5,a0
		add.l	#4,a0
		move.l	(gl_rd_output,GL),a1
		bsr	_SaveFileMsg

	;free destination memory
		move.l	d5,a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOFreeVec,a6)
.afterfreedest

	;free input
		move.l	d6,a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOFreeVec,a6)
.noinput
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


;##########################################################################

	CNOP 0,4
_badkick	dc.b	"requires Kickstart 2.0 or better.",10,0
_readargs	dc.b	"read arguments",0
_nomem		dc.b	"not enough free store",0
_allocdestmem	dc.b	"alloc temp dest mem",0

;subsystems
_dosname	DOSNAME

_template	dc.b	"Input/A"		;file to encode
		dc.b	",Output/A"		;file to save
		dc.b	0

;##########################################################################

	SECTION g,BSS

_Globals	ds.b	gl_SIZEOF

;##########################################################################

	END
