 IFND	STRINGS_I
STRINGS_I = 1
;*---------------------------------------------------------------------------
;  :Author.	Bert Jahn
;  :Contens.	macros for processing strings
;  :EMail.	wepl@kagi.com
;  :Address.	Franz-Liszt-Straße 16, Rudolstadt, 07404, Germany
;  :Version.	$Id: strings.i 1.3 1999/06/24 23:13:31 jah Exp wepl $
;  :History.	29.12.95 separated from WRip.asm
;		18.01.96 IFD Label replaced by IFD Symbol
;			 because Barfly optimize problems
;		02.03.96 _RemoveExtension,_AppendString added
;		25.08.96 _atoi,_etoi added
;		21.07.97 _StrLen added
;		22.07.97 Macro UPPER separated from whdl_cache.s
;		22.07.97 _StrNCaseCmp added
;		16.11.97 buffer length check fixed in _FormatString,
;			 now works, but it is no longer reentrant !
;		21.12.97 _DoStringNull added
;		27.06.98 cleanup for use with "HrtMon"
;		17.10.98 parameters for _AppendString corrected
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
;  :Translator.	Barfly 2.9
;---------------------------------------------------------------------------*
*##
*##	strings.i
*##
*##	_FormatString	fmt(a0),argarray(a1),buffer(a2),bufsize(d0)
*##	_DoStringNull	list(a0),number(d0.w) --> stringptr(d0)
*##	_DoString	list(a0),number(d0.w) --> stringptr(d0)
*##	_CopyString	source(a0),dest(a1),destbufsize(d0) --> success(d0)
*##	_RemoveExtension source(a0) --> success(d0)
*##	_AppendString	source(a0),dest(a1),destbufsize(d0) --> success(d0)
*##	_atoi		source(a0) --> integer(d0),stringleft(a0)
*##	_etoi		source(a0) --> integer(d0),stringleft(a0)
*##	UPPER		char(dx) --> char(dx)
*##	_StrLen		source(a0) --> length(d0)
*##	_StrNCaseCmp	string(a0),string(a1),len(d0) --> relation(d0)

	dc.b	"$Id: strings.i 1.3 1999/06/24 23:13:31 jah Exp wepl $"
	EVEN

;----------------------------------------
; Formatiert String (printf)
; Übergabe :	D0 = ULONG Länge des Buffers
;		A0 = APTR FormatString
;		A1 = APTR Argumente
;		A2 = Buffer
; Rückgabe :	-

FormatString	MACRO
	IFND	FORMATSTRING
FORMATSTRING=1
		IFND	_LVORawDoFmt
			INCLUDE lvo/exec.i
		ENDC
_FormatString	movem.l	a2-a3/a6,-(a7)
		lea	(.bufend),a3
		add.l	a2,d0
		move.l	d0,(a3)
		move.l	a2,a3
		lea	(.PutChar),a2
		move.l	(gl_execbase,GL),a6
		jsr	(_LVORawDoFmt,a6)
		movem.l	(a7)+,a2-a3/a6
		rts

.PutChar	move.b	d0,(a3)+
		cmp.l	(.bufend),a3
		bne	.PC_ok
		subq.l	#1,a3
.PC_ok		rts	

.bufend		dc.l	0
	ENDC
		ENDM

;----------------------------------------
; Berechnet String-Adresse über Zuordungstabelle
; Übergabe :	D0 = WORD   value
;		A0 = STRUCT Zuordnungstabelle
; Rückgabe :	D0 = CPTR   string or NULL

DoStringNull	MACRO
	IFND	DOSTRINGNULL
DOSTRINGNULL=1
_DoStringNull
.start		cmp.w	(a0),d0			;lower bound
		blt	.nextlist
		cmp.w	(2,a0),d0		;upper bound
		bgt	.nextlist
		move.w	d0,d1
		sub.w	(a0),d1			;index
		add.w	d1,d1			;because words
		move.w	(8,a0,d1.w),d1		;rptr
		beq	.nextlist
		add.w	d1,a0
		move.l	a0,d0
		rts

.nextlist	move.l	(4,a0),a0		;next list
		move.l	a0,d1
		bne	.start
		
		moveq	#0,d0
		rts

		ENDC
		ENDM

;----------------------------------------
; Berechnet String-Adresse über Zuordungstabelle (data not reetrant !)
; Übergabe :	D0 = WORD   value
;		A0 = STRUCT Zuordnungstabelle
; Rückgabe :	D0 = CPTR   string

