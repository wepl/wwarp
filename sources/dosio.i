 IFND DOSIO_I
DOSIO_I=1
;*---------------------------------------------------------------------------
;  :Author.	Bert Jahn
;  :Contens.	macros for input/output via dos.library
;  :EMail.	wepl@whdload.de
;  :Version.	$Id: dosio.i 1.7 2008/05/06 22:01:00 wepl Exp wepl $
;  :History.	30.12.95 separated from WRip.asm
;		18.01.96 IFD Label replaced by IFD Symbol
;			 because Barfly optimize problems
;		20.01.96 _CheckBreak separated from Wrip
;		21.07.97 _FGetS added
;		09.11.97 _GetS added
;			 _FlushInput added
;		27.12.99 _PrintLn shortend
;			 _CheckBreak enhanced (nested checks)
;		13.01.00 _GetKey added
;		28.06.00 gloabal variable from _GetKey removed
;		26.04.08 _PrintMore added
;  :Requires.	-
;  :Copyright.	This program is free software; you can redistribute it and/or
;		modify it under the terms of the GNU General Public License
;		as published by the Free Software Foundation; either version 2
;		of the License, or (at your option) any later version.
;		This program is distributed in the hope that it will be useful,
;		but WITHOUT ANY WARRANTY; without even the implied warranty of
;		MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;		GNU General Public License for more details.
;		You can find the full GNU GPL online at: http://www.gnu.org
;  :Language.	68000 Assembler
;  :Translator.	BASM 2.16
;---------------------------------------------------------------------------*
*##
*##	dosio.i
*##
*##	_CheckBreak	--> true(d0) if ^C was pressed
*##	_FGetS		fh(d1) buffer(d2) buflen(d3) --> buffer(d0)
*##	_FlushInput	flushes the input stream
*##	_FlushOutput	flushes the output stream
*##	_GetKey		--> key(d0)
*##	_GetS		buffer(a0) buflen(d0) --> buffer(d0)
*##	_Print		outputs a string(a0)
*##	_PrintArgs	outputs formatstring(a0) expanded from argarray(a1)
*##	_PrintInt	outputs a longint (d0)
*##	_PrintLn	outputs a linefeed
*##	_PrintMore	outputs a string(a0) with more/less pipe

	dc.b	"$Id: dosio.i 1.7 2008/05/06 22:01:00 wepl Exp wepl $",10,0
	EVEN

		IFND	STRINGS_I
			INCLUDE	strings.i
		ENDC

;----------------------------------------
; Zeilenschaltung
; IN :	-
; OUT :	-

PrintLn		MACRO
	IFND	PRINTLN
PRINTLN = 1
		IFND	PRINT
			Print
		ENDC
_PrintLn	lea	(.nl),a0
		bra	_Print
.nl		dc.b	10,0
	ENDC
		ENDM

;----------------------------------------
; Gibt FormatString gebuffert aus
; IN :	A0 = CPTR FormatString
;	A1 = STRUCT Array mit Argumenten
; OUT :	-

PrintArgs	MACRO
	IFND	PRINTARGS
PRINTARGS = 1
_PrintArgs	movem.l	d2/a6,-(a7)
		move.l	a0,d1
		move.l	a1,d2
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOVPrintf,a6)
		movem.l	(a7)+,d2/a6
		rts
	ENDC
		ENDM

;----------------------------------------
; Gibt LongInt gebuffert aus
; IN :	D0 = LONG
; OUT :	-

PrintInt	MACRO
	IFND	PRINTINT
PRINTINT = 1
_PrintInt	clr.l	-(a7)
		move.l	#"%ld"<<8+10,-(a7)
		move.l	a7,a0
		move.l	d0,-(a7)
		move.l	a7,a1
		bsr	_PrintArgs
		add.w	#12,a7
		rts
	ENDC
		ENDM

;----------------------------------------
; Gibt String gebuffert aus
; IN :	A0 = CPTR String
; OUT :	-

