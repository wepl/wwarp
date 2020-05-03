;*---------------------------------------------------------------------------
;  :Program.	encode.asm
;  :Contents.	encodes data to mfm
;  :Author.	Bert Jahn
;  :Version	$Id: encode.asm 1.3 2020/03/14 14:10:32 wepl Exp wepl $
;  :History.	06.02.02 initial
;		20.02.20 adapted for vamos build
;		03.05.20 Blit/S option added which creates MFM suitable for
;			 decoding using blitter, first all odd data, then all even
;		03.05.20 encoding optimized using X-flag
;  :Requires.	OS V37+
;  :Language.	68000 Assembler
;  :Translator.	Barfly V2.9, vasm 1.8h
;  :To Do.
;---------------------------------------------------------------------------*
;##########################################################################

	INCDIR	Includes:
	INCLUDE	lvo/exec.i
	INCLUDE	exec/execbase.i
	INCLUDE	lvo/dos.i
	INCLUDE	dos/dos.i

	INCLUDE	macros/sprint.i

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

	STRUCTURE	Globals,0
		APTR	gl_execbase
		APTR	gl_dosbase
		APTR	gl_rdargs
		LABEL	gl_rdarray
		ULONG	gl_rd_input
		ULONG	gl_rd_output
		ULONG	gl_rd_blit
		ULONG	gl_src
		ULONG	gl_dest
		ULONG	gl_savelen
		ULONG	gl_rc			;programs return code
		ALIGNLONG
		LABEL	gl_SIZEOF

;##########################################################################

GL	EQUR	A4		;a4 ptr to Globals
LOC	EQUR	A5		;a5 for local vars
CPU	=	68000

Version		= 1
Revision	= 2

	SECTION a,CODE

		bra	_Start

		dc.b	"$VER: "
_txt_creator	sprint	"encode ",Version,".",Revision," "
		INCBIN	".date"
		dc.b	0
	EVEN

;##########################################################################

	INCDIR	sources
	INCLUDE	dosio.i
		Print
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
		move.l	d0,(gl_src,GL)			;input
		beq	.noinput

	;check length
		moveq	#3,d0
		and.l	d7,d0
		beq	.lenok
		lea	(_badlen),a0
		bsr	_Print
		bra	.afterfreedest
.lenok
	;alloc destination mem
		move.l	d7,d0
		add.l	d0,d0
		move.l	d0,(gl_savelen,GL)		;save length
		moveq	#MEMF_ANY,d1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOAllocVec,a6)
		move.l	d0,(gl_dest,GL)			;output
		bne	.memok
		moveq	#0,d0
		lea	(_nomem),a0
		lea	(_allocdestmem),a1
		bsr	_PrintError
		bra	.afterfreedest
.memok
	;process
		tst.l	(gl_rd_blit,GL)
		bne	.blit

	;create odd, even long by long
		move.l	(gl_src,GL),a0		;a0 = source data
		move.l	(gl_dest,GL),a1		;a1 = dest mfm
		move.l	#$55555555,d4		;d4 = mask even
		move.l	d4,d5
		add.l	d5,d5			;d5 = mask odd = $aaaaaaaa
		moveq	#0,d6			;d6 = previous bit #0
.loop		move.l	(a0)+,d2		;d2 = odd data
		move.l	d2,d3			;d3 = even data
		lsr.l	#1,d2
		and.l	d4,d2			;mask data bits
		move.l	d2,d0
		move.l	d2,d1
		add.l	d0,d0			;left shift data bits
		lsr.w	#1,d6			;set X
		roxr.l	#1,d1			;right shift data bits
		or.l	d0,d1			;clock bits = data before | after
		eor.l	d5,d1			;clock bits = not ( data before | after )
		or.l	d1,d2			;merge clock bits
		move.l	d2,(a1)+		;write odd data
		lsr.w	#1,d2			;set X
		and.l	d4,d3			;mask data bits
		move.l	d3,d0
		move.l	d3,d1
		roxr.l	#1,d1			;right shift data bits
		add.l	d0,d0			;left shift data bits
		or.l	d0,d1			;clock bits = data before | after
		eor.l	d5,d1			;clock bits = not ( data before | after )
		or.l	d1,d3			;merge clock bits
		move.l	d3,(a1)+		;write even data
		move.w	d3,d6
		subq.l	#4,d7
		bne	.loop
		bra	.done

	;create all odd, then all even
	;suitable for blitter decoding and used in trackdisk.device format
.blit		move.l	(gl_src,GL),a0		;a0 = source data
		move.l	(gl_dest,GL),a1		;a1 = dest mfm odd
		lea	(a1,d7.l),a2		;a2 = dest mfm even
		lea	(a0,d7.l),a3		;a3 = source data end
		move.l	#$55555555,d4		;d4 = mask even
		move.l	d4,d5
		add.l	d5,d5			;d5 = mask odd = $aaaaaaaa
		moveq	#0,d6			;d6 = previous bit #0 odd
		move.w	(-2,a3),d7		;last word of data
		lsr.w	#1,d7			;d7 = previous bit #0 even
.loopb		move.l	(a0)+,d2		;d2 = odd data
		move.l	d2,d3			;d3 = even data
		lsr.l	#1,d2
		and.l	d4,d2			;mask data bits
		move.l	d2,d0
		move.l	d2,d1
		add.l	d0,d0			;left shift data bits
		lsr.w	#1,d6			;set X
		roxr.l	#1,d1			;right shift data bits
		or.l	d0,d1			;clock bits = data before | after
		eor.l	d5,d1			;clock bits = not ( data before | after )
		or.l	d1,d2			;merge clock bits
		move.l	d2,(a1)+		;write odd data
		move.w	d2,d6
		and.l	d4,d3			;mask data bits
		move.l	d3,d0
		move.l	d3,d1
		add.l	d0,d0			;left shift data bits
		lsr.w	#1,d7			;set X
		roxr.l	#1,d1			;right shift data bits
		or.l	d0,d1			;clock bits = data before | after
		eor.l	d5,d1			;clock bits = not ( data before | after )
		or.l	d1,d3			;merge clock bits
		move.l	d3,(a2)+		;write odd data
		move.w	d3,d7
		cmp.l	a0,a3
		bne	.loopb
.done
	;save file
		move.l	(gl_savelen,GL),d0
		move.l	(gl_dest,GL),a0
		move.l	(gl_rd_output,GL),a1
		bsr	_SaveFileMsg

	;free destination memory
		move.l	(gl_dest,GL),a1
		move.l	(gl_execbase,GL),a6
		jsr	(_LVOFreeVec,a6)
.afterfreedest

	;free input
		move.l	(gl_src,GL),a1
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
_badlen		dc.b	"file length must be a multiple of 4",10,0

;subsystems
_dosname	DOSNAME

_template	dc.b	"Input/A"		;file to encode
		dc.b	",Output/A"		;file to save
		dc.b	",Blit/S"		;blitter mode, first all odd mfm then even
		dc.b	0

;##########################################################################

	SECTION g,BSS

_Globals	ds.b	gl_SIZEOF

;##########################################################################

	END