DoString	MACRO
	IFND	DOSTRING
DOSTRING=1
		IFND	DOSTRINGNULL
			DoStringNull
		ENDC
		IFND	FORMATSTRING
			FormatString
		ENDC

_DoString	ext.l	d0
		movem.l	d0/a2,-(a7)
		bsr	_DoStringNull
		tst.l	d0
		beq	.maketxt
		addq.l	#8,a7
		rts

.maketxt		move.l	a7,a1			;args
		moveq	#8,d0			;buflen
		lea	(.fmt),a0		;format string
		lea	(.buf),a2		;buffer
		bsr	_FormatString
		move.l	a2,d0
		addq.l	#4,a7
		move.l	(a7)+,a2
		rts

.fmt		dc.b	"%ld",0
.buf		ds.w	4,0

		ENDC
		ENDM

;----------------------------------------
; Kopiert String
; Übergabe :	D0 = LONG dest buffer size
;		A0 = CPTR  source string
;		A1 = APTR  dest buffer
; Rückgabe :	D0 = LONG  success (fail if buffer to small)

CopyString	MACRO
	IFND	COPYSTRING
COPYSTRING=1
_CopyString	tst.l	d0
		ble	.err
.lp		move.b	(a0)+,(a1)+
		beq	.ok
		subq.l	#1,d0
		bne	.lp
		clr.b	-(a1)
.err		moveq	#0,d0
		rts

.ok		moveq	#-1,d0
		rts
	ENDC
		ENDM

;----------------------------------------
; Entfernt Endung
; Übergabe :	A0 = CPTR  source string
; Rückgabe :	D0 = LONG  success (true if a extension is removed)

RemoveExtension	MACRO
	IFND	REMOVEEXTENSION
REMOVEEXTENSION=1
_RemoveExtension
		move.l	a0,d0
		beq	.err
.l1		tst.b	(a0)+
		bne	.l1
.l2		cmp.l	a0,d0
		beq	.err
		cmp.b	#".",-(a0)
		bne	.l2
		clr.b	(a0)
		moveq	#-1,d0
		rts
		
.err		moveq	#0,d0
		rts
	ENDC
		ENDM

;----------------------------------------
; Hängt String hinten an
; IN:	D0 = LONG  destination buffer size
;	A0 = CPTR  source string (to append)
;	A1 = CPTR  destination string (to append on)
; OUT:	D0 = LONG  success (fail if buffer to small)

AppendString	MACRO
	IFND	APPENDSTRING
APPENDSTRING=1
_AppendString	tst.l	d0
		ble	.err
.l1		subq.l	#1,d0
		tst.b	(a1)+
		bne	.l1
		subq.l	#1,a1
		addq.l	#1,d0
		ble	.err
		
.lp		move.b	(a0)+,(a1)+
		beq	.ok
		subq.l	#1,d0
		bne	.lp
		clr.b	-(a1)

.err		moveq	#0,d0
		rts

.ok		moveq	#-1,d0
		rts
	ENDC
		ENDM

;----------------------------------------
; Umwandlung ASCII to Integer
; asciiint ::= [+|-] { {<digit>} | ${<hexdigit>} }¹
; hexdigit ::= {012456789abcdefABCDEF}¹
; digit    ::= {0123456789}¹
; Übergabe :	A0 = CPTR ascii | NIL
; Rückgabe :	D0 = LONG integer (on error=0)
;		A0 = CPTR first char after translated ASCII

atoi		MACRO
	IFND	ATOI
ATOI=1
_atoi		movem.l	d6-d7,-(a7)
		moveq	#0,d0		;default
		move.l	a0,d1		;a0 = NIL ?
		beq	.eend
		moveq	#0,d1
		move.b	(a0)+,d1
		cmp.b	#"-",d1
		seq	d7		;D7 = negative
		beq	.1p
		cmp.b	#"+",d1
		bne	.base
.1p		move.b	(a0)+,d1
.base		cmp.b	#"$",d1
		beq	.hexs

.dec		cmp.b	#"0",d1
		blo	.end
		cmp.b	#"9",d1
		bhi	.end
		sub.b	#"0",d1
		move.l	d0,d6		;D0 * 10
		lsl.l	#3,d0		;
		add.l	d6,d0		;
		add.l	d6,d0		;
		add.l	d1,d0
		move.b	(a0)+,d1
		bra	.dec

.hexs		move.b	(a0)+,d1
.hex		cmp.b	#"0",d1
		blo	.hexl
		cmp.b	#"9",d1
		bhi	.hexl
		sub.b	#"0",d1
		bra	.hexgo