Print		MACRO
	IFND	PRINT
PRINT = 1
		IFND	PRINTARGS
			PrintArgs
		ENDC

_Print		sub.l	a1,a1
		bra	_PrintArgs
	ENDC
		ENDM

;----------------------------------------
; print text, when console window is filled wait for a key
; and then continue
; IN:	A0 = CPTR text to display
; OUT:	-

PrintMore	MACRO
	IFND	PRINTMORE
PRINTMORE = 1
HLPBUFLEN = 32

_PrintMore	movem.l	d2-d7/a2-a3/a6,-(a7)
		sub.l	#HLPBUFLEN,a7
		move.l	a0,a3				;A3 = text

		move.l	(gl_dosbase,GL),a6		;A6 = dosbase
		jsr	(_LVOInput,a6)
		move.l	d0,d7				;D7 = input
		jsr	(_LVOOutput,a6)
		move.l	d0,d6				;D6 = output

		move.l	d7,a1
		jsr	(_LVOIsInteractive,a6)
		tst.l	d0
		bne	.interactive
		move.l	a3,d1
		jsr	(_LVOPutStr,a6)
		bra	.quit
.interactive
		lea	.init,a0
		bsr	.write

		move.l	d7,d1
		moveq	#1,d2				;mode = raw
		jsr	(_LVOSetMode,a6)

		bsr	.getwin

.nextscreen	move.l	d4,d1
		subq.l	#1,d1				;lines to write

.nextlines	move.l	a3,d2
		moveq	#0,d3
.loop		move.b	(a3)+,d0
		beq	.print
		addq.l	#1,d3
		cmp.b	#10,d0
		bne	.loop
		subq.l	#1,d1
		bne	.loop
.print		move.l	d6,d1
		jsr	(_LVOWrite,a6)

		tst.b	(-1,a3)
		beq	.end

		lea	.status,a0
		bsr	.write

.wait		move.l	d7,d1
		move.l	#1000000,d2			;microseconds
		jsr	(_LVOWaitForChar,a6)
		tst.l	d0
		beq	.wait

		move.l	d7,d1
		move.l	a7,d2
		moveq	#HLPBUFLEN-1,d3
		jsr	(_LVORead,a6)

		lea	.space,a2
		cmp.b	#" ",(a7)
		beq	.key
		lea	.return,a2
		cmp.b	#13,(a7)
		beq	.key
		cmp.w	#155<<8+"B",(a7)		;cursor down
		beq	.key
		lea	.end,a2
		cmp.b	#"q",(a7)
		bne	.wait

.key		lea	.statusclear,a0
		bsr	.write
		jmp	(a2)

.space		lea	.clearscreen,a0
		bsr	.write
		bra	.nextscreen

.return		moveq	#1,d1
		bra	.nextlines
.end
		move.l	d7,d1
		moveq	#0,d2				;mode = con
		jsr	(_LVOSetMode,a6)

		lea	.finit,a0
		bsr	.write

	IFD DEBUG
		lea	.debug,a0
		move.l	a0,d1
		pea	(1,a7)
		move.l	d4,-(a7)
		move.l	d5,-(a7)
		move.l	a7,d2
		jsr	(_LVOVPrintf,a6)
		add.w	#12,a7
	ENDC

.quit		add.l	#HLPBUFLEN,a7
		movem.l	(a7)+,_MOVEMREGS
		rts

.getwin		move.l	d7,d1
		jsr	(_LVOFlush,a6)

		lea	.wsr,a0
		bsr	.write

		move.l	d7,d1
		move.l	a7,d2
		addq.l	#4,d2
		moveq	#HLPBUFLEN-1,d3
		jsr	(_LVORead,a6)

		cmp.l	#10,d0
		bls	.getwin_err
		lea	(4,a7),a0
		cmp.b	#155,(a0)
		beq	.getwin_1
		cmp.b	#27,(a0)+
		bne	.getwin_err
		cmp.b	#91,(a0)
		bne	.getwin_err
