;
; debug facility which can be used with WinUAE
; requires:
;	- WinUAE 4.4.0 Beta 1, 2020.05.02
;	- ROM - Advanced UAE expansion board/Boot ROM Settings = New UAE (128k, ROM, Direct)
;	- Miscellaneous - Create winuaelog.txt log
;	- Miscellaneous - Debug memory space
; supported formats:
;	%c, %d, %i, %u, %o, %x, %X, %p, %s, %b (BSTR), %[CYCLES]d
; values written can be byte/word/long, also b/w must be written to UAEDBGADR (macro only uses long)
; format string must be written UAEDBGADR+4 and performs to log
; alternative parameter array can be written to UAEDBGADR+8 prior to format string
; line header of winuaelog.txt explained:
;	02-988 [9206 003-000]:
;	RealWorldSeconds-Milliseconds [EmulatedFrameCounter HorizontalCounter-VerticalCounter]:
;

; DEBUG enables also UAEDEBUG
	IFD DEBUG
	IFNE DEBUG
UAEDEBUG EQU 1
	ENDC
	ENDC
; default is off
	IFND UAEDEBUG
UAEDEBUG EQU 0
	ENDC

UAEDBGADR EQU $bfff00

; write a message to winuaelog.txt
; first argument is the format string, upto 5 parameters following
; a3 cannot be used as argument!

UAEDBG	MACRO
	IFNE UAEDEBUG
		move.l	a3,-(a7)
		lea	(UAEDBGADR),a3
		pea	(.go\@,pc)
	IFEQ NARG-1
		move.l	(a7)+,(a3)+
	ENDC
	IFEQ NARG-2
		move.l	(a7)+,(a3)
		move.l	\2,(a3)+
	ENDC
	IFEQ NARG-3
		move.l	(a7)+,(a3)
		move.l	\2,(a3)
		move.l	\3,(a3)+
	ENDC
	IFEQ NARG-4
		move.l	(a7)+,(a3)
		move.l	\2,(a3)
		move.l	\3,(a3)
		move.l	\4,(a3)+
	ENDC
	IFEQ NARG-5
		move.l	(a7)+,(a3)
		move.l	\2,(a3)
		move.l	\3,(a3)
		move.l	\4,(a3)
		move.l	\5,(a3)+
	ENDC
	IFEQ NARG-6
		move.l	(a7)+,(a3)
		move.l	\2,(a3)
		move.l	\3,(a3)
		move.l	\4,(a3)
		move.l	\5,(a3)
		move.l	\6,(a3)+
	ENDC
	IFEQ NARG-7
		move.l	(a7)+,(a3)
		move.l	\2,(a3)
		move.l	\3,(a3)
		move.l	\4,(a3)
		move.l	\5,(a3)
		move.l	\6,(a3)
		move.l	\7,(a3)+
	ENDC
	IFEQ NARG-8
		move.l	(a7)+,(a3)
		move.l	\2,(a3)
		move.l	\3,(a3)
		move.l	\4,(a3)
		move.l	\5,(a3)
		move.l	\6,(a3)
		move.l	\7,(a3)
		move.l	\8,(a3)+
	ENDC
	IFGT NARG-8
	FAIL Too many arguments for UAEDBG
	ENDC
		pea	(.txt\@,pc)
		move.l	(a7)+,(a3)
		move.l	(a7)+,a3
		bra.b	.go\@
.txt\@		dc.b	"%p ",\1," (%[CYCLES]d)",10,0
	EVEN
.go\@
	ENDC
	ENDM

; dump memory
; arguments: address, byte count

UAEDUMP	MACRO
	IFNE UAEDEBUG
	IFNE NARG-2
	FAIL two arguments are required for UAEDUMP
	ENDC
		movem.l	d0-d1/a0/a3,-(a7)
		move.l	\1,a0			; address
		move.w	\2,d0			; count
		lea	(UAEDBGADR),a3

.next\@		move.l	a0,(a3)			; address
		moveq	#7,d1			; 8 longs
.lp\@		move.l	(a0)+,(a3)
		dbf	d1,.lp\@

		pea	(.txt\@,pc)
		move.l	(a7)+,(4,a3)		; print

		sub.w	#4*8,d0
		bcc	.next\@

		movem.l	(a7)+,d0-d1/a0/a3
		bra.b	.go\@

.txt\@		dc.b	"%p = %08x %08x %08x %08x %08x %08x %08x %08x",10,0
	EVEN
.go\@
	ENDC
	ENDM

; print address of current pc
; make screen blue
; wait in endless loop for interception

UAEWAIT MACRO
		move.l	a3,-(a7)
		lea	(UAEDBGADR),a3
		pea	(.go\@,pc)
		move.l	(a7)+,(a3)+
		pea	(.txt\@,pc)
		move.l	(a7)+,(a3)+
		move.l	(a7)+,a3
		bra.b	.go\@
.txt\@		dc.b	"waiting at %p",10,0
	EVEN
.go\@		move.w	#$f,$dff180		; screen blue
		bra.b	.go\@
		nop				; makes breakpoint after loop easier
	ENDM

; example test code
; vasmm68k_mot -Fhunkexe -kick1hunks -DUAEDEBUG=1 -DTESTCODE -o uaedebug uaedebug.i
; ira -A uaedebug && cat uaedebug.asm

	IFD TESTCODE

		UAEDBG	"Test1"
		UAEDBG	<"Test2 %s">,#_text
		move.l	#1000,d0
		UAEDBG	<"Test3 d=%d x=%05x u=%u">,d0,#1000,#-1000
		moveq	#-1,d0
.loop		tst.b	$bfe001
		dbf	d0,.loop
		UAEDBG	"Cycles Run"

		UAEDUMP	#0,#127

		lea	(UAEDBGADR),a0
		move.w	#300,(a0)
		move.b	#10,(a0)
		lea	_test4,a1
		move.l	a1,(4,a0)

		lea	(UAEDBGADR),a0
		move.w	#300,(a0)
		move.b	#10,(a0)
		UAEDBG	<"Test5 word=%d byte=%d">

		moveq	#0,d0
		rts

_text		dc.b	"Text",0
_test4		dc.b	"Test4 word=%d byte=%d",10,0

	ENDC