.hexl		cmp.b	#"a",d1
		blo	.hexh
		cmp.b	#"f",d1
		bhi	.hexh
		sub.b	#"a"-10,d1
		bra	.hexgo
.hexh		cmp.b	#"A",d1
		blo	.end
		cmp.b	#"F",d1
		bhi	.end
		sub.b	#"A"-10,d1
.hexgo		lsl.l	#4,d0		;D0 * 16
		add.l	d1,d0
		move.b	(a0)+,d1
		bra	.hex

.end		subq.l	#1,a0
		tst.b	d7
		beq	.eend
		neg.l	d0
.eend		movem.l	(a7)+,d6-d7
		rts
	ENDC
		ENDM

;----------------------------------------
; Umwandlung Expression to Integer
; asiiexp ::= {<space>} <asciiint> { {<space>} {+|-}¹ {<space>} <asciiint> }
; space   ::= {SPACE|TAB}
; Übergabe :	A0 = CPTR ascii | NIL
; Rückgabe :	D0 = LONG integer (on error=0)
;		A0 = CPTR first char after translated ASCII

etoi		MACRO
	IFND	ETOI
	IFND	ATOI
		atoi
	ENDC
ETOI=1
_etoi		movem.l	d2-d3,-(a7)
		moveq	#0,d2		;D2 = result
		move.l	a0,d1		;a0 = NIL ?
		beq	.eend
		moveq	#0,d3		;D3 = operation

.sp		move.b	(a0)+,d1
		cmp.b	#" ",d1		;space
		beq	.sp
		cmp.b	#"	",d1	;tab
		beq	.sp
		subq.l	#1,a0
		bsr	_atoi
		cmp.b	#"-",d3
		beq	.minus
.plus		add.l	d0,d2
		bra	.newop
.minus		sub.l	d0,d2
.newop		move.b	(a0)+,d1
		cmp.b	#" ",d1		;space
		beq	.newop
		cmp.b	#"	",d1	;tab
		beq	.newop
		cmp.b	#"+",d1
		beq	.opok
		cmp.b	#"-",d1
		bne	.end
.opok		move.b	d1,d3		;D3 = operation
		bra	.sp

.end		subq.l	#1,a0
.eend		move.l	d2,d0
		movem.l	(a7)+,d2-d3
		rts
	ENDC
		ENDM

;----------------------------------------
; calculate length of a string
; (confirming BSD 4.3)
; IN :	A0 = CPTR  source string
; OUT :	D0 = ULONG length

StrLen	MACRO
	IFND	STRLEN
STRLEN=1
_StrLen		moveq	#0,d0		;length
		move.l	a0,d1
		beq	.end
.loop		tst.b	(a0)+
		beq	.end
		addq.l	#1,d0
		bra	.loop
.end		rts
	ENDC
		ENDM

;----------------------------------------
; makes character in Dx upper case
; only 7-bit ASCII !

UPPER	MACRO
		cmp.b	#"a",\1
		blo	.l\@
		cmp.b	#"z",\1
		bhi	.l\@
		sub.b	#$20,\1
.l\@
	ENDM

;----------------------------------------
; compare two strings with given length case insensitiv (only 7-bit ASCII !!!)
; (confirming BSD 4.3)
; IN :	D0 = ULONG amount of chars to compare
;	A0 = CPTR  string 1
;	A1 = CPTR  string 2
; OUT :	D0 = ULONG <0 if a0 less than a1
;		    0 if a0 equal a1
;		   >0 if a0 greater than a1

StrNCaseCmp	MACRO
	IFND	STRNCASECMP
STRNCASECMP=1
_StrNCaseCmp	move.l	d2,-(a7)

		tst.l	d0		;len = 0 ?
		beq	.equal
		cmp.l	a0,a1		;string equal ?
		beq	.equal
		move.l	a0,d1
		beq	.less
		move.l	a1,d1
		beq	.greater
		
.next		move.b	(a0)+,d1
		UPPER	d1
		move.b	(a1)+,d2
		UPPER	d2
		cmp.b	d1,d2
		bhi	.less
		blo	.greater
		subq.l	#1,d0
		bne	.next

.equal		moveq	#0,d0
		bra	.end
.less		moveq	#-1,d0
		bra	.end
.greater	moveq	#1,d0
.end		move.l	(a7)+,d2
		rts
	ENDC
		ENDM

;---------------------------------------------------------------------------

	ENDC
 