.getwin_1	addq.l	#1,a0				;skip CSI
		cmp.b	#"1",(a0)+
		bne	.getwin_err
		cmp.b	#";",(a0)+
		bne	.getwin_err
		cmp.b	#"1",(a0)+
		bne	.getwin_err
		cmp.b	#";",(a0)+
		bne	.getwin_err
		bsr	.getnum
		move.l	d0,d4				;D4 = heigth
		cmp.b	#";",(a0)+
		bne	.getwin_err
		bsr	.getnum
		move.l	d0,d5				;D5 = width
		cmp.b	#" ",(a0)+
		bne	.getwin_err
		cmp.b	#"r",(a0)+
		bne	.getwin_err
		rts

.getwin_err	move.l	#80,d5				;D5 = width
		move.l	#25,d4				;D4 = height
.rts		rts

.getnum		moveq	#0,d0
		moveq	#0,d1
.getnum_loop	move.b	(a0),d1
		sub.b	#"0",d1
		bcs	.rts
		cmp.b	#10,d1
		bhs	.rts
		mulu	#10,d0
		add.l	d1,d0
		addq.l	#1,a0
		bra	.getnum_loop

; a0 = CPTR

.write		move.l	d6,d1
		move.l	a0,d2
		moveq	#-1,d3
.write1		addq.l	#1,d3
		tst.b	(a0)+
		bne	.write1
		jmp	(_LVOWrite,a6)

.wsr		dc.b	155," q",0
.init		dc.b	155,"0 p"	;cursor off
.clearscreen	dc.b	155,"1;1H"	;set cursor position
		dc.b	155,"J",0	;erase display
.finit		dc.b	155," p",0	;cursor on
	IFD DEBUG
.debug		dc.b	"width=%ld height=%ld buffer+1=%s",10,0
	ENDC
.status		dc.b	155,"3m"	;italics
		dc.b	155,"7m"	;reverse
		dc.b	" (space) next screen  (return/cursor down) next line  (q) quit "
		dc.b	155,"0m",0	;normal
.statusclear	dc.b	13,155,"K",0	;cr + erase line
	EVEN
	ENDC
		ENDM

;----------------------------------------
; L�schen der Ausgabepuffer
; IN :	-
; OUT :	-

FlushOutput	MACRO
	IFND	FLUSHOUTPUT
FLUSHOUTPUT = 1
_FlushOutput	move.l	a6,-(a7)
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOOutput,a6)
		move.l	d0,d1
		beq	.err
		jsr	(_LVOFlush,a6)
.err		move.l	(a7)+,a6
		rts
	ENDC
		ENDM

;----------------------------------------
; IN :	-
; OUT :	-

FlushInput	MACRO
	IFND	FLUSHINPUT
FLUSHINPUT = 1
_FlushInput	move.l	a6,-(a7)
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOInput,a6)
		move.l	d0,d1
		beq	.err
		jsr	(_LVOFlush,a6)
.err		move.l	(a7)+,a6
		rts
	ENDC
		ENDM

;----------------------------------------
; print string "break"
; IN :	-
; OUT :	-

PrintBreak	MACRO
	IFND	PRINTBREAK
PRINTBREAK = 1
	IFND	PRINT
		Print
	ENDC
_PrintBreak	lea	(.break),a0
		bra	_Print
.break		dc.b	"*** User Break ***",10,0
		EVEN
	ENDC
		ENDM

;----------------------------------------
; Check break (CTRL-C)
; IN :	-
; OUT :	d0 = BOOL break

CheckBreak	MACRO
	IFND	CHECKBREAK
CHECKBREAK=1
	IFND	PRINTBREAK
		PrintBreak
	ENDC
