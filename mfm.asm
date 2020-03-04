;*---------------------------------------------------------------------------
;  :Program.	mfm.asm
;  :Contents.	decodes mfm data
;  :Author.	Bert Jahn
;  :Version	$Id: mfm.asm 1.4 2005/04/07 23:37:04 wepl Exp wepl $
;  :History.	27.02.00 initial
;		23.03.05 assembler options adjusted
;		20.02.20 adapted for vamos build
;		26.02.20 support also encoding a long
;  :Requires.	OS V37+
;  :Copyright.	© 2000-2005,2020 Bert Jahn, All Rights Reserved
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
		ULONG	gl_rd_odd
		ULONG	gl_rd_even
		ULONG	gl_rd_decoded
		ULONG	gl_rc			;programs return code
		STRUCT	gl_tmp,16
		LABEL	gl_SIZEOF

;##########################################################################

GL	EQUR	A4		;a4 ptr to Globals
LOC	EQUR	A5		;a5 for local vars
CPU	=	68000

	IFD BARFLY
	OUTPUT	C:mfm
	BOPT	O+		;enable optimizing
	BOPT	OG+		;enable optimizing
	BOPT	ODd-		;disable mul optimizing
	BOPT	ODe-		;disable mul optimizing
	BOPT	wo-		;no optimize warnings
	IFND	.passchk
	DOSCMD	"WDate >.date"
.passchk
	ENDC
	ELSE
sprintx	MACRO
		dc.b	\1
	ENDM
	ENDC

Version		= 0
Revision	= 2

	SECTION a,CODE

		bra	_Start

		dc.b	"$VER: "
_txt_creator	sprintx	"mfm %ld.%ld ",Version,Revision
		INCBIN	".date"
		dc.b	0
	EVEN

;##########################################################################

	INCDIR	sources
	INCLUDE	dosio.i
		PrintArgs
	INCLUDE	strings.i
		atoi
	INCLUDE	error.i
		PrintErrorDOS

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
		move.l	(gl_rd_odd,GL),a0
		bsr	_parse
		move.l	d0,d5			;d5 = odd
		move.l	(gl_rd_even,GL),a0
		bsr	_parse
		move.l	d0,d6			;d6 = even
		move.l	(gl_rd_decoded,GL),a0
		bsr	_parse
		move.l	d0,d7			;d7 = decoded
		bne	.encode

		move.l	#$55555555,d0
		move.l	d5,d1
		and.l	d0,d1
		add.l	d1,d1
		move.l	d6,d2
		and.l	d0,d2
		or.l	d1,d2
		lea	(_out),a0
		move.l	d2,-(a7)
		move.l	d6,-(a7)
		move.l	d5,-(a7)
		move.l	a7,a1
		bsr	_PrintArgs
		add.w	#12,a7
		bra	.end

.encode		move.l	#$55555555,d4
		move.l	d7,-(a7)
		move.l	d7,d3

		and.l	d4,d3
		move.l	d3,d0
		eor.l	d4,d0
		move.l	d0,d1
		add.l	d0,d0
		lsr.l	#1,d1
		bset	#31,d1
		and.l	d0,d1
		or.l	d1,d3
		move.l	d3,-(a7)

		lsr.l	#1,d7
		and.l	d4,d7
		move.l	d7,d0
		eor.l	d4,d0
		move.l	d0,d1
		add.l	d0,d0
		lsr.l	#1,d1
		bset	#31,d1
		and.l	d0,d1
		or.l	d1,d7
		move.l	d7,-(a7)

		lea	(_out),a0
		move.l	a7,a1
		bsr	_PrintArgs
		add.w	#12,a7
.end
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

	;prepend $ if not present
_parse		move.l	a0,d0
		beq	_rts
		lea	(gl_tmp,GL),a1
		moveq	#"$",d0
		cmp.b	(a0),d0
		bne	.1
		addq.l	#1,a0
.1		move.b	d0,(a1)+
		moveq	#8,d0
.2		move.b	(a0)+,(a1)+
		dbeq	d0,.2
		clr.b	(a1)
		lea	(gl_tmp,GL),a0
		bra	_atoi

;##########################################################################

	CNOP 0,4
_out		dc.b	"  odd      even   decoded",10
		dc.b	"%08lx %08lx %08lx",10,0

_badkick	dc.b	"requires Kickstart 2.0 or better.",10,0
_readargs	dc.b	"read arguments",0

;subsystems
_dosname	DOSNAME

_template	dc.b	"O=Odd/K"		;odd bits
		dc.b	",E=Even/K"		;even bits
		dc.b	",D=Decoded/K"		;decoded data
		dc.b	0

;##########################################################################

	SECTION g,BSS

_Globals	ds.b	gl_SIZEOF

;##########################################################################

	END
