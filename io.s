;*---------------------------------------------------------------------------
;  :Program.	WWarp.asm
;  :Contents.	io via dos or asyncio.libaray
;  :Author.	Bert Jahn
;  :EMail.	wepl@whdload.de
;  :Version	$Id: io.s 1.6 2008/05/06 21:54:18 wepl Exp wepl $
;  :History.	18.06.04 separated from wwarm.asm to be used in mfmwarp
;		28.10.04 error handling fixed (doslib mode)
;		07.11.04 ASyncIO: Read() and Write() results changed
;		27.04.08 better error messages
;  :Requires.	OS V37+, MC68020+
;  :Copyright.	©1998-2008 Bert Jahn, All Rights Reserved
;  :Language.	68020 Assembler
;  :Translator.	Barfly V2.9
;  :To Do.
;---------------------------------------------------------------------------*

	INCLUDE	libraries/asyncio.i
	INCLUDE	libraries/asyncio_lib.i

IOBUFLEN	= 2*2*$6d00	;buffer size for asyncio.library

;----------------------------------------
; open file for reading
; IN:	A0 = CPTR filename
; OUT:	D0 = LONG handle or NIL
;	CC = D0

_OpenRead	movem.l	d2/a0/a6,-(a7)

		move.l	(gl_asynciobase,GL),d0
		bne	.async

	;use dos.library
.dos		move.l	a0,d1
		move.l	#MODE_OLDFILE,d2
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOOpen,a6)
		tst.l	d0
		beq	.error
		bra	.end

	;use asyncio.library
.async		move.l	d0,a6
		move.l	#MODE_READ,d0
		move.l	#IOBUFLEN,d1
		jsr	(_LVOOpenAsync,a6)
		tst.l	d0
		beq	.error

.end		movem.l	(a7)+,_MOVEMREGS
		rts

.error		lea	(_openfileread),a0
		move.l	(4,a7),a1
		bsr	_PrintErrorDOSName
		moveq	#0,d0
		bra	.end

;----------------------------------------
; open file for writing
; IN:	A0 = CPTR filename
; OUT:	D0 = LONG handle or NIL
;	CC = D0

_OpenWrite	movem.l	d2/a0/a6,-(a7)

		move.l	(gl_asynciobase,GL),d0
		bne	.async

	;use dos.library
.dos		move.l	a0,d1
		move.l	#MODE_NEWFILE,d2
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOOpen,a6)
		tst.l	d0
		beq	.error
		bra	.end

	;use asyncio.library
.async		move.l	d0,a6
		move.l	#MODE_WRITE,d0
		move.l	#IOBUFLEN,d1
		jsr	(_LVOOpenAsync,a6)
		tst.l	d0
		beq	.error

.end		movem.l	(a7)+,_MOVEMREGS
		rts

.error		lea	(_openfilewrite),a0
		move.l	(4,a7),a1
		bsr	_PrintErrorDOSName
		moveq	#0,d0
		bra	.end

;----------------------------------------
; close file
; IN:	D1 = LONG handle or NIL
; OUT:	-

_Close		movem.l	a6,-(a7)
		tst.l	d1
		beq	.end

		move.l	(gl_asynciobase,GL),d0
		bne	.async

	;use dos.library
.dos		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOClose,a6)
		bra	.end

	;use asyncio.library
.async		move.l	d0,a6
		move.l	d1,a0
		jsr	(_LVOCloseAsync,a6)

.end		movem.l	(a7)+,_MOVEMREGS
		rts

;----------------------------------------
; seek in a file relative to the start position
; IN:	D0 = LONG position
;	D1 = LONG handle
; OUT:	D0 = BOOL success
;	CC = D0

_SeekBeginning	movem.l	d2-d3/a6,-(a7)

		move.l	(gl_asynciobase,GL),d3
		bne	.async

	;use dos.library