_CheckBreak	move.l	a6,-(a7)
	IFD gl_break
		tst.b	(gl_break,GL)
		bne	.b
	ENDC
		move.l	#SIGBREAKF_CTRL_C,d1
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOCheckSignal,a6)
		tst.l	d0
		beq	.end
		bsr	_PrintBreak
	IFD gl_break
		st	(gl_break,GL)
	ENDC
.b		moveq	#-1,d0
.end		move.l	(a7)+,a6
		rts
	ENDM

;----------------------------------------
; get line from file
; remove all LF,CR,SPACE,TAB from the end of line
; IN :	D1 = BPTR  fh
;	D2 = APTR  buffer
;	D3 = ULONG buffer size
; OUT :	D0 = ULONG buffer or 0 on error/EOF

FGetS	MACRO
	IFND	FGETS
FGETS=1
		IFND	STRLEN
			StrLen
		ENDC
_FGetS		movem.l	d3/a6,-(a7)
		subq.l	#1,d3			;due a bug in V36/V37
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOFGets,a6)
		move.l	d0,-(a7)
		beq	.end
	;remove LF,CR,SPACE,TAB from the end
		move.l	(a7),a0
		bsr	_StrLen
.len		tst.l	d0
		beq	.end
		move.l	(a7),a0
		cmp.b	#10,(-1,a0,d0)		;LF
		beq	.cut
		cmp.b	#13,(-1,a0,d0)		;CR
		beq	.cut
		cmp.b	#" ",(-1,a0,d0)		;SPACE
		beq	.cut
		cmp.b	#"	",(-1,a0,d0)	;TAB
		bne	.end
.cut		clr.b	(-1,a0,d0)
		subq.l	#1,d0
		bra	.len
.end		movem.l	(a7)+,d0/d3/a6
		rts
	ENDC
		ENDM

;----------------------------------------
; get line from stdin
; remove all LF,CR,SPACE,TAB from the end of line
; IN :	D0 = ULONG buffer size
;	A0 = APTR  buffer
; OUT :	D0 = ULONG buffer or 0 on error/EOF

GetS	MACRO
	IFND	GETS
GETS=1
		IFND	FGETS
			FGetS
		ENDC
_GetS		movem.l	d2-d3/a6,-(a7)
		move.l	d0,d3			;buffer size
		move.l	a0,d2			;buffer
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOInput,a6)
		move.l	d0,d1			;fh
		bsr	_FGetS
		movem.l	(a7)+,_MOVEMREGS
		rts
	ENDC
		ENDM

;----------------------------------------
; wait for a key pressed
; IN:	-
; OUT:	D0 = ULONG input char (155 = CSI!)

GetKey	MACRO
	IFND	GETKEY
GETKEY=1
	IFND	PRINTBREAK
		PrintBreak
	ENDC
_GetKey		movem.l	d2-d5/a6,-(a7)

		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOInput,a6)
		move.l	d0,d5				;d5 = stdin

		move.l	d5,d1
		moveq	#1,d2				;mode = raw
		jsr	(_LVOSetMode,a6)

		move.l	d5,d1
		clr.l	-(a7)
		move.l	a7,d2
		moveq	#1,d3
		jsr	(_LVORead,a6)
		move.l	(a7)+,d4
		rol.l	#8,d4
		
		bra	.check

.flush		move.l	d5,d1
		subq.l	#4,a7
		move.l	a7,d2
		moveq	#1,d3
		jsr	(_LVORead,a6)
		addq.l	#4,a7

.check		move.l	d5,d1
		move.l	#0,d2				;0 seconds
		jsr	(_LVOWaitForChar,a6)
		tst.l	d0
		bne	.flush
		
		move.l	d5,d1
		moveq	#0,d2				;mode = con
		jsr	(_LVOSetMode,a6)
		
		cmp.b	#3,d4				;Ctrl-C pressed?
		bne	.end
		bsr	_PrintBreak

.end		move.l	d4,d0
		movem.l	(a7)+,_MOVEMREGS
		rts
	ENDC
		ENDM

;----------------------------------------
	
 ENDC