.dos		move.l	d0,d2
		move.l	#OFFSET_BEGINNING,d3
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOSeek,a6)
		jsr	(_LVOIoErr,a6)
		tst.l	d0
		beq	.ok
		bra	.error

	;use asyncio.library
.async		move.l	d3,a6
		move.l	d1,a0
		move.l	#MODE_START,d1
		jsr	(_LVOSeekAsync,a6)
		tst.l	d0
		bmi	.error

.ok		moveq	#-1,d0
.end		movem.l	(a7)+,_MOVEMREGS
		rts

.error		lea	(_seeking),a0
		bsr	_PrintErrorDOS
		moveq	#0,d0
		bra	.end

;----------------------------------------
; seek in a file relative to the actual position
; IN:	D0 = LONG position
;	D1 = LONG handle
; OUT:	D0 = BOOL success
;	CC = D0

_SeekCurrent	movem.l	d2-d3/a6,-(a7)

		move.l	(gl_asynciobase,GL),d3
		bne	.async

	;use dos.library
.dos		move.l	d0,d2
		move.l	#OFFSET_CURRENT,d3
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOSeek,a6)
		jsr	(_LVOIoErr,a6)
		tst.l	d0
		beq	.ok
		bra	.error

	;use asyncio.library
.async		move.l	d3,a6
		move.l	d1,a0
		move.l	#MODE_CURRENT,d1
		jsr	(_LVOSeekAsync,a6)
		tst.l	d0
		bmi	.error

.ok		moveq	#-1,d0
.end		movem.l	(a7)+,_MOVEMREGS
		rts

.error		lea	(_seeking),a0
		bsr	_PrintErrorDOS
		moveq	#0,d0
		bra	.end

;----------------------------------------
; read from a file
; IN:	D0 = LONG length
;	D1 = LONG handle
;	A0 = APTR buffer
; OUT:	D0 = BOOL success
;	CC = D0

_Read		movem.l	d2-d3/a6,-(a7)

		move.l	d0,d3
		move.l	(gl_asynciobase,GL),d2
		bne	.async

	;use dos.library
.dos		move.l	a0,d2
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVORead,a6)
		bra	.result

	;use asyncio.library
.async		move.l	d2,a6
		move.l	a0,a1
		move.l	d1,a0
		jsr	(_LVOReadAsync,a6)

.result		cmp.l	d0,d3
		bne	.error

.ok		moveq	#-1,d0
.end		movem.l	(a7)+,_MOVEMREGS
		rts

.error		lea	(_txt_reading),a0
		bsr	_PrintErrorDOS
		moveq	#0,d0
		bra	.end

;----------------------------------------
; write to a file
; IN:	D0 = LONG length
;	D1 = LONG handle
;	A0 = APTR buffer
; OUT:	D0 = BOOL success
;	CC = D0

_Write		movem.l	d2-d3/a6,-(a7)

		move.l	d0,d3
		move.l	(gl_asynciobase,GL),d2
		bne	.async

	;use dos.library
.dos		move.l	a0,d2
		move.l	(gl_dosbase,GL),a6
		jsr	(_LVOWrite,a6)
		bra	.result

	;use asyncio.library
.async		move.l	d2,a6
		move.l	a0,a1
		move.l	d1,a0
		jsr	(_LVOWriteAsync,a6)

.result		cmp.l	d0,d3
		bne	.error

.ok		moveq	#-1,d0
.end		movem.l	(a7)+,_MOVEMREGS
		rts

.error		lea	(_txt_writing),a0
		bsr	_PrintErrorDOS
		moveq	#0,d0
		bra	.end


;##########################################################################

_asyncioname	dc.b	"asyncio.library",0
_openfileread	dc.b	"open file to read",0
_openfilewrite	dc.b	"open file to write",0
_seeking	dc.b	"seeking",0
_txt_writing	dc.b	"writing file",0
_txt_reading	dc.b	"reading file",0
	EVEN
